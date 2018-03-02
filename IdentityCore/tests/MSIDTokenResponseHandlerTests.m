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
#import "MSIDAADTokenResponse.h"
#import "MSIDTokenResponseHandler.h"
#import "MSIDError.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDTokenResponseHandlerTests : XCTestCase

@end

@implementation MSIDTokenResponseHandlerTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testVerifyResponse_whenNilRespose_shouldReturnError
{
    MSIDTokenResponse *response = nil;
    NSError *error = nil;
    BOOL isToken = [MSIDTokenResponseHandler verifyResponse:response
                                           fromRefreshToken:YES
                                                    context:nil
                                                      error:&error];
    
    XCTAssertFalse(isToken);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"processTokenResponse called without a response dictionary");
}

- (void)testVerifyResponse_whenV1OAuthErrorViaRefreshToken_shouldReturnError
{
    MSIDAADTokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"}
                                                                                      error:nil];
    NSError *error = nil;
    BOOL isToken = [MSIDTokenResponseHandler verifyResponse:response
                                           fromRefreshToken:YES
                                                    context:nil
                                                      error:&error];
    
    XCTAssertFalse(isToken);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerRefreshTokenRejected);
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
}

- (void)testVerifyResponse_whenV1OAuthErrorViaAuthCode_shouldReturnError
{
    MSIDAADTokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"}
                                                                                      error:nil];
    NSError *error = nil;
    BOOL isToken = [MSIDTokenResponseHandler verifyResponse:response
                                           fromRefreshToken:NO
                                                    context:nil
                                                      error:&error];
    
    XCTAssertFalse(isToken);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerOauth);
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
}

- (void)testVerifyResponse_whenV2OAuthErrorViaAuthCode_shouldReturnError
{
    MSIDAADTokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"}
                                                                                      error:nil];
    NSError *error = nil;
    BOOL isToken = [MSIDTokenResponseHandler verifyResponse:response
                                           fromRefreshToken:NO
                                                    context:nil
                                                      error:&error];
    
    XCTAssertFalse(isToken);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
}

- (void)testVerifyResponse_whenNoAccessToken_shouldReturnError
{
    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDAADTokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"refresh_token":@"fake_refresh_token",
                                                                                              @"client_info":rawClientInfo
                                                                                              }
                                                                                      error:nil];
    NSError *error = nil;
    BOOL isToken = [MSIDTokenResponseHandler verifyResponse:response
                                           fromRefreshToken:NO
                                                    context:nil
                                                      error:&error];
    
    XCTAssertFalse(isToken);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Authentication response received without expected accessToken");
}

- (void)testVerifyResponse_whenNoUserInfo_shouldReturnError
{
    MSIDAADTokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                              @"refresh_token":@"fake_refresh_token"}
                                                                                      error:nil];
    NSError *error = nil;
    BOOL isToken = [MSIDTokenResponseHandler verifyResponse:response
                                           fromRefreshToken:NO
                                                    context:nil
                                                      error:&error];
    
    XCTAssertFalse(isToken);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Client info was not returned in the server response");
}

- (void)testVerifyResponse_whenValidResponseWithTokens_shouldReturnNoError
{
    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDAADTokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                              @"refresh_token":@"fake_refresh_token",
                                                                                              @"client_info":rawClientInfo
                                                                                              }
                                                                                      error:nil];
    NSError *error = nil;
    BOOL isToken = [MSIDTokenResponseHandler verifyResponse:response
                                           fromRefreshToken:NO
                                                    context:nil
                                                      error:&error];
    
    XCTAssertTrue(isToken);
    XCTAssertNil(error);
}

@end
