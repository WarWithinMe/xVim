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

// ====================
// Subclass should override the methods below.

// This method is called by the XVimController.
// If a subclass does not call general_hj_keydown() to hijack the keydown,
// it must override this method.
-(void) handleFakeKeyEvent:(NSEvent*) fakeEvent;

// Ask the textview to close any popup(e.g. a code-complete popup).
// Return YES if a popup is closed.
-(BOOL) closePopup;

// Returns the current visible lines range. Starting with 0
-(NSRange) visibleParagraphRange;
// --------------------

@end
