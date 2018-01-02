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
#import "MSIDAADV1RequestParameters.h"
#import "MSIDAADV2RequestParameters.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"

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


- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


#pragma mark - Saving

- (void)testSaveAccessToken_withV1RequestParameters_shouldReturnError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                    request:[MSIDTestRequestParams v2DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_cacheAccessor saveAccessToken:token
                                          account:account
                                    requestParams:[MSIDTestRequestParams v1DefaultParams]
                                          context:nil
                                            error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testSaveAccessToken_withTokenAndAccount_shouldSaveToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                    request:[MSIDTestRequestParams v2DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_cacheAccessor saveAccessToken:token
                                          account:account
                                    requestParams:[MSIDTestRequestParams v2DefaultParams]
                                          context:nil
                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
    XCTAssertEqualObjects(accessTokensInCache[0], token);
}


- (void)testSaveAccessToken_sameEverythingWithScopesIntersect_shouldOverwriteToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAccessToken *token1 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                     request:[MSIDTestRequestParams v2DefaultParams]];
    
    // save 1st token with default test scope
    [_cacheAccessor saveAccessToken:token1
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    XCTAssertEqual([[_dataSource allDefaultAccessTokens] count], 1);
    
    // save 2nd token with intersecting scope
    NSOrderedSet<NSString *> *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, @"profile.read", nil];
    
    MSIDAccessToken *token2 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponseWithScopes:scopes]
                                                                     request:[MSIDTestRequestParams v2DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_cacheAccessor saveAccessToken:token2
                                          account:account
                                    requestParams:[MSIDTestRequestParams v2DefaultParamsWithScopes:scopes]
                                          context:nil
                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
    XCTAssertEqualObjects(accessTokensInCache[0], token2);
}


- (void)testSaveAccessToken_sameEverythingWithScopesDontIntersect_shouldWriteNewToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAccessToken *token1 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                     request:[MSIDTestRequestParams v2DefaultParams]];
    
    // save 1st token with default test scope
    [_cacheAccessor saveAccessToken:token1
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    XCTAssertEqual([[_dataSource allDefaultAccessTokens] count], 1);
    
    // save 2nd token with non-intersecting scope
    NSOrderedSet<NSString *> *scopes = [NSOrderedSet orderedSetWithObjects:@"profile.read", nil];
    
    MSIDAccessToken *token2 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponseWithScopes:scopes]
                                                                     request:[MSIDTestRequestParams v2DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_cacheAccessor saveAccessToken:token2
                                          account:account
                                    requestParams:[MSIDTestRequestParams v2DefaultParamsWithScopes:scopes]
                                          context:nil
                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 2);
    XCTAssertEqualObjects(accessTokensInCache[0], token1);
    XCTAssertEqualObjects(accessTokensInCache[1], token2);
}


- (void)testSaveAccessToken_withDifferentAuthorities_shouldSave2Tokens
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAccessToken *token1 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                     request:[MSIDTestRequestParams v2DefaultParams]];
    
    // save 1st token with default test scope
    [_cacheAccessor saveAccessToken:token1
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
    // save 2nd token with different authority
    MSIDAccessToken *token3 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                                           RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                                       scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                                                      idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                                          uid:DEFAULT_TEST_UID
                                                                                                         utid:DEFAULT_TEST_UTID
                                                                                                     familyId:nil]
                                                         request:[MSIDTestRequestParams v2ParamsWithAuthority:[NSURL URLWithString:@"https://contoso2.com"]
                                                                                                  redirectUri:nil
                                                                                                     clientId:DEFAULT_TEST_CLIENT_ID
                                                                                                       scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]]];
    NSError *error = nil;
    BOOL result = [_cacheAccessor saveAccessToken:token3
                                          account:account
                                    requestParams:[MSIDTestRequestParams v2DefaultParams]
                                          context:nil
                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 2);
    
}

- (void)testSaveAccessToken_withDifferentUsers_shouldSave2Tokens
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAccessToken *token1 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                     request:[MSIDTestRequestParams v2DefaultParams]];
    
    // save 1st token with default test scope
    [_cacheAccessor saveAccessToken:token1
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
    // save 2nd token with different user
    MSIDAccount *account2 = [[MSIDAccount alloc] initWithUpn:nil utid:@"UTID2" uid:@"UID2"];
    
    MSIDAccessToken *token4 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                                           RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                                       scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                                                      idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                                          uid:account2.uid
                                                                                                         utid:account2.utid
                                                                                                     familyId:nil]
                                                                     request:[MSIDTestRequestParams v2DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_cacheAccessor saveAccessToken:token4
                                          account:account2
                                    requestParams:[MSIDTestRequestParams v2DefaultParams]
                                          context:nil
                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 2);
}

- (void)testSaveSharedRTForAccount_withRT_shouldSaveOneEntry
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v2DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_cacheAccessor saveSharedRTForAccount:account
                                            refreshToken:token
                                                 context:nil error:nil];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allDefaultRefreshTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
    XCTAssertEqualObjects(accessTokensInCache[0], token);
}

#pragma mark - Retrieve

- (void)testGetAccessToken_whenNoItemsInCache_shouldReturnNil
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    MSIDAccessToken *token = [_cacheAccessor getATForAccount:account
                                               requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                     context:nil
                                                       error:&error];
    
    XCTAssertNil(error);
    
    XCTAssertNil(token);
}

- (void)testGetAccessToken_withWrongParameters_shouldReturnError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    MSIDAccessToken *token = [_cacheAccessor getATForAccount:account
                                               requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                     context:nil
                                                       error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertNil(token);
}

- (void)testGetAccessToken_withMultipleAccessTokensInCache_shouldReturnRightToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAccessToken *token1 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                     request:[MSIDTestRequestParams v2DefaultParams]];
    
    // save 1st token with default test scope
    [_cacheAccessor saveAccessToken:token1
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
    // save 2nd token with non-intersecting scope
    NSOrderedSet<NSString *> *scopes = [NSOrderedSet orderedSetWithObjects:@"profile.read", nil];
    
    MSIDAccessToken *token2 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponseWithScopes:scopes]
                                                                     request:[MSIDTestRequestParams v2DefaultParamsWithScopes:scopes]];
   
    [_cacheAccessor saveAccessToken:token2
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParamsWithScopes:scopes]
                            context:nil
                              error:nil];

    // save 3rd token with different authority
    MSIDAccessToken *token3 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                                           RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                                       scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                                                      idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                                          uid:DEFAULT_TEST_UID
                                                                                                         utid:DEFAULT_TEST_UTID
                                                                                                     familyId:nil]
                                                                     request:[MSIDTestRequestParams v2ParamsWithAuthority:[NSURL URLWithString:@"https://contoso2.com"]
                                                                                                  redirectUri:nil
                                                                                                     clientId:DEFAULT_TEST_CLIENT_ID
                                                                                                       scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]]];
    
    [_cacheAccessor saveAccessToken:token3
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParamsWithScopes:scopes]
                            context:nil
                              error:nil];
    
    // save 4th token with different user
    MSIDAccount *account2 = [[MSIDAccount alloc] initWithUpn:nil utid:@"UTID2" uid:@"UID2"];
    
    MSIDAccessToken *token4 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                                           RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                                       scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                                                      idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                                          uid:account2.uid
                                                                                                         utid:account2.utid
                                                                                                     familyId:nil]
                                                                     request:[MSIDTestRequestParams v2DefaultParams]];
    
    [_cacheAccessor saveAccessToken:token4
                            account:account2
                      requestParams:[MSIDTestRequestParams v2DefaultParamsWithScopes:scopes]
                            context:nil
                              error:nil];
    
    NSArray *accessTokensInCache = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 4);
    
    // retrieve first at
    NSError *error = nil;
    MSIDAccessToken *returnedToken = [_cacheAccessor getATForAccount:account
                                                       requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                             context:nil
                                                               error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token1, returnedToken);
}

- (void)testGetAccessToken_withCorrectAccountAndParameters_shouldReturnToken
{
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                    request:[MSIDTestRequestParams v2DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save token
    [_cacheAccessor saveAccessToken:token
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
    NSError *error = nil;
    MSIDAccessToken *returnedToken = [_cacheAccessor getATForAccount:account
                                                       requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                             context:nil
                                                               error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetAccessToken_withCorrectAccountAndParametersWithNoAuthority_shouldReturnToken
{
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                    request:[MSIDTestRequestParams v2DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save token
    [_cacheAccessor saveAccessToken:token
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
    // Retrieve token
    MSIDAADV2RequestParameters *param = [MSIDTestRequestParams v2DefaultParams];
    param.authority = nil;
    
    NSError *error = nil;
    MSIDAccessToken *returnedToken = [_cacheAccessor getATForAccount:account
                                                       requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                             context:nil
                                                               error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetAccessToken_withNoAuthority_andMultipleAuthoritiesFound_shouldReturnError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // save token 1
    MSIDAADV2RequestParameters *param = [MSIDTestRequestParams v2DefaultParams];
    param.authority = [NSURL URLWithString:@"https://authority1.contoso.com"];
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                    request:param];
    
    [_cacheAccessor saveAccessToken:token
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
    // save token 2
    param.authority = [NSURL URLWithString:@"https://authority2.contoso.com"];
    
    MSIDAccessToken *token2 = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                     request:param];
    
    [_cacheAccessor saveAccessToken:token2
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
   // get token without specifying authority
    param.authority = nil;
    
    NSError *error = nil;
    MSIDAccessToken *returnedToken = [_cacheAccessor getATForAccount:account
                                                       requestParams:param
                                                             context:nil
                                                               error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorAmbiguousAuthority);
    XCTAssertNil(returnedToken);
}


- (void)testGetSharedRTForAccount_whenNoItemsInCache_shouldReturnNil
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    MSIDRefreshToken *token = [_cacheAccessor getSharedRTForAccount:account
                                                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                            context:nil
                                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(token);
}

- (void)testGetSharedRTForAccount_whenAccountWithUtidAndUidProvided_shouldReturnToken
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v2DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_cacheAccessor saveSharedRTForAccount:account
                              refreshToken:token
                                   context:nil
                                     error:nil];
    
    NSError *error = nil;

    MSIDRefreshToken *returnedToken = [_cacheAccessor getSharedRTForAccount:account
                                                              requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                                    context:nil
                                                                      error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetSharedRTForAccount_whenAccountWithUtidAndUidProvided_andOnlyAT_shouldReturnNil
{
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                    request:[MSIDTestRequestParams v2DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_cacheAccessor saveAccessToken:token
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil error:nil];
    
    NSError *error = nil;

    MSIDRefreshToken *returnedToken = [_cacheAccessor getSharedRTForAccount:account
                                                              requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                                    context:nil
                                                                      error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}


- (void)testGetSharedRTForAccount_whenAccountWithNoUtidAndUidProvided_shouldReturnError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    NSError *error = nil;
    MSIDRefreshToken *returnedToken = [_cacheAccessor getSharedRTForAccount:account
                                                              requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                                    context:nil
                                                                      error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(returnedToken);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testGetAllSharedRTs_whenNoItemsInCache_shouldReturnEmptyResult
{
    NSError *error = nil;
    NSArray *results = [_cacheAccessor getAllSharedRTsWithClientId:[MSIDTestRequestParams v2DefaultParams].clientId
                                                           context:nil
                                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 0);
}

- (void)testGetAllSharedRTs_whenOnlyAccessTokenItemsInCache_shouldNotReturnToken
{
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                    request:[MSIDTestRequestParams v2DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_cacheAccessor saveAccessToken:token
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    // Save token
    NSError *error = nil;
    
    NSArray *results = [_cacheAccessor getAllSharedRTsWithClientId:[MSIDTestRequestParams v2DefaultParams].clientId
                                                           context:nil
                                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 0);
}

- (void)testGetAllSharedRTs_whenItemsInCacheAccountWithUtidUidProvided_shouldReturnItems
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v2DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save token
    [_cacheAccessor saveSharedRTForAccount:account
                              refreshToken:token
                                   context:nil
                                     error:nil];
    
    NSError *error = nil;
    NSArray *results = [_cacheAccessor getAllSharedRTsWithClientId:[MSIDTestRequestParams v2DefaultParams].clientId
                                                           context:nil
                                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], token);
}

- (void)testGetAllSharedRTsAfterSaving_whenBothATandRTinCache_andAccountWithUtidUidProvided_shouldReturnItems
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save an access token & refresh token
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                          request:[MSIDTestRequestParams v2DefaultParams]];

    [_cacheAccessor saveAccessToken:accessToken account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
    
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                             request:[MSIDTestRequestParams v2DefaultParams]];
    
    [_cacheAccessor saveSharedRTForAccount:account
                              refreshToken:refreshToken
                                   context:nil
                                     error:nil];

    // retrieve all RTs
    NSError *error = nil;
    
    NSArray *results = [_cacheAccessor getAllSharedRTsWithClientId:[MSIDTestRequestParams v2DefaultParams].clientId
                                                           context:nil
                                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

#pragma mark - Remove

- (void)testRemoveSharedRTForAccount_whenItemInCache_andAccountWithUidUtidProvided_shouldRemoveOnlyRTItems
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                          request:[MSIDTestRequestParams v2DefaultParams]];
    
    // Save an access token
    [_cacheAccessor saveAccessToken:accessToken account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
    // Save a refresh token
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                             request:[MSIDTestRequestParams v2DefaultParams]];
    
    [_cacheAccessor saveSharedRTForAccount:account
                              refreshToken:refreshToken
                                   context:nil
                                     error:nil];

    NSError *error = nil;
    BOOL result = [_cacheAccessor removeSharedRTForAccount:account
                                                     token:refreshToken
                                                   context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *allRTs = [_dataSource allDefaultRefreshTokens];
    XCTAssertEqual([allRTs count], 0);
    
    NSArray *allATs = [_dataSource allDefaultAccessTokens];
    XCTAssertEqual([allATs count], 1);
}

- (void)testRemoveSharedRTForAccount_whenItemInCache_butWithDifferentRT_shouldNotRemoveItem
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save a refresh token
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                                             request:[MSIDTestRequestParams v2DefaultParams]];
    
    [_cacheAccessor saveSharedRTForAccount:account
                              refreshToken:refreshToken
                                   context:nil
                                     error:nil];
    
    NSError *error = nil;

    // Delete a token with different refresh token value
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponseWithRefreshToken:@"DIFFTOKEN"];
    MSIDRefreshToken *refreshTokenToDelete = [[MSIDRefreshToken alloc] initWithTokenResponse:response
                                                                                     request:[MSIDTestRequestParams v2DefaultParams]];
    
    BOOL result = [_cacheAccessor removeSharedRTForAccount:account
                                                     token:refreshTokenToDelete
                                                   context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *allRTs = [_dataSource allDefaultRefreshTokens];
    XCTAssertEqual([allRTs count], 1);
}

@end
