//
//  Created by Morris on 11-12-16.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import <Cocoa/Cocoa.h>

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
// When XVimController receives a key event, it will call this method,
// if return YES, the key event we be handled directly. Otherwise, the key
// event will be checked if it's part of a keymap.
-(BOOL) forceIgnoreKeymap;
@end







@interface XVimNormalModeHandler : XVimModeHandler
-(void) reset;
-(id) initWithController:(XVimController*) controller;
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags;
-(BOOL) isWaitingForMotion;
-(NSArray*) selectionChangedFrom:(NSArray*)oldRanges to:(NSArray*)newRanges;
-(BOOL) forceIgnoreKeymap;
@end


@interface XVimInsertModeHandler : XVimModeHandler
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags;
@end


@interface XVimReplaceModeHandler : XVimModeHandler
-(void) enterWith:(VimMode) submode;
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags;
@end


@interface XVimVisualModeHandler : XVimModeHandler
-(void) reset;
-(void) enterWith:(VimMode) submode;
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags;
-(BOOL) isLineMode;
-(NSInteger)selectionEnd;
-(void) setNewSelectionEnd:(NSInteger)end;
@end

@interface XVimExModeHandler : XVimModeHandler<NSTextFieldDelegate>
@property (retain) NSString* lastSearch;
@property (retain) NSString* lastCommand;
@property (assign) BOOL lastSearchWasForwards;

- (void)repeatSearch:(BOOL)reverse;
- (void)repeatCommand;
@end
