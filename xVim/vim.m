//
//  Created by Morris on 11-12-17.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "vim.h"

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

NSUInteger mv_caret_handler(NSTextView* view)
{
    NSString* string = [[view textStorage] string];
    NSUInteger index = [view selectedRange].location;
    NSUInteger resultIndex  = index;
    NSUInteger seekingIndex = index;
    
    NSCharacterSet* set = [NSCharacterSet newlineCharacterSet];
    
    while (seekingIndex > 0) {
        unichar ch = [string characterAtIndex:seekingIndex-1];
        if ([set characterIsMember:ch]) {
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
            if ([set characterIsMember:ch] || (ch != '\t' && ch != ' ')) {
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
    
    NSCharacterSet* set = [NSCharacterSet newlineCharacterSet];
    
    while (index > 0) {
        if ([set characterIsMember:[string characterAtIndex:index-1]]) {
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
    
    NSCharacterSet* set = [NSCharacterSet newlineCharacterSet];
    
    while (index < maxIndex) {
        if ([set characterIsMember:[string characterAtIndex:index+1]]) {
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
        if ([[NSCharacterSet newlineCharacterSet] characterIsMember:[string characterAtIndex:maxIndex - 1]] == NO)
            --maxIndex;
        
        range.location = maxIndex;
    }
    
    [view setSelectedRange:range];
    range.location = mv_caret_handler(view);
    [view setSelectedRange:range];
    if (ensureVisible) { [view scrollRangeToVisible:range]; }
}
