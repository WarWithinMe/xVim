//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import <Foundation/Foundation.h>

@class XTextViewBridge;

typedef enum e_VimMode
{
    Normal,
    Insert,
    Visual
} VimMode;

// The controller is used to process the key input
@interface XVimController : NSObject

@property (readonly) VimMode mode;

-(XVimController*) initWithBridge:(XTextViewBridge*) bridge;
-(BOOL) processKeyEvent:(NSEvent*) event;

@end
