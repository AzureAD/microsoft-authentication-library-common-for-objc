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
#import "MSIDInteractiveTokenRequestParameters.h"
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
#import "MSIDTestIdentifiers.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDDefaultBrokerResponseHandler.h"
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDTestIdTokenUtil.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDTestBrokerResponseHelper.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDTestBrokerKeyProviderHelper.h"
#import "MSIDTestSwizzle.h"
#import "MSIDAppExtensionUtil.h"
#import "MSIDThrottlingService.h"
#import "MSIDDefaultTokenRequestProvider.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDDefaultTokenCacheAccessor.h"

@interface MSIDBrokerInteractiveControllerIntegrationTests : XCTestCase

@end

@implementation MSIDBrokerInteractiveControllerIntegrationTests

- (NSMutableDictionary<NSString *, NSMutableArray<MSIDTestSwizzle *> *> *)swizzleStacks
{
    static dispatch_once_t once;
    static NSMutableDictionary<NSString *, NSMutableArray<MSIDTestSwizzle *> *> *swizzleStacks = nil;
    
    dispatch_once(&once, ^{
        swizzleStacks = [NSMutableDictionary new];
    });
    
    return swizzleStacks;
}

- (void)setUp
{
    [super setUp];
    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:@"v2.0" forKey:@"aadApiVersion"];

    [MSIDTestBrokerKeyProviderHelper addKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"] accessGroup:@"com.microsoft.adalcache" applicationTag:MSID_BROKER_SYMMETRIC_KEY_TAG];
}

- (void)tearDown
{
    [MSIDTestSwizzle resetWithSwizzleArray:[self.swizzleStacks objectForKey:self.name]];
    // Clear keychain
    NSDictionary *query = @{(id)kSecClass : (id)kSecClassKey,
                            (id)kSecAttrKeyClass : (id)kSecAttrKeyClassSymmetric};

    SecItemDelete((CFDictionaryRef)query);

    [[MSIDAuthority openIdConfigurationCache] removeAllObjects];
    [[MSIDAadAuthorityCache sharedInstance] removeAllObjects];
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:nil forKey:@"aadApiVersion"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
    [super tearDown];
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
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
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

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, __unused NSDictionary<NSString *,id> *options) {

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

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

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

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenSuccessfulBrokerResponse_shouldUpdateThrottleLastRefresh
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
       
    MSIDDefaultTokenRequestProvider *provider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                              defaultAccessor:[MSIDDefaultTokenCacheAccessor new]
                                                                                      accountMetadataAccessor:[MSIDAccountMetadataCacheAccessor new]
                                                                                       tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                                                                 tokenRequestProvider:provider
                                                                                                                   fallbackController:nil
                                                                                                                                error:&error];
    
    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);
    
    MSIDTokenResult *testResult = [self resultWithParameters:parameters];
    
    [MSIDApplicationTestUtil onOpenURL:^BOOL(__unused NSURL *url, __unused NSDictionary<NSString *,id> *options) {
        MSIDTestBrokerResponseHandler *brokerResponseHandler = [[MSIDTestBrokerResponseHandler alloc] initWithTestResponse:testResult testError:nil];
        [MSIDBrokerInteractiveController completeAcquireToken:[NSURL URLWithString:@"https://contoso.com"]
                                            sourceApplication:@"com.microsoft.azureauthenticator"
                                        brokerResponseHandler:brokerResponseHandler];
        return YES;
    }];
    
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];
    __block int count = 0;
    [MSIDTestSwizzle classMethod:@selector(updateLastRefreshTimeDatasource:context:error:)
                           class:[MSIDThrottlingService class]
                           block:(id)^(__unused id obj)
     {
        count++;
        return YES;
    }];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    [brokerController acquireToken:^(__unused MSIDTokenResult * _Nullable result, __unused NSError * _Nullable acquireTokenError) {
        
        XCTAssertEqual(count, 1);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenInsufficientScopesReturned_shouldReturnNilResultAndError
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
    parameters.oidcScope = @"openid profile offline_access not_granted_scope";
    parameters.telemetryApiId = @"api_broker_success";

    NSDictionary *testResumeDictionary = @{@"test-resume-key1": @"test-resume-value1",
                                           @"test-resume-key2": @"test-resume-value2",
                                           MSID_SDK_NAME_KEY: MSID_MSAL_SDK_NAME,
                                           @"keychain_group" : @"com.microsoft.adalcache",
                                           @"redirect_uri" : @"x-msauth-test://com.microsoft.testapp",
                                           @"broker_nonce" : @"nonce"
    };

    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey1"];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:testResumeDictionary];

    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                                                                 tokenRequestProvider:provider
                                                                                                                   fallbackController:nil
                                                                                                                                error:&error];

    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);

    NSString *scopes = @"myscope1 myscope2";
    NSString *idTokenString = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"user@contoso.com"
                                                                        subject:@"mysubject"
                                                                      givenName:@"myGivenName"
                                                                     familyName:@"myFamilyName"
                                                                           name:@"Contoso"
                                                                        version:@"2.0"
                                                                            tid:@"contoso.com-guid"];

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, __unused NSDictionary<NSString *,id> *options) {

        XCTAssertEqualObjects(url, brokerRequestURL);

        NSDictionary *resumeDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
        XCTAssertEqualObjects(resumeDictionary, testResumeDictionary);

        NSDictionary *clientInfo = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
        NSString *rawClientInfo = [clientInfo msidBase64UrlJson];

        NSDate *expiresOn = [NSDate dateWithTimeIntervalSinceNow:3600];
        NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];

        NSString *correlationId = [[NSUUID UUID] UUIDString];

        NSDictionary *brokerResponseParams =
        @{
          @"correlation_id" : correlationId,
          @"x-broker-app-ver" : @"1.0.0",
          @"success": @NO,
          @"broker_nonce" : @"nonce",
          @"MSIDDeclinedScopesKey" : @"not_granted_scope",
          @"MSIDGrantedScopesKey" : scopes,
          @"additional_tokens" : [NSString stringWithFormat:@"{\"client_info\":\"\%@\",\"authority\":\"https://login.microsoftonline.com/common\",\"token_type\":\"Bearer\",\"x-broker-app-ver\":\"1.0\",\"refresh_token\":\"i-am-a-refresh-token\",\"scope\":\"%@ openid profile\",\"broker_version\":\"3.1.37\",\"application_token\":\"app-token\",\"success\":true,\"expires_on\":\"%@\",\"device_mode\":\"personal\",\"wpj_status\":\"notJoined\",\"correlation_id\":\"%@\",\"vt\":\"YES\",\"client_id\":\"my_client_id\",\"id_token\":\"%@\",\"access_token\":\"i-am-an-access-token\",\"sso_extension_mode\":\"full\"}", rawClientInfo, scopes, expiresOnString, correlationId, idTokenString],
          @"broker_error_code" : @(-50003), // MSALErrorServerDeclinedScopes
          @"broker_error_domain" : @"MSALErrorDomain",
          @"error_description" : @"Server returned less scopes than requested",
          @"error_metadata" : @"{}"
          };

        NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                                 redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                               encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];

        MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];

        [MSIDBrokerInteractiveController completeAcquireToken:brokerResponseURL
                                            sourceApplication:@"com.microsoft.azureauthenticator"
                                        brokerResponseHandler:brokerResponseHandler];
        return YES;
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireError) {

        XCTAssertNil(result);
        // Check result
        XCTAssertNil(result.accessToken);
        XCTAssertNil(result.rawIdToken);
        XCTAssertNil(result.account);
        XCTAssertNil(result.authority);
        XCTAssertNotNil(acquireError);

        // Check userInfo
        XCTAssertNotNil(acquireError.userInfo[MSIDDeclinedScopesKey]);
        XCTAssertEqualObjects([[NSArray arrayWithArray:acquireError.userInfo[MSIDDeclinedScopesKey]] componentsJoinedByString:@" "], @"not_granted_scope");
        XCTAssertNotNil(acquireError.userInfo[MSIDGrantedScopesKey]);
        XCTAssertEqualObjects([[NSArray arrayWithArray:acquireError.userInfo[MSIDGrantedScopesKey]] componentsJoinedByString:@" "], scopes);

        MSIDTokenResult *tokenResult = acquireError.userInfo[MSIDInvalidTokenResultKey];
        XCTAssertNotNil(tokenResult);
        XCTAssertEqualObjects(tokenResult.accessToken.accessToken, @"i-am-an-access-token");
        XCTAssertEqualObjects(tokenResult.refreshToken.refreshToken, @"i-am-a-refresh-token");
        XCTAssertEqualObjects(tokenResult.rawIdToken, idTokenString);

        // Check Telemetry event
        XCTAssertEqual([receivedEvents count], 4);
        NSDictionary *telemetryEvent = [receivedEvents[2] propertyMap];
        XCTAssertNotNil(telemetryEvent[@"start_time"]);
        XCTAssertNotNil(telemetryEvent[@"stop_time"]);
        XCTAssertEqualObjects(telemetryEvent[@"api_id"], @"api_broker_success");
        XCTAssertEqualObjects(telemetryEvent[@"event_name"], @"api_event");
        XCTAssertEqualObjects(telemetryEvent[@"extended_expires_on_setting"], @"yes");
        XCTAssertEqualObjects(telemetryEvent[@"is_successfull"], @"no");
        XCTAssertEqualObjects(telemetryEvent[@"request_id"], parameters.telemetryRequestId);
        XCTAssertEqualObjects(telemetryEvent[@"status"], @"failed");
        XCTAssertEqualObjects(telemetryEvent[@"login_hint"], @"d24dfead25359b0c562c8a02a6a0e6db8de4a8b235d56e122a75a8e1f2e473ee");
        XCTAssertEqualObjects(telemetryEvent[@"client_id"], @"my_client_id");
        XCTAssertEqualObjects(telemetryEvent[@"correlation_id"], parameters.correlationId.UUIDString);
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

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, __unused NSDictionary<NSString *,id> *options) {

        XCTAssertEqualObjects(url, brokerRequestURL);
        return NO;
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        // Check error
        XCTAssertEqualObjects(acquireTokenError.domain, MSIDErrorDomain);
        XCTAssertEqual(acquireTokenError.code, MSIDErrorInternal);
        XCTAssertEqualObjects(acquireTokenError.userInfo[MSIDErrorDescriptionKey], @"Failed to open broker URL. Application is active");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

}

- (void)testAcquireToken_whenFailedToLaunchBrokerThroughUniversalLink_andFallbackController_shouldFallback
{
    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey1"];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:nil];

    NSError *error = nil;
    MSIDTestLocalInteractiveController *fallbackController = [[MSIDTestLocalInteractiveController alloc] initWithRequestParameters:[MSIDTestParametersProvider testInteractiveParameters]
                                                                                                              tokenRequestProvider:provider
                                                                                                                fallbackController:nil
                                                                                                                             error:nil];
    fallbackController.acquireTokenResult = [self resultWithParameters:[self requestParameters]];
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:[self requestParameters]
                                                                                                                 tokenRequestProvider:provider
                                                                                                                   fallbackController:fallbackController
                                                                                                                                error:&error];

    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, __unused NSDictionary<NSString *,id> *options) {

        XCTAssertEqualObjects(url, brokerRequestURL);
        return NO;
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertEqual(fallbackController.acquireTokenCalledCount, 1);
        XCTAssertNotNil(result);
        XCTAssertNil(acquireTokenError);
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
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_broker_failure";

    NSDictionary *testResumeDictionary = @{@"test-resume-key1": @"test-resume-value2",
                                           @"test-resume-key2": @"test-resume-value2"};

    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey2"];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:testResumeDictionary];

    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider fallbackController:nil error:&error];

    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);

    NSError *testError = MSIDCreateError(MSIDErrorDomain, 123456789, @"Test broker error", @"broker_error", @"broker_sub_error", nil, parameters.correlationId, nil, YES);

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, __unused NSDictionary<NSString *,id> *options) {

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

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqual(acquireTokenError.code, 123456789);
        XCTAssertEqualObjects(acquireTokenError.domain, MSIDErrorDomain);
        XCTAssertEqualObjects(acquireTokenError.userInfo[MSIDErrorDescriptionKey], @"Test broker error");
        XCTAssertEqualObjects(acquireTokenError.userInfo[MSIDOAuthErrorKey], @"broker_error");
        XCTAssertEqualObjects(acquireTokenError.userInfo[MSIDOAuthSubErrorKey], @"broker_sub_error");

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
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
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

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, __unused NSDictionary<NSString *,id> *options) {

        XCTAssertEqualObjects(url, brokerRequestURL);

        NSDictionary *resumeDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
        XCTAssertEqualObjects(resumeDictionary, testResumeDictionary);

        MSIDBrokerInteractiveController *secondBrokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider fallbackController:nil error:nil];

        [secondBrokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {
            XCTAssertNotNil(acquireTokenError);
            XCTAssertEqual(acquireTokenError.code, MSIDErrorInteractiveSessionAlreadyRunning);
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

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNotNil(result);
        // Check result
        XCTAssertEqualObjects(result.accessToken, testResult.accessToken);
        XCTAssertEqualObjects(result.rawIdToken, testResult.rawIdToken);
        XCTAssertEqualObjects(result.account, testResult.account);
        XCTAssertEqualObjects(result.authority, testResult.authority);
        XCTAssertNil(acquireTokenError);

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
        XCTAssertEqualObjects(telemetryEvent[@"tenant_id"], DEFAULT_TEST_UTID);
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
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_broker_failure";

    NSError *testError = MSIDCreateError(MSIDErrorDomain, 1234567, @"Failed to create broker request", nil, nil, nil, nil, nil, YES);

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:testError testWebMSAuthResponse:nil brokerRequestURL:nil resumeDictionary:nil];

    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider fallbackController:nil error:&error];

    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqual(acquireTokenError.code, 1234567);
        XCTAssertEqualObjects(acquireTokenError.domain, MSIDErrorDomain);
        XCTAssertEqualObjects(acquireTokenError.userInfo[MSIDErrorDescriptionKey], @"Failed to create broker request");

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
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.telemetryApiId = @"api_broker_response_not_received";

    NSDictionary *testResumeDictionary = @{@"test-resume-key1": @"test-resume-value2",
                                           @"test-resume-key2": @"test-resume-value2"};

    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey4"];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:testResumeDictionary];

    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters tokenRequestProvider:provider fallbackController:nil error:&error];

    XCTAssertNotNil(brokerController);
    XCTAssertNil(error);

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, __unused NSDictionary<NSString *,id> *options) {

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

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        // Make sure completion is not called multiple times
        XCTAssertFalse(calledCompletion);
        calledCompletion = YES;

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqual(acquireTokenError.code, MSIDErrorBrokerResponseNotReceived);
        XCTAssertEqualObjects(acquireTokenError.domain, MSIDErrorDomain);

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
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
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

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, __unused NSDictionary<NSString *,id> *options) {

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

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable acquireTokenError) {

        // Make sure completion is not called multiple times
        XCTAssertFalse(calledCompletion);
        calledCompletion = YES;

        XCTAssertNil(result);
        XCTAssertNotNil(acquireTokenError);
        XCTAssertEqual(acquireTokenError.code, MSIDErrorBrokerResponseNotReceived);
        XCTAssertEqualObjects(acquireTokenError.domain, MSIDErrorDomain);

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
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
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

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, __unused NSDictionary<NSString *,id> *options) {

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

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable result, __unused NSError * _Nullable acquireTokenError) {

        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken, testResult.accessToken);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
#endif

#if !AD_BROKER
- (void)testAcquireToken_whenFailedToLaunchBrokerWhileAppIsInactive_andNoFallbackController_shouldErrorOutWithCorrectCode
{
    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey1"];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:nil];

    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:[self requestParameters]
                                                                                                                 tokenRequestProvider:provider
                                                                                                                   fallbackController:nil
                                                                                                                                error:&error];
    
    MSIDTestSwizzle *swizzle = [MSIDTestSwizzle instanceMethod:@selector(applicationState)
                              class:[UIApplication class]
                              block:(id)^(void)
    {
        return UIApplicationStateInactive;
    }];

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, __unused NSDictionary<NSString *,id> *options)
    {

        XCTAssertEqualObjects(url, brokerRequestURL);
        return NO;
    }];
    
    [[self.swizzleStacks objectForKey:self.name] addObject:swizzle];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Failed with inactive error code"];

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable __unused result, NSError * _Nullable acquireTokenError) {

        if (acquireTokenError.code == MSIDErrorBrokerAppIsInactive)
        {
            [expectation fulfill];
        }
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenFailedToLaunchBrokerWhileAppIsInBackground_andNoFallbackController_shouldErrorOutWithCorrectCode
{
    NSURL *brokerRequestURL = [NSURL URLWithString:@"https://contoso.com?broker=request_url&broker_key=mykey1"];

    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil testError:nil testWebMSAuthResponse:nil brokerRequestURL:brokerRequestURL resumeDictionary:nil];

    NSError *error = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:[self requestParameters]
                                                                                                                 tokenRequestProvider:provider
                                                                                                                   fallbackController:nil
                                                                                                                                error:&error];
    
    MSIDTestSwizzle *swizzle = [MSIDTestSwizzle instanceMethod:@selector(applicationState)
                              class:[UIApplication class]
                              block:(id)^(void)
    {
        return UIApplicationStateBackground;
    }];

    [MSIDApplicationTestUtil onOpenURL:^BOOL(NSURL *url, __unused NSDictionary<NSString *,id> *options)
    {

        XCTAssertEqualObjects(url, brokerRequestURL);
        return NO;
    }];
    
    [[self.swizzleStacks objectForKey:self.name] addObject:swizzle];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Failed with background error code"];

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponse:discoveryResponse];

    [brokerController acquireToken:^(MSIDTokenResult * _Nullable __unused result, NSError * _Nullable acquireTokenError) {

        if (acquireTokenError.code == MSIDErrorBrokerAppIsInBackground)
        {
            [expectation fulfill];
        }
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
#endif

@end
