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
#import "MSIDThrottlingModelInteractionRequire.h"
#import "MSIDThrottlingMetaData.h"
#import "MSIDThrottlingMetaDataCache.h"
#import "NSDate+MSIDExtensions.h"
#import "NSError+MSIDExtensions.h"
static NSInteger const DefaultUIRequired = 120;

@implementation MSIDThrottlingModelInteractionRequire

- (instancetype) initWithRequest:(id<MSIDThumbprintCalculatable> _Nonnull)request
                     cacheRecord:(MSIDThrottlingCacheRecord * _Nullable)cacheRecord
                   errorResponse:(NSError *)errorResponse
                     accessGroup:(NSString *)accessGroup
{
    self = [super initWithRequest:request cacheRecord:cacheRecord errorResponse:errorResponse accessGroup:accessGroup];
    if (self)
    {
        self.thumbprintType = MSIDThrottlingThumbprintTypeFull;
        self.thumbprintValue = [request fullRequestThumbprint];
        self.throttleDuration = DefaultUIRequired;
    }
    return self;
}


/**
 * if is appliable for UIRequired:
 * Throttle conditions:
 * MSAL <-> server flow: OAuth error: error.msidOauthError is not nil
 * MSAL <-> SSO-Ext <-> Server flow: error.code MSALErrorInteractionRequired
 */
+ (BOOL)isApplicableForTheThrottleModel:(NSError *)errorResponse
{
    // MSALErrorInteractionRequired = -50002
    NSSet *uirequiredErrors = [[NSSet alloc] initWithArray:@[[NSNumber numberWithInt:(-50002)]]];
    BOOL isMSIDError = [errorResponse msidIsMSIDError];
    
    if (isMSIDError)
    {
        NSString *errorString = errorResponse.msidOauthError;
        NSUInteger errorCode = errorResponse.code;
        if ([NSString msidIsStringNilOrBlank:errorString] || (errorCode == MSIDErrorInteractionRequired))
        {
            return YES;
        }
    }
    else
    {
        if ([uirequiredErrors containsObject:[NSNumber numberWithLong:errorResponse.code]])
        {
            return YES;
        }
    }
    return NO;
}

- (BOOL)shouldThrottleRequest
{
    NSError *error;
    NSDate *currentTime = [NSDate date];
    NSDate *lastRefreshTime = [MSIDThrottlingModelInteractionRequire getLastRefreshTimeAccessGroup:self.accessGroup context:self.context error:&error];
    // If currentTime is later than the expiration Time or the lastRefreshTime is later then the expiration Time, we don't throttle the request
    if ([currentTime compare:self.cacheRecord.expirationTime] != NSOrderedAscending
        || (lastRefreshTime && [lastRefreshTime compare:self.cacheRecord.expirationTime] != NSOrderedAscending))
    {
        [[MSIDThrottlingModelBase cacheService] removeObjectForKey:self.thumbprintValue error:&error];
        if (error)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"Throttling: error when remove record from database %@ ", error);
        }
        return NO;
    }
    return YES;
}

/**
 Get last refresh time from our key chain.
 */
+ (NSDate *)getLastRefreshTimeAccessGroup:(NSString *)accessGroup
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError*__nullable*__nullable)error
{
    MSIDThrottlingMetaData *metadata = [MSIDThrottlingMetaDataCache getThrottlingMetadataWithAccessGroup:accessGroup Context:context error:error];
    NSString *stringDate = metadata.lastRefreshTime;
    return [NSDate msidDateFromTimeStamp:stringDate];
}

- (MSIDThrottlingCacheRecord *)prepareCacheRecord
{
    MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:self.errorResponse
                                                                                    throttleType:MSIDThrottlingTypeInteractiveRequired
                                                                                throttleDuration:self.throttleDuration];
    return record;
}

- (void) updateServerTelemetry
{
    // TODO implement telemetry update here
    return ;
}

@end
