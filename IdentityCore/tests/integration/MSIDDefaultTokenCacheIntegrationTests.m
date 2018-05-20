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
#import "MSIDTestCacheDataSource.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDTestConfiguration.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDBaseToken.h"
#import "MSIDAccount.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAadAuthorityCache+TestUtil.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDDefaultTokenCacheIntegrationTests : XCTestCase
{
    MSIDDefaultTokenCacheAccessor *_cacheAccessor;
    MSIDLegacyTokenCacheAccessor *_otherAccessor;
    id<MSIDTokenCacheDataSource> _dataSource;
}
@end

@implementation MSIDDefaultTokenCacheIntegrationTests

#pragma mark - Setup

- (void)setUp
{

#if TARGET_OS_IOS
    _dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
#else
    // TODO: this should be replaced with a real macOS datasource instead
    _dataSource = [[MSIDTestCacheDataSource alloc] init];
#endif
    _otherAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:_dataSource otherCacheAccessors:nil];
    _cacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:_dataSource otherCacheAccessors:@[_otherAccessor]];
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];

    [[MSIDAadAuthorityCache sharedInstance] clear];
    [_dataSource removeItemsWithKey:[MSIDCacheKey new] context:nil error:nil];
}

#pragma mark - Saving

- (void)testSaveTokensWithRequestParams_whenHomeAccountIdNil_shouldReturnError
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    NSOrderedSet *set = [NSOrderedSet orderedSetWithObjects:@"user.read", nil];
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2TokenResponseWithAT:@"at" RT:@"rt" scopes:set idToken:nil uid:nil utid:nil familyId:nil];

    NSError *error = nil;

    BOOL result = [_cacheAccessor saveTokensWithFactory:factory
                                          configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                               response:tokenResponse
                                                context:nil
                                                  error:&error];

    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testSaveTokensWithRequestParams_withAccessToken_shouldSaveToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithFactory:factory
                                          configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                               response:tokenResponse
                                                context:nil
                                                  error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokens = [self getAllAccessTokens];
    XCTAssertNil(error);

    XCTAssertEqual([accessTokens count], 1);
    XCTAssertEqualObjects([accessTokens[0] accessToken], tokenResponse.accessToken);
}

- (void)testSaveTokensWithRequestParams_withNilAccessToken_shouldNotSaveToken_returnError
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2TokenResponseWithAT:nil
                                                                                 RT:@"rt"
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                            idToken:@"id_token"
                                                                                uid:@"uid"
                                                                               utid:@"utid"
                                                                           familyId:@"family_id"];

    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithFactory:factory
                                          configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                               response:tokenResponse
                                                context:nil
                                                  error:&error];

    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInternal);

    NSError *readError = nil;
    NSArray *allTokens = [_cacheAccessor allTokensWithContext:nil error:&readError];
    XCTAssertNil(readError);
    XCTAssertEqual([allTokens count], 0);
}

- (void)testSaveTokensWithRequestParams_withAccessTokenSameEverythingWithScopesIntersect_shouldOverwriteToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    BOOL result = [_cacheAccessor saveTokensWithFactory:factory
                                          configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                               response:tokenResponse
                                                context:nil
                                                  error:nil];

    NSArray *allTokens = [self getAllAccessTokens];
    XCTAssertEqual([allTokens count], 1);

    // save 2nd token with intersecting scope
    NSOrderedSet<NSString *> *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, @"profile.read", nil];
    MSIDTokenResponse *tokenResponse2 = [MSIDTestTokenResponse v2DefaultTokenResponseWithScopes:scopes];

    NSError *error = nil;
    result = [_cacheAccessor saveTokensWithFactory:factory
                                     configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                          response:tokenResponse2
                                           context:nil
                                             error:nil];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokensInCache = [self getAllAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
    XCTAssertEqualObjects([accessTokensInCache[0] accessToken], tokenResponse2.accessToken);
}

- (void)testSaveTokensWithRequestParams_withAccessTokenSameEverythingWithScopesDontIntersect_shouldWriteNewToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // save 1st token with default test scope
    BOOL result = [_cacheAccessor saveTokensWithFactory:factory
                                          configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                               response:tokenResponse
                                                context:nil
                                                  error:nil];

    NSArray *accessTokensInCache = [self getAllAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 1);

    // save 2nd token with non-intersecting scope
    NSOrderedSet<NSString *> *scopes = [NSOrderedSet orderedSetWithObjects:@"profile.read", nil];
    MSIDTokenResponse *tokenResponse2 = [MSIDTestTokenResponse v2DefaultTokenResponseWithScopes:scopes];

    NSError *error = nil;

    result = [_cacheAccessor saveTokensWithFactory:factory
                                     configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                          response:tokenResponse2
                                           context:nil
                                             error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    accessTokensInCache = [self getAllAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 2);
}

- (void)testSaveTokensWithRequestParams_withAccessTokenAndDifferentAuthorities_shouldSave2Tokens
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    NSError *error = nil;

    // save 1st token with default test scope
    BOOL result = [_cacheAccessor saveTokensWithFactory:factory
                                          configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                               response:tokenResponse
                                                context:nil
                                                  error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    // save 2nd token with different authority
    MSIDTokenResponse *tokenResponse2 = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://contoso2.com"
                                                                                clientId:DEFAULT_TEST_CLIENT_ID
                                                                             redirectUri:nil
                                                                                  target:DEFAULT_TEST_SCOPE];

    result = [_cacheAccessor saveTokensWithFactory:factory
                                     configuration:configuration
                                          response:tokenResponse2
                                           context:nil
                                             error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokensInCache = [self getAllAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 2);
}

- (void)testSaveTokensWithRequestParams_withAccessTokenAndDifferentUsers_shouldSave2Tokens
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // save 1st token with default test scope

    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithFactory:factory
                                          configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                               response:tokenResponse
                                                context:nil
                                                  error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    // save 2nd token with different user
    MSIDTokenResponse *tokenResponse2 = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                  RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                              scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                             idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                 uid:@"1"
                                                                                utid:@"222.qwe"
                                                                            familyId:nil];

    result = [_cacheAccessor saveTokensWithFactory:factory
                                     configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                          response:tokenResponse2
                                           context:nil
                                             error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokensInCache = [self getAllAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 2);
}

- (void)testSaveTokensWithRequestParams_withNilIDToken_shouldNotSaveIDToken_andSaveAccessToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2TokenResponseWithAT:@"at"
                                                                                 RT:@"rt"
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                            idToken:nil
                                                                                uid:@"uid"
                                                                               utid:@"utid"
                                                                           familyId:@"family_id"];

    NSError *error = nil;

    BOOL result = [_cacheAccessor saveTokensWithFactory:factory
                                          configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                               response:tokenResponse
                                                context:nil
                                                  error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokensInCache = [self getAllAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 1);

    NSArray *idTokensInCache = [self getAllIDTokens];
    XCTAssertEqual([idTokensInCache count], 0);
}

- (void)testSaveTokensWithRequestParams_withIDToken_shouldSaveIDToken_andSaveAccessToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2TokenResponseWithAT:@"at"
                                                                                 RT:@"rt"
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                            idToken:@"id_token"
                                                                                uid:@"uid"
                                                                               utid:@"utid"
                                                                           familyId:@"family_id"];

    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithFactory:factory
                                          configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                               response:tokenResponse
                                                context:nil
                                                  error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokensInCache = [self getAllAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 1);

    NSArray *idTokensInCache = [self getAllIDTokens];
    XCTAssertEqual([idTokensInCache count], 1);
}

- (void)testSaveSSOState_withResponse_shouldSaveOneRefreshTokenEntry
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    NSError *error = nil;

    BOOL result = [_cacheAccessor saveSSOStateWithFactory:factory
                                            configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                 response:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                  context:nil
                                                    error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *refreshTokensInCache = [self getAllRefreshTokens];
    XCTAssertEqual([refreshTokensInCache count], 1);
}

- (void)testSaveRefreshToken_whenNoUserIdentifier_shouldReturnError
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"user.read", nil];
    MSIDTokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:@"at"
                                                                            RT:@"rt"
                                                                        scopes:scopes
                                                                       idToken:nil
                                                                           uid:nil
                                                                          utid:nil
                                                                      familyId:nil];

    NSError *error = nil;

    BOOL result = [_cacheAccessor saveSSOStateWithFactory:factory
                                            configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                 response:response
                                                  context:nil
                                                    error:&error];

    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

#pragma mark - Retrieve

- (void)testGetTokenWithType_whenTypeAccessNoItemsInCache_shouldReturnNil
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];

    NSError *error = nil;
    MSIDAccessToken *token = [_cacheAccessor getAccessTokenForAccount:account
                                                        configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                              context:nil
                                                                error:&error];

    XCTAssertNil(error);
    XCTAssertNil(token);
}

- (void)testGetTokenWithType_whenTypeAccessMultipleAccessTokensInCache_shouldReturnRightToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // save 1st token with default test scope
    [_cacheAccessor saveTokensWithFactory:factory
                            configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                 response:tokenResponse
                                  context:nil
                                    error:nil];

    // save 2nd token with non-intersecting scope
    NSOrderedSet<NSString *> *scopes = [NSOrderedSet orderedSetWithObjects:@"profile.read", nil];

    MSIDTokenResponse *tokenResponse2 = [MSIDTestTokenResponse v2TokenResponseWithAT:@"access_token 2"
                                                                                  RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                              scopes:scopes
                                                                             idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                 uid:@"1"
                                                                                utid:@"1234-5678-90abcdefg"
                                                                            familyId:nil];

    [_cacheAccessor saveTokensWithFactory:factory
                            configuration:[MSIDTestConfiguration v2DefaultConfigurationWithScopes:scopes]
                                 response:tokenResponse2
                                  context:nil
                                    error:nil];

    // save 3rd token with different authority
    MSIDAADV2TokenResponse *tokenResponse3 = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                       RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                   scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                                  idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                      uid:DEFAULT_TEST_UID
                                                                                     utid:DEFAULT_TEST_UTID
                                                                                 familyId:nil];

    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://contoso2.com/common"
                                                                              clientId:DEFAULT_TEST_CLIENT_ID
                                                                           redirectUri:nil
                                                                                target:DEFAULT_TEST_SCOPE];

    [_cacheAccessor saveTokensWithFactory:factory
                            configuration:configuration
                                 response:tokenResponse3
                                  context:nil
                                    error:nil];

    // save 4th token with different user
    MSIDTokenResponse *tokenResponse4 = [MSIDTestTokenResponse v2TokenResponseWithAT:@"access_token 3"
                                                                                  RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                              scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                             idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                 uid:@"UID2"
                                                                                utid:@"UTID2"
                                                                            familyId:nil];

    [_cacheAccessor saveTokensWithFactory:factory
                            configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                 response:tokenResponse4
                                  context:nil
                                    error:nil];

    NSArray *accessTokensInCache = [self getAllAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 4);

    configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/1234-5678-90abcdefg"];

    // retrieve first at
    NSError *error = nil;

    MSIDAccessToken *returnedToken = [_cacheAccessor getAccessTokenForAccount:account
                                                                configuration:configuration
                                                                      context:nil
                                                                        error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
}

- (void)testGetTokenWithType_whenTypeAccessCorrectAccountAndParameters_shouldReturnToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // Save token
    [_cacheAccessor saveTokensWithFactory:factory
                            configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                 response:tokenResponse
                                  context:nil
                                    error:nil];

    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/1234-5678-90abcdefg"];

    NSError *error = nil;

    MSIDAccessToken *returnedToken = [_cacheAccessor getAccessTokenForAccount:account
                                                                configuration:configuration
                                                                      context:nil
                                                                        error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
}

- (void)testGetTokenWithType_whenTypeAccessCorrectAccount_andNoAuthority_shouldReturnToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // Save token
    [_cacheAccessor saveTokensWithFactory:factory
                            configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                 response:tokenResponse
                                  context:nil
                                    error:nil];

    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:nil
                                                                             clientId:DEFAULT_TEST_CLIENT_ID
                                                                             redirectUri:nil
                                                                                  target:DEFAULT_TEST_SCOPE];

    NSError *error = nil;
    MSIDAccessToken *returnedToken = [_cacheAccessor getAccessTokenForAccount:account
                                                                configuration:configuration
                                                                      context:nil
                                                                        error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
}

- (void)testGetTokenWithType_whenTypeAccessCorrectAccount_noAuthorityAndMultipleAccessTokensInCache_shouldReturnError
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // Save first token
    [_cacheAccessor saveTokensWithFactory:factory
                            configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                 response:tokenResponse
                                  context:nil
                                    error:nil];

    // Save second token
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.microsoftonline.de/common"
                                                                                clientId:DEFAULT_TEST_CLIENT_ID
                                                                             redirectUri:nil
                                                                                  target:DEFAULT_TEST_SCOPE];

    [_cacheAccessor saveTokensWithFactory:factory
                            configuration:configuration
                                 response:tokenResponse
                                  context:nil
                                    error:nil];

    // Query cache
    MSIDConfiguration *configuration2 = [MSIDTestConfiguration configurationWithAuthority:nil
                                                                                 clientId:DEFAULT_TEST_CLIENT_ID
                                                                              redirectUri:nil
                                                                                   target:DEFAULT_TEST_SCOPE];

    NSError *error = nil;
    MSIDAccessToken *returnedToken = [_cacheAccessor getAccessTokenForAccount:account
                                                                configuration:configuration2
                                                                      context:nil
                                                                        error:&error];

    XCTAssertNotNil(error);
    XCTAssertNil(returnedToken);
    XCTAssertEqual(error.code, MSIDErrorAmbiguousAuthority);
}


- (void)testGetTokenWithType_whenTypeAccessCorrectAccountAndParametersWithNoAuthority_shouldReturnToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];

    // Save token
    [_cacheAccessor saveTokensWithFactory:factory
                            configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                 response:tokenResponse
                                  context:nil
                                    error:nil];

    // Retrieve token
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/1234-5678-90abcdefg"];

    NSError *error = nil;
    MSIDAccessToken *returnedToken = [_cacheAccessor getAccessTokenForAccount:account
                                                                configuration:configuration
                                                                      context:nil
                                                                        error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
}

- (void)testGetTokenWithType_whenTypeAccessNoAuthority_andMultipleAuthoritiesFound_shouldReturnError
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];

    // save token 1
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.authority = [NSURL URLWithString:@"https://authority1.contoso.com"];

    [_cacheAccessor saveTokensWithFactory:factory
                            configuration:configuration
                                 response:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                  context:nil
                                    error:nil];

    // save token 2
    configuration.authority = [NSURL URLWithString:@"https://authority2.contoso.com"];
    [_cacheAccessor saveTokensWithFactory:factory
                           configuration:configuration
                                 response:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                  context:nil
                                    error:nil];

    // get token without specifying authority
    configuration.authority = nil;

    NSError *error = nil;
    MSIDAccessToken *returnedToken = [_cacheAccessor getAccessTokenForAccount:account
                                                                configuration:configuration
                                                                      context:nil
                                                                        error:&error];

    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorAmbiguousAuthority);
    XCTAssertNil(returnedToken);
}

- (void)testGetTokenWithType_whenTypeRefreshNoItemsInCache_shouldReturnNil
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];

    NSError *error = nil;

    MSIDRefreshToken *returnedToken = [_cacheAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}


- (void)testGetTokenWithType_whenTypeRefreshAccountWithUtidAndUidProvided_shouldReturnToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];
    [_cacheAccessor saveSSOStateWithFactory:factory
                              configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                   response:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                    context:nil
                                      error:nil];

    NSError *error = nil;

    MSIDRefreshToken *returnedToken = [_cacheAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
}

- (void)testGetTokenWithType_whenTypeRefreshAccountWithLegacyIDProvided_shouldReturnToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    [_cacheAccessor saveSSOStateWithFactory:factory
                              configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                   response:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                    context:nil
                                      error:nil];


    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:nil];

    NSError *error = nil;
    MSIDRefreshToken *returnedToken = [_cacheAccessor getRefreshTokenWithAccount:account
                                                                        familyId:nil
                                                                   configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                                         context:nil
                                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
}

#pragma mark - Remove

- (void)testRemoveToken_whenItemInCache_andAccountWithUidUtidProvided_shouldRemoveOnlyRTItems
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // Save an access token
    [_cacheAccessor saveTokensWithFactory:factory
                            configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                 response:response
                                  context:nil
                                    error:nil];

    // Save a refresh token
    [_cacheAccessor saveSSOStateWithFactory:factory
                              configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                   response:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                    context:nil
                                      error:nil];

    NSArray *allRefreshTokens = [self getAllRefreshTokens];
    XCTAssertEqual([allRefreshTokens count], 1);

    MSIDRefreshToken *firstRefreshToken = allRefreshTokens[0];

    NSError *error = nil;

    BOOL result = [_cacheAccessor validateAndRemoveRefreshToken:firstRefreshToken context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *allRTs = [self getAllRefreshTokens];
    XCTAssertEqual([allRTs count], 0);

    NSArray *allATs = [self getAllAccessTokens];
    XCTAssertEqual([allATs count], 1);

    NSArray *allIDs = [self getAllIDTokens];
    XCTAssertEqual([allIDs count], 0);
}

#pragma mark - Helpers

- (NSArray *)getAllAccessTokens
{
    return [self getAllTokensWithType:MSIDAccessTokenType];
}

- (NSArray *)getAllRefreshTokens
{
    return [self getAllTokensWithType:MSIDRefreshTokenType];
}

- (NSArray *)getAllIDTokens
{
    return [self getAllTokensWithType:MSIDIDTokenType];
}

- (NSArray *)getAllTokensWithType:(MSIDCredentialType)type
{
    NSError *error = nil;

    NSArray *allTokens = [_cacheAccessor allTokensWithContext:nil error:&error];
    XCTAssertNil(error);

    NSMutableArray *results = [NSMutableArray array];

    for (MSIDBaseToken *token in allTokens)
    {
        if (token.credentialType == type)
        {
            [results addObject:token];
        }
    }

    return results;
}

@end
