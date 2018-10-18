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

@interface MSIDLegacyAccessorSSOIntegrationTests : XCTestCase
{
    MSIDLegacyTokenCacheAccessor *_legacyAccessor;
    MSIDLegacyTokenCacheAccessor *_nonSSOAccessor;
    MSIDDefaultTokenCacheAccessor *_otherAccessor;
    id<MSIDTokenCacheDataSource> _legacyDataSource;
    id<MSIDTokenCacheDataSource> _otherDataSource;

}

@end

@implementation MSIDLegacyAccessorSSOIntegrationTests

- (void)setUp
{

#if TARGET_OS_IOS
    _legacyDataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
    _otherDataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
#else
    // TODO: this should be replaced with a real macOS datasource instead
    _legacyDataSource = [MSIDMacTokenCache defaultCache];
    _otherDataSource = [[MSIDTestCacheDataSource alloc] init];
#endif
    MSIDOauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    _otherAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:_otherDataSource otherCacheAccessors:nil factory:factory];
    _legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:_legacyDataSource otherCacheAccessors:@[_otherAccessor] factory:factory];
    _nonSSOAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:_legacyDataSource otherCacheAccessors:nil factory:factory];
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
    [_legacyDataSource removeItemsWithKey:[MSIDCacheKey new] context:nil error:nil];
    [_otherDataSource removeItemsWithKey:[MSIDCacheKey new] context:nil error:nil];
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
                                                         context:nil
                                                           error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testSaveTokensWithFactory_whenMultiResourceResponse_andNoOtherAccessors_savesTokensToPrimaryAccessor
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" tenantId:@"tid"];

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
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    MSIDLegacyAccessToken *accessToken = accessTokens[0];

    XCTAssertEqualObjects(accessToken.accessTokenType, @"Bearer");
    XCTAssertEqualObjects(accessToken.idToken, idToken);
    XCTAssertEqualObjects(accessToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([accessToken.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNil(accessToken.extendedExpireTime);
    XCTAssertEqualObjects(accessToken.resource, @"graph resource");
    XCTAssertEqual(accessToken.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(accessToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(accessToken.additionalServerInfo, [NSDictionary dictionary]);

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];

    XCTAssertEqualObjects(refreshToken.idToken, idToken);
    XCTAssertEqualObjects(refreshToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertNil(refreshToken.familyId);
    XCTAssertEqual(refreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(refreshToken.additionalServerInfo, [NSDictionary dictionary]);

    NSArray *allTokens = [_nonSSOAccessor allTokensWithContext:nil error:nil];
    XCTAssertEqual([allTokens count], 2);
}

- (void)testSaveTokensWithFactory_whenMultiResourceResponse_savesTokensToBothAccessors
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" tenantId:@"tid"];

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
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    MSIDLegacyAccessToken *accessToken = accessTokens[0];

    XCTAssertEqualObjects(accessToken.accessTokenType, @"Bearer");
    XCTAssertEqualObjects(accessToken.idToken, idToken);
    XCTAssertEqualObjects(accessToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([accessToken.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNil(accessToken.extendedExpireTime);
    XCTAssertEqualObjects(accessToken.resource, @"graph resource");
    XCTAssertEqual(accessToken.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(accessToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(accessToken.additionalServerInfo, [NSDictionary dictionary]);

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];

    XCTAssertEqualObjects(refreshToken.idToken, idToken);
    XCTAssertEqualObjects(refreshToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertNil(refreshToken.familyId);
    XCTAssertEqual(refreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(refreshToken.additionalServerInfo, [NSDictionary dictionary]);

    NSArray *allTokens = [_legacyAccessor allTokensWithContext:nil error:nil];
    XCTAssertEqual([allTokens count], 2);

    // Now check default accessor
    NSArray *defaultAccessTokens = [self getAllAccessTokens];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 1);

    MSIDRefreshToken *defaultRefreshToken = defaultRefreshTokens[0];
    XCTAssertEqualObjects(defaultRefreshToken.refreshToken, @"refresh token");
    XCTAssertNil(defaultRefreshToken.familyId);
    XCTAssertEqual(defaultRefreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(defaultRefreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(defaultRefreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(defaultRefreshToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(defaultRefreshToken.additionalServerInfo, nil);

    NSArray *defaultIDTokens = [self getAllIDTokens];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *accounts = [_otherAccessor allAccountsForAuthority:authority
                                                       clientId:@"test_client_id"
                                                       familyId:nil
                                                        context:nil
                                                          error:&error];

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
    XCTAssertNil(account.alternativeAccountId);
    XCTAssertEqualObjects(account.authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
}

- (void)testSaveTokensWithFactory_whenMultiResourceFOCIResponse_savesTokensToBothAccessors
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" tenantId:@"tid"];

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
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *legacyAccessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([legacyAccessTokens count], 1);

    NSArray *legacyRefreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([legacyRefreshTokens count], 2);
    XCTAssertNotEqualObjects(legacyRefreshTokens[0], legacyRefreshTokens[1]);

    MSIDLegacyRefreshToken *refreshToken1 = legacyRefreshTokens[0];
    MSIDLegacyRefreshToken *refreshToken2 = legacyRefreshTokens[1];

    XCTAssertEqualObjects(refreshToken1.familyId, @"2");
    XCTAssertEqualObjects(refreshToken2.familyId, @"2");
    XCTAssertEqualObjects(refreshToken1.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken2.clientId, @"foci-2");

    NSArray *defaultAccessTokens = [self getAllAccessTokens];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 2);

    MSIDRefreshToken *defaultRefreshToken1 = defaultRefreshTokens[0];
    MSIDRefreshToken *defaultRefreshToken2 = defaultRefreshTokens[1];

    XCTAssertEqualObjects(defaultRefreshToken1.familyId, @"2");
    XCTAssertNil(defaultRefreshToken2.familyId);
    XCTAssertEqualObjects(defaultRefreshToken1.clientId, @"test_client_id");
    XCTAssertEqualObjects(defaultRefreshToken2.clientId, @"test_client_id");

    NSArray *defaultIDTokens = [self getAllIDTokens];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *clientAccounts = [_otherAccessor allAccountsForAuthority:authority
                                                             clientId:@"test_client_id"
                                                             familyId:nil
                                                              context:nil
                                                                error:&error];

    XCTAssertEqual([clientAccounts count], 1);

    NSArray *familyAccounts = [_otherAccessor allAccountsForAuthority:authority
                                                             clientId:nil
                                                             familyId:@"2"
                                                              context:nil
                                                                error:&error];

    XCTAssertEqual([familyAccounts count], 1);

    NSArray *allAccounts = [_otherAccessor allAccountsForAuthority:authority
                                                          clientId:@"test_client_id"
                                                          familyId:@"2"
                                                           context:nil
                                                             error:&error];

    XCTAssertEqual([allAccounts count], 1);
}

- (void)testSaveTokensWithFactory_whenNotMultiresourceResponse_savesTokensOnlyToPrimaryAccessor
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" tenantId:@"tid"];

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
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 0);

    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *legacyTokens = [self getAllLegacyTokens];
    XCTAssertEqual([legacyTokens count], 1);

    MSIDLegacySingleResourceToken *token = legacyTokens[0];

    XCTAssertEqualObjects(token.accessTokenType, @"Bearer");
    XCTAssertEqualObjects(token.idToken, idToken);
    XCTAssertEqualObjects(token.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(token.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([token.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNil(token.extendedExpireTime);
    XCTAssertEqualObjects(token.resource, @"graph");
    XCTAssertEqual(token.credentialType, MSIDLegacySingleResourceTokenType);
    XCTAssertEqualObjects(token.authority.url.absoluteString, @"https://login.windows.net/contoso.com");
    XCTAssertEqualObjects(token.clientId, @"test_client_id");
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(token.additionalServerInfo, [NSDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, @"refresh token");
    XCTAssertNil(token.familyId);

    NSArray *defaultAccessTokens = [self getAllAccessTokens];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 0);

    NSArray *defaultIDTokens = [self getAllIDTokens];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_otherAccessor allAccountsForAuthority:authority
                                                       clientId:@"test_client_id"
                                                       familyId:nil
                                                        context:nil
                                                          error:&error];

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
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 0);

    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *legacyTokens = [self getAllLegacyTokens];
    XCTAssertEqual([legacyTokens count], 1);

    MSIDLegacySingleResourceToken *token = legacyTokens[0];

    XCTAssertEqualObjects(token.accessTokenType, @"Bearer");
    XCTAssertNil(token.idToken);
    XCTAssertNil(token.accountIdentifier.legacyAccountId);
    XCTAssertEqualObjects(token.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([token.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNil(token.extendedExpireTime);
    XCTAssertEqualObjects(token.resource, @"graph");
    XCTAssertEqual(token.credentialType, MSIDLegacySingleResourceTokenType);
    XCTAssertEqualObjects(token.authority.url.absoluteString, @"https://login.windows.net/contoso.com");
    XCTAssertEqualObjects(token.clientId, @"test_client_id");
    XCTAssertNil(token.accountIdentifier.homeAccountId);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, @"refresh token");
    XCTAssertNil(token.familyId);

    NSArray *defaultAccessTokens = [self getAllAccessTokens];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 0);

    NSArray *defaultIDTokens = [self getAllIDTokens];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_otherAccessor allAccountsForAuthority:authority
                                                       clientId:@"test_client_id"
                                                       familyId:nil
                                                        context:nil
                                                          error:&error];

    XCTAssertNil(error);
    XCTAssertEqual([accounts count], 0);
}

- (void)testSaveTokensWithFactoryAndBrokerResponse_whenSaveSSOStateOnlyFalse_savesTokensToBothAccessors
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" tenantId:@"tid"];

    NSString *clientInfoString = [@{ @"uid" : @"uid", @"utid" : @"utid"} msidBase64UrlJson];

    NSDictionary *responseDictionary = @{@"access_token": @"access token",
                                         @"refresh_token": @"refresh token",
                                         @"resource": @"graph resource",
                                         @"token_type": @"Bearer",
                                         @"expires_in": @"3600",
                                         @"client_info": clientInfoString,
                                         @"id_token": idToken,
                                         @"client_id": @"test_client_id",
                                         @"authority": @"https://login.microsoftonline.com/common"
                                         };

    NSError *error = nil;
    MSIDBrokerResponse *brokerResponse = [[MSIDBrokerResponse alloc] initWithDictionary:responseDictionary error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(brokerResponse);

    BOOL result = [_legacyAccessor saveTokensWithBrokerResponse:brokerResponse
                                               saveSSOStateOnly:NO
                                                        context:nil
                                                          error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    MSIDLegacyAccessToken *accessToken = accessTokens[0];

    XCTAssertEqualObjects(accessToken.accessTokenType, @"Bearer");
    XCTAssertEqualObjects(accessToken.idToken, idToken);
    XCTAssertEqualObjects(accessToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([accessToken.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNil(accessToken.extendedExpireTime);
    XCTAssertEqualObjects(accessToken.resource, @"graph resource");
    XCTAssertEqual(accessToken.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(accessToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"uid.utid");

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];

    XCTAssertEqualObjects(refreshToken.idToken, idToken);
    XCTAssertEqualObjects(refreshToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertNil(refreshToken.familyId);
    XCTAssertEqual(refreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid.utid");

    NSArray *allTokens = [_legacyAccessor allTokensWithContext:nil error:nil];
    XCTAssertEqual([allTokens count], 2);

    // Now check default accessor
    NSArray *defaultAccessTokens = [self getAllAccessTokens];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 1);

    MSIDRefreshToken *defaultRefreshToken = defaultRefreshTokens[0];
    XCTAssertEqualObjects(defaultRefreshToken.refreshToken, @"refresh token");
    XCTAssertNil(defaultRefreshToken.familyId);
    XCTAssertEqual(defaultRefreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(defaultRefreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(defaultRefreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(defaultRefreshToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(defaultRefreshToken.additionalServerInfo, nil);

    NSArray *defaultIDTokens = [self getAllIDTokens];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *accounts = [_otherAccessor allAccountsForAuthority:authority
                                                       clientId:@"test_client_id"
                                                       familyId:nil
                                                        context:nil
                                                          error:&error];

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
    XCTAssertNil(account.alternativeAccountId);
    XCTAssertEqualObjects(account.authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
}

- (void)testSaveTokensWithFactoryAndBrokerResponse_whenSaveSSOStateOnlyTrue_savesOnlySSOStateToBothAccessors
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" tenantId:@"tid"];

    NSString *clientInfoString = [@{ @"uid" : @"uid", @"utid" : @"utid"} msidBase64UrlJson];

    NSDictionary *responseDictionary = @{@"access_token": @"access token",
                                         @"refresh_token": @"refresh token",
                                         @"resource": @"graph resource",
                                         @"token_type": @"Bearer",
                                         @"expires_in": @"3600",
                                         @"client_info": clientInfoString,
                                         @"id_token": idToken,
                                         @"client_id": @"test_client_id",
                                         @"authority": @"https://login.microsoftonline.com/common"
                                         };

    NSError *error = nil;
    MSIDBrokerResponse *brokerResponse = [[MSIDBrokerResponse alloc] initWithDictionary:responseDictionary error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(brokerResponse);

    BOOL result = [_legacyAccessor saveTokensWithBrokerResponse:brokerResponse
                                               saveSSOStateOnly:YES
                                                        context:nil
                                                          error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 0);

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];

    XCTAssertEqualObjects(refreshToken.idToken, idToken);
    XCTAssertEqualObjects(refreshToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertNil(refreshToken.familyId);
    XCTAssertEqual(refreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid.utid");

    NSArray *allTokens = [_legacyAccessor allTokensWithContext:nil error:nil];
    XCTAssertEqual([allTokens count], 1);

    // Now check default accessor
    NSArray *defaultAccessTokens = [self getAllAccessTokens];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 1);

    MSIDRefreshToken *defaultRefreshToken = defaultRefreshTokens[0];
    XCTAssertEqualObjects(defaultRefreshToken.refreshToken, @"refresh token");
    XCTAssertNil(defaultRefreshToken.familyId);
    XCTAssertEqual(defaultRefreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(defaultRefreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(defaultRefreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(defaultRefreshToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(defaultRefreshToken.additionalServerInfo, nil);

    NSArray *defaultIDTokens = [self getAllIDTokens];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *accounts = [_otherAccessor allAccountsForAuthority:authority
                                                       clientId:@"test_client_id"
                                                       familyId:nil
                                                        context:nil
                                                          error:&error];

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
    XCTAssertNil(account.alternativeAccountId);
    XCTAssertEqualObjects(account.authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
}

- (void)testSaveTokens_withNoHomeAccountIdForSecondaryFormat_shouldSaveToLegacyFormatOnly
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" tenantId:@"tid"];

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
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *legacyTokens = [self getAllLegacyTokens];
    XCTAssertEqual([legacyTokens count], 0);

    NSArray *defaultAccessTokens = [self getAllAccessTokens];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 0);

    NSArray *defaultIDTokens = [self getAllIDTokens];
    XCTAssertEqual([defaultIDTokens count], 0);
}

- (void)testSaveTokensWithRequestParams_whenNoRefreshTokenReturnedInResponse_shouldOnlySaveAccessTokensToPrimaryCache
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:@"upn@test.com" tenantId:@"tid"];

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
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *defaultAccessTokens = [self getAllAccessTokens];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 0);

    NSArray *defaultIDTokens = [self getAllIDTokens];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *allAccounts = [_otherAccessor allAccountsForAuthority:authority
                                                          clientId:@"test_client_id"
                                                          familyId:nil
                                                           context:nil
                                                             error:&error];

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
    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn2@test.com" homeAccountId:nil];
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
    XCTAssertEqualObjects(legacyRefreshToken.accountIdentifier.legacyAccountId, @"upn2@test.com");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.windows.net/common");
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
    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn2@test.com" homeAccountId:nil];
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
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.windows.net/common");
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
    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 4);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn2@test.com" homeAccountId:nil];
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
    XCTAssertEqualObjects(legacyRefreshToken.accountIdentifier.legacyAccountId, @"upn2@test.com");
    XCTAssertEqualObjects(refreshToken.clientId, @"foci-2");
    XCTAssertEqualObjects(refreshToken.familyId, @"2");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.windows.net/common");
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
    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 4);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn2@test.com" homeAccountId:nil];
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
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.windows.net/common");
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
    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:nil];
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
    XCTAssertEqualObjects(legacyRefreshToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(refreshToken.clientId, @"foci-1");
    XCTAssertEqualObjects(refreshToken.familyId, @"1");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.windows.net/common");
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
    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:nil];
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
    XCTAssertEqualObjects(legacyRefreshToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertNil(refreshToken.familyId);
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.windows.net/common");
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

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:nil];
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

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:nil];
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

- (void)testGetRefreshToken_whenNoLegacyUserId_onlyHomeAccountId_andTokenInPrimaryCache_shouldReturnToken
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid2"
                         utid:@"utid2"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"uid2"
                         utid:@"utid2"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
             additionalFields:nil
                     accessor:_nonSSOAccessor];

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

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:@"uid2.utid2"];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:configuration
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNotNil(refreshToken);
    XCTAssertNil(error);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid2.utid2");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.legacyAccountId, @"upn2@test.com");
}

- (void)testGetRefreshToken_whenNoLegacyUserId_onlyHomeAccountId_andTokenInPrimaryCacheWithoutUniqueUser_shouldReturnSingleTokne
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

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:@"uid2.utid2"];
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

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:nil];
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

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:nil];
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

    NSArray *allAccounts = [_otherAccessor allAccountsForAuthority:authority
                                                          clientId:@"test_client_id"
                                                          familyId:@"1"
                                                           context:nil
                                                             error:&error];

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

    NSArray *accounts = [_legacyAccessor allAccountsForAuthority:authority
                                                        clientId:@"test_client_id"
                                                        familyId:nil
                                                         context:nil
                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
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

    NSArray *accounts = [_legacyAccessor allAccountsForAuthority:authority
                                                        clientId:nil
                                                        familyId:@"1"
                                                         context:nil
                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
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

    NSArray *accounts = [_legacyAccessor allAccountsForAuthority:authority
                                                        clientId:@"test_client_id"
                                                        familyId:nil
                                                         context:nil
                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
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

    NSArray *accounts = [_legacyAccessor allAccountsForAuthority:authority
                                                        clientId:nil
                                                        familyId:@"1"
                                                         context:nil
                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
}

#pragma mark - Get single account

- (void)testGetAccount_whenNoAccountsInCache_shouldReturnNilAndNilError
{
    NSError *error = nil;

    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"legacy.id"
                                                                                 homeAccountId:@"home.id"];

    MSIDAccount *account = [_legacyAccessor accountForIdentifier:identifier
                                                        familyId:nil
                                                   configuration:configuration
                                                         context:nil
                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNil(account);
}

- (void)testGetAccount_whenAccountInPrimaryCache_shouldReturnAccountAndNilError
{
    [self saveResponseWithUPN:@"legacy.id"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"home"
                         utid:@"id"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:@{@"foci": @"1"}
                     accessor:_legacyAccessor];

    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"legacy.id"
                                                                                 homeAccountId:nil];

    NSError *error = nil;

    MSIDAccount *account = [_legacyAccessor accountForIdentifier:identifier
                                                        familyId:nil
                                                   configuration:configuration
                                                         context:nil
                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"home.id");
    XCTAssertEqualObjects(account.accountIdentifier.legacyAccountId, @"legacy.id");
}

- (void)testGetAccount_whenAccountInSecondaryCache_shouldReturnAccountAndNilError
{
    [self saveResponseWithUPN:@"legacy.id"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
             responseResource:@"graph"
                inputResource:@"graph"
                          uid:@"home"
                         utid:@"id"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
             additionalFields:nil
                     accessor:_otherAccessor];

    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil
                                                                                 homeAccountId:@"home.id"];

    NSError *error = nil;

    MSIDAccount *account = [_legacyAccessor accountForIdentifier:identifier
                                                        familyId:nil
                                                   configuration:configuration
                                                         context:nil
                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"home.id");
    XCTAssertEqualObjects(account.accountIdentifier.legacyAccountId, @"legacy.id");
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
    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id2"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDLegacyAccessToken *accessToken = [_legacyAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accessToken);
    XCTAssertEqualObjects(accessToken.accessToken, @"access token 2");
    XCTAssertEqualObjects(accessToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id2");
    XCTAssertEqualObjects(accessToken.authority.url.absoluteString, @"https://login.windows.net/common");
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
    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:nil];
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
    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:nil];
    NSError *error = nil;
    MSIDLegacyAccessToken *accessToken = [_legacyAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accessToken);
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualObjects(accessToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.authority.url.absoluteString, @"https://login.windows.net/common");
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
    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:nil];
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
    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *legacyTokens = [self getAllLegacyTokens];
    XCTAssertEqual([legacyTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.com/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDLegacySingleResourceToken *accessToken = [_legacyAccessor getSingleResourceTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accessToken);
    XCTAssertEqualObjects(accessToken.accessToken, @"access token 2");
    XCTAssertEqualObjects(accessToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.refreshToken, @"refresh token 2");
    XCTAssertEqualObjects(accessToken.authority.url.absoluteString, @"https://login.windows.com/common");
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
    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *legacyTokens = [self getAllLegacyTokens];
    XCTAssertEqual([legacyTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:nil];
    NSError *error = nil;
    MSIDLegacySingleResourceToken *accessToken = [_legacyAccessor getSingleResourceTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accessToken);
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualObjects(accessToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.refreshToken, @"refresh token");
    XCTAssertEqualObjects(accessToken.authority.url.absoluteString, @"https://login.windows.net/common");
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

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];
    refreshToken.refreshToken = @"outdated refresh token";

    NSError *error = nil;
    BOOL result = [_legacyAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remaininRefreshTokens = [self getAllLegacyRefreshTokens];
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

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];

    NSError *error = nil;
    BOOL result = [_legacyAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remaininRefreshTokens = [self getAllLegacyRefreshTokens];
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

    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];

    NSError *error = nil;
    BOOL result = [_legacyAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remaininRefreshTokens = [self getAllRefreshTokens];
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

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyAccessToken *firstToken = accessTokens[0];
    MSIDLegacyAccessToken *secondToken = accessTokens[1];

    NSError *error = nil;
    BOOL result = [_legacyAccessor removeAccessToken:secondToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainingAccessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([remainingAccessTokens count], 1);
    XCTAssertEqualObjects(remainingAccessTokens[0], firstToken);

    NSArray *remaininRefreshTokens = [self getAllLegacyRefreshTokens];
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

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn2@test.com" homeAccountId:nil];

    NSError *error = nil;
    BOOL result = [_legacyAccessor clearCacheForAccount:account context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainingAccessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([remainingAccessTokens count], 1);
    MSIDLegacyAccessToken *remainingAccessToken = remainingAccessTokens[0];
    XCTAssertEqualObjects(remainingAccessToken.accountIdentifier.legacyAccountId, @"upn@test.com");

    NSArray *remaininRefreshTokens = [self getAllLegacyRefreshTokens];
    MSIDLegacyRefreshToken *reminingRefreshToken = remaininRefreshTokens[0];
    XCTAssertEqual([remaininRefreshTokens count], 1);
    XCTAssertEqualObjects(reminingRefreshToken.accountIdentifier.legacyAccountId, @"upn@test.com");
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

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *otherRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([otherRefreshTokens count], 2);

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn2@test.com" homeAccountId:nil];

    NSError *error = nil;
    BOOL result = [_legacyAccessor clearCacheForAccount:account clientId:@"test_client_id" context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainingAccessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([remainingAccessTokens count], 1);
    MSIDLegacyAccessToken *remainingAccessToken = remainingAccessTokens[0];
    XCTAssertEqualObjects(remainingAccessToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects([remainingAccessTokens[0] clientId], @"test_client_id2");

    NSArray *remaininRefreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([remaininRefreshTokens count], 1);
    MSIDLegacyRefreshToken *remainingRefreshToken = remaininRefreshTokens[0];
    XCTAssertEqualObjects(remainingRefreshToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects([remaininRefreshTokens[0] clientId], @"test_client_id2");

    NSArray *otherRemainingRefreshTokens = [self getAllRefreshTokens];
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

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:nil];

    NSError *error = nil;
    BOOL result = [_legacyAccessor clearCacheForAccount:account clientId:@"test_client_id" context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainingAccessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([remainingAccessTokens count], 1);
    XCTAssertEqualObjects([remainingAccessTokens[0] clientId], @"test_client_id2");

    NSArray *remaininRefreshTokens = [self getAllLegacyRefreshTokens];
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
    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.microsoftonline.com/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:nil];
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
    XCTAssertEqualObjects(legacyRefreshToken.accountIdentifier.legacyAccountId, @"upn@test.com");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(refreshToken.storageAuthority.url.absoluteString, @"https://login.windows.net/common");
}

#pragma mark - Get App Metadata
- (void)testSaveTokensWithFactory_whenMultiResourceFOCIResponse_savesAppMetadata
{
    
    MSIDAADTokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponseWithAdditionalFields:@{@"foci": @"familyId"}];
    
    NSError *error = nil;
    MSIDConfiguration *configuration = [MSIDTestConfiguration defaultParams];
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:configuration
                                                      response:response
                                                       context:nil
                                                         error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    MSIDAppMetadataCacheItem *appMetadata = [_otherAccessor getAppAppMetadataForConfiguration:configuration
                                                                                      context:nil
                                                                                        error:nil];
    
    XCTAssertNotNil(appMetadata);
    XCTAssertEqualObjects(appMetadata.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(appMetadata.environment, configuration.authority.environment);
    XCTAssertEqualObjects(appMetadata.familyId, @"familyId");
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
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:upn tenantId:@"tid"];

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

    NSError *error = nil;
    // Save first token
    BOOL result = [accessor saveTokensWithConfiguration:configuration
                                               response:response
                                                context:nil
                                                  error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (NSArray *)getAllLegacyAccessTokens
{
    return [self getAllTokensWithType:MSIDAccessTokenType class:MSIDLegacyAccessToken.class accessor:_legacyAccessor];
}

- (NSArray *)getAllLegacyRefreshTokens
{
    return [self getAllTokensWithType:MSIDRefreshTokenType class:MSIDLegacyRefreshToken.class accessor:_legacyAccessor];
}

- (NSArray *)getAllAccessTokens
{
    return [self getAllTokensWithType:MSIDAccessTokenType class:MSIDAccessToken.class accessor:_otherAccessor];
}

- (NSArray *)getAllRefreshTokens
{
    return [self getAllTokensWithType:MSIDRefreshTokenType class:MSIDRefreshToken.class accessor:_otherAccessor];
}

- (NSArray *)getAllIDTokens
{
    return [self getAllTokensWithType:MSIDIDTokenType class:MSIDIdToken.class accessor:_otherAccessor];
}

- (NSArray *)getAllLegacyTokens
{
    return [self getAllTokensWithType:MSIDLegacySingleResourceTokenType class:MSIDLegacySingleResourceToken.class accessor:_legacyAccessor];
}

- (NSArray *)getAllTokensWithType:(MSIDCredentialType)type class:(Class)typeClass accessor:(id<MSIDCacheAccessor>)accessor
{
    NSError *error = nil;

    NSArray *allTokens = [accessor allTokensWithContext:nil error:&error];
    XCTAssertNil(error);

    NSMutableArray *results = [NSMutableArray array];

    for (MSIDBaseToken *token in allTokens)
    {
        if ([token supportsCredentialType:type]
            && [token isKindOfClass:typeClass])
        {
            [results addObject:token];
        }
    }

    return results;
}

@end
