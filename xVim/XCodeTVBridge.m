//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "XCodeTVBridge.h"
#import "XVimController.h"

// Looks like whenever we open a text file, 
// or switch to another text file,
// or bring up a new assistant editor. 
// DVTSourceTextView's initWithCoder: is invoked.
typedef void* (*O_InitWithCoder) (void*, SEL, void*);
static O_InitWithCoder orig_initWithCoder = 0;
static void* xc_initWithCoder(void*, SEL, void*);


#if defined(DEBUG) && defined(XCode_Safe_Hijack)
// I don't know when DVTSourceTextView's init / initWithFrame:textContainer: is invoked.
// But if we never see a hook message, we may remove these hooks ~
typedef void* (*O_Init)(void*, SEL);
typedef void* (*O_InitWithFrameTextContainer)(void* self, SEL sel, void*, void*);
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
    associateBridgeAndView(bridge, self);
    [bridge release];
    return orig_initWithCoder(self, sel, p1);
}


@interface NSTextView(XTVBridge)
// visibleParagraphRange is a method of Xcode's editor,
// I just want to suppress the warning.
-(NSRange) visibleParagraphRange;
@end


@implementation XCodeTVBridge

+(void) hijack
{
    Class dvtTextViewClass = NSClassFromString(@"DVTSourceTextView");
    orig_initWithCoder = methodSwizzle(dvtTextViewClass, @selector(initWithCoder:), xc_initWithCoder);
    general_hj_finalize(dvtTextViewClass);
    general_hj_keydown(dvtTextViewClass);
    general_hj_DIPIR(dvtTextViewClass);
    
    Class ideDelegateClass = NSClassFromString(@"IDESourceCodeEditor");
    general_hj_willChangeSelection(ideDelegateClass);
    
#if defined(DEBUG) && defined(XCode_Safe_Hijack)
    orig_init = methodSwizzle(dvtTextViewClass, @selector(init), xc_init);
    orig_initWithFTC = methodSwizzle(dvtTextViewClass, @selector(initWithFrame:textContainer:), xc_initWithFTC);
#endif
}

-(NSRange) visibleParagraphRange {
    return [[super targetView] visibleParagraphRange];
}

@end
