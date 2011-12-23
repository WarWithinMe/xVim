//
//  Created by Morris on 11-12-16.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

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
-(void) enter;
// Called before leaving the mode.
-(void) reset;
// Return YES if the key is processed, otherwise, return NO.
// The variable key is not the keycode of the keyboard.
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags;
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
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags;
@end

@interface XVimSReplaceModeHandler : XVimModeHandler
-(BOOL) processKey:(unichar)key modifiers:(NSUInteger)flags;
@end


@interface XVimVisualModeHandler : XVimModeHandler
@end
@interface XVimExModeHandler : XVimModeHandler
@end
