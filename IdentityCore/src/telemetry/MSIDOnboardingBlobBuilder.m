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

#import "MSIDOnboardingBlobBuilder.h"
#import "MSIDOnboardingBlobFieldKeys.h"
#import "MSIDSessionCachePersistence.h"

// Seed field keys — must match xplat core (Djinni-generated constants).
static NSString *const MSID_FIELD_SCHEMA_VERSION = @"schema_version";
static NSString *const MSID_FIELD_SESSION_CORRELATION_ID = @"sessionCorrelationId";
static NSString *const MSID_FIELD_ONBOARDING_MODE = @"onboardingMode";
static NSString *const MSID_FIELD_STEPS_LIST = @"stepsList";
static NSString *const MSID_FIELD_STEP_ID = @"stepId";
static NSString *const MSID_FIELD_TS = @"ts";

// The schema version this platform builder understands. Anything else is treated
// as forward-compat passthrough by callers.
static NSString *const MSID_SUPPORTED_SCHEMA_VERSION = @"1.0.0";

// Process-wide serial queue that gates load/mutate/save against the shared
// NSUserDefaults-backed session correlation cache. Multiple concurrent builders
// would otherwise race in `persistSessionCorrelation` and lose entries.
static dispatch_queue_t MSIDOnboardingPersistQueue(void)
{
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.microsoft.identitycore.onboardingblob.persist", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

// Parses `json` into an NSDictionary if and only if the input represents a JSON object.
// Returns nil for nil/empty/non-JSON/non-dictionary inputs.
static NSDictionary * _Nullable MSIDOnboardingParseSeedDictionary(NSString * _Nullable json)
{
    if ([NSString msidIsStringNilOrBlank:json])
    {
        return nil;
    }

    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];

    if (!data)
    {
        return nil;
    }

    NSError *parseError = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];

    if (parseError || ![parsed isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }

    return (NSDictionary *)parsed;
}

@interface MSIDOnboardingBlobBuilder ()

@property (nonatomic, copy) NSString *schemaVersion;
@property (nonatomic, copy) NSString *sessionCorrelationId;
@property (nonatomic, copy) NSString *onboardingMode;

@property (nonatomic, copy) NSString *clientId;
@property (nonatomic, copy) NSString *target;

@property (nonatomic) NSMutableArray<NSDictionary *> *stepsList;
@property (nonatomic) NSMutableArray<NSString *> *blockingErrors;
@property (nonatomic) NSMutableArray<NSString *> *uxFlowUsed;
@property (nonatomic, copy, nullable) NSString *lastLoadedDomain;
@property (nonatomic) BOOL remediationNeeded;

@property (nonatomic) MSIDSessionCachePersistence *sessionCachePersistence;

@end

@implementation MSIDOnboardingBlobBuilder

#pragma mark - Public class API

+ (MSIDOnboardingSeedClassification)classifySeedJson:(NSString *)json
{
    NSDictionary *seed = MSIDOnboardingParseSeedDictionary(json);

    if (!seed)
    {
        return MSIDOnboardingSeedClassificationMalformed;
    }

    NSString *schemaVersion = [seed[MSID_FIELD_SCHEMA_VERSION] isKindOfClass:[NSString class]]
                              ? seed[MSID_FIELD_SCHEMA_VERSION] : nil;

    if (schemaVersion.length == 0)
    {
        // schema_version missing or non-string is treated as malformed; we cannot honor a
        // forward-compat passthrough without at least a version tag. The caller should drop.
        return MSIDOnboardingSeedClassificationMalformed;
    }

    if (![schemaVersion isEqualToString:MSID_SUPPORTED_SCHEMA_VERSION])
    {
        return MSIDOnboardingSeedClassificationUnknownVersion;
    }

    return MSIDOnboardingSeedClassificationSupported;
}

#pragma mark - Init

- (instancetype)initWithSeedJson:(NSString *)json
                        clientId:(NSString *)clientId
                          target:(NSString *)target
{
    self = [super init];

    if (self)
    {
        _clientId = [clientId copy];
        _target = [target copy];
        _stepsList = [NSMutableArray new];
        _blockingErrors = [NSMutableArray new];
        _uxFlowUsed = [NSMutableArray new];
        _sessionCachePersistence = [MSIDSessionCachePersistence new];

        // Parse seed JSON
        NSString *schemaVersion = @"";
        NSString *sessionCorrelationId = @"";
        NSString *onboardingMode = @"";

        NSDictionary *seed = MSIDOnboardingParseSeedDictionary(json);

        if (seed)
        {
            schemaVersion = [seed[MSID_FIELD_SCHEMA_VERSION] isKindOfClass:[NSString class]]
                            ? seed[MSID_FIELD_SCHEMA_VERSION] : @"";
            sessionCorrelationId = [seed[MSID_FIELD_SESSION_CORRELATION_ID] isKindOfClass:[NSString class]]
                                   ? seed[MSID_FIELD_SESSION_CORRELATION_ID] : @"";
            onboardingMode = [seed[MSID_FIELD_ONBOARDING_MODE] isKindOfClass:[NSString class]]
                             ? seed[MSID_FIELD_ONBOARDING_MODE] : @"";
        }

        _schemaVersion = schemaVersion;
        _sessionCorrelationId = sessionCorrelationId;
        _onboardingMode = onboardingMode;
    }

    return self;
}

#pragma mark - Public

- (void)addStep:(NSString *)stepId timestamp:(NSDate *)timestamp
{
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSString *ts = [formatter stringFromDate:timestamp];

    [self.stepsList addObject:@{MSID_FIELD_STEP_ID : stepId, MSID_FIELD_TS : ts}];
}

- (void)addBlockingError:(NSString *)errorCode
{
    [self.blockingErrors addObject:errorCode];
    [self persistSessionCorrelation];
}

- (void)setLastLoadedDomain:(NSString *)domain
{
    _lastLoadedDomain = [domain copy];
}

- (void)setRemediationNeeded:(BOOL)needed
{
    _remediationNeeded = needed;
}

- (void)addUxFlowUsed:(NSString *)flowTag
{
    [self.uxFlowUsed addObject:flowTag];
}

- (NSString *)finalizeBlob
{
    if (self.blockingErrors.count == 0)
    {
        return @"";
    }

    NSMutableDictionary *blob = [NSMutableDictionary dictionary];

    // Seed fields
    blob[MSID_FIELD_SCHEMA_VERSION] = self.schemaVersion;
    blob[MSID_FIELD_SESSION_CORRELATION_ID] = self.sessionCorrelationId;
    blob[MSID_FIELD_ONBOARDING_MODE] = self.onboardingMode;

    // Steps list
    blob[MSID_FIELD_STEPS_LIST] = [self.stepsList copy];

    // Blocking errors
    blob[MSIDOnboardingBlobFieldBlockingErrors] = [self.blockingErrors copy];
    blob[MSIDOnboardingBlobFieldLastBlockingError] = self.blockingErrors.lastObject;

    // Last loaded domain
    if (self.lastLoadedDomain)
    {
        blob[MSIDOnboardingBlobFieldLastLoadedDomain] = self.lastLoadedDomain;
    }

    // Last completed step
    if (self.stepsList.count > 0)
    {
        blob[MSIDOnboardingBlobFieldLastCompletedStep] = self.stepsList.lastObject[MSID_FIELD_STEP_ID];
    }

    // Remediation needed
    if (self.remediationNeeded)
    {
        blob[MSIDOnboardingBlobFieldRemediationNeeded] = @(YES);
    }

    // UX flow used
    if (self.uxFlowUsed.count > 0)
    {
        blob[MSIDOnboardingBlobFieldUxFlowUsed] = [self.uxFlowUsed copy];
    }

    NSError *serializationError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:blob options:0 error:&serializationError];

    if (serializationError || !jsonData)
    {
        return @"";
    }

    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] ?: @"";
}

#pragma mark - Private

- (void)persistSessionCorrelation
{
    // Snapshot mutable state on the calling thread, then apply load/mutate/save under
    // a process-wide serial queue. Without this, two concurrent flows recording a
    // blocking error on different (clientId|target) pairs can read the cache, each
    // mutate their own copy, and the second write loses the first.
    NSString *clientId = self.clientId ?: @"";
    NSString *target = self.target ?: @"";
    NSString *sessionCorrelationId = self.sessionCorrelationId ?: @"";
    MSIDSessionCachePersistence *persistence = self.sessionCachePersistence;

    dispatch_sync(MSIDOnboardingPersistQueue(), ^{
        NSString *existing = [persistence load];
        NSMutableDictionary *cache = [NSMutableDictionary dictionary];

        if (![NSString msidIsStringNilOrBlank:existing])
        {
            NSData *data = [existing dataUsingEncoding:NSUTF8StringEncoding];

            if (data)
            {
                NSError *error = nil;
                id parsed = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];

                if (!error && [parsed isKindOfClass:[NSDictionary class]])
                {
                    [cache addEntriesFromDictionary:parsed];
                }
            }
        }

        NSString *key = [NSString stringWithFormat:@"%@|%@", clientId, target];
        cache[key] = @{
            @"id" : sessionCorrelationId,
            @"ts" : @((long)([[NSDate date] timeIntervalSince1970]))
        };

        NSError *serializationError = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:cache options:0 error:&serializationError];

        if (!serializationError && jsonData)
        {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            [persistence save:jsonString];
        }
    });
}

@end
