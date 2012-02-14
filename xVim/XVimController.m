//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "XVimController.h"
#import "XVimMode.h"
#import "XTextViewBridge.h"
#import "vim.h"

// Kill buffer
NSMutableString* killBuffer = nil;
BOOL             killBufferIsWholeLine = NO;

// Key mapping dicts
static NSMutableDictionary* keyMapDicts[VimModeCount] = {nil};
static NSDictionary*        specialKeys               = nil;


NSArray* keyStringTokeyArray(NSString* string);
NSArray* keyStringTokeyArray(NSString* string)
{
    NSMutableArray* keyArray = [[NSMutableArray alloc] init];
    
    DLog(@"KeyString: %@", string);
    int keyBeginIndex = 0;
    int keyEndIndex   = 0;
    NSUInteger strLen = [string length];
    
    while (keyBeginIndex < strLen)
    {
        unichar bch = [string characterAtIndex:keyBeginIndex];
        
        if (bch == '<')
        {
            ++keyEndIndex;
            while (keyEndIndex < strLen) {
                unichar ch = [string characterAtIndex:keyEndIndex];
                if (ch == '<') {
                    keyEndIndex = keyBeginIndex;
                    break;
                } else if (ch == '>') {
                    break;
                }
                ++keyEndIndex;
            }
            if (keyEndIndex == strLen) { keyEndIndex = keyBeginIndex; }
        }
        
        if (keyBeginIndex == keyEndIndex)
        {
            [keyArray addObject:[NSNumber numberWithUnsignedLong:bch]];
            
        } else if(keyBeginIndex + 1 < keyEndIndex)
        {
            NSString* subStr = [string substringWithRange:NSMakeRange(keyBeginIndex+1, 
                                                                     keyEndIndex - keyBeginIndex - 1)];
            NSMutableString* m = [NSMutableString stringWithString:subStr];
            
            NSUInteger key = 0;
            NSRange    range = [m rangeOfString:@"C-"];
            if (range.location != NSNotFound) {
                key |= NSControlKeyMask;
                [m deleteCharactersInRange:range];
            }
            
            range = [m rangeOfString:@"D-"];
            if (range.location != NSNotFound) {
                key |= NSCommandKeyMask;
                [m deleteCharactersInRange:range];
            }
            
            range = [m rangeOfString:@"M-"];
            if (range.location != NSNotFound) {
                key |= NSAlternateKeyMask;
                [m deleteCharactersInRange:range];
            }
            
            range = [m rangeOfString:@"S-"];
            if (range.location != NSNotFound) {
                key |= NSShiftKeyMask;
                [m deleteCharactersInRange:range];
            }
            
            if ([m length] == 1) {
                key |= [m characterAtIndex:0];
                [keyArray addObject:[NSNumber numberWithUnsignedLong:key]];
            } else {
                NSNumber* keyCode = [specialKeys objectForKey:m];
                if (keyCode != nil)
                {
                    unichar keyCodePlain = [keyCode unsignedShortValue];
                    key |= keyCodePlain;
                    if (keyCodePlain >= NSUpArrowFunctionKey &&
                        keyCodePlain <= NSModeSwitchFunctionKey)
                    {
                        key |= NSFunctionKeyMask;
                        if (keyCodePlain <= NSRightArrowFunctionKey) {
                            key |= NSNumericPadKeyMask;
                        }
                    }
                    [keyArray addObject:[NSNumber numberWithUnsignedLong:key]];
                }
            }
            
        }
        
        ++keyEndIndex;
        keyBeginIndex = keyEndIndex;
    }
    
    return keyArray;
}

@interface XVimController()
{
    @private
        XTextViewBridge*  bridge;
    
        VimMode           vi_mode;
        XVimModeHandler*  handlers[VimModeCount];
    
        // This buffer contains all the keys that we have to process.
        // inputBuffer and currentKeyEvent is mutal-exclusive.
        // That is if inputBuffer is empty, currentKeyEvent must not be nil. Vice versa.
        NSMutableArray*  inputBuffer;
        // If currentKeyEvent is nil, then currentKey holds the key value
        // that we are processing.
        NSEvent*         currentKeyEvent;
        NSUInteger       currentKey;
    
        BOOL             timerStarted;
}

-(void) processBuffer;
// Generate a fake key event based on the value of currentKey
-(NSEvent*) generateFakeEvent;
-(void) stopKeymapTimer;
-(void) startKeymapTimer;
-(BOOL) isKeymapPrefix:(NSArray*) keys;
@end



@implementation XVimController

-(void) finalize { 
    if (timerStarted) { [self stopKeymapTimer]; }
    [super finalize];
}

+(void) load 
{
    killBuffer = [[NSMutableString alloc] init];
    
    specialKeys = [[NSDictionary alloc] initWithObjectsAndKeys:
                   [NSNumber numberWithInt:NSDeleteCharacter],         @"BS",
                   [NSNumber numberWithInt:NSTabCharacter],            @"Tab",
                   [NSNumber numberWithInt:NSCarriageReturnCharacter], @"CR",
                   [NSNumber numberWithInt:NSEnterCharacter],          @"Enter",
                   [NSNumber numberWithInt:27],                        @"Esc",
                   [NSNumber numberWithInt:' '],                       @"Space",
                   [NSNumber numberWithInt:NSUpArrowFunctionKey],      @"Up",
                   [NSNumber numberWithInt:NSDownArrowFunctionKey],    @"Down",
                   [NSNumber numberWithInt:NSLeftArrowFunctionKey],    @"Left",
                   [NSNumber numberWithInt:NSRightArrowFunctionKey],   @"Right",
                   [NSNumber numberWithInt:NSF1FunctionKey],           @"F1",
                   [NSNumber numberWithInt:NSF2FunctionKey],           @"F2",
                   [NSNumber numberWithInt:NSF3FunctionKey],           @"F3",
                   [NSNumber numberWithInt:NSF4FunctionKey],           @"F4",
                   [NSNumber numberWithInt:NSF5FunctionKey],           @"F5",
                   [NSNumber numberWithInt:NSF6FunctionKey],           @"F6",
                   [NSNumber numberWithInt:NSF7FunctionKey],           @"F7",
                   [NSNumber numberWithInt:NSF8FunctionKey],           @"F8",
                   [NSNumber numberWithInt:NSF9FunctionKey],           @"F9",
                   [NSNumber numberWithInt:NSF10FunctionKey],          @"F10",
                   [NSNumber numberWithInt:NSF11FunctionKey],          @"F11",
                   [NSNumber numberWithInt:NSF12FunctionKey],          @"F12",
                   [NSNumber numberWithInt:NSInsertCharFunctionKey],   @"Insert",
                   [NSNumber numberWithInt:NSDeleteFunctionKey],       @"Del",
                   [NSNumber numberWithInt:NSHomeFunctionKey],         @"Home",
                   [NSNumber numberWithInt:NSEndFunctionKey],          @"End",
                   [NSNumber numberWithInt:NSPageUpFunctionKey],       @"PageUp",
                   [NSNumber numberWithInt:NSPageDownFunctionKey],     @"PageDown",
                   nil];
    
    // Read the key mapping.
    // The key mapping syntax is like: {[niv]} {originalKey} {mappedKey}
    NSString* keymapPath = [[NSBundle bundleWithIdentifier:@"com.warwithinme.xvim"] pathForResource:@"keymap" ofType:nil];
    NSString* keymapData = [[NSString alloc] initWithContentsOfFile:keymapPath 
                                                           encoding:NSUTF8StringEncoding
                                                              error:nil];
    NSArray*  keymapLines = [keymapData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if (keymapLines != nil && [keymapLines count] > 0)
    {
        keyMapDicts[InsertMode]  = [[NSMutableDictionary alloc] init];
        keyMapDicts[NormalMode]  = [[NSMutableDictionary alloc] init];
        keyMapDicts[VisualMode]  = [[NSMutableDictionary alloc] init];
        keyMapDicts[ReplaceMode] = [[NSMutableDictionary alloc] init];
        
        for (NSString* line in keymapLines)
        {
            NSArray* map = [line componentsSeparatedByString:@" "];
            int mode = NormalMode;
            if (3 <= [map count])
            {
                switch ([[map objectAtIndex:0] characterAtIndex:0]) {
                    case 'i': mode = InsertMode; break;
                    case 'n': mode = NormalMode; break;
                    case 'v': mode = VisualMode; break;
                    case 'r': mode = ReplaceMode; break;
                }
                [keyMapDicts[mode] setObject:keyStringTokeyArray([map objectAtIndex:2]) 
                                      forKey:keyStringTokeyArray([map objectAtIndex:1])];
            }
        }
        
        DLog(@"Insert mode dict %@", keyMapDicts[InsertMode]);
    }
    [keymapData release];
}

-(XVimController*) initWithBridge:(XTextViewBridge*) b
{
    if (self = [super init]) {
        bridge = b;
        vi_mode = NormalMode;
        inputBuffer = [[NSMutableArray alloc] init];
        
        handlers[NormalMode] = [[XVimNormalModeHandler alloc] initWithController:self];
        handlers[VisualMode] = [[XVimVisualModeHandler alloc] initWithController:self];
        handlers[InsertMode] = [[XVimInsertModeHandler alloc] initWithController:self];
        handlers[ExMode]     = [[XVimExModeHandler alloc] initWithController:self];
        handlers[ReplaceMode] = [[XVimReplaceModeHandler alloc] initWithController:self];
    }
    return self;
}

-(void) dealloc
{
    [inputBuffer release];
    for (int i = 0; i < VimModeCount; ++i) { [handlers[i] release]; }
}

-(NSString*) yankContent:(BOOL*)isWholeLine 
{ 
    if (isWholeLine) { *isWholeLine = killBufferIsWholeLine; }
    return killBuffer;
}
-(void) yank:(NSString*)string withRange:(NSRange)range wholeLine:(BOOL)flag
{
    [killBuffer setString:[string substringWithRange:range]];
    if (flag && testNewLine([killBuffer characterAtIndex:[killBuffer length] - 1]) == NO) {
        [killBuffer appendString:@"\n"];
    }
    killBufferIsWholeLine = flag;
}

@synthesize bridge;

-(VimMode) mode { return vi_mode; }
-(void) switchToMode:(VimMode)mode
{
    [self switchToMode:mode subMode:NoSubMode];
}

-(void) switchToMode:(VimMode)mode subMode:(VimMode)sub
{
    NSAssert(mode < VimModeCount, @"The vim mode is wrong");
    if (vi_mode == mode) { return; }
    
    [handlers[vi_mode] reset];
    
    // Check to see if we should notify the textview that it should
    // redraw the caret immediately
    BOOL needToRedrawCaret = (0 == (mode & vi_mode) || // Either mode is InsertMode
                              (vi_mode < ReplaceMode && mode >= ReplaceMode) ||
                              (vi_mode >= ReplaceMode && mode < ReplaceMode));
    vi_mode = mode;
    if (needToRedrawCaret) {
        [[bridge targetView] updateInsertionPointStateAndRestartTimer:YES];
    }
    
    [handlers[vi_mode] enterWith:sub];
}

-(void) processBuffer
{
    if (currentKeyEvent != nil)
    {
        // Process the currentKeyEvent.
        unichar    ch   = [[currentKeyEvent charactersIgnoringModifiers] characterAtIndex:0];
        NSUInteger flag = [currentKeyEvent modifierFlags];
        if ((flag & XMaskCapLock) && ch >= 'a' && ch <= 'z') { ch = ch + 'A' - 'a'; }
        
        BOOL handled = [handlers[vi_mode] processKey:ch
                                           modifiers:(flag & XModifierFlagsMask)];
        if (handled == NO)
            [bridge handleFakeKeyEvent:currentKeyEvent];
        
        currentKeyEvent = nil;
    } else {
        // Process the buffer.
        for (NSNumber* key in inputBuffer)
        {
            currentKey = [key unsignedIntegerValue];
            BOOL handled = [handlers[vi_mode] processKey:(currentKey & XUnicharMask) 
                                               modifiers:(currentKey & XModifierFlagsMask)];
            // The key is not handled, ask the NSTextView to handle it.
            if (handled == NO)
                [bridge handleFakeKeyEvent:[self generateFakeEvent]];
        }
        currentKey = 0;
    }
    [inputBuffer removeAllObjects];
}

-(NSEvent*) generateFakeEvent
{
    unichar ch = (currentKey & XUnicharMask);
    NSString* characters = [NSString stringWithCharacters:&ch length:1];
    
    return [NSEvent keyEventWithType:NSKeyDown 
                            location:NSMakePoint(0, 0)
                       modifierFlags:(currentKey & XModifierFlagsMask)
                           timestamp:0
                        windowNumber:0
                             context:nil
                          characters:characters
         charactersIgnoringModifiers:characters
                           isARepeat:NO 
                             keyCode:0];
}

-(void) processKeyEvent:(NSEvent*) event
{
    // Whenever the buffer is not empty, the currentKeyEvent should be nil.
    if (timerStarted) { [self stopKeymapTimer]; }
    
    
    NSString* key = [event charactersIgnoringModifiers];
    if ([key length] == 0) { return; }
    
    unichar    ch   = [key characterAtIndex:0];
    NSUInteger flag = [event modifierFlags];
    if ((flag & XMaskCapLock) && ch >= 'a' && ch <= 'z') { ch = ch + 'A' - 'a'; }
    
    NSUInteger keyCode = (flag & XModifierFlagsMaskX) | ch;
    DLog(@"KeyCode: %lu, Flags: %lu, Char: %C(%i), The Event:%@", keyCode, flag, ch, ch, event);
    
    NSMutableDictionary* dict = keyMapDicts[vi_mode];
    if (dict != nil && [handlers[vi_mode] forceIgnoreKeymap] == NO)
    {
        // When there's a key input, we do these checking:
        // 1. If the buffer is empty:
        //    1). Key is a prefix of a keymap, put it into the buffer.
        //    2). Key is not a prefix but a keymap, traslate and process it.
        //    3). Key is not a prefix nor a keymap, process it.
        // 2. If the buffer is not empty:
        //    1). [buffer + key] is a prefix, append the key to the buffer.
        //    2). [buffer + key] is not a prefix but a keymap, traslate and process it.
        //    3). [buffer + key] is not a prefix nor a keymap, but buffer is a keymap, traslate and
        //        process buffer, otherwise, abandon buffer and then go back to 1.
        
        if ([inputBuffer count] > 0)
        {
            NSArray* newBuffer = [inputBuffer arrayByAddingObject:[NSNumber numberWithUnsignedLong:keyCode]];
            if ([self isKeymapPrefix:newBuffer])
            {
                DLog(@"Inputbuffer and new input is a prefix");
                // The key is a prefix of a keymap, wait for another input of timeout.
                [inputBuffer setArray:newBuffer];
                [self startKeymapTimer];
                return;
            }
            
            NSArray* mappedKey = [dict objectForKey:newBuffer];//[self findMappedKey:newBuffer];
            if (mappedKey != nil)
            {
                DLog(@"InputBuffer and new input is a keymap");
                [inputBuffer setArray:mappedKey];
                [self processBuffer];
                return;
            }
            
            mappedKey = [dict objectForKey:inputBuffer];//[self findMappedKey:inputBuffer];
            if (mappedKey != nil) {
                DLog(@"InputBuffer is a keymap"); 
                [inputBuffer setArray:mappedKey];
            }
            [self processBuffer];
        }
        
        [inputBuffer addObject:[NSNumber numberWithUnsignedLong:keyCode]];
        if ([self isKeymapPrefix:inputBuffer])
        {
            DLog(@"Input is a prefix");
            [self startKeymapTimer];
        } else
        {
            NSArray* mappedKey = [dict objectForKey:inputBuffer];//[self findMappedKey:inputBuffer];
            if (mappedKey != nil) {
                DLog(@"Input is a keymap");
                [inputBuffer setArray:mappedKey];
                [self processBuffer];
            } else {
                // The key input is not a keymap prefix nor a keymap,
                // We should handle it directly.
                currentKeyEvent = event;
                [self processBuffer];
            }
        }
        
    } else {
        currentKeyEvent = event;
        [self processBuffer];
    }
}

-(void) stopKeymapTimer
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    timerStarted = NO;
}

-(void) startKeymapTimer
{
    if (timerStarted) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    }
    
    [self performSelector:@selector(processBuffer) 
               withObject:self 
               afterDelay:(double)VIM_KEYMAP_TIMEOUT / 1000];
    timerStarted = YES;
}

-(BOOL) isKeymapPrefix:(NSArray*) keys
{
    NSMutableDictionary* dict = keyMapDicts[vi_mode];
    for (NSArray* key in dict)
    {
        NSUInteger keysCount = [keys count];
        if (keysCount < [key count])
        {
            int i = 0;
            for (; i < keysCount; ++i)
            {
                if ([[keys objectAtIndex:i] unsignedLongValue] != 
                    [[key objectAtIndex:i] unsignedLongValue]) {
                    break;
                }
            }
            if (i == keysCount) { return YES; }
        }
    }
    return NO;
}

-(NSArray*) selectionChangedFrom:(NSArray*)oldRanges to:(NSArray*)newRanges
{
    return [handlers[vi_mode] selectionChangedFrom:oldRanges to:newRanges];
}
@end
