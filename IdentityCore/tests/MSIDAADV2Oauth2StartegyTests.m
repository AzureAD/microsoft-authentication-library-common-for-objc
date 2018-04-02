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
#import "MSIDAADV2Oauth2Strategy.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAADV1TokenResponse.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDBaseToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDTestRequestParams.h"
#import "MSIDTestIdTokenUtil.h"

@interface MSIDAADV2Oauth2StartegyTests : XCTestCase

@end

@implementation MSIDAADV2Oauth2StartegyTests

#pragma mark - Token response

- (void)testTokenResponseFromJSON_whenNilJSON_shouldReturnError
{
    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];

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

    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];

    NSError *error = nil;
    MSIDTokenResponse *response = [strategy tokenResponseFromJSON:tokenResponse context:nil error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    BOOL expectedClass = [response isKindOfClass:[MSIDAADV2TokenResponse class]];
    XCTAssertTrue(expectedClass);
    XCTAssertEqualObjects(response.accessToken, @"access token");
    XCTAssertEqualObjects(response.refreshToken, @"refresh token");
}

- (void)testTokenResponseFromJSON_whenValidJSON_andRefreshToken_shouldReturnAADTokenResponseWithAdditionalFields
{
    NSDictionary *tokenResponse = @{@"access_token": @"access token",
                                    @"refresh_token": @"refresh token"
                                    };

    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];

    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    refreshToken.idToken = @"id token";

    NSError *error = nil;
    MSIDTokenResponse *response = [strategy tokenResponseFromJSON:tokenResponse refreshToken:refreshToken context:nil error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    BOOL expectedClass = [response isKindOfClass:[MSIDAADV2TokenResponse class]];
    XCTAssertTrue(expectedClass);
    XCTAssertEqualObjects(response.accessToken, @"access token");
    XCTAssertEqualObjects(response.refreshToken, @"refresh token");
    XCTAssertEqualObjects(response.idToken, @"id token");
}

#pragma mark - Verify response

- (void)testVerifyResponse_whenWrongResponseProvided_shouldReturnError
{
    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];
    MSIDAADV1TokenResponse *response = [MSIDAADV1TokenResponse new];

    NSError *error = nil;
    BOOL result = [strategy verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testVerifyResponse_whenValidResponseWithTokens_shouldReturnNoError
{
    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];

    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                                @"refresh_token":@"fake_refresh_token",
                                                                                                @"client_info":rawClientInfo
                                                                                                }
                                                                                        error:nil];
    NSError *error = nil;
    BOOL result = [strategy verifyResponse:response context:nil error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testVerifyResponse_whenOAuthErrorViaAuthCode_shouldReturnError
{
    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];

    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"}
                                                                                      error:nil];
    NSError *error = nil;
    BOOL result = [strategy verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidGrant);
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
}

- (void)testVerifyResponse_whenNoClientInfo_shouldReturnError
{
    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];

    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                                @"refresh_token":@"fake_refresh_token"}
                                                                                        error:nil];
    NSError *error = nil;
    BOOL result = [strategy verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Client info was not returned in the server response");
}

#pragma mark - Tokens

- (void)testBaseTokenFromResponse_whenAADV2TokenResponse_shouldReturnToken
{
    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];

    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v2DefaultParams];

    MSIDBaseToken *token = [strategy baseTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, [NSURL URLWithString:@"https://login.microsoftonline.com/1234-5678-90abcdefg"]);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];

    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
}

- (void)testAccessTokenFromResponse_whenAADV2TokenResponse_shouldReturnToken
{
    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];

    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v2DefaultParams];

    MSIDAccessToken *token = [strategy accessTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, [NSURL URLWithString:@"https://login.microsoftonline.com/1234-5678-90abcdefg"]);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];

    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.accessTokenType, @"Bearer");

    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);

    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];

    XCTAssertEqualObjects(token.idToken, idToken);

    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil];

    XCTAssertEqualObjects(token.scopes, scopes);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testRefreshTokenFromResponse_whenAADV2TokenResponse_shouldReturnToken
{
    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];

    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v2DefaultParams];

    MSIDRefreshToken *token = [strategy refreshTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, [NSURL URLWithString:@"https://login.microsoftonline.com/1234-5678-90abcdefg"]);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];

    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);

    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];

    XCTAssertEqualObjects(token.idToken, idToken);

    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
}

- (void)testIDTokenFromResponse_whenAADV2TokenResponse_shouldReturnToken
{
    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];

    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v2DefaultParams];

    MSIDIdToken *token = [strategy idTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, [NSURL URLWithString:@"https://login.microsoftonline.com/1234-5678-90abcdefg"]);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];

    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);

    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];
    XCTAssertEqualObjects(token.rawIdToken, idToken);
}

- (void)testLegacyTokenFromResponse_whenAADV2TokenResponse_shouldReturnToken
{
    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];

    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v2DefaultParams];

    MSIDLegacySingleResourceToken *token = [strategy legacyTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, [NSURL URLWithString:@"https://login.microsoftonline.com/1234-5678-90abcdefg"]);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];

    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);

    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);

    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];

    XCTAssertEqualObjects(token.idToken, idToken);

    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil];

    XCTAssertEqualObjects(token.scopes, scopes);
    XCTAssertNotNil(token.expiresOn);
}

@end
