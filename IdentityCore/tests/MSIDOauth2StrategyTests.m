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
#import "MSIDOauth2Strategy.h"
#import "MSIDTokenResponse.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDOauth2StrategyTest : XCTestCase

@end

@implementation MSIDOauth2StrategyTest

#pragma mark - Token response

- (void)testTokenResponseFromJSON_whenNilJSON_shouldReturnError
{
    MSIDOauth2Strategy *strategy = [MSIDOauth2Strategy new];

    NSError *error = nil;
    MSIDTokenResponse *response = [strategy tokenResponseFromJSON:nil context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testTokenResponseFromJSON_whenValidJSON_shouldReturnTokenResponse
{
    NSDictionary *tokenResponse = @{@"access_token": @"access token",
                                    @"refresh_token": @"refresh token"
                                    };

    MSIDOauth2Strategy *strategy = [MSIDOauth2Strategy new];

    NSError *error = nil;
    MSIDTokenResponse *response = [strategy tokenResponseFromJSON:tokenResponse context:nil error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    BOOL expectedClass = [response isKindOfClass:[MSIDTokenResponse class]];
    XCTAssertTrue(expectedClass);
    XCTAssertEqualObjects(response.accessToken, @"access token");
    XCTAssertEqualObjects(response.refreshToken, @"refresh token");
}

#pragma mark - Verify response

- (void)testVerifyResponse_whenNilRespose_shouldReturnError
{
    MSIDOauth2Strategy *strategy = [MSIDOauth2Strategy new];

    NSError *error = nil;

    BOOL result = [strategy verifyResponse:nil context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"processTokenResponse called without a response dictionary");
}

- (void)testVerifyResponse_whenOAuthError_shouldReturnError
{
    MSIDOauth2Strategy *strategy = [MSIDOauth2Strategy new];

    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"} error:nil];

    NSError *error = nil;
    BOOL result = [strategy verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerOauth);
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
}

- (void)testVerifyResponse_whenNoAccessToken_shouldReturnError
{
    MSIDOauth2Strategy *strategy = [MSIDOauth2Strategy new];

    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:@{@"refresh_token":@"fake_refresh_token",
                                                                                              @"client_info":rawClientInfo
                                                                                              }
                                                                                      error:nil];
    NSError *error = nil;
    BOOL result = [strategy verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Authentication response received without expected accessToken");
}

- (void)testVerifyResponse_whenValidResponseWithTokens_shouldReturnNoError
{
    MSIDOauth2Strategy *strategy = [MSIDOauth2Strategy new];

    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                              @"refresh_token":@"fake_refresh_token",
                                                                                              @"client_info":rawClientInfo
                                                                                              }
                                                                                      error:nil];
    NSError *error = nil;
    BOOL result = [strategy verifyResponse:response context:nil error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);
}

@end
