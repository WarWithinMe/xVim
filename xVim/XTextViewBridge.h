//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

@protocol XCmdlineDelegate 
- (void) cmdlineTextDidChange:(NSString*) newStr;
- (void) cmdlineCanceled;
- (void) cmdlineAccepted:(NSString*) controlStr;
@end

@interface XCmdlineTextField : NSTextField<NSTextFieldDelegate>

- (id) initWithFrame:(NSRect) frame;

// The XCmdlineTextField will never have focus by default.
// Call this method to make it process key input.
// Whenever the cmdline has finished editing (clicking outside of it,
// pressing enter or esc), the textfield's delegate is reset to nil.
// And its focus should be removed by the delegate. 
- (void) setFocus:(id<XCmdlineDelegate>) delegate withText:(NSString*) str;
// Call this method to notify the textfield its focus has been removed.
- (void) focusRemoved;
- (BOOL) hasFocus;
- (void) setStringValue:(NSString*) str;
- (void) setTitle:(NSString*) title;
@end

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

@property (retain) XCmdlineTextField* cmdline;

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

// When the editor enters a code template, the user can 'tab' to select some
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
