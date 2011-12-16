//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XVimController.h"
#import "XVimPlugin.h"
#import "XVimMode.h"

static NSDictionary*        specialKeyName   = 0;
static NSDictionary*        specialKeyCode   = 0;
static NSMutableDictionary* keyMapDicts[4];

@interface XVimController()
{
    @private
        XTextViewBridge* bridge;
        NSMutableString* inputBuffer;
    
        VimMode vi_mode;
        XVimModeHandler* handlers[6];
    
        NSEvent* currentKeyEvent;
}

// Return YES if the sequence is the prefix of a keymap.
-(BOOL) isKeymapPrefix:(NSString*) sequence;

// Translate the key event to something like <C-BS>
// The returned NSString is autoreleased.
-(NSString*) normalizeEvent:(NSEvent*) event;

-(void) stopKeymapTimer;
-(void) startKeymapTimer;

-(void) processBuffer;
-(void) processKey:(NSString*) key;
@end

@implementation XVimController

+(void) setup
{    
    specialKeyName = [[NSDictionary alloc] initWithObjectsAndKeys:
                      @"BS",     [NSNumber numberWithInt:NSDeleteCharacter],
                      @"Tab",    [NSNumber numberWithInt:NSTabCharacter],
                      @"CR",     [NSNumber numberWithInt:NSCarriageReturnCharacter],
                      @"Enter",  [NSNumber numberWithInt:NSEnterCharacter],
                      @"Esc",    [NSNumber numberWithInt:27],
                      @"Space",  [NSNumber numberWithInt:' '],
                      @"Up",     [NSNumber numberWithInt:NSUpArrowFunctionKey],
                      @"Down",   [NSNumber numberWithInt:NSDownArrowFunctionKey],
                      @"Left",   [NSNumber numberWithInt:NSLeftArrowFunctionKey],
                      @"Right",  [NSNumber numberWithInt:NSRightArrowFunctionKey],
                      @"F1",     [NSNumber numberWithInt:NSF1FunctionKey],
                      @"F2",     [NSNumber numberWithInt:NSF2FunctionKey],
                      @"F3",     [NSNumber numberWithInt:NSF3FunctionKey],
                      @"F4",     [NSNumber numberWithInt:NSF4FunctionKey],
                      @"F5",     [NSNumber numberWithInt:NSF5FunctionKey],
                      @"F6",     [NSNumber numberWithInt:NSF6FunctionKey],
                      @"F7",     [NSNumber numberWithInt:NSF7FunctionKey],
                      @"F8",     [NSNumber numberWithInt:NSF8FunctionKey],
                      @"F9",     [NSNumber numberWithInt:NSF9FunctionKey],
                      @"F10",    [NSNumber numberWithInt:NSF10FunctionKey],
                      @"F11",    [NSNumber numberWithInt:NSF11FunctionKey],
                      @"F12",    [NSNumber numberWithInt:NSF12FunctionKey],
                      @"Insert", [NSNumber numberWithInt:NSInsertCharFunctionKey],
                      @"Del",    [NSNumber numberWithInt:NSDeleteFunctionKey],
                      @"Home",   [NSNumber numberWithInt:NSHomeFunctionKey],
                      @"End",    [NSNumber numberWithInt:NSEndFunctionKey],
                      @"PageUp", [NSNumber numberWithInt:NSPageUpFunctionKey],
                      @"PageDown", [NSNumber numberWithInt:NSPageDownFunctionKey],
                      nil];
    
    specialKeyCode = [[NSDictionary alloc] initWithObjectsAndKeys:
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
        keyMapDicts[InsertMode] = [[NSMutableDictionary alloc] init];
        keyMapDicts[NormalMode] = [[NSMutableDictionary alloc] init];
        keyMapDicts[VisualMode] = [[NSMutableDictionary alloc] init];
        keyMapDicts[ExMode] = nil;
        
        for (NSString* line in keymapLines)
        {
            NSArray* map = [line componentsSeparatedByString:@" "];
            int mode = NormalMode;
            if (3 == [map count])
            {
                switch ([[map objectAtIndex:0] characterAtIndex:0]) {
                    case 'i': mode = InsertMode; break;
                    case 'n': mode = NormalMode; break;
                    case 'v': mode = VisualMode; break;
                }
                [keyMapDicts[mode] setObject:[map objectAtIndex:2] forKey:[map objectAtIndex:1]];
            }
        }
    }
    [keymapData release];
}

+(NSEvent*) fakeEventFor:(NSString*) key
{
    if ([key length] == 0) { return nil; }
    
    unsigned int modifiers = 0;
    NSMutableString* parseKey = [NSMutableString stringWithString:key];
    if ([parseKey characterAtIndex:0] == '<') {
        [parseKey deleteCharactersInRange:NSMakeRange(0, 1)];
        [parseKey deleteCharactersInRange:NSMakeRange([parseKey length]-1, 1)];
    }
    if ([parseKey hasPrefix:@"C-"]) {
        modifiers |= NSControlKeyMask;
        [parseKey deleteCharactersInRange:NSMakeRange(0, 2)];
    }
    if ([parseKey hasPrefix:@"D-"]) {
        modifiers |= NSCommandKeyMask;
        [parseKey deleteCharactersInRange:NSMakeRange(0, 2)];
    }
    if ([parseKey hasPrefix:@"M-"]) {
        modifiers |= NSAlternateKeyMask;
        [parseKey deleteCharactersInRange:NSMakeRange(0, 2)];
    }
    
    if ([parseKey length] != 1)
    {
        NSNumber* keyCode = [specialKeyCode objectForKey:parseKey];
        if (keyCode == nil)
        {
            unichar keyCodePlain = [keyCode unsignedLongValue];
            [parseKey setString:[NSString stringWithCharacters:&keyCodePlain length:1]];
            if (keyCodePlain >= NSUpArrowFunctionKey &&
                keyCodePlain <= NSModeSwitchFunctionKey)
            {
                modifiers |= NSFunctionKeyMask;
                if (keyCodePlain <= NSRightArrowFunctionKey) {
                    modifiers |= NSNumericPadKeyMask;
                }
            }
        }
    }
    
    return [NSEvent keyEventWithType:NSKeyDown 
                            location:NSMakePoint(0, 0)
                       modifierFlags:modifiers
                           timestamp:0
                        windowNumber:0
                             context:nil
                          characters:parseKey
         charactersIgnoringModifiers:parseKey
                           isARepeat:NO 
                             keyCode:0];
}

-(XTextViewBridge*) bridge { return bridge; }

-(XVimController*) initWithBridge:(XTextViewBridge*) b
{
    if (self = [super init]) {
        bridge = b;
        inputBuffer = [[NSMutableString alloc] init];
        
        handlers[NormalMode] = [[XVimNormalModeHandler alloc] init];
        handlers[VisualMode] = [[XVimVisualModeHandler alloc] init];
        handlers[InsertMode] = [[XVimInsertModeHandler alloc] init];
        handlers[ExMode]     = [[XVimExModeHandler alloc] init];
        handlers[ReplaceMode] = [[XVimReplaceModeHandler alloc] init];
        handlers[SingleReplaceMode] = [[ XVimSReplaceModeHandler alloc] init];
    }
    return self;
}

-(void) dealloc
{
    [inputBuffer release];
    
    [handlers[NormalMode] release];
    [handlers[VisualMode] release];
    [handlers[InsertMode] release];
    [handlers[ExMode] release];
    [handlers[ReplaceMode] release];
    [handlers[SingleReplaceMode] release];
}

-(NSEvent*) currentKeyEvent { return currentKeyEvent; }

-(NSString*) normalizeEvent:(NSEvent*) event
{
    NSUInteger flags = [event modifierFlags];
    NSMutableString* normalize = [[NSMutableString alloc] init];
    
    if (flags & NSControlKeyMask) {
        [normalize appendString:@"C-"];
    }
    if (flags & NSCommandKeyMask) {
        [normalize appendString:@"D-"];
    }
    if (flags & NSAlternateKeyMask) {
        [normalize appendString:@"M-"];
    }
    
    BOOL needBracket = [normalize length] > 0;
    
    unichar key = [[event charactersIgnoringModifiers] characterAtIndex:0];
    
    NSString* name = [specialKeyName objectForKey:[NSNumber numberWithUnsignedShort:key]];
    if (name == nil) {
        [normalize appendFormat:@"%c", key];
    } else {
        [normalize appendString:name];
        needBracket = YES;
    }
    
    if (needBracket == YES) {
        [normalize insertString:@"<" atIndex:0];
        [normalize appendString:@">"];
    }
    return [normalize autorelease];
}

-(BOOL) isKeymapPrefix:(NSString*) key
{    
    NSEnumerator* i = [keyMapDicts[vi_mode] keyEnumerator];
    NSString* amap = nil;
    while (amap = [i nextObject]) {
        if ([amap hasPrefix:key] && [amap length] != [key length]) {
            return YES;
        }
    }
    return NO;
}

// In processKeyEvent, we simply examine the key input and the buffer may be a keymap.
-(void) processKeyEvent:(NSEvent*) event
{
    [self stopKeymapTimer];
    currentKeyEvent = event;
    
    NSString* normalizedKey  = [self normalizeEvent:event];
    NSDictionary* keymapDict = keyMapDicts[vi_mode];
    
    // When there's a key input, we do these checking:
    // 0. If the user press Esc, we immediately process the buffer. (TODO)
    // 1. If the buffer is empty:
    //    1). Key is a prefix of a keymap, put it into the buffer.
    //    2). Key is not a prefix but a keymap, traslate and process it.
    //    3). Key is not a prefix nor a keymap, process it.
    //
    // 2. If the buffer is not empty:
    //    1). [buffer + key] is a prefix, append the key to the buffer.
    //    2). [buffer + key] is not a prefix but a keymap, traslate and process it.
    //    3). [buffer + key] is not a prefix nor a keymap, but buffer is a keymap, traslate and
    //        process buffer, otherwise, abandon buffer and then go back to 1.
    
    // In insert mode, if the input is not part of a keymap, then the orignial textview handle
    // that key input.
    
    // In other modes, if we can't handle key inputs with C/D/M modifiers, those inputs are
    // send back to the textview.
    
    if ([inputBuffer length] > 0)
    {
        NSString* newBuffer = [inputBuffer stringByAppendingString:normalizedKey];
        if ([self isKeymapPrefix:newBuffer])
        {
            [inputBuffer appendString:normalizedKey];
            [self startKeymapTimer];
            
            currentKeyEvent = nil;
            return;
        }
        
        newBuffer = [keymapDict objectForKey:newBuffer];
        if (newBuffer != nil)
        {
            [inputBuffer setString:newBuffer];
            
            currentKeyEvent = nil;
            [self processBuffer];
            
            return;
        }
        
        newBuffer = [keymapDict objectForKey:inputBuffer];
        if (newBuffer != nil)
        {
            [inputBuffer setString:newBuffer];
            
            currentKeyEvent = nil; // We we are processing a keymap, the currentKeyEvent is nil.
            [self processBuffer];
        }
    }
    
    if ([self isKeymapPrefix:normalizedKey])
    {
        [inputBuffer appendString:normalizedKey];
        [self startKeymapTimer];
    } else {
        NSString* map = [keymapDict objectForKey:normalizedKey];
        if (map != nil)
        {
            [inputBuffer appendString:map];
            
            currentKeyEvent = nil;
            [self processBuffer];
        } else {
            // The key input is not a keymap prefix nor a keymap.
            currentKeyEvent = event;
            [self processKey:normalizedKey];
            
            NSUInteger modifiers = [event modifierFlags];
            if (modifiers & NSDeviceIndependentModifierFlagsMask)
            {
                // If the key contains any modifiers, let
                // the original text view handle it.
                [bridge handleFakeKeyEvent:event];
            }
        }
    }
    
    currentKeyEvent = nil;
    return;
}

// The buffer might be a key sequence.
-(void) processBuffer
{
    DLog(@"Processing Buffer: %@", inputBuffer);
    int keyBeginIndex = 0;
    int keyEndIndex   = 0;
    NSUInteger bufferLength = [inputBuffer length];
    while (keyBeginIndex < bufferLength)
    {
        if ([inputBuffer characterAtIndex:keyBeginIndex] == '<')
        {
            ++keyEndIndex;
            while (keyEndIndex < bufferLength) {
                unichar ch = [inputBuffer characterAtIndex:keyEndIndex];
                if (ch == '<') {
                    keyEndIndex = keyBeginIndex;
                    break;
                } else if (ch == '>') {
                    break;
                }
                ++keyEndIndex;
            }
            if (keyEndIndex == bufferLength) { keyEndIndex = keyBeginIndex; }
        }
        NSRange range = {keyBeginIndex, keyEndIndex - keyBeginIndex + 1};
        [self processKey:[inputBuffer substringWithRange:range]];
        ++keyEndIndex;
        keyBeginIndex = keyEndIndex;
    }
}

// We break down that buffer and process each of them.
-(void) processKey:(NSString *)key
{
    DLog(@"Process Key: %@", key);
    [handlers[vi_mode] processKey:key For:self];
}

-(void) switchToMode:(VimMode)mode
{
    [handlers[vi_mode] reset];
    vi_mode = mode;
}

-(void) startKeymapTimer{}
-(void) stopKeymapTimer{}
@end
