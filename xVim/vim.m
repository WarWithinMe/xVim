//
//  Created by Morris on 11-12-17.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "vim.h"


BOOL testDigit(unichar ch);
BOOL testAlpha(unichar ch);
BOOL testDelimeter(unichar ch);
BOOL testWhiteSpace(unichar ch);
BOOL testNonAscii(unichar ch);
BOOL testNewLine(unichar ch);
BOOL testFuzzyWord(unichar ch);


BOOL testDigit(unichar ch) { return ch >= '0' && ch <= '9'; }
BOOL testWhiteSpace(unichar ch) { return ch == ' ' || ch == '\t'; }
BOOL testNewLine(unichar ch) { return (ch >= 0xA && ch <= 0xD) || ch == 0x85; }
BOOL testNonAscii(unichar ch) { return ch > 128; }
BOOL testAlpha(unichar ch) { 
    return (ch >= 'A' && ch <= 'Z') ||
    (ch >= 'a' && ch <= 'z') || ch == '_';
}
BOOL testDelimeter(unichar ch) {
    return (ch >= '!' && ch <= '/') ||
    (ch >= ':' && ch <= '@') ||
    (ch >= '[' && ch <= '`' && ch != '_') ||
    (ch >= '{' && ch <= '~');
}
BOOL testFuzzyWord(unichar ch) {
    return (!testWhiteSpace(ch)) && (!testNewLine(ch));
}


NSUInteger mv_caret_handler(NSTextView* view)
{
    NSString* string = [[view textStorage] string];
    NSUInteger index = [view selectedRange].location;
    NSUInteger resultIndex  = index;
    NSUInteger seekingIndex = index;
    
    while (seekingIndex > 0) {
        unichar ch = [string characterAtIndex:seekingIndex-1];
        if (testNewLine(ch)) {
            break;
        } else if (ch != '\t' && ch != ' ') {
            resultIndex = seekingIndex - 1;
        }
        --seekingIndex;
    }
    
    if (resultIndex == index) {
        NSUInteger maxIndex = [string length] - 1;
        while (resultIndex < maxIndex) {
            unichar ch = [string characterAtIndex:resultIndex];
            if (testNewLine(ch) || testWhiteSpace(ch) == NO) {
                break;
            }
            ++resultIndex;
        }
    }
    
    return resultIndex;
}

NSUInteger mv_0_handler(NSTextView* view)
{
    NSString* string = [[view textStorage] string];
    NSUInteger index = [view selectedRange].location;
    
    while (index > 0) {
        if (testNewLine([string characterAtIndex:index-1])) {
            break;
        }
        --index;
    }
    return index;
}

NSUInteger mv_dollar_handler(NSTextView* view)
{
    NSString* string    = [[view textStorage] string];
    NSUInteger index    = [view selectedRange].location;
    NSUInteger maxIndex = [string length] - 1;
    
    while (index < maxIndex) {
        if (testNewLine([string characterAtIndex:index+1])) {
            break;
        }
        ++index;
    }
    return index;
}

@interface NSTextView(xVim)
-(NSRange) accessibilityCharacterRangeForLineNumber:(NSUInteger) lineNumber;
@end
void textview_goto_line(NSTextView* view, NSInteger lineNumber, BOOL ensureVisible)
{
    NSRange range = {0,0};
    if (lineNumber > 0) {
        range = [view accessibilityCharacterRangeForLineNumber:lineNumber];
        range.length = 0;
        if (range.location == 0 && lineNumber != 0) {
            // The lineNumber is not valid,
            // We move it to the last line.
            lineNumber = -1;
        }
    }
    
    if (lineNumber == -1) {
        // Goto last line
        NSString* string = [[view textStorage] string];
        NSUInteger maxIndex = [string length];
        if (testNewLine([string characterAtIndex:maxIndex - 1]) == NO)
            --maxIndex;
        
        range.location = maxIndex;
    }
    
    [view setSelectedRange:range];
    range.location = mv_caret_handler(view);
    [view setSelectedRange:range];
    if (ensureVisible) { [view scrollRangeToVisible:range]; }
}

NSUInteger mv_h_handler(NSTextView* view, int repeatCount)
{
    NSUInteger index = [view selectedRange].location;
    NSString* string = [[view textStorage] string];
    
    for (int i = 0; i < repeatCount; ++i)
    {
        if (index == 0) { 
            return 0;
        } else if (index == 1) {
            return 0;
        }
        
        // When moveing left and right, we should never place the caret
        // before the CR, unless the line is a blank line.
        
        --index;
        if ([string characterAtIndex:index] == '\n') {
            if ([string characterAtIndex:index - 1] != '\n') {
                --index;
            }
        }
    }
    
    return index;
}

NSUInteger mv_l_handler(NSTextView* view, int repeatCount)
{
    NSString* string    = [[view textStorage] string];
    NSUInteger index    = [view selectedRange].location;
    NSUInteger maxIndex = [string length] - 1;
    
    for (int i = 0; i < repeatCount; ++i) {
        if (index >= maxIndex) {
            return index;
        }
        
        ++index;
        if ([string characterAtIndex:index] == '\n') {
            ++index;
        }
    }
    return index;
}

typedef BOOL (*testAscii) (unichar);
testAscii testForChar(unichar ch);
testAscii testForChar(unichar ch)
{
    if (testDigit(ch)) return testDigit;
    if (testAlpha(ch)) return testAlpha;
    if (testWhiteSpace(ch)) return testWhiteSpace;
    if (testNewLine(ch)) return testNewLine;
    if (testNonAscii(ch)) return testNonAscii;
    return testDelimeter;
}

NSUInteger mv_w_handler(NSTextView* view, int repeatCount, BOOL bigWord)
{
    NSUInteger      index    = [view selectedRange].location;
    NSString*       string   = [[view textStorage] string];
    NSUInteger      maxIndex = [string length] - 1;
    
    for (int i = 0; i < repeatCount && index < maxIndex; ++i)
    {
        unichar ch = [string characterAtIndex:index];
        
        // There are three situations that the ch is a newLine(CR):
        // 1. (CR)|(CR) // We are between two CR.
        // 2. ABC|(CR)  // We are at the end of the line, because the 
        //                 user place the caret with mouse.
        // For both case, we move the caret forward and consider we are at the
        // beginning of the next word.
        
        BOOL blankLine = NO;
        if (testNewLine(ch)) {
            ++index;
            blankLine = YES;
        } else {
            testAscii test = bigWord ? testFuzzyWord : testForChar(ch);
            do {
                ++index;
            } while (index < maxIndex && test([string characterAtIndex:index]));
        }
        
        while (index < maxIndex)
        {
            ch = [string characterAtIndex:index];
            if (blankLine == NO && testNewLine(ch)) {
                blankLine = YES;
            } else if (testWhiteSpace(ch)) {
                blankLine = NO;
            } else {
                break;
            }
            ++index;
        }
    }
    
    if (index == maxIndex && testNewLine([string characterAtIndex:index]))
    {
        // We are at the end of the text, and the end is a new line.
        // So place the caret behind the new line.
        // FIXME: If the end of the text is like : ABC|(CR)(CR)
        // After 'w', it becomes : ABC|(CR)(CR) -> ABC(CR)(CR)|
        // But we expect this    : ABC|(CR)(CR) -> ABC(CR)|(CR)
        ++index;
    }
    
    return index;
}

NSUInteger mv_b_handler(NSTextView* view, int repeatCount, BOOL bigWord)
{
    // 'b' If we are not at the beginning of a word, go to the beginning of it.
    // Otherwise go to the beginning of the word before it.
    NSUInteger index  = [view selectedRange].location;
    NSString*  string = [[view textStorage] string];
    NSUInteger maxI   = [string length] - 1;
    if (index >= maxI) { index = maxI; }
    
    for (int i = 0; i < repeatCount && index > 0; ++i)
    {
        unichar ch = [string characterAtIndex:index];

        // There are three situations that the ch is a newLine(CR):
        // 1. (CR)|(CR) // We are between two CR.
        // 2. ABC|(CR)  // We are at the end of the line, because the 
        //                 user place the caret with mouse.
        // For s1, we move the caret backward once.
        if (testNewLine(ch) && testNewLine([string characterAtIndex:index - 1])) {
            --index;
            if (index == 0) { return 0; }
        }

        BOOL      blankLine = NO;
        testAscii test      = bigWord ? testFuzzyWord : testForChar(ch);
        BOOL      inWord    = test([string characterAtIndex:index - 1]);

        if (inWord == NO || testWhiteSpace(ch))
        {
            // We are at the beginning of a word, or in the
            // middle of whitespaces. Move to the end of the
            // word before. Blank line is consider a word.
            while (index > 0)
            {
                --index;
                ch = [string characterAtIndex:index];
                if (testWhiteSpace(ch)) {
                    blankLine = NO;
                } else if (testNewLine(ch)) {
                    if (blankLine == YES) {
                        ++index;
                        break;
                    }
                    blankLine = YES;
                } else {
                    break;
                }
            }
        }

        // Now ch is the character after the caret.
        if (index == 0) {
            return 0;
        } else if (testNewLine(ch) == NO)
        {
            test = bigWord ? testFuzzyWord : testForChar(ch);
            while (index > 0) {
                ch = [string characterAtIndex:index - 1];
                if (test(ch) == NO) {
                    break;
                }
                --index;
            }
        }
    }
    
    return index;
}

NSUInteger mv_e_handler(NSTextView* view, int repeatCount, BOOL bigWord)
{
    // 'e' If we are not at the end of a word, go to the end of it.
    // Otherwise go to the end of the word after it.
    
    // Test in MacVim, when dealing with 'e', 
    // the blank line is not consider a word.
    // So whitespace and newline are totally ingored.
    
    NSUInteger index    = [view selectedRange].location;
    NSString*  string   = [[view textStorage] string];
    NSUInteger maxIndex = [string length] - 1;
    
    for (int i = 0; i < repeatCount && index < maxIndex; ++i)
    {
        unichar   ch      = [string characterAtIndex:index];
        testAscii test    = bigWord ? testFuzzyWord : testForChar(ch);
        BOOL      inWord  = test([string characterAtIndex:index + 1]);
        
        if (inWord == NO || testWhiteSpace(ch) || testNewLine(ch))
        {
            while (index < maxIndex)
            {
                ++index;
                ch = [string characterAtIndex:index];
                if (testWhiteSpace(ch) || testNewLine(ch)) {
                    continue;
                } else {
                    break;
                }
            }
        }
        
        // Now ch is the character after the caret.
        if (index < maxIndex)
        {
            test = bigWord ? testFuzzyWord : testForChar(ch);
            while (index < maxIndex) {
                ch = [string characterAtIndex:index + 1];
                if (test(ch) == NO) {
                    break;
                }
                ++index;
            }
        }
        
        if (index == maxIndex && testNewLine([string characterAtIndex:index])) {
            return maxIndex + 1;
        }
    }
    
    return index;
}
