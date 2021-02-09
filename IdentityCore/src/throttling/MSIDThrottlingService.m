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
#import "MSIDThrottlingService+Internal.h"
#import "NSDate+MSIDExtensions.h"
#import "NSError+MSIDExtensions.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDKeychainUtil.h"
#import "MSIDConstants.h"
#import "MSIDLRUCache.h"
#import "MSIDExtendedTokenCacheDataSource.h"
#import "MSIDCacheKey.h"
#import "MSIDThrottlingMetaData.h"
#import "MSIDThrottlingMetaDataCache.h"
#import "MSIDThrottlingTypeProcessor.h"
#import "NSError+MSIDThrottlingExtension.h"

@implementation MSIDThrottlingService

static NSString *const BASE_MSG_READING_ERROR = @"Throttling checking request error. Error %@";
static NSString *const BASE_MSG_UPDATING_ERROR = @"Throttling updating service error. Error %@";
static NSInteger const MaxRetryAfter = 3600;
static NSInteger const Default429Throttling = 60;
static NSInteger const DefaultUIRequired = 120;

#pragma mark - Initializer

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        _lastRequestTelemetry = [MSIDLastRequestTelemetry sharedInstance];
    }
    return self;
}

- (instancetype _Nonnull)initWithAccessGroup:(NSString *)accessGroup
                                     context:(id<MSIDRequestContext> _Nonnull)context
{
    self = [self init];
    if (self)
    {
        _context = context;
        _accessGroup = accessGroup;
    }
    return self;
}

#pragma mark - Public API

/**
  Base on the thumbprint value of the request, throttling service will query database to see if any existing record and return throttling decision to calling module.
 - NOT throttle case: return result
 - Shoud throttle case: return cached result + update server telemetry + update cache record
 */
- (void)shouldThrottleRequest:(id<MSIDThumbprintCalculatable> _Nonnull)request
                  resultBlock:(nonnull MSIDThrottleResultBlock)resultBlock
{
    if (![MSIDThrottlingService validateInput:request] || !resultBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, BASE_MSG_READING_ERROR, nil);
    }
    
    void (^resultBlockWrapper)(MSIDThrottlingType, NSError *) = ^(MSIDThrottlingType throttlingType, NSError *error)
    {
        resultBlock(throttlingType != MSIDThrottlingTypeNone, error);
    };
    
    BOOL result = [self getThrottleTypeFromDatabase:request resultBlock:resultBlockWrapper];
    
    if (result)
    {
        resultBlock(NO, nil);
    }
    return;
}

/**
 Whenever we receives a response from server, we want to check if any throttling error to update database. This is an public API of throttling service for that task.
 */
- (void)updateThrottlingService:(NSError *)error tokenRequest:(id<MSIDThumbprintCalculatable>)tokenRequest
{
    NSError *throttlingError = nil;
    [self updateThrottlingDatabaseWithRequest:tokenRequest
                                errorResponse:error
                                  returnError:&throttlingError];
    if (throttlingError)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"Throttling error when updating db %@, %ld", throttlingError.domain, (long)throttlingError.code);
    }
}

#pragma mark - Internal API

/**
 Using request's thumbprint to query db
 If it's a hit, we also update telemetry.
*/
- (BOOL)getThrottleTypeFromDatabase:request
                        resultBlock:(void (^)(MSIDThrottlingType throttlingType, NSError *error))resultBlock
{
    MSIDThrottlingType throttlingType = MSIDThrottlingTypeNone;
    NSError *error = nil;
    NSString *strictThumbprint = [request strictRequestThumbprint];
    NSString *fullThumbprint = [request fullRequestThumbprint];
    
    MSIDThrottlingCacheRecord *cacheRecord = [self getDBRecordWithStrictThumbprint:strictThumbprint
                                                                    fullThumbprint:fullThumbprint                                                       error:&error];
    
    if (!cacheRecord)
    {
        // we just log error (if any) and keep moving to the next UIRequired check
        if (error)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, BASE_MSG_READING_ERROR, error);
        }
        return NO;
    }
    else
    {
        // check if we have Interaction Required but expired
        if ([self isInteractionThrottleExpired:cacheRecord thumbprint:fullThumbprint])
        {
            return NO;
        }
        [self updateServerTelemetry:cacheRecord];
        resultBlock(throttlingType, cacheRecord.cachedErrorResponse);
        return YES;
    }
}

- (MSIDThrottlingCacheRecord *)getDBRecordWithStrictThumbprint:(NSString *)strictThumbprint
                                                fullThumbprint:(NSString *)fullThumbprint
                                                         error:(NSError **)error
{
    MSIDThrottlingCacheRecord *cacheRecord = [self.cacheService objectForKey:strictThumbprint                                                  error:error];
    if (!cacheRecord)
    {
        cacheRecord = [self.cacheService objectForKey:fullThumbprint error:error];
    }
    return cacheRecord;
}

- (BOOL)isInteractionThrottleExpired:(MSIDThrottlingCacheRecord *)cacheRecord
                          thumbprint:(NSString *)thumbprint
{
    NSError *error;
    NSDate *currentTime = [NSDate date];
    NSDate *lastRefreshTime = [MSIDThrottlingService getLastRefreshTimeAccessGroup:self.accessGroup context:self.context error:&error];
    // If currentTime is later than the expiration Time or the lastRefreshTime is later then the expiration Time, we clear the cache record
    if ([currentTime compare:cacheRecord.expirationTime] != NSOrderedAscending
        || (lastRefreshTime && [lastRefreshTime compare:cacheRecord.expirationTime] != NSOrderedAscending))
    {
        [self.cacheService removeObjectForKey:thumbprint error:&error];
        if (error)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, BASE_MSG_READING_ERROR, error);
        }
        return YES;
    }
    return NO;
}

- (void)updateThrottlingDatabaseWithRequest:(id<MSIDThumbprintCalculatable> _Nonnull)request
                              errorResponse:(NSError * _Nullable )errorResponse
                                returnError:(NSError *_Nullable *_Nullable)error
{
    NSError *localError = nil;
    MSIDThrottlingType throttleType = [MSIDThrottlingTypeProcessor processErrorResponseToGetThrottleType:errorResponse
                                                                                                   error:&localError];
    if (localError)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, BASE_MSG_UPDATING_ERROR, localError);
        if (error)
        {
            *error = localError;
        }
        return;
    }
    
    if (throttleType == MSIDThrottlingTypeNone) return;
    
    // create throttling record and update to db
    [self createDBRecordAndUpdateWithRequest:request
                               errorResponse:errorResponse
                                throttleType:throttleType
                                 returnError:error];
    
    return;
}

/**
 Prepare record and update to throttling cache
 */
- (void)createDBRecordAndUpdateWithRequest:(id<MSIDThumbprintCalculatable> _Nonnull)request
                             errorResponse:(NSError * _Nullable)errorResponse
                              throttleType:(MSIDThrottlingType)throttleType
                               returnError:(NSError *_Nullable *_Nullable)error
{
    NSString *thumbprint = nil;
    NSInteger throttleDuration = 0;
    
    NSDate *retryHeaderDate = [errorResponse msidGetRetryDateFromError];
    
    switch (throttleType)
    {
        case MSIDThrottlingType429:
            thumbprint = request.strictRequestThumbprint;
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
            break;
        case MSIDThrottlingTypeInteractiveRequired:
            thumbprint = request.fullRequestThumbprint;
            throttleDuration = DefaultUIRequired;
            break;
        default:
            break;
    }
    
    MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:errorResponse
                                                                                    throttleType:throttleType
                                                                                throttleDuration:throttleDuration];
    [self.cacheService setObject:record forKey:thumbprint error:error];        
}

/**
// TODO:  Huge TODO Here
 */
- (void)updateServerTelemetry:(MSIDThrottlingCacheRecord *)cacheRecord
{
    
}

+ (BOOL)validateInput:(id<MSIDThumbprintCalculatable> _Nonnull)request
{
    return (request.fullRequestThumbprint || request.strictRequestThumbprint);
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

/**
 Update last refresh time when interactive flow is complete and success.
 */
+ (BOOL)updateLastRefreshTimeAccessGroup:(NSString * _Nullable)accessGroup
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError*__nullable*__nullable)error
{
    return [MSIDThrottlingMetaDataCache updateLastRefreshTimeWithAccessGroup:accessGroup Context:context error:error];
}

- (MSIDLRUCache *)cacheService
{
    static MSIDLRUCache *cacheService = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cacheService = [[MSIDLRUCache alloc] initWithCacheSize:1000];
    });
    return cacheService;
}

@end
