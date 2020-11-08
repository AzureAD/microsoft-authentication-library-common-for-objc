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
#import "MSIDTestParametersProvider.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDOIDCSignoutRequest.h"
#import "MSIDTestSwizzle.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDTestURLSession.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDInteractiveTokenRequestParameters.h"

@interface MSIDOIDCSignoutRequestTests : XCTestCase

@end

@implementation MSIDOIDCSignoutRequestTests

- (void)setUp
{
    [super setUp];
    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:@"v2.0" forKey:@"aadApiVersion"];
}

- (void)tearDown
{
    [[MSIDAadAuthorityCache sharedInstance] removeAllObjects];
    [[MSIDAuthority openIdConfigurationCache] removeAllObjects];
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:nil forKey:@"aadApiVersion"];
    [super tearDown];
}

- (void)testLogoutRequest_whenLogoutSucceeded_shouldReturnSuccessNilError
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"fakeuser@contoso.com" homeAccountId:@"uid.utid"];
    parameters.webviewType = MSIDWebviewTypeWKWebView;
    
    MSIDOIDCSignoutRequest *logoutRequest = [[MSIDOIDCSignoutRequest alloc] initWithRequestParameters:parameters oauthFactory:[MSIDAADV2Oauth2Factory new]];
    XCTAssertNotNil(logoutRequest);

    // Swizzle out the main entry point for WebUI, WebUI is tested in its own component tests
    [MSIDTestSwizzle classMethod:@selector(startSessionWithWebView:oauth2Factory:configuration:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(
                              __unused id obj,
                              __unused NSObject<MSIDWebviewInteracting> *webview,
                              __unused MSIDOauth2Factory *oauth2Factory,
                              MSIDBaseWebRequestConfiguration *configuration,
                              __unused id<MSIDRequestContext> context,
                              MSIDWebviewAuthCompletionHandler completionHandler) {
         NSString *responseString = [NSString stringWithFormat:@"x-msauth-test://com.microsoft.testapp?state=%@", configuration.state];

         MSIDWebOAuth2Response *oauthResponse = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:responseString]
                                                                                   context:nil error:nil];
         completionHandler(oauthResponse, nil);
     }];

    NSString *wwAuthority = @"https://login.microsoftonline.com/common";

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:wwAuthority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *wwOidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:wwAuthority];
    [MSIDTestURLSession addResponse:wwOidcResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Run request."];
    
    [logoutRequest executeRequestWithCompletion:^(BOOL success, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertTrue(success);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testLogoutRequest_whenLogoutFailedWithMismatchedState_shouldReturnFailureAndFillError
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"fakeuser@contoso.com" homeAccountId:@"uid.utid"];
    parameters.authority.metadata.authorizationEndpoint = [NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/authorize"];
    parameters.webviewType = MSIDWebviewTypeWKWebView;
    
    MSIDOIDCSignoutRequest *logoutRequest = [[MSIDOIDCSignoutRequest alloc] initWithRequestParameters:parameters oauthFactory:[MSIDAADV2Oauth2Factory new]];
    XCTAssertNotNil(logoutRequest);

    // Swizzle out the main entry point for WebUI, WebUI is tested in its own component tests
    [MSIDTestSwizzle classMethod:@selector(startSessionWithWebView:oauth2Factory:configuration:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(
                                __unused id obj,
                                __unused NSObject<MSIDWebviewInteracting> *webview,
                                __unused MSIDOauth2Factory *oauth2Factory,
                                MSIDBaseWebRequestConfiguration *configuration,
                                __unused id<MSIDRequestContext> context,
                                MSIDWebviewAuthCompletionHandler completionHandler)
    {
         NSString *responseString = @"x-msauth-test://com.microsoft.testapp?state=fakestate";

         NSError *stateError;
         MSIDWebOAuth2Response *oauthResponse = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:responseString] requestState:configuration.state ignoreInvalidState:NO context:nil error:&stateError];
         completionHandler(oauthResponse, stateError);
     }];

    NSString *wwAuthority = @"https://login.microsoftonline.com/common";

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:wwAuthority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *wwOidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:wwAuthority];
    [MSIDTestURLSession addResponse:wwOidcResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Run request."];
    
    [logoutRequest executeRequestWithCompletion:^(BOOL success, NSError * _Nullable error) {
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDOAuthErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
        XCTAssertFalse(success);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
