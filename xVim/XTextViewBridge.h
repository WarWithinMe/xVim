//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

@interface XCmdlineTextField : NSTextField
-(BOOL) resignFirstResponder;
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

@interface XTextViewBridge : NSObject<NSTextFieldDelegate>

-(XTextViewBridge*) initWithTextView:(NSTextView*) view;
-(void) dealloc;

-(NSTextView*)     targetView;
-(XVimController*) vimController;
-(void) processKeyEvent:(NSEvent*) event;
-(void) handleFakeKeyEvent:(NSEvent*) fakeEvent;

// XTextViewBridge use NSTextField as cmdline.
// The NSTextField's delegate will be replaced by this class.
-(void) setCmdlineTextField:(XCmdlineTextField*) tf;
-(XCmdlineTextField*) cmdlineTextField;

-(void)controlTextDidChange:(NSNotification*)obj;
-(BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command;

// ====================
// Subclass should override the methods below.

// Ask the textview to close any popup(e.g. a code-complete popup).
// Return YES if a popup is closed.
-(BOOL) closePopup;

// When the editor enters a code template, the user can 'tab' to select some
// text. In this situation, this method should return YES, and we don't enter 
// visual mode, since the user just want to type in something.
-(BOOL) ignoreString:(NSString*) string selection:(NSRange) range;

// Called by the controller when Vimmode is changed.
// Override this method to display the title, e.g. "NORMAL INSERT REPLACE"
-(void) setModeTitle:(NSString*) modeTitle;

// Called by XVimModeHandler to set string in the command line.
// For example : 'd5d'. This should not trigger notifications.
-(void) setCmdString:(NSString*) cmd;

// Called by XVimModeHanlder after entering Ex/Search mode, so that the
// cmdline textfield grabs the keyboard inputs.
-(void) setFocusToCmdline;
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
