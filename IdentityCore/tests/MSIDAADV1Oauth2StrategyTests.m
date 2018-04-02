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
#import "MSIDAADV1Oauth2Strategy.h"
#import "MSIDAADV1TokenResponse.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDRefreshToken.h"

@interface MSIDAADV1Oauth2StrategyTests : XCTestCase

@end

@implementation MSIDAADV1Oauth2StrategyTests

#pragma mark - Token response

- (void)testTokenResponseFromJSON_whenNilJSON_shouldReturnError
{
    MSIDAADV1Oauth2Strategy *strategy = [MSIDAADV1Oauth2Strategy new];

    NSError *error = nil;
    MSIDTokenResponse *response = [strategy tokenResponseFromJSON:nil context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testTokenResponseFromJSON_whenValidJSON_shouldReturnAADTokenResponse
{
    NSDictionary *tokenResponse = @{@"access_token": @"access token",
                                    @"refresh_token": @"refresh token"
                                    };

    MSIDAADV1Oauth2Strategy *strategy = [MSIDAADV1Oauth2Strategy new];

    NSError *error = nil;
    MSIDTokenResponse *response = [strategy tokenResponseFromJSON:tokenResponse context:nil error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    BOOL expectedClass = [response isKindOfClass:[MSIDAADV1TokenResponse class]];
    XCTAssertTrue(expectedClass);
    XCTAssertEqualObjects(response.accessToken, @"access token");
    XCTAssertEqualObjects(response.refreshToken, @"refresh token");
}

- (void)testTokenResponseFromJSON_whenValidJSON_andRefreshToken_shouldReturnAADTokenResponseWithAdditionalFields
{
    NSDictionary *tokenResponse = @{@"access_token": @"access token",
                                    @"refresh_token": @"refresh token"
                                    };

    MSIDAADV1Oauth2Strategy *strategy = [MSIDAADV1Oauth2Strategy new];

    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    refreshToken.idToken = @"id token";

    NSError *error = nil;
    MSIDTokenResponse *response = [strategy tokenResponseFromJSON:tokenResponse refreshToken:refreshToken context:nil error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    BOOL expectedClass = [response isKindOfClass:[MSIDAADV1TokenResponse class]];
    XCTAssertTrue(expectedClass);
    XCTAssertEqualObjects(response.accessToken, @"access token");
    XCTAssertEqualObjects(response.refreshToken, @"refresh token");
    XCTAssertEqualObjects(response.idToken, @"id token");
}

#pragma mark - Verify response

- (void)testVerifyResponse_whenWrongResponseProvided_shouldReturnError
{
    MSIDAADV1Oauth2Strategy *strategy = [MSIDAADV1Oauth2Strategy new];
    MSIDTokenResponse *response = [MSIDTokenResponse new];

    NSError *error = nil;
    BOOL result = [strategy verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testVerifyResponse_whenValidResponseWithTokens_shouldReturnNoError
{
    MSIDAADV1Oauth2Strategy *strategy = [MSIDAADV1Oauth2Strategy new];

    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                            @"refresh_token":@"fake_refresh_token",
                                                                                            @"client_info":rawClientInfo
                                                                                            }
                                                                                    error:nil];
    NSError *error = nil;
    BOOL result = [strategy verifyResponse:response context:nil error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testVerifyResponse_whenOAuthErrorViaRefreshToken_shouldReturnError
{
    MSIDAADV1Oauth2Strategy *strategy = [MSIDAADV1Oauth2Strategy new];

    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"}
                                                                                      error:nil];
    NSError *error = nil;
    BOOL result = [strategy verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerRefreshTokenRejected);
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
}

- (void)testVerifyResponse_whenOAuthErrorViaAuthCode_shouldReturnError
{
    MSIDAADV1Oauth2Strategy *strategy = [MSIDAADV1Oauth2Strategy new];

    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"}
                                                                                      error:nil];
    NSError *error = nil;
    BOOL result = [strategy verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerOauth);
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
}

@end
