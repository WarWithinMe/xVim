//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XCodeTVBridge.h"

// Below are some methods we may want to override.

// === Xcode ===
// Looks like whenever we open a text file, 
// or switch to another text file,
// or bring up a new assistant editor. 
// DVTSourceTextView's initWithCoder: is invoked.
typedef void* (*O_InitWithCoder) (void*, SEL, void*);
typedef void  (*O_Finalize) (void*, SEL);
typedef void  (*O_KeyDown) (void*, SEL, NSEvent*);

// I don't know when DVTSourceTextView's init / initWithFrame:textContainer: is invoked.
// But if we never see a hook message, we may remove these hooks ~
typedef void* (*O_Init)(void*, SEL);
typedef void* (*O_InitWithFrameTextContainer)(void* self, SEL sel, void*, void*);


static O_Finalize      orig_finalize = 0;
static O_InitWithCoder orig_initWithCoder = 0;
static O_KeyDown       orig_keyDown  = 0;
static void  xc_finalize(void*, SEL);
static void* xc_initWithCoder(void*, SEL, void*);
static void  xc_keyDown(void*, SEL, NSEvent*);

#if defined(DEBUG) && defined(XCode_Safe_Hijack)
static O_Init orig_init = 0;
static O_InitWithFrameTextContainer orig_initWithFTC = 0;
static void* xc_init(void*, SEL);
static void* xc_initWithFTC(void*, SEL, void*, void*);
void* xc_init(void* self, SEL sel)
{
    DLog(@"HJ_init");
    return orig_init(self, sel);
}

void* xc_initWithFTC(void* self, SEL sel, void* p1, void* p2)
{
    DLog(@"HJ_initWithFrame");
    return orig_initWithFTC(self, sel, p1, p2);
}
#endif



void* xc_initWithCoder(void* self, SEL sel, void* p1)
{
    DLog(@"HJ_initWithCoder");
    XTextViewBridge* bridge = [[XCodeTVBridge alloc] initWithTextView:self];
    [XVimPlugin storeBridge:bridge ForView:self];
    [bridge release];
    return orig_initWithCoder(self, sel, p1);
}

void xc_finalize(void* self, SEL sel)
{
    DLog(@"HJ_Finalize");
    [XVimPlugin removeBridgeForView:self];
    orig_finalize(self, sel);
}

void xc_keyDown(void* self, SEL sel, NSEvent* event)
{
    XTextViewBridge* bridge = [[XVimPlugin bridgeFor:self] retain];
    if (NO == [bridge processKeyEvent:event]) {
        DLog(@"HJ_KeyDown: the original text view should process %@", [event characters]);
        orig_keyDown(self, sel, event);
    }
    [bridge release];
}



@implementation XCodeTVBridge

+(void) hijack
{
#if defined(DEBUG) && defined(XCode_Safe_Hijack)
    orig_init = methodSwizzle(NSClassFromString(@"DVTSourceTextView"), 
                              @selector(init), 
                              xc_init);
    
    orig_initWithFTC = methodSwizzle(NSClassFromString(@"DVTSourceTextView"), 
                                     @selector(initWithFrame:textContainer:), 
                                     xc_initWithFTC);
#endif
    
    orig_initWithCoder = methodSwizzle(NSClassFromString(@"DVTSourceTextView"), 
                                       @selector(initWithCoder:), 
                                       xc_initWithCoder);
    
    orig_finalize = methodSwizzle(NSClassFromString(@"DVTSourceTextView"), 
                                  @selector(finalize), 
                                  xc_finalize);
    
    orig_keyDown = methodSwizzle(NSClassFromString(@"DVTSourceTextView"), 
                                 @selector(keyDown:), 
                                 xc_keyDown);
}
@end

