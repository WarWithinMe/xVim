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

NSUInteger mv_dollar_inc_handler(NSString* string, NSUInteger index)
{
    NSUInteger strLen = [string length];
    
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

NSUInteger mv_caret_handler_h(NSTextView* view)
{
    return mv_caret_handler([view string], [view selectedRange].location);
}
NSUInteger mv_caret_handler(NSString* string, NSUInteger index)
{
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

NSUInteger mv_0_handler_h(NSTextView* view) {
    return mv_0_handler([view string], [view selectedRange].location);
}
NSUInteger mv_0_handler(NSString* string, NSUInteger index)
{    
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

NSUInteger mv_w_handler_h(NSTextView* view, int repeatCount, BOOL bigWord)
{
    return mv_w_handler([view string], [view selectedRange].location, repeatCount, bigWord);
}
NSUInteger mv_w_handler(NSString* string, NSUInteger index, int repeatCount, BOOL bigWord)
{
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

NSUInteger mv_w_motion_handler_h(NSTextView* view, int repeatCount, BOOL bigWord)
{
    return mv_w_motion_handler([view string], [view selectedRange].location, repeatCount, bigWord);
}
NSUInteger mv_w_motion_handler(NSString* string, NSUInteger oldIdx, int repeatCount, BOOL bigWord)
{
    // Reduce index if we are at the beginning indentation of another line.
    NSUInteger newIdx  = mv_w_handler(string, oldIdx, repeatCount, bigWord);
    NSUInteger testIdx = newIdx - 1;
    
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

NSUInteger mv_e_handler_h(NSTextView* view, int repeatCount, BOOL bigWord)
{
    return mv_e_handler([view string], [view selectedRange].location, repeatCount, bigWord);
}
NSUInteger mv_e_handler(NSString* string, NSUInteger index, int repeatCount, BOOL bigWord)
{
    // 'e' If we are not at the end of a word, go to the end of it.
    // Otherwise go to the end of the word after it.
    
    // Test in MacVim, when dealing with 'e', 
    // the blank line is not consider a word.
    // So whitespace and newline are totally ingored.
    
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

// A port from vim's findmatchlimit, simplied version.
// This one only works for (), [], {}, <>
// Return -1 if we cannot find it.
// cpo_match is YES means ignore quotes.
#define MAYBE     2
#define FORWARD   1
#define BACKWARD -1
int findmatchlimit(NSString* string, NSUInteger pos, unichar initc, BOOL cpo_match);
int findmatchlimit(NSString* string, NSUInteger pos, unichar initc, BOOL cpo_match)
{ 
    // ----------
    unichar    findc           = 0; // The char to find.
    BOOL       backwards       = NO;
    
    int        count           = 0;      // Cumulative number of braces.
    int        do_quotes       = -1;     // Check for quotes in current line.
    int        at_start        = -1;     // do_quotes value at start position.
    int        start_in_quotes = MAYBE;  // Start position is in quotes
    BOOL       inquote         = NO;     // YES when inside quotes
    int        match_escaped   = 0;      // Search for escaped match.
    
    // NSUInteger pos             = cursor; // Current search position
    // BOOL       cpo_match       = YES;    // cpo_match = (vim_strchr(p_cpo, CPO_MATCH) != NULL);
    BOOL       cpo_bsl         = NO;     // cpo_bsl = (vim_strchr(p_cpo, CPO_MATCHBSL) != NULL);
    
    // ----------
    char*      b_p_mps         = "(:),{:},[:],<:>";
    for (char* ptr = b_p_mps; *b_p_mps; ptr += 2) 
    {
        if (*ptr == initc) {
            findc = initc;
            initc = ptr[2];
            backwards = YES;
            break;
        }
        
        ptr += 2;
        if (*ptr == initc) {
            findc = initc;
            initc = *(ptr - 2);
            backwards = NO;
            break;
        }
        
        if (ptr[1] != ',') { break; } // Invalid initc!
    }
    
    if (findc == 0) { return -1; }
    
    // ----------

    
    // ----------
    NSStringHelper  help;
    NSStringHelper* h        = &help;
    NSUInteger      maxIndex = [string length] - 1; 
    backwards ? initNSStringHelperBackward(h, string, maxIndex+1) : initNSStringHelper(h, string, maxIndex+1);
    
    // ----------
    while (YES)
    {
        if (backwards)
        {
            if (pos == 0) { break; } // At start of file
            --pos;
            
            if (testNewLine(characterAtIndex(h, pos)))
            {
                // At prev line.
                do_quotes = -1;
            }
        } else {  // Forward search
            if (pos == maxIndex) { break; } // At end of file
            
            if (testNewLine(characterAtIndex(h, pos))) {
                do_quotes = -1;
            }
            
            ++pos;
        }
        
        // ----------
        // if (pos.col == 0 && (flags & FM_BLOCKSTOP) && (linep[0] == '{' || linep[0] == '}'))
        // if (comment_dir)
        // ----------
        
        if (cpo_match) {
            do_quotes = 0;
        } else if (do_quotes == -1)
        {
            /*
             * Count the number of quotes in the line, skipping \" and '"'.
             * Watch out for "\\".
             */
            at_start = do_quotes;
            
            NSUInteger ptr = pos;
            while (ptr > 0 && !testNewLine([string characterAtIndex:ptr-1])) { --ptr; }
            NSUInteger sta = ptr;
            
            while (ptr < maxIndex && 
                   !testNewLine(characterAtIndex(h, ptr)))
            {
                if (ptr == pos + backwards) { at_start = (do_quotes & 1); }
                
                if (characterAtIndex(h, ptr) == '"' &&
                    (ptr == sta || 
                     characterAtIndex(h, ptr - 1) != '\'' || 
                     characterAtIndex(h, ptr + 1) != '\'')) 
                {
                    ++do_quotes;
                }
                
                if (characterAtIndex(h, ptr) == '\\' && 
                    ptr + 1 < maxIndex && 
                    !testNewLine(characterAtIndex(h, ptr+1))) 
                { ++ptr; }
                ++ptr;
            }
            do_quotes &= 1; // result is 1 with even number of quotes
            
            //
            // If we find an uneven count, check current line and previous
            // one for a '\' at the end.
            //
            if (do_quotes == 0)
            {
                inquote = NO;
                if (start_in_quotes == MAYBE)
                {
                    // Do we need to use at_start here?
                    inquote = YES;
                    start_in_quotes = YES;
                } else if (backwards)
                {
                    inquote = YES;
                }
                
                if (sta > 1 && characterAtIndex(h, sta - 2) == '\\')
                {
                    // Checking last char fo previous line.
                    do_quotes = 1;
                    if (start_in_quotes == MAYBE) {
                        inquote = at_start != 0;
                        if (inquote) {
                            start_in_quotes = YES;
                        }
                    } else if (!backwards)
                    {
                        inquote = YES;
                    }
                }
            }
        }
        if (start_in_quotes == MAYBE) {
            start_in_quotes = NO;
        }
        
        unichar c = characterAtIndex(h, pos);
        switch (c) {
                
            case '"':
                /* a quote that is preceded with an odd number of backslashes is
                 * ignored */
                if (do_quotes)
                {
                    NSUInteger col = pos;
                    int qcnt = 0;
                    unichar c2;
                    while (col > 0) {
                        --col;
                        c2 = characterAtIndex(h, col);
                        if (testNewLine(c2) || c2 != '\\') {
                            break;
                        }
                        ++qcnt;
                    }
                    if ((qcnt & 1) == 0) {
                        inquote = !inquote;
                        start_in_quotes = NO;
                    }
                }
                break;
                
            case '\'':
                if (!cpo_match && initc != '\'' && findc != '\'')
                {
                    if (backwards)
                    {
                        NSUInteger p1 = pos;
                        int col = 0;
                        while (p1 > 0 && col < 3) {
                            --p1;
                            if (testNewLine(characterAtIndex(h, p1))) {
                                break;
                            }
                            ++col;
                        }
                        
                        if (col > 1)
                        {
                            if (characterAtIndex(h, pos - 2) == '\'')
                            {
                                pos -= 2;
                                break;
                            } else if (col > 2 &&
                                       characterAtIndex(h, pos - 2) == '\\' &&
                                       characterAtIndex(h, pos - 3) == '\'')
                            {
                                pos -= 3;
                                break;
                            }
                        }
                    } else {
                        // Forward search
                        if (pos < maxIndex && !testNewLine(characterAtIndex(h, pos + 1)))
                        {
                            if (characterAtIndex(h, pos + 1) == '\\' &&
                                (pos < maxIndex - 2) &&
                                !testNewLine(characterAtIndex(h, pos + 2)) &&
                                characterAtIndex(h, pos + 3) == '\'') 
                            {
                                pos += 3;
                                break;
                            } else if (pos < maxIndex - 1 && 
                                       characterAtIndex(h, pos + 2) == '\'')
                            {
                                pos += 2;
                                break;
                            }
                        }
                    }
                }
                /* FALLTHROUGH */
                
            default:
                /* Check for match outside of quotes, and inside of
                 * quotes when the start is also inside of quotes. */
                if ((!inquote || start_in_quotes == YES) && 
                    (c == initc || c == findc))
                {
                    int bslcnt = 0;
                    
                    if (!cpo_bsl)
                    {
                        NSUInteger col = pos;
                        unichar c2;
                        while (col > 0) {
                            --col;
                            c2 = characterAtIndex(h, col);
                            if (testNewLine(c2) || c2 != '\\') {
                                break;
                            }
                            ++bslcnt;
                        }
                    }
                    /* Only accept a match when 'M' is in 'cpo' or when escaping
                     * is what we expect. */
                    if (cpo_bsl || (bslcnt & 1) == match_escaped)
                    {
                        if (c == initc)
                            count++;
                        else
                        {
                            if (count == 0)
                                return (int)pos;
                            --count;
                        }
                    }
                }
        }
        
    } // End of while
    
    return -1;
}

NSRange current_block(NSTextView* view, int count, BOOL inclusive, char what, char other)
{
    NSString* string = [view string];
    NSUInteger idx   = [view selectedRange].location;
    
    if ([string characterAtIndex:idx] == what)
    {
        /* cursor on '(' or '{', move cursor just after it */
        ++idx;
        if (idx >= [string length]) {
            return NSMakeRange(NSNotFound, 0);
        }
    }
    
    int start_pos = (int)idx;
    int end_pos   = (int)idx;
    
    while (count-- > 0)
    {
        /*
         * Search backwards for unclosed '(', '{', etc..
         * Put this position in start_pos.
         * Ignore quotes here.
         */
        if ((start_pos = findmatchlimit(string, start_pos, what, YES)) == -1)
        {
            return NSMakeRange(NSNotFound, 0);
        }
        
        /*
         * Search for matching ')', '}', etc.
         * Put this position in curwin->w_cursor.
         */
        if ((end_pos = findmatchlimit(string, end_pos, other, NO)) == -1) {
            return NSMakeRange(NSNotFound, 0);
        }
    }
    
    if (!inclusive)
    {
        ++start_pos;
        if (what == '{')
        {
            NSUInteger idx = mv_caret_handler(string, end_pos);
            if (idx == end_pos)
            {
                // The '}' is only preceded by indent, skip that indent.
                end_pos = (int) mv_0_handler(string, end_pos) - 1;
            }
        }
    } else {
        ++end_pos;
    }
    
    return NSMakeRange(start_pos, end_pos - start_pos);
}

NSRange current_word(NSTextView* view, int repeatCount, BOOL inclusive, BOOL fuzzy)
{    
    NSString*  string   = [view string];
    NSUInteger index    = [view selectedRange].location;
    NSUInteger maxIndex = [string length] - 1;
    
    if (index > maxIndex) { return NSMakeRange(NSNotFound, 0); }
    
    unichar    ch    = [string characterAtIndex:index];
    testAscii  test  = testWhiteSpace(ch) ? testWhiteSpace : (fuzzy ? testFuzzyWord : testForChar(ch));
    
    NSUInteger begin = index;
    NSUInteger end   = index;
    
    while (begin > 0)
    {
        if (test([string characterAtIndex:begin - 1]) == NO) { break; }
        --begin;
    }
        
    //
    // Word is like (  word  )
    if (testWhiteSpace(ch) == inclusive)
    {
        // If inclusive and at whitespace, whitespace is included: ("  word"  )
        // If exclusive and not at whitespace, then: (  "word"  )
        // That means we should find the end of the word.
        end = mv_e_handler(string, index, repeatCount, fuzzy) + 1;
    } else {
        // If inclusive and not at whitespace: (  "word  ")
        // If exclusive and at whitespace, then: ("  "word  )
        
        if (repeatCount > 1) {
            // Select more words.
            end = mv_w_handler(string, end, repeatCount - 1, fuzzy);
        }
        // If the end index is at beginning indent of next line,
        // Go back to prev line.
        end = mv_w_motion_handler(string, end, 1, fuzzy);
        
        // If we don't have any trailing whitespace,
        // Extend begin to include whitespace.
        if (!testWhiteSpace([string characterAtIndex:end - 1]))
        {
            while (begin > 0 && testWhiteSpace([string characterAtIndex:begin - 1]))
            {
                --begin;
            }
        }
    }
    
    return NSMakeRange(begin, end - begin);
}
NSRange current_quote(NSTextView* view, int repeatCount, BOOL inclusive, char what)
{
    return NSMakeRange(NSNotFound, 0);
}
NSRange current_tagblock(NSTextView* view, int repeatCount, BOOL inclusive)
{
    return NSMakeRange(NSNotFound, 0);
}
