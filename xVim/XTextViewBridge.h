//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

@class XVimController;

// XTextViewBridge is implemented in XGlobal.m
@interface XTextViewBridge : NSObject

-(XTextViewBridge*) initWithTextView:(NSTextView*) view;
-(void) dealloc;

-(NSTextView*)     targetView;
-(XVimController*) vimController;
-(void) processKeyEvent:(NSEvent*) event;
-(void) handleFakeKeyEvent:(NSEvent*) fakeEvent;

// ====================
// Subclass should override the methods below.

// Ask the textview to close any popup(e.g. a code-complete popup).
// Return YES if a popup is closed.
-(BOOL) closePopup;
// --------------------
@end


// ====================
// If a target textview doesn't have a delegate,
// we can use XTextViewDelegate and there's no need to hijack the delgate's method.
@interface XTextViewDelegate : NSObject <NSTextViewDelegate>
- (NSArray*) textView:(NSTextView*) view willChangeSelectionFromCharacterRanges:(NSArray*) old toCharacterRanges:(NSArray*) new;
@end
// --------------------
