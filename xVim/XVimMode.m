//
//  Created by Morris on 11-12-16.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#ifdef __LP64__

#import "XGlobal.h"
#import "XVimMode.h"
#import "XVimController.h"
#import "XTextViewBridge.h"
#import "vim.h"

@interface XVimModeHandler()
{
@private
    NSRect lastRect;
    NSRect scrollToRect;
}

-(void) doScrollRect;
@end


@implementation XVimModeHandler
-(id) initWithController:(XVimController*) c
{
    if (self = [super init]) {
        controller = c;
    }
    return self;
}
-(void) enterWith:(VimMode)submode{}
-(void) reset{}
-(BOOL) processKey:(unichar)k modifiers:(NSUInteger)f { return NO; }
-(BOOL) forceIgnoreKeymap { return NO; }
-(NSArray*) selectionChangedFrom:(NSArray*)oldRanges to:(NSArray*)newRanges { return newRanges; }
-(void) cmdlineTextChanged:(NSString*) newText{}
-(void) cmdlineCanceled:(NSTextView*) textView{}
-(void) cmdlineAccepted:(NSTextView*) textView{}

-(void) scrollViewRectToVisible:(NSRect)visibleRect
{
    lastRect = [[[controller bridge] targetView] visibleRect];
    scrollToRect = visibleRect;
    [self doScrollRect];
}

-(void) doScrollRect
{
    NSTextView* view = [[controller bridge] targetView];
    
    NSRect visibleRect = [view visibleRect];
    
    if (memcmp(&visibleRect, &lastRect, sizeof(NSRect)) != 0)
    {
        // The user scroll the text himsel no need to scroll again. 
        return;
    }
    
    NSInteger dX = visibleRect.origin.x - scrollToRect.origin.x;
    NSInteger dY = visibleRect.origin.y - scrollToRect.origin.y;
    
    if (dX == 0 && dY == 0) { return; }
    
    if (dX > SCROLL_STEP) { dX = SCROLL_STEP; } else if (dX < -SCROLL_STEP) { dX = -SCROLL_STEP; }
    if (dY > SCROLL_STEP) { dY = SCROLL_STEP; } else if (dY < -SCROLL_STEP) { dY = -SCROLL_STEP; }
    
    NSRect toRect = visibleRect;
    toRect.origin.x -= dX;
    toRect.origin.y -= dY;
    
    [view scrollRectToVisible:toRect];
    lastRect = [view visibleRect];
    
    if (memcmp(&lastRect, &scrollToRect, sizeof(NSRect)) != 0)
    {
        // We need to scroll again.
        [self performSelector:@selector(doScrollRect) withObject:nil afterDelay:.03f];
    }
}
@end




@interface XVimReplaceModeHandler()
{
    @private
        BOOL isSingleMode;
}
@end

@implementation XVimReplaceModeHandler

-(void) enterWith:(VimMode)submode
{
    isSingleMode = (submode == SingleReplaceMode);
}

-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags
{
    if ((key == XEsc && (flags & XImportantMask) == 0) || 
        (flags == XMaskControl && (key == 'c' || key == '['))
        )
    {
        NSTextView* view     = [[controller bridge] targetView];
        NSString*   string   = [[view textStorage] string];
        NSUInteger  index    = [view selectedRange].location;
        
        if (index > 0) {
            if (testNewLine([string characterAtIndex:index - 1]) == NO) {
                [view setSelectedRange:NSMakeRange(index - 1, 0)];
            }
        }
        
        [controller switchToMode:NormalMode];
        return YES;
    }
    
    if ((flags & XImportantMask) != 0) {
        // This may not be a visible character, let the NSTextView process it.
        return NO;
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
    
    range.length = 1;
    
    // Handle Single Mode
    if (isSingleMode)
    {
        if (range.location < [string length] && [string characterAtIndex:range.location] != '\n')
        {
            // Don't insert anything if we are at the bottom of an empty line.
            NSString* ch = [NSString stringWithCharacters:&key length:1];
            [hijackedView insertText:ch replacementRange:range];
            range.length = 0;
            [hijackedView setSelectedRange:range];
        }
        
        
        [controller switchToMode:NormalMode];
        return YES;
    }
    
    // Handle Replace Mode
    if (range.location > maxIndex || testNewLine([string characterAtIndex:range.location]))
    {
        // Let the textview process the key input, that is inserting the char.
        return NO;
    } else {
        
        NSString* ch = [NSString stringWithCharacters:&key length:1];
        [hijackedView insertText:ch replacementRange:range];
        return YES;
    }
}
@end

#endif
