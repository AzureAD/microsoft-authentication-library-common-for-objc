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
#import "MSIDSilentController.h"
#import "MSIDRequestParameters.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDTokenResult.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponse.h"
#import "MSIDAccessToken.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDTelemetryTestDispatcher.h"
#import "MSIDTelemetry.h"
#import "MSIDRefreshToken.h"
#import "MSIDSSOExtensionSilentTokenRequestController.h"
#import "MSIDAADRequestErrorHandler.h"

@interface MSIDSilentControllerIntegrationTests : XCTestCase

@end

@implementation MSIDSilentControllerIntegrationTests

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
    MSIDRefreshToken *refreshToken = [factory refreshTokenFromResponse:response configuration:parameters.msidConfiguration];

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

- (void)testAcquireToken_whenSuccessfulSilentRequest_shouldReturnSuccess
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

    // Setup test request providers
    MSIDRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_id1111";

    MSIDTokenResult *testResult = [self resultWithParameters:parameters];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:testResult testError:nil testWebMSAuthResponse:nil];

    NSError *error = nil;
    MSIDSilentController *silentController = [[MSIDSilentController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:provider error:&error];

    XCTAssertNotNil(silentController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [silentController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

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
        XCTAssertEqualObjects(telemetryEvent[@"is_extended_life_time_token"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"succeeded");
        XCTAssertNotNil(telemetryEvent[@"response_time"]);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenFailingSilentRequest_andNofallbackController_shouldReturnFailure
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

    // Setup test request providers
    MSIDRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_prompt_fail";

    NSError *testError = MSIDCreateError(MSIDErrorDomain, -51433, @"Invalid grant", @"invalid_grant", @"consent_required", nil, parameters.correlationId, nil, YES);

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:testError testWebMSAuthResponse:nil];

    NSError *error = nil;
    MSIDSilentController *silentController = [[MSIDSilentController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:provider error:&error];

    XCTAssertNotNil(silentController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [silentController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

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
        XCTAssertEqualObjects(telemetryEvent[@"is_extended_life_time_token"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"failed");
        XCTAssertNotNil(telemetryEvent[@"response_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_error_code"], @"-51433");
        XCTAssertEqualObjects(telemetryEvent[@"error_domain"], MSIDErrorDomain);
        XCTAssertEqualObjects(telemetryEvent[@"error_protocol_code"], @"invalid_grant");

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenFailingSilentRequest_andFailingInteractiveRequest_shouldReturnFailure
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

    // Setup test request providers
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_prompt_auto_fail";

    NSError *testError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidGrant, @"Invalid grant", @"invalid_grant", @"consent_required", nil, parameters.correlationId, nil, YES);

    MSIDTestTokenRequestProvider *silentProvider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:testError testWebMSAuthResponse:nil];

    NSError *interactiveError = MSIDCreateError(MSIDErrorDomain, -51433, @"Invalid grant 2", @"invalid_grant2", @"consent_required2", nil, parameters.correlationId, nil, YES);

    MSIDTestTokenRequestProvider *interactiveProvider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:interactiveError testWebMSAuthResponse:nil];

    NSError *error = nil;

    MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:interactiveProvider error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(interactiveController);

    MSIDSilentController *silentController = [[MSIDSilentController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:silentProvider fallbackInteractiveController:interactiveController error:&error];

    XCTAssertNotNil(silentController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [silentController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqualObjects(acquireTokenError, interactiveError);

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 1);
        NSDictionary *telemetryEvent = [receivedEvents[0] propertyMap];
        XCTAssertNotNil(telemetryEvent[@"start_time"]);
        XCTAssertNotNil(telemetryEvent[@"stop_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"api_prompt_auto_fail");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"failed");
        XCTAssertNotNil(telemetryEvent[@"response_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_error_code"], @"-51433");
        XCTAssertEqualObjects(telemetryEvent[@"error_domain"], MSIDErrorDomain);
        XCTAssertEqualObjects(telemetryEvent[@"error_protocol_code"], @"invalid_grant2");

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenFailingSilentRequest_andSuccessfulInteractiveRequest_shouldReturnSuccess
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

    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"prompt_auto_interactive_success";

    NSError *testError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidGrant, @"Invalid grant", @"invalid_grant", @"consent_required", nil, parameters.correlationId, nil, YES);

    MSIDTestTokenRequestProvider *silentProvider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:testError testWebMSAuthResponse:nil];

    MSIDTokenResult *testResult = [self resultWithParameters:parameters];

    MSIDTestTokenRequestProvider *interactiveProvider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:testResult testError:nil testWebMSAuthResponse:nil];

    NSError *error = nil;

    MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:interactiveProvider error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(interactiveController);

    MSIDSilentController *silentController = [[MSIDSilentController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:silentProvider fallbackInteractiveController:interactiveController error:&error];

    XCTAssertNotNil(silentController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [silentController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNotNil(result);
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
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"prompt_auto_interactive_success");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"succeeded");
        XCTAssertNotNil(telemetryEvent[@"response_time"]);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_WhenFallingLocalController_AndFallbackControllerReturnSSOUnexpectedError_ShouldReturnLocalError
{

        // Setup test request providers
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_prompt_auto_fail";

    NSError *localError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidGrant, @"Invalid grant", @"invalid_grant", @"consent_required", nil, parameters.correlationId, nil, YES);

    MSIDTestTokenRequestProvider *localSilentProvider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:localError testWebMSAuthResponse:nil];


    NSError *error = nil;
    NSError *ssoUnexpectedError = MSIDCreateError(MSIDErrorDomain, MSIDErrorSSOExtensionUnexpectedError, @"unexpected error", @"unexpected error", @"unexpected error", nil, parameters.correlationId, nil, YES);
    MSIDTestTokenRequestProvider *brokerSilentProvider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:ssoUnexpectedError testWebMSAuthResponse:nil];

    MSIDSilentController *brokerController = [[MSIDSSOExtensionSilentTokenRequestController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:brokerSilentProvider error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(brokerController);

    MSIDSilentController *silentController = [[MSIDSilentController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:localSilentProvider fallbackInteractiveController:brokerController error:&error];
    XCTAssertNotNil(silentController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    [silentController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqualObjects(acquireTokenError, localError);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

}

- (void)testAcquireToken_WhenFallingLocalController_AndFallbackControllerReturnSSOExpectedError_ShouldReturnSSOError
{

    // Setup test request providers
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_prompt_auto_fail";

    NSError *localError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidGrant, @"Invalid grant", @"invalid_grant", @"consent_required", nil, parameters.correlationId, nil, YES);

    MSIDTestTokenRequestProvider *localSilentProvider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:localError testWebMSAuthResponse:nil];


    NSError *error = nil;
    NSError *ssoExpectedError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidGrant, @"Expected error", @"Expected error", @"Expected error", nil, parameters.correlationId, nil, YES);
    MSIDTestTokenRequestProvider *brokerSilentProvider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:ssoExpectedError testWebMSAuthResponse:nil];

    MSIDSilentController *brokerController = [[MSIDSSOExtensionSilentTokenRequestController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:brokerSilentProvider error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(brokerController);

    MSIDSilentController *silentController = [[MSIDSilentController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:localSilentProvider fallbackInteractiveController:brokerController error:&error];
    XCTAssertNotNil(silentController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    [silentController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqualObjects(acquireTokenError, ssoExpectedError);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

}

- (void)testAcquireToken_WhenFallingLocalController_AndFallbackControllerReturnSSOUnexpectedError_ShouldReturnLocalError_AllowLocalRtFlow
{

        // Setup test request providers
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_prompt_auto_fail";
    parameters.allowUsingLocalCachedRtWhenSsoExtFailed = YES;
    NSError *localError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidGrant, @"Invalid grant", @"invalid_grant", @"consent_required", nil, parameters.correlationId, nil, YES);

    MSIDTestTokenRequestProvider *localSilentProvider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:localError testWebMSAuthResponse:nil];


    NSError *error = nil;
    NSError *ssoUnexpectedError = MSIDCreateError(MSIDErrorDomain, MSIDErrorSSOExtensionUnexpectedError, @"unexpected error", @"unexpected error", @"unexpected error", nil, parameters.correlationId, nil, YES);
    MSIDTestTokenRequestProvider *brokerSilentProvider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:ssoUnexpectedError testWebMSAuthResponse:nil];
    
    MSIDSilentController *silentControllerFallback = [[MSIDSilentController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:localSilentProvider error:&error];
    XCTAssertNotNil(silentControllerFallback);
    XCTAssertNil(error);

    MSIDSilentController *brokerController = [[MSIDSSOExtensionSilentTokenRequestController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:brokerSilentProvider fallbackInteractiveController:silentControllerFallback error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(brokerController);

    MSIDSilentController *silentController = [[MSIDSilentController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:localSilentProvider fallbackInteractiveController:brokerController error:&error];
    XCTAssertNotNil(silentController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    [silentController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqualObjects(acquireTokenError, localError);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

}

- (void)testAcquireToken_WhenFallingLocalController_AndFallbackControllerReturnSSOExpectedError_ShouldReturnSSOError_AllowLocalRtFlow
{

    // Setup test request providers
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_prompt_auto_fail";
    parameters.allowUsingLocalCachedRtWhenSsoExtFailed = YES;
    NSError *localError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidGrant, @"Invalid grant", @"invalid_grant", @"consent_required", nil, parameters.correlationId, nil, YES);

    MSIDTestTokenRequestProvider *localSilentProvider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:localError testWebMSAuthResponse:nil];


    NSError *error = nil;
    NSError *ssoExpectedError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidGrant, @"Expected error", @"Expected error", @"Expected error", nil, parameters.correlationId, nil, YES);
    MSIDTestTokenRequestProvider *brokerSilentProvider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:ssoExpectedError testWebMSAuthResponse:nil];

    MSIDSilentController *silentControllerFallback = [[MSIDSilentController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:localSilentProvider error:&error];
    XCTAssertNotNil(silentControllerFallback);
    XCTAssertNil(error);
    
    MSIDSilentController *brokerController = [[MSIDSSOExtensionSilentTokenRequestController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:brokerSilentProvider fallbackInteractiveController:silentControllerFallback error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(brokerController);

    MSIDSilentController *silentController = [[MSIDSilentController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:localSilentProvider fallbackInteractiveController:brokerController error:&error];
    XCTAssertNotNil(silentController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    [silentController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqualObjects(acquireTokenError, localError);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

}

- (void)testAcquireToken_whenNetworkFailure_shouldRetry
{
    // Setup telemetry callback
    MSIDTelemetryTestDispatcher *dispatcher = [MSIDTelemetryTestDispatcher new];
    NSMutableArray *receivedEvents = [NSMutableArray array];

    [dispatcher setTestCallback:^(id<MSIDTelemetryEventInterface> event) {
        [receivedEvents addObject:event];
    }];

    // Register the dispatcher
    [[MSIDTelemetry sharedInstance] addDispatcher:dispatcher];

    // Setup test request parameters
    MSIDRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_network_retry_test";

    // Network failure error
    NSError *networkError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];

    // Configure the token request provider to simulate a network failure
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:networkError testWebMSAuthResponse:nil];

    NSError *error = nil;
    MSIDSilentController *silentController = [[MSIDSilentController alloc] initWithRequestParameters:parameters forceRefresh:NO tokenRequestProvider:provider error:&error];

    XCTAssertNotNil(silentController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [silentController acquireToken:^(__unused MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        // Check if the error was correctly identified as a network failure
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqual(acquireTokenError.code, networkError.code);

        // Check to see if retry logic was attempted
        XCTAssertTrue([MSIDAADRequestErrorHandler shouldRetryNetworkingFailure:acquireTokenError.code]);

        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
