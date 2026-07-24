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
#import "NSString+MSIDExtensions.h"

// Per-session keychain coordinates. Each in-flight request stores its blob under an account
// derived from its session correlation id, so a read/clear addresses exactly one request and
// can never observe or stomp another. Both consumers (broker writer, OneAuth reader) resolve to
// the same slot for a given session id in the shared access group.
static NSString *const kHandoffCacheService = @"DeviceOnboardingBlobHandoff";
static NSString *const kHandoffCacheAccountPrefix = @"com.microsoft.deviceOnboardingBlobHandoff";

// Envelope field keys.
static NSString *const kFieldVersion = @"version";
// session_correlation_id is both (a) the field name INSIDE the onboarding blob (written by
// MSIDOnboardingBlobBuilder), from which we derive the keychain key, and (b) a field we copy into
// our envelope so the clear-time TTL sweep can recover an entry's id and delete it by key. The
// read path does NOT use it — the keychain slot is already keyed on the session id.
static NSString *const kFieldSessionCorrelationId = @"session_correlation_id";
static NSString *const kFieldOnboardingBlob = @"onboardingBlob";
static NSString *const kFieldWrittenAt = @"written_at";

// Envelope schema version. Bump only for breaking envelope-shape changes; purely additive
// fields do not require a bump because the reader keys off field names.
static const NSInteger kEnvelopeVersion = 1;

// GC hygiene / residency window used by the clear-time sweep only. The read path does not enforce
// this — a blob is always returned to its own session regardless of age. This bounds how long an
// entry may linger in the shared keychain, and gives a slow user (bounced out to the system browser
// for SSO/MFA/consent) headroom so their still-in-flight blob isn't swept by another session's
// clear before they return.
static const NSTimeInterval kDefaultHandoffTtlSeconds = 1200.0;

#pragma mark - Envelope

/// Value type owning the on-the-wire envelope shape: it builds the dictionary we persist, parses
/// one back leniently for read / GC, validates the schema version, and answers TTL-expiry. Keeping
/// this in one place means write, read, and the clear-time sweep don't each re-implement the field
/// names, parsing, and expiry rules.
@interface MSIDDeviceOnboardingBlobHandoffEnvelope : NSObject

@property (nonatomic, readonly) NSInteger version;
@property (nonatomic, readonly, nullable) NSString *sessionCorrelationId;
@property (nonatomic, readonly, nullable) NSString *onboardingBlob;
@property (nonatomic, readonly) BOOL hasWrittenAt;
@property (nonatomic, readonly) NSTimeInterval writtenAt;

/// Builds an envelope for a write, stamped with the current schema version and @c writtenAt (unix
/// seconds). Returns nil when @c onboardingBlob is not a valid JSON object, so a malformed payload
/// never reaches the shared keychain (where it would be served back unchanged and silently fail
/// downstream correlation-id parsing).
+ (nullable instancetype)envelopeWithSessionCorrelationId:(NSString *)sessionCorrelationId
                                  onboardingBlob:(NSString *)onboardingBlob
                                       writtenAt:(NSTimeInterval)writtenAt;

/// Parses a stored dictionary. Returns nil only when @c dictionary isn't a dictionary at all;
/// otherwise fields are populated best-effort so the caller can make read vs. GC decisions.
+ (nullable instancetype)envelopeFromJSONDictionary:(nullable NSDictionary *)dictionary;

/// The serialized form persisted to the keychain.
- (NSDictionary *)jsonDictionary;

/// YES when the stamped version matches what this build understands.
- (BOOL)isSupportedVersion;

/// YES when the entry has no usable written_at, or is older than @c ttl at @c now (unix seconds).
- (BOOL)isExpiredAtTime:(NSTimeInterval)now ttl:(NSTimeInterval)ttl;

@end

@implementation MSIDDeviceOnboardingBlobHandoffEnvelope

+ (nullable instancetype)envelopeWithSessionCorrelationId:(NSString *)sessionCorrelationId
                                  onboardingBlob:(NSString *)onboardingBlob
                                       writtenAt:(NSTimeInterval)writtenAt
{
    // Reject anything that isn't a valid JSON object: the blob is opaque to this cache but is
    // consumed downstream as JSON (correlation-id extraction, OneAuth merge), so persisting a
    // malformed value would just plant a silent failure in the shared keychain.
    NSData *data = [onboardingBlob dataUsingEncoding:NSUTF8StringEncoding];
    id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![parsed isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }

    MSIDDeviceOnboardingBlobHandoffEnvelope *envelope = [[MSIDDeviceOnboardingBlobHandoffEnvelope alloc] init];
    envelope->_version = kEnvelopeVersion;
    envelope->_sessionCorrelationId = [sessionCorrelationId copy];
    envelope->_onboardingBlob = [onboardingBlob copy];
    envelope->_writtenAt = writtenAt;
    envelope->_hasWrittenAt = YES;
    return envelope;
}

+ (nullable instancetype)envelopeFromJSONDictionary:(nullable NSDictionary *)dictionary
{
    if (![dictionary isKindOfClass:[NSDictionary class]])
    {
        // A nil dictionary is just a cache miss (no entry) and isn't worth logging; a non-nil,
        // non-dictionary payload means something malformed is actually stored in the keychain.
        if (dictionary != nil)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Ignoring hand-off entry: stored envelope is not a JSON object");
        }
        return nil;
    }

    MSIDDeviceOnboardingBlobHandoffEnvelope *envelope = [[MSIDDeviceOnboardingBlobHandoffEnvelope alloc] init];

    id version = dictionary[kFieldVersion];
    envelope->_version = [version isKindOfClass:[NSNumber class]] ? [(NSNumber *)version integerValue] : 0;

    id sessionId = dictionary[kFieldSessionCorrelationId];
    envelope->_sessionCorrelationId = ([sessionId isKindOfClass:[NSString class]] && ((NSString *)sessionId).length > 0) ? sessionId : nil;

    id blob = dictionary[kFieldOnboardingBlob];
    envelope->_onboardingBlob = ([blob isKindOfClass:[NSString class]] && ((NSString *)blob).length > 0) ? blob : nil;

    id writtenAt = dictionary[kFieldWrittenAt];
    if ([writtenAt isKindOfClass:[NSNumber class]])
    {
        envelope->_writtenAt = [(NSNumber *)writtenAt doubleValue];
        envelope->_hasWrittenAt = YES;
    }

    return envelope;
}

- (NSDictionary *)jsonDictionary
{
    return @{
        kFieldVersion: @(self.version),
        // Stored so the clear-time sweep can recover an expired entry's id and delete it by key.
        kFieldSessionCorrelationId: self.sessionCorrelationId ?: @"",
        kFieldOnboardingBlob: self.onboardingBlob ?: @"",
        kFieldWrittenAt: @(self.writtenAt),
    };
}

- (BOOL)isSupportedVersion
{
    return self.version == kEnvelopeVersion;
}

- (BOOL)isExpiredAtTime:(NSTimeInterval)now ttl:(NSTimeInterval)ttl
{
    if (!self.hasWrittenAt)
    {
        return YES;
    }
    return (now - self.writtenAt) > ttl;
}

@end

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

- (MSIDCacheKey *)cacheKeyForSessionCorrelationId:(NSString *)sessionCorrelationId
{
    // Bake the session correlation id into the account so each in-flight request gets its own
    // keychain slot. Addressing by id means a read never has to validate a stored id against the
    // request, and a clear can only ever remove its own entry.
    NSString *account = [NSString stringWithFormat:@"%@.%@", kHandoffCacheAccountPrefix, sessionCorrelationId];
    return [[MSIDCacheKey alloc] initWithAccount:account
                                         service:kHandoffCacheService
                                         generic:nil
                                            type:nil];
}

- (MSIDCacheKey *)cacheKeyForAllEntries
{
    // Service-only key (nil account) matches every hand-off entry regardless of session id, so the
    // TTL sweep can enumerate them. Never pass this to a remove — a service-only delete would wipe
    // every entry, including fresh ones; expired entries are removed one-by-one via their own key.
    return [[MSIDCacheKey alloc] initWithAccount:nil
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
        if (jsonError)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Could not parse onboarding blob JSON to extract session correlation id: %@", jsonError);
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Could not extract session correlation id from onboarding blob JSON: expected a JSON object");
        }
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
    NSDictionary *jsonDictionary = [self readEnvelopeLockedForSessionCorrelationId:sessionCorrelationId];
    MSIDDeviceOnboardingBlobHandoffEnvelope *envelope = [MSIDDeviceOnboardingBlobHandoffEnvelope envelopeFromJSONDictionary:jsonDictionary];
    if (!envelope)
    {
        return nil;
    }

    // Reject envelopes this build doesn't understand rather than risk mis-merging a differently
    // shaped blob. The keychain key already scopes the entry to this exact session.
    if (![envelope isSupportedVersion])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Ignoring hand-off entry with unsupported envelope version %ld", (long)envelope.version);
        return nil;
    }

    // Intentionally TTL-free on read: a blob is always returned to its own session, even after a
    // long detour through the system browser, so a late-returning user still gets the broker-built
    // steps. Residency is bounded by the clear-time sweep (removeExpiredEntriesLocked), not by read.
    if ([NSString msidIsStringNilOrBlank:envelope.onboardingBlob])
    {
        return nil;
    }

    return envelope.onboardingBlob;
}

#pragma mark - Clear

- (void)clearBlobForSessionCorrelationId:(NSString *)sessionCorrelationId
{
    if ([NSString msidIsStringNilOrBlank:sessionCorrelationId])
    {
        return;
    }

    dispatch_sync(_accessQueue, ^{
        // The key is scoped to this session, so this can only ever remove our own entry.
        [self removeEnvelopeLockedForSessionCorrelationId:sessionCorrelationId];
        // Opportunistically GC entries left behind by requests that were never read back (e.g. the
        // user never returned from the system browser), so stale blobs don't linger in the shared
        // keychain past their TTL.
        [self removeExpiredEntriesLocked];
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
        MSIDDeviceOnboardingBlobHandoffEnvelope *envelope =
            [MSIDDeviceOnboardingBlobHandoffEnvelope envelopeWithSessionCorrelationId:sessionCorrelationId
                                                                      onboardingBlob:blobJson
                                                                           writtenAt:[[NSDate date] timeIntervalSince1970]];
        if (!envelope)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Skipping write: onboarding blob is not valid JSON");
            return;
        }
        success = [self writeEnvelopeLocked:[envelope jsonDictionary] forSessionCorrelationId:sessionCorrelationId];
    });

    return success;
}

#pragma mark - Keychain plumbing

- (nullable NSDictionary *)readEnvelopeLockedForSessionCorrelationId:(NSString *)sessionCorrelationId
{
    NSError *error = nil;
    NSArray<MSIDJsonObject *> *jsonObjects = [self.dataSource jsonObjectsWithKey:[self cacheKeyForSessionCorrelationId:sessionCorrelationId]
                                                                      serializer:self.serializer
                                                                         context:nil
                                                                           error:&error];
    if (error)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Failed to read hand-off entry: %@", error);
        return nil;
    }

    if (!jsonObjects || jsonObjects.count == 0)
    {
        return nil;
    }

    // Return the raw payload and let MSIDDeviceOnboardingBlobHandoffEnvelope validate it, so
    // malformed-entry detection and logging live in one place rather than being silently swallowed
    // here.
    return [jsonObjects.firstObject jsonDictionary];
}

- (BOOL)writeEnvelopeLocked:(NSDictionary *)envelope forSessionCorrelationId:(NSString *)sessionCorrelationId
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
                                               key:[self cacheKeyForSessionCorrelationId:sessionCorrelationId]
                                           context:nil
                                             error:&error];
    if (!success)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Failed to write hand-off entry: %@", error);
    }

    return success;
}

- (void)removeEnvelopeLockedForSessionCorrelationId:(NSString *)sessionCorrelationId
{
    NSError *error = nil;
    BOOL success = [self.dataSource removeAccountsWithKey:[self cacheKeyForSessionCorrelationId:sessionCorrelationId] context:nil error:&error];
    if (!success)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Failed to remove hand-off entry: %@", error);
    }
}

// Enumerates every hand-off entry and removes those whose written_at is older than the TTL (or
// whose written_at is missing/unusable, i.e. a corrupt entry). Each expired entry is deleted by
// its own per-session key, recovered from the envelope's session_correlation_id field.
- (void)removeExpiredEntriesLocked
{
    NSError *error = nil;
    NSArray<MSIDJsonObject *> *jsonObjects = [self.dataSource jsonObjectsWithKey:[self cacheKeyForAllEntries]
                                                                      serializer:self.serializer
                                                                         context:nil
                                                                           error:&error];
    if (error)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"(MSIDDeviceOnboardingBlobHandoffCache) Failed to enumerate hand-off entries for sweep: %@", error);
        return;
    }

    if (!jsonObjects.count)
    {
        return;
    }

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    for (MSIDJsonObject *jsonObject in jsonObjects)
    {
        MSIDDeviceOnboardingBlobHandoffEnvelope *envelope = [MSIDDeviceOnboardingBlobHandoffEnvelope envelopeFromJSONDictionary:[jsonObject jsonDictionary]];
        if ([NSString msidIsStringNilOrBlank:envelope.sessionCorrelationId])
        {
            // No id to address the entry by, so it can't be selectively removed here; leave it.
            continue;
        }

        if ([envelope isExpiredAtTime:now ttl:kDefaultHandoffTtlSeconds])
        {
            [self removeEnvelopeLockedForSessionCorrelationId:envelope.sessionCorrelationId];
        }
    }
}

@end
