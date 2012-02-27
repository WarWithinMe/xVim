//
//  Created by Morris on 11-12-19.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#ifdef __LP64__

#import "XGlobal.h"
#import "NSStringHelper.h"

void initNSStringHelper(NSStringHelper* h, NSString* string, NSUInteger strLen)
{
    h->string = string;
    h->strLen = strLen;
    h->index  = -ITERATE_STRING_BUFFER_SIZE;
}

void initNSStringHelperBackward(NSStringHelper* h, NSString* string, NSUInteger strLen)
{
    h->string = string;
    h->strLen = strLen;
    h->index  = strLen;
}

NSInteger fetchSubStringFrom(NSStringHelper* h, NSInteger index);
NSInteger fetchSubStringFrom(NSStringHelper* h, NSInteger index)
{
    NSInteger copyBegin = index;
    NSInteger size      = (index + ITERATE_STRING_BUFFER_SIZE) > h->strLen ? h->strLen - index : ITERATE_STRING_BUFFER_SIZE;
    [h->string getCharacters:h->buffer range:NSMakeRange(copyBegin, size)];
    return copyBegin;
}

NSInteger fetchSubStringEnds(NSStringHelper* h, NSInteger index);
NSInteger fetchSubStringEnds(NSStringHelper* h, NSInteger index)
{
    NSInteger copyBegin = (index + 1) >= ITERATE_STRING_BUFFER_SIZE ? index + 1 - ITERATE_STRING_BUFFER_SIZE : 0;
    NSInteger size      = index - copyBegin + 1;
    [h->string getCharacters:h->buffer range:NSMakeRange(copyBegin, size)];
    return copyBegin;
}

unichar characterAtIndex(NSStringHelper* h, NSInteger index)
{
    if (h->index > index)
    {
        h->index = fetchSubStringEnds(h, index);
    } else if (index >= (h->index + ITERATE_STRING_BUFFER_SIZE))
    {
        h->index = fetchSubStringFrom(h, index);
    }
    return h->buffer[index - h->index];
}

#endif
