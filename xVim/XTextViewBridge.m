//
//  Created by Morris on 11-12-17.
//  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
//

#import "XGlobal.h"
#import "XTextViewBridge.h"
#import "XVimController.h"

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
