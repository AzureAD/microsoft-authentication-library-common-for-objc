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
#import "MSIDTestRequestParams.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDBaseToken.h"
#import "MSIDAccount.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDRequestParameters.h"

@interface MSIDDefaultTokenCacheIntegrationTests : XCTestCase
{
    MSIDDefaultTokenCacheAccessor *_cacheAccessor;
    MSIDTestCacheDataSource *_dataSource;
}
@end

@implementation MSIDDefaultTokenCacheIntegrationTests

#pragma mark - Setup

- (void)setUp
{
    _dataSource = [[MSIDTestCacheDataSource alloc] init];
    _cacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:_dataSource];
    
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Saving

- (void)testSaveTokensWithRequestParams_whenUniqueUserIdNil_shouldReturnError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:nil];
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];
    
    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                       account:account
                                                      response:tokenResponse
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testSaveTokensWithRequestParams_withAccessToken_shouldSaveToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                                      account:account
                                                     response:tokenResponse
                                                      context:nil
                                                        error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
    XCTAssertEqualObjects([accessTokensInCache[0] accessToken], tokenResponse.accessToken);
}

- (void)testSaveTokensWithRequestParams_withAccessTokenSameEverythingWithScopesIntersect_shouldOverwriteToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // save 1st token with default test scope
    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                                      account:account
                                                     response:tokenResponse
                                                      context:nil
                                                        error:nil];
    XCTAssertEqual([[_dataSource allDefaultAccessTokens] count], 1);
    
    // save 2nd token with intersecting scope
    NSOrderedSet<NSString *> *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, @"profile.read", nil];
    MSIDTokenResponse *tokenResponse2 = [MSIDTestTokenResponse v2DefaultTokenResponseWithScopes:scopes];
    
    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                                      account:account
                                                     response:tokenResponse2
                                                      context:nil
                                                        error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
    XCTAssertEqualObjects([accessTokensInCache[0] accessToken], tokenResponse2.accessToken);
}

- (void)testSaveTokensWithRequestParams_withAccessTokenSameEverythingWithScopesDontIntersect_shouldWriteNewToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // save 1st token with default test scope
    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                        account:account
                                       response:tokenResponse
                                        context:nil
                                          error:nil];
    XCTAssertEqual([[_dataSource allDefaultAccessTokens] count], 1);

    // save 2nd token with non-intersecting scope
    NSOrderedSet<NSString *> *scopes = [NSOrderedSet orderedSetWithObjects:@"profile.read", nil];
    MSIDTokenResponse *tokenResponse2 = [MSIDTestTokenResponse v2DefaultTokenResponseWithScopes:scopes];

    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                                      account:account
                                                     response:tokenResponse2
                                                      context:nil
                                                        error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokensInCache = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 2);
}

- (void)testSaveTokensWithRequestParams_withAccessTokenAndDifferentAuthorities_shouldSave2Tokens
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // save 1st token with default test scope
    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                        account:account
                                       response:tokenResponse
                                        context:nil
                                          error:nil];

    // save 2nd token with different authority
    MSIDTokenResponse *tokenResponse2 = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *requestParams = [MSIDTestRequestParams paramsWithAuthority:@"https://contoso2.com"
                                                                          clientId:DEFAULT_TEST_CLIENT_ID
                                                                       redirectUri:nil
                                                                            target:DEFAULT_TEST_SCOPE];
    
    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithRequestParams:requestParams
                                                      account:account
                                                     response:tokenResponse2
                                                      context:nil
                                                        error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokensInCache = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 2);
}

- (void)testSaveTokensWithRequestParams_withAccessTokenAndDifferentUsers_shouldSave2Tokens
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // save 1st token with default test scope
    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                        account:account
                                       response:tokenResponse
                                        context:nil
                                          error:nil];

    // save 2nd token with different user
    MSIDAccount *account2 = [[MSIDAccount alloc] initWithLegacyUserId:nil
                                                        uniqueUserId:@"222.qwe"];
    MSIDTokenResponse *tokenResponse2 = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                  RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                              scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                             idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                 uid:@"1"
                                                                                utid:@"1234-5678-90abcdefg"
                                                                            familyId:nil];

    NSError *error = nil;
    BOOL result = [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                                      account:account2
                                                     response:tokenResponse2
                                                      context:nil
                                                        error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *accessTokensInCache = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 2);
}

- (void)testSaveRefreshToken_withRTAndAccount_shouldSaveOneEntry
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v2DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_cacheAccessor saveRefreshToken:token
                                           account:account
                                           context:nil
                                             error:nil];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allDefaultRefreshTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
    XCTAssertEqualObjects(accessTokensInCache[0], token);
}

#pragma mark - Retrieve

- (void)testGetTokenWithType_whenTypeAccessNoItemsInCache_shouldReturnNil
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];

    NSError *error = nil;
    MSIDBaseToken *token = [_cacheAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                     account:account
                                               requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                     context:nil
                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(token);
}


- (void)testGetTokenWithType_whenTypeAccessAccountWithoutUniqueUserId_shouldReturnError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:nil];;

    NSError *error = nil;
    MSIDBaseToken *token = [_cacheAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                    account:account
                                              requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                    context:nil
                                                      error:&error];

    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertNil(token);
}

- (void)testGetTokenWithType_whenTypeAccessMultipleAccessTokensInCache_shouldReturnRightToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // save 1st token with default test scope
    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                        account:account
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

    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParamsWithScopes:scopes]
                                        account:account
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
    
    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams paramsWithAuthority:@"https://contoso2.com/common"
                                                                                  clientId:DEFAULT_TEST_CLIENT_ID
                                                                               redirectUri:nil
                                                                                    target:DEFAULT_TEST_SCOPE]
                                        account:account
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

    MSIDAccount *account2 = [[MSIDAccount alloc] initWithTokenResponse:tokenResponse4 request:[MSIDTestRequestParams v2DefaultParams]];

    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                        account:account2
                                       response:tokenResponse4
                                        context:nil
                                          error:nil];

    NSArray *accessTokensInCache = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 4);
    
    // retrieve first at
    NSError *error = nil;
    MSIDAccessToken *returnedToken = (MSIDAccessToken *)[_cacheAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                                                 account:account
                                                                           requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                                                 context:nil
                                                                                   error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
}

- (void)testGetTokenWithType_whenTypeAccessCorrectAccountAndParameters_shouldReturnToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // Save token
    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                        account:account
                                       response:tokenResponse
                                        context:nil
                                          error:nil];

    NSError *error = nil;
    MSIDAccessToken *returnedToken = (MSIDAccessToken *)[_cacheAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                                                 account:account
                                                                           requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                                                 context:nil
                                                                                   error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
}


- (void)testGetTokenWithType_whenTypeAccessCorrectAccountAndParametersWithNoAuthority_shouldReturnToken
{
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponse];

    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];

    // Save token
    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                        account:account
                                       response:tokenResponse
                                        context:nil
                                          error:nil];

    // Retrieve token
    MSIDRequestParameters *param = [MSIDTestRequestParams v2DefaultParams];
    param.authority = nil;

    NSError *error = nil;
    MSIDAccessToken *returnedToken = (MSIDAccessToken *)[_cacheAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                                                 account:account
                                                                           requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                                                 context:nil
                                                                                   error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
}

- (void)testGetTokenWithType_whenTypeAccessNoAuthority_andMultipleAuthoritiesFound_shouldReturnError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];

    // save token 1
    MSIDRequestParameters *param = [MSIDTestRequestParams v2DefaultParams];
    param.authority = [NSURL URLWithString:@"https://authority1.contoso.com"];

    [_cacheAccessor saveTokensWithRequestParams:param
                                        account:account
                                       response:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                        context:nil
                                          error:nil];

    // save token 2
    param.authority = [NSURL URLWithString:@"https://authority2.contoso.com"];
    [_cacheAccessor saveTokensWithRequestParams:param
                                        account:account
                                       response:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                        context:nil
                                          error:nil];

   // get token without specifying authority
    param.authority = nil;

    NSError *error = nil;
    MSIDAccessToken *returnedToken = (MSIDAccessToken *)[_cacheAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                                                 account:account
                                                                           requestParams:param
                                                                                 context:nil
                                                                                   error:&error];

    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorAmbiguousAuthority);
    XCTAssertNil(returnedToken);
}

- (void)testGetTokenWithType_whenTypeRefreshNoItemsInCache_shouldReturnNil
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];

    NSError *error = nil;
    MSIDRefreshToken *returnedToken = (MSIDRefreshToken *)[_cacheAccessor getTokenWithType:MSIDTokenTypeRefreshToken
                             account:account
                       requestParams:[MSIDTestRequestParams v2DefaultParams]
                             context:nil
                               error:&error];

    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}


- (void)testGetTokenWithType_whenTypeRefreshAccountWithUtidAndUidProvided_shouldReturnToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:nil
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v2DefaultParams]];

    [_cacheAccessor saveRefreshToken:token
                             account:account
                             context:nil
                               error:nil];

    NSError *error = nil;
    MSIDRefreshToken *returnedToken = (MSIDRefreshToken *)[_cacheAccessor getTokenWithType:MSIDTokenTypeRefreshToken
                                                                                   account:account
                                                                             requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                                                   context:nil
                                                                                     error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
}

- (void)testGetTokenWithType_whenTypeRefreshAccountWithUtidAndUidProvided_andOnlyAT_shouldReturnNil
{
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];

    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:nil
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];

    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                        account:account
                                       response:response
                                        context:nil
                                          error:nil];

    NSError *error = nil;
    MSIDRefreshToken *returnedToken = (MSIDRefreshToken *)[_cacheAccessor getTokenWithType:MSIDTokenTypeRefreshToken
                                                                                   account:account
                                                                             requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                                                   context:nil
                                                                                     error:&error];

    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}

- (void)testGetAllTokensOfType_whenTypeRefreshNoItemsInCache_shouldReturnEmptyResult
{
    NSError *error = nil;
    NSArray *results = [_cacheAccessor getAllTokensOfType:MSIDTokenTypeRefreshToken
                                             withClientId:[MSIDTestRequestParams v2DefaultParams].clientId
                                                  context:nil
                                                    error:nil];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 0);
}

- (void)testGetAllTokensOfType_whenTypeRefreshOnlyAccessTokenItemsInCache_shouldNotReturnToken
{
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:nil
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    // Save token
    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                        account:account
                                       response:response
                                        context:nil
                                          error:nil];

    NSError *error = nil;
    NSArray *results = [_cacheAccessor getAllTokensOfType:MSIDTokenTypeRefreshToken
                                             withClientId:[MSIDTestRequestParams v2DefaultParams].clientId
                                                  context:nil
                                                    error:nil];

    XCTAssertNil(error);
    XCTAssertEqual([results count], 0);
}

- (void)testGetAllTokensOfType_whenTypeRefreshItemsInCacheAccountWithUtidUidProvided_shouldReturnItems
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:nil
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v2DefaultParams]];
    // Save token
    [_cacheAccessor saveRefreshToken:token
                             account:account
                             context:nil
                               error:nil];



    NSError *error = nil;
    NSArray *results = [_cacheAccessor getAllTokensOfType:MSIDTokenTypeRefreshToken
                                             withClientId:[MSIDTestRequestParams v2DefaultParams].clientId
                                                  context:nil
                                                    error:nil];

    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], token);
}

- (void)testGetAllTokensOfType_whenTypeRefreshBothATandRTinCache_andAccountWithUtidUidProvided_shouldReturnItems
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];

    // Save an access token & refresh token
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];

    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                        account:account
                                       response:response
                                        context:nil
                                          error:nil];

    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                             request:[MSIDTestRequestParams v2DefaultParams]];

    [_cacheAccessor saveRefreshToken:refreshToken
                             account:account
                             context:nil
                               error:nil];

    // retrieve all RTs
    NSError *error = nil;
    NSArray *results = [_cacheAccessor getAllTokensOfType:MSIDTokenTypeRefreshToken
                                             withClientId:[MSIDTestRequestParams v2DefaultParams].clientId
                                                  context:nil
                                                    error:nil];

    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

#pragma mark - Remove

- (void)testRemoveToken_whenItemInCache_andAccountWithUidUtidProvided_shouldRemoveOnlyRTItems
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];

    // Save an access token
    [_cacheAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v2DefaultParams]
                                        account:account
                                       response:response
                                        context:nil
                                          error:nil];

    // Save a refresh token
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                             request:[MSIDTestRequestParams v2DefaultParams]];

    [_cacheAccessor saveRefreshToken:refreshToken
                             account:account
                             context:nil
                               error:nil];

    NSError *error = nil;
    BOOL result = [_cacheAccessor removeToken:refreshToken account:account context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *allRTs = [_dataSource allDefaultRefreshTokens];
    XCTAssertEqual([allRTs count], 0);

    NSArray *allATs = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([allATs count], 1);
}

@end
