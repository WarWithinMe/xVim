//
//  Created by Morris on 11-12-17.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

/*
 * vim.h defines the common functions that are used to handle vim commands.
 */

// Return the location of the start of indentation on current line. '^'
NSUInteger mv_caret_handler_h(NSTextView* view);
NSUInteger mv_caret_handler(NSString* string, NSUInteger index);

// Return the beginning of line location. '0'
NSUInteger mv_0_handler_h(NSTextView* view);
NSUInteger mv_0_handler(NSString* string, NSUInteger index);

// Return the end of the line. '$'
NSUInteger mv_dollar_handler(NSTextView* view);
// This one returns index of the CR
NSUInteger mv_dollar_inc_handler(NSString* string, NSUInteger index);
// Return the last non-blank of the line. 'g_'
NSUInteger mv_g__handler(NSTextView* view);

// Return the index after procesing %
NSUInteger mv_percent_handler(NSTextView* view);

// Return the index of the character in the column of current line.
NSUInteger columnToIndex(NSTextView* view, NSUInteger column);

// Return the new location of the caret, after handler h,j,w,W,e,E,b,B
NSUInteger mv_h_handler(NSTextView* view, int repeatCount);
NSUInteger mv_l_handler(NSTextView* view, int repeatCount, BOOL stepForward);
NSUInteger mv_b_handler(NSTextView* view, int repeatCount, BOOL bigWord);
NSUInteger mv_e_handler_h(NSTextView* view, int repeatCount, BOOL bigWord);
NSUInteger mv_e_handler(NSString* string, NSUInteger index, int repeatCount, BOOL bigWord);
NSUInteger mv_w_handler_h(NSTextView* view, int repeatCount, BOOL bigWord);
NSUInteger mv_w_handler(NSString* string, NSUInteger index, int repeatCount, BOOL bigWord);
// mv_w_motion_handler slightly differs from mv_w_handler.
NSUInteger mv_w_motion_handler_h(NSTextView* view, int repeatCount, BOOL bigWord);
NSUInteger mv_w_motion_handler(NSString* string, NSUInteger index, int repeatCount, BOOL bigWord);
// There's no function by now for 'j' and 'k', 
// since NSTextView has a moveUp: and moveDown: method

// Unlike vim, this function won't ignore indent before the current character
// even if what is '{'
NSRange current_block(NSTextView* view, int repeatCount, BOOL inclusive, char what, char other);
NSRange current_word(NSTextView* view, int repeatCount, BOOL inclusive, BOOL fuzzy);
NSRange current_quote(NSTextView* view, int repeatCount, BOOL inclusive, char what);
NSRange current_tagblock(NSTextView* view, int repeatCount, BOOL inclusive);

BOOL testDigit(unichar ch);
BOOL testAlpha(unichar ch);
BOOL testDelimeter(unichar ch);
BOOL testWhiteSpace(unichar ch);
BOOL testNonAscii(unichar ch);
BOOL testNewLine(unichar ch);
BOOL testFuzzyWord(unichar ch);
