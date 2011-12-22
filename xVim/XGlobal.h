//
//  Created by Morris on 11-12-17.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//


// ====================
// Switches:
#define SUPPORTED_APP_COUNT 2
#define VIM_KEYMAP_TIMEOUT 220
// #define MAKE_0_AS_CARET      // If defined, 0 acts as ^
// --------------------


#ifdef DEBUG
#   define DLog(fmt, ...) NSLog(fmt, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif


// How xVim works:
// 1.In the entry point of this bundle (defined as XVimPlugin in XGlobal.m),
//   we hijack the application's NSTextView class or possibly its subclass,
//   by calling hijack method of the subclass of XTextViewBridge.
// 2.Subclass of XTextViewBridge can ask XTextViewBridge to get the XVimController,
//   which is used to handle every key input.


// ====================
// Hidden API
@interface NSTextView(xVim)
-(void)       _scrollRangeToVisible:(NSRange) range forceCenter:(BOOL) flag;
@end
@interface NSText(xVim)
-(NSUInteger) accessibilityInsertionPointLineNumber;
-(NSRange)    accessibilityCharacterRangeForLineNumber:(NSUInteger) lineNumber;
@end
// --------------------
