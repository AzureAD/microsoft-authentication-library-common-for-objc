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

#import "MSIDOnboardingStatusCache.h"
#import "MSIDTokenCacheDataSource.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDOnboardingStatus.h"
#import "MSIDCacheKey.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDJsonObject.h"
#import "MSIDError.h"
#import "MSIDLogger+Internal.h"
#import "MSIDBrokerConstants.h"
#import "NSString+MSIDExtensions.h"

static NSString *const MSID_ONBOARDING_STATUS_CACHE_SERVICE = @"OnboardingStatus";
static NSString *const MSID_ONBOARDING_STATUS_CACHE_ACCOUNT = @"com.microsoft.onboardingStatus";

@interface MSIDOnboardingStatusCache ()

@property (nonatomic) id<MSIDExtendedTokenCacheDataSource> dataSource;
@property (nonatomic) MSIDCacheItemJsonSerializer *serializer;

- (BOOL)isOwnerOverride:(MSIDOnboardingStatus *)status;

@end

@implementation MSIDOnboardingStatusCache

#pragma mark - Shared Instance

+ (MSIDOnboardingStatusCache *)sharedInstance
{
    static MSIDOnboardingStatusCache *singleton = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        singleton = [[self alloc] init];
    });
    
    return singleton;
}

#pragma mark - Init

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:MSIDKeychainTokenCache.defaultKeychainGroup error:nil];
        _serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    }
    
    return self;
}

#pragma mark - Cache Key

- (MSIDCacheKey *)cacheKey
{
    return [[MSIDCacheKey alloc] initWithAccount:MSID_ONBOARDING_STATUS_CACHE_ACCOUNT
                                         service:MSID_ONBOARDING_STATUS_CACHE_SERVICE
                                         generic:nil
                                            type:nil];
}

#pragma mark - Read

- (MSIDOnboardingStatus *)readOnboardingStatusWithCorrelationId:(NSUUID *)correlationId
                                                          error:(NSError *__autoreleasing *)error
{
    MSID_LOG_WITH_CORR(MSIDLogLevelInfo, correlationId, @"(MSIDOnboardingStatusCache) Reading onboarding status from cache");
    
    MSIDCacheKey *key = [self cacheKey];
    
    NSArray<MSIDJsonObject *> *jsonObjects = [self.dataSource jsonObjectsWithKey:key
                                                                      serializer:self.serializer
                                                                         context:nil
                                                                           error:error];
    
    if (!jsonObjects || jsonObjects.count == 0)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelInfo, correlationId, @"(MSIDOnboardingStatusCache) No onboarding status found in cache");
        return nil;
    }
    
    if (jsonObjects.count > 1)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelWarning, correlationId, @"(MSIDOnboardingStatusCache) Multiple onboarding status items found in cache, using the first one");
    }
    
    MSIDJsonObject *jsonObject = jsonObjects.firstObject;
    NSDictionary *jsonDictionary = [jsonObject jsonDictionary];
    
    if (!jsonDictionary)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, correlationId, @"(MSIDOnboardingStatusCache) Failed to get JSON dictionary from cached item");
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to deserialize onboarding status from cache.", nil, nil, nil, correlationId, nil, YES);
        }
        return nil;
    }
    
    NSError *deserializationError = nil;
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:jsonDictionary error:&deserializationError];
    
    if (!status)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, correlationId, @"(MSIDOnboardingStatusCache) Failed to deserialize onboarding status: %@", deserializationError);
        if (error)
        {
            *error = deserializationError;
        }
        return nil;
    }
    
    MSID_LOG_WITH_CORR(MSIDLogLevelInfo, correlationId, @"(MSIDOnboardingStatusCache) Successfully read onboarding status from cache");
    return status;
}

#pragma mark - Write

- (BOOL)writeOnboardingStatus:(MSIDOnboardingStatus *)status
                        error:(NSError *__autoreleasing *)error
{
    if (!status)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, nil, @"(MSIDOnboardingStatusCache) Cannot write nil onboarding status");
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Onboarding status cannot be nil.", nil, nil, nil, nil, nil, YES);
        }
        return NO;
    }
    
    NSUUID *correlationId = status.correlationId;
    
    MSID_LOG_WITH_CORR(MSIDLogLevelInfo, correlationId, @"(MSIDOnboardingStatusCache) Writing onboarding status to cache");
    
    NSDictionary *jsonDictionary = [status jsonDictionary];
    
    if (!jsonDictionary)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, correlationId, @"(MSIDOnboardingStatusCache) Failed to serialize onboarding status to JSON");
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize onboarding status.", nil, nil, nil, correlationId, nil, YES);
        }
        return NO;
    }
    
    NSError *initError = nil;
    MSIDJsonObject *jsonObject = [[MSIDJsonObject alloc] initWithJSONDictionary:jsonDictionary error:&initError];
    
    if (!jsonObject)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, correlationId, @"(MSIDOnboardingStatusCache) Failed to create JSON object: %@", initError);
        if (error)
        {
            *error = initError;
        }
        return NO;
    }
    
    MSIDCacheKey *key = [self cacheKey];
    
    BOOL success = [self.dataSource saveJsonObject:jsonObject
                                        serializer:self.serializer
                                               key:key
                                           context:nil
                                             error:error];
    
    if (success)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelInfo, correlationId, @"(MSIDOnboardingStatusCache) Successfully wrote onboarding status to cache");
    }
    else
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, correlationId, @"(MSIDOnboardingStatusCache) Failed to write onboarding status to cache");
    }
    
    return success;
}

#pragma mark - Remove

- (BOOL)removeOnboardingStatusWithContext:(id<MSIDRequestContext>)context
                                    error:(NSError *__autoreleasing *)error
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"(MSIDOnboardingStatusCache) Removing onboarding status from cache");
    
    MSIDCacheKey *key = [self cacheKey];
    
    // Using removeAccountsWithKey as it internally delegates to removeItemsWithKey
    BOOL success = [self.dataSource removeAccountsWithKey:key
                                                  context:context
                                                    error:error];
    
    if (success)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"(MSIDOnboardingStatusCache) Successfully removed onboarding status from cache");
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"(MSIDOnboardingStatusCache) Failed to remove onboarding status from cache");
    }
    
    return success;
}

#pragma mark - Public Convenience Methods

- (BOOL)isOwnerOverride:(MSIDOnboardingStatus *)status
{
    // This method checks if the onboarding status is owned by the current running app.
    NSString *currentBundleId = [[NSBundle mainBundle] bundleIdentifier];
    if ([NSString msidIsStringNilOrBlank:currentBundleId])
    {
        currentBundleId = @"unknown";
    }
    
    return [currentBundleId caseInsensitiveCompare:status.ownerBundleId] == NSOrderedSame;
}

- (BOOL)setWithStatus:(MSIDOnboardingStatus *)status
{
    if (!status)
    {
        return NO;
    }
    
    MSIDOnboardingStatus *current = [self getOnboardingStatus];
    
    // If there's an existing status with a phase other than none, validate that the new status is either
    // from the same originating bundle or is an owner override. This prevents different apps from overwriting
    // each other's onboarding status.
    if (current && current.phase != MSIDOnboardingPhaseNone)
    {
        NSString *currentBundleId = current.originatingBundleId;
        if ([NSString msidIsStringNilOrBlank:currentBundleId])
        {
            currentBundleId = @"unknown";
        }
        
        // Validate ownership or self-override
        if ([currentBundleId caseInsensitiveCompare:status.originatingBundleId] != NSOrderedSame
            && ![self isOwnerOverride:status])
        {
            return NO;
        }
    }
    
    // Write to Keychain using shared access group
    return [self writeOnboardingStatus:status error:nil];
}

- (MSIDOnboardingStatus *)getOnboardingStatus
{
    MSIDOnboardingStatus *status = [self readOnboardingStatusWithCorrelationId:nil error:nil];
    
    if (!status)
    {
        // return new status with phase set to none
        return [MSIDOnboardingStatus new];
    }
    
    // Check TTL and remove if expired (status.startedAt + status.ttlSeconds < now)
    NSDate *expirationDate = [status.startedAt dateByAddingTimeInterval:status.ttlSeconds];
    if ([expirationDate timeIntervalSinceNow] < 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"(MSIDOnboardingStatusCache) Onboarding status is expired, removing from cache");
        [self removeOnboardingStatusWithContext:nil error:nil];
        // return new status with phase set to none
        return [MSIDOnboardingStatus new];
    }
    
    return status;
}

- (BOOL)clear:(NSString *)bundleId
{
    if ([NSString msidIsStringNilOrBlank:bundleId])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"(MSIDOnboardingStatusCache) Cannot clear with nil bundleId");
        return NO;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"(MSIDOnboardingStatusCache) Clearing onboarding status for bundleId: %@", bundleId);
    
    MSIDOnboardingStatus *current = [self getOnboardingStatus];
    
    // If there's no existing status or the phase is none, there's nothing to clear
    if (!current || current.phase == MSIDOnboardingPhaseNone)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"(MSIDOnboardingStatusCache) No onboarding status found to clear");
        return YES;
    }
    
    // If the current status matches the bundleId (checking ownerBundleId or originatingBundleId), remove it
    if ([current.ownerBundleId caseInsensitiveCompare:bundleId] != NSOrderedSame &&
        [current.originatingBundleId caseInsensitiveCompare:bundleId] != NSOrderedSame)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"(MSIDOnboardingStatusCache) BundleId does not match current status, nothing to clear");
        return NO;
    }
    
    return [self removeOnboardingStatusWithContext:nil error:nil];
}

@end
