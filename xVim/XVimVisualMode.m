//
//  Created by Morris on 12-1-1.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#ifdef __LP64__

#import "XVimMode.h"
#import "XGlobal.h"
#import "XTextViewBridge.h"
#import "vim.h"

@interface XVimVisualModeHandler()
{
@private
    BOOL isLineMode;
    BOOL dontCheckSel;
    
    NSInteger selectionStart;
    NSInteger selectionEnd; // selectionStart and selectionEnd are the 
                            // same if selection is only one char
    
    int count;
    unichar cmd;
    NSTextView* hijackedView;
}
-(void) switchToMode:(VimMode) mode;
-(NSRange) linewiseRange;
-(NSRange) characterwiseRange;

-(void) updateRealSelection;
-(void) setNewSelectionEnd:(NSInteger) end;
@end

@implementation XVimVisualModeHandler

-(NSRange) linewiseRange
{
    NSInteger start, end;
    if (selectionStart < selectionEnd) {
        start = selectionStart;
        end = selectionEnd + 1;
    } else {
        start = selectionEnd;
        end = selectionStart + 1;
    }
    
    xv_set_index(start);
    start = xv_0();
    xv_set_index(end);
    end = xv_dollar_inc();
    return NSMakeRange(start, end - start);
}
-(NSRange) characterwiseRange
{
    if (selectionStart < selectionEnd) {
        return NSMakeRange(selectionStart, selectionEnd + 1 - selectionStart);
    } else {
        return NSMakeRange(selectionEnd, selectionStart + 1 - selectionEnd);
    }
}
-(void) setNewSelectionEnd:(NSInteger)end
{
    selectionEnd = end;
    if (isLineMode) {
        [hijackedView setSelectedRange:[self linewiseRange]];
    } else {
        [hijackedView setSelectedRange:[self characterwiseRange]];
    }
    [hijackedView scrollRangeToVisible:NSMakeRange(end, 1)];
}


-(void) reset 
{
    dontCheckSel = NO;
    cmd = 0;
    count = 0;
    selectionStart = 0;
    selectionEnd   = 0;
}
-(void) enterWith:(VimMode)submode 
{ 
    isLineMode   = (submode == VisualLineMode);
    hijackedView = [[controller bridge] targetView];
    
    [self updateRealSelection];
}

-(void) updateRealSelection
{
    dontCheckSel = YES;
    
    NSRange     selection = [hijackedView selectedRange];
    NSUInteger  length    = [[hijackedView textStorage] length];
    
    DLog(@"Selection: %@", [[hijackedView string] substringWithRange:selection]);
    
    selectionStart = selection.location;
    selectionEnd   = selectionStart;
    
    if (selection.length == 0)
    {        
        // We enter Visual Mode by pressing v,V
        if (selection.location < length)
        {
            // Not at the bottom of file, select the char under the caret.
            [hijackedView setSelectedRange:NSMakeRange(selectionStart, 1)];
        }
        
    } else if ([[controller bridge] ignoreString:[hijackedView string] 
                                       selection:selection])
    {
        [controller switchToMode:InsertMode subMode:NoSubMode];
    } else {
        NSInteger trackingSelStart = [controller getTrackingSel];
        if (trackingSelStart != -1)
        {            
            NSInteger end = selection.location + selection.length;
            if (end == trackingSelStart)
            {
                selectionStart = trackingSelStart - 1;
                selectionEnd   = selection.location;
            } else {
                selectionEnd   = end - 1;
            }
        }
    }
    
    dontCheckSel = NO;
}

-(NSArray*) selectionChangedFrom:(NSArray*)oldRanges to:(NSArray*)newRanges
{
    if (dontCheckSel) { return newRanges; }
    
    if ([[newRanges objectAtIndex:0] rangeValue].length == 0)
    {
        [controller switchToMode:NormalMode subMode:NoSubMode];
    } else {
        [self updateRealSelection];
    }
    
    return newRanges;
}

-(void) switchToMode:(VimMode) mode
{
    NSRange idx = NSMakeRange(selectionStart, 0);
    [controller switchToMode:mode subMode:NoSubMode];
    [hijackedView setSelectedRange:idx];
    [hijackedView scrollRangeToVisible:idx];
}

-(BOOL) processKey:(unichar)c modifiers:(NSUInteger)flags
{
    // Don't interpret tabs.
    // Note : In my machine, Shift-Tab produce a character 25. 
    //        Don't know if it's the same in the other's machine.
    if (c == '\t' || c == 25) { return NO; } 
    
    dontCheckSel = YES;
    
    NSString* string    = [[hijackedView textStorage] string];
    NSRange   selection = [hijackedView selectedRange];
    NSInteger caretIdx  = selectionEnd;
    
    if (cmd == 'r')
    {
        NSMutableString* subString = [NSMutableString stringWithCapacity:selection.length];
        NSString* ch = [NSString stringWithCharacters:&c length:1];
        for (int i = 0; i < selection.length; ++i)
        {
            NSInteger idx = selection.location + i;
            if (testNewLine([string characterAtIndex:idx]))
            {
                [subString appendString:[string substringWithRange:NSMakeRange(idx, 1)]];
            } else {
                [subString appendString:ch];
            }
        }
        
        [hijackedView insertText:subString replacementRange:selection];
        cmd = 0;
        count = 0;
        dontCheckSel = NO;
        return YES;
    }
    
    xv_set_string(string);
    xv_set_index(selectionEnd);
    
    BOOL handled = NO;
    
    // 1. Check number.
    if (c >= '0' && c <= '9')
    {
        if (count == 0)
        {
            if (c != '0') 
            { 
                count = c - '0';
                handled = YES;
            }
        } else {
            count = count * 10 + c - '0';
            handled = YES;
        }
    }
    
    if (handled == YES) {
        dontCheckSel = NO;
        return YES;
    }
    
    VimMode mode = NoSubMode;
    BOOL affectLines = isLineMode;
    if (count == 0) { count = 1; }
    
    // 2. Commands
    switch (c)
    {
        case 'p':
        {
            BOOL wholeLine;
            NSString* regStr = [[controller yankContent:&wholeLine] copy];
            
            [controller yank:string
                   withRange:selection
                   wholeLine:isLineMode];
            [hijackedView insertText:regStr
                    replacementRange:selection];
            
            [regStr release];
            
            mode = NormalMode;
            caretIdx = [hijackedView selectedRange].location + regStr.length;
        }
            break;
            
        case 'Y':
        case 'D':
        case 'C':
        case 'S':
        case 'X':
            selection = [self linewiseRange];
            affectLines = YES;
            // Fall through
        case 'y':
        case 'd':
        case 'x':
        case NSDeleteCharacter:
        case 'c':
        case 's':
            [controller yank:string
                   withRange:selection
                   wholeLine:affectLines];
            mode = NormalMode;
            if (c != 'y' && c != 'Y')
            {
                [hijackedView insertText:@""
                        replacementRange:selection];
                caretIdx = [hijackedView selectedRange].location;
                if (c == 'c' || c == 's' || c == 'C' || c == 'S')
                {
                    mode = InsertMode;
                }
            }
            break;
        case 'u':
        case 'U':
        case '~':
        {
            NSMutableString* subString = [NSMutableString stringWithString:[string substringWithRange:selection]];
            NSRange r = {0,1};
            
            if (c == '~') {
                for (; r.location < selection.length; ++r.location) 
                {
                    unichar c = [subString characterAtIndex:r.location];
                    if (c >= 'a' && c <= 'z')
                        c = c + 'A' - 'a';
                    else if (c >= 'A' && c <= 'Z')
                        c = c + 'a' - 'A';
                    [subString replaceCharactersInRange:r 
                                             withString:[NSString stringWithCharacters:&c 
                                                                                length:1]];
                }
            }
            
            [hijackedView insertText:(c == '~' ? subString : 
                                          (c == 'u' ? [subString lowercaseString] : 
                                                      [subString uppercaseString]))
                    replacementRange:selection]; 
            mode = NormalMode;
        }
        case XEsc:
            mode = NormalMode;
            break;
        case 'o':
        case 'O':
        {
            NSInteger temp = selectionStart;
            selectionStart = selectionEnd;
            selectionEnd   = temp;
        }
            break;
        case 'v':
            if (!isLineMode) {
                mode = NormalMode;
            } else {
                isLineMode = NO;
                [hijackedView setSelectedRange:[self characterwiseRange]];
            }
            break;
        case 'V':
            if (isLineMode) {
                mode = NormalMode;
            } else {
                isLineMode = YES;
                [hijackedView setSelectedRange:[self linewiseRange]];
            }
            break;
        case 'r':
            cmd = 'r';
            break;
            
        // TODO : Implement 'J'. 'F', 'f', ';', ',', 'g_', 'gg', 'G', text_object...
        
        case NSLeftArrowFunctionKey:
        case 'h':
        {
            NSInteger newIdx = selectionEnd - count;
            if (newIdx < 0) { newIdx = 0; }
            [self setNewSelectionEnd:newIdx];
        }
            break;
            
        case NSRightArrowFunctionKey:
        case 'l':
        {
            NSInteger newIdx = selectionEnd + count;
            if (newIdx > [string length] - 1) {
                newIdx = [string length] - 1;
            }
            [self setNewSelectionEnd:newIdx];
        }
            break;
            
        case NSDownArrowFunctionKey:
        case 'j': 
        {
            [hijackedView setSelectedRange:NSMakeRange(selectionEnd, 0)];
            [controller moveCaretDown:count];
            NSRange n = [hijackedView selectedRange];
            [self setNewSelectionEnd:n.location];
        }
            break;
            
        case NSUpArrowFunctionKey: 
        case 'k': 
        {
            [hijackedView setSelectedRange:NSMakeRange(selectionEnd, 0)];
            [controller moveCaretUp:count];
            NSRange n = [hijackedView selectedRange];
            [self setNewSelectionEnd:n.location];
        }
            break;
        case 'w':
        case 'W':
            [self setNewSelectionEnd:xv_w(count, c == 'W')];
            break;
        case 'b':
        case 'B':
            [self setNewSelectionEnd:xv_b(count, c == 'B')];
            break;
        case 'e':
        case 'E':
            [self setNewSelectionEnd:xv_e(count, c == 'E')];
            break;
        case '|': // Go to column
            [self setNewSelectionEnd:xv_columnToIndex(count)];
            break;
        case '%':
            [self setNewSelectionEnd:xv_percent()];
            break;
        case '$':
            [self setNewSelectionEnd:xv_dollar()];
            break;
        case '0':
#ifndef MAKE_0_AS_CARET
            [self setNewSelectionEnd:xv_0()];
            break;
#endif
        case '_':
        case '^':
            [self setNewSelectionEnd:xv_caret()];
            break;            
    }
    
    if (mode != NoSubMode) {
        NSRange idx = NSMakeRange(caretIdx, 0);
        [controller switchToMode:mode subMode:NoSubMode];
        [hijackedView setSelectedRange:idx];
        [hijackedView scrollRangeToVisible:idx];
    }
    
    count = 0;
    return YES;
}
@end

#endif
