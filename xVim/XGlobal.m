//
//  Created by Morris on 11-12-17.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "XTextViewBridge.h"
#import "XVimController.h"
#import <objc/runtime.h>


// Hijacking parameters
static Class bridgeClass = nil;
static XTextViewDelegate* delegate = nil;
static BOOL  createBridgeWhenNeeded = NO;


// Replace target selector of a target class with our function
// the overriden method is returned.
void* methodSwizzle(Class c, SEL sel, void* overrideFunction);
void* methodSwizzle(Class c, SEL sel, void* overrideMethod)
{
    Method origM   = class_getInstanceMethod(c, sel);
    void*  origIMP = method_getImplementation(origM);
    
    if (!class_addMethod(c, sel, (IMP)overrideMethod, method_getTypeEncoding(origM)))
    {
        method_setImplementation(origM, (IMP)overrideMethod);
    }
    return origIMP;
}


// ====================
// These methods are used to associate a XTextViewBridge and NSTextView
// without using the cocoa system.
// Associate a bridge with a textview in the hijacked init method.
void associateBridgeAndView(XTextViewBridge*, NSTextView*);
// Retreive the associated bridge object in the hijacked keydown method.
XTextViewBridge* getBridgeForView(NSTextView*);
// Free the bridge for a textview in the hijacked finalize method.
void removeBridgeForView(NSTextView*);
// --------------------

NSMutableDictionary* bridgeDict = 0;

void associateBridgeAndView(XTextViewBridge* b, NSTextView* tv)
{
    [bridgeDict setObject:b forKey:[NSValue valueWithPointer:tv]];
}
XTextViewBridge* getBridgeForView(NSTextView* tv)
{
    XTextViewBridge* b = [bridgeDict objectForKey:[NSValue valueWithPointer:tv]];
    if (b == nil && createBridgeWhenNeeded)
    {
        DLog(@"Creating a new bridge when needed");
        b = [[bridgeClass alloc] initWithTextView:tv];
        associateBridgeAndView(b, tv);
    }
    return b;
}
void removeBridgeForView(NSTextView* tv)
{
    [bridgeDict removeObjectForKey:[NSValue valueWithPointer:tv]];
}


// Original methods:
typedef void  (*O_Finalize)                  (void*, SEL);
typedef void  (*O_Dealloc)                   (void*, SEL);
typedef void  (*O_KeyDown)                   (void*, SEL, NSEvent*);
typedef void  (*O__DrawInsertionPointInRect) (NSTextView*, SEL, NSRect, NSColor*); // This one is for private api.
typedef void  (*O_DrawInsertionPointInRect)  (NSTextView*, SEL, NSRect, NSColor*, BOOL);
typedef void* (*O_WillChangeSelection)       (void*, SEL, NSTextView*, NSArray* oldRanges, NSArray* newRanges);
static O_Finalize                  orig_finalize            = 0;
static O_Dealloc                   orig_dealloc             = 0;
static O_KeyDown                   orig_keyDown             = 0;
static O__DrawInsertionPointInRect orig_DIPIR_private       = 0;
static O_DrawInsertionPointInRect  orig_DIPIR               = 0;
static O_WillChangeSelection       orig_willChangeSelection = 0;
// Hijackers:
static void  configureInsertionPointRect(NSTextView* view, NSRect*);
static void  hj_finalize(void*, SEL);
static void  hj_dealloc(void*, SEL);
static void  hj_keyDown(void*, SEL, NSEvent*);
static void  hj_DIPIR_private(NSTextView*, SEL, NSRect, NSColor*);
static void  hj_DIPIR(NSTextView*, SEL, NSRect, NSColor*, BOOL);
static void* hj_willChangeSelection(void*, SEL, NSTextView*, NSArray* oldRanges, NSArray* newRanges);

// Special init methods:
static void* orig_init = 0;

typedef void* (*O_Init)          (void*, SEL);
typedef void* (*O_InitWithCoder) (void*, SEL, void*);
typedef void* (*O_InitWithFrame) (void*, SEL, NSRect);
typedef void* (*O_InitWithFTC)   (void*, SEL, NSRect, void*);
typedef void* (*O_InitWithFM)    (void*, SEL, NSRect, BOOL);

static void* hj_init          (void*, SEL);
static void* hj_initWithCoder (void*, SEL, void*);
static void* hj_initWithFrame (void*, SEL, NSRect);
static void* hj_initWithFTC   (void*, SEL, NSRect, void*);
static void* hj_initWithFM    (void*, SEL, NSRect, BOOL);


// Hijack info:
typedef struct s_HijackInfo {
    NSString* bridgeClassName;       // Can be nil
    NSString* textViewSubclassName;
    NSString* delegateClassName;     // Can be nil
    
    void*     initHijackFunc;        // If this is nil, 
                                     // we create the bridge the first time we need it.
    NSString* initSelectorName;      // This can be nil if initHijackFunc is nil.
    
    NSString* appIdentifier;
} HijackInfo;

// The hijack info map
#define SUPPORTED_APP_COUNT 3

// The map:
static HijackInfo s_hijackInfo_map[SUPPORTED_APP_COUNT] =
{
    {nil,
        @"DVTSourceTextView",
        @"IDESourceCodeEditor", 
        hj_initWithCoder, 
        @"initWithCoder:",
        @"com.apple.dt.Xcode"}, // XCode
    
    {nil,
        @"EKTextView",
        nil,
        hj_initWithFM,
        @"initWithFrame:makeFieldEditor:",
        @"com.macrabbit.Espresso"}, // Espresso
    
    {nil,
        @"CHFullTextView",
        @"CHTextViewController",
        nil,
        nil,
        @"com.chocolatapp.Chocolat"} // Chocolat use GC, but finalize never calls.
};


// The entry point of this plugin.
// In the load method, we call XXXBridge's(subclass of XTextViewBridge) hijack class method
// to inject our code to init/dealloc/finalize/keydown method.
// Basically:
// In init, we alloc a new XXXBridge and associate it with the hijacked textview.
// In dealloc and finalize, we free that XXXBridge.
// In keydown, we ask the associated XXXBridge to process the keydown method.
@interface XVimPlugin : NSObject
@end
@implementation XVimPlugin
// The entry point of our plugin
+(void) load
{
    // [XVimController load];
    bridgeDict = [[NSMutableDictionary alloc] init];
    
    // Warning: When hijacking, we must not hijack NSTextView
    // directly. Because that will affect line editor control.
    
    NSString* id = [[NSBundle mainBundle] bundleIdentifier];
    for (int i = 0; i < SUPPORTED_APP_COUNT; ++i)
    {
        HijackInfo* info = s_hijackInfo_map + i;
        
        if ([id isEqualToString:info->appIdentifier])
        {
            DLog(@"xVim hijacking app: %@", id);
            
            bridgeClass = info->bridgeClassName == nil ? 
                              [XTextViewBridge class] : NSClassFromString(info->bridgeClassName);
            
            Class tvSubClass  = NSClassFromString(info->textViewSubclassName);
            
            if (info->initHijackFunc)
            {
                orig_init = methodSwizzle(tvSubClass, 
                                          NSSelectorFromString(info->initSelectorName), 
                                          info->initHijackFunc);
            } else {
                createBridgeWhenNeeded = YES;
            }
            
            
            
            orig_dealloc  = methodSwizzle(tvSubClass, @selector(dealloc),  hj_dealloc);
            orig_finalize = methodSwizzle(tvSubClass, @selector(finalize), hj_finalize);
            
            orig_keyDown  = methodSwizzle(tvSubClass, @selector(keyDown:), hj_keyDown);
            orig_DIPIR    = methodSwizzle(tvSubClass, 
                                          @selector(drawInsertionPointInRect:color:turnedOn:), 
                                          hj_DIPIR);
            orig_DIPIR_private = methodSwizzle(tvSubClass, 
                                               @selector(_drawInsertionPointInRect:color:), 
                                               hj_DIPIR_private);
            
            if (info->delegateClassName == nil)
            {
                delegate = [[XTextViewDelegate alloc] init];
            } else {
                
                Class delegateClass = NSClassFromString(info->delegateClassName);
                orig_willChangeSelection = methodSwizzle(delegateClass, 
                                                         @selector(textView:willChangeSelectionFromCharacterRanges:toCharacterRanges:), 
                                                         hj_willChangeSelection);
            }
            
            break;
        }
    }
}
@end

// ========== XTextViewBridge ==========
@interface XTextViewBridge()
{
@private
    XVimController*    controller;
    __weak NSTextView* targetView;
}
@end
@implementation XTextViewBridge

-(NSTextView*)     targetView    { return targetView; }
-(XVimController*) vimController { return controller; }

-(XTextViewBridge*) initWithTextView:(NSTextView*) view
{
    if (self = [super init]) {
        targetView = view; // Must assigned this before creating the XVimController.
        controller = [[XVimController alloc] initWithBridge:self];
    }
    return self;
}

-(void)    dealloc  { DLog(@"Deallocing XTexViewBridge: %@", self); [controller release]; }
-(void)    finalize { DLog(@"XTextViewBridge Finalized"); [super finalize]; }
-(void)    processKeyEvent:(NSEvent*)event { [controller processKeyEvent:event]; }
-(BOOL)    closePopup { return NO; }
-(NSRange) visibleParagraphRange { return NSMakeRange(0, 0); }

-(void) handleFakeKeyEvent:(NSEvent*) fakeEvent {
    if (orig_keyDown) {
        orig_keyDown(self->targetView, @selector(keyDown:), fakeEvent);
    }
}

@end

@implementation XTextViewDelegate
-(NSArray*) textView:(NSTextView*) view willChangeSelectionFromCharacterRanges:(NSArray*) old toCharacterRanges:(NSArray*) new
{
    return hj_willChangeSelection(nil, nil, view, old, new);
}
@end

// ========== General Hijack Functions ==========
void configureInsertionPointRect(NSTextView* view, NSRect* rect)
{
    XTextViewBridge* bridge = getBridgeForView(view);
    XVimController* controller = [bridge vimController];
    
    VimMode mode = [controller mode];
    if (mode == InsertMode) {
        rect->size.width = 1;
    } else {
        
        NSRange   range  = [view selectedRange];
        NSString* string = [[view textStorage] string];
        
        if (range.location + 1 >= [string length]) {
            rect->size.width = 8;
        } else {
            unichar ch = [string characterAtIndex:range.location];
            
            if ((ch >= 0xA && ch <= 0xD) || ch == 0x85) {
                // This is new line
                rect->size.width = 8;
            } else {
                NSUInteger glyphIndex = [[view layoutManager] glyphIndexForCharacterAtIndex:range.location];
                NSRect glyphRect = [[view layoutManager] boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
                                                                   inTextContainer:[view textContainer]];
                rect->size.width = glyphRect.size.width;
            }
        }
            
        if (mode == ReplaceMode || mode == SingleReplaceMode) {
            rect->origin.y += rect->size.height;
            rect->origin.y -= 3;
            rect->size.height = 3;
        }
    }
}

void hj_DIPIR_private(NSTextView* self, SEL sel, NSRect rect, NSColor* color)
{
    configureInsertionPointRect(self, &rect);
    orig_DIPIR_private(self, sel, rect, color);
}

void hj_DIPIR(NSTextView* self, SEL sel, NSRect rect, NSColor* color, BOOL turnedOn)
{
    configureInsertionPointRect(self, &rect);
    orig_DIPIR(self, sel, rect, color, turnedOn);
}

void hj_finalize(void* self, SEL sel)
{
    DLog(@"HJ_Finalize");
    removeBridgeForView(self);
    if(orig_finalize) orig_finalize(self, sel);
}

void hj_dealloc(void* self, SEL sel)
{
    DLog(@"Hj_Dealloc");
    removeBridgeForView(self);
    if(orig_dealloc) orig_dealloc(self, sel);
}

void hj_keyDown(void* self, SEL sel, NSEvent* event)
{
    DLog(@"HJ_KeyDown");
    [getBridgeForView(self) processKeyEvent:event];
}

void* hj_willChangeSelection(void* self, SEL sel, NSTextView* view, NSArray* oldRanges, NSArray* newRanges)
{
    XTextViewBridge* bridge = getBridgeForView(view);
    if (bridge != nil) {
        newRanges = [[bridge vimController] selectionChangedFrom:oldRanges to:newRanges];
    }
    if (orig_willChangeSelection) { return orig_willChangeSelection(self, sel, view, oldRanges, newRanges); }
    return newRanges;
}


// ========== Special Init Methods ==========
static void* hj_init(void* self, SEL sel)
{
    DLog(@"HJ_init");
    
    O_Init o_init = (O_Init) orig_init;
    NSTextView* r = o_init(self, sel);
    
    if (r == nil) { return nil; }
    
    XTextViewBridge* bridge = [[bridgeClass alloc] initWithTextView:r];
    
    if (bridge != nil) {
        associateBridgeAndView(bridge, r);
        [bridge release];
    }
    if (delegate != nil) { [r setDelegate:delegate]; }
    
    return r;
}

static void* hj_initWithCoder(void* self, SEL sel, void* p1)
{
    DLog(@"HJ_initWithCoder");
    
    O_InitWithCoder o_init = (O_InitWithCoder) orig_init;
    NSTextView* r = o_init(self, sel, p1);
    
    if (r == nil) { return nil; }
    
    XTextViewBridge* bridge = [[bridgeClass alloc] initWithTextView:r];
    
    if (bridge != nil) {
        associateBridgeAndView(bridge, r);
        [bridge release];
    }
    if (delegate != nil) { [r setDelegate:delegate]; }
    
    return r;
}

static void* hj_initWithFrame(void* self, SEL sel, NSRect p1)
{
    DLog(@"HJ_initWithFrame");
    
    O_InitWithFrame o_init = (O_InitWithFrame) orig_init;
    NSTextView* r = o_init(self, sel, p1);
    
    if (r == nil) { return nil; }
    
    XTextViewBridge* bridge = [[bridgeClass alloc] initWithTextView:r];
    
    if (bridge != nil) {
        associateBridgeAndView(bridge, r);
        [bridge release];
    }
    if (delegate != nil) { [r setDelegate:delegate]; }
    
    return r;
}

static void* hj_initWithFTC(void* self, SEL sel, NSRect p1, void* p2)
{
    DLog(@"HJ_initWithFTC");
    
    O_InitWithFTC o_init = (O_InitWithFTC) orig_init;
    NSTextView* r = o_init(self, sel, p1, p2);
    
    if (r == nil) { return nil; }
    
    XTextViewBridge* bridge = [[bridgeClass alloc] initWithTextView:r];
    
    if (bridge != nil) {
        associateBridgeAndView(bridge, r);
        [bridge release];
    }
    if (delegate != nil) { [r setDelegate:delegate]; }
    
    return r;
}

static void* hj_initWithFM(void* self, SEL sel, NSRect p1, BOOL makeFieldEditor)
{
    DLog(@"HJ_initWithFM");
    
    O_InitWithFM o_init = (O_InitWithFM) orig_init;
    NSTextView* r = o_init(self, sel, p1, makeFieldEditor);
    
    if (makeFieldEditor == YES || r == nil) { return r; }
    
    XTextViewBridge* bridge = [[bridgeClass alloc] initWithTextView:r];
    
    if (bridge != nil) {
        associateBridgeAndView(bridge, r);
        [bridge release];
    }
    if (delegate != nil) { [r setDelegate:delegate]; }
    
    return r;
}
