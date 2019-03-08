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
#import "MSIDWebviewConfiguration.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDPkce.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDDeviceId.h"
#import "MSIDWebviewResponse.h"
#import "MSIDWebOAuth2Response.h"

@interface MSIDWebviewFactoryTests : XCTestCase

@end

@implementation MSIDWebviewFactoryTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


#pragma mark - Webview (startURL)
- (void)testAuthorizationParametersFromConfiguration_whenValidParams_shouldContainsConfiguration
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    __block NSUUID *correlationId = [NSUUID new];
    MSIDWebviewConfiguration *config = [[MSIDWebviewConfiguration alloc] initWithAuthorizationEndpoint:[NSURL URLWithString:DEFAULT_TEST_AUTHORIZATION_ENDPOINT]
                                                                                           redirectUri:DEFAULT_TEST_REDIRECT_URI
                                                                                              clientId:DEFAULT_TEST_CLIENT_ID
                                                                                              resource:nil
                                                                                                scopes:[NSOrderedSet orderedSetWithObjects:@"scope1", nil]
                                                                                         correlationId:correlationId
                                                                                            enablePkce:YES];
    
    config.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2", @"eqp3" : @""};
    config.loginHint = @"fakeuser@contoso.com";
    
    NSString *requestState = @"state";

    NSDictionary *params = [factory authorizationParametersFromConfiguration:config requestState:requestState];
    
    NSMutableDictionary *expectedQPs = [NSMutableDictionary dictionaryWithDictionary:
                                        @{
                                          @"client_id" : DEFAULT_TEST_CLIENT_ID,
                                          @"redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
                                          @"response_type" : @"code",
                                          @"code_challenge_method" : @"S256",
                                          @"code_challenge" : config.pkce.codeChallenge,
                                          @"eqp1" : @"val1",
                                          @"eqp2" : @"val2",
                                          @"eqp3" : @"",
                                          @"login_hint" : @"fakeuser@contoso.com",
                                          @"state" : requestState.msidBase64UrlEncode,
                                          @"scope" : @"scope1"
                                          }];
    
    XCTAssertTrue([expectedQPs compareAndPrintDiff:params]);
}


- (void)testStartURL_whenExplicitStartURL_shouldReturnStartURL
{

    MSIDWebviewConfiguration *config = [[MSIDWebviewConfiguration alloc] initWithAuthorizationEndpoint:[NSURL URLWithString:DEFAULT_TEST_AUTHORIZATION_ENDPOINT]
                                                                                           redirectUri:DEFAULT_TEST_REDIRECT_URI
                                                                                              clientId:DEFAULT_TEST_CLIENT_ID
                                                                                              resource:nil
                                                                                                scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                                         correlationId:nil
                                                                                            enablePkce:NO];
                                        
                                        
    config.explicitStartURL = [NSURL URLWithString:@"https://contoso.com"];

    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    NSURL *url = [factory startURLFromConfiguration:config requestState:@"state"];

    XCTAssertEqual(url, config.explicitStartURL);
}


- (void)testStartURLFromConfiguration_whenNilConfiguration_shouldReturnNil
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    NSURL *url = [factory startURLFromConfiguration:nil requestState:nil];
    
    XCTAssertNil(url);
}

- (void)testStartURLFromConfiguration_whenAuthorizationEndpoint_shouldHaveMatchingSchemeAndHost
{
    MSIDWebviewConfiguration *config = [[MSIDWebviewConfiguration alloc] initWithAuthorizationEndpoint:[NSURL URLWithString:@"https://contoso.com/paths"]
                                                                                           redirectUri:DEFAULT_TEST_REDIRECT_URI
                                                                                              clientId:DEFAULT_TEST_CLIENT_ID
                                                                                              resource:nil
                                                                                                scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                                         correlationId:nil
                                                                                            enablePkce:YES];

    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    NSURL *url = [factory startURLFromConfiguration:config requestState:@"state"];

    XCTAssertEqualObjects(url.scheme, @"https");
    XCTAssertEqualObjects(url.host, @"contoso.com");
}

- (void)testStartURLFromConfiguration_whenExtraQueryParameters_shouldHaveQueryParams
{
    MSIDWebviewConfiguration *config = [[MSIDWebviewConfiguration alloc] initWithAuthorizationEndpoint:[NSURL URLWithString:@"https://contoso.com/paths"]
                                                                                           redirectUri:DEFAULT_TEST_REDIRECT_URI
                                                                                              clientId:DEFAULT_TEST_CLIENT_ID
                                                                                              resource:nil
                                                                                                scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                                         correlationId:nil
                                                                                            enablePkce:YES];
    config.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2", @"eqp3" : @""};
    
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    NSURL *url = [factory startURLFromConfiguration:config requestState:@"state"];
    
    XCTAssertEqualObjects(url.scheme, @"https");
    XCTAssertEqualObjects(url.host, @"contoso.com");
    XCTAssertTrue([url.query containsString:@"eqp1=val1"]);
    XCTAssertTrue([url.query containsString:@"eqp2=val2"]);
    XCTAssertTrue([url.query containsString:@"eqp3&"]);
}

#pragma mark - Webview (Response)
- (void)testResponseWithURL_whenNilURL_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"https://host"] requestState:nil ignoreInvalidState:NO context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
}


- (void)testResponseWithURL_whenRedirectUriSchemeNil_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory responseWithURL:nil requestState:nil ignoreInvalidState:NO context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
}



- (void)testResponseWithURL_whenURLWithNoParams_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"https://host"] requestState:nil ignoreInvalidState:NO context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

- (void)testResponseWithURL_whenURLWithNoParamsWithPath_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"https://host/path"]  requestState:nil ignoreInvalidState:NO context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

- (void)testResponseWithURL_whenURLWithNoParamsWithQuestionMark_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"https://host?"] requestState:nil ignoreInvalidState:NO context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

- (void)testResponseWithURL_whenURLWithError_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"https://host/msal?error=iamanerror&error_description=evenmoreinfo"]
                                       requestState:nil
                        ignoreInvalidState:NO
                                            context:nil
                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertTrue([response isKindOfClass:MSIDWebOAuth2Response.class]);
    
    MSIDWebOAuth2Response *oauthResponse = ((MSIDWebOAuth2Response *)response);
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
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"redirecturi://somepayload?code=authcode"]
                                       requestState:nil
                        ignoreInvalidState:NO
                                            context:nil
                                              error:&error];

    XCTAssertTrue([response isKindOfClass:MSIDWebOAuth2Response.class]);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(((MSIDWebOAuth2Response *)response).authorizationCode, @"authcode");
}

- (void)testResponseWithURL_whenURLStartsWithURNRedirectUri_shouldReturnAADAuthResponse
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"urn:ietf:wg:oauth:2.0:oob?code=authcode"]
                                       requestState:nil
                                 ignoreInvalidState:NO
                                            context:nil
                                              error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebOAuth2Response.class]);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(((MSIDWebOAuth2Response *)response).authorizationCode, @"authcode");
}

- (void)testResponseWithURL_whenStateVerificationFails_shouldReturnNilWithError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"redirecturi://consoto.com?code=authcode&state=wrongstate"]
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
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"redirecturi://consoto.com?code=authcode"]
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
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"redirecturi://consoto.com"]
                                       requestState:nil
                        ignoreInvalidState:NO
                                            context:nil
                                              error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

@end
