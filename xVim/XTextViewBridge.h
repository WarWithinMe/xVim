//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

/*
 * XTextViewBridge is used as an adapter between the XVimController 
 * and the subclass of NSTextView. Subclass XTextViewBridge to provide 
 * application specific implementations for to controller.
 *
 * XTextViewBridge is implemented in XGlobal.m
 *
 * Default implemtation of XTextViewBridge is for XCode only.
 */
@class XVimController;

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

// When the editor enters a template code, the user can 'tab' to select some
// text. In this situation, this method should return YES, and we don't enter 
// visual mode, since the user just want to type in something.
-(BOOL) ignoreString:(NSString*) string selection:(NSRange) range;
// --------------------
@end


/*
 * If a target textview doesn't have a delegate,
 * we can use XTextViewDelegate and there's no need to hijack the delgate's method.
 */
@interface XTextViewDelegate : NSObject <NSTextViewDelegate>
- (NSArray*) textView:(NSTextView*) view willChangeSelectionFromCharacterRanges:(NSArray*) old toCharacterRanges:(NSArray*) new;
- (void)textViewDidChangeSelection:(NSNotification*) aNotification;
@end
