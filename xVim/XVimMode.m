//
//  Created by Morris on 11-12-16.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "XVimMode.h"
#import "XVimController.h"
#import "XTextViewBridge.h"
#import "vim.h"

@implementation XVimModeHandler
-(void) enter{}
-(void) reset{}
-(BOOL) processKey:(unichar)k modifiers:(NSUInteger)f forController:(XVimController*) c { return NO; }
@end

@implementation XVimVisualModeHandler
@end
@implementation XVimExModeHandler
@end



@implementation XVimInsertModeHandler
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags forController:(XVimController*)controller
{
    if (key == XEsc && (flags & XImportantMask) == 0)
    {
        XTextViewBridge* bridge = [controller bridge];
        if ([bridge closePopup] == NO)
        {
            // There's no popup, so we now switch to Normal Mode.
            NSTextView* view     = [bridge targetView];
            NSString*   string   = [[view textStorage] string];
            NSUInteger  index    = [view selectedRange].location;
            NSUInteger  maxIndex = [string length] - 1;
            if (index > maxIndex) {
                index = maxIndex;
            }
            if (index > 0) {
                if (testNewLine([string characterAtIndex:index - 1]) == NO) {
                    [view setSelectedRange:NSMakeRange(index - 1, 0)];
                }
            }
            
            [controller switchToMode:NormalMode];
        }
        return YES;
    }
    
    if(flags == (XMaskNumeric | XMaskFn))
    {
        NSTextView* view     = [[controller bridge] targetView];
        NSString*   string   = [[view textStorage] string];
        NSUInteger  index    = [view selectedRange].location;
        NSUInteger  maxIndex = [string length] - 1;
        if (key == NSLeftArrowFunctionKey)
        {
            if (index > 0 && testNewLine([string characterAtIndex:index - 1]) == NO) {
                return NO;
            } else {
                return YES;
            }
        } else if (key == NSRightArrowFunctionKey) {
            if (index <= maxIndex && testNewLine([string characterAtIndex:index]) == NO) {
                return NO;
            } else {
                return YES;
            }
        }
    }
    
    return NO;
}
@end



@implementation XVimReplaceModeHandler
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags forController:(XVimController*)controller
{
    if ((flags & XImportantMask) != 0) {
        // This may not be a visible character, let the NSTextView process it.
        return NO;
    }
    
    if (key == XEsc)
    {
        if ([[controller bridge] closePopup] == NO) {
            [controller switchToMode:NormalMode];
        }
        return YES;
    }
    
    // Replace mode behaviour:
    // 1. Typing will replace the character after the caret.
    // 2. If the character after the caret is newline, we insert char instead of replacing.
    // 3. We can move the caret by using arrow keys and home key and ...
    // 4. Deleting a replaced character is restoring it (We can't restore the char after
    //    moving the caret)
    
    // Extra: if the caret doesn't moved, all the change should be grouped together, so that
    //        undo once can return to the state before replace mode.
    
    // FIXME: Almost none of the beviour above is supported right now.
    
    NSTextView* hijackedView = [[controller bridge] targetView];
    NSString*   string       = [[hijackedView textStorage] string];
    NSUInteger  maxIndex     = [string length] - 1;
    NSRange     range        = [hijackedView selectedRange];
    if (range.location >= maxIndex || testNewLine([string characterAtIndex:range.location]))
    {
        // Let the textview process the key input, that is inserting the char.
        return NO;
    } else {
        range.length = 1;
        NSString* ch = [NSString stringWithCharacters:&key length:1];
        [hijackedView insertText:ch replacementRange:range];
        return YES;
    }
}
@end



@implementation XVimSReplaceModeHandler
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags forController:(XVimController*)controller
{
    if ((flags & XImportantMask) != 0) {
        // This may not be a visible character, let the NSTextView process it.
        return NO;
    }
    
    if (key == XEsc)
    {
        if ([[controller bridge] closePopup] == NO) {
            [controller switchToMode:NormalMode];
        }
        return YES;
    }
    
    NSTextView* hijackedView = [[controller bridge] targetView];
    NSRange range = [hijackedView selectedRange];
    range.length = 1;
    
    NSString* ch = [NSString stringWithCharacters:&key length:1];
    [hijackedView insertText:ch replacementRange:range];
    range.length = 0;
    [hijackedView setSelectedRange:range];
    [controller switchToMode:NormalMode];
    return YES;
}
@end



@interface XVimNormalModeHandler()
{
    @private
        int     commandCount;
        int     motionCount;
        unichar commandChar;
        unichar motionChar;
}
@end

@implementation XVimNormalModeHandler
-(void) reset
{
    commandCount = 0;
    motionCount  = 0;
    commandChar  = 0;
    motionChar   = 0;
}

// Below are commands that are going to be implemented.
// #>    Indent
// #<    Un-Indent
// #|    Jump to column (specified by the repeat parameter).
// {     Goto start of current (or previous) paragraph
// }     Goto end of current (or next) paragraph
// zt	 Scroll view so current line becomes the first line
// zb	 Scroll view so current line is at the bottom (last line)
// fx    Find char x on current line and go to it
// tx    Similar to fx, but stops one character short before x
// Fx    Similar to fx, but searches backwards
// Tx    Similar to tx, but searches backwards
// #;    Repeat last find motion
// #,    Repeat last find motion, but in reverse
// #*    Find next occurance of identifier under caret or currently selected text
// ##    Similar to * but backwards
// :#    Jump to line number #.
// :q, :q!, :w, :wq, :x

// y	 Yank (copy). See below for more.
// d	 Delete. (also yanks)
// c     Change: deletes (and yanks) then enters insert mode.
-(BOOL) processKey:(unichar)ch modifiers:(NSUInteger)flags forController:(XVimController*)controller
{
    // Currently we have nothing to do with a key, if it has some flags.
    if ((flags & XImportantMask) != 0) { return NO; }
    // Esc will reset everything
    if (ch == XEsc) { [self reset]; return YES; }
    
    XTextViewBridge* bridge       = [controller bridge];
    NSTextView*      hijackedView = [bridge targetView];
    
    // If the commandCount is not defined, we treat '0' as a command instead of a number.
    if (ch <= '9' && ((commandCount > 0 && ch >= '0') || (commandCount == 0 && ch > '0')) )
    {
        DLog(@"This key is a digit");
        if (commandChar == 0) {
            commandCount = commandCount * 10 + ch - '0';
            DLog(@"Current command count is: %d", commandCount);
        } else if(motionChar == 0) {
            motionCount = motionCount * 10 + ch - '0';
            DLog(@"Current motion count is: %d", motionCount);
        } else {
            // Bad command, ignore it.
            [self reset];
            DLog(@"Bad command, ignoring.");
        }
        return YES;
    }
    
    BOOL commandCountSpecified = commandCount > 0; // This is need only for 'G'
    if (commandCount == 0) commandCount = 1;
    
    if (commandChar != 0)
    {
        if (commandChar == ch)
        {
            if (motionCount != 0) { commandCount *= motionCount; }
            switch (ch) {
                case 'g': textview_goto_line(hijackedView, 0, YES); break;
                case 'z': [hijackedView _scrollRangeToVisible:[hijackedView selectedRange]
                                                  forceCenter:YES]; break;
                case 'y':
                {
                    ch = 'Y';
                    commandChar = 0;
                    motionCount = 0;
                    goto yy_escape;
                }
                    
                case 'd':
                    // Delete whole lines.
                    
                case 'c':
                    // Delete whole lines except last new line character. And enter insert mode.
                    
                default:
                    break;
            }
        }
        
        [self reset];
        return YES;
    }
    
yy_escape:
    
    switch (ch) {
            // NOTE: 'j' and 'k' calls the NSTextView's methods,
            // So them won't ensure that the caret won't be before the CR
        case 'j': for (int i = 0; i < commandCount; ++i) { [hijackedView moveDown:nil]; } break;
        case 'k': for (int i = 0; i < commandCount; ++i) { [hijackedView moveUp:nil];   } break;
        case NSDeleteCharacter: // Backspace in normal mode are like 'h'
        case 'h': [hijackedView setSelectedRange:NSMakeRange(mv_h_handler(hijackedView,commandCount),0)]; break;
        case 'l': [hijackedView setSelectedRange:NSMakeRange(mv_l_handler(hijackedView,commandCount),0)]; break;
            
        case 'r': [controller switchToMode:SingleReplaceMode]; break;
        case 'R': [controller switchToMode:ReplaceMode];       break;
            
        case 'u': for (int i = 0; i < commandCount; ++i) { [[hijackedView undoManager] undo]; } break;
        case 'U': for (int i = 0; i < commandCount; ++i) { [[hijackedView undoManager] redo]; } break;

            
            // TODO: commandCount for aAiIoOrR is not implemented.
        case 'a':
            [hijackedView moveRight:nil];
            // Fall through to 'i'
        case 'i':
            [controller switchToMode:InsertMode];
            break;
        case '0':
            [hijackedView setSelectedRange:
             NSMakeRange(mv_0_handler(hijackedView), 0)];
            break;
        case '$':
            [hijackedView setSelectedRange:
             NSMakeRange(mv_dollar_handler(hijackedView), 0)];
            break;
        case 'A':
            [hijackedView moveToEndOfLine:nil];
            [controller switchToMode:InsertMode];
            break;
        case '_':
        case '^':
        case 'I':
        {
            [hijackedView setSelectedRange:
             NSMakeRange(mv_caret_handler(hijackedView), 0)];
            if (ch == 'I') { [controller switchToMode:InsertMode]; }
        }
            break;
        case 'o':
            [hijackedView moveToEndOfLine:nil];
            [hijackedView insertNewline:nil];
            [controller switchToMode:InsertMode];
            break;
        case 'O':
        {
            NSRange currRange = [hijackedView selectedRange];
            [hijackedView moveUp:nil];
            if (currRange.location == [hijackedView selectedRange].location) {
                [hijackedView moveToBeginningOfLine:nil];
            } else {
                [hijackedView moveToEndOfLine:nil];
            }
            [hijackedView insertNewline:nil];
            [controller switchToMode:InsertMode];
        }
            break;
            
            
        case 'H':
        {
            NSRange lines = [bridge visibleParagraphRange];
            if (lines.length != 0) { textview_goto_line(hijackedView,lines.location, NO); }
        }
            break;
        case 'M':
        {
            NSRange lines = [bridge visibleParagraphRange];
            if (lines.length != 0) 
                textview_goto_line(hijackedView, lines.location + lines.length / 2, NO);
        }
            break;
        case 'L':
        {
            NSRange lines = [bridge visibleParagraphRange];
            if (lines.length != 0) 
                textview_goto_line(hijackedView, lines.location + lines.length, NO);
        }
            break;
        case 'G':
            textview_goto_line(hijackedView, (commandCountSpecified ? commandCount - 1 : -1), YES);
            break;
            
            
        case 'J': 
            // In Vim, if line ends with dot, two spaces are inserted isnead of one
            // when joining lines. But I don't want to do it that way. :) 
            // J, 1J, 2J are all join this line and next line. 3J is joining three lines.
            // FIXME: After undoing, the caret cannot be place at where 'J' is called.
        {
            NSString* string    = [[hijackedView textStorage] string];
            NSUInteger index    = [hijackedView selectedRange].location;
            NSUInteger maxIndex = [string length] - 1;
            NSUndoManager* undoManager = [hijackedView undoManager];
            
            commandCount = commandCount > 2 ? commandCount - 1 : 1;
            
            [undoManager beginUndoGrouping];
            
            for (int i = 0; i < commandCount; ++i)
            {
                while (index < maxIndex) {
                    if (testNewLine([string characterAtIndex:index]))
                        break;
                    ++index;
                }
                // Now we are at the end of current line.
                if (index == maxIndex) {
                    // If the end of the textview is CR, we simply remove it.
                    if (testNewLine([string characterAtIndex:index])) {
                        [hijackedView insertText:@"" 
                                replacementRange:NSMakeRange(maxIndex, 1)];
                        [hijackedView setSelectedRange:NSMakeRange(maxIndex - 1, 0)];
                    }
                    break;
                } else {
                    // Go back to found out how many space we can remove.
                    NSInteger before = index;
                    unichar ch = 0;
                    while (before > 0) {
                        ch = [string characterAtIndex:before - 1];
                        if (ch != '\t' && ch != ' ') { break; }
                        --before;
                    }
                    // The whole line is whitespace, these whitespaces eshould not removed.
                    if (testNewLine(ch) || before == 0) { before = index; }
                    // Go forward to find space.
                    NSInteger after = index;
                    NSInteger place = before;
                    while (after < maxIndex) {
                        ch = [string characterAtIndex:after + 1];
                        if (ch != '\t' && ch != ' ') { break; }
                        ++after;
                    }
                    // The whole line is whitespace, these whitespaces eshould not removed.
                    if (testNewLine(ch) || after == maxIndex) { 
                        place = after; 
                        after = index;
                    }
                    [hijackedView insertText:@" " 
                            replacementRange:NSMakeRange(before, after - before + 1)];
                    [hijackedView setSelectedRange:NSMakeRange(place, 0)];
                }
            }
            
            [undoManager endUndoGrouping];
        }
            break;
            
            
        case 'X':
        {
            NSInteger index = [hijackedView selectedRange].location;
            NSInteger rIndex = index - commandCount;
            if (rIndex < 0) { rIndex = 0; }
            if (index > rIndex) {
                [hijackedView setSelectedRange:NSMakeRange(rIndex, index - rIndex)];
                [hijackedView cut:nil];
            }
        }
            break;
        case 'x':
        {
            // x deletes the character after the caret.
            // If the following is a newline and the preceding is not,
            // we have to move the caret backward once.
            NSString*  string   = [[hijackedView textStorage] string];
            NSUInteger maxIndex = [string length] - 1;
            NSUInteger index    = [hijackedView selectedRange].location;
            if (index <= maxIndex)
            {
                NSRange range = {index, commandCount};
                
                [hijackedView setSelectedRange:range];
                [hijackedView cut:nil];
                if ((index >= maxIndex - commandCount ||
                     testNewLine([string characterAtIndex:index])) &&
                    index > 0 &&
                    testNewLine([string characterAtIndex:index-1]) == NO)
                {
                    range.location = index - 1;
                    range.length = 0;
                    [hijackedView setSelectedRange:range];
                }
            }
        }
            break;
        case '~':
            // ~ will only work on the character in current line.
        {
            NSString*  string   = [[hijackedView textStorage] string];
            NSUInteger maxIndex = [string length] - 1;
            NSUInteger index    = [hijackedView selectedRange].location;
            if (index <= maxIndex && testNewLine([string characterAtIndex:index]) == NO)
            {
                NSUInteger length = 1;
                if (commandCount > 1)
                {
                    NSUInteger lineEndIndex = mv_dollar_handler(hijackedView) + 1;
                    length = lineEndIndex - index;
                    if (length > commandCount) { length = commandCount; }
                }
                
                NSRange range = {index, length};
                NSMutableString* subString = [NSMutableString stringWithString:[string substringWithRange:range]];
                NSRange r = {0,1};
                for (; r.location < length; ++r.location) {
                    unichar c = [subString characterAtIndex:r.location];
                    if (c >= 'a' && c <= 'z')
                        c = c + 'A' - 'a';
                    else if (c >= 'A' && c <= 'Z')
                        c = c + 'a' - 'A';
                    [subString replaceCharactersInRange:r 
                                             withString:[NSString stringWithCharacters:&c 
                                                                                length:1]];
                }
                [hijackedView insertText:subString replacementRange:range];
                
                range.length = 0;
                range.location += length;
                if (index < maxIndex && testNewLine([string characterAtIndex:range.location])) {
                    --range.location;
                }
                [hijackedView setSelectedRange:range];
            }
        }
            break;
            
            
            // TODO: If there's a whole line in clipboard, we should paste the content
            // in a newline. We may have to work with 'y' and observe the clipboard.
        case 'p':
        {
            NSUInteger index    = [hijackedView selectedRange].location;
            if (index < [[[hijackedView textStorage] string] length]) {
                [hijackedView setSelectedRange:NSMakeRange(index+1, 0)];
            }
        }
            // Fall through to 'P'
        case 'P':
            for (int i = 0; i < commandCount; ++i) {
                [hijackedView paste:nil];
            }
            break;
            
            
            // wWbBeE
        case 'w':
        case 'W':
        {
            NSRange range = {mv_w_handler(hijackedView, commandCount, ch == 'W'), 0};
            [hijackedView setSelectedRange:range];
            [hijackedView scrollRangeToVisible:range];
        }
            break;
        case 'b':
        case 'B':
        {
            NSRange range = {mv_b_handler(hijackedView, commandCount, ch == 'B'), 0};
            [hijackedView setSelectedRange:range];
            [hijackedView scrollRangeToVisible:range];
        }
            break;
        case 'e':
        case 'E':
        {
            NSRange range = {mv_e_handler(hijackedView, commandCount, ch == 'E'), 0};
            [hijackedView setSelectedRange:range];
            [hijackedView scrollRangeToVisible:range];
        }
            break;
            
        case 'Y':
        case 'D':
        case 'C':
        {
            // Yank the whole line, but does not include the last new line character.
            NSString*  string   = [[hijackedView textStorage] string];
            NSUInteger current  = [hijackedView selectedRange].location;
            NSUInteger lineEnd  = current;
            NSUInteger max      = [string length] - 1;
            while (lineEnd <= max)
            {
                if (testNewLine([string characterAtIndex:lineEnd])) {
                    --commandCount;
                    if (commandCount == 0) { break; }
                }
                ++lineEnd;
            }
            
            NSUInteger lineBegin = ch == 'Y' ? mv_0_handler(hijackedView) : current;
            NSRange    range     = {lineBegin, lineEnd - lineBegin};
            [hijackedView setSelectedRange:range];
            [hijackedView copy:nil];
            [hijackedView setSelectedRange:NSMakeRange(current, 0)];
            
            if (ch == 'Y')
            {
                // TODO: Mark that we have copied a whole line, so that 'pP' can paste at a new line.
            } else {
                [hijackedView insertText:@"" replacementRange:range];
                if (ch == 'C') {
                    [controller switchToMode:InsertMode];
                } else {
                    max     = [string length] - 1;
                    current = [hijackedView selectedRange].location;
                    
                    if ((current > max && testNewLine([string characterAtIndex:max]) == NO) ||
                        testNewLine([string characterAtIndex:current]) == YES)
                    {
                        [hijackedView setSelectedRange:NSMakeRange(current - 1, 0)];
                    }
                }
            }
        }
            break;
            
        // Below are commands that need a parameter
        case 'g':
        case 'z':
        case 'y':
        case 'd':
        case 'c':
            commandChar = ch;
            goto dontResetCommandCount;
            break;
    }
    
    commandCount = 0; // We don't have to reset the other properties.
    
dontResetCommandCount:
    return YES;
}
@end
