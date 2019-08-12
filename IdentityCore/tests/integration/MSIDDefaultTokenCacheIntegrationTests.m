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
#import "MSIDTestIdentifiers.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDAccountIdentifier.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDTestCacheAccessorHelper.h"
#import "MSIDCache.h"
#import "MSIDIntuneInMemoryCacheDataSource.h"
#import "MSIDIntuneEnrollmentIdsCache.h"

@interface MSIDDefaultTokenCacheIntegrationTests : XCTestCase
{
    MSIDDefaultTokenCacheAccessor *_cacheAccessor;
    MSIDLegacyTokenCacheAccessor *_otherAccessor;
    id<MSIDExtendedTokenCacheDataSource> _dataSource;
}
@end

@implementation MSIDDefaultTokenCacheIntegrationTests

#pragma mark - Setup

- (void)setUp
{

#if TARGET_OS_IOS
    _dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil error:nil];
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

    [[MSIDAadAuthorityCache sharedInstance] removeAllObjects];
    [_dataSource removeTokensWithKey:[MSIDCacheKey new] context:nil error:nil];
}

#pragma mark - Saving

- (void)testSaveTokensWithRequestParams_whenHomeAccountIdNil_shouldReturnError
{
    NSOrderedSet *set = [NSOrderedSet orderedSetWithObjects:@"user.read", nil];
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2TokenResponseWithAT:@"at" RT:@"rt" scopes:set idToken:nil uid:nil utid:nil familyId:nil];

    NSError *error = nil;

    BOOL result = [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                     response:tokenResponse
                                                      factory:[MSIDAADV2Oauth2Factory new]
                                                      context:nil
                                                        error:&error];

    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testSaveTokensWithRequestParams_withAccessToken_shouldSaveToken
{
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                     response:tokenResponse
                                                      factory:[MSIDAADV2Oauth2Factory new]
                                                      context:nil
                                                        error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_cacheAccessor];
    XCTAssertNil(error);

    XCTAssertEqual([accessTokens count], 1);
    XCTAssertEqualObjects([accessTokens[0] accessToken], tokenResponse.accessToken);
}

- (void)testSaveTokensWithRequestParams_withAccessToken_andIntuneEnrolled_shouldSaveToken
{
    [self setUpEnrollmentIdsCache:NO];
    
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.applicationIdentifier = @"app.bundle.id";
    
    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithConfiguration:configuration
                                                     response:tokenResponse
                                                      factory:[MSIDAADV2Oauth2Factory new]
                                                      context:nil
                                                        error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_cacheAccessor];
    XCTAssertNil(error);
    
    XCTAssertEqual([accessTokens count], 1);
    XCTAssertEqualObjects([accessTokens[0] accessToken], tokenResponse.accessToken);
    XCTAssertEqualObjects([accessTokens[0] enrollmentId], @"enrollmentId");
    
    [self setUpEnrollmentIdsCache:YES];
}

- (void)testSaveTokensWithRequestParams_withNilAccessToken_shouldNotSaveToken_returnError
{
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2TokenResponseWithAT:nil
                                                                                 RT:@"rt"
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                            idToken:@"id_token"
                                                                                uid:@"uid"
                                                                               utid:@"utid"
                                                                           familyId:@"family_id"];

    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                     response:tokenResponse
                                                      factory:[MSIDAADV2Oauth2Factory new]
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
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    BOOL result = [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                     response:tokenResponse
                                                      factory:[MSIDAADV2Oauth2Factory new]
                                                      context:nil
                                                        error:nil];

    NSArray *allTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_cacheAccessor];
    XCTAssertEqual([allTokens count], 1);

    // save 2nd token with intersecting scope
    NSOrderedSet<NSString *> *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, @"profile.read", nil];
    MSIDTokenResponse *tokenResponse2 = [MSIDTestTokenResponse v2DefaultTokenResponseWithScopes:scopes];

    NSError *error = nil;
    result = [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                response:tokenResponse2
                                                 factory:[MSIDAADV2Oauth2Factory new]
                                                 context:nil
                                                   error:nil];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokensInCache = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_cacheAccessor];
    XCTAssertEqual([accessTokensInCache count], 1);
    XCTAssertEqualObjects([accessTokensInCache[0] accessToken], tokenResponse2.accessToken);
}

- (void)testSaveTokensWithRequestParams_withAccessTokenAndDifferentAuthorities_shouldSave2Tokens
{
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];
    
    NSError *error = nil;
    
    // save 1st token with default test scope
    BOOL result = [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                     response:tokenResponse
                                                      factory:[MSIDAADV2Oauth2Factory new]
                                                      context:nil
                                                        error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // save 2nd token with different authority
    MSIDTokenResponse *tokenResponse2 = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                  RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                              scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                             idToken:[MSIDTestIdTokenUtil idTokenWithName:@"name" upn:@"upn@upn.com" oid:@"oid" tenantId:@"tid2"]
                                                                                 uid:DEFAULT_TEST_UID
                                                                                utid:DEFAULT_TEST_UTID
                                                                            familyId:nil];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithAuthority:@"https://login.microsoftonline.com/8eaef023-2b34-4da1-9baa-8bc8c9d6a490"
                                                                                clientId:DEFAULT_TEST_CLIENT_ID
                                                                             redirectUri:nil
                                                                                  target:DEFAULT_TEST_SCOPE];
    
    result = [_cacheAccessor saveTokensWithConfiguration:configuration
                                                response:tokenResponse2
                                                 factory:[MSIDAADV2Oauth2Factory new]
                                                 context:nil
                                                   error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_cacheAccessor];
    XCTAssertEqual([accessTokensInCache count], 2);
}

- (void)testSaveTokensWithRequestParams_withAccessTokenSameEverythingWithScopesDontIntersect_shouldWriteNewToken
{
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // save 1st token with default test scope
    BOOL result = [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                     response:tokenResponse
                                                      factory:[MSIDAADV2Oauth2Factory new]
                                                      context:nil
                                                        error:nil];

    NSArray *accessTokensInCache = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_cacheAccessor];
    XCTAssertEqual([accessTokensInCache count], 1);

    // save 2nd token with non-intersecting scope
    NSOrderedSet<NSString *> *scopes = [NSOrderedSet orderedSetWithObjects:@"profile.read", nil];
    MSIDTokenResponse *tokenResponse2 = [MSIDTestTokenResponse v2DefaultTokenResponseWithScopes:scopes];

    NSError *error = nil;

    result = [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                response:tokenResponse2
                                                 factory:[MSIDAADV2Oauth2Factory new]
                                                 context:nil
                                                   error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    accessTokensInCache = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_cacheAccessor];
    XCTAssertEqual([accessTokensInCache count], 2);
}


- (void)testSaveTokensWithRequestParams_withAccessTokenAndDifferentUsers_shouldSave2Tokens
{
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // save 1st token with default test scope

    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                     response:tokenResponse
                                                      factory:[MSIDAADV2Oauth2Factory new]
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

    result = [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                response:tokenResponse2
                                                 factory:[MSIDAADV2Oauth2Factory new]
                                                 context:nil
                                                   error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokensInCache = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_cacheAccessor];
    XCTAssertEqual([accessTokensInCache count], 2);
}

- (void)testSaveTokensWithRequestParams_withNilIDToken_shouldNotSaveIDToken_andSaveAccessToken
{
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2TokenResponseWithAT:@"at"
                                                                                 RT:@"rt"
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                            idToken:nil
                                                                                uid:@"uid"
                                                                               utid:@"utid"
                                                                           familyId:@"family_id"];

    NSError *error = nil;

    BOOL result = [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                     response:tokenResponse
                                                      factory:[MSIDAADV2Oauth2Factory new]
                                                      context:nil
                                                        error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokensInCache = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_cacheAccessor];
    XCTAssertEqual([accessTokensInCache count], 1);

    NSArray *idTokensInCache = [MSIDTestCacheAccessorHelper getAllIdTokens:_cacheAccessor];
    XCTAssertEqual([idTokensInCache count], 0);
}

- (void)testSaveTokensWithRequestParams_withIDToken_shouldSaveIDToken_andSaveAccessToken
{
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2TokenResponseWithAT:@"at"
                                                                                 RT:@"rt"
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                            idToken:@"id_token"
                                                                                uid:@"uid"
                                                                               utid:@"utid"
                                                                           familyId:@"family_id"];

    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                     response:tokenResponse
                                                      factory:[MSIDAADV2Oauth2Factory new]
                                                      context:nil
                                                        error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokensInCache = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_cacheAccessor];
    XCTAssertEqual([accessTokensInCache count], 1);

    NSArray *idTokensInCache = [MSIDTestCacheAccessorHelper getAllIdTokens:_cacheAccessor];
    XCTAssertEqual([idTokensInCache count], 1);
}

- (void)testSaveSSOState_withResponse_shouldSaveOneRefreshTokenEntry
{
    NSError *error = nil;

    BOOL result = [_cacheAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                       response:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        factory:[MSIDAADV2Oauth2Factory new]
                                                        context:nil
                                                          error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *refreshTokensInCache = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_cacheAccessor];
    XCTAssertEqual([refreshTokensInCache count], 1);
}

- (void)testSaveRefreshToken_whenNoAccountIdentifier_shouldReturnError
{
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"user.read", nil];
    MSIDTokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:@"at"
                                                                            RT:@"rt"
                                                                        scopes:scopes
                                                                       idToken:nil
                                                                           uid:nil
                                                                          utid:nil
                                                                      familyId:nil];

    NSError *error = nil;

    BOOL result = [_cacheAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                       response:response
                                                        factory:[MSIDAADV2Oauth2Factory new]
                                                        context:nil
                                                          error:&error];

    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

#pragma mark - Retrieve

- (void)testGetTokenWithType_whenTypeAccessNoItemsInCache_shouldReturnNil
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
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
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // save 1st token with default test scope
    [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                       response:tokenResponse
                                        factory:[MSIDAADV2Oauth2Factory new]
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

    [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfigurationWithScopes:scopes]
                                       response:tokenResponse2
                                        factory:[MSIDAADV2Oauth2Factory new]
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

    [_cacheAccessor saveTokensWithConfiguration:configuration
                                       response:tokenResponse3
                                        factory:[MSIDAADV2Oauth2Factory new]
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

    [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                       response:tokenResponse4
                                        factory:[MSIDAADV2Oauth2Factory new]
                                        context:nil
                                          error:nil];

    NSArray *accessTokensInCache = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_cacheAccessor];
    XCTAssertEqual([accessTokensInCache count], 4);

    configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.authority = [@"https://login.microsoftonline.com/1234-5678-90abcdefg" aadAuthority];

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
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // Save token
    [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                       response:tokenResponse
                                        factory:[MSIDAADV2Oauth2Factory new]
                                        context:nil
                                          error:nil];

    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.authority = [@"https://login.microsoftonline.com/1234-5678-90abcdefg" aadAuthority];

    NSError *error = nil;

    MSIDAccessToken *returnedToken = [_cacheAccessor getAccessTokenForAccount:account
                                                                configuration:configuration
                                                                      context:nil
                                                                        error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertNil(returnedToken.enrollmentId);
}

- (void)testGetTokenWithType_whenTypeAccessCorrectAccountAndParameters_andIntuneEnrolled_shouldReturnToken
{
    [self setUpEnrollmentIdsCache:NO];
    
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                            homeAccountId:@"1.1234-5678-90abcdefg"];
    
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.applicationIdentifier = @"app.bundle.id";
    
    // Save token
    [_cacheAccessor saveTokensWithConfiguration:configuration
                                       response:tokenResponse
                                        factory:[MSIDAADV2Oauth2Factory new]
                                        context:nil
                                          error:nil];
    
    configuration.authority = [@"https://login.microsoftonline.com/1234-5678-90abcdefg" aadAuthority];
    
    NSError *error = nil;
    
    MSIDAccessToken *returnedToken = [_cacheAccessor getAccessTokenForAccount:account
                                                                configuration:configuration
                                                                      context:nil
                                                                        error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(returnedToken.enrollmentId, @"enrollmentId");
    
    [self setUpEnrollmentIdsCache:YES];
}

- (void)testGetTokenWithType_whenTypeAccessCorrectAccountAndParametersWithNoAuthority_shouldReturnToken
{
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];

    // Save token
    [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                       response:tokenResponse
                                        factory:[MSIDAADV2Oauth2Factory new]
                                        context:nil
                                          error:nil];

    // Retrieve token
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.authority = [@"https://login.microsoftonline.com/1234-5678-90abcdefg" aadAuthority];

    NSError *error = nil;
    MSIDAccessToken *returnedToken = [_cacheAccessor getAccessTokenForAccount:account
                                                                configuration:configuration
                                                                      context:nil
                                                                        error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
}

- (void)testGetTokenWithType_whenTypeRefreshNoItemsInCache_shouldReturnNil
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
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
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil
                                                                              homeAccountId:@"1.1234-5678-90abcdefg"];
    [_cacheAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                         response:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                          factory:[MSIDAADV2Oauth2Factory new]
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
    [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                       response:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                        factory:[MSIDAADV2Oauth2Factory new]
                                        context:nil
                                          error:nil];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
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
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // Save an access token
    [_cacheAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                       response:response
                                        factory:[MSIDAADV2Oauth2Factory new]
                                        context:nil
                                          error:nil];

    // Save a refresh token
    [_cacheAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                         response:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                          factory:[MSIDAADV2Oauth2Factory new]
                                          context:nil
                                            error:nil];

    NSArray *allRefreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_cacheAccessor];
    XCTAssertEqual([allRefreshTokens count], 1);

    MSIDRefreshToken *firstRefreshToken = allRefreshTokens[0];

    NSError *error = nil;

    BOOL result = [_cacheAccessor validateAndRemoveRefreshToken:firstRefreshToken
                                                        context:nil
                                                          error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *allRTs = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:_cacheAccessor];
    XCTAssertEqual([allRTs count], 0);

    NSArray *allATs = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:_cacheAccessor];
    XCTAssertEqual([allATs count], 1);

    NSArray *allIDs = [MSIDTestCacheAccessorHelper getAllIdTokens:_cacheAccessor];
    XCTAssertEqual([allIDs count], 1);
}

#pragma mark - Helpers

- (void)setUpEnrollmentIdsCache:(BOOL)isEmpty
{
    NSDictionary *emptyDict = @{};
    
    NSDictionary *dict = @{MSID_INTUNE_ENROLLMENT_ID_KEY: @{@"enrollment_ids": @[@{
                                                                                     @"tid" : @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1",
                                                                                     @"oid" : @"d3444455-mike-4271-b6ea-e499cc0cab46",
                                                                                     @"home_account_id" : @"1.1234-5678-90abcdefg",
                                                                                     @"user_id" : @"mike@contoso.com",
                                                                                     @"enrollment_id" : @"enrollmentId"
                                                                                     },
                                                                                 @{
                                                                                     @"tid" : @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1",
                                                                                     @"oid" : @"6eec576f-dave-416a-9c4a-536b178a194a",
                                                                                     @"home_account_id" : @"1e4dd613-dave-4527-b50a-97aca38b57ba",
                                                                                     @"user_id" : @"dave@contoso.com",
                                                                                     @"enrollment_id" : @"64d0557f-dave-4193-b630-8491ffd3b180"
                                                                                     }
                                                                                 ]}};
    
    MSIDCache *msidCache = [[MSIDCache alloc] initWithDictionary:isEmpty ? emptyDict : dict];
    MSIDIntuneInMemoryCacheDataSource *memoryCache = [[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:msidCache];
    MSIDIntuneEnrollmentIdsCache *enrollmentIdsCache = [[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:memoryCache];
    [MSIDIntuneEnrollmentIdsCache setSharedCache:enrollmentIdsCache];
}

@end
