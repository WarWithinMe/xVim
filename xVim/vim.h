//
//  Created by Morris on 11-12-17.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

// Return the location of the start of indentation on current line. '^'
NSUInteger mv_caret_handler(NSTextView* view);

// Return the beginning of line location. '0'
NSUInteger mv_0_handler(NSTextView* view);

// Return the end of the line. '$'
NSUInteger mv_dollar_handler(NSTextView* view);

// This makes the caret to position after the indentation of line (lineNumber).
// This function does not check if the lineNumber is valid.
// lineNumber is 0-base. -1 means goto the last line
void textview_goto_line(NSTextView* view, NSInteger lineNumber, BOOL ensureVisible);

// Return the new location of the caret, after handler h,j,w,W,e,E,b,B
NSUInteger mv_h_handler(NSTextView* view, int repeatCount);
NSUInteger mv_l_handler(NSTextView* view, int repeatCount);
NSUInteger mv_w_handler(NSTextView* view, int repeatCount, BOOL bigWord);
NSUInteger mv_e_handler(NSTextView* view, int repeatCount, BOOL bigWord);
NSUInteger mv_b_handler(NSTextView* view, int repeatCount, BOOL bigWord);
// There's no function by now for 'j' and 'k', 
// since NSTextView has a moveUp: and moveDown: method

BOOL testDigit(unichar ch);
BOOL testAlpha(unichar ch);
BOOL testDelimeter(unichar ch);
BOOL testWhiteSpace(unichar ch);
BOOL testNonAscii(unichar ch);
BOOL testNewLine(unichar ch);
BOOL testFuzzyWord(unichar ch);
