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
#import "MSIDAuthorityFactory.h"
#import "MSIDTokenResult.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponse.h"
#import "MSIDAccessToken.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDTelemetryTestDispatcher.h"
#import "MSIDTelemetry.h"
#if TARGET_OS_IPHONE
#import "MSIDApplicationTestUtil.h"
#import "MSIDWebMSAuthResponse.h"
#import "MSIDBrokerInteractiveController.h"
#import "MSIDTestBrokerResponseHandler.h"
#endif

#import "MSIDConfiguration.h"

@interface MSIDInteractiveControllerIntegrationTests : XCTestCase

@end

@implementation MSIDInteractiveControllerIntegrationTests

#pragma mark - Helpers

- (MSIDInteractiveRequestParameters *)requestParameters
{
    MSIDInteractiveRequestParameters *parameters = [MSIDInteractiveRequestParameters new];

    MSIDAuthority *authority = [MSIDAuthorityFactory authorityFromUrl:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"my_redirect_uri"
                                                                           clientId:@"my_client_id"
                                                                             target:@"user.read tasks.read"];

    parameters.configuration = configuration;
    parameters.oidcScope = @"openid profile offline_access";
    parameters.correlationId = [NSUUID new];
    parameters.extendedLifetimeEnabled = YES;
    parameters.telemetryRequestId = [[NSUUID new] UUIDString];
    parameters.loginHint = @"user@contoso.com";
    return parameters;

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
                                                             extExpiresIn:nil];

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:testResponse context:nil error:nil];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:parameters.msidConfiguration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:parameters.msidConfiguration];

    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:accessToken.authority
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
    MSIDInteractiveRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_id1111";

    MSIDTokenResult *testResult = [self resultWithParameters:parameters];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:testResult testError:nil testWebMSAuthResponse:nil];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider error:&error];

    XCTAssertNotNil(interactiveController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(result);
        // Check result
        XCTAssertEqualObjects(result.accessToken, testResult.accessToken);
        XCTAssertEqualObjects(result.rawIdToken, testResult.rawIdToken);
        XCTAssertEqualObjects(result.account, testResult.account);
        XCTAssertEqualObjects(result.authority, testResult.authority);
        XCTAssertNil(error);

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
        XCTAssertEqualObjects(telemetryEvent[@"tenant_id"], @"1234-5678-90abcdefg");
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
    MSIDInteractiveRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_prompt_fail";

    NSError *testError = MSIDCreateError(MSIDErrorDomain, -51433, @"Invalid grant", @"invalid_grant", @"consent_required", nil, parameters.correlationId, nil);

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:testError testWebMSAuthResponse:nil];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider error:&error];

    XCTAssertNotNil(interactiveController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error, testError);

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

#if TARGET_OS_IPHONE
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
    MSIDInteractiveRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_broker_success";

    NSString *brokerURL = [NSString stringWithFormat:@"msauth://wpj?app_link=https%%3A%%2F%%2Ftest.url.broker%%3Ftest1%%3Dtest2"];
    MSIDWebMSAuthResponse *msAuthResponse = [[MSIDWebMSAuthResponse alloc] initWithURL:[NSURL URLWithString:brokerURL] context:nil error:nil];

    NSDictionary *testResumeDictionary = @{@"test-resume-key1": @"test-resume-value2",
                                           @"test-resume-key2": @"test-resume-value2"};

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:msAuthResponse brokerRequestURL:[NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey"] resumeDictionary:testResumeDictionary];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider error:&error];

    XCTAssertNotNil(interactiveController);
    XCTAssertNil(error);

    MSIDTokenResult *testResult = [self resultWithParameters:parameters];

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, NSDictionary<NSString *,id> *options) {

        XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://test.url.broker?test1=test2"]);

        UIPasteboard *appPasteBoard = [UIPasteboard pasteboardWithName:@"WPJ" create:NO];
        XCTAssertEqualObjects(appPasteBoard.URL, [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey&sourceApplication=com.microsoft.MSIDTestsHostApp"]);

        NSDictionary *resumeDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
        XCTAssertEqualObjects(resumeDictionary, testResumeDictionary);

        MSIDTestBrokerResponseHandler *brokerResponseHandler = [[MSIDTestBrokerResponseHandler alloc] initWithTestResponse:testResult testError:nil];

        [MSIDBrokerInteractiveController completeAcquireToken:[NSURL URLWithString:@"https://contoso.com"] brokerResponseHandler:brokerResponseHandler];
        return YES;
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(result);
        // Check result
        XCTAssertEqualObjects(result.accessToken, testResult.accessToken);
        XCTAssertEqualObjects(result.rawIdToken, testResult.rawIdToken);
        XCTAssertEqualObjects(result.account, testResult.account);
        XCTAssertEqualObjects(result.authority, testResult.authority);
        XCTAssertNil(error);

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 2);
        NSDictionary *telemetryEvent = [receivedEvents[0] propertyMap];
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
        XCTAssertEqualObjects(telemetryEvent[@"tenant_id"], @"1234-5678-90abcdefg");
        XCTAssertEqualObjects(telemetryEvent[@"client_id"], @"my_client_id");
        XCTAssertEqualObjects(telemetryEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertNotNil(telemetryEvent[@"response_time"]);

        NSDictionary *brokerEvent = [receivedEvents[1] propertyMap];
        XCTAssertEqualObjects(brokerEvent[@"broker_app"], @"Microsoft Authenticator");
        XCTAssertEqualObjects(brokerEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertEqualObjects(brokerEvent[@"event_name"], @"broker_event");
        XCTAssertEqualObjects(brokerEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(brokerEvent[@"status"], @"succeeded");
        XCTAssertNotNil(brokerEvent[@"start_time"]);
        XCTAssertNotNil(brokerEvent[@"stop_time"]);

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
    MSIDInteractiveRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_broker_link_failure";

    NSString *brokerURL = [NSString stringWithFormat:@"msauth://wpj?app_link_wrong=https%%3A%%2F%%2Ftest.url.broker%%3Ftest1%%3Dtest2"];
    MSIDWebMSAuthResponse *msAuthResponse = [[MSIDWebMSAuthResponse alloc] initWithURL:[NSURL URLWithString:brokerURL] context:nil error:nil];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:msAuthResponse brokerRequestURL:[NSURL URLWithString:@"https://contoso.com"] resumeDictionary:@{}];

    NSError *error = nil;
    MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider error:&error];

    XCTAssertNotNil(interactiveController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInternal);

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

@end
