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
- (void)testStartURL_whenExplicitStartURL_shouldReturnStartURL
{

    MSIDWebviewConfiguration *config = [[MSIDWebviewConfiguration alloc] initWithAuthority:[NSURL URLWithString:DEFAULT_TEST_AUTHORITY]
                                                                     authorizationEndpoint:[NSURL URLWithString:DEFAULT_TEST_AUTHORIZATION_ENDPOINT]
                                                                               redirectUri:DEFAULT_TEST_REDIRECT_URI
                                                                                  clientId:DEFAULT_TEST_CLIENT_ID
                                                                                    target:DEFAULT_TEST_SCOPE
                                                                             correlationId:nil];
    config.explicitStartURL = [NSURL URLWithString:@"https://contoso.com"];

    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    NSURL *url = [factory startURLFromConfiguration:config requestState:@"state"];

    XCTAssertEqual(url, config.explicitStartURL);
}

- (void)testStartURL_whenValidParams_shouldContainQPs
{
    __block NSUUID *correlationId = [NSUUID new];

    MSIDPkce *pkce = [[MSIDPkce alloc] init];

    MSIDWebviewConfiguration *config = [[MSIDWebviewConfiguration alloc] initWithAuthority:[NSURL URLWithString:DEFAULT_TEST_AUTHORITY]
                                                                     authorizationEndpoint:[NSURL URLWithString:DEFAULT_TEST_AUTHORIZATION_ENDPOINT]
                                                                               redirectUri:DEFAULT_TEST_REDIRECT_URI
                                                                                  clientId:DEFAULT_TEST_CLIENT_ID
                                                                                    target:DEFAULT_TEST_SCOPE
                                                                             correlationId:correlationId];
    config.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    config.promptBehavior = @"login";
    config.claims = @"claim";
    config.pkce = pkce;
    config.utid = DEFAULT_TEST_UTID;
    config.uid = DEFAULT_TEST_UID;
    config.sliceParameters = DEFAULT_TEST_SLICE_PARAMS_DICT;
    config.loginHint = @"fakeuser@contoso.com";

    NSString *requestState = @"state";

    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];
    NSURL *url = [factory startURLFromConfiguration:config requestState:requestState];

    NSMutableDictionary *expectedQPs = [NSMutableDictionary dictionaryWithDictionary:
    @{
      @"client_id" : DEFAULT_TEST_CLIENT_ID,
      @"redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
      @"response_type" : @"code",
      @"code_challenge_method" : @"S256",
      @"code_challenge" : config.pkce.codeChallenge,
      @"eqp1" : @"val1",
      @"eqp2" : @"val2",
      @"claims" : @"claim",
      @"return-client-request-id" : correlationId.UUIDString,
      @"login_hint" : @"fakeuser@contoso.com",
      @"state" : requestState.msidBase64UrlEncode,
      @"scope" : MSID_OAUTH2_SCOPE_OPENID_VALUE
      }];
    [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
    [expectedQPs addEntriesFromDictionary:DEFAULT_TEST_SLICE_PARAMS_DICT];

    NSDictionary *QPs = [NSDictionary msidURLFormDecode:url.query];
    XCTAssertTrue([expectedQPs compareAndPrintDiff:QPs]);
    
    NSURL *authorizationEndpoint = [NSURL URLWithString:DEFAULT_TEST_AUTHORIZATION_ENDPOINT];
    XCTAssertEqualObjects(url.scheme, authorizationEndpoint.scheme);
    XCTAssertEqualObjects(url.host, authorizationEndpoint.host);
}


//#pragma mark - Webview (Response)
- (void)testResponseWithURL_whenNilURL_shouldReturnNilAndError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory responseWithURL:nil requestState:nil verifyState:NO context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
}


- (void)testResponseWithURL_whenOAuth2Response_shouldReturnAADAuthResponse
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"redirecturi://somepayload?code=authcode"]
                                       requestState:nil
                                        verifyState:NO
                                            context:nil
                                              error:&error];

    XCTAssertTrue([response isKindOfClass:MSIDWebOAuth2Response.class]);
    XCTAssertNil(error);
}


- (void)testResponseWithURL_whenStateVerificationFailsAndVerifyStateIsYES_shouldReturnNilWithError
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"https://consoto.com?code=authcode&state=wrongstate"]
                                       requestState:@"somerequeststate"
                                        verifyState:YES
                                            context:nil
                                              error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidState);
}


- (void)testResponseWithURL_whenStateVerificationFailsAndVerifyStateIsNO_shouldReturnResponse
{
    MSIDWebviewFactory *factory = [MSIDWebviewFactory new];

    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"https://consoto.com?code=authcode&state=wrongstate"]
                                       requestState:@"somerequeststate"
                                        verifyState:NO
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
                                        verifyState:NO
                                            context:nil
                                              error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

//#pragma mark - Webview (State verifier)
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

@end
