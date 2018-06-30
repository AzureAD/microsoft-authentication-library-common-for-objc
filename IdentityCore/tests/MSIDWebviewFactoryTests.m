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
- (void)testAuthorizationParametersFromConfiguration_withValidParams_shouldContainsConfiguration
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
    
    config.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
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


#pragma mark - Webview (Response)
- (void)testResponseWithURL_whenNilURL_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory responseWithURL:nil requestState:nil context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
}


- (void)testResponseWithURL_whenURLContainsCode_shouldReturnAADAuthResponse
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"redirecturi://somepayload?code=authcode"]
                                       requestState:nil
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
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"https://consoto.com?code=authcode&state=wrongstate"]
                                       requestState:@"somerequeststate"
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
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"https://consoto.com?code=authcode"]
                                       requestState:nil
                                            context:nil
                                              error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
}


- (void)testResponseWithURL_whenNotValidOAuthResponse_shouldReturnNilWithError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"https://consoto.com"]
                                       requestState:nil
                                            context:nil
                                              error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

#pragma mark - Webview (State verifier)
- (void)testVerifyRequestState_whenNoRequestState_shouldFail
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    NSError *error = nil;
    
    XCTAssertFalse([factory verifyRequestState:nil responseURL:[NSURL URLWithString:@"https://contoso?state=value"] error:&error]);
    XCTAssertNotNil(error);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"state"]);
}


- (void)testVerifyRequestState_whenStateReceivedMatches_shouldSucceed
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    NSError *error = nil;
    
    NSURL *urlWithEncodedState = [NSURL URLWithString:[NSString stringWithFormat:@"https://contoso?state=%@", @"value".msidBase64UrlEncode]];
    
    XCTAssertTrue([factory verifyRequestState:@"value" responseURL:urlWithEncodedState error:&error]);
    XCTAssertNil(error);
}


- (void)testVerifyRequestState_whenStateReceivedDoesNotMatch_shouldFail
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    NSError *error = nil;
    
    NSURL *urlWithEncodedState = [NSURL URLWithString:@"https://contoso?state=somevalue"];
    
    XCTAssertFalse([factory verifyRequestState:@"value" responseURL:urlWithEncodedState error:&error]);
    XCTAssertNotNil(error);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"state"]);
}

/*
 
 - (void)testInitWithParameters_whenValidParams_shouldInit
 {
 NSError *error = nil;
 
 __block NSUUID *correlationId = [NSUUID new];
 
 MSALRequestParameters *parameters = [MSALRequestParameters new];
 parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
 parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
 parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
 parameters.clientId = UNIT_TEST_CLIENT_ID;
 parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
 parameters.loginHint = @"fakeuser@contoso.com";
 parameters.correlationId = correlationId;
 
 MSALInteractiveRequest *request =
 [[MSALInteractiveRequest alloc] initWithParameters:parameters
 extraScopesToConsent:@[@"fakescope3"]
 behavior:MSALForceConsent
 tokenCache:nil
 error:&error];
 
 XCTAssertNotNil(request);
 XCTAssertNil(error);
 }
 
 - (void)testAuthorizationUri_whenValidParams_shouldContainQPs
 {
 NSError *error = nil;
 
 __block NSUUID *correlationId = [NSUUID new];
 
 MSALRequestParameters *parameters = [MSALRequestParameters new];
 parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
 parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
 parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
 parameters.clientId = UNIT_TEST_CLIENT_ID;
 parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
 parameters.loginHint = @"fakeuser@contoso.com";
 parameters.correlationId = correlationId;
 parameters.sliceParameters = @{ UT_SLICE_PARAMS_DICT };
 
 [MSALTestSwizzle classMethod:@selector(randomUrlSafeStringOfSize:)
 class:[NSString class]
 block:(id)^(id obj, NSUInteger size)
 {
 (void)obj;
 (void)size;
 return @"randomValue";
 }];
 
 MSALPkce *pkce = [MSALPkce new];
 
 MSALInteractiveRequest *request =
 [[MSALInteractiveRequest alloc] initWithParameters:parameters
 extraScopesToConsent:@[@"fakescope3"]
 behavior:MSALForceLogin
 tokenCache:nil
 error:&error];
 
 XCTAssertNotNil(request);
 XCTAssertNil(error);
 
 request.authority = [MSALTestAuthority AADAuthority:parameters.unvalidatedAuthority];
 
 NSURL *authorizationUrl = [request authorizationUrl];
 XCTAssertNotNil(authorizationUrl);
 XCTAssertEqualObjects(authorizationUrl.scheme, @"https");
 XCTAssertEqualObjects(authorizationUrl.msidHostWithPortIfNecessary, @"login.microsoftonline.com");
 XCTAssertEqualObjects(authorizationUrl.path, @"/common/oauth2/v2.0/authorize");
 
 NSDictionary *msalId = [MSIDDeviceId deviceId];
 NSDictionary *expectedQPs =
 @{
 @"x-client-Ver" : MSAL_VERSION_NSSTRING,
 #if TARGET_OS_IPHONE
 @"x-client-SKU" : @"MSAL.iOS",
 @"x-client-DM" : msalId[@"x-client-DM"],
 #else
 @"x-client-SKU" : @"MSAL.OSX",
 #endif
 @"x-client-OS" : msalId[@"x-client-OS"],
 @"x-client-CPU" : msalId[@"x-client-CPU"],
 @"return-client-request-id" : correlationId.UUIDString,
 @"state" : request.state,
 @"login_hint" : @"fakeuser@contoso.com",
 @"client_id" : UNIT_TEST_CLIENT_ID,
 @"prompt" : @"login",
 @"scope" : @"fakescope1 fakescope2 fakescope3 openid profile offline_access",
 @"eqp1" : @"val1",
 @"eqp2" : @"val2",
 @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
 @"response_type" : @"code",
 @"code_challenge": pkce.codeChallenge,
 @"code_challenge_method" : @"S256",
 UT_SLICE_PARAMS_DICT
 };
 NSDictionary *QPs = [NSDictionary msidURLFormDecode:authorizationUrl.query];
 XCTAssertTrue([expectedQPs compareAndPrintDiff:QPs]);
 }
 
 - (void)testAuthorizationUri_whenValidParamsWithUser_shouldContainDomainReqAndLoginReq
 {
 NSError *error = nil;
 
 __block NSUUID *correlationId = [NSUUID new];
 
 MSALRequestParameters *parameters = [MSALRequestParameters new];
 parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
 parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
 parameters.redirectUri = [NSURL URLWithString:UNIT_TEST_DEFAULT_REDIRECT_URI];
 parameters.clientId = UNIT_TEST_CLIENT_ID;
 parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
 parameters.correlationId = correlationId;
 
 MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"User"
 name:@"user@contoso.com"
 homeAccountId:@"1.1234-5678-90abcdefg"
 localAccountId:@"1"
 environment:@"login.microsoftonline.com"
 tenantId:@"1234-5678-90abcdefg"
 clientInfo:nil];
 
 parameters.account = account;
 [MSALTestSwizzle classMethod:@selector(randomUrlSafeStringOfSize:)
 class:[NSString class]
 block:(id)^(id obj, NSUInteger size)
 {
 (void)obj;
 (void)size;
 return @"randomValue";
 }];
 
 MSALPkce *pkce = [MSALPkce new];
 
 MSALInteractiveRequest *request =
 [[MSALInteractiveRequest alloc] initWithParameters:parameters
 extraScopesToConsent:@[@"fakescope3"]
 behavior:MSALForceLogin
 tokenCache:nil
 error:&error];
 
 XCTAssertNotNil(request);
 XCTAssertNil(error);
 
 request.authority = [MSALTestAuthority AADAuthority:parameters.unvalidatedAuthority];
 
 NSURL *authorizationUrl = [request authorizationUrl];
 XCTAssertNotNil(authorizationUrl);
 XCTAssertEqualObjects(authorizationUrl.scheme, @"https");
 XCTAssertEqualObjects(authorizationUrl.msidHostWithPortIfNecessary, @"login.microsoftonline.com");
 XCTAssertEqualObjects(authorizationUrl.path, @"/common/oauth2/v2.0/authorize");
 
 NSDictionary *msalId = [MSIDDeviceId deviceId];
 NSDictionary *expectedQPs =
 @{
 @"x-client-Ver" : MSAL_VERSION_NSSTRING,
 #if TARGET_OS_IPHONE
 @"x-client-SKU" : @"MSAL.iOS",
 @"x-client-DM" : msalId[@"x-client-DM"],
 #else
 @"x-client-SKU" : @"MSAL.OSX",
 #endif
 @"x-client-OS" : msalId[@"x-client-OS"],
 @"x-client-CPU" : msalId[@"x-client-CPU"],
 @"return-client-request-id" : correlationId.UUIDString,
 @"state" : request.state,
 @"login_hint" : @"User",
 @"login_req" : @"1",
 @"domain_req" : @"1234-5678-90abcdefg",
 @"client_id" : UNIT_TEST_CLIENT_ID,
 @"prompt" : @"login",
 @"scope" : @"fakescope1 fakescope2 fakescope3 openid profile offline_access",
 @"eqp1" : @"val1",
 @"eqp2" : @"val2",
 @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
 @"response_type" : @"code",
 @"code_challenge": pkce.codeChallenge,
 @"code_challenge_method" : @"S256",
 };
 NSDictionary *QPs = [NSDictionary msidURLFormDecode:authorizationUrl.query];
 XCTAssertTrue([expectedQPs compareAndPrintDiff:QPs]);
 }

 */

@end
