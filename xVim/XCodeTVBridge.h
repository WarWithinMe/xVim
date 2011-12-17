//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XTextViewBridge.h"

@interface XCodeTVBridge : XTextViewBridge
+(void) hijack;
-(void) handleFakeKeyEvent:(NSEvent*) fakeEvent;
@end

// --- Xcode ---


