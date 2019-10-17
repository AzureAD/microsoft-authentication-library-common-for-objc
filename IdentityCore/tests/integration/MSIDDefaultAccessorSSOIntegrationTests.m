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
#import "MSIDTokenCacheDataSource.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDCacheKey.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTestConfiguration.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"
#import "MSIDAccount.h"
#import "MSIDLegacySingleResourceToken.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDLegacyRefreshToken.h"
#import "MSIDTestIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDBrokerResponse.h"
#import "MSIDAADIdTokenClaimsFactory.h"
#import "MSIDMacTokenCache.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAADAuthority.h"
#import "MSIDAadAuthorityCacheRecord.h"

@interface MSIDDefaultAccessorSSOIntegrationTests : XCTestCase
{
    MSIDDefaultTokenCacheAccessor *_defaultAccessor;
    MSIDDefaultTokenCacheAccessor *_nonSSOAccessor;
    MSIDLegacyTokenCacheAccessor *_otherAccessor;
    id<MSIDTokenCacheDataSource> _defaultDataSource;
    id<MSIDTokenCacheDataSource> _otherDataSource;

}

@end

@implementation MSIDDefaultAccessorSSOIntegrationTests

- (void)setUp
{

#if TARGET_OS_IOS
    _defaultDataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
    _otherDataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
#else
    // TODO: this should be replaced with a real macOS datasource instead
    _otherDataSource = [MSIDMacTokenCache defaultCache];
    _defaultDataSource = [[MSIDTestCacheDataSource alloc] init];
#endif
    MSIDOauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    _otherAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:_otherDataSource otherCacheAccessors:nil factory:factory];
    _defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:_defaultDataSource otherCacheAccessors:@[_otherAccessor] factory:factory];
    _nonSSOAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:_defaultDataSource otherCacheAccessors:nil factory:factory];
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
    [_defaultDataSource removeItemsWithKey:[MSIDCacheKey new] context:nil error:nil];
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
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"upn@test.com" subject:@"subject" givenName:@"Hello" familyName:@"World" name:@"Hello World" version:@"2.0" tid:@"tenantId.onmicrosoft.com"];

    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"user.read", @"user.write", nil];
    MSIDTokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:@"access token"
                                                                            RT:@"refresh token"
                                                                        scopes:scopes
                                                                       idToken:idToken
                                                                           uid:@"uid"
                                                                          utid:@"utid"
                                                                      familyId:nil];


    NSError *error = nil;
    BOOL result = [_nonSSOAccessor saveTokensWithConfiguration:[MSIDTestConfiguration defaultParams]
                                                      response:response
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    MSIDAccessToken *accessToken = accessTokens[0];
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([accessToken.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNotNil(accessToken.extendedExpireTime);
    XCTAssertEqualObjects(accessToken.scopes, scopes);
    XCTAssertEqual(accessToken.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(accessToken.authority.url.absoluteString, @"https://login.microsoftonline.com/tenantId.onmicrosoft.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNotNil(accessToken.additionalServerInfo[MSID_EXTENDED_EXPIRES_ON_CACHE_KEY]);

    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDRefreshToken *refreshToken = refreshTokens[0];
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertNil(refreshToken.familyId);
    XCTAssertEqual(refreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(refreshToken.additionalServerInfo, [NSDictionary dictionary]);

    NSArray *idTokens = [self getAllIDTokens];
    XCTAssertEqual([idTokens count], 1);

    MSIDIdToken *defaultIDToken = idTokens[0];
    XCTAssertEqualObjects(defaultIDToken.rawIdToken, idToken);
    XCTAssertEqual(defaultIDToken.credentialType, MSIDIDTokenType);
    XCTAssertEqualObjects(defaultIDToken.authority.url.absoluteString, @"https://login.microsoftonline.com/tenantId.onmicrosoft.com");
    XCTAssertEqualObjects(defaultIDToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(defaultIDToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(defaultIDToken.additionalServerInfo, [NSDictionary dictionary]);

    NSArray *allTokens = [_nonSSOAccessor allTokensWithContext:nil error:nil];
    XCTAssertEqual([allTokens count], 3);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id"
                                                         familyId:nil
                                                          context:nil
                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertEqual([accounts count], 1);

    MSIDAccount *account = accounts[0];
    XCTAssertEqual(account.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account.username, @"upn@test.com");
    XCTAssertEqualObjects(account.givenName, @"Hello");
    XCTAssertNil(account.middleName);
    XCTAssertEqualObjects(account.familyName, @"World");
    XCTAssertEqualObjects(account.name, @"Hello World");
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNil(account.alternativeAccountId);
    XCTAssertEqualObjects(account.authority.url.absoluteString, @"https://login.microsoftonline.com/tenantId.onmicrosoft.com");
}

- (void)testSaveTokensWithFactory_whenMultiResourceResponse_savesTokensOnlyToDefaultAccessor
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"upn@test.com" subject:@"subject" givenName:@"Hello" familyName:@"World" name:@"Hello World" version:@"2.0" tid:@"tenantId.onmicrosoft.com"];

    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"user.read", @"user.write", nil];
    MSIDTokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:@"access token"
                                                                            RT:@"refresh token"
                                                                        scopes:scopes
                                                                       idToken:idToken
                                                                           uid:@"uid"
                                                                          utid:@"utid"
                                                                      familyId:nil];
    NSError *error = nil;
    BOOL result = [_defaultAccessor saveTokensWithConfiguration:[MSIDTestConfiguration defaultParams]
                                                       response:response
                                                        context:nil
                                                          error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    MSIDAccessToken *accessToken = accessTokens[0];
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([accessToken.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNotNil(accessToken.extendedExpireTime);
    XCTAssertEqualObjects(accessToken.scopes, scopes);
    XCTAssertEqual(accessToken.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(accessToken.authority.url.absoluteString, @"https://login.microsoftonline.com/tenantId.onmicrosoft.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNotNil(accessToken.additionalServerInfo[MSID_EXTENDED_EXPIRES_ON_CACHE_KEY]);

    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDRefreshToken *refreshToken = refreshTokens[0];
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertNil(refreshToken.familyId);
    XCTAssertEqual(refreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(refreshToken.additionalServerInfo, [NSDictionary dictionary]);

    NSArray *idTokens = [self getAllIDTokens];
    XCTAssertEqual([idTokens count], 1);

    MSIDIdToken *defaultIDToken = idTokens[0];
    XCTAssertEqualObjects(defaultIDToken.rawIdToken, idToken);
    XCTAssertEqual(defaultIDToken.credentialType, MSIDIDTokenType);
    XCTAssertEqualObjects(defaultIDToken.authority.url.absoluteString, @"https://login.microsoftonline.com/tenantId.onmicrosoft.com");
    XCTAssertEqualObjects(defaultIDToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(defaultIDToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(defaultIDToken.additionalServerInfo, [NSDictionary dictionary]);

    NSArray *allTokens = [_nonSSOAccessor allTokensWithContext:nil error:nil];
    XCTAssertEqual([allTokens count], 3);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id"
                                                         familyId:nil
                                                          context:nil
                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertEqual([accounts count], 1);

    MSIDAccount *account = accounts[0];
    XCTAssertEqual(account.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account.username, @"upn@test.com");
    XCTAssertEqualObjects(account.givenName, @"Hello");
    XCTAssertNil(account.middleName);
    XCTAssertEqualObjects(account.familyName, @"World");
    XCTAssertEqualObjects(account.name, @"Hello World");
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNil(account.alternativeAccountId);
    XCTAssertEqualObjects(account.authority.url.absoluteString, @"https://login.microsoftonline.com/tenantId.onmicrosoft.com");

    // Now check legacy accessor
    NSArray *legacyAccessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([legacyAccessTokens count], 0);

    NSArray *legacyRefreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([legacyRefreshTokens count], 0);
}

- (void)testSaveTokensWithFactory_whenMultiResourceFOCIResponse_savesTokensOnlyToDefaultAccessor
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"upn@test.com" subject:@"subject" givenName:@"Hello" familyName:@"World" name:@"Hello World" version:@"2.0" tid:@"tenantId.onmicrosoft.com"];

    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"user.read", @"user.write", nil];
    MSIDTokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:@"access token"
                                                                            RT:@"refresh token"
                                                                        scopes:scopes
                                                                       idToken:idToken
                                                                           uid:@"uid"
                                                                          utid:@"utid"
                                                                      familyId:@"2"];
    NSError *error = nil;
    BOOL result = [_defaultAccessor saveTokensWithConfiguration:[MSIDTestConfiguration defaultParams]
                                                       response:response
                                                        context:nil
                                                          error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *legacyAccessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([legacyAccessTokens count], 0);

    NSArray *legacyRefreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([legacyRefreshTokens count], 0);

    NSArray *defaultAccessTokens = [self getAllAccessTokens];
    XCTAssertEqual([defaultAccessTokens count], 1);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 2);

    MSIDRefreshToken *defaultRefreshToken1 = defaultRefreshTokens[0];
    MSIDRefreshToken *defaultRefreshToken2 = defaultRefreshTokens[1];

    MSIDRefreshToken *copiedRefreshToken = [defaultRefreshToken1 copy];
    copiedRefreshToken.familyId = nil;

    XCTAssertTrue([defaultRefreshTokens containsObject:copiedRefreshToken]);

    copiedRefreshToken.familyId = @"2";
    XCTAssertTrue([defaultRefreshTokens containsObject:copiedRefreshToken]);
    XCTAssertEqualObjects(defaultRefreshToken1.clientId, @"test_client_id");
    XCTAssertEqualObjects(defaultRefreshToken2.clientId, @"test_client_id");

    NSArray *defaultIDTokens = [self getAllIDTokens];
    XCTAssertEqual([defaultIDTokens count], 1);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *clientAccounts = [_otherAccessor allAccountsForAuthority:authority
                                                             clientId:@"test_client_id"
                                                             familyId:nil
                                                              context:nil
                                                                error:&error];

    XCTAssertEqual([clientAccounts count], 0);

    NSArray *familyAccounts = [_otherAccessor allAccountsForAuthority:authority
                                                             clientId:nil
                                                             familyId:@"2"
                                                              context:nil
                                                                error:&error];

    XCTAssertEqual([familyAccounts count], 0);

    NSArray *allAccounts = [_otherAccessor allAccountsForAuthority:authority
                                                          clientId:@"test_client_id"
                                                          familyId:@"2"
                                                           context:nil
                                                             error:&error];

    XCTAssertEqual([allAccounts count], 0);
}


- (void)testSaveTokensWithFactoryAndBrokerResponse_shouldFailWithUnsupportedError
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"upn@test.com" subject:@"subject" givenName:@"Hello" familyName:@"World" name:@"Hello World" version:@"2.0" tid:@"tenantId.onmicrosoft.com"];

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

    BOOL result = [_defaultAccessor saveTokensWithBrokerResponse:brokerResponse
                                                   appIdentifier:nil
                                                    enrollmentId:nil
                                                saveSSOStateOnly:NO
                                                         context:nil
                                                           error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorUnsupportedFunctionality);
}

- (void)testSaveTokens_withNoHomeAccountIdForDefaultFormat_shouldReturnNoAndFillError
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"upn@test.com" subject:@"subject" givenName:@"Hello" familyName:@"World" name:@"Hello World" version:@"2.0" tid:@"tenantId.onmicrosoft.com"];

    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"user.read", @"user.write", nil];
    MSIDTokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:@"access token"
                                                                            RT:@"refresh token"
                                                                        scopes:scopes
                                                                       idToken:idToken
                                                                           uid:nil
                                                                          utid:nil
                                                                      familyId:nil];

    NSError *error = nil;
    BOOL result = [_defaultAccessor saveTokensWithConfiguration:[MSIDTestConfiguration defaultParams]
                                                       response:response
                                                        context:nil
                                                          error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 0);

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *legacyTokens = [self getAllLegacyTokens];
    XCTAssertEqual([legacyTokens count], 0);

    NSArray *defaultAccessTokens = [self getAllAccessTokens];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 0);

    NSArray *defaultIDTokens = [self getAllIDTokens];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id"
                                                         familyId:nil
                                                          context:nil
                                                            error:&error];

    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 0);
}

- (void)testSaveTokensWithRequestParams_whenNoRefreshTokenReturnedInResponse_shouldOnlySaveAccessAndIDTokensToPrimaryCacheReturnYES
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"upn@test.com" subject:@"subject" givenName:@"Hello" familyName:@"World" name:@"Hello World" version:@"2.0" tid:@"tenantId.onmicrosoft.com"];

    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"user.read", @"user.write", nil];
    MSIDTokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:@"access token"
                                                                            RT:nil
                                                                        scopes:scopes
                                                                       idToken:idToken
                                                                           uid:@"uid"
                                                                          utid:@"utid"
                                                                      familyId:nil];

    NSError *error = nil;
    BOOL result = [_defaultAccessor saveTokensWithConfiguration:[MSIDTestConfiguration defaultParams]
                                                       response:response
                                                        context:nil
                                                          error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokens count], 0);

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *legacyTokens = [self getAllLegacyTokens];
    XCTAssertEqual([legacyTokens count], 0);

    NSArray *defaultAccessTokens = [self getAllAccessTokens];
    XCTAssertEqual([defaultAccessTokens count], 1);

    NSArray *defaultRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([defaultRefreshTokens count], 0);

    NSArray *defaultIDTokens = [self getAllIDTokens];
    XCTAssertEqual([defaultIDTokens count], 1);

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
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:@"uid2.utid"];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_defaultAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:configuration
                                                                          context:nil
                                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token 2");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid2.utid");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.windows.net/common");
}

- (void)testGetRefreshTokenWithAccount_whenNoFamilyId_andTokenInSecondaryAccessor_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
                     familyId:nil
                     accessor:_otherAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *legacyRefreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([legacyRefreshTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:@"uid2.utid"];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_defaultAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:configuration
                                                                          context:nil
                                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token 2");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid2.utid");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.windows.net/common");
}

- (void)testGetRefreshTokenWithAccount_whenFamilyIdProvided_andTokenInPrimaryAccessor_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"2"
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 4);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id2"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:@"uid2.utid"];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_defaultAccessor getRefreshTokenWithAccount:account
                                                                         familyId:@"3"
                                                                    configuration:configuration
                                                                          context:nil
                                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token 2");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid2.utid");
    XCTAssertEqualObjects(refreshToken.familyId, @"3");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.windows.net/common");
}

- (void)testGetRefreshTokenWithAccount_whenFamilyIdProvided_andTokenInSecondaryAccessor_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"2"
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
                     familyId:@"3"
                     accessor:_otherAccessor];

    // Check cache state
    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *legacyRefreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([legacyRefreshTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id2"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:@"uid2.utid"];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_defaultAccessor getRefreshTokenWithAccount:account
                                                                         familyId:@"3"
                                                                    configuration:configuration
                                                                          context:nil
                                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token 2");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid2.utid");
    XCTAssertEqualObjects(refreshToken.familyId, @"3");
    XCTAssertEqualObjects(refreshToken.clientId, @"foci-3");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.windows.net/common");
}

- (void)testGetRefreshTokenWithAccount_whenFamilyIdProvided_andTokensInBothAccessors_shouldReturnTokenFromPrimary
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
                     familyId:@"3"
                     accessor:_otherAccessor];

    // Check cache state
    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *legacyRefreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([legacyRefreshTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id2"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:@"uid2.utid"];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_defaultAccessor getRefreshTokenWithAccount:account
                                                                         familyId:@"3"
                                                                    configuration:configuration
                                                                          context:nil
                                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid2.utid");
    XCTAssertEqualObjects(refreshToken.familyId, @"3");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.windows.net/common");
}

- (void)testGetRefreshTokenWithAccount_whenNoFamilyIdProvided_andTokensInBothAccessors_shouldReturnTokenFromPrimary
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
                     familyId:nil
                     accessor:_otherAccessor];

    // Check cache state
    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *legacyRefreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([legacyRefreshTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:@"uid2.utid"];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_defaultAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:configuration
                                                                          context:nil
                                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid2.utid");
    XCTAssertEqualObjects(refreshToken.familyId, nil);
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.windows.net/common");
}

- (void)testGetRefreshTokenWithAccount_whenFamilyIdProvided_andOnlyClientTokenInPrimaryAccessor_shouldReturnNil
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token 2"
                     familyId:nil
                     accessor:_otherAccessor];

    // Check cache state
    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *legacyRefreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([legacyRefreshTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:@"uid2.utid"];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_defaultAccessor getRefreshTokenWithAccount:account
                                                                         familyId:@"3"
                                                                    configuration:configuration
                                                                          context:nil
                                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNil(refreshToken);
}

- (void)testGetRefreshToken_whenNoHomeAccountId_onlyLegacyUserId_andTokenInPrimaryCache_shouldReturnToken
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id2"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token 2"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id2"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_defaultAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:configuration
                                                                          context:nil
                                                                            error:&error];

    XCTAssertNotNil(refreshToken);
    XCTAssertNil(error);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token 2");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid2.utid");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id2");
}

#pragma mark - Clear

- (void)testClearWithContext_whenTokensInBothCaches_shouldClearAllTokens
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_defaultAccessor];

    NSError *error = nil;
    NSArray *allTokens = [_defaultAccessor allTokensWithContext:nil error:&error];
    XCTAssertNotNil(allTokens);
    XCTAssertNil(error);
    XCTAssertEqual([allTokens count], 3);

    BOOL result = [_defaultAccessor clearWithContext:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    allTokens = [_defaultAccessor allTokensWithContext:nil error:&error];
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
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_defaultAccessor];

    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id"
                                                         familyId:nil
                                                          context:nil
                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid2.utid");
}

- (void)testAllAccountsWithEnvironment_whenFamilyIdProvided_andTokensInPrimaryCache_shouldReturnAccounts
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_defaultAccessor];

    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:nil
                                                         familyId:@"3"
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
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_otherAccessor];

    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id"
                                                         familyId:nil
                                                          context:nil
                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.givenName, @"Hello");
    XCTAssertEqualObjects(account.familyName, @"World");
    XCTAssertEqualObjects(account.username, @"upn@test.com");
    XCTAssertEqualObjects(account.name, @"Hello World");
}

- (void)testAllAccountsWithEnvironment_whenFamilyIdProvided_andTokensInBothCaches_shouldReturnAccounts
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_otherAccessor];

    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id2"
                                                         familyId:@"3"
                                                          context:nil
                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.givenName, @"Hello");
    XCTAssertEqualObjects(account.familyName, @"World");
    XCTAssertEqualObjects(account.username, @"upn@test.com");
    XCTAssertEqualObjects(account.name, @"Hello World");
}

- (void)testAllAccountsWithEnvironment_whenMatchingTokenOnlyInLegacyCache_andNoAliases_shouldReturnMatchingAccount
{
    // Save test response
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.microsoftonline.com/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token 2"
                     familyId:@"3"
                     accessor:_otherAccessor];

    // Test accounts retrieval
    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id"
                                                         familyId:@"3"
                                                          context:nil
                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.username, @"upn@test.com");
}

- (void)testAllAccountsWithEnvironment_whenTokensInBothCachesWithDifferentAuthorities_andNoAliases_shouldReturnMatchingAccount
{
    // Save test response
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.microsoftonline.com/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.microsoftonline.com/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token 2"
                     familyId:@"3"
                     accessor:_otherAccessor];

    // Test accounts retrieval
    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id"
                                                         familyId:@"3"
                                                          context:nil
                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.username, @"upn@test.com");
}

- (void)testAllAccountsWithEnvironment_whenTokensInBothCachesWithDifferentAuthorities_andNoAliases_andNilEnvironment_shouldReturnTwoAccounts
{
    // Save test response
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.microsoftonline.com/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.microsoftonline.com/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token 2"
                     familyId:@"3"
                     accessor:_otherAccessor];

    // Test accounts retrieval
    NSError *error = nil;

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:nil
                                                         clientId:@"test_client_id"
                                                         familyId:@"3"
                                                          context:nil
                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 2);
    MSIDAccount *firstAccount = accounts[0];
    XCTAssertEqualObjects(firstAccount.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(firstAccount.username, @"upn@test.com");

    MSIDAccount *secondAccount = accounts[1];
    XCTAssertEqualObjects(secondAccount.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(secondAccount.username, @"upn@test.com");
}

- (void)testAllAccountsWithEnvironment_whenTokensInBothCachesWithDifferentAuthorities_andAliasesAvailable_shouldReturnOneAccount
{
    // Save test response
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.microsoftonline.com/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.microsoftonline.com/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token 2"
                     familyId:@"3"
                     accessor:_otherAccessor];

    // Add authorities to cache
    MSIDAadAuthorityCacheRecord *record = [MSIDAadAuthorityCacheRecord new];
    record.networkHost = @"login.microsoftonline.com";
    record.cacheHost = @"login.windows.net";
    record.aliases = @[@"login.microsoftonline.com", @"login.windows.net", @"login.microsoft.com"];
    record.validated = YES;

    MSIDAadAuthorityCache *cache = [MSIDAadAuthorityCache sharedInstance];
    [cache setObject:record forKey:@"login.microsoftonline.com"];
    [cache setObject:record forKey:@"login.windows.net"];
    [cache setObject:record forKey:@"login.microsoft.com"];

    // Test accounts retrieval
    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoft.com/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id"
                                                         familyId:@"3"
                                                          context:nil
                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *firstAccount = accounts[0];
    XCTAssertEqualObjects(firstAccount.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(firstAccount.username, @"upn@test.com");
    XCTAssertEqualObjects(firstAccount.authority.environment, @"login.microsoft.com");

    accounts = [_defaultAccessor allAccountsForAuthority:nil
                                                clientId:@"test_client_id"
                                                familyId:@"3"
                                                 context:nil
                                                   error:&error];

    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 2);
}

- (void)testAllAccountsWithEnvironment_whenTokensInBothCachesWithDifferentAuthorities_andNoClientInfo_andAliasesAvailable_shouldReturnOneAccount
{
    // Save test response
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.microsoftonline.com/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:nil
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token 2"
                     familyId:@"3"
                     accessor:_otherAccessor];

    // Add authorities to cache
    MSIDAadAuthorityCacheRecord *record = [MSIDAadAuthorityCacheRecord new];
    record.networkHost = @"login.microsoftonline.com";
    record.cacheHost = @"login.windows.net";
    record.aliases = @[@"login.microsoftonline.com", @"login.windows.net", @"login.microsoft.com"];
    record.validated = YES;

    MSIDAadAuthorityCache *cache = [MSIDAadAuthorityCache sharedInstance];
    [cache setObject:record forKey:@"login.microsoftonline.com"];
    [cache setObject:record forKey:@"login.windows.net"];
    [cache setObject:record forKey:@"login.microsoft.com"];

    // Test accounts retrieval
    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id"
                                                         familyId:@"3"
                                                          context:nil
                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.givenName, @"Hello");
    XCTAssertEqualObjects(account.familyName, @"World");
    XCTAssertEqualObjects(account.username, @"upn@test.com");
    XCTAssertEqualObjects(account.name, @"Hello World");

    accounts = [_defaultAccessor allAccountsForAuthority:nil
                                                clientId:@"test_client_id"
                                                familyId:@"3"
                                                 context:nil
                                                   error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 2);
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

    MSIDAccount *account = [_defaultAccessor accountForIdentifier:identifier
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
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"home"
                         utid:@"id"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_defaultAccessor];

    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil
                                                                                 homeAccountId:@"home.id"];

    NSError *error = nil;

    MSIDAccount *account = [_defaultAccessor accountForIdentifier:identifier
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
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"home"
                         utid:@"id"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_otherAccessor];

    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"legacy.id"
                                                                                 homeAccountId:nil];

    NSError *error = nil;

    MSIDAccount *account = [_defaultAccessor accountForIdentifier:identifier
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
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing"
                  inputScopes:@"user.sing"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/utid"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.write"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:@"uid.utid"];
    NSError *error = nil;
    MSIDAccessToken *accessToken = [_defaultAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accessToken);
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.authority.url.absoluteString, @"https://login.windows.net/utid");
}

#pragma mark - Remove

- (void)testValidateAndRemoveRefreshToken_whenNilTokenProvided_shouldReturnError
{
    NSError *error = nil;
    BOOL result = [_defaultAccessor validateAndRemoveRefreshToken:nil context:nil error:&error];
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
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDRefreshToken *refreshToken = refreshTokens[0];
    refreshToken.refreshToken = @"outdated refresh token";

    NSError *error = nil;
    BOOL result = [_defaultAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remaininRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([remaininRefreshTokens count], 1);
}

- (void)testValidateAndRemoveRefreshToken_whenTokenProvided_andTokenFromPrimaryCache_shouldRemoveToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDRefreshToken *refreshToken = refreshTokens[0];

    NSError *error = nil;
    BOOL result = [_defaultAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remaininRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([remaininRefreshTokens count], 0);
}

- (void)testValidateAndRemoveRefreshToken_whenTokenProvided_butTokenFromSecondaryCache_shouldRemoveToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_otherAccessor];

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDRefreshToken *refreshToken = refreshTokens[0];

    NSError *error = nil;
    BOOL result = [_defaultAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remaininRefreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([remaininRefreshTokens count], 0);
}

- (void)testRemoveAccessToken_whenTokenProvided_shouldRemoveToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing"
                  inputScopes:@"user.sing"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDAccessToken *firstToken = accessTokens[0];
    MSIDAccessToken *secondToken = accessTokens[1];

    NSError *error = nil;
    BOOL result = [_defaultAccessor removeToken:secondToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainingAccessTokens = [self getAllAccessTokens];
    XCTAssertEqual([remainingAccessTokens count], 1);
    XCTAssertEqualObjects(remainingAccessTokens[0], firstToken);

    NSArray *remaininRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([remaininRefreshTokens count], 1);
}

- (void)testRemoveIDToken_whenTokenProvided_shouldRemoveToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id2"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing"
                  inputScopes:@"user.sing"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *idTokens = [self getAllIDTokens];
    XCTAssertEqual([idTokens count], 2);

    MSIDIdToken *firstToken = idTokens[0];
    MSIDIdToken *secondToken = idTokens[1];

    NSError *error = nil;
    BOOL result = [_defaultAccessor removeToken:secondToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainingIDTokens = [self getAllIDTokens];
    XCTAssertEqual([remainingIDTokens count], 1);
    XCTAssertEqualObjects(remainingIDTokens[0], firstToken);

    NSArray *remaininRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([remaininRefreshTokens count], 2);
}

- (void)testRemoveAccessToken_whenNilTokenProvided_shouldReturnError
{
    NSError *error = nil;
    BOOL result = [_defaultAccessor removeToken:nil context:nil error:&error];
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
               responseScopes:@"user.sing"
                  inputScopes:@"user.sing"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    NSError *error = nil;
    NSArray *allTokens = [_defaultAccessor allTokensWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allTokens);
    XCTAssertEqual([allTokens count], 3);
}

- (void)testGetAllTokensWithContext_whenTokensInSecondaryCache_shouldNotReturnTokens
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing"
                  inputScopes:@"user.sing"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_otherAccessor];

    NSError *error = nil;
    NSArray *allTokens = [_defaultAccessor allTokensWithContext:nil error:&error];
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
         XCTAssertNil(error);
         XCTAssertTrue(result);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing"
                  inputScopes:@"user.sing"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.microsoftonline.com/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:@"uid.utid"];
    NSError *error = nil;
    MSIDRefreshToken *refreshToken = [_defaultAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:configuration
                                                                          context:nil
                                                                            error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(refreshToken.storageAuthority.url.absoluteString, @"https://login.windows.net/common");
}

#pragma mark - Get ID token

- (void)testGetIDTokenForAccount_whenIDTokensInPrimaryCache_shouldReturnToken
{
    // Save first token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid2"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Save second token
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing"
                  inputScopes:@"user.sing"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    // Check cache state
    NSArray *refreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *idTokens = [self getAllIDTokens];
    XCTAssertEqual([idTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/utid2"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.write"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"upn@test.com" homeAccountId:@"uid.utid2"];
    NSError *error = nil;
    MSIDIdToken *idToken = [_defaultAccessor getIDTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(idToken);

    MSIDIdTokenClaims *claims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken.rawIdToken error:&error];
    XCTAssertNotNil(claims);
    XCTAssertNil(error);

    XCTAssertEqualObjects(claims.realm, @"utid2");
    XCTAssertEqualObjects(claims.username, @"upn@test.com");
    XCTAssertEqualObjects(idToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(idToken.authority.url.absoluteString, @"https://login.windows.net/utid2");
}

#pragma mark - Remove account

- (void)testRemoveAccount_whenAccountNil_shouldReturnError
{
    NSError *error = nil;
    BOOL result = [_defaultAccessor removeAccount:nil context:nil error:&error];
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testRemoveAccount_whenAccountNotNil_shouldRemoveAccount
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing"
                  inputScopes:@"user.sing"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id"
                                                         familyId:nil
                                                          context:nil
                                                            error:&error];

    XCTAssertNotNil(accounts);
    XCTAssertNil(error);
    XCTAssertEqual([accounts count], 1);

    MSIDAccount *account = accounts[0];

    BOOL result = [_defaultAccessor removeAccount:account context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                clientId:@"test_client_id"
                                                familyId:nil
                                                 context:nil
                                                   error:&error];
    XCTAssertNil(error);
    XCTAssertEqual([accounts count], 0);
}

#pragma mark - clearCacheForAccount

- (void)testClearCacheForAccount_whenNilAccount_shouldReturnError
{
    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSError *error = nil;
    BOOL result = [_defaultAccessor clearCacheForAccount:nil authority:authority clientId:@"test_client_id" context:nil error:&error];
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testClearCacheForAccount_whenAccountProvided_shouldRemoveTokens
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing"
                  inputScopes:@"user.sing"
                          uid:@"uid2"
                         utid:@"utid2"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing"
                  inputScopes:@"user.sing"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing2 user.dance"
                  inputScopes:@"user.sing2 user.dance"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_defaultAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing2 user.dance"
                  inputScopes:@"user.sing2 user.dance"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_otherAccessor];

    NSError *error = nil;

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id"
                                                         familyId:nil
                                                          context:nil
                                                            error:&error];
    XCTAssertNotNil(accounts);
    XCTAssertNil(error);
    XCTAssertEqual([accounts count], 2);

    NSArray *allATs = [self getAllAccessTokens];
    XCTAssertEqual([allATs count], 3);

    NSArray *allRTs = [self getAllRefreshTokens];
    XCTAssertEqual([allRTs count], 2);

    NSArray *allIDs = [self getAllIDTokens];
    XCTAssertEqual([allIDs count], 2);

    NSArray *allLegacyRTs = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([allLegacyRTs count], 1);

    MSIDAccount *account = nil;

    for (MSIDAccount *accountInCache in accounts)
    {
        if ([accountInCache.accountIdentifier.homeAccountId isEqualToString:@"uid.utid"])
        {
            account = accountInCache;
            break;
        }
    }

    XCTAssertNotNil(account);

    MSIDAccountIdentifier *identifier = [MSIDAccountIdentifier new];
    identifier.homeAccountId = account.accountIdentifier.homeAccountId;
    identifier.legacyAccountId = account.username;

    MSIDAuthority *msidAuthority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    BOOL result = [_defaultAccessor clearCacheForAccount:identifier authority:msidAuthority clientId:@"test_client_id" context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    allATs = [self getAllAccessTokens];
    XCTAssertEqual([allATs count], 1);

    MSIDAccessToken *accessToken = allATs[0];
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"uid2.utid2");

    allRTs = [self getAllRefreshTokens];
    XCTAssertEqual([allRTs count], 1);

    MSIDRefreshToken *refreshToken = allRTs[0];
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid2.utid2");

    allIDs = [self getAllIDTokens];
    XCTAssertEqual([allIDs count], 1);
    MSIDIdToken *idToken = allIDs[0];
    XCTAssertEqualObjects(idToken.accountIdentifier.homeAccountId, @"uid2.utid2");

    accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                clientId:@"test_client_id"
                                                familyId:nil
                                                 context:nil
                                                   error:&error];
    XCTAssertEqual([accounts count], 1);

    MSIDAccount *remainingAccount = accounts[0];
    XCTAssertEqualObjects(remainingAccount.accountIdentifier.homeAccountId, @"uid2.utid2");

    allLegacyRTs = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([allLegacyRTs count], 0);
}

- (void)testClearCacheForAccount_whenAccountProvided_andNilClientId_shouldRemoveTokensForAllClientIds
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id1"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing"
                  inputScopes:@"user.sing"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id2"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing"
                  inputScopes:@"user.sing"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id3"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.sing2 user.dance"
                  inputScopes:@"user.sing2 user.dance"
                          uid:@"uid"
                         utid:@"utid"
                  accessToken:@"access token 2"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_nonSSOAccessor];

    MSIDAccountIdentifier *identifier = [MSIDAccountIdentifier new];
    identifier.homeAccountId = @"uid.utid";
    identifier.legacyAccountId = @"upn@test.com";

    NSError *error = nil;
    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];
    BOOL result = [_defaultAccessor clearCacheForAccount:identifier authority:authority clientId:nil context:nil error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *allATs = [self getAllAccessTokens];
    XCTAssertEqual([allATs count], 0);

    NSArray *allRTs = [self getAllRefreshTokens];
    XCTAssertEqual([allRTs count], 0);

    NSArray *allIDs = [self getAllIDTokens];
    XCTAssertEqual([allIDs count], 0);

    NSArray *accounts = [_defaultAccessor allAccountsForAuthority:authority
                                                         clientId:@"test_client_id"
                                                         familyId:nil
                                                          context:nil
                                                            error:&error];
    XCTAssertEqual([accounts count], 0);
}

#pragma mark - Helpers

- (void)saveResponseWithUPN:(NSString *)upn
                   clientId:(NSString *)clientId
                  authority:(NSString *)authority
             responseScopes:(NSString *)responseScopes
                inputScopes:(NSString *)inputScopes
                        uid:(NSString *)uid
                       utid:(NSString *)utid
                accessToken:(NSString *)accessToken
               refreshToken:(NSString *)refreshToken
                   familyId:(NSString *)familyId
                   accessor:(id<MSIDCacheAccessor>)accessor
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:upn subject:@"subject" givenName:@"Hello" familyName:@"World" name:@"Hello World" version:@"2.0" tid:utid];

    MSIDTokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:accessToken
                                                                            RT:refreshToken
                                                                        scopes:[responseScopes msidScopeSet]
                                                                       idToken:idToken
                                                                           uid:uid
                                                                          utid:utid
                                                                      familyId:familyId];

    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:authority
                                                                                clientId:clientId
                                                                             redirectUri:nil
                                                                                  target:inputScopes];

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
    return [self getAllTokensWithType:MSIDAccessTokenType class:MSIDLegacyAccessToken.class accessor:_otherAccessor];
}

- (NSArray *)getAllLegacyRefreshTokens
{
    return [self getAllTokensWithType:MSIDRefreshTokenType class:MSIDLegacyRefreshToken.class accessor:_otherAccessor];
}

- (NSArray *)getAllAccessTokens
{
    return [self getAllTokensWithType:MSIDAccessTokenType class:MSIDAccessToken.class accessor:_defaultAccessor];
}

- (NSArray *)getAllRefreshTokens
{
    return [self getAllTokensWithType:MSIDRefreshTokenType class:MSIDRefreshToken.class accessor:_defaultAccessor];
}

- (NSArray *)getAllIDTokens
{
    return [self getAllTokensWithType:MSIDIDTokenType class:MSIDIdToken.class accessor:_defaultAccessor];
}

- (NSArray *)getAllLegacyTokens
{
    return [self getAllTokensWithType:MSIDLegacySingleResourceTokenType class:MSIDLegacySingleResourceToken.class accessor:_otherAccessor];
}

- (NSArray *)getAllTokensWithType:(MSIDCredentialType)type class:(Class)typeClass accessor:(id<MSIDCacheAccessor>)accessor
{
    NSError *error = nil;

    NSArray *allTokens = [accessor allTokensWithContext:nil error:&error];
    XCTAssertNil(error);

    NSMutableArray *results = [NSMutableArray array];

    for (MSIDBaseToken *token in allTokens)
    {
        if (token.credentialType == type
            && [token isKindOfClass:typeClass])
        {
            [results addObject:token];
        }
    }

    return results;
}

@end
