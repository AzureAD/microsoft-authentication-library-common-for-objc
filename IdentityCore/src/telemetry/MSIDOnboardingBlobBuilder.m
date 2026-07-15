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
#import "NSString+MSIDExtensions.h"
#import "MSIDOAuth2Constants.h"

// Seed field keys — must match xplat core (Djinni-generated constants).
static NSString *const MSID_ONBOARDING_FIELD_SCHEMA_VERSION = @"schema_version";
static NSString *const MSID_ONBOARDING_FIELD_SESSION_CORRELATION_ID = @"session_correlation_id";
static NSString *const MSID_ONBOARDING_FIELD_ONBOARDING_MODE = @"onboarding_mode";
static NSString *const MSID_ONBOARDING_FIELD_UX_FLOW_USED = @"ux_flow_used";
static NSString *const MSID_ONBOARDING_FIELD_STEPS_LIST = @"steps_list";
static NSString *const MSID_ONBOARDING_FIELD_STEP_ID = @"step_id";
static NSString *const MSID_ONBOARDING_FIELD_TS = @"ts";

// The schema version this platform builder understands. Anything else is treated
// as forward-compat passthrough by callers.
static NSString *const MSID_ONBOARDING_SUPPORTED_SCHEMA_VERSION = @"1.0.0";

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

@property (nonatomic) MSIDSessionCachePersistence *sessionCachePersistence;

@property (nonatomic, readwrite) BOOL strongAuthSetupStarted;

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

    NSString *schemaVersion = [seed[MSID_ONBOARDING_FIELD_SCHEMA_VERSION] isKindOfClass:[NSString class]]
                              ? seed[MSID_ONBOARDING_FIELD_SCHEMA_VERSION] : nil;

    if (schemaVersion.length == 0)
    {
        // schema_version missing or non-string is treated as malformed; we cannot honor a
        // forward-compat passthrough without at least a version tag. The caller should drop.
        return MSIDOnboardingSeedClassificationMalformed;
    }

    if (![schemaVersion isEqualToString:MSID_ONBOARDING_SUPPORTED_SCHEMA_VERSION])
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
            schemaVersion = [seed[MSID_ONBOARDING_FIELD_SCHEMA_VERSION] isKindOfClass:[NSString class]]
                            ? seed[MSID_ONBOARDING_FIELD_SCHEMA_VERSION] : @"";
            sessionCorrelationId = [seed[MSID_ONBOARDING_FIELD_SESSION_CORRELATION_ID] isKindOfClass:[NSString class]]
                                   ? seed[MSID_ONBOARDING_FIELD_SESSION_CORRELATION_ID] : @"";
            onboardingMode = [seed[MSID_ONBOARDING_FIELD_ONBOARDING_MODE] isKindOfClass:[NSString class]]
                             ? seed[MSID_ONBOARDING_FIELD_ONBOARDING_MODE] : @"";

            id seedUxFlowUsed = seed[MSID_ONBOARDING_FIELD_UX_FLOW_USED];

            if ([seedUxFlowUsed isKindOfClass:[NSArray class]])
            {
                for (id flowTag in (NSArray *)seedUxFlowUsed)
                {
                    if ([flowTag isKindOfClass:[NSString class]])
                    {
                        [_uxFlowUsed addObject:flowTag];
                    }
                }
            }

            id seedStepsList = seed[MSID_ONBOARDING_FIELD_STEPS_LIST];

            if ([seedStepsList isKindOfClass:[NSArray class]])
            {
                for (id entry in (NSArray *)seedStepsList)
                {
                    if (![entry isKindOfClass:[NSDictionary class]])
                    {
                        continue;
                    }

                    id stepId = ((NSDictionary *)entry)[MSID_ONBOARDING_FIELD_STEP_ID];
                    id ts = ((NSDictionary *)entry)[MSID_ONBOARDING_FIELD_TS];

                    if ([stepId isKindOfClass:[NSString class]] && [ts isKindOfClass:[NSString class]])
                    {
                        [_stepsList addObject:@{MSID_ONBOARDING_FIELD_STEP_ID : stepId, MSID_ONBOARDING_FIELD_TS : ts}];
                    }
                }
            }

            id seedBlockingErrors = seed[MSIDOnboardingBlobFieldBlockingErrors];

            if ([seedBlockingErrors isKindOfClass:[NSArray class]])
            {
                for (id errorCode in (NSArray *)seedBlockingErrors)
                {
                    if ([errorCode isKindOfClass:[NSString class]])
                    {
                        // Populate _blockingErrors directly rather than calling addBlockingError:
                        // so init does not trigger persistSessionCorrelation — the seed already
                        // represents prior persisted state.
                        [_blockingErrors addObject:errorCode];
                    }
                }
            }

            id seedLastLoadedDomain = seed[MSIDOnboardingBlobFieldLastLoadedDomain];

            if ([seedLastLoadedDomain isKindOfClass:[NSString class]] && [(NSString *)seedLastLoadedDomain length] > 0)
            {
                _lastLoadedDomain = [(NSString *)seedLastLoadedDomain copy];
            }
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

    [self.stepsList addObject:@{MSID_ONBOARDING_FIELD_STEP_ID : stepId, MSID_ONBOARDING_FIELD_TS : ts}];
}

- (void)addBlockingError:(NSString *)errorCode
{
    [self.blockingErrors addObject:errorCode];
}

- (void)setLastLoadedDomain:(NSString *)domain
{
    _lastLoadedDomain = [domain copy];
}

- (void)addUxFlowUsed:(NSString *)flowTag
{
    [self.uxFlowUsed addObject:flowTag];
}

- (void)ensureBrokeredOnboardingMode
{
    if (![self.onboardingMode isEqualToString:MSIDOnboardingModeBrokered])
    {
        self.onboardingMode = MSIDOnboardingModeBrokered;
    }
}

#pragma mark - HTTP Response Telemetry Processing

// Error codes that are returned during normal sign-in flow and should not be
// treated as blocking onboarding errors.
//   50058  UserInformationNotProvided      - User not signed in / no valid SSO session found
//   50097  DeviceAuthenticationRequired    - Device auth interrupt triggered by CA policy
//   50126  InvalidUserNameOrPassword       - Wrong username or password
+ (NSSet<NSString *> *)nonBlockingOnboardingErrorCodes
{
    static NSSet<NSString *> *codes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        codes = [NSSet setWithObjects:@"50058", @"50097", @"50126", nil];
    });
    return codes;
}

- (void)processResponseHeaders:(NSDictionary *)headers responseURL:(NSURL *)responseURL
{
    NSString *host = responseURL.host;
    if (host.length > 0)
    {
        [self setLastLoadedDomain:host];
    }

    NSString *cliTelem = headers[MSID_OAUTH2_CLIENT_TELEMETRY];
    if ([NSString msidIsStringNilOrBlank:cliTelem])
    {
        return;
    }

    // Format: <version>,<error_code>,<suberror_code>,<rt_age>,<spe_info>
    NSArray *components = [cliTelem componentsSeparatedByString:@","];
    if (components.count < 2)
    {
        return;
    }

    NSString *errorCode = [components[1] msidTrimmedString];
    if (errorCode.length == 0 || [errorCode isEqualToString:@"0"])
    {
        return;
    }

    if ([[self.class nonBlockingOnboardingErrorCodes] containsObject:errorCode])
    {
        return;
    }

    [self addBlockingError:errorCode];
    [self recordRemediationStepForErrorCode:errorCode];
}

- (void)recordRemediationStepForErrorCode:(NSString *)errorCode
{
    NSDate *now = [NSDate date];

    // 50079: Strong auth enrollment needed (MFA setup, not MFA fulfillment like 50076/50078)
    if ([errorCode isEqualToString:@"50079"] && !self.strongAuthSetupStarted)
    {
        [self addStep:MSIDOnboardingBlobStepStrongAuthSetupStarted timestamp:now];
        self.strongAuthSetupStarted = YES;
    }
    // 50129 (DeviceIsNotWorkplaceJoined), 501291 (DeviceIsNotWorkplaceJoinedForMamApp): device registration needed
    else if ([errorCode isEqualToString:@"50129"] || [errorCode isEqualToString:@"501291"])
    {
        [self addStep:MSIDOnboardingBlobStepDeviceRegistrationRequired timestamp:now];
    }
    // 530001, 530002: Device not compliant
    else if ([errorCode isEqualToString:@"530001"] || [errorCode isEqualToString:@"530002"])
    {
        [self addStep:MSIDOnboardingBlobStepDeviceNotCompliant timestamp:now];
    }
    // 53000, 530003: MDM enrollment required
    else if ([errorCode isEqualToString:@"53000"] || [errorCode isEqualToString:@"530003"])
    {
        [self addStep:MSIDOnboardingBlobStepMdmEnrollmentRequired timestamp:now];
    }
    // 50127: MAM app, device not registered
    else if ([errorCode isEqualToString:@"50127"])
    {
        [self addStep:MSIDOnboardingBlobStepBrokerInstallPromptedForMAM timestamp:now];
    }
    // 501271: Broker app needs to be installed
    else if ([errorCode isEqualToString:@"501271"])
    {
        [self addStep:MSIDOnboardingBlobStepBrokerInstallPrompted timestamp:now];
    }

    // All other error codes (50076, 50078, 53005, 53003, etc.): blocking error only, no step.
}

- (NSString *)finalizeBlob
{
    NSMutableDictionary *blob = [NSMutableDictionary dictionary];

    // Seed fields
    blob[MSID_ONBOARDING_FIELD_SCHEMA_VERSION] = self.schemaVersion;
    blob[MSID_ONBOARDING_FIELD_SESSION_CORRELATION_ID] = self.sessionCorrelationId;
    blob[MSID_ONBOARDING_FIELD_ONBOARDING_MODE] = self.onboardingMode;

    // Steps list
    blob[MSID_ONBOARDING_FIELD_STEPS_LIST] = [self.stepsList copy];

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
        blob[MSIDOnboardingBlobFieldLastCompletedStep] = self.stepsList.lastObject[MSID_ONBOARDING_FIELD_STEP_ID];
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
        // Log serialization error
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to serialize onboarding blob: %@", serializationError);
        
        return @"";
    }

    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] ?: @"";
}

@end
