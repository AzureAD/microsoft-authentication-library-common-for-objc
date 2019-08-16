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
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDAADV2BrokerResponse.h"
#import "MSIDTestCacheAccessorHelper.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDV1IdToken.h"
#import "MSIDAADV1Oauth2Factory.h"

@interface MSIDDefaultTokenCacheAccessor (TestUtil)

- (BOOL)saveToken:(MSIDBaseToken *)token
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error;

@end

@interface MSIDDefaultAccessorSSOIntegrationTests : XCTestCase
{
    MSIDDefaultTokenCacheAccessor *_defaultAccessor;
    MSIDDefaultTokenCacheAccessor *_nonSSOAccessor;
    MSIDLegacyTokenCacheAccessor *_otherAccessor;
    id<MSIDExtendedTokenCacheDataSource> _defaultDataSource;
    id<MSIDTokenCacheDataSource> _otherDataSource;

}

@end

@implementation MSIDDefaultAccessorSSOIntegrationTests

- (void)setUp
{

#if TARGET_OS_IOS
    _defaultDataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil error:nil];
    _otherDataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil error:nil];
#else
    // TODO: this should be replaced with a real macOS datasource instead
    _otherDataSource = [MSIDMacTokenCache defaultCache];
    _defaultDataSource = [[MSIDTestCacheDataSource alloc] init];
#endif
    _otherAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:_otherDataSource otherCacheAccessors:nil];
    _defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:_defaultDataSource otherCacheAccessors:@[_otherAccessor]];
    _nonSSOAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:_defaultDataSource otherCacheAccessors:nil];
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
    [_defaultDataSource removeTokensWithKey:[MSIDCacheKey new] context:nil error:nil];
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
                                                       factory:[MSIDAADV2Oauth2Factory new]
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
                                                         factory:[MSIDAADV2Oauth2Factory new]
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
                                                       factory:[MSIDAADV2Oauth2Factory new]
                                                       context:nil
                                                         error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 1);

    MSIDAccessToken *accessToken = accessTokens[0];
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([accessToken.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNotNil(accessToken.extendedExpiresOn);
    XCTAssertEqualObjects(accessToken.scopes, scopes);
    XCTAssertEqual(accessToken.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(accessToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(accessToken.realm, @"tenantid.onmicrosoft.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNotNil(accessToken.extendedExpiresOn);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDRefreshToken *refreshToken = refreshTokens[0];
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertNil(refreshToken.familyId);
    XCTAssertEqual(refreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(refreshToken.environment, @"login.microsoftonline.com");
    XCTAssertNil(refreshToken.realm);
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNil(refreshToken.additionalServerInfo);

    NSArray *idTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_defaultAccessor];
    XCTAssertEqual([idTokens count], 1);

    MSIDIdToken *defaultIDToken = idTokens[0];
    XCTAssertEqualObjects(defaultIDToken.rawIdToken, idToken);
    XCTAssertEqual(defaultIDToken.credentialType, MSIDIDTokenType);
    XCTAssertEqualObjects(defaultIDToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(defaultIDToken.realm, @"tenantid.onmicrosoft.com");
    XCTAssertEqualObjects(defaultIDToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(defaultIDToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNil(defaultIDToken.additionalServerInfo);

    NSArray *allTokens = [_nonSSOAccessor allTokensWithContext:nil error:nil];
    XCTAssertEqual([allTokens count], 3);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

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
    XCTAssertEqualObjects(account.realm, @"tenantid.onmicrosoft.com");
    XCTAssertNil(account.alternativeAccountId);
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.realm, @"tenantid.onmicrosoft.com");
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
                                                        factory:[MSIDAADV2Oauth2Factory new]
                                                        context:nil
                                                          error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 1);

    MSIDAccessToken *accessToken = accessTokens[0];
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualWithAccuracy([accessToken.expiresOn timeIntervalSinceDate:[NSDate date]], 3600, 5);
    XCTAssertNotNil(accessToken.extendedExpiresOn);
    XCTAssertEqualObjects(accessToken.scopes, scopes);
    XCTAssertEqual(accessToken.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(accessToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(accessToken.realm, @"tenantid.onmicrosoft.com");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNotNil(accessToken.extendedExpiresOn);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDRefreshToken *refreshToken = refreshTokens[0];
    XCTAssertEqualObjects(refreshToken.refreshToken, @"refresh token");
    XCTAssertNil(refreshToken.familyId);
    XCTAssertEqual(refreshToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(refreshToken.environment, @"login.microsoftonline.com");
    XCTAssertNil(refreshToken.realm);
    XCTAssertEqualObjects(refreshToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNil(refreshToken.additionalServerInfo);

    NSArray *idTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_defaultAccessor];
    XCTAssertEqual([idTokens count], 1);

    MSIDIdToken *defaultIDToken = idTokens[0];
    XCTAssertEqualObjects(defaultIDToken.rawIdToken, idToken);
    XCTAssertEqual(defaultIDToken.credentialType, MSIDIDTokenType);
    XCTAssertEqualObjects(defaultIDToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(defaultIDToken.realm, @"tenantid.onmicrosoft.com");
    XCTAssertEqualObjects(defaultIDToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(defaultIDToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertNil(defaultIDToken.additionalServerInfo);

    NSArray *allTokens = [_nonSSOAccessor allTokensWithContext:nil error:nil];
    XCTAssertEqual([allTokens count], 3);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

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
    XCTAssertEqualObjects(account.realm, @"tenantid.onmicrosoft.com");
    XCTAssertNil(account.alternativeAccountId);
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.realm, @"tenantid.onmicrosoft.com");
    // Now check legacy accessor
    NSArray *legacyAccessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_otherAccessor];
    XCTAssertEqual([legacyAccessTokens count], 0);

    NSArray *legacyRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
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
                                                        factory:[MSIDAADV2Oauth2Factory new]
                                                        context:nil
                                                          error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *legacyAccessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_otherAccessor];
    XCTAssertEqual([legacyAccessTokens count], 0);

    NSArray *legacyRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
    XCTAssertEqual([legacyRefreshTokens count], 0);

    NSArray *defaultAccessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([defaultAccessTokens count], 1);

    NSArray *defaultRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
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

    NSArray *defaultIDTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_defaultAccessor];
    XCTAssertEqual([defaultIDTokens count], 1);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSArray *clientAccounts = [_otherAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];
    XCTAssertEqual([clientAccounts count], 0);

    NSArray *familyAccounts = [_otherAccessor accountsWithAuthority:authority clientId:nil familyId:@"2" accountIdentifier:nil context:nil error:&error];
    XCTAssertEqual([familyAccounts count], 0);

    NSArray *allAccounts = [_otherAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:@"2" accountIdentifier:nil context:nil error:&error];
    XCTAssertEqual([allAccounts count], 0);
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
                                                        factory:[MSIDAADV2Oauth2Factory new]
                                                        context:nil
                                                          error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_otherAccessor];
    XCTAssertEqual([accessTokens count], 0);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *legacyTokens = [MSIDTestCacheAccessorHelper getAllLegacyTokens:_otherAccessor];
    XCTAssertEqual([legacyTokens count], 0);

    NSArray *defaultAccessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([defaultAccessTokens count], 0);

    NSArray *defaultRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([defaultRefreshTokens count], 0);

    NSArray *defaultIDTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_defaultAccessor];
    XCTAssertEqual([defaultIDTokens count], 0);

    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    error = nil;
    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

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
                                                        factory:[MSIDAADV2Oauth2Factory new]
                                                        context:nil
                                                          error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:_otherAccessor];
    XCTAssertEqual([accessTokens count], 0);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
    XCTAssertEqual([refreshTokens count], 0);

    NSArray *legacyTokens = [MSIDTestCacheAccessorHelper getAllLegacyTokens:_otherAccessor];
    XCTAssertEqual([legacyTokens count], 0);

    NSArray *defaultAccessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([defaultAccessTokens count], 1);

    NSArray *defaultRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([defaultRefreshTokens count], 0);

    NSArray *defaultIDTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_defaultAccessor];
    XCTAssertEqual([defaultIDTokens count], 1);

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
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:@"uid2.utid"];
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
    XCTAssertEqualObjects(refreshToken.environment, @"login.windows.net");
    XCTAssertNil(refreshToken.realm);
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
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *legacyRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
    XCTAssertEqual([legacyRefreshTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:@"uid2.utid"];
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
    XCTAssertEqualObjects(refreshToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(refreshToken.realm, @"common");
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
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 4);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id2"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:@"uid2.utid"];
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
    XCTAssertEqualObjects(refreshToken.environment, @"login.windows.net");
    XCTAssertNil(refreshToken.realm);
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
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *legacyRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
    XCTAssertEqual([legacyRefreshTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id2"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:@"uid2.utid"];
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
    XCTAssertEqualObjects(refreshToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(refreshToken.realm, @"common");
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
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *legacyRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
    XCTAssertEqual([legacyRefreshTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id2"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:@"uid2.utid"];
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
    XCTAssertEqualObjects(refreshToken.environment, @"login.windows.net");
    XCTAssertNil(refreshToken.realm);
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
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *legacyRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
    XCTAssertEqual([legacyRefreshTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:@"uid2.utid"];
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
    XCTAssertEqualObjects(refreshToken.environment, @"login.windows.net");
    XCTAssertNil(refreshToken.realm);
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
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 1);

    NSArray *legacyRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
    XCTAssertEqual([legacyRefreshTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.read"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:@"uid2.utid"];
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

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
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

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid2.utid");
    XCTAssertEqualObjects(account.realm, @"utid");
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

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:nil familyId:@"3" accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"utid");
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

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"utid");
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

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id2" familyId:@"3" accountIdentifier:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"utid");
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

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:@"3" accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"utid");
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

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:@"3" accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"utid");
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

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:nil clientId:@"test_client_id" familyId:@"3" accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 2);
    MSIDAccount *firstAccount = accounts[0];
    XCTAssertEqualObjects(firstAccount.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(firstAccount.realm, @"utid");
    XCTAssertEqualObjects(firstAccount.username, @"upn@test.com");

    MSIDAccount *secondAccount = accounts[1];
    XCTAssertEqualObjects(secondAccount.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(secondAccount.realm, @"utid");
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

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:@"3" accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *firstAccount = accounts[0];
    XCTAssertEqualObjects(firstAccount.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(firstAccount.realm, @"utid");
    XCTAssertEqualObjects(firstAccount.username, @"upn@test.com");
    XCTAssertEqualObjects(firstAccount.environment, @"login.microsoft.com");

    accounts = [_defaultAccessor accountsWithAuthority:nil clientId:@"test_client_id" familyId:@"3" accountIdentifier:nil context:nil error:&error];

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

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:@"3" accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"utid");
    XCTAssertEqualObjects(account.givenName, @"Hello");
    XCTAssertEqualObjects(account.familyName, @"World");
    XCTAssertEqualObjects(account.username, @"upn@test.com");
    XCTAssertEqualObjects(account.name, @"Hello World");

    accounts = [_defaultAccessor accountsWithAuthority:nil clientId:@"test_client_id" familyId:@"3" accountIdentifier:nil context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 2);
}

- (void)testAccountsWithAuthority_whenNilAuthority_NilClientId_nilFamilyId_andHomeAccountIdentifier_shouldReturnMatch
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
                          uid:@"uid2"
                         utid:@"utid2"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    NSError *error = nil;
    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:@"uid.utid"];
    NSArray *accounts = [_defaultAccessor accountsWithAuthority:nil clientId:nil familyId:nil accountIdentifier:identifier context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"utid");
}

- (void)testAccountsWithAuthority_whenNilAuthority_NonNilClientId_nilFamilyId_andLegacyAccountIdentifier_shouldReturnMatch
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

    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid2"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    NSError *error = nil;
    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSArray *accounts = [_defaultAccessor accountsWithAuthority:nil clientId:@"test_client_id" familyId:nil accountIdentifier:identifier context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"utid");
}

- (void)testAccountsWithAuthority_whenNilAuthority_NilClientId_nonNilFamilyId_andLegacyAccountIdentifier_andTokensInLegacyCache_shouldReturnMatch
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
                     accessor:_otherAccessor];

    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid2"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];

    NSError *error = nil;
    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSArray *accounts = [_defaultAccessor accountsWithAuthority:nil clientId:nil familyId:@"3" accountIdentifier:identifier context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.realm, @"utid");
}

- (void)testAccountsWithAuthority_whenNilAuthority_NilClientId_nonNilFamilyId_andHomeAccountIdentifier_andTokensInLegacyCache_shouldReturnMatch
{
    [self saveResponseWithUPN:@"upn@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:nil
                         utid:nil
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_otherAccessor];
    
    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid"
                         utid:@"utid2"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:@"3"
                     accessor:_nonSSOAccessor];
    
    NSError *error = nil;
    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:@"uid.utid2"];
    NSArray *accounts = [_defaultAccessor accountsWithAuthority:nil clientId:nil familyId:@"3" accountIdentifier:identifier context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid2");
    XCTAssertEqualObjects(account.realm, @"utid2");
}

- (void)testAccountsWithAuthority_whenNilAuthority_NonNilClientId_andNonNilFamilyId_andNilAccountIdentifier_andTokensInLegacyCache_shouldReturnMatch
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
                     accessor:_otherAccessor];
    
    [self saveResponseWithUPN:@"upn2@test.com"
                     clientId:@"test_client_id2"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid2"
                         utid:@"utid2"
                  accessToken:@"access token"
                 refreshToken:@"refresh token 2"
                     familyId:nil
                     accessor:_otherAccessor];
    
    [self saveResponseWithUPN:@"upn3@test.com"
                     clientId:@"test_client_id3"
                    authority:@"https://login.windows.net/common"
               responseScopes:@"user.read user.write"
                  inputScopes:@"user.read user.write"
                          uid:@"uid3"
                         utid:@"utid3"
                  accessToken:@"access token"
                 refreshToken:@"refresh token 2"
                     familyId:@"4"
                     accessor:_otherAccessor];
    
    NSError *error = nil;
    NSArray *accounts = [_defaultAccessor accountsWithAuthority:nil clientId:@"test_client_id2" familyId:@"3" accountIdentifier:nil context:nil error:&error];
    XCTAssertEqual([accounts count], 2);
    NSArray *accountUPNs = @[[accounts[0] username], [accounts[1] username]];
    XCTAssertTrue([accountUPNs containsObject:@"upn@test.com"]);
    XCTAssertTrue([accountUPNs containsObject:@"upn2@test.com"]);
    XCTAssertFalse([accountUPNs containsObject:@"upn3@test.com"]);
}

#pragma mark - Get single account

- (void)testGetAccount_whenNoAccountsInCache_shouldReturnNilAndNilError
{
    NSError *error = nil;

    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy.id"
                                                                                 homeAccountId:@"home.id"];

    MSIDAuthority *authority = [@"https://login.windows.net/common" aadAuthority];
    MSIDAccount *account = [_defaultAccessor getAccountForIdentifier:identifier authority:authority context:nil error:&error];

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
                         utid:@"contoso.com"
                  accessToken:@"access token"
                 refreshToken:@"refresh token"
                     familyId:nil
                     accessor:_defaultAccessor];

    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil
                                                                                 homeAccountId:@"home.contoso.com"];

    NSError *error = nil;

    MSIDAuthority *authority = [@"https://login.windows.net/contoso.com" aadAuthority];

    MSIDAccount *account = [_defaultAccessor getAccountForIdentifier:identifier authority:authority context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"home.contoso.com");
    XCTAssertEqualObjects(account.accountIdentifier.displayableId, @"legacy.id");
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
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/utid"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.write"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:@"uid.utid"];
    NSError *error = nil;
    MSIDAccessToken *accessToken = [_defaultAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(accessToken);
    XCTAssertEqualObjects(accessToken.accessToken, @"access token");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(accessToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(accessToken.realm, @"utid");
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

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDRefreshToken *refreshToken = refreshTokens[0];
    refreshToken.refreshToken = @"outdated refresh token";

    NSError *error = nil;
    BOOL result = [_defaultAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remaininRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
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

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDRefreshToken *refreshToken = refreshTokens[0];

    NSError *error = nil;
    BOOL result = [_defaultAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remaininRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([remaininRefreshTokens count], 0);
}

- (void)testValidateAndRemoveRefreshToken_whenTokenProvided_butTokenFromSecondaryCache_shouldNotRemoveToken
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

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDRefreshToken *refreshToken = refreshTokens[0];

    NSError *error = nil;
    BOOL result = [_defaultAccessor validateAndRemoveRefreshToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remaininRefreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
    XCTAssertEqual([remaininRefreshTokens count], 1);
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

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDAccessToken *firstToken = accessTokens[0];
    MSIDAccessToken *secondToken = accessTokens[1];

    NSError *error = nil;
    BOOL result = [_defaultAccessor removeToken:secondToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainingAccessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([remainingAccessTokens count], 1);
    XCTAssertEqualObjects(remainingAccessTokens[0], firstToken);

    NSArray *remaininRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
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

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *idTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_defaultAccessor];
    XCTAssertEqual([idTokens count], 2);

    MSIDIdToken *firstToken = idTokens[0];
    MSIDIdToken *secondToken = idTokens[1];

    NSError *error = nil;
    BOOL result = [_defaultAccessor removeToken:secondToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainingIDTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_defaultAccessor];
    XCTAssertEqual([remainingIDTokens count], 1);
    XCTAssertEqualObjects(remainingIDTokens[0], firstToken);

    NSArray *remaininRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
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
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 1);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.microsoftonline.com/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"graph"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:@"uid.utid"];
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
    XCTAssertEqualObjects(refreshToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(refreshToken.storageEnvironment, @"login.windows.net");
    XCTAssertNil(refreshToken.realm);
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
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 2);

    NSArray *idTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:_defaultAccessor];
    XCTAssertEqual([idTokens count], 2);

    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/utid2"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.write"];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:@"uid.utid2"];
    NSError *error = nil;
    MSIDIdToken *idToken = [_defaultAccessor getIDTokenForAccount:account configuration:configuration idTokenType:MSIDIDTokenType context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(idToken);

    MSIDIdTokenClaims *claims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken.rawIdToken error:&error];
    XCTAssertNotNil(claims);
    XCTAssertNil(error);

    XCTAssertEqualObjects(claims.realm, @"utid2");
    XCTAssertEqualObjects(claims.username, @"upn@test.com");
    XCTAssertEqualObjects(idToken.clientId, @"test_client_id");
    XCTAssertEqualObjects(idToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(idToken.realm, @"utid2");
}

- (void)testGetIDTokenForAccount_whenWrongIDTokenType_shouldReturnError
{
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/utid2"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.write"];
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:@"uid.utid2"];
    
    NSError *error = nil;
    MSIDIdToken *idToken = [_defaultAccessor getIDTokenForAccount:account configuration:configuration idTokenType:MSIDAccessTokenType context:nil error:&error];
    
    XCTAssertNil(idToken);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Wrong id token type passed.");
}

- (void)testGetIDTokenForAccount_whenV1AndV2IDTokenInCache_shouldBeAbleToRetrieveThem
{
    // save v1 id token
    MSIDV1IdToken *v1IdToken = [MSIDV1IdToken new];
    v1IdToken.environment = @"contoso.com";
    v1IdToken.realm = @"common";
    v1IdToken.clientId = @"test_client_id";
    v1IdToken.additionalServerInfo = @{@"spe_info" : @"value2"};
    v1IdToken.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy.id" homeAccountId:@"uid.utid"];
    v1IdToken.rawIdToken = @"v1idToken";
    v1IdToken.storageEnvironment = v1IdToken.environment;
    
    NSError *error;
    [_defaultAccessor saveToken:v1IdToken context:nil error:&error];
    XCTAssertNil(error);
    
    // save v2 id token
    MSIDIdToken *v2IdToken = [MSIDIdToken new];
    v2IdToken.environment = @"contoso.com";
    v2IdToken.realm = @"common";
    v2IdToken.clientId = @"test_client_id";
    v2IdToken.additionalServerInfo = @{@"spe_info" : @"value2"};
    v2IdToken.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy.id" homeAccountId:@"uid.utid"];
    v2IdToken.rawIdToken = @"v2idToken";
    v2IdToken.storageEnvironment = v2IdToken.environment;
    
    error = nil;
    [_defaultAccessor saveToken:v2IdToken context:nil error:&error];
    XCTAssertNil(error);
    
    // get v1 id token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://contoso.com/common"
                                                                                clientId:@"test_client_id"
                                                                             redirectUri:nil
                                                                                  target:@"user.write"];
    
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:@"uid.utid"];
    error = nil;
    MSIDIdToken *v1IdTokenInCache = [_defaultAccessor getIDTokenForAccount:account configuration:configuration idTokenType:MSIDLegacyIDTokenType context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue([v1IdTokenInCache isMemberOfClass:MSIDV1IdToken.class]);
    XCTAssertEqualObjects(v1IdTokenInCache.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(v1IdTokenInCache.rawIdToken, @"v1idToken");
    
    // get v2 id token
    error = nil;
    MSIDIdToken *v2IdTokenInCache = [_defaultAccessor getIDTokenForAccount:account configuration:configuration idTokenType:MSIDIDTokenType context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue([v2IdTokenInCache isMemberOfClass:MSIDIdToken.class]);
    XCTAssertEqualObjects(v2IdTokenInCache.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(v2IdTokenInCache.rawIdToken, @"v2idToken");
                           
}

#pragma mark - clearCacheForAccount

- (void)testClearCacheForAccount_whenNilAccount_shouldReturnError
{
    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    NSError *error = nil;
    BOOL result = [_defaultAccessor clearCacheForAccount:nil authority:authority clientId:@"test_client_id" familyId:nil context:nil error:&error];
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

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];
    XCTAssertNotNil(accounts);
    XCTAssertNil(error);
    XCTAssertEqual([accounts count], 2);

    NSArray *allATs = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([allATs count], 3);

    NSArray *allRTs = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([allRTs count], 2);

    NSArray *allIDs = [MSIDTestCacheAccessorHelper getAllIdTokens:_defaultAccessor];
    XCTAssertEqual([allIDs count], 2);

    NSArray *allLegacyRTs = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
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

    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:account.username homeAccountId:account.accountIdentifier.homeAccountId];

    MSIDAuthority *msidAuthority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];

    BOOL result = [_defaultAccessor clearCacheForAccount:identifier authority:msidAuthority clientId:@"test_client_id" familyId:nil context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    allATs = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([allATs count], 1);

    MSIDAccessToken *accessToken = allATs[0];
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"uid2.utid2");

    allRTs = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([allRTs count], 1);

    MSIDRefreshToken *refreshToken = allRTs[0];
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"uid2.utid2");

    allIDs = [MSIDTestCacheAccessorHelper getAllIdTokens:_defaultAccessor];
    XCTAssertEqual([allIDs count], 1);
    MSIDIdToken *idToken = allIDs[0];
    XCTAssertEqualObjects(idToken.accountIdentifier.homeAccountId, @"uid2.utid2");

    accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];

    XCTAssertEqual([accounts count], 1);

    MSIDAccount *remainingAccount = accounts[0];
    XCTAssertEqualObjects(remainingAccount.accountIdentifier.homeAccountId, @"uid2.utid2");

    allLegacyRTs = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:_otherAccessor];
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

    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:@"uid.utid"];

    NSError *error = nil;
    MSIDAuthority *authority = [[MSIDAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.windows.net/common"] context:nil error:nil];
    BOOL result = [_defaultAccessor clearCacheForAccount:identifier authority:authority clientId:nil familyId:nil context:nil error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *allATs = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([allATs count], 0);

    NSArray *allRTs = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([allRTs count], 0);

    NSArray *allIDs = [MSIDTestCacheAccessorHelper getAllIdTokens:_defaultAccessor];
    XCTAssertEqual([allIDs count], 0);

    NSArray *accounts = [_defaultAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:nil error:&error];
    XCTAssertEqual([accounts count], 0);
}

- (void)testSaveAppMetadataWithFactory_whenMultiResourceFOCIResponse
{
    MSIDTokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponseWithFamilyId:@"familyId"];
    NSError *error = nil;
    MSIDConfiguration *configuration = [MSIDTestConfiguration defaultParams];
    
    BOOL result = [_defaultAccessor saveTokensWithConfiguration:configuration
                                                       response:response
                                                        factory:[MSIDAADV2Oauth2Factory new]
                                                        context:nil
                                                          error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSArray<MSIDAppMetadataCacheItem *> *appMetadataEntries = [_defaultAccessor getAppMetadataEntries:configuration
                                                                                              context:nil
                                                                                                error:nil];
    
    XCTAssertEqual([appMetadataEntries count], 1);
    XCTAssertEqualObjects(appMetadataEntries[0].clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(appMetadataEntries[0].environment, configuration.authority.environment);
    XCTAssertEqualObjects(appMetadataEntries[0].familyId, @"familyId");
}

- (void)testGetAccessTokenForAccount_whenAccessTokenCachePartitionedByAppIdentifier_andTwoTokensInCache_shouldReturnToken
{
    // Save first token
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
                appIdentifier:@"myapp1"
                     accessor:_nonSSOAccessor];
    
    // Save second token (same clientId, but different app identifier)
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
                appIdentifier:@"myapp2"
                     accessor:_nonSSOAccessor];
    
    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 1);
    
    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 2);
    
    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/utid"
                                                                                clientId:@"test_client_id1"
                                                                             redirectUri:nil
                                                                                  target:@"user.sing"];
    configuration.applicationIdentifier = @"myapp1";
    
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:@"uid.utid"];
    NSError *error = nil;
    MSIDAccessToken *accessToken = [_defaultAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(accessToken);
    XCTAssertEqualObjects(accessToken.accessToken, @"access token 2");
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(accessToken.clientId, @"test_client_id1");
    XCTAssertEqualObjects(accessToken.environment, @"login.windows.net");
    XCTAssertEqualObjects(accessToken.realm, @"utid");
}

- (void)testGetAccessTokenForAccount_whenAccessTokenCachePartitionedByAppIdentifier_whenDifferentApp_shouldReturnNil
{
    // Save first token
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
                appIdentifier:@"myapp1"
                     accessor:_nonSSOAccessor];
    
    // Check cache state
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([refreshTokens count], 1);
    
    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_defaultAccessor];
    XCTAssertEqual([accessTokens count], 1);
    
    // Get token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.windows.net/utid"
                                                                                clientId:@"test_client_id1"
                                                                             redirectUri:nil
                                                                                  target:@"user.sing"];
    configuration.applicationIdentifier = @"myapp3";
    
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@test.com" homeAccountId:nil];
    NSError *error = nil;
    MSIDAccessToken *accessToken = [_defaultAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(accessToken);
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
    [self saveResponseWithUPN:upn
                     clientId:clientId
                    authority:authority
               responseScopes:responseScopes
                  inputScopes:inputScopes
                          uid:uid
                         utid:utid
                  accessToken:accessToken
                 refreshToken:refreshToken
                     familyId:familyId
                appIdentifier:nil
                     accessor:accessor];
}

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
              appIdentifier:(NSString *)appIdentifier
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
    
    configuration.applicationIdentifier = appIdentifier;

    NSError *error = nil;
    // Save first token
    BOOL result = [accessor saveTokensWithConfiguration:configuration
                                               response:response
                                                factory:[MSIDAADV2Oauth2Factory new]
                                                context:nil
                                                  error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);
}

@end
