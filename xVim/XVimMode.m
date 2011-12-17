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
-(void) processKey:(NSString *)key For:(XVimController *)controller{}
@end

@implementation XVimInsertModeHandler
-(void) processKey:(NSString*)key For:(XVimController*)controller
{
    if ([key compare:@"<Esc>"] == NSOrderedSame) {
        if ([[controller bridge] closePopup] == NO) {
            // There's no popup, so we now switch to Normal Mode.
            [controller switchToMode:NormalMode];
        }
    } else {
        // The key is not Esc, send the key back to the hijacked textview.
        NSEvent* keyEvent = [controller currentKeyEvent];
        if (keyEvent == nil) { keyEvent = [XVimController fakeEventFor:key]; }
        [[controller bridge] handleFakeKeyEvent:keyEvent];
    }
}
@end

@implementation XVimReplaceModeHandler
-(void) processKey:(NSString*) key For:(XVimController*) controller
{
    if ([key compare:@"<Esc>"] == NSOrderedSame) {
        if ([[controller bridge] closePopup] == NO) {
            // There's no popup, so we now switch to Normal Mode.
            // TODO: When switch to Normal Mode, if the caret is not at 
            // the beginning of the line, we should move the caret left.
            [controller switchToMode:NormalMode];
        }
    } else {
        if ([key length] == 1)
        {
            // This key should be a visible key input.
            // Change the text.
            
            // TODO: This approach works, however,
            // the replacing doesn't group together, so that undo once
            // can only get back one character.
            // When we are at the end of the line, we need to insert that
            // charater, instead of replacing the new-line character.
            NSTextView* hijackedView = [[controller bridge] targetView];
            NSRange selectedRange = [hijackedView selectedRange];
            selectedRange.length = 1;
            [hijackedView setSelectedRange:selectedRange];
            [hijackedView insertText:key];
        }
    }
}
@end

@implementation XVimSReplaceModeHandler
-(void) processKey:(NSString *)key For:(XVimController *)controller
{
    if ([key compare:@"<Esc>"] == NSOrderedSame) {
        if ([[controller bridge] closePopup] == NO) {
            // There's no popup, so we now switch to Normal Mode.
            [controller switchToMode:NormalMode];
        }
    } else {
        if ([key length] == 1)
        {
            NSTextView* hijackedView = [[controller bridge] targetView];
            NSRange selectedRange = [hijackedView selectedRange];
            selectedRange.length = 1;
            [hijackedView setSelectedRange:selectedRange];
            [hijackedView insertText:key];
            [controller switchToMode:NormalMode];
        }
    }
}
@end

@interface XVimNormalModeHandler()
{
    @private
        int commandCount;
        int motionCount;
        unichar commandChar;
        unichar motionChar;
}
@end

NSCharacterSet* characterSetForChar(unichar ch);
NSCharacterSet* characterSetForChar(unichar ch)
{
    if (isdigit(ch)) return [NSCharacterSet decimalDigitCharacterSet];
    if (isalpha(ch)) return [NSCharacterSet letterCharacterSet];
    if (ch == ' ' || ch == '\t') return [NSCharacterSet whitespaceCharacterSet];
    if (isascii(ch)) return [NSCharacterSet characterSetWithCharactersInString:
                             @"`~!@#$%^&*()_+{}|:\"<>?-=[]\\;',./"];
    return [[NSCharacterSet characterSetWithRange:NSMakeRange(0, 128)] invertedSet];
}

@implementation XVimNormalModeHandler
-(id) init
{
    [super init];
    commandCount = 0;
    motionCount = 0;
    commandChar = 0;
    motionChar = 0;
    return self;
}
-(void) reset
{
    commandCount = 0;
    motionCount = 0;
    commandChar = 0;
    motionChar = 0;
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
// #G    Goto last line, or line number (eg 12G goes to line 12)
// #u    Undo.
// #U    Redo.
// #J    Join this line with the one(s) under it.
// #x    Delete character under caret, and put the deleted chars into clipboard.
// #X    Delete character before caret (backspace), and put the deleted chars into clipboard.
// #~    Toggle case of character(s) under caret and move caret across them.
// #w    Moves to the start of the next word
// #b    Moves (back) to the start of the current (or previous) word.
// #e    Moves to the end of the current (or next) word.
// #WBE  Similar to wbe commands, but words are separated by white space, so ABC+X(Y) is considered a single word.

// Below are commands that are going to be implemented.
// #>    Indent
// #<    Un-Indent
// #|    Jump to column (specified by the repeat parameter).

// Below are commands that I don't know how to implement.
// #.    Repeat last change/insert command (doesn't repeat motions or other things).

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
//p	 Paste text, if copied text is whole lines, pastes below current line.
//P	 Paste text, if copied text is whole lines, pastes above current line.
//y	 Yank (copy). See below for more.
//d	 Delete. (also yanks)
//c	 Change: deletes (and yanks) then enters insert mode.
//   Y	 Yank from current position to the end of line
//   D	 Delete from current position to the end of line
//   C	 Change from current position to the end of line
//   s	 Substitute: deletes character under caret and enter insert mode.
//   S	 Change current line (substitute line)
-(void) processKey:(NSString*) key For:(XVimController*) controller
{
    if ([key compare:@"<Esc>"] == NSOrderedSame) {
        [self reset];
        return;
    }
    
    XTextViewBridge* bridge  = [controller bridge];
    NSTextView* hijackedView = [bridge targetView];
    
    if ([key length] == 1)
    {
        unichar ch = [key characterAtIndex:0];
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
        } else {
            
            BOOL commandCountSpecified = commandCount > 0;
            if (commandCount == 0) commandCount = 1;
            if (commandChar == 0) {
                // We don't receive any motion command yet (ydc).
                
                switch (ch) {
                    case 'h':
                        [hijackedView setSelectedRange:
                         NSMakeRange(mv_h_handler(hijackedView, commandCount), 0)];
                        break;
                    case 'l': 
                        [hijackedView setSelectedRange:
                         NSMakeRange(mv_l_handler(hijackedView, commandCount), 0)];
                        break;
                    // TODO: 'j' and 'k' calls the NSTextView's methods,
                    // So them won't ensure that the caret won't be before the CR
                    case 'j': 
                        for (int i = 0; i < commandCount; ++i)
                            [hijackedView moveDown:nil];
                        break;
                    case 'k':
                        for (int i = 0; i < commandCount; ++i)
                            [hijackedView moveUp:nil];
                        break;

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
                    case 'r':
                        [controller switchToMode:SingleReplaceMode];
                        break;
                    case 'R':
                        [controller switchToMode:ReplaceMode];
                        break;
                    case 'H':
                    {
                        NSRange lines = [bridge visibleParagraphRange];
                        DLog(@"Line Range: %@", NSStringFromRange(lines));
                        if (lines.length != 0) { textview_goto_line(hijackedView,lines.location, NO); }
                    }
                        break;
                    case 'M':
                    {
                        NSRange lines = [bridge visibleParagraphRange];
                                                DLog(@"Line Range: %@", NSStringFromRange(lines));
                        if (lines.length != 0) 
                            textview_goto_line(hijackedView, lines.location + lines.length / 2, NO);
                    }
                        break;
                    case 'L':
                    {
                        NSRange lines = [bridge visibleParagraphRange];
                        DLog(@"Line Range: %@", NSStringFromRange(lines));
                        if (lines.length != 0) 
                            textview_goto_line(hijackedView, lines.location + lines.length, NO);
                    }
                        break;
                    case 'G':
                        textview_goto_line(hijackedView, (commandCountSpecified ? commandCount - 1 : -1), YES);
                        break;
                    case 'u':
                        for (int i = 0; i < commandCount; ++i)
                            [[hijackedView undoManager] undo];
                        break;
                    case 'U':
                        for (int i = 0; i < commandCount; ++i)
                            [[hijackedView undoManager] redo];
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
                    
                        
                    // wWbBeE
                    case 'w':
                    {
                        NSRange    range       = [hijackedView selectedRange];
                        NSString*  string      = [[hijackedView textStorage] string];
                        NSUInteger maxIndex    = [string length] - 1;
                        NSCharacterSet* wspSet = [NSCharacterSet whitespaceCharacterSet];
                        NSCharacterSet* nlSet  = [NSCharacterSet newlineCharacterSet];
                        
                        for (int i = 0; i < commandCount; ++i)
                        {
                            if (range.location >= maxIndex) { break; }
                            
                            unichar ch = [string characterAtIndex:range.location];
                            
                            BOOL blankLine = NO;
                            NSCharacterSet* cs = characterSetForChar(ch);
                            
                            do
                            {
                                ++range.location;
                                ch = [string characterAtIndex:range.location];
                            } while (range.location < maxIndex && [cs characterIsMember:ch]);
                            
                            while (range.location < maxIndex)
                            {
                                ch = [string characterAtIndex:range.location];
                                if (blankLine == NO && [nlSet characterIsMember:ch]) {
                                    blankLine = YES;
                                } else if ([wspSet characterIsMember:ch]) {
                                    blankLine = NO;
                                } else {
                                    break;
                                }
                                ++range.location;
                            }
                            
                            [hijackedView setSelectedRange:range];
                            [hijackedView scrollRangeToVisible:range];
                        }
                        
                    }
                        break;
                    case 'b':
                    {
                        NSRange    range       = [hijackedView selectedRange];
                        NSString*  string      = [[hijackedView textStorage] string];
                        NSCharacterSet* wspSet = [NSCharacterSet whitespaceCharacterSet];
                        NSCharacterSet* nlSet  = [NSCharacterSet newlineCharacterSet];
                        
                        for (int i = 0; i < commandCount; ++i)
                        {
                            if (range.location <= 0) { break; }
                            
                            unichar ch = [string characterAtIndex:range.location];
                            
                            BOOL blankLine = NO;
                            NSCharacterSet* cs = characterSetForChar(ch);
                            
                            do
                            {
                                --range.location;
                                ch = [string characterAtIndex:range.location];
                            } while (range.location > 0 && [cs characterIsMember:ch]);
                            
                            while (range.location > 0)
                            {
                                ch = [string characterAtIndex:range.location];
                                if (blankLine == NO && [nlSet characterIsMember:ch]) {
                                    blankLine = YES;
                                } else if ([wspSet characterIsMember:ch]) {
                                    blankLine = NO;
                                } else {
                                    break;
                                }
                                --range.location;
                            }
                            
                            cs = characterSetForChar(ch);
                            
                            while (range.location > 0) {
                                ch = [string characterAtIndex:range.location - 1];
                                if ([cs characterIsMember:ch] == NO) { break; }
                                --range.location;
                            }
                            
                            [hijackedView setSelectedRange:range];
                            [hijackedView scrollRangeToVisible:range];
                        }
                        
                    }
                        break;
                }
                
                commandCount = 0; // We don't have to reset the other properties.
                
                
            } else {
                // Handle the motion command.
            }
            
        }
    } else {
        
    }
    
}
@end

@implementation XVimVisualModeHandler
-(void) processKey:(NSString*) key For:(XVimController*) controller{}
@end

@implementation XVimExModeHandler
-(void) processKey:(NSString*) key For:(XVimController*) controller{}
@end
