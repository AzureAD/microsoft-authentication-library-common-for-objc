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
#import "MSIDAADV1Oauth2Factory.h"
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
#import "MSIDAccount.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDLegacyRefreshToken.h"

@interface MSIDAADV1Oauth2FactoryTests : XCTestCase

@end

@implementation MSIDAADV1Oauth2FactoryTests

#pragma mark - Token response

- (void)testTokenResponseFromJSON_whenNilJSON_shouldReturnError
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:nil context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testTokenResponseFromJSON_whenValidJSON_shouldReturnAADTokenResponse
{
    NSDictionary *tokenResponse = @{@"access_token": @"access token",
                                    @"refresh_token": @"refresh token"
                                    };

    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:tokenResponse context:nil error:&error];

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

    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];

    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:tokenResponse refreshToken:refreshToken context:nil error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    BOOL expectedClass = [response isKindOfClass:[MSIDAADV1TokenResponse class]];
    XCTAssertTrue(expectedClass);
    XCTAssertEqualObjects(response.accessToken, @"access token");
    XCTAssertEqualObjects(response.refreshToken, @"refresh token");
}

#pragma mark - Verify response

- (void)testVerifyResponse_whenWrongResponseProvided_shouldReturnError
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDTokenResponse *response = [MSIDTokenResponse new];

    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testVerifyResponse_whenValidResponseWithTokens_shouldReturnNoError
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                            @"refresh_token":@"fake_refresh_token",
                                                                                            @"client_info":rawClientInfo
                                                                                            }
                                                                                    error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testVerifyResponse_whenOAuthErrorViaRefreshToken_shouldReturnError
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"}
                                                                                      error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response fromRefreshToken:YES context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerRefreshTokenRejected);
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
}

- (void)testVerifyResponse_whenOAuthErrorViaAuthCode_shouldReturnError
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"}
                                                                                      error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerOauth);
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
}

#pragma mark - Tokens

- (void)testBaseTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];

    MSIDBaseToken *token = [factory baseTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];

    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
}

- (void)testAccessTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];

    MSIDAccessToken *token = [factory accessTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];

    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);

    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.resource, DEFAULT_TEST_RESOURCE);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testRefreshTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];

    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertNil(token.familyId);
}

- (void)testRefreshTokenFromResponse_whenWrongTokenResponseType_shouldReturnNil
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADTokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response request:params];
    XCTAssertNil(token);
}

- (void)testAccountFromTokenFromResponse_whenWrongTokenResponseType_shouldReturnNil
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADTokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];

    MSIDAccount *account = [factory accountFromResponse:response request:params];
    XCTAssertNil(account);
}

- (void)testRefreshTokenFromResponse_whenSingleResourceToken_shouldReturnNil
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 rt:DEFAULT_TEST_REFRESH_TOKEN
                                                                           resource:nil
                                                                                uid:DEFAULT_TEST_UID
                                                                               utid:DEFAULT_TEST_UTID
                                                                                upn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                           tenantId:DEFAULT_TEST_UTID
                                        additionalFields:nil];

    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response request:params];

    XCTAssertNil(token);
}

- (void)testIDTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];

    MSIDIdToken *token = [factory idTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];

    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.rawIdToken, idToken);
}

- (void)testLegacyTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponseWithAdditionalFields:@{@"foci": @"1"}];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];

    MSIDLegacySingleResourceToken *token = [factory legacyTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];

    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);

    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(token.familyId, @"1");
    XCTAssertEqualObjects(token.accessTokenType, @"Bearer");
    XCTAssertEqualObjects(token.legacyUserId, DEFAULT_TEST_ID_TOKEN_USERNAME);

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];

    XCTAssertEqualObjects(token.idToken, idToken);
    XCTAssertEqualObjects(token.resource, DEFAULT_TEST_RESOURCE);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testLegacyAccessTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponseWithAdditionalFields:@{@"foci": @"1"}];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];

    MSIDLegacyAccessToken *token = [factory legacyAccessTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];

    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);

    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.accessTokenType, @"Bearer");
    XCTAssertEqualObjects(token.legacyUserId, DEFAULT_TEST_ID_TOKEN_USERNAME);

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];

    XCTAssertEqualObjects(token.idToken, idToken);
    XCTAssertEqualObjects(token.resource, DEFAULT_TEST_RESOURCE);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testLegacyRefreshTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponseWithAdditionalFields:@{@"foci": @"1"}];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];

    MSIDLegacyRefreshToken *token = [factory legacyRefreshTokenFromResponse:response request:params];

    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);

    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];

    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(token.familyId, @"1");
    XCTAssertEqualObjects(token.legacyUserId, DEFAULT_TEST_ID_TOKEN_USERNAME);

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.idToken, idToken);
}

- (void)testAccountFromTokenResponse_whenAADV1TokenResponse_shouldInitAccountAndSetProperties
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Eric" upn:@"eric_cartman@upn.com" tenantId:@"tenantId" additionalClaims:@{@"altsecid": @"::live.com::XXXXXX"}];
    NSDictionary *json = @{@"id_token": idToken, @"client_info": base64String};
    MSIDRequestParameters *requestParameters =
    [[MSIDRequestParameters alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY msidUrl]
                                         redirectUri:@"redirect uri"
                                            clientId:@"client id"
                                              target:@"target"];
    MSIDAADV1TokenResponse *tokenResponse = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:json error:nil];

    MSIDAccount *account = [factory accountFromResponse:tokenResponse request:requestParameters];

    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];

    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"eric_cartman@upn.com");
    XCTAssertEqualObjects(account.uniqueUserId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(account.clientInfo, clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeAADV2);
    XCTAssertEqualObjects(account.username, @"eric_cartman@upn.com");
    XCTAssertNil(account.givenName);
    XCTAssertNil(account.familyName);
    XCTAssertEqualObjects(account.name, @"Eric");
    XCTAssertNil(account.middleName);
    XCTAssertEqualObjects(account.alternativeAccountId, @"::live.com::XXXXXX");
    XCTAssertEqualObjects(account.authority.absoluteString, DEFAULT_TEST_AUTHORITY);
}

- (void)testAccessTokenFromResponse_whenV1ResponseAndNoResourceInRequest_shouldUseResourceInRequest
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    NSString *resourceInRequest = @"https://contoso.com";
    MSIDRequestParameters *requestParams = [[MSIDRequestParameters alloc] initWithAuthority:[NSURL URLWithString:@"https://contoso.com/common"]
                                                                                redirectUri:@"fake_redirect_uri"
                                                                                   clientId:@"fake_client_id"
                                                                                     target:resourceInRequest];
    MSIDAADV1TokenResponse *tokenResponse = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                                     }
                                                                                             error:nil];

    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:tokenResponse request:requestParams];

    XCTAssertEqualObjects(accessToken.resource, resourceInRequest);
}

- (void)testAccessTokenFromResponse_whenV1ResponseAndDotDefaultInRequest_shouldNotAddDotDefaultScope
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    NSString *resourceInRequest = @"https://contoso.com/.Default";
    NSString *resourceInResponse = @"https://contoso.com";
    MSIDRequestParameters *requestParams = [[MSIDRequestParameters alloc] initWithAuthority:[NSURL URLWithString:@"https://contoso.com/common"]
                                                                                redirectUri:@"fake_redirect_uri"
                                                                                   clientId:@"fake_client_id"
                                                                                     target:resourceInRequest];
    MSIDAADV1TokenResponse *tokenResponse = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                                     @"resource":resourceInResponse
                                                                                                     }
                                                                                             error:nil];

    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:tokenResponse request:requestParams];

    XCTAssertEqual(accessToken.scopes.count, 1);
    XCTAssertEqualObjects(accessToken.resource, resourceInResponse);
}

- (void)testAccessTokenFromResponse_whenWrongTypeOfResponse_shouldReturnNil
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *parameters = [MSIDTestRequestParams v1DefaultParams];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response request:parameters];
    XCTAssertNil(accessToken);
}

@end
