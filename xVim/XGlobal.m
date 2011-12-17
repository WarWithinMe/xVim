//
//  Created by Morris on 11-12-17.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "XVimPlugin.h"
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
    [XVimController setup];
    bridgeDict = [[NSMutableDictionary alloc] init];
    
    NSString* id = [[NSBundle mainBundle] bundleIdentifier];
    if ([id isEqualToString:@"com.apple.dt.Xcode"])
    {
        DLog(@"xVim hijacking xcode");
        [XCodeTVBridge hijack];
    }
}
@end
