//
//  Created by Morris on 12-1-17.
//  Copyright (c) 2012年 http://warwithime.com . All rights reserved.
//

#import "XVimMode.h"
#import "XTextViewBridge.h"
#import "vim.h"

@implementation XVimInsertModeHandler
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags
{
    // Ctrl + u : delete line before // a CR/LF is consider a line.
    // Ctrl + w : delete word before // a CR/LF is consider a word.
    // Ctrl + h : backspace
    // Ctrl + c : command mode
    // Ctrl + [ : command mode
    BOOL performEsc = FALSE;
    
    if (flags == XMaskControl)
    {
        switch (key) {
            case 'c':
            case '[':
                performEsc = YES;
                break;
            case 'h':
            {
                unichar  ch = NSBackspaceCharacter;
                NSString* c = [NSString stringWithCharacters:&ch length:1];
                NSEvent*  e = [NSEvent keyEventWithType:NSKeyDown 
                                               location:NSMakePoint(0, 0)
                                          modifierFlags:0
                                              timestamp:0
                                           windowNumber:0
                                                context:nil
                                             characters:c
                            charactersIgnoringModifiers:c
                                              isARepeat:NO 
                                                keyCode:0];
                [[controller bridge] handleFakeKeyEvent:e];
                return YES;
            }
                
            case 'u':
            case 'w':
            {
                NSTextView* view   = [[controller bridge] targetView];
                NSUInteger  delIdx = key == 'u' ? mv_0_handler(view) : mv_b_handler(view, 1, NO);
                [view insertText:@"" 
                replacementRange:NSMakeRange(delIdx, [view selectedRange].location - delIdx)];
            }
                break;
                
                // case 'e': // Ctrl + e : insert from below
                // case 'y': // Ctrl + y : insert from above
                break;
        }
        
    } else if ((flags & XImportantMask) == 0)
    {
        if (key == XEsc) {
            performEsc = YES;
        }
    }
    
    if (performEsc)
    {
        XTextViewBridge* bridge = [controller bridge];
        if ([bridge closePopup] == NO)
        {
            // There's no popup, so we now switch to Normal Mode.
            NSTextView* view     = [bridge targetView];
            NSString*   string   = [[view textStorage] string];
            NSUInteger  index    = [view selectedRange].location;
            
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

