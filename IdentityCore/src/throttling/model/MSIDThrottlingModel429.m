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
#import "MSIDThrottlingModel429.h"
#import "NSError+MSIDThrottlingExtension.h"

@implementation MSIDThrottlingModel429
static NSInteger const Default429Throttling = 60;
static NSInteger const MaxRetryAfter = 3600;

- (instancetype) initWithRequest:(id<MSIDThumbprintCalculatable> _Nonnull)request
                     cacheRecord:(MSIDThrottlingCacheRecord * _Nullable)cacheRecord
                   errorResponse:(NSError *)errorResponse
                     accessGroup:(NSString *)accessGroup
{
    self = [super init];
    if (self)
    {
        self.thumbprintType = MSIDThrottlingThumbprintTypeStrict;
        self.thumbprintValue = [request strictRequestThumbprint];
        self.throttleDuration = Default429Throttling;
    }
    return self;
}


/**
 429 throttle conditions:
 - HTTP Response code is 429 or in 5xx range
 - OR Retry-After in response header
 */
+ (BOOL)isApplicableForTheThrottleModel:(NSError *)errorResponse
{
    /**
     In SSO-Ext flow, it can be both MSAL or MSID Error. If it's MSALErrorDomain, we need to extract information we need (error code and user info)
     */
    BOOL res = NO;
    BOOL isMSIDError = [errorResponse.domain hasPrefix:@"MSID"];
    NSString *httpResponseCode = errorResponse.userInfo[isMSIDError ? MSIDHTTPResponseCodeKey : @"MSALHTTPResponseCodeKey"];
    NSInteger responseCode = [httpResponseCode intValue];
    if (responseCode == 429) res = YES;
    if (responseCode >= 500 && responseCode <= 599) res = YES;
    NSDate *retryHeaderDate = [errorResponse msidGetRetryDateFromError];
    if (retryHeaderDate)
    {
        res = YES;
    }
    return res;
}

- (BOOL)shouldThrottleRequest
{
    BOOL res = YES;
    NSDate *currentTime = [NSDate new];
    if ([currentTime compare:self.cacheRecord.expirationTime] != NSOrderedAscending)
    {
        res = NO;
    }
    return res;
}

- (MSIDThrottlingCacheRecord *)prepareCacheRecord
{
    NSDate *retryHeaderDate = [self.errorResponse msidGetRetryDateFromError];
    NSInteger throttleDuration = 0;
    if (!retryHeaderDate)
    {
        throttleDuration = Default429Throttling;
    }
    else
    {
        NSTimeInterval MAX_THROTTLING_TIME = MaxRetryAfter;
        NSDate *max429ThrottlingDate = [[NSDate date] dateByAddingTimeInterval:MAX_THROTTLING_TIME];
        NSTimeInterval timeDiff = [retryHeaderDate timeIntervalSinceDate:max429ThrottlingDate];
        throttleDuration = (timeDiff > MAX_THROTTLING_TIME) ? MAX_THROTTLING_TIME : timeDiff;
    }
    MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:self.errorResponse
                                                                                    throttleType:self.thumbprintType
                                                                                throttleDuration:throttleDuration];
    return record;
}
@end
