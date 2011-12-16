//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import <Foundation/Foundation.h>

@class XTextViewBridge;

typedef enum e_VimMode
{
    NormalMode = 0,
    InsertMode = 1,
    VisualMode = 2,
    ExMode     = 3,
    ReplaceMode = 4,
    SingleReplaceMode = 5
} VimMode;

// The controller is used to process the key input
@interface XVimController : NSObject

+(void) setup;
+(NSEvent*) fakeEventFor:(NSString*) key;

-(XVimController*) initWithBridge:(XTextViewBridge*) bridge;
-(void) dealloc;

-(void) processKeyEvent:(NSEvent*) event;
-(void) switchToMode:(VimMode) mode;

-(XTextViewBridge*) bridge;

// Return the current key event that we are working with,
// or nil, if we are working with a mapped key.
-(NSEvent*) currentKeyEvent;

@end
