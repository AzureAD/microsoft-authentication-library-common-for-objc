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
#import "MSIDPkce.h"
#import "MSIDWebWPJResponse.h"
#import "MSIDAuthority.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAADAuthority.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDHttpRequest.h"
#import "MSIDAuthorizationCodeGrantRequest.h"
#import "MSIDRefreshTokenGrantRequest.h"
#import "MSIDBoundRefreshTokenGrantRequest.h"
#import "MSIDBoundRefreshToken.h"
#import "MSIDTestSwizzle.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDJWECrypto.h"
#import "MSIDBoundRefreshToken+Redemption.h"
#import "MSIDHttpResponseSerializer.h"
#import "MSIDJsonResponsePreprocessor.h"
#import "MSIDAuthenticationScheme.h"
#import "MSIDRegistrationInformationMock.h"
#import "MSIDTestSecureEnclaveKeyPairGenerator.h"
#import "MSIDJwtAlgorithm.h"
#import "MSIDEcdhApv.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDKeychainUtil.h"
#import "MSIDClaimsRequest.h"
#import "MSIDCache.h"
#import "MSIDIntuneInMemoryCacheDataSource.h"
#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDAADTokenResponseSerializer.h"
#import "MSIDAADJsonResponsePreprocessor.h"

@interface MSIDAADV2Oauth2FactoryTests : XCTestCase
@property (nonatomic) SecKeyRef privateStk;
@property (nonatomic) SecKeyRef privateDk;
@property (nonnull, nonatomic) MSIDRequestParameters *silentRequestParameters;
@end

@implementation MSIDAADV2Oauth2FactoryTests

#pragma mark - Token response

- (void)setUp
{
    MSIDRequestParameters *parameters = [MSIDRequestParameters new];
    parameters.authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    MSIDOpenIdProviderMetadata *metadata = [[MSIDOpenIdProviderMetadata alloc] init];
    metadata.tokenEndpoint = [NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"];
    parameters.authority.metadata = metadata;
    parameters.clientId = @"my_client_id";
    parameters.target = @"user.read tasks.read";
    parameters.oidcScope = @"openid profile offline_access";
    parameters.redirectUri = @"my_redirect_uri";
    parameters.correlationId = [NSUUID new];
    parameters.extendedLifetimeEnabled = YES;
    parameters.telemetryRequestId = [[NSUUID new] UUIDString];
    parameters.authScheme = [MSIDAuthenticationScheme new];
    self.silentRequestParameters = parameters;
}

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
    
    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
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
    
    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
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
    XCTAssertEqualObjects(token.realm, DEFAULT_TEST_UTID);
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
    XCTAssertEqualObjects(token.realm, DEFAULT_TEST_UTID);
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

- (void)testAccessTokenFromResponse_whenOIDCTokenResponseAndNestedAuth_shouldReturnTokenWithRedirectUrl
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.redirectUri = @"brk-1fec8e78-1234-5678-9101://myNestedApp.com";
    configuration.nestedAuthBrokerClientId = @"1fec8e78-1234-5678-9101";
    configuration.nestedAuthBrokerRedirectUri = @"msauth.com.microsoft.teams://auth";
    
    MSIDAccessToken *token = [factory accessTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, DEFAULT_TEST_UTID);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNotNil(token.extendedExpiresOn);

    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil];
    
    XCTAssertEqualObjects(token.scopes, scopes);
    XCTAssertNotNil(token.expiresOn);
    XCTAssertNotNil(token.redirectUri);
    XCTAssertEqualObjects(token.redirectUri, @"brk-1fec8e78-1234-5678-9101://myNestedApp.com");
}

- (void)testRefreshTokenFromResponse_whenAADV2TokenResponse_shouldReturnToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    
    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, DEFAULT_TEST_UTID);
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
    XCTAssertEqualObjects(token.realm, DEFAULT_TEST_UTID);
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
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2TokenResponseWithAT:@"at" RT:@"rt" scopes:scopes idToken:idToken uid:DEFAULT_TEST_UID utid:DEFAULT_TEST_UTID familyId:@"1"];
    
    MSIDConfiguration *configuration =

    [[MSIDConfiguration alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY aadAuthority]
                                     redirectUri:@"redirect uri"
                                        clientId:@"client id"
                                          target:@"target"];
    
    MSIDAccount *account = [factory accountFromResponse:tokenResponse configuration:configuration];
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, DEFAULT_TEST_HOME_ACCOUNT_ID);
    XCTAssertNotNil(account.clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account.username, @"eric999");
    XCTAssertNil(account.givenName, @"Eric");
    XCTAssertNil(account.familyName, @"Cartman");
    XCTAssertEqualObjects(account.name, @"Eric Cartman");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.realm, @"contoso.com");
}

#pragma mark - Request

- (void)testAuthorizationGrantRequest_whenNestedAuth_shouldIncludeAdditionalParameters
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDRequestParameters *parameters = [self nestedAuthRequestParameters];

    MSIDAuthorizationCodeGrantRequest *request = [factory authorizationGrantRequestWithRequestParameters:parameters
                                                                                            codeVerifier:@"pkce_code_verifier"
                                                                                                authCode:@"auth_code"
                                                                                           homeAccountId:@"home_account_id"];

    XCTAssertNotNil(request);
    XCTAssertEqualObjects(request.parameters[MSID_NESTED_AUTH_BROKER_CLIENT_ID], @"other_client_id");
    XCTAssertEqualObjects(request.parameters[MSID_NESTED_AUTH_BROKER_REDIRECT_URI], @"other_redirect_uri");
}

- (void)testRefreshTokenRequest_whenNestedAuth_shouldIncludeAdditionalParameters
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDRequestParameters *parameters = [self nestedAuthRequestParameters];

    MSIDRefreshTokenGrantRequest *request = [factory refreshTokenRequestWithRequestParameters:parameters
                                                                                 refreshToken:@"the_refresh_token"];

    XCTAssertNotNil(request);
    XCTAssertEqualObjects(request.parameters[MSID_NESTED_AUTH_BROKER_CLIENT_ID], @"other_client_id");
    XCTAssertEqualObjects(request.parameters[MSID_NESTED_AUTH_BROKER_REDIRECT_URI], @"other_redirect_uri");
}

- (MSIDInteractiveTokenRequestParameters *)nestedAuthRequestParameters
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    authority.metadata = [MSIDOpenIdProviderMetadata new];
    authority.metadata.tokenEndpoint = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"];

    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    parameters.authority = authority;
    parameters.clientId = @"my_client_id";
    parameters.target = @"user.read tasks.read";
    parameters.oidcScope = @"openid profile offline_access";
    parameters.redirectUri = @"my_redirect_uri";
    parameters.correlationId = [NSUUID new];
    parameters.extendedLifetimeEnabled = YES;
    parameters.telemetryRequestId = [[NSUUID new] UUIDString];
    parameters.nestedAuthBrokerClientId = @"other_client_id";
    parameters.nestedAuthBrokerRedirectUri = @"other_redirect_uri";
    return parameters;
}

#pragma mark - MSIDAADV2Oauth2Factory.boundRefreshTokenRequestWithRequestParameters Tests
#if TARGET_OS_IPHONE
- (void)testBoundRefreshTokenGrantRequest_whenNilBoundRefreshToken_shouldReturnNil
{
    MSIDAADV2Oauth2Factory *aadv2TokenFactory = [[MSIDAADV2Oauth2Factory alloc] init];
    NSError *error;
    MSIDAADRefreshTokenGrantRequest *tokenRequest = [aadv2TokenFactory
                                                       boundRefreshTokenRequestWithRequestParameters:self.silentRequestParameters
                                                                                        refreshToken:nil
                                                                                      requestContext:nil
                                                                                               error:&error];
    XCTAssertNil(tokenRequest);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Bound app refresh token is nil");
}

- (void)testBoundRefreshTokenGrantRequest_whenValidBoundRefreshToken_withoutWPJData_shouldReturnNil
{
    // Mock WPJ util to return nil
    [MSIDTestSwizzle classMethod:@selector(getWPJKeysWithTenantId:context:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id)^(__unused id obj, __unused NSString *tenantId, __unused id context) {
        return nil;
    }];
    NSError *error;
    MSIDAADV2Oauth2Factory *aadv2TokenFactory = [[MSIDAADV2Oauth2Factory alloc] init];
    MSIDAADRefreshTokenGrantRequest *tokenRequest = [aadv2TokenFactory
                                                       boundRefreshTokenRequestWithRequestParameters:self.silentRequestParameters
                                                                                        refreshToken:[self createBoundRefreshToken]
                                                                                      requestContext:nil
                                                                                               error:&error];
    
    XCTAssertNil(tokenRequest);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorWorkplaceJoinRequired);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Failed to get registered device metadata information when formulating bound refresh token redemption JWT.");
    [MSIDTestSwizzle reset];
}

- (void)testBoundRefreshTokenGrantRequest_whenValidBoundRefreshToken_withValidJWT_shouldReturnRequest
{
    MSIDWPJKeyPairWithCert *wpjInfo = [self createMockWPJKeyPair];
    NSError *jweCryptoError;
    SecKeyRef pubKey = NULL;
    if (self.privateStk)
    {
         pubKey = SecKeyCopyPublicKey(self.privateStk);
    }
    MSIDEcdhApv *apv = [[MSIDEcdhApv alloc] initWithKey:pubKey apvPrefix:@"MsalClient" customClientNonce:@"" context:nil error:nil];
    MSIDJWECrypto *mockJWECrypto = [[MSIDJWECrypto alloc] initWithKeyExchangeAlg:MSID_JWT_ALG_ECDH
                                                             encryptionAlgorithm:MSID_JWT_ALG_A256GCM
                                                                             apv:apv
                                                                         context:nil
                                                                           error:&jweCryptoError];
    
    // Mock WPJ util to return valid WPJ data
    [MSIDTestSwizzle classMethod:@selector(getWPJKeysWithTenantId:context:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id)^(__unused id obj, __unused NSString *tenantId, __unused id context) {
        return wpjInfo;
    }];
    
    // Mock JWT creation to return valid JWT
    [MSIDTestSwizzle instanceMethod:@selector(getTokenRedemptionJwtForTenantId:tokenRedemptionParameters:context:jweCrypto:error:)
                              class:[MSIDBoundRefreshToken class]
                              block:(id)^(__unused id obj,
                                         __unused NSString *tenantId,
                                         __unused MSIDBoundRefreshTokenRedemptionParameters *params,
                                         __unused id context,
                                         MSIDJWECrypto **jweCrypto,
                                         __unused NSError **error) {
        if (jweCrypto) {
            *jweCrypto = mockJWECrypto;
        }
        return @"valid.jwt.token";
    }];
    
    self.silentRequestParameters.claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:@{@"id_token":@{@"polids":@{@"essential":@YES,@"values":@[@"d77e91f0-fc60-45e4-97b8-14a1337faa28"]}}} error:nil];
    self.silentRequestParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"test-user@contoso.com" homeAccountId:@"userid.tenantid"];

    NSDictionary *dict = @{MSID_INTUNE_ENROLLMENT_ID_KEY: @{@"enrollment_ids": @[@{
                                                                                     @"tid" : @"tenantid",
                                                                                     @"oid" : @"d3444455-mike-4271-b6ea-e499cc0cab46",
                                                                                     @"home_account_id" : @"userid.tenantid",
                                                                                     @"user_id" : @"test-user@contoso.com",
                                                                                     @"enrollment_id" : @"enrollmentId"
                                                                                     }
                                                                                 ]}};
    
    MSIDCache *msidCache = [[MSIDCache alloc] initWithDictionary:dict];
    MSIDIntuneInMemoryCacheDataSource *memoryCache = [[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:msidCache];
    MSIDIntuneEnrollmentIdsCache *enrollmentIdsCache = [[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:memoryCache];
    [MSIDIntuneEnrollmentIdsCache setSharedCache:enrollmentIdsCache];
    
    NSString *enrollmentId = [self.silentRequestParameters.authority enrollmentIdForHomeAccountId:self.silentRequestParameters.accountIdentifier.homeAccountId
                                                                                     legacyUserId:self.silentRequestParameters.accountIdentifier.displayableId
                                                                                          context:nil
                                                                                            error:nil];
    
    MSIDAADV2Oauth2Factory *aadv2TokenFactory = [[MSIDAADV2Oauth2Factory alloc] init];
    NSError *error;
    MSIDAADRefreshTokenGrantRequest *tokenRequest = [aadv2TokenFactory
                                                       boundRefreshTokenRequestWithRequestParameters:self.silentRequestParameters
                                                                                        refreshToken:[self createBoundRefreshToken]
                                                                                      requestContext:nil
                                                                                               error:&error];
    MSIDBoundRefreshTokenGrantRequest *request = (MSIDBoundRefreshTokenGrantRequest *)tokenRequest;
    XCTAssertNotNil(request);
    XCTAssertNotNil(request.jweCrypto);
    XCTAssertEqual(request.jweCrypto, mockJWECrypto);
    XCTAssertNotNil(request.wpjInfo);
    XCTAssertEqual(request.wpjInfo, wpjInfo);
    
    // Verify parameters
    XCTAssertNotNil(request.parameters);
    XCTAssertEqualObjects(request.parameters[MSID_OAUTH2_CLIENT_INFO], @YES);
    XCTAssertEqualObjects(request.parameters[MSID_OAUTH2_CLAIMS], @"{\"id_token\":{\"polids\":{\"essential\":true,\"values\":[\"d77e91f0-fc60-45e4-97b8-14a1337faa28\"]}}}");
    XCTAssertEqualObjects(request.parameters[MSID_ENROLLMENT_ID], enrollmentId);
    XCTAssertEqualObjects(request.parameters[MSID_OAUTH2_GRANT_TYPE], @"urn:ietf:params:oauth:grant-type:jwt-bearer");
    XCTAssertEqualObjects(request.parameters[@"request"], @"valid.jwt.token");
    
    MSIDAADTokenResponseSerializer *responseSerializer = (MSIDAADTokenResponseSerializer *)request.responseSerializer;
    XCTAssertNotNil(responseSerializer);
    XCTAssertNotNil(responseSerializer.preprocessor);
    XCTAssertTrue([responseSerializer.preprocessor class] == [MSIDAADJsonResponsePreprocessor class]);
    MSIDJsonResponsePreprocessor *preprocessor = (MSIDJsonResponsePreprocessor *)responseSerializer.preprocessor;
    XCTAssertNotNil(preprocessor.jweDecryptPreProcessor);
    MSIDJweResponseDecryptPreProcessor *jweDecryptor = preprocessor.jweDecryptPreProcessor;
    XCTAssertTrue(jweDecryptor.decryptionKey != NULL);
    XCTAssertEqual(jweDecryptor.decryptionKey, self.privateStk);
    XCTAssertEqual(jweDecryptor.jweCrypto, mockJWECrypto);
    XCTAssertNotNil(jweDecryptor.additionalResponseClaims);
    XCTAssertEqual(jweDecryptor.additionalResponseClaims[MSID_BART_DEVICE_ID_KEY], wpjInfo.certificateSubject);
    [MSIDTestSwizzle reset];
}

#pragma mark - Helper Methods for Bound Refresh Token Tests

- (MSIDBoundRefreshToken *)createBoundRefreshToken
{
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    refreshToken.refreshToken = @"test_refresh_token";
    refreshToken.environment = @"login.microsoftonline.com";
    refreshToken.clientId = @"test_client_id";
    
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"test@contoso.com"
                                                                                      homeAccountId:@"uid.utid"];
    refreshToken.accountIdentifier = accountIdentifier;
    
    MSIDBoundRefreshToken *boundToken = [[MSIDBoundRefreshToken alloc] initWithRefreshToken:refreshToken
                                                                              boundDeviceId:@"test_device_id"];
    
    return boundToken;
}

- (MSIDWPJKeyPairWithCert *)createMockWPJKeyPair
{
    MSIDRegistrationInformationMock *regInfo = [MSIDRegistrationInformationMock new];
    regInfo.isWorkPlaceJoinedFlag = YES;
    [regInfo setCertificateSubject:@"some-device-id"];
    NSString *tenantId = @"contoso.com";
    NSString *accessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", [[MSIDKeychainUtil sharedInstance] teamId]];
    NSString *deviceKeyTag = [NSString stringWithFormat:@"%@#%@%@", kMSIDPrivateKeyIdentifier, tenantId, @"-EC"];
    NSString *transportKeyTag = [NSString stringWithFormat:@"%@#%@%@", kMSIDPrivateTransportKeyIdentifier, tenantId, @"-EC"];
    
    MSIDTestSecureEnclaveKeyPairGenerator *stkkeygen = [[MSIDTestSecureEnclaveKeyPairGenerator alloc] initWithSharedAccessGroup:accessGroup useSecureEnclave:YES applicationTag:transportKeyTag];
    MSIDTestSecureEnclaveKeyPairGenerator *dkkeygen = [[MSIDTestSecureEnclaveKeyPairGenerator alloc] initWithSharedAccessGroup:accessGroup useSecureEnclave:YES applicationTag:deviceKeyTag];
    self.privateDk = dkkeygen.eccPrivateKey;
    self.privateStk = stkkeygen.eccPrivateKey;
    if (self.privateDk)
        CFRetain(self.privateDk);
    if (self.privateStk)
        CFRetain(self.privateStk);
    [regInfo setPrivateKey:self.privateDk];
    [regInfo setPrivateTransportKey:self.privateStk];
    [regInfo setCertificateIssuer:@"82dbaca4-3e81-46ca-9c73-0950c1eaca97"];
    return regInfo;
}

-(void)tearDown
{
    [super tearDown];
    if (self.privateDk)
        CFRelease(self.privateDk);
    if (self.privateStk)
        CFRelease(self.privateStk);
    self.privateDk = nil;
    self.privateStk = nil;
    [self cleanUpWpjInformation];
}

- (void)cleanUpWpjInformation
{
    NSArray *deleteClasses = @[(__bridge id)(kSecClassKey), (__bridge id)(kSecClassCertificate), (__bridge id)(kSecClassGenericPassword)];
    NSString *accessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", [[MSIDKeychainUtil sharedInstance] teamId]];
    for (NSString *deleteClass in deleteClasses)
    {
        NSMutableDictionary *deleteQuery = [[NSMutableDictionary alloc] init];
        [deleteQuery setObject:deleteClass forKey:(__bridge id)kSecClass];
        [deleteQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
        OSStatus result = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
        XCTAssertTrue(result == errSecSuccess || result == errSecItemNotFound);
    }
}
#endif

@end

