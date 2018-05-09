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
#import "MSIDOauth2Factory.h"
#import "MSIDTokenResponse.h"
#import "MSIDBaseToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDTestRequestParams.h"
#import "MSIDTestIdTokenUtil.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDAccount.h"

@interface MSIDOauth2FactoryTest : XCTestCase

@end

@implementation MSIDOauth2FactoryTest

#pragma mark - Token response

- (void)testTokenResponseFromJSON_whenNilJSON_shouldReturnError
{
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:nil context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testTokenResponseFromJSON_whenValidJSON_shouldReturnTokenResponse
{
    NSDictionary *tokenResponse = @{@"access_token": @"access token",
                                    @"refresh_token": @"refresh token"
                                    };

    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:tokenResponse context:nil error:&error];

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
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    NSError *error = nil;

    BOOL result = [factory verifyResponse:nil context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"processTokenResponse called without a response dictionary");
}

- (void)testVerifyResponse_whenOAuthError_shouldReturnError
{
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"} error:nil];

    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidGrant);
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
}

- (void)testVerifyResponse_whenNoAccessToken_shouldReturnError
{
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:@{@"refresh_token":@"fake_refresh_token",
                                                                                              @"client_info":rawClientInfo
                                                                                              }
                                                                                      error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Authentication response received without expected accessToken");
}

- (void)testVerifyResponse_whenValidResponseWithTokens_shouldReturnNoError
{
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                              @"refresh_token":@"fake_refresh_token",
                                                                                              @"client_info":rawClientInfo
                                                                                              }
                                                                                      error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);
}

#pragma mark - Tokens

- (void)testBaseTokenFromResponse_whenNilResponse_shouldReturnNil
{
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    MSIDBaseToken *result = [factory baseTokenFromResponse:nil request:[MSIDRequestParameters new]];

    XCTAssertNil(result);
}

- (void)testBaseTokenFromResponse_whenNilParams_shouldReturnNil
{
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    MSIDBaseToken *result = [factory baseTokenFromResponse:[MSIDTokenResponse new] request:nil];

    XCTAssertNil(result);
}

- (void)testBaseTokenFromResponse_whenOIDCTokenResponse_shouldReturnToken
{
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    MSIDTokenResponse *response = [MSIDTestTokenResponse defaultTokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                           username:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                            subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];

    MSIDRequestParameters *params = [MSIDTestRequestParams defaultParams];

    MSIDBaseToken *token = [factory baseTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    XCTAssertEqualObjects(token.uniqueUserId, DEFAULT_TEST_ID_TOKEN_SUBJECT);
    XCTAssertNil(token.clientInfo);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
}

- (void)testAccessTokenFromResponse_whenOIDCTokenResponse_shouldReturnToken
{
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    MSIDTokenResponse *response = [MSIDTestTokenResponse defaultTokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                           username:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                            subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];

    MSIDRequestParameters *params = [MSIDTestRequestParams defaultParams];

    MSIDAccessToken *token = [factory accessTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    XCTAssertEqualObjects(token.uniqueUserId, DEFAULT_TEST_ID_TOKEN_SUBJECT);
    XCTAssertNil(token.clientInfo);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.accessTokenType, @"Bearer");

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];

    XCTAssertEqualObjects(token.idToken, idToken);

    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil];

    XCTAssertEqualObjects(token.scopes, scopes);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testRefreshTokenFromResponse_whenOIDCTokenResponse_shouldReturnToken
{
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    MSIDTokenResponse *response = [MSIDTestTokenResponse defaultTokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                           username:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                            subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];

    MSIDRequestParameters *params = [MSIDTestRequestParams defaultParams];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    XCTAssertEqualObjects(token.uniqueUserId, DEFAULT_TEST_ID_TOKEN_SUBJECT);
    XCTAssertNil(token.clientInfo);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    XCTAssertEqualObjects(token.idToken, idToken);

    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
}

- (void)testLegacyTokenFromResponse_whenOIDCTokenResponse_shouldReturnToken
{
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    MSIDTokenResponse *response = [MSIDTestTokenResponse defaultTokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                           username:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                            subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];

    MSIDRequestParameters *params = [MSIDTestRequestParams defaultParams];

    MSIDLegacySingleResourceToken *token = [factory legacyTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    XCTAssertEqualObjects(token.uniqueUserId, DEFAULT_TEST_ID_TOKEN_SUBJECT);
    XCTAssertNil(token.clientInfo);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];

    XCTAssertEqualObjects(token.idToken, idToken);

    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil];

    XCTAssertEqualObjects(token.scopes, scopes);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testIDTokenFromResponse_whenOIDCTokenResponse_shouldReturnToken
{
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    MSIDTokenResponse *response = [MSIDTestTokenResponse defaultTokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                           username:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                            subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];

    MSIDRequestParameters *params = [MSIDTestRequestParams defaultParams];

    MSIDIdToken *token = [factory idTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    XCTAssertEqualObjects(token.uniqueUserId, DEFAULT_TEST_ID_TOKEN_SUBJECT);
    XCTAssertNil(token.clientInfo);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    XCTAssertEqualObjects(token.rawIdToken, idToken);
}

- (void)testBaseTokenFromResponse_whenOIDCTokenResponse_andAdditionalFields_shouldReturnTokenAndAdditionalFields
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"eric999" subject:@"subject" givenName:@"Eric" familyName:@"Cartman"];
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    NSDictionary *responseDict = @{@"access_token": @"at",
                                   @"token_type": @"Bearer",
                                   @"expires_in": @"xyz",
                                   @"refresh_token": @"rt",
                                   @"scope": @"user.read",
                                   @"id_token": idToken,
                                   @"additional_key1": @"additional_value1",
                                   @"additional_key2": @"additional_value2"
                                   };

    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:responseDict refreshToken:nil error:nil];
    MSIDRequestParameters *params = [MSIDTestRequestParams defaultParams];

    MSIDBaseToken *token = [factory baseTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    XCTAssertEqualObjects(token.uniqueUserId, @"subject");

    NSDictionary *expectedAdditionalInfo = @{@"additional_key1": @"additional_value1",
                                             @"additional_key2": @"additional_value2"};

    XCTAssertEqualObjects(token.additionalServerInfo, expectedAdditionalInfo);
}

- (void)testAccountFromResponse_whenOIDCTokenResponse_shouldInitAccountAndSetProperties
{
    MSIDOauth2Factory *factory = [MSIDOauth2Factory new];

    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"eric999" subject:@"subject" givenName:@"Eric" familyName:@"Cartman"];
    NSDictionary *json = @{@"id_token": idToken, @"client_info": base64String};
    MSIDRequestParameters *requestParameters =
    [[MSIDRequestParameters alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY msidUrl]
                                         redirectUri:@"redirect uri"
                                            clientId:@"client id"
                                              target:@"target"
                                       correlationId:[NSUUID UUID]];
    MSIDTokenResponse *tokenResponse = [[MSIDTokenResponse alloc] initWithJSONDictionary:json error:nil];

    MSIDAccount *account = [factory accountFromResponse:tokenResponse request:requestParameters];

    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"subject");
    XCTAssertEqualObjects(account.uniqueUserId, @"subject");
    XCTAssertNil(account.clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeOther);
    XCTAssertEqualObjects(account.username, @"eric999");
    XCTAssertEqualObjects(account.firstName, @"Eric");
    XCTAssertEqualObjects(account.lastName, @"Cartman");
    XCTAssertEqualObjects(account.authority.absoluteString, DEFAULT_TEST_AUTHORITY);
}

@end
