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
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDTestConfiguration.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDBaseToken.h"
#import "MSIDAccount.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDUserInformation.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDAADV1Oauth2Factory.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDLegacyRefreshToken.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDLegacyTokenCacheTests : XCTestCase
{
    MSIDLegacyTokenCacheAccessor *_legacyAccessor;
    MSIDLegacyTokenCacheAccessor *_nonSSOAccessor;
    MSIDDefaultTokenCacheAccessor *_otherAccessor;
    id<MSIDTokenCacheDataSource> _dataSource;
}

@end

@implementation MSIDLegacyTokenCacheTests

#pragma mark - Setup

- (void)setUp
{

#if TARGET_OS_IOS
    _dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
#else
    // TODO: this should be replaced with a real macOS datasource instead
    _dataSource = [[MSIDTestCacheDataSource alloc] init];
#endif
    MSIDOauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    _otherAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:_dataSource otherCacheAccessors:nil factory:factory];
    _legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:_dataSource otherCacheAccessors:@[_otherAccessor] factory:factory];
    _nonSSOAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:_dataSource otherCacheAccessors:nil factory:factory];
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];

    [_dataSource removeItemsWithKey:[MSIDCacheKey new] context:nil error:nil];
}

#pragma mark - Saving

- (void)testSaveTokensWithconfiguration_withMultiResourceResponse_shouldSaveAccessToken
{
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponse];
    
    
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:tokenResponse
                                                       context:nil
                                                         error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
    XCTAssertEqualObjects([accessTokensInCache[0] accessToken], tokenResponse.accessToken);
}

- (void)testSaveTokensWithconfiguration_withMultiResourceResponseAndNoAccessToken_shouldNotSaveAccessToken
{
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v1TokenResponseWithAT:nil
                                                                                 rt:@"rt"
                                                                           resource:@"resource"
                                                                                uid:@"uid"
                                                                               utid:@"utid"
                                                                                upn:@"upn"
                                                                           tenantId:@"tenantId"
                                                                   additionalFields:nil];
    
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:tokenResponse
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    
    NSArray *accessTokensInCache = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 0);
}

- (void)testSaveTokensWithconfiguration_withAccessToken_andAccountWithoutUPN_shouldSaveToken
{
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [self getAllLegacyAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
}

- (void)testSaveTokensWithconfiguration_withLegacyTokenAndAccount_shouldSaveToken
{
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:[MSIDTestTokenResponse v1SingleResourceTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *legacyTokensInCache = [self getAllLegacyTokens];
    XCTAssertEqual([legacyTokensInCache count], 1);
    
    MSIDLegacySingleResourceToken *legacyToken = legacyTokensInCache[0];
    XCTAssertEqual(legacyToken.credentialType, MSIDLegacySingleResourceTokenType);
    XCTAssertEqualObjects(legacyToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(legacyToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
}

- (void)testSaveTokensWithconfiguration_withADFSTokenNoAccessToken_shouldNotSaveToken
{
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v1TokenResponseWithAT:nil
                                                                                 rt:@"rt"
                                                                           resource:@"resource"
                                                                                uid:@"uid"
                                                                               utid:@"utid"
                                                                                upn:@"upn"
                                                                           tenantId:@"tenantId"
                                                                   additionalFields:nil];
    
    NSError *error = nil;

    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:tokenResponse
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    
    NSArray *accessTokensInCache = [self getAllLegacyTokens];
    XCTAssertEqual([accessTokensInCache count], 0);
}

- (void)testSaveRefreshTokenForAccount_withMRRT_shouldSaveOneEntry
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDRefreshToken *token = [factory legacyRefreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] configuration:[MSIDTestConfiguration v1DefaultConfiguration]];
    
    NSError *error = nil;

    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *refreshTokensInCache = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokensInCache count], 1);
    XCTAssertEqualObjects(refreshTokensInCache[0], token);
}

- (void)testSaveRefreshTokenForAccount_withMultipleTokensAndDifferentResources_shouldSaveOneEntry
{
    // Save first token
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    
    NSError *error = nil;

    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Save second token
    MSIDTokenResponse *secondResponse = [MSIDTestTokenResponse v1TokenResponseWithAT:@"new access token"
                                                                                  rt:@"new refresh token"
                                                                            resource:@"resource2"
                                                                                 uid:DEFAULT_TEST_UID
                                                                                utid:DEFAULT_TEST_UTID
                                                                                 upn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                            tenantId:DEFAULT_TEST_UTID
                                                                    additionalFields:nil];
    
    MSIDConfiguration *secondConfiguration = [MSIDTestConfiguration configurationWithAuthority:DEFAULT_TEST_AUTHORITY
                                                                                      clientId:DEFAULT_TEST_CLIENT_ID
                                                                                   redirectUri:nil
                                                                                        target:@"resource2"];

    MSIDLegacyRefreshToken *secondToken = [factory legacyRefreshTokenFromResponse:secondResponse configuration:secondConfiguration];

    result = [_legacyAccessor saveTokensWithConfiguration:secondConfiguration
                                                 response:secondResponse
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *refreshTokensInCache = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokensInCache count], 1);
    // Check that the token got overriden
    XCTAssertEqualObjects(refreshTokensInCache[0], secondToken);
}

- (void)testSaveSharedRTForAccount_withMRRT_andAccountWithoutUPN_shouldSaveToken
{
    NSError *error = nil;

    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *refreshTokensInCache = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokensInCache count], 1);
}

#pragma mark - Retrieve

- (void)testTokenWithType_withAccessTokenType_whenNoItemsInCache_shouldReturnNil
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"some id"];
    
    NSError *error = nil;
    MSIDLegacyAccessToken *token = [_legacyAccessor getAccessTokenForAccount:account
                                                               configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                     context:nil
                                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(token);
}

- (void)testGetAccessToken_withAccountWithoutUPN_whenOnlyOneTokenInCache_shouldReturnToken
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"some id"];
    
    // Save token
    NSError *error = nil;

    [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                        response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                         context:nil
                                           error:&error];
    XCTAssertNil(error);
    
    account.legacyAccountId = nil;

    MSIDLegacyAccessToken *token = [_legacyAccessor getAccessTokenForAccount:account
                                                               configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                     context:nil
                                                                       error:&error];

    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqual(token.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
}

- (void)testGetAccessTokenAfterSaving_withCorrectAccountAndParameters_shouldReturnToken
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"some id"];
    
    // Save token
    NSError *error = nil;

    [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                        response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                         context:nil
                                           error:&error];

    MSIDLegacyAccessToken *token = [_legacyAccessor getAccessTokenForAccount:account
                                                               configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                     context:nil
                                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    
    XCTAssertEqual(token.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
}

- (void)testGetAccessToken_withMultipleTokensInCacheWithDifferentResources_andCorrectAccountAndParameters_shouldReturnCorrectToken
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"some id"];
    
    // Save first token
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Second token
    MSIDTokenResponse *secondResponse = [MSIDTestTokenResponse v1TokenResponseWithAT:@"second_at"
                                                                                  rt:@"second_rt"
                                                                            resource:@"second_resource"
                                                                                 uid:DEFAULT_TEST_UID
                                                                                utid:DEFAULT_TEST_UTID
                                                                                 upn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                            tenantId:DEFAULT_TEST_UTID
                                                                    additionalFields:nil];
    
    result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                 response:secondResponse
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that correct token is returned
    MSIDLegacyAccessToken *token = [_legacyAccessor getAccessTokenForAccount:account
                                                               configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                     context:nil
                                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    
    XCTAssertEqualObjects(token.resource, DEFAULT_TEST_RESOURCE);
    
    NSArray *allAccessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([allAccessTokens count], 2);
}

- (void)testGetAccessToken_withMultipleTokensInCacheWithDifferentAuthorities_andCorrectAccountAndParameters_shouldReturnCorrectToken
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"some id"];
    
    // Save first token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Second token
    MSIDConfiguration *secondConfiguration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.microsoftonline.com/contoso.com/"
                                                                                      clientId:DEFAULT_TEST_CLIENT_ID
                                                                                   redirectUri:nil
                                                                                        target:DEFAULT_TEST_RESOURCE];
    
    result = [_legacyAccessor saveTokensWithConfiguration:secondConfiguration
                                                 response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                  context:nil
                                                    error:&error];
    
    // Check that correct token is returned
    MSIDLegacyAccessToken *token = [_legacyAccessor getAccessTokenForAccount:account
                                                               configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                     context:nil
                                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.authority, [NSURL URLWithString:DEFAULT_TEST_AUTHORITY]);
    NSArray *allAccessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([allAccessTokens count], 2);
}

- (void)testGetAccessToken_withMultipleTokensInCacheWithDifferentClientIds_andCorrectAccountAndParameters_shouldReturnCorrectToken
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"some id"];
    
    // Save first token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Second token
    MSIDConfiguration *secondConfiguration = [MSIDTestConfiguration configurationWithAuthority:DEFAULT_TEST_AUTHORITY
                                                                                      clientId:@"client_id_2"
                                                                                   redirectUri:nil
                                                                                        target:DEFAULT_TEST_RESOURCE];
    
    result = [_legacyAccessor saveTokensWithConfiguration:secondConfiguration
                                                 response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that correct token is returned
    MSIDLegacyAccessToken *token = [_legacyAccessor getAccessTokenForAccount:account
                                                               configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                     context:nil
                                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.clientId, DEFAULT_TEST_CLIENT_ID);
    
    NSArray *allAccessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([allAccessTokens count], 2);
}

- (void)testGetAccessToken_withMultipleTokensInCacheWithDifferentUsers_andCorrectAccountAndParameters_shouldReturnCorrectToken
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"some id"];
    
    // Save first token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSIDTokenResponse *secondResponse = [MSIDTestTokenResponse v1TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                  rt:DEFAULT_TEST_REFRESH_TOKEN
                                                                            resource:DEFAULT_TEST_RESOURCE
                                                                                 uid:@"uid2"
                                                                                utid:DEFAULT_TEST_UTID
                                                                                 upn:@"user2@contoso.com"
                                                                            tenantId:DEFAULT_TEST_UTID
                                                                    additionalFields:nil];


    result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                 response:secondResponse
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that correct token is returned
    MSIDLegacyAccessToken *token = [_legacyAccessor getAccessTokenForAccount:account
                                                               configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                     context:nil
                                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.homeAccountId, @"1.1234-5678-90abcdefg");
    
    NSArray *allAccessTokens = [self getAllLegacyAccessTokens];
    XCTAssertEqual([allAccessTokens count], 2);
}

- (void)testGetLegacyToken_withCorrectAccountAndParameters_shouldReturnToken
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@""
                                                                              homeAccountId:nil];
    
    // Save legacy token response
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                      response:[MSIDTestTokenResponse v1SingleResourceTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);

    MSIDLegacySingleResourceToken *token = [_legacyAccessor getSingleResourceTokenForAccount:account
                                                                               configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                                     context:nil
                                                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    
    XCTAssertEqual(token.credentialType, MSIDLegacySingleResourceTokenType);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
}

- (void)testGetSharedRTForAccount_whenNoItemsInCache_shouldReturnNil
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"some id"];
    
    NSError *error = nil;

    MSIDRefreshToken *returnedToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                          context:nil
                                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}

- (void)testGetSharedRTForAccountAfterSaving_whenAccountWithUPNProvided_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDRefreshToken *token = [factory legacyRefreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] configuration:[MSIDTestConfiguration v1DefaultConfiguration]];
    token.storageAuthority = token.authority;
    
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:nil];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                        response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                         context:nil
                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSIDRefreshToken *returnedToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                          context:nil
                                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetSharedRTForAccountAfterSaving_whenMultipleRTsWithDifferentAuthorities_shouldSaveTwoTokensAndReturnCorrectToken
{
    // Save first token
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDRefreshToken *firstToken = [factory legacyRefreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] configuration:[MSIDTestConfiguration v1DefaultConfiguration]];
    firstToken.storageAuthority = firstToken.authority;
    
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:nil];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                        response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                         context:nil
                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Save second token
    MSIDConfiguration *secondConfiguration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.microsoftonline.com/contoso.com/"
                                                                                      clientId:DEFAULT_TEST_CLIENT_ID
                                                                                   redirectUri:nil
                                                                                        target:DEFAULT_TEST_RESOURCE];

    result = [_legacyAccessor saveSSOStateWithConfiguration:secondConfiguration
                                                   response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                    context:nil
                                                      error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that correct token is returned
    MSIDRefreshToken *returnedToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                          context:nil
                                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(firstToken, returnedToken);
    
    NSArray *allRTs = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([allRTs count], 2);
}

- (void)testGetSharedRTForAccountAfterSaving_whenAccountWithUidUtidProvided_shouldReturnToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDRefreshToken *token = [factory legacyRefreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] configuration:[MSIDTestConfiguration v1DefaultConfiguration]];
    token.storageAuthority = token.authority;
    
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                        response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                         context:nil
                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil
                                                       homeAccountId:@"1.1234-5678-90abcdefg"];
    
    // Check that correct token is returned
    MSIDRefreshToken *returnedToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                          context:nil
                                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetSharedRTForAccountAfterSaving_whenAccountWithUidUtidProvided_andOrganizationsAuthority_shouldReturnToken
{
    MSIDConfiguration *organizationConfiguration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.microsoftonline.com/organizations"
                                                                                            clientId:DEFAULT_TEST_CLIENT_ID
                                                                                         redirectUri:nil
                                                                                              target:DEFAULT_TEST_SCOPE];

    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDRefreshToken *token = [factory legacyRefreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] configuration:organizationConfiguration];
    token.storageAuthority = token.authority;
    
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                        response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                         context:nil
                                                           error:&error];

    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil
                                                       homeAccountId:@"1.1234-5678-90abcdefg"];
    
    // Check that correct token is returned
    MSIDRefreshToken *returnedToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:organizationConfiguration
                                                                          context:nil
                                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    token.storageAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    XCTAssertEqualObjects(token, returnedToken);
    XCTAssertEqualObjects(returnedToken.storageAuthority, [NSURL URLWithString:@"https://login.microsoftonline.com/common"]);
}

- (void)testGetSharedRTForAccountAfterSaving_whenConsumerAuthority_shouldReturnNil
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_nonSSOAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                        response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                         context:nil
                                                           error:&error];

    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSIDConfiguration *consumerParameters = [MSIDTestConfiguration configurationWithAuthority:@"https://login.microsoftonline.com/consumers"
                                                                                     clientId:DEFAULT_TEST_CLIENT_ID
                                                                                  redirectUri:nil
                                                                                       target:DEFAULT_TEST_SCOPE];
    
    // Check that correct token is returned
    MSIDRefreshToken *returnedToken = [_nonSSOAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:consumerParameters
                                                                          context:nil
                                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}

- (void)testGetSharedRTForAccountAfterSaving_whenMultipleLegacyItemsInCache_andAccountWithUidUtidProvided_shouldNotReturnNil
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:nil];
    
    // Save first token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                        response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                         context:nil
                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    account.legacyAccountId = @"user Id 2";

    MSIDTokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:@"at"
                                                                            rt:@"rt 2"
                                                                      resource:DEFAULT_TEST_RESOURCE
                                                                           uid:DEFAULT_TEST_UID
                                                                          utid:DEFAULT_TEST_UTID
                                                                           upn:@"user Id 2"
                                                                      tenantId:@"tid2"
                                                              additionalFields:nil];
    
    result = [_legacyAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                   response:response
                                                    context:nil
                                                      error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil
                                                       homeAccountId:@"1.1234-5678-90abcdefg"];
    
    // Check that correct token is returned
    MSIDRefreshToken *returnedToken = [_legacyAccessor getRefreshTokenWithAccount:account
                                                                         familyId:nil
                                                                    configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                          context:nil
                                                                            error:&error];
    
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.refreshToken, @"refresh_token");
}

#pragma mark - Remove

- (void)testRemovedSharedRTForAccount_whenNoItemsInCacheTokenProvided_shouldReturnYes
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDLegacyRefreshToken *token = [factory legacyRefreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo] configuration:[MSIDTestConfiguration v1DefaultConfiguration]];
    
    NSError *error = nil;

    BOOL result = [_legacyAccessor validateAndRemoveRefreshToken:token context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testRemovedSharedRTForAccount_whenNoItemsInCache_andAccountWithoutUPNProvided_shouldSucceed
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDLegacyRefreshToken *token = [factory legacyRefreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo] configuration:[MSIDTestConfiguration v1DefaultConfiguration]];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor validateAndRemoveRefreshToken:token context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testRemovedSharedRTForAccount_whenNoItemsInCacheNilTokenProvided_shouldReturnFalseAndFillError
{
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor validateAndRemoveRefreshToken:nil context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
}

- (void)testRemovedSharedRTForAccount_whenItemsInCacheNilTokenProvided_shouldReturnFalseAndFillError
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDRefreshToken *token = [factory legacyRefreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo] configuration:[MSIDTestConfiguration v1DefaultConfiguration]];

    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                        response:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                         context:nil
                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    result = [_legacyAccessor validateAndRemoveRefreshToken:nil context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    
    NSArray *allRTs = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([allRTs count], 1);
    XCTAssertEqualObjects(allRTs[0], token);
}

- (void)testRemoveSharedRTForAccount_whenItemInCache_andAccountAndTokenProvided_shouldRemoveItem
{    
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                        response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                         context:nil
                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *refreshTokens = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([refreshTokens count], 1);
    
    result = [_legacyAccessor validateAndRemoveRefreshToken:refreshTokens[0] context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *allRTs = [self getAllLegacyRefreshTokens];
    XCTAssertEqual([allRTs count], 0);
}

#pragma mark - Helpers

- (NSArray *)getAllLegacyAccessTokens
{
    return [self getAllTokensWithType:MSIDAccessTokenType class:MSIDLegacyAccessToken.class];
}

- (NSArray *)getAllLegacyRefreshTokens
{
    return [self getAllTokensWithType:MSIDRefreshTokenType class:MSIDLegacyRefreshToken.class];
}

- (NSArray *)getAllLegacyTokens
{
    return [self getAllTokensWithType:MSIDLegacySingleResourceTokenType class:MSIDLegacySingleResourceToken.class];
}

- (NSArray *)getAllTokensWithType:(MSIDCredentialType)type class:(Class)typeClass
{
    NSError *error = nil;

    NSArray *allTokens = [_legacyAccessor allTokensWithContext:nil error:&error];
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

