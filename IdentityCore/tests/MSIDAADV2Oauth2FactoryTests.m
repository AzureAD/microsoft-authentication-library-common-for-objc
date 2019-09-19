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
#import "MSIDAADV2Oauth2Factory.h"
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
#import "MSIDTestIdentifiers.h"
#import "MSIDTestConfiguration.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAccount.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDWebviewConfiguration.h"
#import "MSIDPkce.h"
#import "MSIDWebWPJResponse.h"
#import "MSIDWebAADAuthResponse.h"
#import "MSIDAuthority.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAADAuthority.h"

@interface MSIDAADV2Oauth2FactoryTests : XCTestCase

@end

@implementation MSIDAADV2Oauth2FactoryTests

#pragma mark - Token response

- (void)testTokenResponseFromJSON_whenNilJSON_shouldReturnError
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
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
    
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:tokenResponse context:nil error:&error];
    
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
    
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:tokenResponse refreshToken:refreshToken context:nil error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    BOOL expectedClass = [response isKindOfClass:[MSIDAADV2TokenResponse class]];
    XCTAssertTrue(expectedClass);
    XCTAssertEqualObjects(response.accessToken, @"access token");
    XCTAssertEqualObjects(response.refreshToken, @"refresh token");
}

#pragma mark - Verify response

- (void)testVerifyResponse_whenWrongResponseProvided_shouldReturnError
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAADV1TokenResponse *response = [MSIDAADV1TokenResponse new];
    
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testVerifyResponse_whenValidResponseWithTokens_shouldReturnNoError
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                                @"refresh_token":@"fake_refresh_token",
                                                                                                @"client_info":rawClientInfo
                                                                                                }
                                                                                        error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testVerifyResponse_whenResponseWithoutAccessToken_shouldReturnError
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{@"refresh_token":@"fake_refresh_token",
                                                                                                @"client_info":rawClientInfo
                                                                                                }
                                                                                        error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testVerifyResponse_whenOAuthErrorViaAuthCode_shouldReturnError
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"}
                                                                                        error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidGrant);
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
}

- (void)testVerifyResponse_whenProtectionPolicyRequiredError_shouldReturnErrorWithSuberror
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{@"error":@"unauthorized_client",
                                                                                                @"suberror":MSID_PROTECTION_POLICY_REQUIRED,
                                                                                                @"adi":@"cooldude@somewhere.com"
                                                                                                }
                                                                                        error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerProtectionPoliciesRequired);
    XCTAssertEqual(error.userInfo[MSIDUserDisplayableIdkey], @"cooldude@somewhere.com");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], MSID_PROTECTION_POLICY_REQUIRED);
}

- (void)testVerifyResponse_whenNoClientInfo_shouldReturnError
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                                @"refresh_token":@"fake_refresh_token"}
                                                                                        error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Client info was not returned in the server response");
}

#pragma mark - Tokens

- (void)testBaseTokenFromResponse_whenAADV2TokenResponse_shouldReturnToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    
    MSIDBaseToken *token = [factory baseTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"1234-5678-90abcdefg");
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);
        
    XCTAssertNil(token.additionalServerInfo);
}

- (void)testAccessTokenFromResponse_whenAADV2TokenResponse_shouldReturnToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    
    MSIDAccessToken *token = [factory accessTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"1234-5678-90abcdefg");
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNotNil(token.extendedExpiresOn);

    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil];
    
    XCTAssertEqualObjects(token.scopes, scopes);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testRefreshTokenFromResponse_whenAADV2TokenResponse_shouldReturnToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    
    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"1234-5678-90abcdefg");
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertNil(token.familyId);
}

- (void)testIDTokenFromResponse_whenAADV2TokenResponse_shouldReturnToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    
    MSIDIdToken *token = [factory idTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"1234-5678-90abcdefg");
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNil(token.additionalServerInfo);
    
    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];
    XCTAssertEqualObjects(token.rawIdToken, idToken);
}

- (void)testLegacyTokenFromResponse_whenAADV2TokenResponse_shouldReturnToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    
    MSIDLegacySingleResourceToken *token = [factory legacyTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"common");
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNotNil(token.extendedExpiresOn);
    
    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil];
    
    XCTAssertEqualObjects(token.scopes, scopes);
    XCTAssertNotNil(token.expiresOn);
}

#pragma mark - .default scope

- (void)testAccessTokenFromResponse_withAdditionFromRequest_whenMultipleScopesInRequest_shouldNotAddDefaultScope
{
    NSString *scopeInRequest = @"user.write abc://abc/.default";
    NSString *scopeInResposne = @"user.read";
    
    // construct configuration
    MSIDAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"] rawTenant:nil context:nil error:nil];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority redirectUri:nil clientId:nil target:scopeInRequest];
    
    // construct response
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"refresh_token": @"rt",
                                @"scope": scopeInResposne
                                };
    NSError *error = nil;
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    
    // scope should be the same as it is in response
    XCTAssertEqualObjects(accessToken.scopes.msidToString, scopeInResposne);
}

- (void)testAccessTokenFromResponse_withAdditionFromRequest_whenNoDefaultScopeInRequest_shouldNotAddDefaultScope
{
    NSString *scopeInRequest = @"user.write";
    NSString *scopeInResposne = @"user.read";
    
    // construct configuration
    MSIDAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"] rawTenant:nil context:nil error:nil];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority redirectUri:nil clientId:nil target:scopeInRequest];
    
    // construct response
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"refresh_token": @"rt",
                                @"scope": scopeInResposne
                                };
    NSError *error = nil;
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    
    // scope should be the same as it is in response
    XCTAssertEqualObjects(accessToken.scopes.msidToString, scopeInResposne);
}


- (void)testAccountFromTokenResponse_whenAADV2TokenResponse_shouldInitAccountAndSetProperties
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Eric Cartman" preferredUsername:@"eric999" oid:nil tenantId:@"contoso.com"];
    
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"user.read", nil];
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2TokenResponseWithAT:@"at" RT:@"rt" scopes:scopes idToken:idToken uid:@"1" utid:@"1234-5678-90abcdefg" familyId:@"1"];
    
    MSIDConfiguration *configuration =

    [[MSIDConfiguration alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY aadAuthority]
                                     redirectUri:@"redirect uri"
                                        clientId:@"client id"
                                          target:@"target"];
    
    MSIDAccount *account = [factory accountFromResponse:tokenResponse configuration:configuration];
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertNotNil(account.clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account.username, @"eric999");
    XCTAssertNil(account.givenName, @"Eric");
    XCTAssertNil(account.familyName, @"Cartman");
    XCTAssertEqualObjects(account.name, @"Eric Cartman");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.realm, @"contoso.com");
}

@end

