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
    if ([MSIDThrottlingService validateInput:request])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, BASE_MSG_READING_ERROR, nil);
    }
    
    // If if any check return TRUE, the resultBlock will be executed inside the check, if not we return result block with shouldBeThrottle = NO
    if ([self is429ThrottleType:request resultBlock:resultBlock] || [self isUIRequiredThrottleType:request resultBlock:resultBlock])
    {
        return;
    }
    
    resultBlock(NO, nil);
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
 return cached error if a request is 429 in db.
 If it's a hit, we also update telemetry.
 */
- (BOOL)is429ThrottleType:(id<MSIDThumbprintCalculatable> _Nonnull)request
              resultBlock:(nonnull MSIDThrottleResultBlock)resultBlock
{
    NSError *error = nil;
    // Check 429 throttling case
    NSString *strictThumbprint = [request strictRequestThumbprint];
    MSIDThrottlingCacheRecord *cacheRecord = [self.cacheService objectForKey:strictThumbprint                                                  error:&error];
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
        [self updateServerTelemetry:cacheRecord];
        resultBlock(YES, cacheRecord.cachedErrorResponse);
        return YES;
    }
}

/**
 return cached error if a request is UIRequired in db.
 If it's a hit, we also update telemetry.
 */
- (BOOL)isUIRequiredThrottleType:(id<MSIDThumbprintCalculatable> _Nonnull)request
                     resultBlock:(nonnull MSIDThrottleResultBlock)resultBlock
{
    NSError *error = nil;
    NSString *fullRequestThumbprint = [request fullRequestThumbprint];
    MSIDThrottlingCacheRecord *cacheRecord = [self.cacheService objectForKey:fullRequestThumbprint                                                  error:&error];
    if (!cacheRecord)
    {
        if (error)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, BASE_MSG_READING_ERROR, error);
        }
        return NO;
    }
    else
    {
        NSDate *currentTime = [NSDate date];
        NSDate *lastRefreshTime = [MSIDThrottlingService getLastRefreshTimeAccessGroup:self.accessGroup context:self.context error:&error];
        // If currentTime is later than the expiration Time or the lastRefreshTime is later then the expiration Time, we clear the cache record
        if ([currentTime compare:cacheRecord.expirationTime] != NSOrderedAscending
            || (lastRefreshTime && [lastRefreshTime compare:cacheRecord.expirationTime] != NSOrderedAscending))
        {
            [self.cacheService removeObjectForKey:fullRequestThumbprint error:&error];
            if (error)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, BASE_MSG_READING_ERROR, error);
            }
            return NO;
        }
        
        // Expiration time still valid, we have a valid throttle case here so return cache response to calling
        [self updateServerTelemetry:cacheRecord];
        resultBlock(YES, cacheRecord.cachedErrorResponse);
        return YES;
    }
}

- (void)updateThrottlingDatabaseWithRequest:(id<MSIDThumbprintCalculatable> _Nonnull)request
                              errorResponse:(NSError * _Nullable )errorResponse
                                returnError:(NSError *_Nullable *_Nullable)error
{
    NSError *localError = nil;
    MSIDThrottlingType throttleType = [self getThrottleTypeFromRequest:request
                                                         errorResponse:errorResponse
                                                                 error:&localError] ;
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

- (MSIDThrottlingType)getThrottleTypeFromRequest:(id<MSIDThumbprintCalculatable> _Nonnull)request
                                   errorResponse:(NSError *)errorResponse
                                           error:(NSError *_Nullable *_Nullable)error
{
    
    MSIDThrottlingType throttleType = MSIDThrottlingTypeNone;
    throttleType = [self get429ThrottleTypeWithErrorResponse:errorResponse
                                                       error:error];
                                                   
    if (throttleType == MSIDThrottlingType429) return throttleType;
    throttleType = [self getUIRequiredThrottleTypeWithErrorResponse:errorResponse];
    return throttleType;
}

/**
 429 throttle conditions:
 - HTTP Response code is 429 or in 5xx range
 - OR Retry-After in response header
 */
- (MSIDThrottlingType)get429ThrottleTypeWithErrorResponse:(NSError * _Nullable )errorResponse
                                                    error:(NSError *_Nullable *_Nullable)error
{
    MSIDThrottlingType throttleType = MSIDThrottlingTypeNone;
    /**
     In SSO-Ext flow, it can be both MSAL or MSID Error. If it's MSALErrorDomain, we need to extract information we need (error code and user info)
     */
    BOOL isMSIDError = [errorResponse.domain hasPrefix:@"MSID"];
    NSString *httpResponseCode = errorResponse.userInfo[isMSIDError ? MSIDHTTPResponseCodeKey : @"MSALHTTPResponseCodeKey"];
    NSInteger responseCode = [httpResponseCode intValue];
    if (responseCode == 429) throttleType = MSIDThrottlingType429;
    if (responseCode >= 500 && responseCode <= 599) throttleType = MSIDThrottlingType429;
    NSDate *retryHeaderDate = [self getRetryDateFromErrorResponse:errorResponse];
    if (retryHeaderDate)
    {
        throttleType = MSIDThrottlingType429;
    }
    
    return throttleType;
}

/**
 * If not 429, we check if is appliable for UIRequired:
 * error response can be: invalid_request, invalid_client, invalid_scope, invalid_grant, unauthorized_client, interaction_required, access_denied
 */
- (MSIDThrottlingType)getUIRequiredThrottleTypeWithErrorResponse:(NSError *)errorResponse
{
    MSIDThrottlingType throttleType = MSIDThrottlingTypeNone;
    // If not 429, we check if is appliable for UIRequired:
    // error response can be: invalid_request, invalid_client, invalid_scope, invalid_grant, unauthorized_client, interaction_required, access_denied

    NSSet *uirequiredErrors = [NSSet setWithArray:@[@"invalid_request", @"invalid_client", @"invalid_scope", @"invalid_grant", @"unauthorized_client", @"interaction_required", @"access_denied"]];
    BOOL isMSIDError = [errorResponse.domain hasPrefix:@"MSID"];
    
    if (isMSIDError)
    {
        NSString *errorString = errorResponse.msidOauthError;
        NSUInteger errorCode = errorResponse.code;
        if ([uirequiredErrors containsObject:errorString] || (errorCode == MSIDErrorInteractionRequired))
        {
            throttleType = MSIDThrottlingTypeUIRequired;
        }
    }
    else
    {
        // -50002 = MSALErrorInteractionRequired
        if (errorResponse.code == -50002)
        {
            throttleType = MSIDThrottlingTypeUIRequired;
        }
    }
    
    return throttleType;
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
    NSString *throttleTypeString = nil;
    NSInteger throttleDuration = 0;
    
    NSDate *retryHeaderDate = [self getRetryDateFromErrorResponse:errorResponse];
    
    switch (throttleType)
    {
        case MSIDThrottlingType429:
            thumbprint = request.strictRequestThumbprint;
            throttleTypeString = @"MSIDThrottlingType429";
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
        case MSIDThrottlingTypeUIRequired:
            thumbprint = request.fullRequestThumbprint;
            throttleTypeString = @"MSIDThrottlingTypeUIRequired";
            throttleDuration = DefaultUIRequired;
            break;
        default:
            break;
    }
    
    MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:errorResponse
                                                                                    throttleType:throttleTypeString
                                                                                throttleDuration:throttleDuration];
    [self.cacheService setObject:record forKey:thumbprint error:error];        
}

/**
// TODO:  Huge TODO Here
 */
- (void)updateServerTelemetry:(MSIDThrottlingCacheRecord *)cacheRecord
{
    
}

- (NSDate *)getRetryDateFromErrorResponse:(NSError * _Nullable)errorResponse
{
    NSDate *retryHeaderDate = nil;
    NSString *retryHeaderString = nil;
    NSDictionary *headerFields = [errorResponse.domain hasPrefix:@"MSID"] ? errorResponse.userInfo[MSIDHTTPHeadersKey] : errorResponse.userInfo[@"MSALHTTPHeadersKey"];
    retryHeaderString = headerFields[@"Retry-After"];
    retryHeaderDate = [NSDate msidDateFromRetryHeader:retryHeaderString];
    return retryHeaderDate;
}

+ (BOOL)validateInput:(id<MSIDThumbprintCalculatable> _Nonnull)request
{
    return (!request.fullRequestThumbprint && !request.strictRequestThumbprint);
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
