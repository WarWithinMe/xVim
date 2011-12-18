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
    // The support for insert mode is not completed.
    if (key == XEsc && (flags & XImportantMask) == 0)
    {
        if ([[controller bridge] closePopup] == NO) {
            // There's no popup, so we now switch to Normal Mode.
            // FIXME: When switch to Normal Mode, if the caret is not at 
            // the beginning of the line, we should move the caret left.
            [controller switchToMode:NormalMode];
        }
        return YES;
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
    
    // FIXME: Almost none of the beviour above is supported right now.
    
    NSTextView* hijackedView = [[controller bridge] targetView];
    NSRange range = [hijackedView selectedRange];
    range.length = 1;
    
    NSString* ch = [NSString stringWithCharacters:&key length:1];
    [hijackedView insertText:ch replacementRange:range];

    return YES;
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
    
    // Replace mode behaviour:
    // 1. Typing will replace the character after the caret.
    // 2. If the character after the caret is newline, we insert char instead of replacing.
    // 3. We can move the caret by using arrow keys and home key and ...
    // 4. Deleting a replaced character is restoring it (We can't restore the char after
    //    moving the caret)
    
    // FIXME: Almost none of the beviour above is supported right now.
    
    NSTextView* hijackedView = [[controller bridge] targetView];
    NSRange range = [hijackedView selectedRange];
    range.length = 1;
    
    NSString* ch = [NSString stringWithCharacters:&key length:1];
    [hijackedView insertText:ch replacementRange:range];
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

// #h    Moves caret to the left
// #j    Moves caret down
// #k    Moves caret up
// #l    Moves caret to the left
//  i    Enters insert mode
//  a    Enters insert mode after the current character
//  I    Enters insert mode at the start of the indentation of current line
//  A    Enters insert mode at the end of line
//  o    Opens a new line below, auto indents, and enters insert mode
//  O    Opens a new line above, auto indents, and enters insert mode
//  r    Enters single replace mode (insert mode with overtype enabled).
//  R    Enters replace mode (insert mode with overtype enabled).
//  0    Move to start of current line
//  $    Move to end of current line
//  _    Move to the start of indentation on current line.
//  ^    Move to the start of indentation on current line.
//  H    Goto first visible line
//  M    Goto the middle of the screen
//  L    Goto last visible line
// #G    Goto last line, or line number (eg 12G goes to line 12), 0G means goto last line.
// #u    Undo.
// #U    Redo.
// #J    Join this line with the one(s) under it.
// #x    Delete character under caret, and put the deleted chars into clipboard.
// #X    Delete character before caret (backspace), and put the deleted chars into clipboard.
// #~    Toggle case of character(s) under caret and move caret across them.
// #p    Paste text after the caret.
// #P    Paste text.
// #w    Moves to the start of the next word
// #b    Moves (back) to the start of the current (or previous) word.
// #e    Moves to the end of the current (or next) word.
// #WBE  Similar to wbe commands, but words are separated by white space, so ABC+X(Y) is considered a single word.

// Below are commands that are going to be implemented.
// #>    Indent
// #<    Un-Indent
// #|    Jump to column (specified by the repeat parameter).
// :#    Jump to line number #.
// :q, :q!, :w, :wq, :x
//{	 Goto start of current (or previous) paragraph
//}	 Goto end of current (or next) paragraph
//rb	 Replace character under caret with b
//zt	 Scroll view so current line becomes the first line
//zz	 Scroll view so current line is in the middle
//zb	 Scroll view so current line is at the bottom (last line)
//gg	 Goto first line in file
//fx	 Find char x on current line and go to it
//tx	 Similar to fx, but stops one character short before x
//Fx	 Similar to fx, but searches backwards
//Tx	 Similar to tx, but searches backwards
//;	 Repeat last find motion
//,	 Repeat last find motion, but in reverse
//*	 Find next occurance of identifier under caret or currently selected text
//#	 Similar to * but backwards
//y	 Yank (copy). See below for more.
//d	 Delete. (also yanks)
//c	 Change: deletes (and yanks) then enters insert mode.
//   Y	 Yank from current position to the end of line
//   D	 Delete from current position to the end of line
//   C	 Change from current position to the end of line
//   s	 Substitute: deletes character under caret and enter insert mode.
//   S	 Change current line (substitute line)
// KeyMapping

// Below are commands that I don't know how to implement.
// #.    Repeat last change/insert command (doesn't repeat motions or other things).

// Below are functionality that I don't want/know how to implement.
// 1. Search and Replace
// 2. Marker
// 3. Register
// 4. Folding and anything that is not metiond above.
-(BOOL) processKey:(unichar)ch modifiers:(NSUInteger)flags forController:(XVimController*)controller
{
    if ((flags & XImportantMask) != 0) {
        // Currently we have nothing to do with a key, if it has some flags.
        return NO;
    }
    
    if (ch == XEsc)
    {
        [self reset];
        return YES;
    }
    
    XTextViewBridge* bridge  = [controller bridge];
    NSTextView* hijackedView = [bridge targetView];
    
    if (ch <= '9' && ((commandCount > 0 && ch >= '0') || (commandCount == 0 && ch > '0')) )
    {
        DLog(@"This key is a digit");
        if (commandChar == 0) {
            commandCount = commandCount * 10 + digittoint(ch);
            DLog(@"Current command count is: %d", commandCount);
        } else if(motionChar == 0) {
            motionCount = motionCount * 10 + digittoint(ch);
            DLog(@"Current motion count is: %d", motionCount);
        } else {
            // Bad command, ignore it.
            [self reset];
            DLog(@"Bad command, ignoring.");
        }
        return YES;
    }
    
    BOOL commandCountSpecified = commandCount > 0;
    if (commandCount == 0) commandCount = 1;
    
    if (commandChar != 0) {
        // Currently the ydc like commands are not supported.
        return YES;
    }
    
    switch (ch) {
            // NOTE: 'j' and 'k' calls the NSTextView's methods,
            // So them won't ensure that the caret won't be before the CR
        case 'j': for (int i = 0; i < commandCount; ++i) { [hijackedView moveDown:nil]; } break;
        case 'k': for (int i = 0; i < commandCount; ++i) { [hijackedView moveUp:nil];   } break;
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
            NSCharacterSet* set = [NSCharacterSet newlineCharacterSet];
            NSUndoManager* undoManager = [hijackedView undoManager];
            
            commandCount = commandCount > 2 ? commandCount - 1 : 1;
            
            [undoManager beginUndoGrouping];
            
            for (int i = 0; i < commandCount; ++i)
            {
                while (index < maxIndex) {
                    if ([set characterIsMember:[string characterAtIndex:index]])
                        break;
                    ++index;
                }
                // Now we are at the end of current line.
                if (index == maxIndex) {
                    // If the end of the textview is CR, we simply remove it.
                    if ([set characterIsMember:[string characterAtIndex:index]]) {
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
                    if ([set characterIsMember:ch] || before == 0) { before = index; }
                    // Go forward to find space.
                    NSInteger after = index;
                    NSInteger place = before;
                    while (after < maxIndex) {
                        ch = [string characterAtIndex:after + 1];
                        if (ch != '\t' && ch != ' ') { break; }
                        ++after;
                    }
                    // The whole line is whitespace, these whitespaces eshould not removed.
                    if ([set characterIsMember:ch] || after == maxIndex) { 
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
        case '~':
            // x and ~ will only work on the character in current line.
        {
            NSString*  string   = [[hijackedView textStorage] string];
            NSUInteger maxIndex = [string length] - 1;
            NSUInteger index    = [hijackedView selectedRange].location;
            NSCharacterSet* set = [NSCharacterSet newlineCharacterSet];
            if (index <= maxIndex &&
                [set characterIsMember:[string characterAtIndex:index]] == NO)
            {
                NSUInteger length = 1;
                if (commandCount > 1)
                {
                    NSUInteger lineEndIndex = mv_dollar_handler(hijackedView) + 1;
                    length = lineEndIndex - index;
                    if (length > commandCount) { length = commandCount; }
                }
                
                NSRange range = {index, length};
                
                if (ch == 'x')
                {
                    [hijackedView setSelectedRange:range];
                    [hijackedView cut:nil];
                    if ((index >= maxIndex - length ||
                         [set characterIsMember:[string characterAtIndex:index]]) &&
                        index > 0 &&
                        [set characterIsMember:[string characterAtIndex:index-1]] == NO)
                    {
                        range.location = index - 1;
                        range.length = 0;
                        [hijackedView setSelectedRange:range];
                    }
                } else {
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
                    if (index < maxIndex && 
                        [set characterIsMember:[string characterAtIndex:range.location]])
                    {
                        --range.location;
                    }
                    [hijackedView setSelectedRange:range];
                }
                
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
    }
    
    commandCount = 0; // We don't have to reset the other properties.
    return YES;
}
@end
