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
//
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSIDBartFeatureUtil.h"
#import "MSIDCache.h"
#import "MSIDFlightManager.h"

static NSString *const k_bartCacheKey = @"com.microsoft.msid.bart_feature_enabled";
@implementation MSIDBartFeatureUtil

+ (instancetype)sharedInstance
{
    static MSIDBartFeatureUtil *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        [self sharedCache];
    });
    return sharedInstance;
}

+ (MSIDCache *)sharedCache
{
    static MSIDCache *k_nonceCache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        k_nonceCache = [MSIDCache new];
    });
    return k_nonceCache;
}

- (BOOL)isBartFeatureEnabled
{
#if TARGET_OS_IPHONE
    BOOL isFeatureEnableViaFlight = [MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_IS_BART_SUPPORTED];
    if (isFeatureEnableViaFlight)
    {
        // Enable feature if it is enabled by app setting
        BOOL cachedValue = [[self.class sharedCache] objectForKey:k_bartCacheKey];
        return cachedValue;
    }
    return NO;
#else
    return NO;
#endif
}
@end
