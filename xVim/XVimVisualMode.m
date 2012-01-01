//
//  Created by Morris on 12-1-1.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XVimMode.h"
#import "XGlobal.h"
#import "XTextViewBridge.h"
#import "vim.h"

#ifdef ENABLE_VISUALMODE
@interface XVimVisualModeHandler()
{
@private
    BOOL isLineMode;
    BOOL dontSwitchMode;
    
    NSUInteger anchor; // The anchor and the current caret index makes up the selection range.
}
@end

@implementation XVimVisualModeHandler
-(void) reset 
{ 
    dontSwitchMode = NO; 
    anchor = 0;
}
-(void) enterWith:(VimMode)submode 
{ 
    isLineMode = (submode == VisualLineMode);
    
    NSTextView* view      = [[controller bridge] targetView];
    NSRange     selection = [view selectedRange];
    NSUInteger  length    = [[view string] length];
    if (selection.length == 0)
    {
        // The user press v/V to enter the visual mode.
        // Make at least one selection.
        // And mark the anchor.
        if (selection.location >= length)
        {
            if (selection.location == 0) {
                [controller switchToMode:NormalMode subMode:NoSubMode];
                return;
            }
            
            selection.location = length - 1;
        }
        
        anchor = selection.location;
        
        selection.length = 1;
        dontSwitchMode = YES;
        [view setSelectedRange:selection];
        dontSwitchMode = NO;
    } else {
        // The user use other means to enter visual mode,
        // We need to find out where the anchor is.
    }
}

-(NSArray*) selectionChangedFrom:(NSArray*)oldRanges to:(NSArray*)newRanges
{
    if (dontSwitchMode == NO)
    {
        if ([[newRanges objectAtIndex:0] rangeValue].length == 0)
        {
            [controller switchToMode:NormalMode subMode:NoSubMode];
        }
    }
    
    return newRanges;
}

-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags
{
    NSTextView* view = [[controller bridge] targetView];
    
    if (key == XEsc)
    {
        NSString*   string = [[view textStorage] string];
        NSUInteger  index  = [view selectedRange].location;
        
        if (index > 0) {
            if (testNewLine([string characterAtIndex:index - 1]) == NO) {
                [view setSelectedRange:NSMakeRange(index - 1, 0)];
            }
        }
        
        [controller switchToMode:NormalMode];
        return YES;
    }
    
    return YES;
}
@end
#else
@implementation XVimVisualModeHandler
@end
#endif
