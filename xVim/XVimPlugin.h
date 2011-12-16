//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog(fmt, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

@class XVimController;
@class XVimPlugin;
@class XTextViewBridge;


// Replace target selector of a target class with our function
// the overriden method is returned.
void* methodSwizzle(Class c, SEL sel, void* overrideFunction);



// The entry point of this plugin.
// In the load method, we call XXXBridge's(subclass of XTextViewBridge) hijack class method
// to inject our code to init/dealloc/finalize/keydown method.
// Basically:
// In init, we alloc a new XXXBridge and associate it with the hijacked textview.
// In dealloc and finalize, we free that XXXBridge.
// In keydown, we ask the associated XXXBridge to process the keydown method.
@interface XVimPlugin : NSObject

// Associate a bridge with a textview in the hijacked init method.
+(void) storeBridge:(XTextViewBridge*) bridge ForView:(NSTextView*) textView;
// Retreive the associated bridge object in the hijacked keydown method.
+(XTextViewBridge*) bridgeFor:(NSTextView*) textView;
// Free the bridge for a textview in the hijacked finalize method.
+(void) removeBridgeForView:(NSTextView*) textView;

@end



@interface XTextViewBridge : NSObject

-(XTextViewBridge*) initWithTextView:(NSTextView*) view;
-(void) dealloc;

-(void) processKeyEvent:(NSEvent*) event;

// This method is called by the XVimController, subclass should override
// this method to let the hijacked textview to handle the fakeEvent.
-(void) handleFakeKeyEvent:(NSEvent*) fakeEvent;

// Return the hijacked targetView
-(NSTextView*) targetView;

// Ask the textview to close any popup, return YES if a popup is closed.
-(BOOL) closePopup;
@end
