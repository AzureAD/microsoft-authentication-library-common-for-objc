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
        _cacheService = [MSIDThrottlingCacheService sharedInstance:10];
        _lastRequestTelemetry = [MSIDLastRequestTelemetry sharedInstance];
    }
    return self;
}

- (instancetype)initWithContext:(id<MSIDRequestContext>)context
{
    self = [self init];
    if (self)
    {
        _context = context;
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
    NSError *error = nil;
    if ([MSIDThrottlingService validateInput:request])
    {
        error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Throttling error: invalid inputs", nil, nil, nil, self.context.correlationId, nil, YES);
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
- (void)updateThrottlingDatabaseWithRequest:(id<MSIDThumbprintCalculatable> _Nonnull)request
                              errorResponse:(NSError * _Nullable )errorResponse
                            isSSOExtRequest:(BOOL)isSSOExtRequest
                                returnError:(NSError *_Nullable *_Nullable)error
{
    NSError *localError = nil;
    MSIDThrottlingType throttleType = [self getThrottleTypeFrom:request
                                                  errorResponse:errorResponse
                                                isSSOExtRequest:isSSOExtRequest
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
                             isSSOExtRequest:isSSOExtRequest
                                throttleType:throttleType
                                 returnError:error];
    
    return;
}


#pragma mark - Internal API
- (MSIDThrottlingType)getThrottleTypeFrom:(id<MSIDThumbprintCalculatable> _Nonnull)request
                            errorResponse:(NSError *)errorResponse
                          isSSOExtRequest:(BOOL)isSSOExtRequest
                                    error:(NSError *_Nullable *_Nullable)error
{
    MSIDThrottlingType throttleType = MSIDThrottlingTypeNone;
    throttleType = [self isResponse429ThrottleTypeWithErrorResponse:errorResponse
                                                    isSSOExtRequest:isSSOExtRequest
                                                              error:error];
                                                   
    if (throttleType == MSIDThrottlingType429) return throttleType;
    throttleType = [self isResponseUIRequiredThrottleType:errorResponse];
    return throttleType;
}

/**
 429 throttle conditions:
 - HTTP Response code is 429 or in 5xx range
 - OR Retry-After in response header
 */
- (MSIDThrottlingType)isResponse429ThrottleTypeWithErrorResponse:(NSError * _Nullable )errorResponse
                                                 isSSOExtRequest:(BOOL)isSSOExtRequest
                                                           error:(NSError *_Nullable *_Nullable)error
{
    MSIDThrottlingType throttleType = MSIDThrottlingTypeNone;
    // TODO: Let assume the error here is MSIDError, we will deal with conversion later:
    // In both scenarios (server error or SSO-ext internal error) broker creates MSALError and return to calling app
    if (errorResponse && [errorResponse.domain isEqualToString:MSIDErrorDomain])
    {
        NSString *httpResponseCode = errorResponse.userInfo[MSIDHTTPResponseCodeKey];
        NSInteger responseCode = [httpResponseCode intValue];
        if (responseCode == 429) throttleType = MSIDThrottlingType429;
        if (responseCode >= 500 && responseCode <= 599) throttleType = MSIDThrottlingType429;
        NSDate *retryHeaderDate = [self getRetryDateFromErrorResponse:errorResponse];
        if (retryHeaderDate)
        {
            throttleType = MSIDThrottlingType429;
        }
    }
    
    return throttleType;
}

/**
 * If not 429, we check if is appliable for UIRequired:
 * error response can be: invalid_request, invalid_client, invalid_scope, invalid_grant, unauthorized_client, interaction_required, access_denied
 */
- (MSIDThrottlingType)isResponseUIRequiredThrottleType:(NSError *)errorResponse
{
    MSIDThrottlingType throttleType = MSIDThrottlingTypeNone;
    // If not 429, we check if is appliable for UIRequired:
    // error response can be: invalid_request, invalid_client, invalid_scope, invalid_grant, unauthorized_client, interaction_required, access_denied

    NSSet *uirequiredErrors = [NSSet setWithArray:@[@"invalid_request", @"invalid_client", @"invalid_scope", @"invalid_grant", @"unauthorized_client", @"interaction_required", @"access_denied"]];
    NSString *errorString = errorResponse.msidOauthError;
    NSUInteger errorCode = errorResponse.code;
    if ([uirequiredErrors containsObject:errorString] || (errorCode == MSIDErrorInteractionRequired))
    {
        throttleType = MSIDThrottlingTypeUIRequired;
    }
    return throttleType;
}

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
    MSIDThrottlingCacheRecord *cacheRecord = [self.cacheService getResponseFromCache:strictThumbprint
                                                                               error:&error];
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
    MSIDThrottlingCacheRecord *cacheRecord = [self.cacheService getResponseFromCache:fullRequestThumbprint
                                                                               error:&error];
    if (!cacheRecord)
    {
        if (error)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, BASE_MSG_READING_ERROR, request);
        }
        return NO;
    }
    else
    {
        NSDate *currentTime = [NSDate date];
        NSDate *lastRefreshTime = [MSIDThrottlingService getLastRefreshTime];
        // If currentTime is later than the expiration Time or the lastRefreshTime is later then the expiration Time, we clear the cache record
        if ([currentTime compare:cacheRecord.expirationTime] != NSOrderedAscending
            || (lastRefreshTime && [lastRefreshTime compare:cacheRecord.expirationTime] != NSOrderedAscending))
        {
            [self.cacheService removeRequestFromCache:fullRequestThumbprint error:&error];
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

/**
 Prepare record and update to throttling cache
 */
- (void)createDBRecordAndUpdateWithRequest:(id<MSIDThumbprintCalculatable> _Nonnull)request
                             errorResponse:(NSError * _Nullable)errorResponse
                           isSSOExtRequest:(BOOL)isSSOExtRequest
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
    
    [self.cacheService addRequestToCache:thumbprint
                           errorResponse:errorResponse
                            throttleType:throttleTypeString
                        throttleDuration:throttleDuration
                                   error:error];
}

- (void)updateServerTelemetry:(MSIDThrottlingCacheRecord *)cacheRecord
{
    
}

- (NSDate *)getRetryDateFromErrorResponse:(NSError * _Nullable)errorResponse
{
    NSDate *retryHeaderDate = nil;
    NSString *retryHeaderString = nil;
    NSDictionary *headerFields = errorResponse.userInfo[MSIDHTTPHeadersKey];
    retryHeaderString = headerFields[@"Retry-After"];
    retryHeaderDate = [NSDate msidDateFromRetryHeader:retryHeaderString];
    return retryHeaderDate;
}

+ (BOOL)validateInput:(id<MSIDThumbprintCalculatable> _Nonnull)request
{
    return (!request.fullRequestThumbprint && !request.strictRequestThumbprint);
}

/**
 Get last refresh time from our NSUserDefaults.
 */
+ (NSDate *)getLastRefreshTime
{
    return nil;
}
@end
