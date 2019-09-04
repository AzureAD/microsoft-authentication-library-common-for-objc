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
#import "MSIDRequestParameters.h"
#import "MSIDTokenResult.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponse.h"
#import "MSIDAccessToken.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDTelemetryTestDispatcher.h"
#import "MSIDTelemetry.h"
#import "MSIDApplicationTestUtil.h"
#import "MSIDWebWPJResponse.h"
#import "MSIDBrokerInteractiveController.h"
#import "MSIDTestBrokerResponseHandler.h"
#import "MSIDTestTokenRequestProvider.h"
#import "MSIDRefreshToken.h"
#import "MSIDTestURLSession.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDAadAuthorityCache.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDTestLocalInteractiveController.h"

@interface MSIDBrokerInteractiveControllerIntegrationTests : XCTestCase

@end

@implementation MSIDBrokerInteractiveControllerIntegrationTests

- (void)setUp
{
    [super setUp];
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
}

- (void)tearDown
{
    [[MSIDAuthority openIdConfigurationCache] removeAllObjects];
    [[MSIDAadAuthorityCache sharedInstance] removeAllObjects];
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = nil;
    [super tearDown];
}

#pragma mark - Helpers

- (MSIDInteractiveRequestParameters *)requestParameters
{
    MSIDInteractiveRequestParameters *parameters = [MSIDInteractiveRequestParameters new];
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

#pragma mark - Tests

- (void)testAcquireToken_whenSuccessfulBrokerResponse_shouldReturnSuccess
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

    NSDictionary *testResumeDictionary = @{@"test-resume-key1": @"test-resume-value2",
                                           @"test-resume-key2": @"test-resume-value2"};

    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey1"];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:testResumeDictionary];

    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                                                                 tokenRequestProvider:provider
                                                                                                                   fallbackController:nil
                                                                                                                                error:&error];

    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);

    MSIDTokenResult *testResult = [self resultWithParameters:parameters];

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, NSDictionary<NSString *,id> *options) {

        XCTAssertEqualObjects(url, brokerRequestURL);

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

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(result);
        // Check result
        XCTAssertEqualObjects(result.accessToken, testResult.accessToken);
        XCTAssertEqualObjects(result.rawIdToken, testResult.rawIdToken);
        XCTAssertEqualObjects(result.account, testResult.account);
        XCTAssertEqualObjects(result.authority, testResult.authority);
        XCTAssertNil(error);

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
        XCTAssertEqualObjects(telemetryEvent[@"tenant_id"], @"1234-5678-90abcdefg");
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

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenFailedToLaunchBrokerThroughUniversalLink_andNoFallbackController_shouldReturnError
{
    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey1"];
    
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:nil];
    
    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:[self requestParameters]
                                                                                                                 tokenRequestProvider:provider
                                                                                                                   fallbackController:nil
                                                                                                                                error:&error];
    
    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);
    
    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, NSDictionary<NSString *,id> *options) {
        
        XCTAssertEqualObjects(url, brokerRequestURL);
        return NO;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];
    
    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        // Check error
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Failed to open broker URL.");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    
}

- (void)testAcquireToken_whenFailedToLaunchBrokerThroughUniversalLink_andFallbackController_shouldFallback
{
    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey1"];
    
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:nil];
    
    NSError *error = nil;
    MSIDTestLocalInteractiveController *fallbackController = [MSIDTestLocalInteractiveController new];
    fallbackController.acquireTokenResult = [self resultWithParameters:[self requestParameters]];
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:[self requestParameters]
                                                                                                                 tokenRequestProvider:provider
                                                                                                                   fallbackController:fallbackController
                                                                                                                                error:&error];
    
    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);
    
    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, NSDictionary<NSString *,id> *options) {
        
        XCTAssertEqualObjects(url, brokerRequestURL);
        return NO;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];
    
    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        XCTAssertEqual(fallbackController.acquireTokenCalledCount, 1);
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        // Check error
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenErrorBrokerResponse_shouldReturnError
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
    parameters.telemetryApiId = @"api_broker_failure";

    NSDictionary *testResumeDictionary = @{@"test-resume-key1": @"test-resume-value2",
                                           @"test-resume-key2": @"test-resume-value2"};

    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey2"];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:testResumeDictionary];

    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider fallbackController:nil error:&error];

    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);

    NSError *testError = MSIDCreateError(MSIDErrorDomain, 123456789, @"Test broker error", @"broker_error", @"broker_sub_error", nil, parameters.correlationId, nil);

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, NSDictionary<NSString *,id> *options) {

        XCTAssertEqualObjects(url, brokerRequestURL);

        NSDictionary *resumeDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
        XCTAssertEqualObjects(resumeDictionary, testResumeDictionary);

        MSIDTestBrokerResponseHandler *brokerResponseHandler = [[MSIDTestBrokerResponseHandler alloc] initWithTestResponse:nil testError:testError];

        [MSIDBrokerInteractiveController completeAcquireToken:[NSURL URLWithString:@"https://contoso.com"]
                                            sourceApplication:@"com.microsoft.azureauthenticator"
                                        brokerResponseHandler:brokerResponseHandler];
        return YES;
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, 123456789);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Test broker error");
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"broker_error");
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"broker_sub_error");

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 4);
        NSDictionary *telemetryEvent = [receivedEvents[2] propertyMap];
        XCTAssertNotNil(telemetryEvent[@"start_time"]);
        XCTAssertNotNil(telemetryEvent[@"stop_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"api_broker_failure");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"failed");
        XCTAssertEqualObjects(telemetryEvent[@"login_hint"], @"d24dfead25359b0c562c8a02a6a0e6db8de4a8b235d56e122a75a8e1f2e473ee");
        XCTAssertEqualObjects(telemetryEvent[@"client_id"], @"my_client_id");
        XCTAssertEqualObjects(telemetryEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertEqualObjects(telemetryEvent[@"api_error_code"], @"123456789");
        XCTAssertEqualObjects(telemetryEvent[@"error_domain"], MSIDErrorDomain);
        XCTAssertNotNil(telemetryEvent[@"response_time"]);

        NSDictionary *brokerEvent = [receivedEvents[3] propertyMap];
        XCTAssertEqualObjects(brokerEvent[@"broker_app"], @"Microsoft Authenticator");
        XCTAssertEqualObjects(brokerEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertEqualObjects(brokerEvent[@"event_name"], @"broker_event");
        XCTAssertEqualObjects(brokerEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(brokerEvent[@"status"], @"failed");
        XCTAssertNotNil(brokerEvent[@"start_time"]);
        XCTAssertNotNil(brokerEvent[@"stop_time"]);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenBrokerRequestAlreadyInProgress_shouldReturnErrorForSecondRequest
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

    NSDictionary *testResumeDictionary = @{@"test-resume-key1": @"test-resume-value2",
                                           @"test-resume-key2": @"test-resume-value2"};

    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey3"];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:testResumeDictionary];

    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider fallbackController:nil error:&error];

    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);

    MSIDTokenResult *testResult = [self resultWithParameters:parameters];

    XCTestExpectation *firstRequestExpectation = [self expectationWithDescription:@"First request"];
    XCTestExpectation *secondRequestExpectation = [self expectationWithDescription:@"Second request"];

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, NSDictionary<NSString *,id> *options) {

        XCTAssertEqualObjects(url, brokerRequestURL);

        NSDictionary *resumeDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
        XCTAssertEqualObjects(resumeDictionary, testResumeDictionary);

        MSIDBrokerInteractiveController *secondBrokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider fallbackController:nil error:nil];

        [secondBrokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
            XCTAssertNotNil(error);
            XCTAssertEqual(error.code, MSIDErrorInteractiveSessionAlreadyRunning);
            XCTAssertNil(result);

            [secondRequestExpectation fulfill];

            // Call acquire token completion after we get this error
            MSIDTestBrokerResponseHandler *brokerResponseHandler = [[MSIDTestBrokerResponseHandler alloc] initWithTestResponse:testResult testError:nil];

            [MSIDBrokerInteractiveController completeAcquireToken:[NSURL URLWithString:@"https://contoso.com"]
                                                sourceApplication:@"com.microsoft.azureauthenticator"
                                            brokerResponseHandler:brokerResponseHandler];
        }];

        return YES;
    }];
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(result);
        // Check result
        XCTAssertEqualObjects(result.accessToken, testResult.accessToken);
        XCTAssertEqualObjects(result.rawIdToken, testResult.rawIdToken);
        XCTAssertEqualObjects(result.account, testResult.account);
        XCTAssertEqualObjects(result.authority, testResult.authority);
        XCTAssertNil(error);

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 5);
        NSDictionary *telemetryEvent = [receivedEvents[3] propertyMap];
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

        NSDictionary *brokerEvent = [receivedEvents[4] propertyMap];
        XCTAssertEqualObjects(brokerEvent[@"broker_app"], @"Microsoft Authenticator");
        XCTAssertEqualObjects(brokerEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertEqualObjects(brokerEvent[@"event_name"], @"broker_event");
        XCTAssertEqualObjects(brokerEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(brokerEvent[@"status"], @"succeeded");
        XCTAssertNotNil(brokerEvent[@"start_time"]);
        XCTAssertNotNil(brokerEvent[@"stop_time"]);

        [firstRequestExpectation fulfill];
    }];

    [self waitForExpectations:@[secondRequestExpectation, firstRequestExpectation] timeout:1.0 enforceOrder:YES];
}

- (void)testAcquireToken_whenFailedToCreateBrokerRequest_shouldReturnError
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
    parameters.telemetryApiId = @"api_broker_failure";

    NSError *testError = MSIDCreateError(MSIDErrorDomain, 1234567, @"Failed to create broker request", nil, nil, nil, nil, nil);

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:testError testWebMSAuthResponse:nil brokerRequestURL:nil resumeDictionary:nil];

    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider fallbackController:nil error:&error];

    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, 1234567);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Failed to create broker request");

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 3);
        NSDictionary *telemetryEvent = [receivedEvents[2] propertyMap];
        XCTAssertNotNil(telemetryEvent[@"start_time"]);
        XCTAssertNotNil(telemetryEvent[@"stop_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"api_broker_failure");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"failed");
        XCTAssertEqualObjects(telemetryEvent[@"login_hint"], @"d24dfead25359b0c562c8a02a6a0e6db8de4a8b235d56e122a75a8e1f2e473ee");
        XCTAssertEqualObjects(telemetryEvent[@"client_id"], @"my_client_id");
        XCTAssertEqualObjects(telemetryEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertEqualObjects(telemetryEvent[@"api_error_code"], @"1234567");
        XCTAssertEqualObjects(telemetryEvent[@"error_domain"], MSIDErrorDomain);
        XCTAssertNotNil(telemetryEvent[@"response_time"]);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#if !AD_BROKER
- (void)testAcquireToken_whenBrokerResponseNotReceived_shouldReturnError
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
    parameters.telemetryApiId = @"api_broker_response_not_received";

    NSDictionary *testResumeDictionary = @{@"test-resume-key1": @"test-resume-value2",
                                           @"test-resume-key2": @"test-resume-value2"};

    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey4"];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:testResumeDictionary];

    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider fallbackController:nil error:&error];

    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, NSDictionary<NSString *,id> *options) {

        XCTAssertEqualObjects(url, brokerRequestURL);

        NSDictionary *resumeDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
        XCTAssertEqualObjects(resumeDictionary, testResumeDictionary);

        // Post UIApplication lifecycle notifications to simulate user coming back to the app
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];

        return YES;
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    __block BOOL calledCompletion = NO;
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        // Make sure completion is not called multiple times
        XCTAssertFalse(calledCompletion);
        calledCompletion = YES;

        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorBrokerResponseNotReceived);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 4);
        NSDictionary *telemetryEvent = [receivedEvents[2] propertyMap];
        XCTAssertNotNil(telemetryEvent[@"start_time"]);
        XCTAssertNotNil(telemetryEvent[@"stop_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"api_broker_response_not_received");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"failed");
        XCTAssertEqualObjects(telemetryEvent[@"login_hint"], @"d24dfead25359b0c562c8a02a6a0e6db8de4a8b235d56e122a75a8e1f2e473ee");
        XCTAssertEqualObjects(telemetryEvent[@"client_id"], @"my_client_id");
        XCTAssertEqualObjects(telemetryEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertEqualObjects(telemetryEvent[@"api_error_code"], @"-51800");
        XCTAssertEqualObjects(telemetryEvent[@"error_domain"], MSIDErrorDomain);
        XCTAssertNotNil(telemetryEvent[@"response_time"]);

        NSDictionary *brokerEvent = [receivedEvents[3] propertyMap];
        XCTAssertEqualObjects(brokerEvent[@"broker_app"], @"Microsoft Authenticator");
        XCTAssertEqualObjects(brokerEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertEqualObjects(brokerEvent[@"event_name"], @"broker_event");
        XCTAssertEqualObjects(brokerEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(brokerEvent[@"status"], @"failed");
        XCTAssertNotNil(brokerEvent[@"start_time"]);
        XCTAssertNotNil(brokerEvent[@"stop_time"]);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
#endif

#if !AD_BROKER
- (void)testAcquireToken_whenBrokerResponseReceivedAfterReturningToApp_shouldReturnErrorAndCallCompletionBlockOnce
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
    parameters.telemetryApiId = @"api_broker_response_not_received";

    NSDictionary *testResumeDictionary = @{@"test-resume-key1": @"test-resume-value2",
                                           @"test-resume-key2": @"test-resume-value2"};

    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey5"];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:testResumeDictionary];

    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider fallbackController:nil error:&error];

    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);

    MSIDTokenResult *testResult = [self resultWithParameters:parameters];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, NSDictionary<NSString *,id> *options) {

        XCTAssertEqualObjects(url, brokerRequestURL);

        NSDictionary *resumeDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
        XCTAssertEqualObjects(resumeDictionary, testResumeDictionary);

        // Post UIApplication lifecycle notifications to simulate user coming back to the app
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];

        // Now call acquire token completion, to simulate response arriving after user coming back to the app
        MSIDTestBrokerResponseHandler *brokerResponseHandler = [[MSIDTestBrokerResponseHandler alloc] initWithTestResponse:testResult testError:nil];
        [MSIDBrokerInteractiveController completeAcquireToken:[NSURL URLWithString:@"https://contoso.com"]
                                            sourceApplication:@"com.microsoft.azureauthenticator"
                                        brokerResponseHandler:brokerResponseHandler];

        return YES;
    }];

    __block BOOL calledCompletion = NO;
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        // Make sure completion is not called multiple times
        XCTAssertFalse(calledCompletion);
        calledCompletion = YES;

        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorBrokerResponseNotReceived);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 4);
        NSDictionary *telemetryEvent = [receivedEvents[2] propertyMap];
        XCTAssertNotNil(telemetryEvent[@"start_time"]);
        XCTAssertNotNil(telemetryEvent[@"stop_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"api_broker_response_not_received");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"failed");
        XCTAssertEqualObjects(telemetryEvent[@"login_hint"], @"d24dfead25359b0c562c8a02a6a0e6db8de4a8b235d56e122a75a8e1f2e473ee");
        XCTAssertEqualObjects(telemetryEvent[@"client_id"], @"my_client_id");
        XCTAssertEqualObjects(telemetryEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertEqualObjects(telemetryEvent[@"api_error_code"], @"-51800");
        XCTAssertEqualObjects(telemetryEvent[@"error_domain"], MSIDErrorDomain);
        XCTAssertNotNil(telemetryEvent[@"response_time"]);

        NSDictionary *brokerEvent = [receivedEvents[3] propertyMap];
        XCTAssertEqualObjects(brokerEvent[@"broker_app"], @"Microsoft Authenticator");
        XCTAssertEqualObjects(brokerEvent[@"correlation_id"], parameters.correlationId.UUIDString);
        XCTAssertEqualObjects(brokerEvent[@"event_name"], @"broker_event");
        XCTAssertEqualObjects(brokerEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(brokerEvent[@"status"], @"failed");
        XCTAssertNotNil(brokerEvent[@"start_time"]);
        XCTAssertNotNil(brokerEvent[@"stop_time"]);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
#endif

#if !AD_BROKER
- (void)testCompleteAcquireToken_whenNonBrokerResponse_shouldReturnNOAndNotHandleRequest
{
    MSIDTokenResult *testResult = [self resultWithParameters:[self requestParameters]];

    MSIDTestBrokerResponseHandler *brokerResponseHandler = [[MSIDTestBrokerResponseHandler alloc] initWithTestResponse:testResult testError:nil];
    BOOL result = [MSIDBrokerInteractiveController completeAcquireToken:[NSURL URLWithString:@"https://contoso.com"]
                                                      sourceApplication:@"com.microsoft.otherapp"
                                                  brokerResponseHandler:brokerResponseHandler];

    XCTAssertFalse(result);
}

- (void)testAcquireToken_whenSuccessfulBrokerResponse_andNilSourceApplication_shouldStillReturnSuccess
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
    
    NSDictionary *testResumeDictionary = @{@"test-resume-key1": @"test-resume-value2",
                                           @"test-resume-key2": @"test-resume-value2"};
    
    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey1"];
    
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:testResumeDictionary];
    
    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider fallbackController:nil error:&error];
    
    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);
    
    MSIDTokenResult *testResult = [self resultWithParameters:parameters];
    
    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, NSDictionary<NSString *,id> *options) {
        
        XCTAssertEqualObjects(url, brokerRequestURL);
        
        NSDictionary *resumeDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
        XCTAssertEqualObjects(resumeDictionary, testResumeDictionary);
        
        MSIDTestBrokerResponseHandler *brokerResponseHandler = [[MSIDTestBrokerResponseHandler alloc] initWithTestResponse:testResult testError:nil];
        
        [MSIDBrokerInteractiveController completeAcquireToken:[NSURL URLWithString:@"https://contoso.com"]
                                            sourceApplication:nil
                                        brokerResponseHandler:brokerResponseHandler];
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];
    
    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken, testResult.accessToken);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
#endif

@end
