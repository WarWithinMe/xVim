//
//  Created by Morris on 11-12-16.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#include "XVimController.h"
#include "XGlobal.h"

@class XVimController;


@interface XVimModeHandler : NSObject
{
    @protected
        XVimController* controller;
}
-(id) initWithController:(XVimController*) controller;
// Scroll's the target textview with animation
-(void) scrollViewRectToVisible:(NSRect)visibleRect;
// Called before entering the mode.
-(void) enterWith:(VimMode) submode;
// Called before leaving the mode.
-(void) reset;
// Return YES if the key is processed, otherwise, return NO.
// The variable key is not the keycode of the keyboard.
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags;
// This method is used to validate the selection, aslo used to switch between
// visual mode and other modes.
-(NSArray*) selectionChangedFrom:(NSArray*)oldRanges to:(NSArray*)newRanges;
@end


@interface XVimNormalModeHandler : XVimModeHandler
-(void) reset;
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags;
-(NSArray*) selectionChangedFrom:(NSArray*)oldRanges to:(NSArray*)newRanges;
@end


@interface XVimInsertModeHandler : XVimModeHandler
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags;
@end


@interface XVimReplaceModeHandler : XVimModeHandler
-(void) enterWith:(VimMode) submode;
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags;
@end


@interface XVimVisualModeHandler : XVimModeHandler
#ifdef ENABLE_VISUALMODE
-(void) reset;
-(void) enterWith:(VimMode) submode;
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags;
#endif
@end

@interface XVimExModeHandler : XVimModeHandler
@end
