//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XVimController.h"

@interface XVimController()
{
    @private
        XTextViewBridge* bridge;
        VimMode mode;
}
@end

@implementation XVimController

@synthesize mode;

-(XVimController*)initWithBridge:(XTextViewBridge*) b
{
    if (self = [super init]) {
        bridge = b;
    }
    return self;
}

-(BOOL) processKeyEvent:(NSEvent*) event
{
    if (mode == Normal) {
        
        return YES;
    } else if (mode == Insert) {
        
        return NO;
    } else if (mode == Visual) {
        
        return YES;
    }
    return NO;
}
@end
