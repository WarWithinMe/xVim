//
//  Created by Morris on 11-12-17.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//


// ====================
// Switches:
#define VIM_KEYMAP_TIMEOUT 220
#define SCROLL_STEP        100  // Define how smooth will the textview scroll
                                // due to commands like 'zb' / 'zt'...
                                // The smaller the smoother and slower.
#define UNDERSCORE_IS_WORD      // If defined, "a_word" is consider a word,
                                // otherwise, it's consider three words.
// #define MAKE_0_AS_CARET      // If defined, 0 acts as ^
// #define ENABLE_VISUALMODE    // If defined, visual mode is enabled.
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
@interface NSText(xVim)
-(NSRange)    accessibilityCharacterRangeForLineNumber:(NSUInteger) lineNumber;
@end
// --------------------
