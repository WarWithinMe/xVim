//
//  Created by Morris on 11-12-17.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "XCodeTVBridge.h"
#import "XVimController.h"
#import <objc/runtime.h>

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


NSMutableDictionary* bridgeDict = 0;
void associateBridgeAndView(XTextViewBridge* b, NSTextView* tv)
{
    [bridgeDict setObject:b forKey:[NSValue valueWithPointer:tv]];
}
XTextViewBridge* getBridgeForView(NSTextView* tv)
{
    return [bridgeDict objectForKey:[NSValue valueWithPointer:tv]];
}
void removeBridgeForView(NSTextView* tv)
{
    [bridgeDict removeObjectForKey:[NSValue valueWithPointer:tv]];
}


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
    bridgeDict = [[NSMutableDictionary alloc] init];
    
    NSString* id = [[NSBundle mainBundle] bundleIdentifier];
    if ([id isEqualToString:@"com.apple.dt.Xcode"])
    {
        DLog(@"xVim hijacking xcode");
        [XCodeTVBridge hijack];
    }
}
@end


// ========== General Hijack Functions ==========
//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "XCodeTVBridge.h"
#import "XVimController.h"
#import "vim.h"

typedef void  (*O_Finalize)                  (void*, SEL);
typedef void  (*O_KeyDown)                   (void*, SEL, NSEvent*);
typedef void  (*O__DrawInsertionPointInRect) (NSTextView*, SEL, NSRect, NSColor*); // This one is for private api.
typedef void  (*O_DrawInsertionPointInRect)  (NSTextView*, SEL, NSRect, NSColor*, BOOL);
typedef void* (*O_WillChangeSelection)       (void*, SEL, NSTextView*, NSArray* oldRanges, NSArray* newRanges);
static O_Finalize                  orig_finalize = 0;
static O_KeyDown                   orig_keyDown  = 0;
static O__DrawInsertionPointInRect orig_DIPIR_private = 0;
static O_DrawInsertionPointInRect  orig_DIPIR = 0;
static O_WillChangeSelection       orig_willChangeSelection = 0;
static void  configureInsertionPointRect(NSTextView* view, NSRect*);
static void  hj_finalize(void*, SEL);
static void  hj_keyDown(void*, SEL, NSEvent*);
static void  hj_DIPIR_private(NSTextView*, SEL, NSRect, NSColor*);
static void  hj_DIPIR(NSTextView*, SEL, NSRect, NSColor*, BOOL);
static void* hj_willChangeSelection(void*, SEL, NSTextView*, NSArray* oldRanges, NSArray* newRanges);

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
            
            if (mode == ReplaceMode || mode == SingleReplaceMode) {
                rect->origin.y += rect->size.height;
                rect->origin.y -= 3;
                rect->size.height = 3;
            }
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
    orig_finalize(self, sel);
}

void hj_keyDown(void* self, SEL sel, NSEvent* event)
{
    [getBridgeForView(self) processKeyEvent:event];
}

void* hj_willChangeSelection(void* self, SEL sel, NSTextView* view, NSArray* oldRanges, NSArray* newRanges)
{
    NSArray* a = [[getBridgeForView(view) vimController] selectionChangedFrom:oldRanges to:newRanges];
    if (orig_willChangeSelection) { return orig_willChangeSelection(self, sel, view, oldRanges, a); }
    return a;
}

void general_hj_finalize(Class c) { orig_finalize = methodSwizzle(c, @selector(finalize), hj_finalize); }
void general_hj_keydown(Class c) { orig_keyDown = methodSwizzle(c, @selector(keyDown:), hj_keyDown); }
void general_hj_DIPIR(Class c)
{
    orig_DIPIR_private = methodSwizzle(c, @selector(_drawInsertionPointInRect:color:), hj_DIPIR_private);
    orig_DIPIR = methodSwizzle(c, @selector(drawInsertionPointInRect:color:turnedOn:), hj_DIPIR);
}
void general_hj_willChangeSelection(Class c)
{
    orig_willChangeSelection = methodSwizzle(c, @selector(textView:willChangeSelectionFromCharacterRanges:toCharacterRanges:), hj_willChangeSelection);
}




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
        controller = [[XVimController alloc] initWithBridge:self];
        targetView = view;
    }
    return self;
}

-(void)    dealloc  { DLog(@"XTextViewBridge Dealloced"); [controller release]; }
-(void)    finalize { DLog(@"XTextViewBridge Finalized"); }
-(void)    processKeyEvent:(NSEvent*)event { [controller processKeyEvent:event]; }
-(BOOL)    closePopup { return NO; }
-(NSRange) visibleParagraphRange { return NSMakeRange(0, 0); }

-(void) handleFakeKeyEvent:(NSEvent*) fakeEvent {
    if (orig_keyDown) {
        orig_keyDown(self->targetView, @selector(keyDown:), fakeEvent);
    }
}

// handleFakeKeyEvent is implemented in XGlobal.m

@end
