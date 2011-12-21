//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "XSpecificTVBridge.h"
#import "XVimController.h"

@interface NSTextView(XTVBridge)
// visibleParagraphRange is a method of Xcode's editor,
// I just want to suppress the warning.
-(NSRange) visibleParagraphRange;
@end

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

-(NSRange) visibleParagraphRange {
    return [[super targetView] visibleParagraphRange];
}
@end


typedef void* (*O_InitWithFrame) (void*, SEL, NSRect);
typedef void* (*O_InitWithFM)    (void*, SEL, NSRect, BOOL);
typedef void* (*O_InitWithFTC)   (void*, SEL, NSRect, void*);
static O_InitWithFrame  orig_initWithFrame = 0;
static O_InitWithFM     orig_initWithFM    = 0;
static O_InitWithFTC    orig_initWithFTC   = 0;
static void* es_initWithFrame(void*, SEL, NSRect);
static void* es_initWithFM(void*, SEL, NSRect, BOOL);
static void* es_initWithFTC(void*, SEL, NSRect, void*);
void* es_initWithFrame(void* self, SEL sel, NSRect p1)
{
    DLog(@"This is initWithFrame"); 
    XTextViewBridge* bridge = [[XEspressoTVBridge alloc] initWithTextView:self];
    if (bridge) {
        associateBridgeAndView(bridge, self);
        [bridge release];
    }
    return orig_initWithFrame(self, sel, p1);
}
void* es_initWithFM(void* self, SEL sel, NSRect p1, BOOL p2)
{
    DLog(@"This is initWithFM");
    XTextViewBridge* bridge = [[XEspressoTVBridge alloc] initWithTextView:self];
    if (bridge) {
        associateBridgeAndView(bridge, self);
        [bridge release];
    }
    return orig_initWithFM(self, sel, p1, p2);
}
void* es_initWithFTC(void* self, SEL sel, NSRect p1, void* p2)
{
    DLog(@"This is initWithFTC");
    XTextViewBridge* bridge = [[XEspressoTVBridge alloc] initWithTextView:self];
    if (bridge) {
        associateBridgeAndView(bridge, self);
        [bridge release];
    }
    return orig_initWithFTC(self, sel, p1, p2);
}
@implementation XEspressoTVBridge
+(void) hijack
{
    Class ekTextViewClass = NSClassFromString(@"EKTextView");
    DLog(@"Class: %@", ekTextViewClass);
    general_hj_finalize(ekTextViewClass);
    general_hj_keydown(ekTextViewClass);
    general_hj_DIPIR(ekTextViewClass);
    
    orig_initWithFrame = methodSwizzle(ekTextViewClass, @selector(initWithFrame:), es_initWithFrame);
    orig_initWithFM    = methodSwizzle(ekTextViewClass, @selector(initWithFrame:makeFieldEditor:), es_initWithFM);
    orig_initWithFTC   = methodSwizzle(ekTextViewClass, @selector(initWithFrame:textContainer:), es_initWithFTC);
    
    // TODO: Find the right place of init to hijack.
    // And also deal with the delegate:
    // general_hj_willChangeSelection(ideDelegateClass);
}
@end
