//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XVimController.h"
#import "XVimPlugin.h"

static NSDictionary* specialKeyName = 0;
static NSMutableDictionary* normalModeKeyMap = 0;
static NSMutableDictionary* insertModeKeyMap = 0;
static NSMutableDictionary* visualModeKeyMap = 0;

typedef enum e_VimMode
{
    NormalMode,
    InsertMode,
    VisualMode,
    ReplaceMode,
    ExMode
} VimMode;

@interface XVimController()
{
    @private
        XTextViewBridge* bridge;
        NSMutableString* inputBuffer;
        VimMode vi_mode;
}


// Return YES if the sequence is the prefix of a keymap.
-(BOOL) isKeymapPrefix:(NSString*) sequence;
// Translate the key event to something like <C-BS>
// The returned NSString is autoreleased.
-(NSString*) normalizeEvent:(NSEvent*) event;
-(NSDictionary*) keymapForCurrentMode;
-(void) switchMode:(VimMode) mode;
-(void) stopKeymapTimer;
-(void) startKeymapTimer;
-(void) processBuffer;
-(BOOL) processKey:(NSString*) key;

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
    
    // Read the key mapping.
    NSString* keymapPath = [[NSBundle bundleWithIdentifier:@"com.warwithinme.xvim"] pathForResource:@"keymap" ofType:nil];
    NSString* keymapData = [[NSString alloc] initWithContentsOfFile:keymapPath 
                                             encoding:NSUTF8StringEncoding
                                             error:nil];
    NSArray*  keymapLines = [keymapData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if (keymapLines != nil && [keymapLines count] > 0) {
        
        normalModeKeyMap = [[NSMutableDictionary alloc] init];
        insertModeKeyMap = [[NSMutableDictionary alloc] init];
        
        for (NSString* line in keymapLines) {
            NSArray* map = [line componentsSeparatedByString:@" "];
            if (3 == [map count]) {
                switch ([[map objectAtIndex:0] characterAtIndex:0]) {
                    case 'i':
                        // Insert mode key map
                        [insertModeKeyMap setObject:[map objectAtIndex:2] forKey:[map objectAtIndex:1]];
                        break;
                    case 'n':
                        [normalModeKeyMap setObject:[map objectAtIndex:2] forKey:[map objectAtIndex:1]];
                        // Normal mode key map
                        break;
                    case 'v':
                        [visualModeKeyMap setObject:[map objectAtIndex:2] forKey:[map objectAtIndex:1]];
                        break;
                }
            }
        }
    }
    [keymapData release];
}

-(XVimController*) initWithBridge:(XTextViewBridge*) b
{
    if (self = [super init]) {
        bridge = b;
        inputBuffer = [[NSMutableString alloc] init];
    }
    return self;
}

-(void) dealloc
{
    [inputBuffer release];
}

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

-(NSDictionary*) keymapForCurrentMode
{
    switch (vi_mode) {
        case NormalMode:
            return normalModeKeyMap;
        case InsertMode:
            return insertModeKeyMap;
        case VisualMode:
            return visualModeKeyMap;
        default:
            return nil;
    }
}

-(BOOL) isKeymapPrefix:(NSString*) key
{    
    NSEnumerator* i = [[self keymapForCurrentMode] keyEnumerator];
    NSString* amap = nil;
    while (amap = [i nextObject]) {
        if ([amap hasPrefix:key] && [amap length] != [key length]) {
            return YES;
        }
    }
    return NO;
}

-(BOOL) processKeyEvent:(NSEvent*) event
{
    [self stopKeymapTimer];
    NSString* normalizedKey  = [self normalizeEvent:event];
    NSDictionary* keymapDict = [self keymapForCurrentMode];
    
    // When there's a key input, we do these checking:
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
        if ([self isKeymapPrefix:newBuffer]) {
            [inputBuffer appendString:normalizedKey];
            [self startKeymapTimer];
            return YES;
        }
        
        newBuffer = [keymapDict objectForKey:newBuffer];
        if (newBuffer != nil) {
            [inputBuffer setString:newBuffer];
            [self processBuffer];
            return YES;
        }
        
        newBuffer = [keymapDict objectForKey:inputBuffer];
        if (newBuffer != nil) {
            [inputBuffer setString:newBuffer];
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
            [self processBuffer];
        } else {
            // The key input is not a keymap prefix nor a keymap.s
            switch (vi_mode)
            {
                case InsertMode:
                    if ([[event characters] characterAtIndex:0] == 27)
                    {
                        // TODO: If there's a popup(e.g. auto-complete popup),
                        // the user might press ESC to hide that popup.
                        [self switchMode:NormalMode];
                    } else {
                        return NO; // Let the original textview to handle the event.
                    }
                    break;
                
                default:
                    if ([self processKey:[event characters]] == NO)
                    {
                        // If we don't handle this key input, but this key input has modifiers.
                        // We let the original textview to handle it.
                        if ([event modifierFlags] & (NSControlKeyMask | NSCommandKeyMask | NSAlternateKeyMask))
                        {
                            return NO;
                        }
                    }
            }
        }
    }
    
    return YES;
}

-(void) processBuffer
{
    DLog(@"Processing Buffer: %@", inputBuffer);
    int keyBeginIndex = 0;
    int keyEndIndex = 1;
    NSUInteger bufferLength = [inputBuffer length];
    while (keyBeginIndex < bufferLength)
    {
        if ([inputBuffer characterAtIndex:keyBeginIndex] == '<')
        {
            while (keyEndIndex < bufferLength) {
                unichar ch = [inputBuffer characterAtIndex:keyEndIndex];
                if (ch == '<') {
                    keyEndIndex = keyBeginIndex + 1;
                    break;
                } else if (ch == '>') {
                    break;
                }
                ++keyEndIndex;
            }
            if (keyEndIndex == bufferLength) { keyEndIndex = keyBeginIndex + 1; }
        }
        NSRange range = {keyBeginIndex, keyEndIndex};
        [self processKey:[inputBuffer substringWithRange:range]];
        keyBeginIndex = keyEndIndex + 1;
        keyEndIndex = keyEndIndex + 2;
    }
}

-(BOOL) processKey:(NSString *)key
{
    DLog(@"Process Key: %@", key);
    return NO;
}

-(void) switchMode:(VimMode)mode
{
    vi_mode = mode;
}

-(void) startKeymapTimer
{
}

-(void) stopKeymapTimer
{
    
}
@end
