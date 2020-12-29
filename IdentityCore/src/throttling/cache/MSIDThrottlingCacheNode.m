//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  


#import <Foundation/Foundation.h>
#import "MSIDThrottlingCacheNode.h"
#import "MSIDThrottlingCacheRecord.h"


@interface MSIDThrottlingCacheNode ()

@property (nonatomic) NSMutableString *prevKeyInt;
@property (nonatomic) NSMutableString *nextKeyInt;

@end

@implementation MSIDThrottlingCacheNode

- (NSString *)prevRequestThumbprintKey
{
    return self.prevKeyInt;
}

- (NSString *)nextRequestThumbprintKey
{
    return self.nextKeyInt;
}

- (void)setPrevRequestThumbprintKey:(NSString *)prevRequestThumbprintKey
{
    self.prevKeyInt = [prevRequestThumbprintKey mutableCopy];
}

- (void)setNextRequestThumbprintKey:(NSString *)nextRequestThumbprintKey
{
    self.nextKeyInt = [nextRequestThumbprintKey mutableCopy];
}

- (instancetype)initWithThumbprintKey:(NSString *)thumbprintKey
                        errorResponse:(NSError *)errorResponse
                         throttleType:(NSString *)throttleType
                     throttleDuration:(NSInteger)throttleDuration
             prevRequestThumbprintKey:(NSString *)prevRequestThumbprintKey
             nextRequestThumbprintKey:(NSString *)nextRequestThumbprintKey
{
    self = [super init];
    if (self )
    {
        _requestThumbprintKey = thumbprintKey;
        _prevKeyInt = [prevRequestThumbprintKey mutableCopy];
        _nextKeyInt = [nextRequestThumbprintKey mutableCopy];
        _cacheRecord = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:errorResponse
                                                                   throttleType:throttleType
                                                               throttleDuration:throttleDuration];
    }
    return self;
}


@end
