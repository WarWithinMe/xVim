//
//  Created by Morris on 11-12-19.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#define ITERATE_STRING_BUFFER_SIZE 64

typedef struct s_NSStringHelper
{
    unichar    buffer[ITERATE_STRING_BUFFER_SIZE];
    NSString*  string;
    NSUInteger strLen;
    NSInteger  index;
    
} NSStringHelper;

void initNSStringHelper(NSStringHelper*, NSString* string, NSUInteger strLen);
void initNSStringHelperBackward(NSStringHelper*, NSString* string, NSUInteger strLen);
unichar characterAtIndex(NSStringHelper*, NSInteger index);
