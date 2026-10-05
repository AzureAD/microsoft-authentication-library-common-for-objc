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
@property (nonatomic) MSIDWebCPOnboardingReadinessContract *contract;
@end

@implementation MSIDWebCPOnboardingReadinessContractTests

- (void)setUp
{
    [super setUp];
    self.contract = MSIDWebCPOnboardingReadinessContract.sharedInstance;
}

- (void)testSharedInstance_isStable
{
    XCTAssertEqual(self.contract, MSIDWebCPOnboardingReadinessContract.sharedInstance);
}

- (void)testValidateRequest_whenV1EnvelopeIsValid_shouldAccept
{
    NSDictionary *request = @{@"correlationID": @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb",
                              @"action_name": @"get_onboarding_readiness",
                              @"action_component": @"native",
                              @"params": @{@"contractVersion": @1}};
    XCTAssertEqual([self.contract validateRequest:request],
                   MSIDWebCPOnboardingReadinessRequestValidationValid);
}

- (void)testValidateRequest_whenVersionIsUnsupported_shouldReturnNotSupported
{
    NSDictionary *request = @{@"action_name": @"get_onboarding_readiness",
                              @"action_component": @"native",
                              @"params": @{@"contractVersion": @2}};
    XCTAssertEqual([self.contract validateRequest:request],
                   MSIDWebCPOnboardingReadinessRequestValidationNotSupported);
}

- (void)testValidateRequest_whenAdditionalFieldsArePresent_shouldAccept
{
    NSDictionary *request = @{@"action_name": @"get_onboarding_readiness",
                              @"action_component": @"native",
                              @"params": @{@"contractVersion": @1, @"operation": @"open"},
                              @"before_action": @[]};
    XCTAssertEqual([self.contract validateRequest:request],
                   MSIDWebCPOnboardingReadinessRequestValidationValid);
}

- (void)testValidateRequest_whenActionIsUnsupported_shouldReturnNotSupported
{
    NSDictionary *request = @{@"action_name": @"get_tokens",
                              @"action_component": @"native",
                              @"params": @{@"contractVersion": @1}};
    XCTAssertEqual([self.contract validateRequest:request],
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
        @{@"action_name": @1, @"action_component": @"native", @"params": @{@"contractVersion": @1}}
    ];
    for (id request in requests)
    {
        XCTAssertEqual([self.contract validateRequest:request],
                       MSIDWebCPOnboardingReadinessRequestValidationMalformed);
    }
}

- (void)testCorrelationID_whenValid_shouldEchoOriginal
{
    NSString *identifier = @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb";
    BOOL generated = YES;
    NSString *result = [self.contract correlationIDForRequest:@{@"correlationID": identifier}
                                                                           generated:&generated];
    XCTAssertEqualObjects(result, identifier);
    XCTAssertFalse(generated);
}

- (void)testCorrelationID_whenMissingOrMalformed_shouldGenerateUUID
{
    for (id request in @[@{}, @{@"correlationID": @"not-a-uuid"}, @{@"correlationID": @42}])
    {
        BOOL generated = NO;
        NSString *result = [self.contract correlationIDForRequest:request generated:&generated];
        XCTAssertTrue(generated);
        XCTAssertEqualObjects([[NSUUID alloc] initWithUUIDString:result].UUIDString, result);
    }
}

- (void)testResponse_whenBothAvailable_shouldMatchVersionOneEnvelope
{
    MSIDOnboardingReadiness *readiness = [[MSIDOnboardingReadiness alloc]
        initWithBrokerAvailability:YES ssoExtensionAvailability:YES];
    NSString *identifier = @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb";
    NSDictionary *response = [self.contract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:identifier
                readiness:readiness];
    XCTAssertEqualObjects(response, (@{@"correlationID": identifier, @"status": @"Success",
        @"result": @{@"contractVersion": @1,
                    @"capabilities": @[@"brokerAvailability", @"ssoExtensionAvailability"],
                    @"brokerAvailability": @YES, @"ssoExtensionAvailability": @YES}}));
    XCTAssertNil(response[@"result"][@"ready"]);
    XCTAssertNil(response[@"result"][@"isBrokerFlow"]);
}

- (void)testResponse_whenOnlySSOCanPerformRequest_shouldKeepBooleansIndependent
{
    MSIDOnboardingReadiness *readiness = [[MSIDOnboardingReadiness alloc]
        initWithBrokerAvailability:NO ssoExtensionAvailability:YES];
    NSDictionary *response = [self.contract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:@"a7c08f6d-b239-49fb-a494-85f70f1a2fcb"
                readiness:readiness];
    XCTAssertEqualObjects(response[@"result"][@"brokerAvailability"], @NO);
    XCTAssertEqualObjects(response[@"result"][@"ssoExtensionAvailability"], @YES);
    XCTAssertNil(response[@"result"][@"unknownReasons"]);
}

- (void)testResponse_whenNeitherControllerCanPerformRequest_shouldReturnFalseForBoth
{
    MSIDOnboardingReadiness *readiness = [[MSIDOnboardingReadiness alloc]
        initWithBrokerAvailability:NO ssoExtensionAvailability:NO];
    NSDictionary *response = [self.contract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:@"a7c08f6d-b239-49fb-a494-85f70f1a2fcb"
                readiness:readiness];
    XCTAssertEqualObjects(response[@"result"][@"brokerAvailability"], @NO);
    XCTAssertEqualObjects(response[@"result"][@"ssoExtensionAvailability"], @NO);
    XCTAssertNil(response[@"result"][@"unknownReasons"]);
}

- (void)testResponse_whenUnsupportedOrFailed_shouldNotReturnReadiness
{
    NSString *identifier = @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb";
    NSDictionary *unsupported = [self.contract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusNotSupported
            correlationID:identifier readiness:nil];
    XCTAssertEqualObjects(unsupported, (@{@"correlationID": identifier, @"status": @"NotSupported",
        @"result": @{@"contractVersion": @1, @"supportedContractVersions": @[@1]}}));
    NSDictionary *failed = [self.contract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusFailed
            correlationID:identifier readiness:nil];
    XCTAssertEqualObjects(failed, (@{@"correlationID": identifier, @"status": @"Failed", @"result": @{}}));
    NSDictionary *missingReadiness = [self.contract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:identifier readiness:nil];
    XCTAssertEqualObjects(missingReadiness, failed);
}

@end
