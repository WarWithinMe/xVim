//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XTextViewBridge.h"

// Hijack class for xCode.

@interface XCodeTVBridge : XTextViewBridge
+(void) hijack;
-(NSRange) visibleParagraphRange;
@end

// --- Xcode ---


