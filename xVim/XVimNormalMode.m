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

typedef enum e_affect_range
{
    DefaultAffectRange = 0,
    CharacterWise = 1,
    LineWise      = 2
} AffectRange;

@interface XVimNormalModeHandler()
{
@private
    
    // e.g. 3d5g_ :        |     e.g. 3gg :
    // firstCount    = 3   |   firstCount    = 3
    // secondCount   = 5
    // operatorChar  = d
    // cmdChar       = g   |   cmdChar       = g
    // secondCmdChar = _   |   secondCmdChar = g
    
    int        firstCount;    // Number before the command.
    int        secondCount;   // Number after the command.
    unichar    operatorChar;  // The operator. Currently can only be y,d,c
    NSUInteger cmdChar;       // The command.
    NSUInteger secondCmdChar; // The second command char.
    
    AffectRange affect;
    
    // When dontCheckTrailingCR == YES, we can place the caret
    // right before CR.
    BOOL dontCheckTrailingCR;
    
    XTextViewBridge* bridge;
    NSTextView*      hijackedView;
}

// Generate the range for cmdChar and secondCmdChar
// If the range is invalid. The location of returned value is NSNotFound.
// generateRange will check the firstCount and secondCount!
-(NSRange) generateRange:(BOOL*) ensureVisible defaultLinewise:(BOOL*) flag;

// Return YES if we execute the command.
-(BOOL) executeCMD;
-(BOOL) executeNormalCMD;


-(void) cmdJoin;
-(void) cmdYDC;
-(void) cmdChangeCase;  //~
-(void) cmdDelChar;     //x/X
-(void) cmdOpenNewline; //o/O
-(void) cmdPaste;       //p/P.
-(void) cmdPlaceLine;   //zz/zt/zb

-(void) cmdddcc; // For dd/cc.

-(NSUInteger) cmdScroll; // ctrl-[f/b/d/u].
-(NSUInteger) cmdHML;    // H/M/L.
-(NSUInteger) cmdGoto: (BOOL) cmdCountSpecified; // G
-(NSUInteger) cmdSOL; // Enter/+/-
@end

@implementation XVimNormalModeHandler
-(id) initWithController:(XVimController*) c
{
    if (self = [super initWithController:c])
    {
        bridge       = [c bridge];
        hijackedView = [bridge targetView];
        firstCount   = -1;
        secondCount  = -1;
    }
    return self;
}

-(void) reset
{
    firstCount    = -1;
    secondCount   = -1;
    operatorChar  = 0;
    cmdChar       = 0;
    secondCmdChar = 0;
    affect        = DefaultAffectRange;
    dontCheckTrailingCR = NO;
}

-(NSArray*) selectionChangedFrom:(NSArray*)oldRanges to:(NSArray*)newRanges
{
    if (dontCheckTrailingCR == YES) { return newRanges; }
    if ([newRanges count] > 1)      { return newRanges; }
    
    NSRange selected = [[newRanges objectAtIndex:0] rangeValue];
    if (selected.length > 0 || selected.location == 0) { return newRanges; }
    
    NSString* string = [hijackedView string];
    
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

typedef enum e_handle_stat
{
    NotHandled = 0,
    Handled    = 1,
    BadChar    = 2,
    Execute    = 3,
    ExecuteNormal = 4
} HandleState;

// Below are commands that are going to be implemented.
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
-(BOOL) processKey:(unichar)c modifiers:(NSUInteger)flags
{
    if (c == '\t') { return NO; } // Don't interpret tabs.
    if (c == XEsc) { [self reset]; return YES; } // Esc will reset everything
    
    // In this method, we check what kind of ch is 
    // and assign it to the proper member.
    
    // 1. Check number.
    HandleState state = NotHandled;
    if (c >= '0' && c <= '9')
    {
        // We only accept number only if cmdChar is 0.
        if (cmdChar != 0) {
            state = BadChar;
        } else {
            // The number adds to firstCount if operator is 0.
            // Otherwise it adds to secondCount.
            int* tc = operatorChar == 0 ? &firstCount : &secondCount;
            if (*tc == -1)
            {
                if (c != '0') 
                { 
                    *tc = c - '0';
                    state = Handled;
                }
            } else {
                *tc = *tc * 10 + c - '0';
                state = Handled;
            }
        }
    }
    
    flags &= XImportantMask;
    NSUInteger ch = flags | c; // Combine ch and flags
    
    // 2. Check cmd.
    if (state == NotHandled)
    {
        state = Execute;
        switch (ch) {
                
                // Operators
            case 'y':
            case 'd':
            case 'c':
                if (operatorChar == 0)
                {
                    // Wait for the motion.
                    operatorChar = ch;
                    state = Handled;
                } else {
                    cmdChar = ch;
                }
                break;
                
                // Not motion commands.
            case 'J': // Join
            case 'Y': // Yank   line
            case 'D': // Delete line
            case 'C': // Change line
            case '~': // Change case
            case 'X': // Delete char before
            case 'x': // Delete char after
            case 'O': // Open line above
            case 'o': // Open line below
            case 'p': // Paste
            case 'P': // Pate before
            case 'I': // Insert at beginning.
            case 'A': // Append at end
            case 'u': // Undo
            case 'U': // Redo
            case 'r' | XMaskControl: // Redo
            case 'r': // Replace single
            case 'R': // Replace
                if (operatorChar != 0) {
                    state = BadChar;
                } else {
                    // if (cmdChar == 'g') { secondCmdChar = ch; } else
                    if (cmdChar != 0) 
                    { 
                        state = BadChar; 
                    } else { 
                        cmdChar = ch;
                        state = ExecuteNormal;
                    }
                }
                break;
                
            case 'i': // Insert
            case 'a': // Append
                if (cmdChar != 0) {
                    state = BadChar;
                } else {
                    cmdChar = ch;
                    if (operatorChar != 0)
                    {
                        // They become text objects.
                        state = Handled;
                    } else {
                        state = ExecuteNormal;
                    }
                }
                break;
                
                // Motion commands.
            default:
                if (cmdChar == 0)
                {
                    cmdChar = ch;
                    if (ch == 'z' || ch == 'g')
                    {
                        // Wait for another input.
                        state = Handled;
                    }
                } else {
                    secondCmdChar = ch;
                    if (cmdChar == 'z') { // zx command is not motion.
                        state = ExecuteNormal;
                    }
                }
                break;
        }
    }
    
    BOOL handledKey = YES;
    if (state != Handled)
    {
        BOOL res = YES;
        if (state == Execute)
        {
            res = [self executeCMD];
        } else if (state == ExecuteNormal) {
            res = [self executeNormalCMD];
        }
        
        if (res == NO && flags != 0)
        {
            // Let the NSTextView to process keys with modifiers.
            handledKey = NO;
        }
        // Reset everything only when state is Execute or BadChar.
        [self reset];
    }
    
    return handledKey;
}

-(NSRange) generateRange:(BOOL*) visible defaultLinewise:(BOOL*) linewise
{
    NSRange range             = {NSNotFound, 0};
    BOOL    ensureVisible     = NO;
    BOOL    defaultLineWise   = NO;
    BOOL    cmdCountSpecified = firstCount != -1;
    
    if (!cmdCountSpecified) { firstCount = 1; }
    if (secondCount != -1)  { firstCount *= secondCount; }
    
    if (cmdChar == 'g') // g commands.
    {
        switch (secondCmdChar)
        {
            case 'g': 
                range.location  = [self cmdGoto:YES];
                defaultLineWise = YES;
                ensureVisible   = YES;
                break;
            case '_': // Goto last non-blank of the line.
            {
                NSRange old = [hijackedView selectedRange];
                for (int i = 0; i < firstCount; ++i) {
                    [hijackedView moveDown:nil];
                }
                range.location = mv_g__handler(hijackedView);
                [hijackedView setSelectedRange:old];
            }
                break;
        }
        
    } else if (cmdChar == 'i' || cmdChar == 'a') // Text objects.
    {
        switch (secondCmdChar) {
            case 'w':
            case 'W': // A word
                range = current_word(hijackedView, firstCount, cmdChar == 'a', secondCmdChar == 'W');
                break;
            case 'B':
            case '{':
            case '}': // A {} block
            {
                // If we are at indent, make the caret after the indent.
                NSUInteger oIdx = [hijackedView selectedRange].location;
                NSUInteger nIdx = mv_caret_handler_h(hijackedView);
                if (nIdx != oIdx) {
                    [hijackedView setSelectedRange:NSMakeRange(nIdx, 0)];
                }
                range = current_block(hijackedView, firstCount, cmdChar == 'a', '{', '}');
                if (range.location == NSNotFound && nIdx != oIdx) {
                    [hijackedView setSelectedRange:NSMakeRange(oIdx, 0)];
                }
            }
                break;
            case 'b':
            case '(':
            case ')': // A () block
                range = current_block(hijackedView, firstCount, cmdChar == 'a', '(', ')');
                break;
            case '[':
            case ']': // A [] block
                range = current_block(hijackedView, firstCount, cmdChar == 'a', '[', ']');
                break;
            case '<':
            case '>': // A <> block
                range = current_block(hijackedView, firstCount, cmdChar == 'a', '<', '>');
                break;
                
            case 't':  // A xml tag block
                range = current_tagblock(hijackedView, firstCount, cmdChar == 'a');
                break;
            case '"':  // A double quoted string
            case '\'': // A single quoted string
            case '`':  // A backtick quoted string
                range = current_quote(hijackedView, firstCount, cmdChar == 'a', secondCmdChar);
                break;
                
            default:
                break;
        }
    } else // Normal motion commands.
    {
        switch (cmdChar)
        {
            case 'f' | XMaskControl:
            case 'b' | XMaskControl:
            case 'd' | XMaskControl:
            case 'u' | XMaskControl:
                // Scrolls
                if (operatorChar == 0) {
                    range.location = [self cmdScroll];
                }
                break;
            case 'H':
            case 'M':
            case 'L':
                range.location = [self cmdHML];
                defaultLineWise = YES;
                break;
            case 'G': 
                range.location = [self cmdGoto:cmdCountSpecified];
                ensureVisible   = YES;
                defaultLineWise = YES;
                break;
            case '|': // Go to column
                range.location = columnToIndex(hijackedView, firstCount);
                break;
            case '%':
                range.location = mv_percent_handler(hijackedView);
                ensureVisible = YES;
                break;
            case '$':
                range.location = mv_dollar_handler(hijackedView);
                break;
            case '0':
#ifndef MAKE_0_AS_CARET
                range.location = mv_0_handler_h(hijackedView);
                break;
#endif
            case '^':
            case 'I':
                range.location = mv_caret_handler_h(hijackedView);
                break;
                
            case '_':
            case '-': // First non-blank prev line.
            case '+': // First non-blank next line.
            case NSCarriageReturnCharacter:
                range.location  = [self cmdSOL];
                ensureVisible   = YES;
                defaultLineWise = YES;
                break;
                
            case 'w': 
            case 'W':
                range.location = operatorChar == 0 ? 
                mv_w_handler(hijackedView, firstCount, cmdChar == 'W') :
                mv_w_motion_handler(hijackedView, firstCount, cmdChar == 'W');
                ensureVisible = YES;
                break;
                
            case 'e':
            case 'E':
                range.location = mv_e_handler(hijackedView, firstCount, cmdChar == 'E');
                if (operatorChar != 0) { ++range.location; }
                ensureVisible = YES;
                break;
            case 'b':
            case 'B':
                range.location = mv_b_handler(hijackedView, firstCount, cmdChar == 'B');
                ensureVisible = YES;
                break;
                
            case NSDeleteCharacter:
            case 'h': range.location = mv_h_handler(hijackedView, firstCount);
                break;
                
            case XSpace:
            case 'l': range.location = mv_l_handler(hijackedView, firstCount, operatorChar == 0);  
                break;
                
            case 'j': 
            {
                NSRange old = [hijackedView selectedRange];
                for (int i = 0; i < firstCount; ++i) { [hijackedView moveDown:nil]; }  
                NSRange n   = [hijackedView selectedRange];
                if (old.location != n.location) {
                    range.location = n.location;
                    [hijackedView setSelectedRange:old];
                }
                defaultLineWise = YES;
            }
                break;
            case 'k': 
            {
                NSRange old = [hijackedView selectedRange];
                for (int i = 0; i < firstCount; ++i) { [hijackedView moveUp:nil]; }  
                NSRange n   = [hijackedView selectedRange];
                if (old.location != n.location) {
                    range.location = n.location;
                    [hijackedView setSelectedRange:old];
                }
                defaultLineWise = YES;
            }
        }
    }

    if (visible)  { *visible  = ensureVisible;   }
    if (linewise) { *linewise = defaultLineWise; }
    return range;
}

-(BOOL) executeCMD
{
    // ===== Special handle for yy / dd / cc
    if (cmdChar == secondCmdChar)
    {
        if (firstCount == -1)  { firstCount = 1; }
        if (secondCount != -1) { firstCount *= secondCount; }
        switch (cmdChar) {
            case 'c':
            case 'd': [self cmdddcc]; return YES;
            case 'y': cmdChar = 'Y'; [self cmdYDC]; return YES;
        }
    }
    
    // ===== Finds out the range.
    BOOL    ensureVisible   = NO;
    BOOL    defaultLineWise = NO;
    NSRange range = [self generateRange:&ensureVisible
                        defaultLinewise:&defaultLineWise];
    
    // ===== The command is not supported.
    if (range.location == NSNotFound) {
        return NO;
    }
    
    // ===== The command doesn't change anything.
    if (range.length == 0 && 
        range.location == [hijackedView selectedRange].location)
    {
        return YES;
    }
    
    // ===== Deal with normal command.
    if (operatorChar == 0)
    {
        // This simply moves the caret.
        [hijackedView setSelectedRange:range];
        if (ensureVisible) {
            [hijackedView scrollRangeToVisible:range];
        }
        
        return YES;
    }
    
    // ===== Deal with operators.
    NSInteger motionBegin = -1;
    NSInteger motionEnd   = -1;
    
    if (range.length == 0)
    {
        // The range only specified the new caret position.
        // Calc the real range here.
        
        NSUInteger currentIdx = [hijackedView selectedRange].location;
        if (currentIdx > range.location)
        {
            motionBegin = range.location;
            motionEnd   = currentIdx;
        } else {
            motionBegin = currentIdx;
            motionEnd   = range.location;
        }
    } else {
        motionBegin = range.location;
        motionEnd   = range.location + range.length;
    }
    
    NSString* string = [hijackedView string];
    
    // Check linewise and characterwise (We don't support block wise)
    if (affect == LineWise) {
        defaultLineWise = YES;
    } else if (affect == CharacterWise) {
        defaultLineWise = NO;
    }
    if (defaultLineWise)
    {
        motionBegin = mv_0_handler(string, motionBegin);
        motionEnd   = mv_dollar_inc_handler(string, motionEnd);
    }
    
    range.location = motionBegin;
    range.length   = motionEnd - motionBegin;
    
    [controller yank:string withRange:range wholeLine:defaultLineWise];
    if (operatorChar != 'y') {
        if (operatorChar == 'c') { dontCheckTrailingCR = YES; }
        [hijackedView insertText:@"" replacementRange:range];
        if (operatorChar == 'c') { [controller switchToMode:InsertMode]; }
    }
        
    return YES;
}

-(BOOL) executeNormalCMD
{
    if (firstCount == -1) { firstCount = 1; }
    
    switch (cmdChar)
    {
        case 'J': [self cmdJoin]; break;
        case '~': [self cmdChangeCase]; break;
            
        case 'Y':
        case 'D':
        case 'C':
            [self cmdYDC];
            break;

        case 'X':
        case 'x':
            [self cmdDelChar];
            break;
            
        case 'O':
        case 'o':
            [self cmdOpenNewline];
            break;
            
        case 'p':
        case 'P':
            [self cmdPaste];
            break;
            
        case 'A':
            dontCheckTrailingCR = YES;
            [hijackedView moveToEndOfLine:nil];
            [controller switchToMode:InsertMode];
            break;
        case 'I':
            [hijackedView setSelectedRange: NSMakeRange(mv_caret_handler_h(hijackedView), 0)];
            [controller switchToMode:InsertMode];
            break;
            
        case 'a':
        {
            NSString*  string = [hijackedView string];
            NSUInteger idx    = [hijackedView selectedRange].location;
            NSUInteger max    = [string length];
            if (idx < max && !testNewLine([string characterAtIndex:idx]))
            {
                dontCheckTrailingCR = YES;
                [hijackedView moveRight:nil];
            }
            [controller switchToMode:InsertMode];
        }
            break;
        case 'i':
            [controller switchToMode:InsertMode];
            break;
            
#ifdef U_AS_REDO
        case 'U': // Redo
#else
        case 'r' | XMaskControl: // Redo
#endif
            for (int i = 0; i < firstCount; ++i) { [[hijackedView undoManager] redo]; } 
            break;
        case 'u': // Undo
            for (int i = 0; i < firstCount; ++i) { [[hijackedView undoManager] undo]; } 
            break;
            
        case 'r':
        case 'R': [controller switchToMode:ReplaceMode 
                                   subMode:(cmdChar == 'r' ? SingleReplaceMode : NoSubMode)];
            break;
            
        case 'z':
            [self cmdPlaceLine];
            break;
    }
    
    return YES;
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
    
    firstCount = firstCount > 2 ? firstCount - 1 : 1;
    
    [undoManager beginUndoGrouping];
    
    for (int i = 0; i < firstCount; ++i)
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

-(void) cmdYDC
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
            --firstCount;
            if (firstCount == 0) { break; }
        }
        ++lineEnd;
    }
    
    NSUInteger lineBegin = cmdChar == 'Y' ? mv_0_handler(string, current) : current;
    NSRange    range     = {lineBegin, lineEnd - lineBegin};
    [controller yank:string 
           withRange:range 
           wholeLine:(cmdChar == 'Y')];
    
    if (cmdChar == 'C')
    {
        dontCheckTrailingCR = YES;
        [hijackedView insertText:@"" replacementRange:range];
        [controller switchToMode:InsertMode];
    } else if(cmdChar == 'D')
    {
        [hijackedView insertText:@"" replacementRange:range];
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
        if (firstCount > 1)
        {
            NSUInteger lineEndIndex = mv_dollar_handler(hijackedView) + 1;
            length = lineEndIndex - index;
            if (length > firstCount) { length = firstCount; }
        }
        
        NSRange range = {index, length};
        NSMutableString* subString = [NSMutableString stringWithString:[string substringWithRange:range]];
        NSRange r = {0,1};
        
        for (; r.location < length; ++r.location) 
        {
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

-(void) cmdDelChar
{
    NSString* string = [hijackedView string];
    NSInteger index  = [hijackedView selectedRange].location;
    NSRange   range  = {0, 0};
    
    if (cmdChar == 'x')
    {
        NSUInteger maxIndex = [string length] - 1;
        
        if (index <= maxIndex)
        {
            range.location = index;
            range.length   = firstCount;
        } 
    } else {
        
        NSUInteger rIndex = index > firstCount ? index - firstCount : 0;
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

-(void) cmdOpenNewline
{
    BOOL isAfter = cmdChar == 'o';
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

-(void) cmdPaste
{
    BOOL wholeLine = NO;
    NSString* yankContent = [controller yankContent:&wholeLine];
    if (yankContent != nil)
    {
        dontCheckTrailingCR = YES;
        if (wholeLine)
        {
            if (cmdChar == 'p') {
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
        } else if (cmdChar == 'p') { 
            [hijackedView moveRight:nil];
        }
        
        NSRange currentIndex = [hijackedView selectedRange];
        
        for (int i = 0; i < firstCount; ++i) {
            [hijackedView insertText:yankContent];
            if (wholeLine) {
                [hijackedView setSelectedRange:currentIndex];
            }
        }
    }
}

-(void) cmdPlaceLine
{
    switch (secondCmdChar) {
        case 't':
        case 'b':
        case 'z': break;
        default: return;
    }
    
    NSLayoutManager* manager = [hijackedView layoutManager];
    NSRange range = [hijackedView selectedRange];
    range.length = 1;
    range = [manager glyphRangeForCharacterRange:range actualCharacterRange:nil];
    
    NSRect caretRect   = [manager boundingRectForGlyphRange:range 
                                            inTextContainer:[hijackedView textContainer]];
    
    NSRect visibleRect = [hijackedView visibleRect];
    
    if (secondCmdChar == 't') {
        visibleRect.origin.y = caretRect.origin.y;
    } else if (secondCmdChar == 'b') {
        visibleRect.origin.y = caretRect.origin.y + caretRect.size.height - 
        visibleRect.size.height;
    } else {
        visibleRect.origin.y = caretRect.origin.y - visibleRect.size.height / 2;
    }
    
    if (visibleRect.origin.y < 0) { visibleRect.origin.y = 0; }
    [self scrollViewRectToVisible:visibleRect];
}

-(NSUInteger) cmdScroll
{
    // Ctrl + f one page forward
    // Ctrl + b one page backward
    // Ctrl + d half screen down
    // Ctrl + u harf screen up
    NSRect    currentRect = [hijackedView visibleRect];
    NSSize    viewSize    = [hijackedView frame].size;
    NSInteger scrollToY   = 0;
    NSInteger delta       = currentRect.size.height;
    
    NSUInteger ch = cmdChar & XUnicharMask;
    
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
        
        NSUInteger newIdx = [hijackedView characterIndexForInsertionAtPoint:
                             NSMakePoint(0, caretYInScreen + currentRect.origin.y + delta)];
        newIdx = mv_caret_handler([hijackedView string], newIdx);
        
        // Scroll
        currentRect.origin.y = scrollToY;
        [self scrollViewRectToVisible:currentRect];
        
        return newIdx;
    }
    
    return [hijackedView selectedRange].location;
}

-(NSUInteger) cmdHML
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
    
    
    if (cmdChar == 'M') {
        rect.origin.y += rect.size.height / 2;
    } else if (cmdChar == 'L') {
        rect.origin.y += rect.size.height - caretRect.size.height / 2;
    } else {
        rect.origin.y += caretRect.size.height / 2;
    }
    
    selection.location = [manager characterIndexForPoint:NSMakePoint(rect.origin.x, rect.origin.y) 
                                         inTextContainer:container
                fractionOfDistanceBetweenInsertionPoints:&fraction];
    
    if (selection.location != NSNotFound)
    {
        selection.location = mv_caret_handler([hijackedView string], selection.location);
    }
    
    return selection.location;
}

-(NSUInteger) cmdGoto:(BOOL) ccSpecified
{
    NSInteger  lineNumber = ccSpecified ? firstCount - 1 : -1;
    NSUInteger idx = 0;
    
    if (lineNumber > 0)
    {
        idx = [hijackedView accessibilityCharacterRangeForLineNumber:lineNumber].location;
        if (idx == 0 && lineNumber != 0) 
        {
            // The lineNumber is not valid,
            // We move it to the last line.
            lineNumber = -1;
        }
    }
    
    NSString* string = [hijackedView string];
    
    if (lineNumber == -1)
    {
        // Goto last line
        NSUInteger maxIndex = [string length];
        if (testNewLine([string characterAtIndex:maxIndex - 1]) == NO)
            --maxIndex;
        idx = maxIndex;
    }
    
    idx = mv_caret_handler(string, idx);
    return idx;
}

-(void) cmdddcc
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
                --firstCount;
                if (firstCount == 0) { break; }
            }
            ++lineEnd;
        }
        
        // We need to include a new line character if there's any.
        if (cmdChar == 'd' && testNewLine(characterAtIndex(h, lineEnd))) {
            ++lineEnd;
        }
        
        NSUInteger lineBegin = mv_0_handler_h(hijackedView);
        NSRange    range     = {lineBegin, lineEnd - lineBegin};
        
        [controller yank:string withRange:range wholeLine:YES];
        
        [hijackedView insertText:@"" replacementRange:range];
        if (cmdChar == 'c') { [controller switchToMode:InsertMode]; }
    }
}

-(NSUInteger) cmdSOL
{
    NSUInteger oldIdx = [hijackedView selectedRange].location;
    
    if (cmdChar == '_') { --firstCount; }
    
    for (int i = 0; i < firstCount; ++i)
    {
        NSUInteger idx = [hijackedView selectedRange].location;
        cmdChar == '-' ? [hijackedView moveUp:nil] : [hijackedView moveDown:nil];
        if (idx == [hijackedView selectedRange].location)
        {
            break;
        }
    }
    
    NSUInteger newIdx = mv_caret_handler_h(hijackedView);
    [hijackedView setSelectedRange:NSMakeRange(oldIdx, 0)];
    
    return newIdx == oldIdx ? NSNotFound : newIdx;
}
@end