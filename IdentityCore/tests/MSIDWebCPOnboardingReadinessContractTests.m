//------------------------------------------------------------------------------
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
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDOnboardingReadiness.h"
#import "MSIDWebCPOnboardingReadinessContract.h"

@interface MSIDWebCPOnboardingReadinessContractTests : XCTestCase
@end

@implementation MSIDWebCPOnboardingReadinessContractTests

- (void)testValidateRequest_whenV1EnvelopeIsValid_shouldAccept
{
    NSDictionary *request = @{@"correlationID": @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb",
                              @"action_name": @"get_onboarding_readiness",
                              @"action_component": @"native",
                              @"params": @{@"contractVersion": @1}};
    XCTAssertEqual([MSIDWebCPOnboardingReadinessContract validateRequest:request],
                   MSIDWebCPOnboardingReadinessRequestValidationValid);
}

- (void)testValidateRequest_whenVersionIsUnsupported_shouldReturnNotSupported
{
    NSDictionary *request = @{@"action_name": @"get_onboarding_readiness",
                              @"action_component": @"native",
                              @"params": @{@"contractVersion": @2}};
    XCTAssertEqual([MSIDWebCPOnboardingReadinessContract validateRequest:request],
                   MSIDWebCPOnboardingReadinessRequestValidationNotSupported);
}

- (void)testValidateRequest_whenActionIsUnsupported_shouldReturnNotSupported
{
    NSDictionary *request = @{@"action_name": @"get_tokens",
                              @"action_component": @"native",
                              @"params": @{@"contractVersion": @1}};
    XCTAssertEqual([MSIDWebCPOnboardingReadinessContract validateRequest:request],
                   MSIDWebCPOnboardingReadinessRequestValidationNotSupported);
}

- (void)testValidateRequest_whenParamsOrEnvelopeAreMalformed_shouldReturnMalformed
{
    NSArray *requests = @[
        @[],
        @{@"action_name": @"get_onboarding_readiness", @"action_component": @"native"},
        @{@"action_name": @"get_onboarding_readiness", @"action_component": @"native",
          @"params": @{@"contractVersion": @YES}},
        @{@"action_name": @"get_onboarding_readiness", @"action_component": @"native",
          @"params": @{@"contractVersion": @1.5}},
        @{@"action_name": @"get_onboarding_readiness", @"action_component": @"native",
          @"params": @{@"contractVersion": @1, @"operation": @"open"}},
        @{@"action_name": @"get_onboarding_readiness", @"action_component": @"native",
          @"params": @{@"contractVersion": @1}, @"before_action": @[]},
        @{@"action_name": @1, @"action_component": @"native", @"params": @{@"contractVersion": @1}}
    ];
    for (id request in requests)
    {
        XCTAssertEqual([MSIDWebCPOnboardingReadinessContract validateRequest:request],
                       MSIDWebCPOnboardingReadinessRequestValidationMalformed);
    }
}

- (void)testCorrelationID_whenValid_shouldEchoOriginal
{
    NSString *identifier = @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb";
    BOOL generated = YES;
    NSString *result = [MSIDWebCPOnboardingReadinessContract correlationIDForRequest:@{@"correlationID": identifier}
                                                                           generated:&generated];
    XCTAssertEqualObjects(result, identifier);
    XCTAssertFalse(generated);
}

- (void)testCorrelationID_whenMissingOrMalformed_shouldGenerateUUID
{
    for (id request in @[@{}, @{@"correlationID": @"not-a-uuid"}, @{@"correlationID": @42}])
    {
        BOOL generated = NO;
        NSString *result = [MSIDWebCPOnboardingReadinessContract correlationIDForRequest:request generated:&generated];
        XCTAssertTrue(generated);
        XCTAssertEqualObjects([[NSUUID alloc] initWithUUIDString:result].UUIDString, result);
    }
}

- (void)testResponse_whenBothAvailable_shouldMatchVersionOneEnvelope
{
    MSIDOnboardingReadiness *readiness = [[MSIDOnboardingReadiness alloc]
        initWithBrokerAvailability:MSIDOnboardingReadinessStateAvailable
              brokerUnknownReason:MSIDOnboardingReadinessUnknownReasonNone
         ssoExtensionAvailability:MSIDOnboardingReadinessStateAvailable
        ssoExtensionUnknownReason:MSIDOnboardingReadinessUnknownReasonNone];
    NSString *identifier = @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb";
    NSDictionary *response = [MSIDWebCPOnboardingReadinessContract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:identifier
                readiness:readiness];
    XCTAssertEqualObjects(response, (@{@"correlationID": identifier, @"status": @"Success",
        @"result": @{@"contractVersion": @1,
                    @"capabilities": @[@"brokerAvailability", @"ssoExtensionAvailability"],
                    @"brokerAvailability": @"available", @"ssoExtensionAvailability": @"available"}}));
    XCTAssertNil(response[@"result"][@"ready"]);
    XCTAssertNil(response[@"result"][@"isBrokerFlow"]);
}

- (void)testResponse_whenBrokerUnknown_shouldIncludeOnlyBrokerReason
{
    MSIDOnboardingReadiness *readiness = [[MSIDOnboardingReadiness alloc]
        initWithBrokerAvailability:MSIDOnboardingReadinessStateUnknown
              brokerUnknownReason:MSIDOnboardingReadinessUnknownReasonNotProbeableInCurrentHost
         ssoExtensionAvailability:MSIDOnboardingReadinessStateUnavailable
        ssoExtensionUnknownReason:MSIDOnboardingReadinessUnknownReasonPlatformCapabilityUnavailable];
    NSDictionary *response = [MSIDWebCPOnboardingReadinessContract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:@"a7c08f6d-b239-49fb-a494-85f70f1a2fcb"
                readiness:readiness];
    XCTAssertEqualObjects(response[@"result"][@"brokerAvailability"], @"unknown");
    XCTAssertEqualObjects(response[@"result"][@"ssoExtensionAvailability"], @"unavailable");
    XCTAssertEqualObjects(response[@"result"][@"unknownReasons"],
                          @{@"brokerAvailability": @"notProbeableInCurrentHost"});
}

- (void)testResponse_whenBothUnknown_shouldIncludeIndependentReasons
{
    MSIDOnboardingReadiness *readiness = [[MSIDOnboardingReadiness alloc]
        initWithBrokerAvailability:MSIDOnboardingReadinessStateUnknown
              brokerUnknownReason:MSIDOnboardingReadinessUnknownReasonMissingQuerySchemeConfiguration
         ssoExtensionAvailability:MSIDOnboardingReadinessStateUnknown
        ssoExtensionUnknownReason:MSIDOnboardingReadinessUnknownReasonPlatformCapabilityUnavailable];
    NSDictionary *response = [MSIDWebCPOnboardingReadinessContract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:@"a7c08f6d-b239-49fb-a494-85f70f1a2fcb"
                readiness:readiness];
    XCTAssertEqualObjects(response[@"result"][@"unknownReasons"],
                          (@{@"brokerAvailability": @"missingQuerySchemeConfiguration",
                             @"ssoExtensionAvailability": @"platformCapabilityUnavailable"}));
    XCTAssertEqualObjects(response[@"result"][@"brokerAvailability"], @"unknown");
    XCTAssertEqualObjects(response[@"result"][@"ssoExtensionAvailability"], @"unknown");
}

- (void)testResponse_whenUnsupportedOrFailed_shouldNotReturnReadiness
{
    NSString *identifier = @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb";
    NSDictionary *unsupported = [MSIDWebCPOnboardingReadinessContract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusNotSupported
            correlationID:identifier readiness:nil];
    XCTAssertEqualObjects(unsupported, (@{@"correlationID": identifier, @"status": @"NotSupported",
        @"result": @{@"contractVersion": @1, @"supportedContractVersions": @[@1]}}));
    NSDictionary *failed = [MSIDWebCPOnboardingReadinessContract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusFailed
            correlationID:identifier readiness:nil];
    XCTAssertEqualObjects(failed, (@{@"correlationID": identifier, @"status": @"Failed", @"result": @{}}));
    NSDictionary *missingReadiness = [MSIDWebCPOnboardingReadinessContract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:identifier readiness:nil];
    XCTAssertEqualObjects(missingReadiness, failed);
}

- (void)testResponse_whenReadinessStateIsInvalid_shouldFailRatherThanSerializeUnknown
{
    MSIDOnboardingReadiness *readiness = [[MSIDOnboardingReadiness alloc]
        initWithBrokerAvailability:(MSIDOnboardingReadinessState)NSIntegerMax
              brokerUnknownReason:MSIDOnboardingReadinessUnknownReasonNone
         ssoExtensionAvailability:MSIDOnboardingReadinessStateAvailable
        ssoExtensionUnknownReason:MSIDOnboardingReadinessUnknownReasonNone];
    NSDictionary *response = [MSIDWebCPOnboardingReadinessContract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:@"a7c08f6d-b239-49fb-a494-85f70f1a2fcb"
                readiness:readiness];
    XCTAssertEqualObjects(response[@"status"], @"Failed");
    XCTAssertEqualObjects(response[@"result"], @{});
}

@end
