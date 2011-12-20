//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "XVimController.h"
#import "XVimMode.h"
#import "XTextViewBridge.h"
#import "vim.h"


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
    
        NSMutableString* killBuffer;
        BOOL             killBufferIsWholeLine;
}

-(void) processBuffer;
// Generate a fake key event based on the value of currentKey
-(NSEvent*) generateFakeEvent;
@end



@implementation XVimController

-(XVimController*) initWithBridge:(XTextViewBridge*) b
{
    if (self = [super init]) {
        bridge = b;
        vi_mode = NormalMode;
        inputBuffer = [[NSMutableArray alloc] init];
        killBuffer  = [[NSMutableString alloc] init];
        
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
    [killBuffer  release];
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
-(void) markAsMode:(VimMode)mode { vi_mode = mode; }
-(void) switchToMode:(VimMode)mode
{
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
    
    [handlers[vi_mode] enter];
}

-(void) processBuffer
{
    if ([inputBuffer count] == 0)
    {
        // Process the currentKeyEvent.
        unichar ch = [[currentKeyEvent charactersIgnoringModifiers] characterAtIndex:0];
        BOOL handled = [handlers[vi_mode] processKey:ch
                                           modifiers:([currentKeyEvent modifierFlags] & XModifierFlagsMask) 
                                       forController:self];
        if (handled == NO)
            [bridge handleFakeKeyEvent:currentKeyEvent];
    } else {
        // Process the buffer.
        for (NSNumber* key in inputBuffer)
        {
            currentKey = [key unsignedIntegerValue];
            BOOL handled = [handlers[vi_mode] processKey:(currentKey & XUnicharMask) 
                                               modifiers:(currentKey & XModifierFlagsMask) 
                                           forController:self];
            // The key is not handled, ask the NSTextView to handle it.
            if (handled == NO)
                [bridge handleFakeKeyEvent:[self generateFakeEvent]];
        }
        currentKey = 0;
    }
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
    // For now, we simply directly process the event.
    // But we can do key mapping here.
    currentKeyEvent = event;
    [self processBuffer];
    currentKeyEvent = nil;
}

@end
