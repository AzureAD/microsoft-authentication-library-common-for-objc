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
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDAADV1Oauth2Factory.h"
#import "MSIDTestConfiguration.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDLegacyAccessToken.h"
#import "MSIDLegacyRefreshToken.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDMacTokenCache.h"
#import "MSIDIdToken.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDBrokerResponse.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAADAuthority.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDTestCacheAccessorHelper.h"

@interface MSIDLegacyAccessorSSOIntegrationTests : XCTestCase
{
    MSIDLegacyTokenCacheAccessor *_legacyAccessor;
    MSIDLegacyTokenCacheAccessor *_nonSSOAccessor;
    MSIDDefaultTokenCacheAccessor *_otherAccessor;
    id<MSIDTokenCacheDataSource> _legacyDataSource;
    id<MSIDExtendedTokenCacheDataSource> _otherDataSource;

}

@end

@implementation MSIDLegacyAccessorSSOIntegrationTests

- (void)setUp
{

#if TARGET_OS_IOS
    _legacyDataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil error:nil];
    _otherDataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil error:nil];
#else
    // TODO: this should be replaced with a real macOS datasource instead
    _legacyDataSource = [MSIDMacTokenCache defaultCache];
    _otherDataSource = [[MSIDTestCacheDataSource alloc] init];
#endif
    _otherAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:_otherDataSource otherCacheAccessors:nil];
    _legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:_legacyDataSource otherCacheAccessors:@[_otherAccessor]];
    _nonSSOAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:_legacyDataSource otherCacheAccessors:nil];
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
    [_legacyDataSource removeTokensWithKey:[MSIDCacheKey new] context:nil error:nil];
    [_otherDataSource removeTokensWithKey:[MSIDCacheKey new] context:nil error:nil];
    [[MSIDAadAuthorityCache sharedInstance] removeAllObjects];

#if !TARGET_OS_IOS
    [[MSIDMacTokenCache defaultCache] clear];
#endif
}

#pragma mark - Saving

- (void)testSaveTokensWithFactory_whenNilResponse_shouldReturnError
{
    NSError *error = nil;
    BOOL result = [_nonSSOAccessor saveTokensWithConfiguration:[MSIDTestConfiguration defaultParams]
                                                      response:nil
                                                       factory:[MSIDAADV1Oauth2Factory new]
                                                       context:nil
                                                         error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testSaveSSOStateWithFactory_whenNilResponse_shouldReturnError
{
    NSError *error = nil;
    BOOL result = [_nonSSOAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration defaultParams]
                                                        response:nil
                                                         factory:[MSIDAADV1Oauth2Factory new]
                                                         context:nil
                                                           error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testSaveTokensWithFactory_whenMultiResourceResponse_andNoOtherAccessors_savesTokensToPrimaryAccessor
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" oid:nil tenantId:@"tid"];

    MSIDTokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:@"access token"
                                                                            rt:@"refresh token"
                                                                      resource:@"graph resource"
                                                                           uid:@"uid"
                                                                          utid:@"utid"
                                                                       idToken:idToken
                                                              additionalFields:nil];

    NSError *error = nil;
    BOOL result = [_nonSSOAccessor saveTokensWithConfiguration:[MSIDTestConfiguration defaultParams]
                                                      response:response
                                                       factory:[MSIDAADV1Oauth2Factory new]
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 1);

    MSIDLegacyAccessToken *accessToken = accessTokens[0];

    XCTAssertEqualObjects(accessToken.accessTokenType, @"Bearer");
    XCTAssertEqualObjects(accessToken.idToken, idToken);
    XCTAssertEqualObjects(accessToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([accessToken.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNil(accessToken.extendedExpiresOn);
    XCTAssertEqualObjects(accessToken.resource, @"graph resource");
    XCTAssertEqual(accessToken.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(accessToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(accessToken.realm, @"common");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNil(accessToken.additionalServerInfo);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];

    XCTAssertEqualObjects(refreshToken.idToken, idToken);
    XCTAssertEqualObjects(refreshToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertNil(refreshToken.familyId);
    XCTAssertEqual(refreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(refreshToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(refreshToken.realm, @"common");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNil(refreshToken.additionalServerInfo);

    NSArray *allTokens = [_nonSSOAccessor allTokensWithContext:nil error:nil];
    XCTAssertEqual([allTokens count], 2);
}

- (void)testSaveTokensWithFactory_whenMultiResourceResponse_savesTokensToBothAccessors
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" oid:nil tenantId:@"tid"];

    MSIDTokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:@"access token"
                                                                            rt:@"refresh token"
                                                                      resource:@"graph resource"
                                                                           uid:@"uid"
                                                                          utid:@"utid"
                                                                       idToken:idToken
                                                              additionalFields:nil];

    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration defaultParams]
                                                      response:response
                                                       factory:[MSIDAADV1Oauth2Factory new]
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 1);

    MSIDLegacyAccessToken *accessToken = accessTokens[0];

    XCTAssertEqualObjects(accessToken.accessTokenType, @"Bearer");
    XCTAssertEqualObjects(accessToken.idToken, idToken);
    XCTAssertEqualObjects(accessToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([accessToken.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNil(accessToken.extendedExpiresOn);
    XCTAssertEqualObjects(accessToken.resource, @"graph resource");
    XCTAssertEqual(accessToken.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(accessToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(accessToken.realm, @"common");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNil(accessToken.additionalServerInfo);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];

    XCTAssertEqualObjects(refreshToken.idToken, idToken);
    XCTAssertEqualObjects(refreshToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertNil(refreshToken.familyId);
    XCTAssertEqual(refreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(refreshToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(refreshToken.realm, @"common");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNil(refreshToken.additionalServerInfo);

    NSArray *allTokens = [_legacyAccessor allTokensWithContext:nil error:nil];
    XCTAssertEqual([allTokens count], 2);

    // Now check default accessor
    NSArray *defaultAccessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_otherAccessor];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([defaultRefreshTokens count], 1);

    MSIDRefreshToken *defaultRefreshToken = defaultRefreshTokens[0];
    XCTAssertEqualObjects(defaultRefreshToken.refreshToken, @"refresh token");
    XCTAssertNil(defaultRefreshToken.familyId);
    XCTAssertEqual(defaultRefreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(defaultRefreshToken.environment, @"login.microsoftonline.com");
    XCTAssertNil(defaultRefreshToken.realm);
    XCTAssertEqualObjects(defaultRefreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(defaultRefreshToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNil(defaultRefreshToken.additionalServerInfo);

    NSArray *defaultIDTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_otherAccessor];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *accounts = [_otherAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

    XCTAssertNotNil(accounts);
    XCTAssertNil(error);
    XCTAssertEqual([accounts count], 1);

    MSIDAccount *account = accounts[0];
    XCTAssertEqual(account.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account.username, @"upn@test.com");
    XCTAssertNil(account.givenName);
    XCTAssertNil(account.middleName);
    XCTAssertNil(account.familyName);
    XCTAssertEqualObjects(account.name, DEFAULT_TEST_ID_TOKEN_NAME);
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"tid");
    XCTAssertNil(account.alternativeAccountId);
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.realm, @"tid");
}

- (void)testSaveTokensWithFactory_whenMultiResourceFOCIResponse_savesTokensToBothAccessors
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" oid:nil tenantId:@"tid"];

    MSIDTokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:@"access token"
                                                                            rt:@"refresh token"
                                                                      resource:@"graph resource"
                                                                           uid:@"uid"
                                                                          utid:@"utid"
                                                                       idToken:idToken
                                                              additionalFields:@{@"foci": @"2"}];

    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration defaultParams]
                                                      response:response
                                                       factory:[MSIDAADV1Oauth2Factory new]
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *legacyAccessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([legacyAccessTokens count], 1);

    NSArray *legacyRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([legacyRefreshTokens count], 2);
    XCTAssertNotEqualObjects(legacyRefreshTokens[0], legacyRefreshTokens[1]);

    MSIDLegacyRefreshToken *refreshToken1 = legacyRefreshTokens[0];
    MSIDLegacyRefreshToken *refreshToken2 = legacyRefreshTokens[1];

    XCTAssertEqualObjects(refreshToken1.familyId, @"2");
    XCTAssertEqualObjects(refreshToken2.familyId, @"2");
    XCTAssertEqualObjects(refreshToken1.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken2.clientId, @"foci-2");

    NSArray *defaultAccessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_otherAccessor];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([defaultRefreshTokens count], 2);

    MSIDRefreshToken *defaultRefreshToken1 = defaultRefreshTokens[0];
    MSIDRefreshToken *defaultRefreshToken2 = defaultRefreshTokens[1];

    XCTAssertEqualObjects(defaultRefreshToken1.familyId, @"2");
    XCTAssertNil(defaultRefreshToken2.familyId);
    XCTAssertEqualObjects(defaultRefreshToken1.clientId, @"test_client_id");
    XCTAssertEqualObjects(defaultRefreshToken2.clientId, @"test_client_id");

    NSArray *defaultIDTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_otherAccessor];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *clientAccounts = [_otherAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

    XCTAssertEqual([clientAccounts count], 1);

    NSArray *familyAccounts = [_otherAccessor accountsWithAuthority:authority
                                                             clientId:nil
                                                             familyId:@"2"
                                                  accountIdentifier:nil
                                                              context:nil
                                                                error:&error];

    XCTAssertEqual([familyAccounts count], 1);

    NSArray *allAccounts = [_otherAccessor accountsWithAuthority:authority
                                                          clientId:@"test_client_id"
                                                          familyId:@"2"
                                                accountIdentifier:nil
                                                           context:nil
                                                             error:&error];

    XCTAssertEqual([allAccounts count], 1);
}

- (void)testSaveTokensWithFactory_whenNotMultiresourceResponse_savesTokensOnlyToPrimaryAccessor
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" oid:nil tenantId:@"tid"];

    MSIDTokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:@"access token"
                                                                            rt:@"refresh token"
                                                                      resource:nil
                                                                           uid:@"uid"
                                                                          utid:@"utid"
                                                                       idToken:idToken
                                                              additionalFields:nil];

    MSIDConfiguration *config = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/contoso.com"
                                                                         clientId:@"test_client_id"
                                                                      redirectUri:nil
                                                                           target:@"graph"];

    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:config
                                                      response:response
                                                       factory:[MSIDAADV1Oauth2Factory new]
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_otherAccessor];
    XCTAssertEqual([accessTokens count], 0);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *legacyTokens = [MSIDTestCacheAccessorHelper getAllLegacyTokens:_legacyAccessor];
    XCTAssertEqual([legacyTokens count], 1);

    MSIDLegacySingleResourceToken *token = legacyTokens[0];

    XCTAssertEqualObjects(token.accessTokenType, @"Bearer");
    XCTAssertEqualObjects(token.idToken, idToken);
    XCTAssertEqualObjects(token.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(token.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([token.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNil(token.extendedExpiresOn);
    XCTAssertEqualObjects(token.resource, @"graph");
    XCTAssertEqual(token.credentialType, MSIDLegacySingleResourceTokenType);
    XCTAssertEqualObjects(token.environment, @"login.windows.net");
    XCTAssertEqualObjects(token.realm, @"contoso.com");
    XCTAssertEqualObjects(token.clientId, @"test_client_id");
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.refreshToken, @"refresh token");
    XCTAssertNil(token.familyId);

    NSArray *defaultAccessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_otherAccessor];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([defaultRefreshTokens count], 0);

    NSArray *defaultIDTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_otherAccessor];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_otherAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertEqual([accounts count], 0);
}

- (void)testSaveTokensWithFactory_whenNotMultiresourceResponse_andNoIDToken_savesTokensOnlyToPrimaryAccessor
{
    MSIDTokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:@"access token"
                                                                            rt:@"refresh token"
                                                                      resource:nil
                                                                           uid:nil
                                                                          utid:nil
                                                                       idToken:nil
                                                              additionalFields:nil];

    MSIDConfiguration *config = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/contoso.com"
                                                                         clientId:@"test_client_id"
                                                                      redirectUri:nil
                                                                           target:@"graph"];

    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:config
                                                      response:response
                                                       factory:[MSIDAADV1Oauth2Factory new]
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_otherAccessor];
    XCTAssertEqual([accessTokens count], 0);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *legacyTokens = [MSIDTestCacheAccessorHelper getAllLegacyTokens:_legacyAccessor];
    XCTAssertEqual([legacyTokens count], 1);

    MSIDLegacySingleResourceToken *token = legacyTokens[0];

    XCTAssertEqualObjects(token.accessTokenType, @"Bearer");
    XCTAssertNil(token.idToken);
    XCTAssertNil(token.accountIdentifier.displayableId);
    XCTAssertEqualObjects(token.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([token.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNil(token.extendedExpiresOn);
    XCTAssertEqualObjects(token.resource, @"graph");
    XCTAssertEqual(token.credentialType, MSIDLegacySingleResourceTokenType);
    XCTAssertEqualObjects(token.environment, @"login.windows.net");
    XCTAssertEqualObjects(token.realm, @"contoso.com");
    XCTAssertEqualObjects(token.clientId, @"test_client_id");
    XCTAssertNil(token.accountIdentifier.homeAccountId);
    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.refreshToken, @"refresh token");
    XCTAssertNil(token.familyId);

    NSArray *defaultAccessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_otherAccessor];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([defaultRefreshTokens count], 0);

    NSArray *defaultIDTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_otherAccessor];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_otherAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertEqual([accounts count], 0);
}

- (void)testSaveTokens_withNoHomeAccountIdForSecondaryFormat_shouldSaveToLegacyFormatOnly
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" oid:nil tenantId:@"tid"];

    MSIDTokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:@"access token"
                                                                            rt:@"refresh token"
                                                                      resource:@"graph resource"
                                                                           uid:nil
                                                                          utid:nil
                                                                       idToken:idToken
                                                              additionalFields:nil];

    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration defaultParams]
                                                      response:response
                                                       factory:[MSIDAADV1Oauth2Factory new]
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *legacyTokens = [MSIDTestCacheAccessorHelper getAllLegacyTokens:_legacyAccessor];
    XCTAssertEqual([legacyTokens count], 0);

    NSArray *defaultAccessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_otherAccessor];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([defaultRefreshTokens count], 0);

    NSArray *defaultIDTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_otherAccessor];
    XCTAssertEqual([defaultIDTokens count], 0);
}

- (void)testSaveTokensWithRequestParams_whenNoRefreshTokenReturnedInResponse_shouldOnlySaveAccessTokensToPrimaryCache
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" oid:nil tenantId:@"tid"];

    MSIDTokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:@"access token"
                                                                            rt:nil
                                                                      resource:@"graph resource"
                                                                           uid:@"uid"
                                                                          utid:@"utid"
                                                                       idToken:idToken
                                                              additionalFields:nil];

    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration defaultParams]
                                                      response:response
                                                       factory:[MSIDAADV1Oauth2Factory new]
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *defaultAccessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_otherAccessor];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([defaultRefreshTokens count], 0);

    NSArray *defaultIDTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_otherAccessor];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *allAccounts = [_otherAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertEqual([allAccounts count], 0);
}

#pragma mark - Get refresh token

- (void)testGetRefreshTokenWithAccount_whenNoFamilyId_andTokenInPrimaryAccessor_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn2@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token 2");
    XCTAssertTrue([refreshToken isKindOfClass:[MSIDLegacyRefreshToken class]]);

    MSIDLegacyRefreshToken *legacyRefreshToken = (MSIDLegacyRefreshToken *) refreshToken;
    XCTAssertEqualObjects(legacyRefreshToken.accountIdentifier.displayableId, @"upn2@test.com");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(refreshToken.realm, @"common");
}

- (void)testGetRefreshTokenWithAccount_whenNoFamilyId_andTokenInSecondaryAccessor_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_otherAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid2"
                         utid:@"utid2"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                     accessor:_otherAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_otherAccessor];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn2@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token 2");
    XCTAssertTrue([refreshToken isKindOfClass:[MSIDRefreshToken class]]);
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.environment, @"login.windows.net");
    XCTAssertNil(refreshToken.realm);
}

- (void)testGetRefreshTokenWithAccount_whenFamilyIdProvided_andTokenInPrimaryAccessor_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:@{@"foci": @"1"}
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:@{@"foci": @"2"}
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 4);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn2@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:@"2"
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token 2");
    XCTAssertTrue([refreshToken isKindOfClass:[MSIDLegacyRefreshToken class]]);

    MSIDLegacyRefreshToken *legacyRefreshToken = (MSIDLegacyRefreshToken *) refreshToken;
    XCTAssertEqualObjects(legacyRefreshToken.accountIdentifier.displayableId, @"upn2@test.com");
    XCTAssertEqualObjects(refreshToken.clientId, @"foci-2");
    XCTAssertEqualObjects(refreshToken.familyId, @"2");
    XCTAssertEqualObjects(refreshToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(refreshToken.realm, @"common");
}

- (void)testGetRefreshTokenWithAccount_whenFamilyIdProvided_andTokenInSecondaryAccessor_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:@{@"foci": @"1"}
                     accessor:_otherAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid2"
                         utid:@"utid2"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:@{@"foci": @"2"}
                     accessor:_otherAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([refreshTokens count], 4);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_otherAccessor];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn2@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:@"2"
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token 2");
    XCTAssertTrue([refreshToken isKindOfClass:[MSIDRefreshToken class]]);
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.familyId, @"2");
    XCTAssertEqualObjects(refreshToken.environment, @"login.windows.net");
    XCTAssertNil(refreshToken.realm);
}

- (void)testGetRefreshTokenWithAccount_whenFamilyIdProvided_andTokensInBothAccessors_shouldReturnTokenFromPrimary
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:@{@"foci": @"1"}
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:@{@"foci": @"2"}
                     accessor:_otherAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *defaultRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([defaultRefreshTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:@"1"
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertTrue([refreshToken isKindOfClass:[MSIDLegacyRefreshToken class]]);

    MSIDLegacyRefreshToken *legacyRefreshToken = (MSIDLegacyRefreshToken *) refreshToken;
    XCTAssertEqualObjects(legacyRefreshToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(refreshToken.clientId, @"foci-1");
    XCTAssertEqualObjects(refreshToken.familyId, @"1");
    XCTAssertEqualObjects(refreshToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(refreshToken.realm, @"common");
}

- (void)testGetRefreshTokenWithAccount_whenNoFamilyIdProvided_andTokensInBothAccessors_shouldReturnTokenFromPrimary
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                     accessor:_otherAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *defaultRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([defaultRefreshTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertTrue([refreshToken isKindOfClass:[MSIDLegacyRefreshToken class]]);

    MSIDLegacyRefreshToken *legacyRefreshToken = (MSIDLegacyRefreshToken *) refreshToken;
    XCTAssertEqualObjects(legacyRefreshToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertNil(refreshToken.familyId);
    XCTAssertEqualObjects(refreshToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(refreshToken.realm, @"common");
}

- (void)testGetRefreshTokenWithAccount_whenNoFamilyId_andOnlyFamilyTokenInPrimaryAccessor_shouldReturnNil
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:@{@"foci": @"3"}
                     accessor:_nonSSOAccessor];

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNotNil(refreshToken);
    BOOL result = [_legacyAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    MSIDRefreshToken *refreshToken2 = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:configuration
                                                                          context:nil
                                                                            error:&error];

    XCTAssertNil(refreshToken2);
    XCTAssertNil(error);
}

- (void)testGetRefreshTokenWithAccount_whenFamilyIdProvided_andOnlyClientTokenInPrimaryAccessor_shouldReturnNil
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNotNil(refreshToken);
    BOOL result = [_legacyAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    MSIDRefreshToken *refreshToken2 = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                         familyId:@"2"
                                                                    configuration:configuration
                                                                          context:nil
                                                                            error:&error];

    XCTAssertNil(refreshToken2);
    XCTAssertNil(error);
}

- (void)testGetRefreshToken_whenNoLegacyUserId_onlyHomeAccountId_andTokenInPrimaryCacheWithoutUniqueUser_shouldReturnSingleToken
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:nil
                         utid:nil
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:@"uid2.utid2"];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNotNil(refreshToken);
    XCTAssertNil(error);
}

- (void)testGetRefreshTokenWithAccount_whenFamilyIdProvidedNoUserID_andOnlyOneTokenInCache_shouldReturnToken
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:@{@"foci": @"1"}
                     accessor:_nonSSOAccessor];

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:nil];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNotNil(refreshToken);
    XCTAssertNil(error);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token 2");
}

- (void)testGetRefreshTokenWithAccount_whenFamilyIdProvidedNoUserID_andMultipleTokensInCache_shouldReturnNilAndFillError
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:@{@"foci": @"1"}
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:@{@"foci": @"1"}
                     accessor:_nonSSOAccessor];

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:nil];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNil(refreshToken);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorCacheMultipleUsers);
}

#pragma mark - Clear

- (void)testClearWithContext_whenTokensInBothCaches_shouldClearAllTokens
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:@{@"foci": @"1"}
                     accessor:_legacyAccessor];

    NSError *error = nil;
    NSArray *allTokens = [_legacyAccessor allTokensWithContext:nil error:&error];
    XCTAssertNotNil(allTokens);
    XCTAssertNil(error);
    XCTAssertEqual([allTokens count], 3);

    NSArray *allDefaultTokens = [_otherAccessor allTokensWithContext:nil error:&error];
    XCTAssertNotNil(allDefaultTokens);
    XCTAssertNil(error);
    XCTAssertEqual([allDefaultTokens count], 2);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *allAccounts = [_otherAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:@"1" accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertEqual([allAccounts count], 1);

    BOOL result = [_legacyAccessor clearWithContext:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    allTokens = [_legacyAccessor allTokensWithContext:nil error:&error];
    XCTAssertNotNil(allTokens);
    XCTAssertNil(error);
    XCTAssertEqual([allTokens count], 0);
}

#pragma mark - Get all accounts

- (void)testAllAccountsWithEnvironment_whenNoFamilyId_andTokensInPrimaryCache_shouldReturnAccounts
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                     accessor:_legacyAccessor];

    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_legacyAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"tid");
}

- (void)testAllAccountsWithEnvironment_whenFamilyIdProvided_andTokensInPrimaryCache_shouldReturnAccounts
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:@{@"foci": @"1"}
                     accessor:_legacyAccessor];

    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_legacyAccessor accountsWithAuthority:authority clientId:nil familyId:@"1" accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"tid");
}

- (void)testAllAccountsWithEnvironment_whenNoFamilyId_andTokensInBothCaches_shouldReturnAccounts
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                     accessor:_legacyAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                     accessor:_otherAccessor];

    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_legacyAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"tid");
}

- (void)testAllAccountsWithEnvironment_whenFamilyIdProvided_andTokensInBothCaches_shouldReturnAccounts
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:@{@"foci": @"1"}
                     accessor:_legacyAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:@{@"foci": @"1"}
                     accessor:_otherAccessor];

    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];
    NSArray *accounts = [_legacyAccessor accountsWithAuthority:authority clientId:nil familyId:@"1" accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"tid");
}

#pragma mark - Get access tokens

- (void)testGetAccessTokenForAccount_whenAccessTokensInPrimaryCache_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id2"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id2"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDLegacyAccessToken *accessToken = [_legacyAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accessToken);
    XCTAssertEqualObjects(accessToken.accessToken, @"access token 2");
    XCTAssertEqualObjects(accessToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id2");
    XCTAssertEqualObjects(accessToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(accessToken.realm, @"common");
}

- (void)testGetAccessTokenForAccount_whenAccessTokenCachePartitionedByAppIdentifier_andTwoTokensInCache_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                 enrollmentId:@"myenrollmentid1"
                appIdentifier:@"myapp1"
                     accessor:_nonSSOAccessor];
    
    // Save second token (same clientId, but different app identifier)
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                 enrollmentId:@"myenrollmentid2"
                appIdentifier:@"myapp2"
                     accessor:_nonSSOAccessor];
    
    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 1);
    
    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 2);
    
    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];
    configuration.applicationIdentifier = @"myapp1";
    
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDLegacyAccessToken *accessToken = [_legacyAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(accessToken);
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualObjects(accessToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(accessToken.realm, @"common");
}

- (void)testGetAccessTokenForAccount_whenAccessTokenCachePartitionedByAppIdentifier_whenDifferentApp_shouldReturnNil
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                 enrollmentId:@"myenrollmentid1"
                appIdentifier:@"myapp1"
                     accessor:_nonSSOAccessor];
    
    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 1);
    
    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 1);
    
    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];
    configuration.applicationIdentifier = @"myapp3";
    
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDLegacyAccessToken *accessToken = [_legacyAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(accessToken);
}

- (void)testGetAccessTokenForAccount_whenAccessTokensInSecondaryCache_shouldNotReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.com/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                     accessor:_otherAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDLegacyAccessToken *accessToken = [_legacyAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNil(accessToken);
    XCTAssertNil(error);
}

- (void)testGetAccessTokenWithAccount_whenNoUserID_andOnlyOneTokenInCache_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:nil];
    NSError *error = nil;
    MSIDLegacyAccessToken *accessToken = [_legacyAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accessToken);
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualObjects(accessToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(accessToken.realm, @"common");
}

- (void)testGetAccessTokenWithAccount_whenNoUserID_andMultipleTokensInCache_shouldReturnNilAndFillError
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:nil];
    NSError *error = nil;
    MSIDLegacyAccessToken *accessToken = [_legacyAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNotNil(error);
    XCTAssertNil(accessToken);
    XCTAssertEqual(error.code, MSIDErrorCacheMultipleUsers);
}

- (void)testGetSingleResourceTokenTokenForAccount_whenAccessTokensInPrimaryCache_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:nil
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.com/common"
             responseResource:nil
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *legacyTokens = [MSIDTestCacheAccessorHelper getAllLegacyTokens:_legacyAccessor];
    XCTAssertEqual([legacyTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.com/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDLegacySingleResourceToken *accessToken = [_legacyAccessor getSingleResourceTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accessToken);
    XCTAssertEqualObjects(accessToken.accessToken, @"access token 2");
    XCTAssertEqualObjects(accessToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.refreshToken, @"refresh token 2");
    XCTAssertEqualObjects(accessToken.environment, @"login.windows.com");
    XCTAssertEqualObjects(accessToken.realm, @"common");
}

- (void)testGetSingleResourceTokenTokenForAccount_whenNoLegacyUserId_whenAccessTokensInPrimaryCache_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:nil
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *legacyTokens = [MSIDTestCacheAccessorHelper getAllLegacyTokens:_legacyAccessor];
    XCTAssertEqual([legacyTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:nil];
    NSError *error = nil;
    MSIDLegacySingleResourceToken *accessToken = [_legacyAccessor getSingleResourceTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accessToken);
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualObjects(accessToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.refreshToken, @"refresh token");
    XCTAssertEqualObjects(accessToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(accessToken.realm, @"common");
}

#pragma mark - Remove

- (void)testValidateAndRemoveRefreshToken_whenNilTokenProvided_shouldReturnError
{
    NSError *error = nil;
    BOOL result = [_legacyAccessor validateAndRemoveRefreshToken:nil context:nil error:&error];
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testValidateAndRemoveRefreshToken_whenTokenProvided_butOutdatedToken_shouldReturnError
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];
    refreshToken.refreshToken = @"outdated refresh token";

    NSError *error = nil;
    BOOL result = [_legacyAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remaininRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([remaininRefreshTokens count], 1);
}

- (void)testValidateAndRemoveRefreshToken_whenTokenProvided_andTokenFromPrimaryCache_shouldRemoveToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];

    NSError *error = nil;
    BOOL result = [_legacyAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remaininRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([remaininRefreshTokens count], 0);
}

- (void)testValidateAndRemoveRefreshToken_whenTokenProvided_butTokenFromSecondaryCache_shouldReturnError
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_otherAccessor];

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];

    NSError *error = nil;
    BOOL result = [_legacyAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remaininRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([remaininRefreshTokens count], 1);
}

- (void)testRemoveAccessToken_whenTokenProvided_shouldRemoveToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph2"
                inputResource:@"graph2"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyAccessToken *firstToken = accessTokens[0];
    MSIDLegacyAccessToken *secondToken = accessTokens[1];

    NSError *error = nil;
    BOOL result = [_legacyAccessor removeAccessToken:secondToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainingAccessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([remainingAccessTokens count], 1);
    XCTAssertEqualObjects(remainingAccessTokens[0], firstToken);

    NSArray *remaininRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([remaininRefreshTokens count], 1);
}

- (void)testClearCacheForAccount_whenTokensInCache_shouldRemoveCorrectTokens
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph2"
                inputResource:@"graph2"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn2@test.com" homeAccountId:nil];

    NSError *error = nil;
    BOOL result = [_legacyAccessor clearCacheForAccount:account authority:nil clientId:nil familyId:nil context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainingAccessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([remainingAccessTokens count], 1);
    MSIDLegacyAccessToken *remainingAccessToken = remainingAccessTokens[0];
    XCTAssertEqualObjects(remainingAccessToken.accountIdentifier.displayableId, @"upn@test.com");

    NSArray *remaininRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    MSIDLegacyRefreshToken *reminingRefreshToken = remaininRefreshTokens[0];
    XCTAssertEqual([remaininRefreshTokens count], 1);
    XCTAssertEqualObjects(reminingRefreshToken.accountIdentifier.displayableId, @"upn@test.com");
}

- (void)testClearCacheForAccount_whenTokensInCacheInMultipleAccessors_shouldRemoveCorrectTokens
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id2"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_legacyAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph2"
                inputResource:@"graph2"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_legacyAccessor];

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *otherRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([otherRefreshTokens count], 2);

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn2@test.com" homeAccountId:nil];

    NSError *error = nil;
    BOOL result = [_legacyAccessor clearCacheForAccount:account authority:nil clientId:@"test_client_id" familyId:nil context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainingAccessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([remainingAccessTokens count], 1);
    MSIDLegacyAccessToken *remainingAccessToken = remainingAccessTokens[0];
    XCTAssertEqualObjects(remainingAccessToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects([remainingAccessTokens[0] clientId], @"test_client_id2");

    NSArray *remaininRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([remaininRefreshTokens count], 1);
    MSIDLegacyRefreshToken *remainingRefreshToken = remaininRefreshTokens[0];
    XCTAssertEqualObjects(remainingRefreshToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects([remaininRefreshTokens[0] clientId], @"test_client_id2");

    NSArray *otherRemainingRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_otherAccessor];
    XCTAssertEqual([otherRemainingRefreshTokens count], 1);
    XCTAssertEqualObjects([otherRemainingRefreshTokens[0] clientId], @"test_client_id2");
}

- (void)testClearCacheForAccountAndClientId_whenTokensInCache_shouldRemoveCorrectTokens
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id2"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph2"
                inputResource:@"graph2"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];

    NSError *error = nil;
    BOOL result = [_legacyAccessor clearCacheForAccount:account authority:nil clientId:@"test_client_id" familyId:nil context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainingAccessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([remainingAccessTokens count], 1);
    XCTAssertEqualObjects([remainingAccessTokens[0] clientId], @"test_client_id2");

    NSArray *remaininRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([remaininRefreshTokens count], 1);
    XCTAssertEqualObjects([remaininRefreshTokens[0] clientId], @"test_client_id2");
}

- (void)testRemoveAccessToken_whenNilTokenProvided_shouldReturnError
{
    NSError *error = nil;
    BOOL result = [_legacyAccessor removeAccessToken:nil context:nil error:&error];
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

#pragma mark - All tokens

- (void)testGetAllTokensWithContext_whenTokensInPrimaryCache_shouldReturnTokens
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    NSError *error = nil;
    NSArray *allTokens = [_legacyAccessor allTokensWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allTokens);
    XCTAssertEqual([allTokens count], 2);
}

- (void)testGetAllTokensWithContext_whenTokensInSecondaryCache_shouldNotReturnTokens
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_otherAccessor];

    NSError *error = nil;
    NSArray *allTokens = [_legacyAccessor allTokensWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allTokens);
    XCTAssertEqual([allTokens count], 0);
}

#pragma mark - Authority migration

- (void)testGetRefreshTokenWithAccount_whenDifferentAuthority_shouldReturnToken
{
    MSIDAadAuthorityCache *cache = [MSIDAadAuthorityCache sharedInstance];
    NSURL *authorityUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    NSArray *metadata = @[ @{ @"preferred_network" : @"login.windows.net",
                              @"preferred_cache" :  @"login.windows.net",
                              @"aliases" : @[ @"login.windows.net", @"login.microsoftonline.com" ] } ];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Process Metadata."];
    [cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil completion:^(BOOL result, NSError *error)
     {
         XCTAssertTrue(result);
         XCTAssertNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_legacyAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_legacyAccessor];
    XCTAssertEqual([accessTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.microsoftonline.com/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertTrue([refreshToken isKindOfClass:[MSIDLegacyRefreshToken class]]);

    MSIDLegacyRefreshToken *legacyRefreshToken = (MSIDLegacyRefreshToken *) refreshToken;
    XCTAssertEqualObjects(legacyRefreshToken.accountIdentifier.displayableId, @"upn@test.com");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(refreshToken.storageEnvironment, @"login.windows.net");
    XCTAssertEqualObjects(refreshToken.realm, @"common");
}

#pragma mark - Get App Metadata
- (void)testSaveTokensWithFactory_whenMultiResourceFOCIResponse_savesAppMetadata
{
    
    MSIDAADTokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponseWithAdditionalFields:@{@"foci": @"familyId"}];
    
    NSError *error = nil;
    MSIDConfiguration *configuration = [MSIDTestConfiguration defaultParams];
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:configuration
                                                      response:response
                                                       factory:[MSIDAADV1Oauth2Factory new]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSArray<MSIDAppMetadataCacheItem *> *appMetadataEntries = [_otherAccessor getAppMetadataEntries:configuration
                                                                                            context:nil
                                                                                              error:nil];
    
    XCTAssertEqual([appMetadataEntries count], 1);
    XCTAssertEqualObjects(appMetadataEntries[0].clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(appMetadataEntries[0].environment, configuration.authority.environment);
    XCTAssertEqualObjects(appMetadataEntries[0].familyId, @"familyId");
}

#pragma mark - Helpers

- (void)saveResponseWithUPN:(NSString *)upn
                   clientId:(NSString *)clientId
                  authority:(NSString *)authority
           responseResource:(NSString *)responseResource
              inputResource:(NSString *)inputResource
                        uid:(NSString *)uid
                       utid:(NSString *)utid
                accessToken:(NSString *)accessToken
               refreshToken:(NSString *)refreshToken
           additionalFields:(NSDictionary *)additionalFields
                   accessor:(id<MSIDCacheAccessor>)accessor
{
    [self saveResponseWithUPN:upn
                     clientId:clientId
                    authority:authority
             responseResource:responseResource
                inputResource:inputResource
                          uid:uid
                         utid:utid
                  accessToken:accessToken
                 refreshToken:refreshToken
             additionalFields:additionalFields
                 enrollmentId:nil
                appIdentifier:nil
                     accessor:accessor];
}

- (void)saveResponseWithUPN:(NSString *)upn
                   clientId:(NSString *)clientId
                  authority:(NSString *)authority
           responseResource:(NSString *)responseResource
              inputResource:(NSString *)inputResource
                        uid:(NSString *)uid
                       utid:(NSString *)utid
                accessToken:(NSString *)accessToken
               refreshToken:(NSString *)refreshToken
           additionalFields:(NSDictionary *)additionalFields
               enrollmentId:(NSString *)enrollmentId
              appIdentifier:(NSString *)appIdentifier
                   accessor:(id<MSIDCacheAccessor>)accessor
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:upn oid:nil tenantId:@"tid"];

    MSIDTokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:accessToken
                                                                            rt:refreshToken
                                                                      resource:responseResource
                                                                           uid:uid
                                                                          utid:utid
                                                                       idToken:idToken
                                                              additionalFields:additionalFields];

    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:authority
                                                                                clientId:clientId
                                                                             redirectUri:nil
                                                                                  target:inputResource];
    
    configuration.applicationIdentifier = appIdentifier;

    NSError *error = nil;
    // Save first token
    BOOL result = [accessor saveTokensWithConfiguration:configuration
                                               response:response
                                                factory:[MSIDAADV1Oauth2Factory new]
                                                context:nil
                                                  error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);
}

@end
