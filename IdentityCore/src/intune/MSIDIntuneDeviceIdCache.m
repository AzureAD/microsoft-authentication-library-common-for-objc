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

#import "MSIDIntuneDeviceIdCache.h"

static MSIDIntuneDeviceIdCache *s_sharedCache;

@interface MSIDIntuneDeviceIdCache ()

@property (nonatomic) NSString *deviceId;

@end

@implementation MSIDIntuneDeviceIdCache

#pragma mark - Shared instance

+ (MSIDIntuneDeviceIdCache *)sharedCache
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!s_sharedCache)
        {
            s_sharedCache = [[MSIDIntuneDeviceIdCache alloc] init];
        }
    });
    return s_sharedCache;
}

+ (void)setSharedCache:(MSIDIntuneDeviceIdCache *)cache
{
    @synchronized(self)
    {
        s_sharedCache = cache;
    }
}

#pragma mark - Cache operations

- (nullable NSString *)intuneDeviceIdWithContext:(__unused id<MSIDRequestContext>)context
                                           error:(__unused NSError *__autoreleasing *)error
{
    @synchronized(self)
    {
        return self.deviceId;
    }
}

- (BOOL)setIntuneDeviceId:(NSString *)deviceId
                  context:(__unused id<MSIDRequestContext>)context
                    error:(__unused NSError *__autoreleasing *)error
{
    @synchronized(self)
    {
        self.deviceId = deviceId;
        return YES;
    }
}

- (void)clear
{
    @synchronized(self)
    {
        self.deviceId = nil;
    }
}

@end
