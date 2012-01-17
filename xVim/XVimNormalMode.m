//
//  Created by Morris on 11-12-19.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "XVimMode.h"
#import "XVimController.h"
#import "XTextViewBridge.h"
#import "vim.h"
#import "NSStringHelper.h"

@interface XVimNormalModeHandler()
{
    @private
        int     commandCount;
        int     motionCount;
        unichar commandChar;
        unichar motionChar;
        BOOL    dontCheckTrailingCR;
    
        XTextViewBridge* bridge;
        NSTextView*      hijackedView;
}

-(void) cmdScroll: (unichar) cmdChar; // Accepts f/b/d/u.
-(void) cmdYDC:    (unichar) cmdChar; // Accepts Y/D/C. cmdYDC will reset everything.
-(void) cmdHML:    (unichar) cmdChar; // Accepts H/M/L.
-(void) cmdPaste:  (unichar) cmdChar; // Accepts p/P.
-(void) cmdChangeCase; // ~
-(void) cmdJoin;       // J
-(void) cmdGoto:       (BOOL) cmdCountSpecified; // G
-(void) cmdDelChar:    (BOOL) isAfter; // x/X
-(void) cmdOpenNewline:(BOOL) isAfter; //o/O
-(void) cmdPlaceLine:(unichar) cmdChar; // For zz/zt/zb
-(void) cmdddcc:     (unichar) cmdChar; // For dd/cc.
-(BOOL) cmdMotions:  (unichar) cmdChar; // Return NO if we need to reset.
@end

@implementation XVimNormalModeHandler
-(void) reset
{
    commandCount = 0;
    motionCount  = 0;
    commandChar  = 0;
    motionChar   = 0;
    dontCheckTrailingCR = NO;
}

-(id) initWithController:(XVimController*) c
{
    if (self = [super initWithController:c])
    {
        bridge       = [c bridge];
        hijackedView = [bridge targetView]; 
    }
    return self;
}

-(NSArray*) selectionChangedFrom:(NSArray*)oldRanges to:(NSArray*)newRanges
{
#ifdef ENABLE_VISUALMODE
    if ([[newRanges objectAtIndex:0] rangeValue].length > 0)
    {
        // Switch to visual mode if 
        [controller switchToMode:VisualMode subMode:NoSubMode];
        return newRanges;
    }
#endif
    
    
    if (dontCheckTrailingCR == YES) { return newRanges; }
    if ([newRanges count] > 1)      { return newRanges; }
    
    NSRange selected = [[newRanges objectAtIndex:0] rangeValue];
    if (selected.length > 0 || selected.location == 0) { return newRanges; }
    
    NSString*   string       = [hijackedView string];
    
    if (!testNewLine([string characterAtIndex:selected.location - 1]))
    {
        NSUInteger strLen = [string length];
        if (selected.location >= strLen || testNewLine([string characterAtIndex:selected.location])) {
            --selected.location;
            return [NSArray arrayWithObject:[NSValue valueWithRange:selected]];
        }
    }
    
    return newRanges;
}

-(void) cmdScroll:(unichar) ch
{
    // Ctrl + f one page forward
    // Ctrl + b one page backward
    // Ctrl + d half screen down
    // Ctrl + u harf screen up
    NSRect    currentRect = [hijackedView visibleRect];
    NSSize    viewSize    = [hijackedView frame].size;
    NSInteger scrollToY   = 0;
    NSInteger delta       = currentRect.size.height; 
    
    if (ch == 'f' || ch == 'd')
    {
        if (ch == 'd') { delta /= 2; }
        
        scrollToY = currentRect.origin.y + delta;
        NSInteger maxY = viewSize.height - currentRect.size.height;
        if (scrollToY > maxY) { scrollToY = maxY; }
        
    } else {
        delta /= ch == 'u' ? -2 : -1;
        scrollToY = currentRect.origin.y + delta;
        if (scrollToY < 0) { scrollToY = 0; }
    }
    
    if (scrollToY != currentRect.origin.y) 
    {
        // Move caret to a new place.
        
        NSLayoutManager* manager = [hijackedView layoutManager];
        NSRange range = [hijackedView selectedRange];
        range.length = 1;
        range = [manager glyphRangeForCharacterRange:range actualCharacterRange:nil];
        
        NSRect    caretRect   = [manager boundingRectForGlyphRange:range 
                                                   inTextContainer:[hijackedView textContainer]];
        NSInteger caretYInScreen = caretRect.origin.y - currentRect.origin.y;
        NSInteger caretYAtLeast  = 0.2 * currentRect.size.height - caretRect.size.height;
        NSInteger caretYAtMost   = 0.8 * currentRect.size.height;
        
        if (caretYInScreen < caretYAtLeast) {
            caretYInScreen = caretYAtLeast;
        } else if (caretYInScreen > caretYAtMost) {
            caretYInScreen = caretYAtMost;
        }
        
        NSRange insertion = {[hijackedView characterIndexForInsertionAtPoint:
                              NSMakePoint(0, caretYInScreen + currentRect.origin.y + delta)],0};
        [hijackedView setSelectedRange:insertion];
        insertion.location = mv_caret_handler(hijackedView);
        [hijackedView setSelectedRange:insertion];
        
        // Scroll
        currentRect.origin.y = scrollToY;
        [self scrollViewRectToVisible:currentRect];
    }
}

-(void) cmdYDC:(unichar) ch
{
    // All these 3 command does not include trailing CR
    NSString*  string   = [hijackedView string];
    NSUInteger current  = [hijackedView selectedRange].location;
    NSUInteger lineEnd  = current;
    NSUInteger maxIndex = [string length];
    
    NSStringHelper  helper;
    NSStringHelper* h = &helper;
    initNSStringHelper(h, string, maxIndex);
    --maxIndex;
    
    while (lineEnd <= maxIndex)
    {
        if (testNewLine(characterAtIndex(&helper, lineEnd))) {
            --commandCount;
            if (commandCount == 0) { break; }
        }
        ++lineEnd;
    }
    
    NSUInteger lineBegin = ch == 'Y' ? mv_0_handler(hijackedView) : current;
    NSRange    range     = {lineBegin, lineEnd - lineBegin};
    [controller yank:string withRange:range wholeLine:(ch == 'Y')];
    
    if (ch == 'C')
    {
        dontCheckTrailingCR = YES;
        [hijackedView insertText:@"" replacementRange:range];
        [controller switchToMode:InsertMode];
    } else if(ch == 'D')
    {
        [hijackedView insertText:@"" replacementRange:range];
    }
    
    // Reset
    commandChar     = 0;
    commandCount    = 0;
    dontCheckTrailingCR = NO;
}

-(void) cmdHML:(unichar) ch
{
    NSLayoutManager* manager   = [hijackedView layoutManager];
    NSTextContainer* container = [hijackedView textContainer];
    NSRect           rect      = [hijackedView visibleRect];
    CGFloat          fraction  = 0;
    
    NSRange          selection = [hijackedView selectedRange];
    selection.length = 1;
    selection        = [manager glyphRangeForCharacterRange:selection 
                                       actualCharacterRange:nil];
    
    NSRect caretRect           = [manager boundingRectForGlyphRange:selection 
                                                    inTextContainer:[hijackedView textContainer]];
    
    
    if (ch == 'M') {
        rect.origin.y += rect.size.height / 2;
    } else if (ch == 'L') {
        rect.origin.y += rect.size.height - caretRect.size.height / 2;
    } else {
        rect.origin.y += caretRect.size.height / 2;
    }
    
    selection.location = [manager characterIndexForPoint:NSMakePoint(rect.origin.x, rect.origin.y) 
                                         inTextContainer:container
                fractionOfDistanceBetweenInsertionPoints:&fraction];
    
    if (selection.location != NSNotFound)
    {
        selection.length   = 0;
        [hijackedView setSelectedRange:selection];
        selection.location = mv_caret_handler(hijackedView);
        [hijackedView setSelectedRange:selection];
    }
}

-(void) cmdPaste:(unichar) ch
{
    BOOL wholeLine = NO;
    NSString* yankContent = [controller yankContent:&wholeLine];
    if (yankContent != nil)
    {
        dontCheckTrailingCR = YES;
        if (wholeLine)
        {
            if (ch == 'p') {
                [hijackedView moveToEndOfLine:nil];
            } else {
                NSRange currRange = [hijackedView selectedRange];
                [hijackedView moveUp:nil];
                if (currRange.location == [hijackedView selectedRange].location) {
                    [hijackedView moveToBeginningOfLine:nil];
                } else {
                    [hijackedView moveToEndOfLine:nil];
                }
            }
            [hijackedView moveRight:nil];
        } else if (ch == 'p') { 
            [hijackedView moveRight:nil];
        }
        
        NSRange currentIndex = [hijackedView selectedRange];
        
        for (int i = 0; i < commandCount; ++i) {
            [hijackedView insertText:yankContent];
            if (wholeLine) {
                [hijackedView setSelectedRange:currentIndex];
            }
        }
    }
}

-(void) cmdChangeCase
{
    // ~ will only work on the character in current line.
    NSString*  string   = [hijackedView string];
    NSUInteger maxIndex = [string length] - 1;
    NSUInteger index    = [hijackedView selectedRange].location;
    if (index <= maxIndex && testNewLine([string characterAtIndex:index]) == NO)
    {
        NSUInteger length = 1;
        if (commandCount > 1)
        {
            NSUInteger lineEndIndex = mv_dollar_handler(hijackedView) + 1;
            length = lineEndIndex - index;
            if (length > commandCount) { length = commandCount; }
        }
        
        NSRange range = {index, length};
        NSMutableString* subString = [NSMutableString stringWithString:[string substringWithRange:range]];
        NSRange r = {0,1};
        for (; r.location < length; ++r.location) {
            unichar c = [subString characterAtIndex:r.location];
            if (c >= 'a' && c <= 'z')
                c = c + 'A' - 'a';
            else if (c >= 'A' && c <= 'Z')
                c = c + 'a' - 'A';
            [subString replaceCharactersInRange:r 
                                     withString:[NSString stringWithCharacters:&c 
                                                                        length:1]];
        }
        [hijackedView insertText:subString replacementRange:range];
        
        range.length = 0;
        range.location += length;
        [hijackedView setSelectedRange:range];
    }
}

-(void) cmdJoin
{
    // Vim seems a real complex, so I don't want to follow it.
    // Two lines are join together and seperate with a whitespace.
    NSString*       string      = [hijackedView string];
    NSUInteger      index       = [hijackedView selectedRange].location;
    NSUndoManager*  undoManager = [hijackedView undoManager];
    NSStringHelper  helper;
    NSStringHelper* h = &helper;
    unichar ch = 0;
    
    commandCount = commandCount > 2 ? commandCount - 1 : 1;
    
    [undoManager beginUndoGrouping];
    
    for (int i = 0; i < commandCount; ++i)
    {
        NSUInteger maxIndex = [string length];
        initNSStringHelper(h, string, maxIndex);
        --maxIndex;
        
        while (index < maxIndex) {
            DLog(@"Checking Newline");
            if (testNewLine(characterAtIndex(h, index)))
                break;
            ++index;
        }
        // Now we are at the end of current line.
        if (index == maxIndex) {
            // If the end of the textview is CR, we simply remove it.
            if (testNewLine(characterAtIndex(h, index)))
            {
                [hijackedView insertText:@"" 
                        replacementRange:NSMakeRange(maxIndex, 1)];
                [hijackedView setSelectedRange:NSMakeRange(maxIndex - 1, 0)];
            }
            break;
        } else {
            // Go forward to find whitespaces.
            NSInteger after = index;
            while (after < maxIndex) {
                ch = characterAtIndex(h, after + 1);
                if (ch != '\t' && ch != ' ') { break; }
                ++after;
            }
            
            // Go backward to find whitespaces.
            NSInteger before = index;
            while (before > 0) {
                ch = characterAtIndex(h, before - 1);
                if (ch != '\t' && ch != ' ') { break; }
                --before;
            }
            // The whole line is whitespace, these whitespaces should not be removed.
            if (testNewLine(ch) || before == 0) { before = index; }
            
            [hijackedView insertText:@" " 
                    replacementRange:NSMakeRange(before, after - before + 1)];
            [hijackedView setSelectedRange:NSMakeRange(before + 1, 0)];
        }
    }
    
    [undoManager endUndoGrouping];
}

-(void) cmdGoto:(BOOL) commandCountSpecified
{
    NSRange   range      = {0, 0};
    NSInteger lineNumber = commandCountSpecified ? commandCount - 1 : -1;
    
    if (lineNumber > 0){
        range = [hijackedView accessibilityCharacterRangeForLineNumber:lineNumber];
        range.length = 0;
        if (range.location == 0 && lineNumber != 0) {
            // The lineNumber is not valid,
            // We move it to the last line.
            lineNumber = -1;
        }
    }
    
    if (lineNumber == -1)
    {
        // Goto last line
        NSString*  string   = [hijackedView string];
        NSUInteger maxIndex = [string length];
        if (testNewLine([string characterAtIndex:maxIndex - 1]) == NO)
            --maxIndex;
        range.location = maxIndex;
    }
    
    [hijackedView setSelectedRange:range];
    range.location = mv_caret_handler(hijackedView);
    [hijackedView setSelectedRange:range];
    [hijackedView scrollRangeToVisible:range];
}

-(void) cmdDelChar:(BOOL)after
{
    NSString* string = [hijackedView string];
    NSInteger index  = [hijackedView selectedRange].location;
    NSRange   range  = {0, 0};
    
    if (after)
    {
        NSUInteger maxIndex = [string length] - 1;

        if (index <= maxIndex)
        {
            range.location = index;
            range.length   = commandCount;
        } 
    } else {
        
        NSUInteger rIndex = index > commandCount ? index - commandCount : 0;
        if (index > rIndex)
        {
            range.location = rIndex;
            range.length   = index - rIndex;
        }
    }
    
    if (range.length != 0) {
        [controller yank:string withRange:range wholeLine:NO];
        [hijackedView insertText:@"" replacementRange:range];
    }
}

-(void) cmdOpenNewline:(BOOL)isAfter
{
    dontCheckTrailingCR = YES;
    
    if (isAfter == NO) {
        NSRange currRange = [hijackedView selectedRange];
        dontCheckTrailingCR = YES;
        [hijackedView moveUp:nil];
        isAfter = currRange.location == [hijackedView selectedRange].location;
    }
    
    if (isAfter) {
        [hijackedView moveToEndOfLine:nil];
    } else {
        [hijackedView moveToBeginningOfLine:nil];
    }
    
    [hijackedView insertNewline:nil];
    [controller switchToMode:InsertMode];
}

-(void) cmdPlaceLine:(unichar) ch
{
    if (ch != 't' && ch != 'b' && ch != 'z') return;
    
    NSLayoutManager* manager = [hijackedView layoutManager];
    NSRange range = [hijackedView selectedRange];
    range.length = 1;
    range = [manager glyphRangeForCharacterRange:range actualCharacterRange:nil];
    
    NSRect caretRect   = [manager boundingRectForGlyphRange:range 
                                            inTextContainer:[hijackedView textContainer]];
    
    NSRect visibleRect = [hijackedView visibleRect];
    
    if (ch == 't') {
        visibleRect.origin.y = caretRect.origin.y;
    } else if (ch == 'b') {
        visibleRect.origin.y = caretRect.origin.y + caretRect.size.height - 
        visibleRect.size.height;
    } else {
        visibleRect.origin.y = caretRect.origin.y - visibleRect.size.height / 2;
    }
    
    if (visibleRect.origin.y < 0) { visibleRect.origin.y = 0; }
    [self scrollViewRectToVisible:visibleRect];
}

-(void) cmdddcc:(unichar) ch
{
    // Delete whole lines except last new line character. And enter insert mode.
    NSString*  string   = [hijackedView string];
    NSUInteger lineEnd  = [hijackedView selectedRange].location;
    NSUInteger strLen   = [string length];
    
    NSStringHelper  helper;
    NSStringHelper* h = &helper;
    initNSStringHelper(h, string, strLen);
    
    if (lineEnd < strLen)
    {
        while (lineEnd < strLen)
        {
            if (testNewLine(characterAtIndex(h, lineEnd))) {
                --commandCount;
                if (commandCount == 0) { break; }
            }
            ++lineEnd;
        }
        
        // We need to include a new line character if there's any.
        if (ch == 'd' && testNewLine(characterAtIndex(h, lineEnd))) {
            ++lineEnd;
        }
        
        NSUInteger lineBegin = mv_0_handler(hijackedView);
        NSRange    range     = {lineBegin, lineEnd - lineBegin};
        
        [controller yank:string withRange:range wholeLine:YES];
        
        [hijackedView insertText:@"" replacementRange:range];
        if (ch == 'c') { [controller switchToMode:InsertMode]; }
    }
}

-(BOOL) cmdMotions:(unichar) ch
{
    // Unsupported:
    // {[()]} // not much useful
    // (left)/(down)/(up)/(right) // the same as hjkl, 
    //                               but we filter them out at the beginning
    //
    // Supported motions: 
    // wbeWBE, hjkl, ^$0_
    // i wW{[(<'"
    // a wW{[(<'"
    // v // toggle character range and line range.(jk is line range, others are character range)
    
    NSInteger motionBegin = -1;
    NSInteger motionEnd   = -1;
    
    if (motionChar == 0 && (ch == 'i' || ch == 'a' || ch == 'v'))
    {
        motionChar = ch;
        return YES;
    }
    
    if (motionChar != 'i' && motionChar != 'a')
    {
        // handle basic motion here
        switch (ch) {
            case 'w': motionEnd   = mv_w_motion_handler(hijackedView, commandCount, NO);  break;
            case 'W': motionEnd   = mv_w_motion_handler(hijackedView, commandCount, YES); break;
                
            case 'e': motionEnd   = mv_e_handler(hijackedView, commandCount, NO)+1;  break;
            case 'E': motionEnd   = mv_e_handler(hijackedView, commandCount, YES)+1; break;
                
            case 'b': motionBegin = mv_b_handler(hijackedView, commandCount, NO);  break;
            case 'B': motionBegin = mv_b_handler(hijackedView, commandCount, YES); break;
                
            case 'h': motionBegin = mv_h_handler(hijackedView, commandCount);      break;
            case 'l': motionEnd   = mv_l_handler(hijackedView, commandCount, NO);  break;
                
            case '^': motionBegin = mv_caret_handler(hijackedView);                break;
            case '_':
            case '0': motionBegin = mv_0_handler(hijackedView);                    break;
            case '$': motionEnd   = mv_dollar_handler(hijackedView);               break;
            case 'j':
            {
                NSRange range = [hijackedView selectedRange];
                for (int i = 0; i < commandCount; ++i) { [hijackedView moveDown:nil]; }
                NSRange newRange = [hijackedView selectedRange];
                // For now, we record only character range.
                if (range.location != newRange.location) {
                    motionBegin = range.location;
                    motionEnd   = newRange.location;
                }
                [hijackedView setSelectedRange:range];
            }
                break;
            case 'k':
            {
                NSRange range = [hijackedView selectedRange];
                for (int i = 0; i < commandCount; ++i) { [hijackedView moveUp:nil]; }
                NSRange newRange = [hijackedView selectedRange];
                // For now, we record only character range.
                if (range.location != newRange.location) {
                    motionBegin = newRange.location;
                    motionEnd   = range.location;
                }
                [hijackedView setSelectedRange:range];
            }
                break;
        }
        
    } else
    {
        NSString* awMotion = @"wbeWBE{[(<'\"";
        NSString* input = [NSString stringWithCharacters:&ch length:1];
        if ([awMotion rangeOfString:input].location != NSNotFound)
        {
            switch (ch) {
                case 'w':
                case 'W':
                    // If we are at whitespace, delete the whitespace, otherwise
                    // delete the word. If it is aw, delete the trailing whitespace
                    // Either way, the caret will stay at the same line.
                {
                    NSRange range = motion_word_bound(hijackedView, ch == 'W', motionChar == 'a');
                    motionBegin = range.location;
                    motionEnd   = range.location + range.length;
                }
                    break;
                case '{':
                case '}':
                case '(':
                case ')':
                case '[':
                case ']':
                case '<':
                case '>':
                case '\'':
                case '"':
                    // TODO: Implement a efficient bracket matching algorithm, and we are all set.
                    break;
                    
                default:
                    break;
            }
        }
    }
    
    if (motionBegin != motionEnd)
    {
        if (motionBegin == -1) { motionBegin = [hijackedView selectedRange].location; }
        if (motionEnd   == -1) { motionEnd   = [hijackedView selectedRange].location; }
        
        NSString* string = [hijackedView string];
        
        BOOL wholeLine = (ch == 'j' || ch == 'k') != (motionChar == 'v');
        if (wholeLine) {
            [hijackedView setSelectedRange:NSMakeRange(motionBegin, 0)];
            motionBegin = mv_0_handler(hijackedView);
            [hijackedView setSelectedRange:NSMakeRange(motionEnd, 0)];
            motionEnd   = mv_dollar_inc_handler(hijackedView);
        }
        
        NSRange range = {motionBegin, motionEnd - motionBegin};
        [controller yank:string withRange:range wholeLine:wholeLine];
        if (commandChar != 'y') {
            if (commandChar == 'c') { dontCheckTrailingCR = YES; }
            [hijackedView insertText:@"" replacementRange:range];
            if (commandChar == 'c') { [controller switchToMode:InsertMode]; }
        }
    }

    return NO;
}

// Below are commands that are going to be implemented.
// %     Goto to the matching bracket
// #>    Indent
// #<    Un-Indent
// fx    Find char x on current line and go to it
// tx    Similar to fx, but stops one character short before x
// Fx    Similar to fx, but searches backwards
// Tx    Similar to tx, but searches backwards
// #;    Repeat last find motion
// #,    Repeat last find motion, but in reverse
// #*    Find next occurance of identifier under caret or currently selected text
// ##    Similar to * but backwards
// :#    Jump to line number #.
// :q, :q!, :w, :wq, :x

-(BOOL) processKey:(unichar)ch modifiers:(NSUInteger)flags
{
    if (ch == '\t') { return NO; } // Don't interpret tabs.
    if (ch == XEsc) { [self reset]; return YES; } // Esc will reset everything
    
    flags &= XImportantMask;
        
    // 1. Deal with key that has modifiers.
    if (flags == XMaskControl &&
        (ch == 'f' || ch =='b' || ch == 'd' || ch == 'u'))
    {
        [self cmdScroll:ch];
        return YES;
        
    }
    if (flags != 0) { return NO; } // No other supported modifiers.
    
    
    // 2. Deal with number keys.
    // If the commandCount is not defined, we treat '0' as a command instead of a number.
    if (ch <= '9' && ((commandCount > 0 && ch >= '0') || (commandCount == 0 && ch > '0')) )
    {
        if (commandChar == 0) {
            commandCount = commandCount * 10 + ch - '0';
        } else {
            // We are waiting for another character to complete the command.
            // And we only accept numbers before the motion is entered.
            // Otherwise, we consider this is a bad command, and reset everything.
            BOOL shouldAccept = NO;
            
            if (commandChar == 'y' || commandChar == 'd' || commandChar == 'c') {
                if (motionChar == 0) {
                    shouldAccept = YES;
                }
            }
            
            if (shouldAccept) {
                motionCount = motionCount * 10 + ch - '0';
            } else {
                [self reset];
            }
        }
        return YES;
    }
    
    BOOL commandCountSpecified = commandCount > 0; // This is needed only for 'G'
    if (commandCount == 0) commandCount = 1;
    
    // 3. Deal with commands that are double chars.
    if (commandChar != 0)
    {
        if (commandChar == 'z')
        {
            [self cmdPlaceLine:ch];

        } else if (commandChar == 'g')
        {
            switch (ch) {
                case 'g': [self cmdGoto:YES]; break;
                case '_': // Goto last non-blank of the line.
                    [hijackedView setSelectedRange:NSMakeRange(mv_g__handler(hijackedView), 0)];
                    break;
            }
        } else
        {
            // Deal with y/d/c
            
            // Apply the motion count.
            if (motionCount != 0) { commandCount *= motionCount; }
            
            if (commandChar == ch)
            {
                switch (ch) {
                    case 'c':
                    case 'd': [self cmdddcc:ch];  break;
                    case 'y': [self cmdYDC:'Y'];  break;                    
                } 
            } else {
                // Handle the motions here.
                // If cmdMotions returns YES, we shouldn't reset.
                if ([self cmdMotions:ch]) { 
                    return YES;
                }
            }
        }
        
        [self reset];
        return YES;
    }
    
    // 4. Deal with commands that are one char.
    motionChar = motionCount = 0;
    
    switch (ch) {
            // NOTE: 'j' and 'k' calls the NSTextView's methods,
            // Them won't ensure that the caret won't be before the CR
        case 'j': for (int i = 0; i < commandCount; ++i) { [hijackedView moveDown:nil]; }  break;
        case 'k': for (int i = 0; i < commandCount; ++i) { [hijackedView moveUp:nil];   } break;
            
        case NSDeleteCharacter: // Backspace in normal mode is like 'h'
        case 'h': 
        {
            NSRange range = {mv_h_handler(hijackedView,commandCount),0};
            [hijackedView setSelectedRange:range];
            [hijackedView scrollRangeToVisible:range];
        }
            break;
            
        case XSpace: // Space in normal mode is like 'l'
        case 'l':
        {
            NSRange range = {mv_l_handler(hijackedView,commandCount,YES),0};
            [hijackedView setSelectedRange:range]; 
            [hijackedView scrollRangeToVisible:range];
        }
            break;
            
        case 'r':
        case 'R': [controller switchToMode:ReplaceMode 
                                   subMode:(ch == 'r' ? SingleReplaceMode : NoSubMode)];
            break;
#ifdef ENABLE_VISUALMODE
        case 'v':
        case 'V': [controller switchToMode:VisualMode 
                                   subMode:(ch == 'V' ? VisualLineMode : NoSubMode)];
            break;
#endif
            
        case 'u': for (int i = 0; i < commandCount; ++i) { [[hijackedView undoManager] undo]; } break;
        case 'U': for (int i = 0; i < commandCount; ++i) { [[hijackedView undoManager] redo]; } break;
            
            
            // TODO: commandCount for aAiIoOrR is not implemented.
        case 'a':
            dontCheckTrailingCR = YES;
            [hijackedView moveRight:nil];
            [controller switchToMode:InsertMode];
            break;
        case 'i':
            [controller switchToMode:InsertMode];
            break;
        case '$':
            [hijackedView setSelectedRange:
             NSMakeRange(mv_dollar_handler(hijackedView), 0)];
            break;
        case 'A':
            dontCheckTrailingCR = YES;
            [hijackedView moveToEndOfLine:nil];
            [controller switchToMode:InsertMode];
            break;
        case '0':
#ifndef MAKE_0_AS_CARET
            [hijackedView setSelectedRange:
             NSMakeRange(mv_0_handler(hijackedView), 0)];
            break;
#endif
        case '_':
        case '^':
        case 'I':
        {
            [hijackedView setSelectedRange: NSMakeRange(mv_caret_handler(hijackedView), 0)];
            if (ch == 'I') { [controller switchToMode:InsertMode]; }
        }
            break;
            
            // wWbBeE
        case 'w':
        case 'W':
        {
            NSRange range = {mv_w_handler(hijackedView, commandCount, ch == 'W'), 0};
            [hijackedView setSelectedRange:range];
            [hijackedView scrollRangeToVisible:range];
        }
            break;
        case 'b':
        case 'B':
        {
            NSRange range = {mv_b_handler(hijackedView, commandCount, ch == 'B'), 0};
            [hijackedView setSelectedRange:range];
            [hijackedView scrollRangeToVisible:range];
        }
            break;
        case 'e':
        case 'E':
        {
            NSRange range = {mv_e_handler(hijackedView, commandCount, ch == 'E'), 0};
            [hijackedView setSelectedRange:range];
            [hijackedView scrollRangeToVisible:range];
        }
            break;
            
        case '|':
            // Go to column
            [hijackedView setSelectedRange:NSMakeRange(columnToIndex(hijackedView, commandCount), 0)];
            break;
            
        case 'H':
        case 'M':
        case 'L':
            [self cmdHML:ch];
            break;
            
        case 'G': 
            [self cmdGoto:commandCountSpecified];
            break;
            
        case 'J': 
            [self cmdJoin];
            break;
            
        case 'Y':
        case 'D':
        case 'C':
            [self cmdYDC:ch];
            break;
            
        case '~':
            [self cmdChangeCase];
            break;
            
        case 'X':
        case 'x':
            // x deletes the character after the caret.
            [self cmdDelChar:ch == 'x'];
            break;
            
        case 'O':
        case 'o':
            [self cmdOpenNewline:ch == 'o'];
            break;
            
        case 'p':
        case 'P':
            [self cmdPaste:ch]; 
            break;
            
            // Below are commands that need a parameter
        case 'g':
        case 'z':
        case 'y':
        case 'd':
        case 'c':
            commandChar = ch;
            return YES; // Don't reset commandCount.
        default:
            break;
    }
    
    // Reset
    commandChar     = 0;
    commandCount    = 0;
    dontCheckTrailingCR = NO;
    return YES;
}
@end