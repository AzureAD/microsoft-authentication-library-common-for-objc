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
#import "MSIDTestIdentifiers.h"
#import "MSIDTestConfiguration.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAccount.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDLegacyRefreshToken.h"
#import "MSIDAadAuthorityCacheRecord.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAuthority.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAadAuthorityCacheRecord.h"
#import "MSIDAadAuthorityCache.h"

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

- (void)testVerifyResponse_whenResponseWithoutAccessToken_shouldReturnError
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    
    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"refresh_token":@"fake_refresh_token",
                                                                                                @"client_info":rawClientInfo
                                                                                                }
                                                                                        error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerOauth);
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

- (void)testVerifyResponse_whenProtectionPolicyRequiredErrorViaRefreshToken_shouldReturnErrorWithSuberror
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"error":@"unauthorized_client",
                                                                                                @"suberror":MSID_PROTECTION_POLICY_REQUIRED,
                                                                                                @"adi":@"cooldude@somewhere.com"
                                                                                                }
                                                                                        error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response fromRefreshToken:YES context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerProtectionPoliciesRequired);
    XCTAssertEqual(error.userInfo[MSIDUserDisplayableIdkey], @"cooldude@somewhere.com");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], MSID_PROTECTION_POLICY_REQUIRED);
    XCTAssert([@"cooldude@somewhere.com" isEqualToString:error.userInfo[MSIDUserDisplayableIdkey]]);
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
    
    XCTAssertEqualObjects(token.environment, configuration.authority.environment);
    XCTAssertEqualObjects(token.realm, @"1234-5678-90abcdefg");
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);
        
    XCTAssertNil(token.additionalServerInfo);
}

- (void)testAccessTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];
    
    MSIDAccessToken *token = [factory accessTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.environment, configuration.authority.environment);
    XCTAssertEqualObjects(token.realm, @"1234-5678-90abcdefg");
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNil(token.additionalServerInfo);
    
    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.resource, DEFAULT_TEST_RESOURCE);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testRefreshTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];
    
    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.environment, configuration.authority.environment);
    XCTAssertEqualObjects(token.realm, @"1234-5678-90abcdefg");
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertNil(token.familyId);
}

- (void)testRefreshTokenFromResponse_whenWrongTokenResponseType_shouldReturnNil
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADTokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response configuration:configuration];
    XCTAssertNil(token);
}

- (void)testAccountFromTokenFromResponse_whenWrongTokenResponseType_shouldReturnNil
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADTokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];

    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
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
    
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"1234-5678-90abcdefg");
    
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNil(token.additionalServerInfo);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME oid:nil tenantId:DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.rawIdToken, idToken);
}

- (void)testLegacyTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponseWithAdditionalFields:@{@"foci": @"1"}];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];

    MSIDLegacySingleResourceToken *token = [factory legacyTokenFromResponse:response configuration:configuration];

    XCTAssertEqualObjects(token.environment, configuration.authority.environment);
    XCTAssertEqualObjects(token.realm, configuration.authority.realm);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNil(token.additionalServerInfo);
    
    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(token.familyId, @"1");
    XCTAssertEqualObjects(token.accessTokenType, @"Bearer");
    XCTAssertEqualObjects(token.accountIdentifier.displayableId, DEFAULT_TEST_ID_TOKEN_USERNAME);
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME oid:nil tenantId:DEFAULT_TEST_UTID];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    XCTAssertEqualObjects(token.resource, DEFAULT_TEST_RESOURCE);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testLegacyAccessTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponseWithAdditionalFields:@{@"foci": @"1"}];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];

    MSIDLegacyAccessToken *token = [factory legacyAccessTokenFromResponse:response configuration:configuration];

    XCTAssertEqualObjects(token.environment, configuration.authority.environment);
    XCTAssertEqualObjects(token.realm, configuration.authority.realm);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);

    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNil(token.additionalServerInfo);

    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.accessTokenType, @"Bearer");
    XCTAssertEqualObjects(token.accountIdentifier.displayableId, DEFAULT_TEST_ID_TOKEN_USERNAME);

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME oid:nil tenantId:DEFAULT_TEST_UTID];

    XCTAssertEqualObjects(token.idToken, idToken);
    XCTAssertEqualObjects(token.resource, DEFAULT_TEST_RESOURCE);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testLegacyRefreshTokenFromResponse_whenAADV1TokenResponse_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponseWithAdditionalFields:@{@"foci": @"1"}];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];

    MSIDLegacyRefreshToken *token = [factory legacyRefreshTokenFromResponse:response configuration:configuration];

    XCTAssertEqualObjects(token.environment, configuration.authority.environment);
    XCTAssertEqualObjects(token.realm, configuration.authority.realm);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);

    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(token.familyId, @"1");
    XCTAssertEqualObjects(token.accountIdentifier.displayableId, DEFAULT_TEST_ID_TOKEN_USERNAME);

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME oid:nil tenantId:DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.idToken, idToken);
}

- (void)testAccountFromTokenResponse_whenAADV1TokenResponse_shouldInitAccountAndSetProperties
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Eric" upn:@"eric_cartman@upn.com" tenantId:@"tenantId" additionalClaims:@{@"altsecid": @"::live.com::XXXXXX"}];
    NSDictionary *json = @{@"id_token": idToken, @"client_info": base64String};

    MSIDConfiguration *configuration =
    [[MSIDConfiguration alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY aadAuthority]
                                     redirectUri:@"redirect uri"
                                        clientId:@"client id"
                                          target:@"target"];

    MSIDAADV1TokenResponse *tokenResponse = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:json error:nil];

    MSIDAccount *account = [factory accountFromResponse:tokenResponse configuration:configuration];

    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(account.clientInfo, clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account.username, @"eric_cartman@upn.com");
    XCTAssertNil(account.givenName);
    XCTAssertNil(account.familyName);
    XCTAssertEqualObjects(account.name, @"Eric");
    XCTAssertNil(account.middleName);
    XCTAssertEqualObjects(account.alternativeAccountId, @"::live.com::XXXXXX");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.realm, @"tenantId");
}

- (void)testAccessTokenFromResponse_whenV1ResponseAndNoResourceInRequest_shouldUseResourceInRequest
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    
    NSString *resourceInRequest = @"https://contoso.com";
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:[@"https://contoso.com/common" aadAuthority]
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

    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:[@"https://contoso.com/common" aadAuthority]
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

- (void)testAccessTokenFromResponse_whenWrongTypeOfResponse_shouldReturnNil
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    XCTAssertNil(accessToken);
}

- (void)setupAADAuthorityCache
{
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.networkHost = @"login.microsoftonline.com";
    record.cacheHost = @"login.windows.net";
    record.aliases = @[@"login.microsoft.com"];
    MSIDAadAuthorityCache *cache = [MSIDAadAuthorityCache sharedInstance];
    [cache setObject:record forKey:@"login.microsoftonline.com"];
}

@end

