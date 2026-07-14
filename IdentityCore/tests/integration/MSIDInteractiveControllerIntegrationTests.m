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
#import "MSIDTestTokenRequestProvider.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDRequestParameters.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDTokenResult.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponse.h"
#import "MSIDAccessToken.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDLocalInteractiveController+Internal.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDOnboardingBlobBuilder.h"
#import "MSIDOnboardingBlobFieldKeys.h"
#import "MSIDTelemetryTestDispatcher.h"
#import "MSIDTelemetry.h"
#import "MSIDRefreshToken.h"
#import "MSIDTestIdentifiers.h"
#if TARGET_OS_IPHONE
#import "MSIDApplicationTestUtil.h"
#import "MSIDWebWPJResponse.h"
#import "MSIDWebUpgradeRegResponse.h"
#import "MSIDBrokerInteractiveController.h"
#import "MSIDTestBrokerResponseHandler.h"
#endif
#import "MSIDTestURLSession.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDWebMDMEnrollmentCompletionResponse.h"
#import "MSIDRequestControllerFactory.h"
#import "MSIDTestSwizzle.h"
#import "MSIDTestLocalInteractiveController.h"

@interface MSIDInteractiveControllerIntegrationTests : XCTestCase

@end

@implementation MSIDInteractiveControllerIntegrationTests

- (void)setUp
{
    [super setUp];

    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:@"v2.0" forKey:@"aadApiVersion"];
}

- (void)tearDown
{
    [super tearDown];
    [[MSIDAuthority openIdConfigurationCache] removeAllObjects];
    [[MSIDAadAuthorityCache sharedInstance] removeAllObjects];
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:nil forKey:@"aadApiVersion"];

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
#if TARGET_OS_IPHONE
    [MSIDApplicationTestUtil reset];
#endif

    [MSIDTestSwizzle reset];
}


#pragma mark - Helpers

- (MSIDInteractiveTokenRequestParameters *)requestParameters
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    parameters.authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    parameters.clientId = @"my_client_id";
    parameters.target = @"user.read tasks.read";
    parameters.oidcScope = @"openid profile offline_access";
    parameters.redirectUri = @"my_redirect_uri";
    parameters.correlationId = [NSUUID new];
    parameters.extendedLifetimeEnabled = YES;
    parameters.telemetryRequestId = [[NSUUID new] UUIDString];
    parameters.loginHint = @"user@contoso.com";
    return parameters;

}

- (MSIDOnboardingBlobBuilder *)onboardingBuilder
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"retry-corr",
        @"onboarding_mode" : @"non-brokered"
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"my_client_id" target:@"user.read"];
}

- (NSArray<NSString *> *)stepIdsFromOnboardingBuilder:(MSIDOnboardingBlobBuilder *)builder
{
    NSData *data = [[builder finalizeBlob] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSMutableArray<NSString *> *stepIds = [NSMutableArray new];
    for (NSDictionary *step in parsed[@"steps_list"])
    {
        [stepIds addObject:step[@"step_id"]];
    }
    return stepIds;
}

- (MSIDTokenResult *)resultWithParameters:(MSIDRequestParameters *)parameters
{
    NSDictionary *testResponse = [MSIDTestURLResponse tokenResponseWithAT:@"access-token"
                                                               responseRT:@"refresh-token"
                                                               responseID:nil
                                                            responseScope:nil
                                                       responseClientInfo:nil
                                                                expiresIn:nil
                                                                     foci:nil
                                                             extExpiresIn:nil
                                                                refreshIn:nil];

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:testResponse context:nil error:nil];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:parameters.msidConfiguration];
    MSIDRefreshToken *refreshToken = [factory refreshTokenFromResponse:response configuration:parameters.msidConfiguration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:parameters.msidConfiguration];

    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:refreshToken
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:parameters.authority
                                                             correlationId:parameters.correlationId
                                                             tokenResponse:response];

    return result;
}

#pragma mark - tests

- (void)testAcquireToken_whenSuccessfulInteractiveRequest_shouldReturnSuccess
{
    // setup telemetry callback
    MSIDTelemetryTestDispatcher *dispatcher = [MSIDTelemetryTestDispatcher new];

    NSMutableArray *receivedEvents = [NSMutableArray array];

    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(id<MSIDTelemetryEventInterface> event)
     {
         [receivedEvents addObject:event];
     }];

    // register the dispatcher
    [[MSIDTelemetry sharedInstance] addDispatcher:dispatcher];
    [MSIDTelemetry sharedInstance].piiEnabled = YES;

    // Setup test request providers
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_id1111";

    MSIDTokenResult *testResult = [self resultWithParameters:parameters];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:testResult testError:nil testWebMSAuthResponse:nil];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider error:&error];

    XCTAssertNotNil(interactiveController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNotNil(result);
        // Check result
        XCTAssertEqualObjects(result.accessToken, testResult.accessToken);
        XCTAssertEqualObjects(result.rawIdToken, testResult.rawIdToken);
        XCTAssertEqualObjects(result.account, testResult.account);
        XCTAssertEqualObjects(result.authority, testResult.authority);
        XCTAssertNil(acquireTokenError);

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 1);
        NSDictionary *telemetryEvent = [receivedEvents[0] propertyMap];
        XCTAssertNotNil(telemetryEvent[@"start_time"]);
        XCTAssertNotNil(telemetryEvent[@"stop_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"api_id1111");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"succeeded");
        XCTAssertEqualObjects(telemetryEvent[@"login_hint"], @"d24dfead25359b0c562c8a02a6a0e6db8de4a8b235d56e122a75a8e1f2e473ee");
        XCTAssertEqualObjects(telemetryEvent[@"user_id"], @"d24dfead25359b0c562c8a02a6a0e6db8de4a8b235d56e122a75a8e1f2e473ee");
        XCTAssertEqualObjects(telemetryEvent[@"tenant_id"], DEFAULT_TEST_UTID);
        XCTAssertEqualObjects(telemetryEvent[@"client_id"], @"my_client_id");
        XCTAssertNotNil(telemetryEvent[@"response_time"]);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenFailingInteractiveRequest_shouldReturnFailure
{
    // setup telemetry callback
    MSIDTelemetryTestDispatcher *dispatcher = [MSIDTelemetryTestDispatcher new];

    NSMutableArray *receivedEvents = [NSMutableArray array];

    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(id<MSIDTelemetryEventInterface> event)
     {
         [receivedEvents addObject:event];
     }];

    // register the dispatcher
    [[MSIDTelemetry sharedInstance] addDispatcher:dispatcher];
    [MSIDTelemetry sharedInstance].piiEnabled = YES;

    // Setup test request providers
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_prompt_fail";

    NSError *testError = MSIDCreateError(MSIDErrorDomain, -51433, @"Invalid grant", @"invalid_grant", @"consent_required", nil, parameters.correlationId, nil, YES);

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:testError testWebMSAuthResponse:nil];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider error:&error];

    XCTAssertNotNil(interactiveController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqualObjects(acquireTokenError, testError);

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 1);
        NSDictionary *telemetryEvent = [receivedEvents[0] propertyMap];
        XCTAssertNotNil(telemetryEvent[@"start_time"]);
        XCTAssertNotNil(telemetryEvent[@"stop_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"api_prompt_fail");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"failed");
        XCTAssertNotNil(telemetryEvent[@"response_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_error_code"], @"-51433");
        XCTAssertEqualObjects(telemetryEvent[@"error_domain"], MSIDErrorDomain);
        XCTAssertEqualObjects(telemetryEvent[@"error_protocol_code"], @"invalid_grant");
        XCTAssertEqualObjects(telemetryEvent[@"login_hint"], @"d24dfead25359b0c562c8a02a6a0e6db8de4a8b235d56e122a75a8e1f2e473ee");
        XCTAssertEqualObjects(telemetryEvent[@"client_id"], @"my_client_id");

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#if TARGET_OS_IPHONE && !AD_BROKER
- (void)testAcquireToken_whenBrokerInstallPrompt_andSuccessfulResponse_shouldReturnResult
{
    // setup telemetry callback
    MSIDTelemetryTestDispatcher *dispatcher = [MSIDTelemetryTestDispatcher new];

    NSMutableArray *receivedEvents = [NSMutableArray array];

    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(id<MSIDTelemetryEventInterface> event)
     {
         [receivedEvents addObject:event];
     }];

    // register the dispatcher
    [[MSIDTelemetry sharedInstance] addDispatcher:dispatcher];
    [MSIDTelemetry sharedInstance].piiEnabled = YES;

    // Setup test request providers
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_broker_success";

    NSString *brokerURL = [NSString stringWithFormat:@"msauth://wpj?app_link=https%%3A%%2F%%2Ftest.url.broker%%3Ftest1%%3Dtest2&username=my@test.com"];
    MSIDWebWPJResponse *msAuthResponse = [[MSIDWebWPJResponse alloc] initWithURL:[NSURL URLWithString:brokerURL] context:nil error:nil];

    NSDictionary *testResumeDictionary = @{@"test-resume-key1": @"test-resume-value2",
                                           @"test-resume-key2": @"test-resume-value2"};

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:msAuthResponse brokerRequestURL:[NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey"] resumeDictionary:testResumeDictionary];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider error:&error];

    XCTAssertNotNil(interactiveController);
    XCTAssertNil(error);

    MSIDTokenResult *testResult = [self resultWithParameters:parameters];

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, __unused NSDictionary<NSString *,id> *options) {

        XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://test.url.broker?test1=test2"]);

        UIPasteboard *appPasteBoard = [UIPasteboard pasteboardWithName:@"WPJ" create:NO];
        XCTAssertEqualObjects(appPasteBoard.URL, [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey&sourceApplication=com.microsoft.MSIDTestsHostApp"]);

        NSDictionary *resumeDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
        XCTAssertEqualObjects(resumeDictionary, testResumeDictionary);

        MSIDTestBrokerResponseHandler *brokerResponseHandler = [[MSIDTestBrokerResponseHandler alloc] initWithTestResponse:testResult testError:nil];

        [MSIDBrokerInteractiveController completeAcquireToken:[NSURL URLWithString:@"https://contoso.com"]
                                            sourceApplication:@"com.microsoft.azureauthenticator"
                                        brokerResponseHandler:brokerResponseHandler];
        return YES;
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNotNil(result);
        // Check result
        XCTAssertEqualObjects(result.accessToken, testResult.accessToken);
        XCTAssertEqualObjects(result.rawIdToken, testResult.rawIdToken);
        XCTAssertEqualObjects(result.account, testResult.account);
        XCTAssertEqualObjects(result.authority, testResult.authority);
        XCTAssertNil(acquireTokenError);
        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 4);
        NSDictionary *telemetryEvent = [receivedEvents[2] propertyMap];
        XCTAssertNotNil(telemetryEvent[@"start_time"]);
        XCTAssertNotNil(telemetryEvent[@"stop_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"api_broker_success");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"succeeded");
        XCTAssertEqualObjects(telemetryEvent[@"login_hint"], @"d24dfead25359b0c562c8a02a6a0e6db8de4a8b235d56e122a75a8e1f2e473ee");
        XCTAssertEqualObjects(telemetryEvent[@"user_id"], @"d24dfead25359b0c562c8a02a6a0e6db8de4a8b235d56e122a75a8e1f2e473ee");
        XCTAssertEqualObjects(telemetryEvent[@"tenant_id"], DEFAULT_TEST_UTID);
        XCTAssertEqualObjects(telemetryEvent[@"client_id"], @"my_client_id");
        XCTAssertEqualObjects(telemetryEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertNotNil(telemetryEvent[@"response_time"]);

        NSDictionary *brokerEvent = [receivedEvents[3] propertyMap];
        XCTAssertEqualObjects(brokerEvent[@"broker_app"], @"Microsoft Authenticator");
        XCTAssertEqualObjects(brokerEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertEqualObjects(brokerEvent[@"event_name"], @"broker_event");
        XCTAssertEqualObjects(brokerEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(brokerEvent[@"status"], @"succeeded");
        XCTAssertNotNil(brokerEvent[@"start_time"]);
        XCTAssertNotNil(brokerEvent[@"stop_time"]);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:7.0 handler:nil];
}

- (void)testAcquireToken_whenWPJRequest_shouldReturnWorkplaceJoinRequiredError
{
    // setup telemetry callback
    MSIDTelemetryTestDispatcher *dispatcher = [MSIDTelemetryTestDispatcher new];

    NSMutableArray *receivedEvents = [NSMutableArray array];

    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(id<MSIDTelemetryEventInterface> event)
     {
         [receivedEvents addObject:event];
     }];

    // register the dispatcher
    [[MSIDTelemetry sharedInstance] addDispatcher:dispatcher];
    [MSIDTelemetry sharedInstance].piiEnabled = YES;

    // Setup test request providers
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_broker_wpj";

    NSString *brokerURL = [NSString stringWithFormat:@"msauth://wpj?username=my@test.com&client_info=eyJ1aWQiOiIwZWE5OWM1OC02NGIzLTRhZmEtYmU1MC00NGU2NDA4ZWRjZDUiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
    MSIDWebWPJResponse *msAuthResponse = [[MSIDWebWPJResponse alloc] initWithURL:[NSURL URLWithString:brokerURL] context:nil error:nil];
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:msAuthResponse brokerRequestURL:nil resumeDictionary:nil];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider error:&error];

    XCTAssertNotNil(interactiveController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqual(acquireTokenError.code, MSIDErrorWorkplaceJoinRequired);
        XCTAssertEqualObjects(acquireTokenError.userInfo[MSIDUserDisplayableIdkey], @"my@test.com");
        XCTAssertEqualObjects(acquireTokenError.userInfo[MSIDHomeAccountIdkey], @"0ea99c58-64b3-4afa-be50-44e6408edcd5.f645ad92-e38d-4d1a-b510-d1b09a74a8ca");

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 1);
        NSDictionary *telemetryEvent = [receivedEvents[0] propertyMap];
        XCTAssertNotNil(telemetryEvent[@"start_time"]);
        XCTAssertNotNil(telemetryEvent[@"stop_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"api_broker_wpj");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"failed");
        XCTAssertEqualObjects(telemetryEvent[@"login_hint"], @"b3bf42e34c6997b665e8693acf69075072641a1bd44ffe0d2aae21296e32ba02");
        XCTAssertEqualObjects(telemetryEvent[@"client_id"], @"my_client_id");
        XCTAssertEqualObjects(telemetryEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertNotNil(telemetryEvent[@"response_time"]);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenUpgradeRegRequest_shouldReturnUpgradeRegistrationRequiredError
{
    // setup telemetry callback
    MSIDTelemetryTestDispatcher *dispatcher = [MSIDTelemetryTestDispatcher new];

    NSMutableArray *receivedEvents = [NSMutableArray array];

    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(id<MSIDTelemetryEventInterface> event)
     {
         [receivedEvents addObject:event];
     }];

    // register the dispatcher
    [[MSIDTelemetry sharedInstance] addDispatcher:dispatcher];
    [MSIDTelemetry sharedInstance].piiEnabled = YES;

    // Setup test request providers
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_broker_upgradeReg";

    NSString *brokerURL = [NSString stringWithFormat:@"msauth://upgradeReg?username=my@test.com&client_info=eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
    MSIDWebUpgradeRegResponse *msAuthResponse = [[MSIDWebUpgradeRegResponse alloc] initWithURL:[NSURL URLWithString:brokerURL]
                                                                                       context:nil
                                                                                         error:nil];
    
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:msAuthResponse
                                                                                       brokerRequestURL:nil
                                                                                       resumeDictionary:nil];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                                                                    tokenRequestProvider:provider
                                                                                                                                   error:&error];

    XCTAssertNotNil(interactiveController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqual(acquireTokenError.code, MSIDErrorInsufficientDeviceStrength);
        XCTAssertEqualObjects(acquireTokenError.userInfo[MSIDUserDisplayableIdkey], @"my@test.com");
        XCTAssertEqualObjects(acquireTokenError.userInfo[MSIDHomeAccountIdkey], @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca");

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 1);
        NSDictionary *telemetryEvent = [receivedEvents[0] propertyMap];
        XCTAssertNotNil(telemetryEvent[@"start_time"]);
        XCTAssertNotNil(telemetryEvent[@"stop_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"api_broker_upgradeReg");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"failed");
        XCTAssertEqualObjects(telemetryEvent[@"login_hint"], @"b3bf42e34c6997b665e8693acf69075072641a1bd44ffe0d2aae21296e32ba02");
        XCTAssertEqualObjects(telemetryEvent[@"client_id"], @"my_client_id");
        XCTAssertEqualObjects(telemetryEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertNotNil(telemetryEvent[@"response_time"]);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenInvalidBrokerInstallRequest_shouldReturnError
{
    // setup telemetry callback
    MSIDTelemetryTestDispatcher *dispatcher = [MSIDTelemetryTestDispatcher new];

    NSMutableArray *receivedEvents = [NSMutableArray array];

    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(id<MSIDTelemetryEventInterface> event)
     {
         [receivedEvents addObject:event];
     }];

    // register the dispatcher
    [[MSIDTelemetry sharedInstance] addDispatcher:dispatcher];
    [MSIDTelemetry sharedInstance].piiEnabled = YES;

    // Setup test request providers
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_broker_link_failure";

    NSString *brokerURL = [NSString stringWithFormat:@"msauth://wpj?app_link_wrong=https%%3A%%2F%%2Ftest.url.broker%%3Ftest1%%3Dtest2"];
    MSIDWebWPJResponse *msAuthResponse = [[MSIDWebWPJResponse alloc] initWithURL:[NSURL URLWithString:brokerURL] context:nil error:nil];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:msAuthResponse brokerRequestURL:[NSURL URLWithString:@"https://contoso.com"] resumeDictionary:@{}];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider error:&error];

    XCTAssertNotNil(interactiveController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqual(acquireTokenError.code, MSIDErrorInternal);

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 1);
        NSDictionary *telemetryEvent = [receivedEvents[0] propertyMap];
        XCTAssertNotNil(telemetryEvent[@"start_time"]);
        XCTAssertNotNil(telemetryEvent[@"stop_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"api_broker_link_failure");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"failed");
        XCTAssertNotNil(telemetryEvent[@"response_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_error_code"], @"-51100");
        XCTAssertEqualObjects(telemetryEvent[@"error_domain"], MSIDErrorDomain);
        XCTAssertEqualObjects(telemetryEvent[@"login_hint"], @"d24dfead25359b0c562c8a02a6a0e6db8de4a8b235d56e122a75a8e1f2e473ee");
        XCTAssertEqualObjects(telemetryEvent[@"client_id"], @"my_client_id");

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
#endif

#pragma mark - MDM Enrollment Completion Tests

// Verifies that when the webview returns an MSIDWebMDMEnrollmentCompletionResponse with a
// successful status, the local controller asks the factory for a (potentially broker-backed)
// controller and forwards the result of its acquireToken: call to the original completion block.
- (void)testAcquireToken_whenMDMEnrollmentCompletionResponse_andSuccessStatus_shouldRetryViaFactoryAndReturnSuccess
{
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_mdm_success_retry";
    parameters.onboardingBlobBuilder = [self onboardingBuilder];

    NSURL *mdmURL = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=success"];
    MSIDWebMDMEnrollmentCompletionResponse *mdmResponse = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:mdmURL
                                                                                                              context:nil
                                                                                                                error:nil];
    XCTAssertNotNil(mdmResponse);
    XCTAssertTrue(mdmResponse.isSuccess);

    // The initial interactive request returns the MDM completion response (no result, no error).
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:mdmResponse];

    MSIDTokenResult *retryResult = [self resultWithParameters:parameters];

    // Stub the factory: after MDM enrollment completion the controller asks the factory for a
    // controller and calls -acquireToken: on it. We return a stub controller that completes with
    // a successful token result.
    __block NSUInteger retryAcquireTokenCalled = 0;
    MSIDTestLocalInteractiveController *retryController =
        [[MSIDTestLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                    tokenRequestProvider:provider
                                                                                   error:nil];
    retryController.acquireTokenResult = retryResult;
    // Leave acquireTokenError unset (defaults to nil); the property is nonnull-annotated.

    [MSIDTestSwizzle classMethod:@selector(interactiveControllerForParameters:tokenRequestProvider:error:)
                           class:[MSIDRequestControllerFactory class]
                           block:(id)^(__unused id obj,
                                       __unused MSIDInteractiveTokenRequestParameters *p,
                                       __unused id<MSIDTokenRequestProviding> tp,
                                       __unused NSError **err)
    {
        retryAcquireTokenCalled++;
        return retryController;
    }];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController =
        [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                tokenRequestProvider:provider
                                                                               error:&error];
    XCTAssertNotNil(interactiveController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token (MDM retry success)"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(acquireTokenError);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken, retryResult.accessToken);
        XCTAssertEqualObjects(result.rawIdToken, retryResult.rawIdToken);

        // The factory must have been consulted exactly once, and acquireToken: must have run
        // exactly once on the returned controller.
        XCTAssertEqual(retryAcquireTokenCalled, 1u);
        XCTAssertEqual(retryController.acquireTokenCalledCount, 1u);

        // Retry telemetry: Started stamped before the retry, Succeeded stamped on the success result.
        NSArray<NSString *> *stepIds = [self stepIdsFromOnboardingBuilder:parameters.onboardingBlobBuilder];
        XCTAssertTrue([stepIds containsObject:MSIDOnboardingBlobStepMdmEnrollmentFinished]);
        XCTAssertTrue([stepIds containsObject:MSIDOnboardingBlobStepTokenRequestRetryStarted]);
        XCTAssertTrue([stepIds containsObject:MSIDOnboardingBlobStepTokenRequestRetrySucceeded]);
        XCTAssertFalse([stepIds containsObject:MSIDOnboardingBlobStepTokenRequestRetryFailed]);
        XCTAssertEqualObjects(stepIds.lastObject, MSIDOnboardingBlobStepTokenRequestRetrySucceeded);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

// Same as above but for the "check_in_timed_out" status, which the response object treats as
// a success.
- (void)testAcquireToken_whenMDMEnrollmentCompletionResponse_andCheckInTimedOutStatus_shouldRetryViaFactory
{
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_mdm_timeout_retry";

    NSURL *mdmURL = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=check_in_timed_out"];
    MSIDWebMDMEnrollmentCompletionResponse *mdmResponse = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:mdmURL
                                                                                                              context:nil
                                                                                                                error:nil];
    XCTAssertNotNil(mdmResponse);
    XCTAssertTrue(mdmResponse.isSuccess);

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:mdmResponse];

    MSIDTokenResult *retryResult = [self resultWithParameters:parameters];

    __block NSUInteger retryAcquireTokenCalled = 0;
    MSIDTestLocalInteractiveController *retryController =
        [[MSIDTestLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                    tokenRequestProvider:provider
                                                                                   error:nil];
    retryController.acquireTokenResult = retryResult;

    [MSIDTestSwizzle classMethod:@selector(interactiveControllerForParameters:tokenRequestProvider:error:)
                           class:[MSIDRequestControllerFactory class]
                           block:(id)^(__unused id obj,
                                       __unused MSIDInteractiveTokenRequestParameters *p,
                                       __unused id<MSIDTokenRequestProviding> tp,
                                       __unused NSError **err)
    {
        retryAcquireTokenCalled++;
        return retryController;
    }];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController =
        [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                tokenRequestProvider:provider
                                                                               error:&error];
    XCTAssertNotNil(interactiveController);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token (MDM timeout retry success)"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(acquireTokenError);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken, retryResult.accessToken);
        XCTAssertEqual(retryAcquireTokenCalled, 1u);
        XCTAssertEqual(retryController.acquireTokenCalledCount, 1u);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

// Verifies that when the webview returns an MSIDWebMDMEnrollmentCompletionResponse with a
// failure status, the controller short-circuits (does NOT consult the factory) and returns an
// MSIDErrorInternal whose description carries the MDM enrollment status.
- (void)testAcquireToken_whenMDMEnrollmentCompletionResponse_andFailureStatus_shouldReturnInternalErrorAndNotRetry
{
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_mdm_failure";

    NSURL *mdmURL = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=failed"];
    MSIDWebMDMEnrollmentCompletionResponse *mdmResponse = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:mdmURL
                                                                                                              context:nil
                                                                                                                error:nil];
    XCTAssertNotNil(mdmResponse);
    XCTAssertFalse(mdmResponse.isSuccess);

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:mdmResponse];

    // Sentinel: the factory must NOT be invoked on the failure path.
    __block NSUInteger factoryCallCount = 0;
    [MSIDTestSwizzle classMethod:@selector(interactiveControllerForParameters:tokenRequestProvider:error:)
                           class:[MSIDRequestControllerFactory class]
                           block:(id)^(__unused id obj,
                                       __unused MSIDInteractiveTokenRequestParameters *p,
                                       __unused id<MSIDTokenRequestProviding> tp,
                                       __unused NSError **err)
    {
        factoryCallCount++;
        return nil;
    }];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController =
        [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                tokenRequestProvider:provider
                                                                               error:&error];
    XCTAssertNotNil(interactiveController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token (MDM failure)"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqualObjects(acquireTokenError.domain, MSIDErrorDomain);
        XCTAssertEqual(acquireTokenError.code, MSIDErrorInternal);

        // No retry must have been attempted via the factory.
        XCTAssertEqual(factoryCallCount, 0u);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

// When the MDM response has no status (or an unrecognized one), the controller treats it as a
// failure and returns an MSIDErrorInternal whose description records the missing-status sentinel.
- (void)testAcquireToken_whenMDMEnrollmentCompletionResponse_andMissingStatus_shouldReturnInternalErrorWithNoneSentinel
{
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_mdm_missing_status";

    NSURL *mdmURL = [NSURL URLWithString:@"msauth://in_app_enrollment_complete"];
    MSIDWebMDMEnrollmentCompletionResponse *mdmResponse = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:mdmURL
                                                                                                              context:nil
                                                                                                                error:nil];
    XCTAssertNotNil(mdmResponse);
    XCTAssertNil(mdmResponse.status);
    XCTAssertFalse(mdmResponse.isSuccess);

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:mdmResponse];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController =
        [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                tokenRequestProvider:provider
                                                                               error:&error];
    XCTAssertNotNil(interactiveController);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token (MDM missing status)"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqualObjects(acquireTokenError.domain, MSIDErrorDomain);
        XCTAssertEqual(acquireTokenError.code, MSIDErrorInternal);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

// Verifies the nil-completionBlock guard early-returns without crashing.
- (void)testHandleWebMDMEnrollmentCompletionResponse_whenCompletionBlockIsNil_shouldReturnSafely
{
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];

    NSURL *mdmURL = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=succeeded"];
    MSIDWebMDMEnrollmentCompletionResponse *mdmResponse = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:mdmURL
                                                                                                              context:nil
                                                                                                                error:nil];
    XCTAssertNotNil(mdmResponse);

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController =
        [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                tokenRequestProvider:[[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                                                                     testError:nil
                                                                                                                         testWebMSAuthResponse:nil]
                                                                               error:&error];
    XCTAssertNotNil(interactiveController);

    // Should not crash when completionBlock is nil.
    MSIDRequestCompletionBlock completionBlock = nil;
    XCTAssertNoThrow([interactiveController handleWebMDMEnrollmentCompletionResponse:mdmResponse completion:completionBlock]);
}

// Controller-factory fallback path: MDM enrollment succeeded but the factory cannot produce a
// controller for the retry. The local controller must surface an error (rather than silently
// dropping the completion or crashing) and must propagate the factory's own error if provided.
- (void)testAcquireToken_whenMDMEnrollmentSuccess_butFactoryReturnsNilWithError_shouldReturnFactoryError
{
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_mdm_factory_error";

    NSURL *mdmURL = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=success"];
    MSIDWebMDMEnrollmentCompletionResponse *mdmResponse = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:mdmURL
                                                                                                              context:nil
                                                                                                                error:nil];
    XCTAssertNotNil(mdmResponse);

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:mdmResponse];

    NSError *factoryError = MSIDCreateError(MSIDErrorDomain,
                                            MSIDErrorInternal,
                                            @"Cannot build controller",
                                            nil, nil, nil,
                                            parameters.correlationId,
                                            nil,
                                            NO);

    // The factory returns nil AND writes an error into the out-pointer.
    __block NSUInteger factoryCallCount = 0;
    [MSIDTestSwizzle classMethod:@selector(interactiveControllerForParameters:tokenRequestProvider:error:)
                           class:[MSIDRequestControllerFactory class]
                           block:(id)^(__unused id obj,
                                       __unused MSIDInteractiveTokenRequestParameters *p,
                                       __unused id<MSIDTokenRequestProviding> tp,
                                       NSError **err)
    {
        factoryCallCount++;
        if (err)
        {
            *err = factoryError;
        }
        return nil;
    }];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController =
        [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                tokenRequestProvider:provider
                                                                               error:&error];
    XCTAssertNotNil(interactiveController);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token (MDM factory error)"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        // The error produced by the factory must be propagated as-is.
        XCTAssertEqualObjects(acquireTokenError, factoryError);
        XCTAssertEqual(factoryCallCount, 1u);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

// Controller-factory fallback path with no underlying error: when the factory returns nil
// without populating an NSError, the controller must synthesize its own MSIDErrorInternal so
// the completion block always fires with a non-nil error.
- (void)testAcquireToken_whenMDMEnrollmentSuccess_butFactoryReturnsNilWithoutError_shouldReturnSynthesizedInternalError
{
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_mdm_factory_nil";

    NSURL *mdmURL = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=success"];
    MSIDWebMDMEnrollmentCompletionResponse *mdmResponse = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:mdmURL
                                                                                                              context:nil
                                                                                                                error:nil];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:mdmResponse];

    [MSIDTestSwizzle classMethod:@selector(interactiveControllerForParameters:tokenRequestProvider:error:)
                           class:[MSIDRequestControllerFactory class]
                           block:(id)^(__unused id obj,
                                       __unused MSIDInteractiveTokenRequestParameters *p,
                                       __unused id<MSIDTokenRequestProviding> tp,
                                       __unused NSError **err)
    {
        // Intentionally do not set *err — exercises the synthesized-error path.
        return nil;
    }];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController =
        [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                tokenRequestProvider:provider
                                                                               error:&error];
    XCTAssertNotNil(interactiveController);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token (MDM factory nil)"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqualObjects(acquireTokenError.domain, MSIDErrorDomain);
        XCTAssertEqual(acquireTokenError.code, MSIDErrorInternal);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

// The retry controller produced by the factory is allowed to fail. In that case the error from
// the retry must reach the original caller untouched.
- (void)testAcquireToken_whenMDMEnrollmentSuccess_andRetryControllerFails_shouldPropagateRetryError
{
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_mdm_retry_failure";
    parameters.onboardingBlobBuilder = [self onboardingBuilder];

    NSURL *mdmURL = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=success"];
    MSIDWebMDMEnrollmentCompletionResponse *mdmResponse = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:mdmURL
                                                                                                              context:nil
                                                                                                                error:nil];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:mdmResponse];

    NSError *retryError = MSIDCreateError(MSIDErrorDomain,
                                          MSIDErrorInteractiveSessionStartFailure,
                                          @"Retry interactive failed",
                                          nil, nil, nil,
                                          parameters.correlationId,
                                          nil,
                                          NO);

    MSIDTestLocalInteractiveController *retryController =
        [[MSIDTestLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                    tokenRequestProvider:provider
                                                                                   error:nil];
    // Leave acquireTokenResult unset (defaults to nil); the property is nonnull-annotated.
    retryController.acquireTokenError = retryError;

    [MSIDTestSwizzle classMethod:@selector(interactiveControllerForParameters:tokenRequestProvider:error:)
                           class:[MSIDRequestControllerFactory class]
                           block:(id)^(__unused id obj,
                                       __unused MSIDInteractiveTokenRequestParameters *p,
                                       __unused id<MSIDTokenRequestProviding> tp,
                                       __unused NSError **err)
    {
        return retryController;
    }];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController =
        [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                tokenRequestProvider:provider
                                                                               error:&error];
    XCTAssertNotNil(interactiveController);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token (MDM retry failure)"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqualObjects(acquireTokenError, retryError);
        XCTAssertEqual(retryController.acquireTokenCalledCount, 1u);

        // Retry telemetry: Started stamped before the retry, Failed stamped on the error result.
        NSArray<NSString *> *stepIds = [self stepIdsFromOnboardingBuilder:parameters.onboardingBlobBuilder];
        XCTAssertTrue([stepIds containsObject:MSIDOnboardingBlobStepTokenRequestRetryStarted]);
        XCTAssertTrue([stepIds containsObject:MSIDOnboardingBlobStepTokenRequestRetryFailed]);
        XCTAssertFalse([stepIds containsObject:MSIDOnboardingBlobStepTokenRequestRetrySucceeded]);
        XCTAssertEqualObjects(stepIds.lastObject, MSIDOnboardingBlobStepTokenRequestRetryFailed);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
