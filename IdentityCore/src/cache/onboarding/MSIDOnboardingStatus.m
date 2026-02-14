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

#import "MSIDOnboardingStatus.h"
#import "NSString+MSIDExtensions.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDError.h"

static NSString *const MSID_ONBOARDING_VERSION_JSON_KEY = @"version";
static NSString *const MSID_ONBOARDING_PHASE_JSON_KEY = @"phase";
static NSString *const MSID_ONBOARDING_CONTEXT_JSON_KEY = @"context";
static NSString *const MSID_ONBOARDING_OWNER_BUNDLE_ID_JSON_KEY = @"ownerBundleId";
static NSString *const MSID_ONBOARDING_ORIGINATING_BUNDLE_ID_JSON_KEY = @"originatingBundleId";
static NSString *const MSID_ONBOARDING_ORIGINATING_DISPLAY_NAME_JSON_KEY = @"originatingDisplayName";
static NSString *const MSID_ONBOARDING_CORRELATION_ID_JSON_KEY = @"correlationId";
static NSString *const MSID_ONBOARDING_STARTED_AT_JSON_KEY = @"startedAt";
static NSString *const MSID_ONBOARDING_TTL_SECONDS_JSON_KEY = @"ttlSeconds";
static NSString *const MSID_ONBOARDING_REASON_JSON_KEY = @"reason";

static NSString *const MSID_ONBOARDING_REASON_CODE_JSON_KEY = @"code";
static NSString *const MSID_ONBOARDING_REASON_MESSAGE_JSON_KEY = @"message";

static NSString *const MSID_ONBOARDING_STRING_NONE = @"none";
static NSString *const MSID_ONBOARDING_STRING_UNKNOWN = @"unknown";

static NSString *const MSID_ONBOARDING_PHASE_BROKER_INTERACTIVE_IN_PROGRESS_STRING = @"broker_interactive_in_progress";
static NSString *const MSID_ONBOARDING_PHASE_MDM_ENROLLMENT_IN_PROGRESS_STRING = @"mdm_enrollment_in_progress";
static NSString *const MSID_ONBOARDING_PHASE_FAILED_STRING = @"failed";

static NSString *const MSID_ONBOARDING_CONTEXT_BROKER_STRING = @"broker";
static NSString *const MSID_ONBOARDING_CONTEXT_IN_APP_WEBVIEW_STRING = @"inAppWebview";

static NSString *const MSID_ONBOARDING_REASON_CODE_USER_CANCEL_STRING = @"user_cancel";
static NSString *const MSID_ONBOARDING_REASON_CODE_NETWORK_STRING = @"network";
static NSString *const MSID_ONBOARDING_REASON_CODE_POLICY_STRING = @"policy";

static NSInteger const MSID_ONBOARDING_DEFAULT_TTL_SECONDS = 900;

@implementation MSIDOnboardingReason

- (instancetype)initWithCode:(MSIDOnboardingReasonCode)code
                     message:(NSString *)message
{
    self = [super init];
    if (self)
    {
        _code = code;
        _message = message;
    }
    return self;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing *)error
{
    self = [super init];
    if (!self) return nil;
    
    if (![json isKindOfClass:NSDictionary.class])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Invalid onboarding reason object.", nil, nil, nil, nil, nil, YES);
        }
        return nil;
    }

    NSString *codeString = nil;
    if (![json msidAssertType:NSString.class ofKey:MSID_ONBOARDING_REASON_CODE_JSON_KEY required:YES error:error]) return nil;
    codeString = json[MSID_ONBOARDING_REASON_CODE_JSON_KEY];

    if (![json msidAssertType:NSString.class ofKey:MSID_ONBOARDING_REASON_MESSAGE_JSON_KEY required:NO error:error])
    {
        return nil;
    }

    _message = json[MSID_ONBOARDING_REASON_MESSAGE_JSON_KEY];
    _code = [MSIDOnboardingStatus reasonCodeFromString:codeString];

    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    json[MSID_ONBOARDING_REASON_CODE_JSON_KEY] = [MSIDOnboardingStatus stringFromReasonCode:self.code];

    if (self.message) json[MSID_ONBOARDING_REASON_MESSAGE_JSON_KEY] = self.message;

    return json;
}

@end

@implementation MSIDOnboardingStatus

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _version = 1;
        _phase = MSIDOnboardingPhaseNone;
        _onboardingContext = MSIDOnboardingContextUnknown;
        _ownerBundleId = [[NSBundle mainBundle] bundleIdentifier];
        _originatingBundleId = [[NSBundle mainBundle] bundleIdentifier];
        NSString *displayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        if (!displayName)
        {
            // Fallback to CFBundleName if CFBundleDisplayName is not set
            displayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
        }
        if (![NSString msidIsStringNilOrBlank:displayName])
        {
            _originatingDisplayName = displayName;
        }
        _correlationId = nil;
        _startedAt = [NSDate date];
        _ttlSeconds = MSID_ONBOARDING_DEFAULT_TTL_SECONDS;
        _reason = nil;
    }
    return self;
}

- (instancetype)initWithPhase:(MSIDOnboardingPhase)phase
              onboardingContext:(MSIDOnboardingContext)onboardingContext
                  ownerBundleId:(NSString *)ownerBundleId
                  correlationId:(NSUUID *)correlationId
{
    self = [super init];
    if (self)
    {
        _version = 1;
        _phase = phase;
        _onboardingContext = onboardingContext;
        _ownerBundleId = ownerBundleId;
        _originatingBundleId = [[NSBundle mainBundle] bundleIdentifier];
        NSString *displayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        if (!displayName)
        {
            // Fallback to CFBundleName if CFBundleDisplayName is not set
            displayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
        }
        if (![NSString msidIsStringNilOrBlank:displayName])
        {
            _originatingDisplayName = displayName;
        }
        _correlationId = correlationId ?: [[NSUUID alloc] init];
        _startedAt = [NSDate date];
        _ttlSeconds = MSID_ONBOARDING_DEFAULT_TTL_SECONDS;
    }
    return self;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing *)error
{
    self = [super init];
    if (!self) return nil;
    
    if (![json isKindOfClass:NSDictionary.class])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Invalid onboarding status object.", nil, nil, nil, nil, nil, YES);
        }
        return nil;
    }

    _version = 1;
    if (json[MSID_ONBOARDING_VERSION_JSON_KEY])
    {
        if (![json msidAssertTypeIsOneOf:@[NSString.class, NSNumber.class] ofKey:MSID_ONBOARDING_VERSION_JSON_KEY required:NO error:error]) return nil;
        _version = [json[MSID_ONBOARDING_VERSION_JSON_KEY] integerValue];
    }

    if (![json msidAssertType:NSString.class ofKey:MSID_ONBOARDING_PHASE_JSON_KEY required:YES error:error]) return nil;
    NSString *phaseString = json[MSID_ONBOARDING_PHASE_JSON_KEY];
    
    if (![json msidAssertType:NSString.class ofKey:MSID_ONBOARDING_CONTEXT_JSON_KEY required:YES error:error]) return nil;
    NSString *contextString = json[MSID_ONBOARDING_CONTEXT_JSON_KEY];

    _phase = [MSIDOnboardingStatus onboardingPhaseFromString:phaseString];
    _onboardingContext = [MSIDOnboardingStatus onboardingContextFromString:contextString];

    if (![json msidAssertType:NSString.class ofKey:MSID_ONBOARDING_OWNER_BUNDLE_ID_JSON_KEY required:NO error:error]) return nil;
    _ownerBundleId = json[MSID_ONBOARDING_OWNER_BUNDLE_ID_JSON_KEY];
    
    if (![json msidAssertType:NSString.class ofKey:MSID_ONBOARDING_ORIGINATING_BUNDLE_ID_JSON_KEY required:NO error:error]) return nil;
    _originatingBundleId = json[MSID_ONBOARDING_ORIGINATING_BUNDLE_ID_JSON_KEY];
    
    if (![json msidAssertType:NSString.class ofKey:MSID_ONBOARDING_ORIGINATING_DISPLAY_NAME_JSON_KEY required:NO error:error]) return nil;
    _originatingDisplayName = json[MSID_ONBOARDING_ORIGINATING_DISPLAY_NAME_JSON_KEY];

    if (json[MSID_ONBOARDING_CORRELATION_ID_JSON_KEY])
    {
        if (![json msidAssertType:NSString.class ofKey:MSID_ONBOARDING_CORRELATION_ID_JSON_KEY required:NO error:error]) return nil;
        _correlationId = [[NSUUID alloc] initWithUUIDString:json[MSID_ONBOARDING_CORRELATION_ID_JSON_KEY]];
    }

    if (json[MSID_ONBOARDING_STARTED_AT_JSON_KEY])
    {
        if (![json msidAssertType:NSString.class ofKey:MSID_ONBOARDING_STARTED_AT_JSON_KEY required:NO error:error]) return nil;
        _startedAt = [MSIDOnboardingStatus dateFromISOString:json[MSID_ONBOARDING_STARTED_AT_JSON_KEY]];
    }

    _ttlSeconds = MSID_ONBOARDING_DEFAULT_TTL_SECONDS;
    if (json[MSID_ONBOARDING_TTL_SECONDS_JSON_KEY])
    {
        if (![json msidAssertType:NSNumber.class ofKey:MSID_ONBOARDING_TTL_SECONDS_JSON_KEY required:NO error:error]) return nil;
        _ttlSeconds = [json[MSID_ONBOARDING_TTL_SECONDS_JSON_KEY] integerValue];
    }

    if (json[MSID_ONBOARDING_REASON_JSON_KEY])
    {
        if (![json msidAssertType:NSDictionary.class ofKey:MSID_ONBOARDING_REASON_JSON_KEY required:NO error:error]) return nil;
        _reason = [[MSIDOnboardingReason alloc] initWithJSONDictionary:json[MSID_ONBOARDING_REASON_JSON_KEY] error:error];
        if (!_reason) return nil;
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];

    json[MSID_ONBOARDING_VERSION_JSON_KEY] = @(self.version);
    json[MSID_ONBOARDING_PHASE_JSON_KEY] = [[self class] stringFromPhase:self.phase];
    json[MSID_ONBOARDING_CONTEXT_JSON_KEY] = [[self class] stringFromContext:self.onboardingContext];

    if (self.ownerBundleId) json[MSID_ONBOARDING_OWNER_BUNDLE_ID_JSON_KEY] = self.ownerBundleId;
    if (self.originatingBundleId) json[MSID_ONBOARDING_ORIGINATING_BUNDLE_ID_JSON_KEY] = self.originatingBundleId;
    if (self.originatingDisplayName) json[MSID_ONBOARDING_ORIGINATING_DISPLAY_NAME_JSON_KEY] = self.originatingDisplayName;
    if (self.correlationId) json[MSID_ONBOARDING_CORRELATION_ID_JSON_KEY] = [self.correlationId UUIDString];
    if (self.startedAt) json[MSID_ONBOARDING_STARTED_AT_JSON_KEY] = [[self class] isoStringFromDate:self.startedAt];

    json[MSID_ONBOARDING_TTL_SECONDS_JSON_KEY] = @(_ttlSeconds);

    if (self.reason)
    {
        NSDictionary *reasonJson = [self.reason jsonDictionary];
        if (!reasonJson) return nil;
        json[MSID_ONBOARDING_REASON_JSON_KEY] = reasonJson;
    }

    return json;
}

#pragma mark - Helpers

+ (MSIDOnboardingPhase)onboardingPhaseFromString:(NSString *)onboardingPhaseString
{
    if ([NSString msidIsStringNilOrBlank:onboardingPhaseString])
    {
        return MSIDOnboardingPhaseNone;
    }
    
    if ([onboardingPhaseString caseInsensitiveCompare:MSID_ONBOARDING_STRING_NONE] == NSOrderedSame) return MSIDOnboardingPhaseNone;
    if ([onboardingPhaseString caseInsensitiveCompare:MSID_ONBOARDING_PHASE_BROKER_INTERACTIVE_IN_PROGRESS_STRING] == NSOrderedSame) return MSIDOnboardingPhaseBrokerInteractiveInProgress;
    if ([onboardingPhaseString caseInsensitiveCompare:MSID_ONBOARDING_PHASE_MDM_ENROLLMENT_IN_PROGRESS_STRING] == NSOrderedSame) return MSIDOnboardingPhaseMdmEnrollmentInProgress;
    if ([onboardingPhaseString caseInsensitiveCompare:MSID_ONBOARDING_PHASE_FAILED_STRING] == NSOrderedSame) return MSIDOnboardingPhaseFailed;

    return MSIDOnboardingPhaseNone;
}

+ (NSString *)stringFromPhase:(MSIDOnboardingPhase)phase
{
    switch (phase)
    {
        case MSIDOnboardingPhaseBrokerInteractiveInProgress: return MSID_ONBOARDING_PHASE_BROKER_INTERACTIVE_IN_PROGRESS_STRING;
        case MSIDOnboardingPhaseMdmEnrollmentInProgress: return MSID_ONBOARDING_PHASE_MDM_ENROLLMENT_IN_PROGRESS_STRING;
        case MSIDOnboardingPhaseFailed: return MSID_ONBOARDING_PHASE_FAILED_STRING;
        case MSIDOnboardingPhaseNone:
        default:
            return MSID_ONBOARDING_STRING_NONE;
    }
}

+ (MSIDOnboardingContext)onboardingContextFromString:(NSString *)onboardingContextString
{
    if ([NSString msidIsStringNilOrBlank:onboardingContextString])
    {
        return MSIDOnboardingContextUnknown;
    }
    
    if ([onboardingContextString caseInsensitiveCompare:MSID_ONBOARDING_CONTEXT_BROKER_STRING] == NSOrderedSame) return MSIDOnboardingContextBroker;
    if ([onboardingContextString caseInsensitiveCompare:MSID_ONBOARDING_CONTEXT_IN_APP_WEBVIEW_STRING] == NSOrderedSame) return MSIDOnboardingContextInAppWebview;

    return MSIDOnboardingContextUnknown;
}

+ (NSString *)stringFromContext:(MSIDOnboardingContext)context
{
    switch (context)
    {
        case MSIDOnboardingContextBroker: return MSID_ONBOARDING_CONTEXT_BROKER_STRING;
        case MSIDOnboardingContextInAppWebview: return MSID_ONBOARDING_CONTEXT_IN_APP_WEBVIEW_STRING;
        case MSIDOnboardingContextUnknown:
        default:
            return MSID_ONBOARDING_STRING_UNKNOWN;
    }
}

+ (MSIDOnboardingReasonCode)reasonCodeFromString:(NSString *)reasonCodeString
{
    if ([NSString msidIsStringNilOrBlank:reasonCodeString])
    {
        return MSIDOnboardingReasonCodeUnknown;
    }
    
    if ([reasonCodeString caseInsensitiveCompare:MSID_ONBOARDING_STRING_NONE] == NSOrderedSame) return MSIDOnboardingReasonCodeNone;
    if ([reasonCodeString caseInsensitiveCompare:MSID_ONBOARDING_REASON_CODE_USER_CANCEL_STRING] == NSOrderedSame) return MSIDOnboardingReasonCodeUserCancel;
    if ([reasonCodeString caseInsensitiveCompare:MSID_ONBOARDING_REASON_CODE_NETWORK_STRING] == NSOrderedSame) return MSIDOnboardingReasonCodeNetwork;
    if ([reasonCodeString caseInsensitiveCompare:MSID_ONBOARDING_REASON_CODE_POLICY_STRING] == NSOrderedSame) return MSIDOnboardingReasonCodePolicy;
    if ([reasonCodeString caseInsensitiveCompare:MSID_ONBOARDING_STRING_UNKNOWN] == NSOrderedSame) return MSIDOnboardingReasonCodeUnknown;

    return MSIDOnboardingReasonCodeUnknown;
}

+ (NSString *)stringFromReasonCode:(MSIDOnboardingReasonCode)reasonCode
{
    switch (reasonCode)
    {
        case MSIDOnboardingReasonCodeUserCancel: return MSID_ONBOARDING_REASON_CODE_USER_CANCEL_STRING;
        case MSIDOnboardingReasonCodeNetwork: return MSID_ONBOARDING_REASON_CODE_NETWORK_STRING;
        case MSIDOnboardingReasonCodePolicy: return MSID_ONBOARDING_REASON_CODE_POLICY_STRING;
        case MSIDOnboardingReasonCodeUnknown: return MSID_ONBOARDING_STRING_UNKNOWN;
        case MSIDOnboardingReasonCodeNone:
        default:
            return MSID_ONBOARDING_STRING_NONE;
    }
}

+ (NSDate *)dateFromISOString:(NSString *)string
{
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSISO8601DateFormatter new];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    });

    NSDate *date = [formatter dateFromString:string];
    if (date) return date;

    // Retry without fractional seconds
    static NSISO8601DateFormatter *formatter2;
    static dispatch_once_t onceToken2;
    dispatch_once(&onceToken2, ^{
        formatter2 = [NSISO8601DateFormatter new];
        formatter2.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });

    return [formatter2 dateFromString:string];
}

+ (NSString *)isoStringFromDate:(NSDate *)date
{
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSISO8601DateFormatter new];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });

    return [formatter stringFromDate:date];
}

@end
