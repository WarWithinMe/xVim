//
//  Created by Morris on 11-12-17.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "vim.h"
#import "NSStringHelper.h"

BOOL testDigit(unichar ch) { return ch >= '0' && ch <= '9'; }
BOOL testWhiteSpace(unichar ch) { return ch == ' ' || ch == '\t'; }
BOOL testNewLine(unichar ch) { return (ch >= 0xA && ch <= 0xD) || ch == 0x85; }
BOOL testNonAscii(unichar ch) { return ch > 128; }
BOOL testAlpha(unichar ch) { 
    return (ch >= 'A' && ch <= 'Z') ||
    (ch >= 'a' && ch <= 'z') 
#ifdef UNDERSCORE_IS_WORD
    || ch == '_'
#endif
    ;
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

NSUInteger mv_dollar_handler(NSTextView* view)
{
    NSString*  string = [view string];
    NSUInteger strLen = [string length];
    NSUInteger index  = [view selectedRange].location;
    
    NSStringHelper helper;
    initNSStringHelper(&helper, string, strLen);
    
    while (index < strLen)
    {
        if (testNewLine(characterAtIndex(&helper, index)))
        {
            break;
        }
        ++index;
    }
    return index;
}

NSUInteger mv_dollar_inc_handler(NSTextView* view)
{
    NSString*  string = [view string];
    NSUInteger strLen = [string length];
    NSUInteger index  = [view selectedRange].location;
    
    NSStringHelper helper;
    initNSStringHelper(&helper, string, strLen);
    
    while (index < strLen)
    {
        if (testNewLine(characterAtIndex(&helper, index)))
        {
            ++index;
            break;
        }
        ++index;
    }
    return index;
}

NSUInteger mv_g__handler(NSTextView* view)
{
    NSUInteger index  = mv_dollar_handler(view);
    NSString*  string = [view string];
    while (index > 0)
    {
        --index;
        if (!testWhiteSpace([string characterAtIndex:index]))
            break;
    }
    return index;
}

NSUInteger mv_caret_handler(NSTextView* view)
{
    NSString*  string       = [view string];
    NSUInteger index        = [view selectedRange].location;
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










//YCursor YModeCommand::percentCommand(const YMotionArgs &args, CmdState *state, MotionStick* ms )
//{
//    if ( ms != NULL ) *ms = MotionNoStick;
//    *state = CmdOk;
//    YCursor cursorBefore = args.view->viewCursor().buffer()  , newCursorPos;
//    QString line = args.view->buffer()->textline(cursorBefore.line());
//    // Characters on which the cursor will jump
//    QString toMatch("\\(\\[\\{") , correspondingMatch("\\)\\]\\}");
//    
//    // Find the next opening or closing character on the current line
//    int pos = line.indexOf(QRegExp("["+toMatch+correspondingMatch+"]"), cursorBefore.column());
//    
//    // If a supported char is found, switch to the corresponding one
//    if(pos>=0)
//    {
//        newCursorPos.setLineColumn(cursorBefore.line(), pos);
//        int nOpen=0 , nClose=0;
//        int maxLine , l = newCursorPos.line();  
//        int direction; // Match forward or backwards ?
//        QChar ch = line[newCursorPos.column()] , correspondingCh;
//        // If it is an opening character (like (, [ ...), go to the closing character
//        if(toMatch.indexOf(ch) != -1)
//        {
//            correspondingCh = correspondingMatch.at(toMatch.indexOf(ch));
//            direction = 1; //search forward
//            maxLine =  args.view->buffer()->lineCount();
//        } else if (correspondingMatch.indexOf(ch) != -1) 
//        {
//            correspondingCh = toMatch.at(correspondingMatch.indexOf(ch));
//            direction = -1; // search backwards
//            maxLine = -1;
//        }
//        int c = newCursorPos.column();
//        // Find the correponding char
//        while(l != maxLine)
//        {
//            while(c<=line.length() && c>=0)
//            {
//                if(ch == line[c]) nOpen++;
//                else if(correspondingCh == line[c]) {
//                    nClose++;
//                    if (nOpen == nClose) {
//                        newCursorPos.setLineColumn(l, c);
//                        return newCursorPos;
//                    }
//                }
//                c += direction;
//            }
//            l += direction;
//            if(l == maxLine) break;
//            line = args.view->buffer()->textline(l);
//            if(direction == 1) c = 0;   else c = line.length()-1;
//        }
//    }
//    return cursorBefore;
//}

NSUInteger mv_percent_handler(NSTextView* view)
{
    NSString*  string    = [view string];
    NSUInteger idxBefore = [view selectedRange].location;

    // Find the first brace in this line that is after the caret.
    NSCharacterSet* set  = [NSCharacterSet characterSetWithCharactersInString:@"([{)]}"];
    NSRange    range     = NSMakeRange(idxBefore, mv_dollar_handler(view)-idxBefore);
    NSUInteger idxNew    = [string rangeOfCharacterFromSet:set 
                                                   options:0 
                                                     range:range].location;
    if (idxNew != NSNotFound)
    {
        // Found brace, switch to the corresponding one.
        unichar correspondingCh = 0;
        unichar ch     = [string characterAtIndex:idxNew];
        int     dir    = 1;
        switch (ch) {
            case '(': correspondingCh = ')'; break;
            case '[': correspondingCh = ']'; break;
            case '{': correspondingCh = '}'; break;
            case ')': correspondingCh = '('; dir = -1; break;
            case ']': correspondingCh = '['; dir = -1; break;
            case '}': correspondingCh = '{'; dir = -1; break;
        }
        
        NSUInteger maxIdx = [string length] - 1;
        int nOpen  = 0;
        int nClose = 0;
        
        NSStringHelper helper;
        NSStringHelper* h = &helper;
        dir == 1 ? initNSStringHelper(h, string, maxIdx+1) : initNSStringHelperBackward(h, string, maxIdx+1);
        
        while (idxNew <= maxIdx && idxNew > 0)
        {
            unichar c = characterAtIndex(h, idxNew);
            if (c == ch) {
                ++nOpen;
            } else if (c == correspondingCh) {
                ++nClose;
                if (nOpen == nClose)
                {
                    return idxNew;
                }
            }
            idxNew += dir;
        }
    }
    
    return idxBefore;
}

NSUInteger mv_0_handler(NSTextView* view)
{
    NSString*  string = [view string];
    NSUInteger index  = [view selectedRange].location;
    
    while (index > 0)
    {
        if (testNewLine([string characterAtIndex:index-1])) { break; }
        --index;
    }
    return index;
}

NSUInteger mv_h_handler(NSTextView* view, int repeatCount)
{
    NSUInteger index  = [view selectedRange].location;
    NSString*  string = [view string];
    
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

NSUInteger mv_l_handler(NSTextView* view, int repeatCount, BOOL stepForward)
{
    NSString*  string   = [view string];
    NSUInteger index    = [view selectedRange].location;
    NSUInteger maxIndex = [string length] - 1;
    
    for (int i = 0; i < repeatCount; ++i) {
        if (index >= maxIndex) {
            return index;
        }
        
        ++index;
        if ([string characterAtIndex:index] == '\n' && stepForward) {
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
    NSUInteger index    = [view selectedRange].location;
    NSString*  string   = [view string];
    NSUInteger maxIndex = [string length] - 1;
    
    if (index == maxIndex) { return maxIndex + 1; }
    
    for (int i = 0; i < repeatCount && index < maxIndex; ++i)
    {
        unichar ch = [string characterAtIndex:index];
        
        // If this the ch is a newLine(CR): e.g. ABC|(CR)
        // We move the caret forward and consider we are at the
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
    
    if (index == maxIndex && 
        testNewLine([string characterAtIndex:index]) &&
        !testNewLine([string characterAtIndex:index - 1]))
    {
        ++index;
    }
    
    return index;
}

NSUInteger mv_w_motion_handler(NSTextView* view, int repeatCount, BOOL bigWord)
{
    // Reduce index if we are at the beginning indentation of another line.
    NSUInteger oldIdx  = [view selectedRange].location;
    NSUInteger newIdx  = mv_w_handler(view, repeatCount, bigWord);
    NSUInteger testIdx = newIdx - 1;
    NSString*  string  = [view string];
    
    while (testIdx > oldIdx)
    {
        unichar ch = [string characterAtIndex:testIdx];
        if (testWhiteSpace(ch)) {
            --testIdx;
            continue;
        } else if (!testNewLine(ch))
        {
            // We can't reach the line before, the newIdx should not change.
            return newIdx;
        }
        break;
    }
    
    return oldIdx == testIdx ? newIdx : testIdx;
}

NSUInteger mv_b_handler(NSTextView* view, int repeatCount, BOOL bigWord)
{
    // 'b' If we are not at the beginning of a word, go to the beginning of it.
    // Otherwise go to the beginning of the word before it.
    NSUInteger index  = [view selectedRange].location;
    NSString*  string = [view string];
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
    NSString*  string   = [view string];
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

NSRange motion_word_bound(NSTextView* view, BOOL fuzzy, BOOL trailing)
{
    NSString*  string   = [view string];
    NSUInteger index    = [view selectedRange].location;
    NSUInteger maxIndex = [string length] - 1;
    
    if (index > maxIndex) { return NSMakeRange(0, 0); }
    
    unichar   ch   = [string characterAtIndex:index];
    testAscii test = testWhiteSpace(ch) ? testWhiteSpace : (fuzzy ? testFuzzyWord : testForChar(ch));
    
    NSUInteger begin = index;
    
    while (begin > 0)
    {
        if (test([string characterAtIndex:begin - 1]) == NO) { break; }
        --begin;
    }
    
    NSUInteger end = index;
    while (end < maxIndex) {
        if (test([string characterAtIndex:end + 1]) == NO) { break; }
        ++end;
    }
    
    if (trailing) {
        while (end < maxIndex) {
            if (testWhiteSpace([string characterAtIndex:end + 1]) == NO) { break; }
            ++end;
        }
    }
    
    return NSMakeRange(begin, end - begin + 1);
}

NSUInteger columnToIndex(NSTextView* view, NSUInteger column)
{
    NSUInteger index  = [view selectedRange].location;
    NSString*  string = [view string];
    NSUInteger strLen = [string length];
    
    if (index >= strLen) { return index; }
    
    NSStringHelper helper;
    initNSStringHelperBackward(&helper, string, strLen);
    
    NSInteger lastLineEnd = index;
    for (; lastLineEnd >= 0; --lastLineEnd)
    {
        unichar ch = characterAtIndex(&helper, lastLineEnd);
        if (testNewLine(ch)) { break; }
    }
    
    // If we are at a blank line, return the current index.
    if (lastLineEnd == index &&
        (index == 0 || testNewLine(characterAtIndex(&helper, index - 1)) )) { return index; }
    
    NSInteger thisLineEnd = index + 1;
    for (; thisLineEnd < strLen; ++thisLineEnd) {
        unichar ch = characterAtIndex(&helper, thisLineEnd);
        if (testNewLine(ch)) { break; }
    }
    
    index = lastLineEnd + column;
    return index < thisLineEnd ? index : thisLineEnd;
}

