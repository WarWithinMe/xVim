//
//  Created by Morris on 11-12-17.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

/*
 * vim.h defines the common functions that are used to handle vim commands.
 */

// =======================
// Use xv_set_string() and xv_set_index() to set the information,
// before calling other xv_xxxxx() functions !!!!!
void xv_set_string(NSString*);
void xv_set_index(NSInteger);


// =======================
// Return the location of the start of indentation on current line. '^'
NSInteger xv_caret(void);
// Return the beginning of line location. '0'
NSInteger xv_0(void);
// Return the end of the line. '$'
NSInteger xv_dollar(void);
// This one returns index of the CR
NSInteger xv_dollar_inc(void);
// Return the last non-blank of the line. 'g_'
NSInteger xv_g_(void);
// Return the index after procesing %
NSInteger xv_percent(void);
// Return the index of the character in the column of current line.
NSInteger xv_columnToIndex(NSUInteger column);
// Return the new location of the caret, after handler h,j,w,W,e,E,b,B
NSInteger xv_h(int repeatCount);
NSInteger xv_l(int repeatCount, BOOL stepForward);
NSInteger xv_b(int repeatCount, BOOL bigWord);
NSInteger xv_e(int repeatCount, BOOL bigWord);
NSInteger xv_w(int repeatCount, BOOL bigWord);
// xv_w_motion slightly differs from xv_w.
NSInteger xv_w_motion(int repeatCount, BOOL bigWord);
// There's no function by now for 'j' and 'k', 
// since NSTextView has a moveUp: and moveDown: method

// Unlike vim, this function won't ignore indent before the current character
// even if what is '{'
NSRange xv_current_block(int repeatCount, BOOL inclusive, char what, char other);
NSRange xv_current_word(int repeatCount, BOOL inclusive, BOOL fuzzy);
NSRange xv_current_quote(int repeatCount, BOOL inclusive, char what);
NSRange xv_current_tagblock(int repeatCount, BOOL inclusive);

// Find char in current line.
// Return the current index if nothing found.
// If inclusive is YES :
//   'fx' returns the index after 'x'
//   'Fx' returns the index before 'x'
NSInteger xv_findChar(int repeatCount, char command, unichar what, BOOL inclusive);

// =======================
BOOL testDigit(unichar ch);
BOOL testAlpha(unichar ch);
BOOL testDelimeter(unichar ch);
BOOL testWhiteSpace(unichar ch);
BOOL testNonAscii(unichar ch);
BOOL testNewLine(unichar ch);
BOOL testFuzzyWord(unichar ch);
