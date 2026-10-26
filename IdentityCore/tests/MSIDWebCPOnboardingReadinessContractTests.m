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
#import "MSIDAuthenticationAvailabilityStatus.h"
#import "MSIDWebCPOnboardingReadinessContract.h"

@interface MSIDWebCPOnboardingReadinessContractTests : XCTestCase
@property (nonatomic) MSIDWebCPOnboardingReadinessContract *contract;
@end

@implementation MSIDWebCPOnboardingReadinessContractTests

- (void)setUp
{
    [super setUp];
    self.contract = [MSIDWebCPOnboardingReadinessContract new];
}

- (void)testValidateRequest_whenEnvelopeIsValid_shouldAccept
{
    NSDictionary *request = @{@"correlationID": @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb",
                              @"action_name": @"get_broker_status",
                              @"action_component": @"native",
                              @"params": @{}};
    XCTAssertEqual([self.contract validateRequest:request],
                   MSIDWebCPOnboardingReadinessRequestValidationValid);
}

- (void)testValidateRequest_whenAdditionalFieldsArePresent_shouldAccept
{
    NSDictionary *request = @{@"action_name": @"get_broker_status",
                              @"action_component": @"native",
                              @"params": @{@"contractVersion": @2, @"operation": @"open"},
                              @"before_action": @[]};
    XCTAssertEqual([self.contract validateRequest:request],
                   MSIDWebCPOnboardingReadinessRequestValidationValid);
}

- (void)testValidateRequest_whenActionIsUnsupported_shouldReturnNotSupported
{
    NSDictionary *request = @{@"action_name": @"get_tokens",
                              @"action_component": @"native",
                              @"params": @{}};
    XCTAssertEqual([self.contract validateRequest:request],
                   MSIDWebCPOnboardingReadinessRequestValidationNotSupported);
}

- (void)testValidateRequest_whenParamsOrEnvelopeAreMalformed_shouldReturnMalformed
{
    NSArray *requests = @[
        @[],
        @{@"action_name": @"get_broker_status", @"action_component": @"native"},
        @{@"action_name": @"get_broker_status", @"action_component": @"native",
          @"params": @YES},
        @{@"action_name": @"get_broker_status", @"action_component": @"native",
          @"params": @[]},
        @{@"action_name": @1, @"action_component": @"native", @"params": @{}}
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

- (void)testResponse_whenBothAvailable_shouldContainOnlyIndependentBooleans
{
    MSIDAuthenticationAvailabilityStatus *readiness = [[MSIDAuthenticationAvailabilityStatus alloc]
        initWithBrokerAppAvailable:YES ssoExtensionAvailable:YES];
    NSString *identifier = @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb";
    NSDictionary *response = [self.contract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:identifier
             availability:readiness];
    XCTAssertEqualObjects(response, (@{@"correlationID": identifier, @"status": @"Success",
        @"result": @{@"brokerAppAvailable": @YES, @"ssoExtensionAvailable": @YES}}));
    XCTAssertNil(response[@"result"][@"ready"]);
    XCTAssertNil(response[@"result"][@"isBrokerFlow"]);
}

- (void)testResponse_whenOnlySSOCanPerformRequest_shouldKeepBooleansIndependent
{
    MSIDAuthenticationAvailabilityStatus *readiness = [[MSIDAuthenticationAvailabilityStatus alloc]
        initWithBrokerAppAvailable:NO ssoExtensionAvailable:YES];
    NSDictionary *response = [self.contract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:@"a7c08f6d-b239-49fb-a494-85f70f1a2fcb"
             availability:readiness];
    XCTAssertEqualObjects(response[@"result"][@"brokerAppAvailable"], @NO);
    XCTAssertEqualObjects(response[@"result"][@"ssoExtensionAvailable"], @YES);
}

- (void)testResponse_whenNeitherControllerCanPerformRequest_shouldReturnFalseForBoth
{
    MSIDAuthenticationAvailabilityStatus *readiness = [[MSIDAuthenticationAvailabilityStatus alloc]
        initWithBrokerAppAvailable:NO ssoExtensionAvailable:NO];
    NSDictionary *response = [self.contract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:@"a7c08f6d-b239-49fb-a494-85f70f1a2fcb"
             availability:readiness];
    XCTAssertEqualObjects(response[@"result"][@"brokerAppAvailable"], @NO);
    XCTAssertEqualObjects(response[@"result"][@"ssoExtensionAvailable"], @NO);
}

- (void)testResponse_whenUnsupportedOrFailed_shouldNotReturnReadiness
{
    NSString *identifier = @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb";
    NSDictionary *unsupported = [self.contract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusNotSupported
            correlationID:identifier availability:nil];
    XCTAssertEqualObjects(unsupported, (@{@"correlationID": identifier, @"status": @"NotSupported",
        @"result": @{}}));
    NSDictionary *failed = [self.contract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusFailed
            correlationID:identifier availability:nil];
    XCTAssertEqualObjects(failed, (@{@"correlationID": identifier, @"status": @"Failed", @"result": @{}}));
    NSDictionary *missingReadiness = [self.contract
        responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusSuccess
            correlationID:identifier availability:nil];
    XCTAssertEqualObjects(missingReadiness, failed);
}

@end
