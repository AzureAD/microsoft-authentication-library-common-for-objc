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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDWebviewFactory.h"
#import "MSIDBaseWebRequestConfiguration.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDPkce.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDDeviceId.h"
#import "MSIDWebviewResponse.h"
#import "MSIDWebOAuth2Response.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDAADAuthority.h"
#import "MSIDWebOAuth2AuthCodeResponse.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDSignoutWebRequestConfiguration.h"
#import "NSURL+MSIDTestUtil.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDAuthorizeWebRequestConfiguration.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDInteractiveTokenRequestParameters.h"

@interface MSIDWebviewFactoryTests : XCTestCase

@end

@implementation MSIDWebviewFactoryTests

#pragma mark - Webview (startURL)
- (void)testAuthorizationParametersFromRequestParameters_whenValidParams_shouldReturnExpectedAuthorizeParameters
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];

    parameters.extraAuthorizeURLQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2", @"eqp3" : @""};
    parameters.loginHint = @"fakeuser@contoso.com";
    
    NSString *requestState = @"state";
    MSIDPkce *pkce = [MSIDPkce new];

    NSDictionary *params = [factory authorizationParametersFromRequestParameters:parameters pkce:pkce requestState:requestState];
    
    NSMutableDictionary *expectedQPs = [NSMutableDictionary dictionaryWithDictionary:
                                        @{
                                          @"client_id" : DEFAULT_TEST_CLIENT_ID,
                                          @"redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
                                          @"response_type" : @"code",
                                          @"code_challenge_method" : @"S256",
                                          @"code_challenge" : pkce.codeChallenge,
                                          @"eqp1" : @"val1",
                                          @"eqp2" : @"val2",
                                          @"eqp3" : @"",
                                          @"login_hint" : @"fakeuser@contoso.com",
                                          @"state" : requestState.msidBase64UrlEncode,
                                          @"scope" : @"scope1",
                                          @"x-app-name" : [MSIDTestRequireValueSentinel new],
                                          @"x-app-ver" : [MSIDTestRequireValueSentinel new],
                                          @"x-client-Ver" : [MSIDTestRequireValueSentinel new],
                                          }];
    
    XCTAssertTrue([expectedQPs compareAndPrintDiff:params]);
}

- (void)testLogoutParametersFromRequestParameters_whenValidParameters_shouldReturnExpectedParams
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    
    NSString *requestState = @"state";

    NSDictionary *params = [factory logoutParametersFromRequestParameters:parameters requestState:requestState];
    
    NSMutableDictionary *expectedQPs = [NSMutableDictionary dictionaryWithDictionary:
                                        @{
                                          @"post_logout_redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
                                          @"state" : requestState.msidBase64UrlEncode,
                                          }];
    
    XCTAssertTrue([expectedQPs compareAndPrintDiff:params]);
}

- (void)testLogoutWebRequestConfiguration_whenNilParameters_shouldReturnNil
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    MSIDInteractiveRequestParameters *parameters = nil;
    MSIDSignoutWebRequestConfiguration *conf = [factory logoutWebRequestConfigurationWithRequestParameters:parameters];
    
    XCTAssertNil(conf);
}

- (void)testAuthorizeWebRequestConfiguration_whenNilParameters_shouldReturnNil
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    MSIDInteractiveTokenRequestParameters *parameters = nil;
    MSIDAuthorizeWebRequestConfiguration *conf = [factory authorizeWebRequestConfigurationWithRequestParameters:parameters];
    
    XCTAssertNil(conf);
}

- (void)testLogoutWebRequestConfiguration_whenValidParameters_noEndSessionURLPresent_shouldReturnNil
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    MSIDInteractiveRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.authority.metadata.endSessionEndpoint = nil;
    
    MSIDSignoutWebRequestConfiguration *conf = [factory logoutWebRequestConfigurationWithRequestParameters:parameters];
    
    XCTAssertNil(conf);
}

- (void)testAuthorizeWebRequestConfiguration_whenValidParameters_noAuthorizeURLPresent_shouldReturnNil
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.authority.metadata.authorizationEndpoint = nil;
    
    MSIDAuthorizeWebRequestConfiguration *conf = [factory authorizeWebRequestConfigurationWithRequestParameters:parameters];
    
    XCTAssertNil(conf);
}

- (void)testLogoutWebRequestConfiguration_whenValidParameters_shouldReturnNonNilWebConfiguration
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    MSIDInteractiveRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.authority.metadata.endSessionEndpoint = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com/logmeout"];
    
    MSIDSignoutWebRequestConfiguration *conf = [factory logoutWebRequestConfigurationWithRequestParameters:parameters];
    
    XCTAssertNotNil(conf);
    XCTAssertNotNil(conf.startURL);
    
    NSDictionary *expectedRequest = @{@"post_logout_redirect_uri": DEFAULT_TEST_REDIRECT_URI,
                                      @"state" : [MSIDTestIgnoreSentinel sentinel],
                                      };

    NSURL *actualURL = conf.startURL;

    NSString *expectedUrlString = [NSString stringWithFormat:@"https://login.microsoftonline.com/contoso.com/logmeout?%@", [expectedRequest msidURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
    
    XCTAssertEqualObjects(conf.endRedirectUrl, DEFAULT_TEST_REDIRECT_URI);
    XCTAssertFalse(conf.prefersEphemeralWebBrowserSession);
    XCTAssertFalse(conf.ignoreInvalidState);
    XCTAssertNotNil(conf.state);
}

- (void)testAuthorizeWebRequestConfiguration_whenValidParameters_shouldReturnNonNilWebConfiguration
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.authority.metadata.authorizationEndpoint = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com/authorizeme"];
    
    parameters.extraAuthorizeURLQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2", @"eqp3" : @""};
    parameters.loginHint = @"fakeuser@contoso.com";
    
    MSIDAuthorizeWebRequestConfiguration *conf = [factory authorizeWebRequestConfigurationWithRequestParameters:parameters];
    
    XCTAssertNotNil(conf);
    XCTAssertNotNil(conf.startURL);
    
    NSDictionary *expectedRequest = @{
                                    @"client_id" : DEFAULT_TEST_CLIENT_ID,
                                    @"redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
                                    @"response_type" : @"code",
                                    @"code_challenge_method" : @"S256",
                                    @"code_challenge" : [MSIDTestIgnoreSentinel sentinel],
                                    @"eqp1" : @"val1",
                                    @"eqp2" : @"val2",
                                    @"eqp3" : @"",
                                    @"login_hint" : @"fakeuser@contoso.com",
                                    @"state" : [MSIDTestIgnoreSentinel sentinel],
                                    @"scope" : @"scope1",
                                    @"x-app-name" : [MSIDTestRequireValueSentinel new],
                                    @"x-app-ver" : [MSIDTestRequireValueSentinel new],
                                    @"x-client-Ver" : [MSIDTestRequireValueSentinel new],
    };

    NSURL *actualURL = conf.startURL;
    XCTAssertTrue([expectedRequest compareAndPrintDiff:actualURL.msidQueryParameters]);
    
    NSURLComponents *actualURLComponents = [NSURLComponents componentsWithURL:actualURL resolvingAgainstBaseURL:NO];
    actualURLComponents.query = nil;
    actualURL = actualURLComponents.URL;
    
    NSURL *expectedURL = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com/authorizeme"];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
    
    XCTAssertEqualObjects(conf.endRedirectUrl, DEFAULT_TEST_REDIRECT_URI);
    XCTAssertFalse(conf.prefersEphemeralWebBrowserSession);
    XCTAssertFalse(conf.ignoreInvalidState);
    XCTAssertNotNil(conf.pkce);
    XCTAssertNotNil(conf.state);
}

#pragma mark - Webview (Response)
- (void)testResponseWithURL_whenNilURL_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"https://host"] requestState:nil ignoreInvalidState:NO context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
}


- (void)testResponseWithURL_whenRedirectUriSchemeNil_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:nil requestState:nil ignoreInvalidState:NO context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

- (void)testResponseWithURL_whenURLWithNoParams_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"https://host"] requestState:nil ignoreInvalidState:NO context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

- (void)testResponseWithURL_whenURLWithNoParamsWithPath_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"https://host/path"]  requestState:nil ignoreInvalidState:NO context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

- (void)testResponseWithURL_whenURLWithNoParamsWithQuestionMark_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"https://host?"] requestState:nil ignoreInvalidState:NO context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

- (void)testResponseWithURL_whenURLWithError_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"https://host/msal?error=iamanerror&error_description=evenmoreinfo"]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                                 context:nil
                                                   error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertTrue([response isKindOfClass:MSIDWebOAuth2Response.class]);
    
    MSIDWebOAuth2AuthCodeResponse *oauthResponse = ((MSIDWebOAuth2AuthCodeResponse *)response);
    XCTAssertNil(oauthResponse.authorizationCode);
    XCTAssertNotNil(oauthResponse.oauthError);
    
    XCTAssertEqual(oauthResponse.oauthError.code, MSIDErrorAuthorizationFailed);
    XCTAssertEqualObjects(oauthResponse.oauthError.userInfo[MSIDErrorDescriptionKey], @"evenmoreinfo");
    XCTAssertEqualObjects(oauthResponse.oauthError.userInfo[MSIDOAuthErrorKey], @"iamanerror");
}


- (void)testResponseWithURL_whenURLContainsCode_shouldReturnAADAuthResponse
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"redirecturi://somepayload?code=authcode"]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                                 context:nil
                                                   error:&error];

    XCTAssertTrue([response isKindOfClass:MSIDWebOAuth2Response.class]);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(((MSIDWebOAuth2AuthCodeResponse *)response).authorizationCode, @"authcode");
}

- (void)testResponseWithURL_whenURLStartsWithURNRedirectUri_shouldReturnAADAuthResponse
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"urn:ietf:wg:oauth:2.0:oob?code=authcode"]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                                 context:nil
                                                   error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebOAuth2Response.class]);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(((MSIDWebOAuth2AuthCodeResponse *)response).authorizationCode, @"authcode");
}

- (void)testResponseWithURL_whenStateVerificationFails_shouldReturnNilWithError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"redirecturi://consoto.com?code=authcode&state=wrongstate"]
                                            requestState:@"somerequeststate"
                                      ignoreInvalidState:NO
                                                 context:nil
                                                   error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}


- (void)testResponseWithURL_whenStateVerificationRequestStateIsNil_shouldReturnResponse
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"redirecturi://consoto.com?code=authcode"]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                                 context:nil
                                                   error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
}


- (void)testResponseWithURL_whenNotValidOAuthResponse_shouldReturnNilWithError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"redirecturi://consoto.com"]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                                 context:nil
                                                   error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

@end
