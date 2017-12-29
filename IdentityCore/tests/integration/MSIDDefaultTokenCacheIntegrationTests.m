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
#import "MSIDToken.h"
#import "MSIDAccount.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAADV1RequestParameters.h"
#import "MSIDAADV2RequestParameters.h"

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
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeAccessToken];
    
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
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeAccessToken];
    
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
    
    MSIDToken *token1 = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                         request:[MSIDTestRequestParams v2DefaultParams]
                                                       tokenType:MSIDTokenTypeAccessToken];
    
    // save 1st token with default test scope
    [_cacheAccessor saveAccessToken:token1
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    XCTAssertEqual([[_dataSource allDefaultAccessTokens] count], 1);
    
    // save 2nd token with intersecting scope
    NSOrderedSet<NSString *> *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, @"profile.read", nil];
    
    MSIDToken *token2 = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponseWithScopes:scopes]
                                                         request:[MSIDTestRequestParams v2DefaultParams]
                                                       tokenType:MSIDTokenTypeAccessToken];
    
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
    
    MSIDToken *token1 = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                         request:[MSIDTestRequestParams v2DefaultParams]
                                                       tokenType:MSIDTokenTypeAccessToken];
    
    // save 1st token with default test scope
    [_cacheAccessor saveAccessToken:token1
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    XCTAssertEqual([[_dataSource allDefaultAccessTokens] count], 1);
    
    // save 2nd token with non-intersecting scope
    NSOrderedSet<NSString *> *scopes = [NSOrderedSet orderedSetWithObjects:@"profile.read", nil];
    
    MSIDToken *token2 = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponseWithScopes:scopes]
                                                         request:[MSIDTestRequestParams v2DefaultParams]
                                                       tokenType:MSIDTokenTypeAccessToken];
    
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



- (void)testSaveSharedRTForAccount_withRT_shouldSaveOneEntry
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    NSError *error = nil;
    
    BOOL result = [_cacheAccessor saveAccessToken:token
                                          account:account
                                    requestParams:[MSIDTestRequestParams v2DefaultParams]
                                          context:nil
                                            error:&error];
    
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
    MSIDToken *token = [_cacheAccessor getATForAccount:account
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
    MSIDToken *token = [_cacheAccessor getATForAccount:account
                                         requestParams:[MSIDTestRequestParams v1DefaultParams]
                                               context:nil
                                                 error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(token);
}

- (void)testGetAccessToken_withCorrectAccountAndParameters_shouldReturnToken
{
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeAccessToken];
    
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
    MSIDToken *returnedToken = [_cacheAccessor getATForAccount:account
                                                 requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetAccessToken_withCorrectAccountAndParametersWithNoAuthority_shouldReturnToken
{
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeAccessToken];
    
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
    MSIDToken *returnedToken = [_cacheAccessor getATForAccount:account
                                                 requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetAccessToken_withCorrectAccountAndParametersWithNoAuthorityMultipleAuthoritiesFound_shouldReturnError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // save token 1
    MSIDAADV2RequestParameters *param = [MSIDTestRequestParams v2DefaultParams];
    param.authority = [NSURL URLWithString:@"https://authority1.contoso.com"];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:param
                                                      tokenType:MSIDTokenTypeAccessToken];
    
    [_cacheAccessor saveAccessToken:token
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
    // save token 2
    param.authority = [NSURL URLWithString:@"https://authority2.contoso.com"];
    
    MSIDToken *token2 = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                         request:param
                                                       tokenType:MSIDTokenTypeAccessToken];
    
    [_cacheAccessor saveAccessToken:token2
                            account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
   // get token without specifying authority
    param.authority = nil;
    
    NSError *error = nil;
    MSIDToken *returnedToken = [_cacheAccessor getATForAccount:account
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
    MSIDToken *token = [_cacheAccessor getSharedRTForAccount:account
                                               requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                     context:nil
                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(token);
}

- (void)testGetSharedRTForAccount_whenAccountWithUtidAndUidProvided_shouldReturnToken
{
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_cacheAccessor saveSharedRTForAccount:account
                              refreshToken:token
                                   context:nil
                                     error:nil];
    
    NSError *error = nil;

    MSIDToken *returnedToken = [_cacheAccessor getSharedRTForAccount:account
                                                        requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                              context:nil
                                                                error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetSharedRTForAccount_whenAccountWithUtidAndUidProvided_andOnlyAT_shouldReturnNil
{
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeAccessToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_cacheAccessor saveSharedRTForAccount:account
                              refreshToken:token
                                   context:nil
                                     error:nil];
    
    NSError *error = nil;

    MSIDToken *returnedToken = [_cacheAccessor getSharedRTForAccount:account
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
    MSIDToken *returnedToken = [_cacheAccessor getSharedRTForAccount:account
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

- (void)testGetAllSharedRTs_whenOnlyAccessTokenItemsInCache_shouldReturnToken
{
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeAccessToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_cacheAccessor saveSharedRTForAccount:account
                              refreshToken:token
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
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
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
    MSIDToken *accessToken = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                              request:[MSIDTestRequestParams v2DefaultParams]
                                                            tokenType:MSIDTokenTypeAccessToken];

    [_cacheAccessor saveAccessToken:accessToken account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
    
    MSIDToken *refreshToken = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                               request:[MSIDTestRequestParams v2DefaultParams]
                                                             tokenType:MSIDTokenTypeRefreshToken];
    
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
    
    MSIDToken *accessToken = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                              request:[MSIDTestRequestParams v2DefaultParams]
                                                            tokenType:MSIDTokenTypeAccessToken];
    
    // Save an access token
    [_cacheAccessor saveAccessToken:accessToken account:account
                      requestParams:[MSIDTestRequestParams v2DefaultParams]
                            context:nil
                              error:nil];
    
    // Save a refresh token
    MSIDToken *refreshToken = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                               request:[MSIDTestRequestParams v2DefaultParams]
                                                             tokenType:MSIDTokenTypeRefreshToken];
    
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






@end
