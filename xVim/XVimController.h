//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import <Foundation/Foundation.h>

@class XTextViewBridge;

// The controller is used to process the key input
@interface XVimController : NSObject

+(void) setup;

-(XVimController*) initWithBridge:(XTextViewBridge*) bridge;
-(BOOL) processKeyEvent:(NSEvent*) event;
-(void) dealloc;

@end
