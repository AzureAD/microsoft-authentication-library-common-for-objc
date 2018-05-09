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
#import "MSIDTestConfiguration.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAccount.h"
#import "MSIDAADV2TokenResponse.h"

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
    refreshToken.idToken = @"id token";
    
    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:tokenResponse refreshToken:refreshToken context:nil error:&error];
    
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
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];
    
    MSIDBaseToken *token = [factory baseTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.authority, configuration.authority);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
}

- (void)testAccessTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];
    
    MSIDAccessToken *token = [factory accessTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.authority, configuration.authority);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    
    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.accessTokenType, @"Bearer");
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    XCTAssertEqualObjects(token.resource, DEFAULT_TEST_RESOURCE);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testRefreshTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];
    
    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.authority, configuration.authority);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
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
                                                                           tenantId:DEFAULT_TEST_UTID];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];
    
    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response configuration:configuration];
    
    XCTAssertNil(token);
}

- (void)testIDTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];
    
    MSIDIdToken *token = [factory idTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.authority, configuration.authority);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
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
    
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];
    
    MSIDLegacySingleResourceToken *token = [factory legacyTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.authority, configuration.authority);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    
    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    XCTAssertEqualObjects(token.resource, DEFAULT_TEST_RESOURCE);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testAccountFromTokenResponse_whenAADV1TokenResponse_shouldInitAccountAndSetProperties
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"eric999" subject:@"subject" givenName:@"Eric" familyName:@"Cartman"];
    NSDictionary *json = @{@"id_token": idToken, @"client_info": base64String};

    MSIDConfiguration *configuration =
    [[MSIDConfiguration alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY msidUrl]
                                     redirectUri:@"redirect uri"
                                        clientId:@"client id"
                                          target:@"target"];

    MSIDAADV1TokenResponse *tokenResponse = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:json error:nil];
    
    MSIDAccount *account = [factory accountFromResponse:tokenResponse configuration:configuration];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"subject");
    XCTAssertEqualObjects(account.uniqueUserId, @"1.1234-5678-90abcdefg");
    XCTAssertNotNil(account.clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeAADV1);
    XCTAssertEqualObjects(account.username, @"eric999");
    XCTAssertEqualObjects(account.firstName, @"Eric");
    XCTAssertEqualObjects(account.lastName, @"Cartman");
    XCTAssertEqualObjects(account.authority.absoluteString, DEFAULT_TEST_AUTHORITY);
}

- (void)testAccessTokenFromResponse_whenV1ResponseAndNoResourceInRequest_shouldUseResourceInRequest
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    
    NSString *resourceInRequest = @"https://contoso.com";
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:[NSURL URLWithString:@"https://contoso.com/common"]
                                                                        redirectUri:@"fake_redirect_uri"
                                                                           clientId:@"fake_client_id"
                                                                             target:resourceInRequest];

    MSIDAADV1TokenResponse *tokenResponse = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                                     }
                                                                                             error:nil];
    
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:tokenResponse configuration:configuration];
    
    XCTAssertEqualObjects(accessToken.resource, resourceInRequest);
}

- (void)testAccessTokenFromResponse_whenV1ResponseAndDotDefaultInRequest_shouldNotAddDotDefaultScope
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    
    NSString *resourceInRequest = @"https://contoso.com/.Default";
    NSString *resourceInResponse = @"https://contoso.com";

    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:[NSURL URLWithString:@"https://contoso.com/common"]
                                                                        redirectUri:@"fake_redirect_uri"
                                                                           clientId:@"fake_client_id"
                                                                             target:resourceInRequest];
    MSIDAADV1TokenResponse *tokenResponse = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                                     @"resource":resourceInResponse
                                                                                                     }
                                                                                             error:nil];
    
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:tokenResponse configuration:configuration];
    
    XCTAssertEqual(accessToken.scopes.count, 1);
    XCTAssertEqualObjects(accessToken.resource, resourceInResponse);
}

@end

