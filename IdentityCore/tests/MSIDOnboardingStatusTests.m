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

#import <XCTest/XCTest.h>

#import "MSIDOnboardingStatus.h"

@interface MSIDOnboardingStatusTests : XCTestCase
@end

@implementation MSIDOnboardingStatusTests

- (void)testInitWithJSONDictionary_whenValidJSON_shouldParse
{
    NSDictionary *json = @{
        @"version" : @1,
        @"phase" : @"broker_interactive_in_progress",
        @"context" : @"broker",
        @"ownerBundleId" : @"com.microsoft.azureauthenticator",
        @"originatingBundleId" : @"com.microsoft.teams",
        @"originatingDisplayName" : @"Teams",
        @"correlationId" : @"f2b9c6e7-1234-5678-90ab-abcdef123456",
        @"startedAt" : @"2025-10-03T20:15:00Z",
        @"ttlSeconds" : @900,
        @"reason" : @{ @"code" : @"none" }
    };

    NSError *error = nil;
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(status);
    XCTAssertNil(error);

    XCTAssertEqual(status.version, 1);
    XCTAssertEqual(status.phase, MSIDOnboardingPhaseBrokerInteractiveInProgress);
    XCTAssertEqual(status.onboardingContext, MSIDOnboardingContextBroker);
    XCTAssertEqualObjects(status.ownerBundleId, @"com.microsoft.azureauthenticator");
    XCTAssertEqualObjects(status.originatingBundleId, @"com.microsoft.teams");
    XCTAssertEqualObjects(status.originatingDisplayName, @"Teams");
    XCTAssertEqualObjects(status.correlationId.UUIDString.lowercaseString, @"f2b9c6e7-1234-5678-90ab-abcdef123456");
    XCTAssertNotNil(status.startedAt);
    XCTAssertEqual(status.ttlSeconds, 900);
    XCTAssertNotNil(status.reason);
    XCTAssertEqual(status.reason.code, MSIDOnboardingReasonCodeNone);
}

- (void)testJsonDictionary_whenRoundtrip_shouldMatchExpectedKeys
{
    MSIDOnboardingReason *reason = [[MSIDOnboardingReason alloc] initWithCode:MSIDOnboardingReasonCodeUserCancel message:@"User canceled enrollment"];
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithPhase:MSIDOnboardingPhaseFailed
                                                             onboardingContext:MSIDOnboardingContextInAppWebview
                                                                 ownerBundleId:@"com.microsoft.azureauthenticator"
                                                                 correlationId:[[NSUUID alloc] initWithUUIDString:@"f2b9c6e7-1234-5678-90ab-abcdef123456"]];
    status.reason = reason;

    NSDictionary *json = [status jsonDictionary];

    XCTAssertEqualObjects(json[@"version"], @1);
    XCTAssertEqualObjects(json[@"phase"], @"failed");
    XCTAssertEqualObjects(json[@"context"], @"inAppWebview");
    XCTAssertEqualObjects(json[@"ownerBundleId"], @"com.microsoft.azureauthenticator");
    XCTAssertNotNil(json[@"originatingBundleId"]); // Set from main bundle
    XCTAssertEqualObjects(json[@"correlationId"], @"F2B9C6E7-1234-5678-90AB-ABCDEF123456");
    XCTAssertNotNil(json[@"startedAt"]); // Set automatically
    XCTAssertEqualObjects(json[@"ttlSeconds"], @900);

    NSDictionary *reasonJson = json[@"reason"];
    XCTAssertEqualObjects(reasonJson[@"code"], @"user_cancel");
    XCTAssertEqualObjects(reasonJson[@"message"], @"User canceled enrollment");
}

- (void)testInitWithJSONDictionary_whenTTLIsMissing_shouldDefault
{
    NSDictionary *json = @{
        @"phase" : @"mdm_enrollment_in_progress",
        @"context" : @"inAppWebview"
    };

    NSError *error = nil;
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(status);
    XCTAssertNil(error);
    XCTAssertEqual(status.ttlSeconds, 900);
}

- (void)testInitWithJSONDictionary_whenPhaseMissing_shouldFail
{
    NSDictionary *json = @{
        @"context" : @"broker"
    };

    NSError *error = nil;
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(status);
    XCTAssertNotNil(error);
}

- (void)testInitWithJSONDictionary_whenContextMissing_shouldFail
{
    NSDictionary *json = @{
        @"phase" : @"none"
    };

    NSError *error = nil;
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(status);
    XCTAssertNotNil(error);
}

- (void)testInitWithJSONDictionary_whenVersionMissing_shouldDefaultToOne
{
    NSDictionary *json = @{
        @"phase" : @"none",
        @"context" : @"broker"
    };

    NSError *error = nil;
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(status);
    XCTAssertNil(error);
    XCTAssertEqual(status.version, 1);
}

- (void)testInitWithJSONDictionary_whenVersionIsString_shouldParse
{
    NSDictionary *json = @{
        @"version" : @"2",
        @"phase" : @"none",
        @"context" : @"broker"
    };

    NSError *error = nil;
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(status);
    XCTAssertNil(error);
    XCTAssertEqual(status.version, 2);
}

- (void)testInitWithJSONDictionary_whenOnlyRequiredFields_shouldParseWithDefaults
{
    NSDictionary *json = @{
        @"phase" : @"failed",
        @"context" : @"unknown"
    };

    NSError *error = nil;
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(status);
    XCTAssertNil(error);
    XCTAssertEqual(status.phase, MSIDOnboardingPhaseFailed);
    XCTAssertEqual(status.onboardingContext, MSIDOnboardingContextUnknown);
    XCTAssertEqual(status.version, 1);
    XCTAssertEqual(status.ttlSeconds, 900);
    XCTAssertNil(status.ownerBundleId);
    XCTAssertNil(status.originatingBundleId);
    XCTAssertNil(status.originatingDisplayName);
    XCTAssertNil(status.correlationId);
    XCTAssertNil(status.reason);
}

- (void)testInitWithJSONDictionary_whenNonDictionaryInput_shouldFail
{
    NSError *error = nil;
    NSArray *notADict = @[@"not", @"a", @"dict"];
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:(NSDictionary *)notADict error:&error];

    XCTAssertNil(status);
    XCTAssertNotNil(error);
}

- (void)testInitWithJSONDictionary_whenStartedAtHasFractionalSeconds_shouldParse
{
    NSDictionary *json = @{
        @"phase" : @"broker_interactive_in_progress",
        @"context" : @"broker",
        @"startedAt" : @"2025-10-03T20:15:00.123Z"
    };

    NSError *error = nil;
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(status);
    XCTAssertNil(error);
    XCTAssertNotNil(status.startedAt);
}

- (void)testInitWithJSONDictionary_whenReasonHasMessage_shouldParseMessage
{
    NSDictionary *json = @{
        @"phase" : @"failed",
        @"context" : @"broker",
        @"reason" : @{
            @"code" : @"network",
            @"message" : @"Connection timed out"
        }
    };

    NSError *error = nil;
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(status);
    XCTAssertNil(error);
    XCTAssertNotNil(status.reason);
    XCTAssertEqual(status.reason.code, MSIDOnboardingReasonCodeNetwork);
    XCTAssertEqualObjects(status.reason.message, @"Connection timed out");
}

- (void)testInitWithJSONDictionary_whenReasonMissingCode_shouldFail
{
    NSDictionary *json = @{
        @"phase" : @"failed",
        @"context" : @"broker",
        @"reason" : @{
            @"message" : @"some message"
        }
    };

    NSError *error = nil;
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(status);
    XCTAssertNotNil(error);
}

#pragma mark - init (default)

- (void)testInit_shouldSetDefaultValues
{
    MSIDOnboardingStatus *status = [MSIDOnboardingStatus new];

    XCTAssertEqual(status.version, 1);
    XCTAssertEqual(status.phase, MSIDOnboardingPhaseNone);
    XCTAssertEqual(status.onboardingContext, MSIDOnboardingContextUnknown);
    XCTAssertNotNil(status.ownerBundleId);
    XCTAssertNotNil(status.startedAt);
    XCTAssertEqual(status.ttlSeconds, 900);
    XCTAssertNil(status.correlationId);
    XCTAssertNil(status.reason);
}

#pragma mark - initWithPhase tests

- (void)testInitWithPhase_whenCalled_shouldSetProperties
{
    NSUUID *correlationId = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithPhase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                                             onboardingContext:MSIDOnboardingContextBroker
                                                                 ownerBundleId:@"com.test"
                                                                 correlationId:correlationId];

    XCTAssertEqual(status.version, 1);
    XCTAssertEqual(status.phase, MSIDOnboardingPhaseBrokerInteractiveInProgress);
    XCTAssertEqual(status.onboardingContext, MSIDOnboardingContextBroker);
    XCTAssertEqualObjects(status.ownerBundleId, @"com.test");
    XCTAssertEqualObjects(status.correlationId, correlationId);
    XCTAssertNotNil(status.startedAt);
    XCTAssertEqual(status.ttlSeconds, 900);
}

- (void)testInitWithPhase_whenCorrelationIdNil_shouldGenerateNew
{
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithPhase:MSIDOnboardingPhaseNone
                                                             onboardingContext:MSIDOnboardingContextUnknown
                                                                 ownerBundleId:@"com.test"
                                                                 correlationId:nil];

    XCTAssertNotNil(status.correlationId);
}

#pragma mark - jsonDictionary

- (void)testJsonDictionary_whenMinimalFields_shouldOmitOptionals
{
    MSIDOnboardingStatus *status = [MSIDOnboardingStatus new];

    NSDictionary *json = [status jsonDictionary];

    XCTAssertNotNil(json);
    XCTAssertEqualObjects(json[@"version"], @1);
    XCTAssertEqualObjects(json[@"phase"], @"none");
    XCTAssertEqualObjects(json[@"context"], @"unknown");
    XCTAssertEqualObjects(json[@"ttlSeconds"], @900);
    XCTAssertNotNil(json[@"startedAt"]);
    XCTAssertNotNil(json[@"ownerBundleId"]);
    XCTAssertNil(json[@"correlationId"]);
    XCTAssertNil(json[@"reason"]);
}

- (void)testJsonDictionary_thenInitFromJSON_shouldRoundtrip
{
    // Create the original status from JSON to set all the fields precisely
    NSDictionary *originalJson = @{
        @"version" : @1,
        @"phase" : @"mdm_enrollment_in_progress",
        @"context" : @"broker",
        @"ownerBundleId" : @"com.microsoft.azureauthenticator",
        @"originatingBundleId" : @"com.microsoft.outlook",
        @"originatingDisplayName" : @"Outlook",
        @"correlationId" : @"abcdef12-3456-7890-abcd-ef1234567890",
        @"startedAt" : @"1970-01-12T13:46:40Z",
        @"ttlSeconds" : @600,
        @"reason" : @{
            @"code" : @"policy",
            @"message" : @"Policy violation"
        }
    };

    NSError *error = nil;
    MSIDOnboardingStatus *original = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:originalJson error:&error];
    XCTAssertNotNil(original);
    XCTAssertNil(error);

    NSDictionary *json = [original jsonDictionary];
    MSIDOnboardingStatus *parsed = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(parsed);
    XCTAssertNil(error);
    XCTAssertEqual(parsed.version, original.version);
    XCTAssertEqual(parsed.phase, original.phase);
    XCTAssertEqual(parsed.onboardingContext, original.onboardingContext);
    XCTAssertEqualObjects(parsed.ownerBundleId, original.ownerBundleId);
    XCTAssertEqualObjects(parsed.originatingBundleId, original.originatingBundleId);
    XCTAssertEqualObjects(parsed.originatingDisplayName, original.originatingDisplayName);
    XCTAssertEqualObjects(parsed.correlationId, original.correlationId);
    XCTAssertEqual(parsed.ttlSeconds, original.ttlSeconds);
    XCTAssertEqual(parsed.reason.code, original.reason.code);
    XCTAssertEqualObjects(parsed.reason.message, original.reason.message);
}

#pragma mark - onboardingPhaseFromString

- (void)testOnboardingPhaseFromString_allValues
{
    XCTAssertEqual([MSIDOnboardingStatus onboardingPhaseFromString:@"none"], MSIDOnboardingPhaseNone);
    XCTAssertEqual([MSIDOnboardingStatus onboardingPhaseFromString:@"broker_interactive_in_progress"], MSIDOnboardingPhaseBrokerInteractiveInProgress);
    XCTAssertEqual([MSIDOnboardingStatus onboardingPhaseFromString:@"mdm_enrollment_in_progress"], MSIDOnboardingPhaseMdmEnrollmentInProgress);
    XCTAssertEqual([MSIDOnboardingStatus onboardingPhaseFromString:@"failed"], MSIDOnboardingPhaseFailed);
}

- (void)testOnboardingPhaseFromString_whenCaseInsensitive_shouldParse
{
    XCTAssertEqual([MSIDOnboardingStatus onboardingPhaseFromString:@"FAILED"], MSIDOnboardingPhaseFailed);
    XCTAssertEqual([MSIDOnboardingStatus onboardingPhaseFromString:@"Broker_Interactive_In_Progress"], MSIDOnboardingPhaseBrokerInteractiveInProgress);
}

- (void)testOnboardingPhaseFromString_whenUnknownValue_shouldReturnNone
{
    XCTAssertEqual([MSIDOnboardingStatus onboardingPhaseFromString:@"something_unexpected"], MSIDOnboardingPhaseNone);
}

- (void)testOnboardingPhaseFromString_whenEmptyString_shouldReturnNone
{
    XCTAssertEqual([MSIDOnboardingStatus onboardingPhaseFromString:@""], MSIDOnboardingPhaseNone);
}

#pragma mark - stringFromPhase

- (void)testStringFromPhase_allValues
{
    XCTAssertEqualObjects([MSIDOnboardingStatus stringFromPhase:MSIDOnboardingPhaseNone], @"none");
    XCTAssertEqualObjects([MSIDOnboardingStatus stringFromPhase:MSIDOnboardingPhaseBrokerInteractiveInProgress], @"broker_interactive_in_progress");
    XCTAssertEqualObjects([MSIDOnboardingStatus stringFromPhase:MSIDOnboardingPhaseMdmEnrollmentInProgress], @"mdm_enrollment_in_progress");
    XCTAssertEqualObjects([MSIDOnboardingStatus stringFromPhase:MSIDOnboardingPhaseFailed], @"failed");
}

#pragma mark - onboardingContextFromString

- (void)testOnboardingContextFromString_allValues
{
    XCTAssertEqual([MSIDOnboardingStatus onboardingContextFromString:@"broker"], MSIDOnboardingContextBroker);
    XCTAssertEqual([MSIDOnboardingStatus onboardingContextFromString:@"inAppWebview"], MSIDOnboardingContextInAppWebview);
}

- (void)testOnboardingContextFromString_whenCaseInsensitive_shouldParse
{
    XCTAssertEqual([MSIDOnboardingStatus onboardingContextFromString:@"BROKER"], MSIDOnboardingContextBroker);
    XCTAssertEqual([MSIDOnboardingStatus onboardingContextFromString:@"InAppWebView"], MSIDOnboardingContextInAppWebview);
}

- (void)testOnboardingContextFromString_whenUnknownValue_shouldReturnUnknown
{
    XCTAssertEqual([MSIDOnboardingStatus onboardingContextFromString:@"something_else"], MSIDOnboardingContextUnknown);
}

- (void)testOnboardingContextFromString_whenEmptyString_shouldReturnUnknown
{
    XCTAssertEqual([MSIDOnboardingStatus onboardingContextFromString:@""], MSIDOnboardingContextUnknown);
}

#pragma mark - stringFromContext

- (void)testStringFromContext_allValues
{
    XCTAssertEqualObjects([MSIDOnboardingStatus stringFromContext:MSIDOnboardingContextUnknown], @"unknown");
    XCTAssertEqualObjects([MSIDOnboardingStatus stringFromContext:MSIDOnboardingContextBroker], @"broker");
    XCTAssertEqualObjects([MSIDOnboardingStatus stringFromContext:MSIDOnboardingContextInAppWebview], @"inAppWebview");
}

#pragma mark - reasonCodeFromString

- (void)testReasonCodeFromString_allValues
{
    XCTAssertEqual([MSIDOnboardingStatus reasonCodeFromString:@"none"], MSIDOnboardingReasonCodeNone);
    XCTAssertEqual([MSIDOnboardingStatus reasonCodeFromString:@"user_cancel"], MSIDOnboardingReasonCodeUserCancel);
    XCTAssertEqual([MSIDOnboardingStatus reasonCodeFromString:@"network"], MSIDOnboardingReasonCodeNetwork);
    XCTAssertEqual([MSIDOnboardingStatus reasonCodeFromString:@"policy"], MSIDOnboardingReasonCodePolicy);
    XCTAssertEqual([MSIDOnboardingStatus reasonCodeFromString:@"unknown"], MSIDOnboardingReasonCodeUnknown);
}

- (void)testReasonCodeFromString_whenCaseInsensitive_shouldParse
{
    XCTAssertEqual([MSIDOnboardingStatus reasonCodeFromString:@"USER_CANCEL"], MSIDOnboardingReasonCodeUserCancel);
    XCTAssertEqual([MSIDOnboardingStatus reasonCodeFromString:@"Network"], MSIDOnboardingReasonCodeNetwork);
}

- (void)testReasonCodeFromString_whenUnrecognized_shouldReturnUnknown
{
    XCTAssertEqual([MSIDOnboardingStatus reasonCodeFromString:@"something_random"], MSIDOnboardingReasonCodeUnknown);
}

- (void)testReasonCodeFromString_whenEmptyString_shouldReturnUnknown
{
    XCTAssertEqual([MSIDOnboardingStatus reasonCodeFromString:@""], MSIDOnboardingReasonCodeUnknown);
}

#pragma mark - stringFromReasonCode

- (void)testStringFromReasonCode_allValues
{
    XCTAssertEqualObjects([MSIDOnboardingStatus stringFromReasonCode:MSIDOnboardingReasonCodeNone], @"none");
    XCTAssertEqualObjects([MSIDOnboardingStatus stringFromReasonCode:MSIDOnboardingReasonCodeUserCancel], @"user_cancel");
    XCTAssertEqualObjects([MSIDOnboardingStatus stringFromReasonCode:MSIDOnboardingReasonCodeNetwork], @"network");
    XCTAssertEqualObjects([MSIDOnboardingStatus stringFromReasonCode:MSIDOnboardingReasonCodePolicy], @"policy");
    XCTAssertEqualObjects([MSIDOnboardingStatus stringFromReasonCode:MSIDOnboardingReasonCodeUnknown], @"unknown");
}

#pragma mark - MSIDOnboardingReason JSON

- (void)testReasonInitWithJSONDictionary_whenValidWithMessage_shouldParse
{
    NSDictionary *json = @{
        @"code" : @"policy",
        @"message" : @"MDM policy required"
    };

    NSError *error = nil;
    MSIDOnboardingReason *reason = [[MSIDOnboardingReason alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(reason);
    XCTAssertNil(error);
    XCTAssertEqual(reason.code, MSIDOnboardingReasonCodePolicy);
    XCTAssertEqualObjects(reason.message, @"MDM policy required");
}

- (void)testReasonInitWithJSONDictionary_whenCodeOnlyNoMessage_shouldParse
{
    NSDictionary *json = @{
        @"code" : @"user_cancel"
    };

    NSError *error = nil;
    MSIDOnboardingReason *reason = [[MSIDOnboardingReason alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(reason);
    XCTAssertNil(error);
    XCTAssertEqual(reason.code, MSIDOnboardingReasonCodeUserCancel);
    XCTAssertNil(reason.message);
}

- (void)testReasonInitWithJSONDictionary_whenNonDictionary_shouldFail
{
    NSError *error = nil;
    NSArray *notADict = @[@"not", @"a", @"dict"];
    MSIDOnboardingReason *reason = [[MSIDOnboardingReason alloc] initWithJSONDictionary:(NSDictionary *)notADict error:&error];

    XCTAssertNil(reason);
    XCTAssertNotNil(error);
}

- (void)testReasonJsonDictionary_whenMessagePresent_shouldIncludeMessage
{
    MSIDOnboardingReason *reason = [[MSIDOnboardingReason alloc] initWithCode:MSIDOnboardingReasonCodeNetwork message:@"Timeout"];

    NSDictionary *json = [reason jsonDictionary];

    XCTAssertEqualObjects(json[@"code"], @"network");
    XCTAssertEqualObjects(json[@"message"], @"Timeout");
}

- (void)testReasonJsonDictionary_whenMessageNil_shouldOmitMessage
{
    MSIDOnboardingReason *reason = [[MSIDOnboardingReason alloc] initWithCode:MSIDOnboardingReasonCodePolicy message:nil];

    NSDictionary *json = [reason jsonDictionary];

    XCTAssertEqualObjects(json[@"code"], @"policy");
    XCTAssertNil(json[@"message"]);
}

@end
