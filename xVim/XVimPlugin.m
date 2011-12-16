//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

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



@implementation XVimPlugin

// The entry point of our plugin
+(void) load
{
    [XVimController setup];
    bridgeDict = [[NSMutableDictionary alloc] init];
    
    NSString* id = [[NSBundle mainBundle] bundleIdentifier];
    if ([id isEqualToString:@"com.apple.dt.Xcode"])
    {
        DLog(@"xVim hijacking xcode");
        [XCodeTVBridge hijack];
    }
}

+(XTextViewBridge*) bridgeFor:(NSTextView*) textView
{
    return [bridgeDict objectForKey:[NSValue valueWithPointer:textView]];
}

+(void) storeBridge:(XTextViewBridge*) bridge ForView:(NSTextView*) textView
{
    [bridgeDict setObject:bridge forKey:[NSValue valueWithPointer:textView]];
}

+(void) removeBridgeForView:(NSTextView*) textView
{
    [bridgeDict removeObjectForKey:[NSValue valueWithPointer:textView]];
}

@end



@interface XTextViewBridge()
{
    @private
        XVimController*    controller;
        __weak NSTextView* targetView;
}
@end

@implementation XTextViewBridge

-(NSTextView*) targetView
{
    return targetView;
}

-(XTextViewBridge*) initWithTextView:(NSTextView*) view
{
    if (self = [super init]) {
        controller = [[XVimController alloc] initWithBridge:self];
        targetView = view;
    }
    return self;
}

-(void) dealloc
{
    DLog(@"XTextViewBridge Dealloced");
    [controller release];
}

-(void) finalize
{
    DLog(@"XTextViewBridge Finalized");
}

-(void) processKeyEvent:(NSEvent *)event
{
    [controller processKeyEvent:event];
}

-(void) handleFakeKeyEvent:(NSEvent*) fakeEvent {}
-(BOOL) closePopup { return NO; }

@end


