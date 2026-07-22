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

#import "MSIDDeviceOnboardingBlobHandoffCache.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDCacheKey.h"
#import "MSIDJsonObject.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDLogger+Internal.h"
#import "MSIDTokenCacheDataSource.h"
#import "NSString+MSIDExtensions.h"

// Single-item keychain coordinates. Both consumers (broker writer, OneAuth reader) resolve to
// this same slot in the shared access group.
static NSString *const kHandoffCacheService = @"DeviceOnboardingBlobHandoff";
static NSString *const kHandoffCacheAccount = @"com.microsoft.deviceOnboardingBlobHandoff";

// Envelope field keys.
static NSString *const kFieldVersion = @"version";
static NSString *const kFieldSessionCorrelationId = @"session_correlation_id";
static NSString *const kFieldOnboardingBlob = @"onboardingBlob";
static NSString *const kFieldWrittenAt = @"written_at";

// Envelope schema version. Bump only for breaking envelope-shape changes; purely additive
// fields do not require a bump because the reader keys off field names.
static const NSInteger kEnvelopeVersion = 1;

// The entry only needs to outlive the user's round trip through the system browser.
static const NSTimeInterval kDefaultHandoffTtlSeconds = 300.0;

@interface MSIDDeviceOnboardingBlobHandoffCache ()
{
    dispatch_queue_t _accessQueue;
}

@property (nonatomic) id<MSIDExtendedTokenCacheDataSource> dataSource;
@property (nonatomic) MSIDCacheItemJsonSerializer *serializer;

@end

@implementation MSIDDeviceOnboardingBlobHandoffCache

#pragma mark - Shared Instance

+ (instancetype)sharedInstance
{
    static MSIDDeviceOnboardingBlobHandoffCache *singleton = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        singleton = [[self alloc] init];
    });

    return singleton;
}

+ (NSTimeInterval)defaultTtlSeconds
{
    return kDefaultHandoffTtlSeconds;
}

+ (NSInteger)envelopeVersion
{
    return kEnvelopeVersion;
}

#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        _dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:MSIDKeychainTokenCache.defaultKeychainGroup error:nil];
        _serializer = [[MSIDCacheItemJsonSerializer alloc] init];
        _accessQueue = dispatch_queue_create("com.microsoft.identity.deviceOnboardingBlobHandoffCache", DISPATCH_QUEUE_SERIAL);
    }

    return self;
}

- (MSIDCacheKey *)cacheKey
{
    return [[MSIDCacheKey alloc] initWithAccount:kHandoffCacheAccount
                                         service:kHandoffCacheService
                                         generic:nil
                                            type:nil];
}

#pragma mark - Session correlation id

+ (nullable NSString *)sessionCorrelationIdFromBlobJson:(nullable NSString *)blobJson
{
    if ([NSString msidIsStringNilOrBlank:blobJson])
    {
        return nil;
    }

    NSData *data = [blobJson dataUsingEncoding:NSUTF8StringEncoding];
    if (!data)
    {
        return nil;
    }

    NSError *jsonError = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (![parsed isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }

    id sessionId = ((NSDictionary *)parsed)[kFieldSessionCorrelationId];
    if (![sessionId isKindOfClass:[NSString class]] || [NSString msidIsStringNilOrBlank:sessionId])
    {
        return nil;
    }

    return (NSString *)sessionId;
}

#pragma mark - Read

- (nullable NSString *)readBlobJsonForSessionCorrelationId:(NSString *)sessionCorrelationId
{
    if ([NSString msidIsStringNilOrBlank:sessionCorrelationId])
    {
        return nil;
    }

    __block NSString *blobJson = nil;
    dispatch_sync(_accessQueue, ^{
        blobJson = [self readBlobJsonForSessionCorrelationIdLocked:sessionCorrelationId];
    });

    return blobJson;
}

- (nullable NSString *)readBlobJsonForSessionCorrelationIdLocked:(NSString *)sessionCorrelationId
{
    NSDictionary *envelope = [self readEnvelopeLocked];
    if (!envelope)
    {
        return nil;
    }

    // Validate the entry belongs to this request before trusting it.
    id storedSessionId = envelope[kFieldSessionCorrelationId];
    if (![storedSessionId isKindOfClass:[NSString class]] ||
        ![(NSString *)storedSessionId isEqualToString:sessionCorrelationId])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Session correlation id mismatch; ignoring entry");
        return nil;
    }

    // Enforce the TTL so a blob abandoned by a prior request can never resurface.
    id writtenAt = envelope[kFieldWrittenAt];
    if ([writtenAt isKindOfClass:[NSNumber class]])
    {
        NSTimeInterval age = [[NSDate date] timeIntervalSince1970] - [(NSNumber *)writtenAt doubleValue];
        if (age < 0 || age > kDefaultHandoffTtlSeconds)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Entry outside TTL (age=%.0fs); removing", age);
            [self removeEnvelopeLocked];
            return nil;
        }
    }

    id blob = envelope[kFieldOnboardingBlob];
    if (![blob isKindOfClass:[NSString class]] || ((NSString *)blob).length == 0)
    {
        return nil;
    }

    return (NSString *)blob;
}

#pragma mark - Clear

- (void)clearBlobForSessionCorrelationId:(NSString *)sessionCorrelationId
{
    if ([NSString msidIsStringNilOrBlank:sessionCorrelationId])
    {
        return;
    }

    dispatch_sync(_accessQueue, ^{
        NSDictionary *envelope = [self readEnvelopeLocked];
        id storedSessionId = envelope[kFieldSessionCorrelationId];
        // Only clear the entry if it is the one we recovered — never stomp another request's blob.
        if ([storedSessionId isKindOfClass:[NSString class]] &&
            [(NSString *)storedSessionId isEqualToString:sessionCorrelationId])
        {
            [self removeEnvelopeLocked];
        }
    });
}

#pragma mark - Write

- (BOOL)writeBlobJson:(NSString *)blobJson
forSessionCorrelationId:(NSString *)sessionCorrelationId
{
    if ([NSString msidIsStringNilOrBlank:blobJson] || [NSString msidIsStringNilOrBlank:sessionCorrelationId])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Skipping write: missing blob or session correlation id");
        return NO;
    }

    __block BOOL success = NO;
    dispatch_sync(_accessQueue, ^{
        NSDictionary *envelope = @{
            kFieldVersion: @(kEnvelopeVersion),
            kFieldSessionCorrelationId: sessionCorrelationId,
            kFieldOnboardingBlob: blobJson,
            kFieldWrittenAt: @([[NSDate date] timeIntervalSince1970]),
        };
        success = [self writeEnvelopeLocked:envelope];
    });

    return success;
}

#pragma mark - Keychain plumbing

- (nullable NSDictionary *)readEnvelopeLocked
{
    NSError *error = nil;
    NSArray<MSIDJsonObject *> *jsonObjects = [self.dataSource jsonObjectsWithKey:[self cacheKey]
                                                                      serializer:self.serializer
                                                                         context:nil
                                                                           error:&error];
    if (!jsonObjects || jsonObjects.count == 0)
    {
        return nil;
    }

    NSDictionary *jsonDictionary = [jsonObjects.firstObject jsonDictionary];
    if (![jsonDictionary isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }

    return jsonDictionary;
}

- (BOOL)writeEnvelopeLocked:(NSDictionary *)envelope
{
    NSError *error = nil;
    MSIDJsonObject *jsonObject = [[MSIDJsonObject alloc] initWithJSONDictionary:envelope error:&error];
    if (!jsonObject)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Failed to build json object: %@", error);
        return NO;
    }

    BOOL success = [self.dataSource saveJsonObject:jsonObject
                                        serializer:self.serializer
                                               key:[self cacheKey]
                                           context:nil
                                             error:&error];
    if (!success)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Failed to write hand-off entry: %@", error);
    }

    return success;
}

- (void)removeEnvelopeLocked
{
    NSError *error = nil;
    [self.dataSource removeAccountsWithKey:[self cacheKey] context:nil error:&error];
}

@end
