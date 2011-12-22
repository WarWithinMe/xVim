//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "XSpecificTVBridge.h"
#import "XVimController.h"

@implementation XCodeTVBridge
+(void) hijack
{
    Class dvtTextViewClass = NSClassFromString(@"DVTSourceTextView");
    general_hj_init(dvtTextViewClass, [XCodeTVBridge class]);
    general_hj_finalize(dvtTextViewClass);
    general_hj_keydown(dvtTextViewClass);
    general_hj_DIPIR(dvtTextViewClass);
    
    Class ideDelegateClass = NSClassFromString(@"IDESourceCodeEditor");
    general_hj_willChangeSelection(ideDelegateClass);
}
@end


// === Espresso === 
typedef void* (*O_InitWithFrame) (void*, SEL, NSRect);
typedef void* (*O_InitWithFTC)   (void*, SEL, NSRect, void*);
typedef void* (*O_InitWithFM)    (NSTextView*, SEL, NSRect, BOOL);
static O_InitWithFrame  orig_initWithFrame = 0;
static O_InitWithFTC    orig_initWithFTC   = 0;
static O_InitWithFM     orig_initWithFM    = 0;
static void* es_initWithFrame(void*, SEL, NSRect);
static void* es_initWithFTC(void*, SEL, NSRect, void*);
static void* es_initWithFM(NSTextView*, SEL, NSRect, BOOL);
void* es_initWithFrame(void* self, SEL sel, NSRect p1)
{
    XTextViewBridge* bridge = [[XEspressoTVBridge alloc] initWithTextView:self];
    if (bridge) {
        associateBridgeAndView(bridge, self);
        [bridge release];
    }
    return orig_initWithFrame(self, sel, p1);
}
void* es_initWithFTC(void* self, SEL sel, NSRect p1, void* p2)
{
    XTextViewBridge* bridge = [[XEspressoTVBridge alloc] initWithTextView:self];
    if (bridge) {
        associateBridgeAndView(bridge, self);
        [bridge release];
    }
    return orig_initWithFTC(self, sel, p1, p2);
}

void* es_initWithFM(NSTextView* self, SEL sel, NSRect p1, BOOL makeFieldEditor)
{
    NSTextView* r = orig_initWithFM(self, sel, p1, makeFieldEditor);
    
    if (makeFieldEditor == NO)
    {
        XTextViewBridge* bridge = [[XEspressoTVBridge alloc] initWithTextView:self];
        if (bridge)
        {
            associateBridgeAndView(bridge, self);
            [bridge release];
        }
        
        static XTextViewDelegate* delegate = nil;
        if (delegate == nil) { delegate = [[XTextViewDelegate alloc] init]; }
        if (r != nil) { [r setDelegate:delegate]; }
    }
    
    return r;
}

@implementation XEspressoTVBridge
+(void) hijack
{
    Class ekTextViewClass = NSClassFromString(@"EKTextView");
    
    general_hj_finalize(ekTextViewClass);
    general_hj_dealloc(ekTextViewClass);
    general_hj_keydown(ekTextViewClass);
    general_hj_DIPIR(ekTextViewClass);
    
    // For espresso, we only need to hijack initWithFrame:makeFieldEditor:
    orig_initWithFM = methodSwizzle(ekTextViewClass, @selector(initWithFrame:makeFieldEditor:), es_initWithFM);
    // orig_initWithFrame = methodSwizzle(ekTextViewClass, @selector(initWithFrame:), es_initWithFrame);
    // orig_initWithFTC   = methodSwizzle(ekTextViewClass, @selector(initWithFrame:textContainer:), es_initWithFTC);
}
@end

@implementation XTextViewDelegate

- (NSArray*) textView:(NSTextView*) view willChangeSelectionFromCharacterRanges:(NSArray*) old toCharacterRanges:(NSArray*) new
{
    XTextViewBridge* bridge = getBridgeForView(view);
    if (bridge != nil) {
        return [[bridge vimController] selectionChangedFrom:old to:new];
    }
    return new;
}
@end