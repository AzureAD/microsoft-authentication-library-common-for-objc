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
#import "MSIDTestRequestParams.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDBaseToken.h"
#import "MSIDAccount.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAADV1RequestParameters.h"
#import "MSIDAADV2RequestParameters.h"
#import "MSIDAdfsToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"

@interface MSIDLegacyTokenCacheTests : XCTestCase
{
    MSIDLegacyTokenCacheAccessor *_legacyAccessor;
    MSIDTestCacheDataSource *_dataSource;
}

@end

@implementation MSIDLegacyTokenCacheTests

#pragma mark - Setup

- (void)setUp
{
    _dataSource = [[MSIDTestCacheDataSource alloc] init];
    _legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:_dataSource];
    
    [super setUp];
}

#pragma mark - Saving

- (void)testSaveAccessToken_withWrongParameters_shouldReturnError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                    request:[MSIDTestRequestParams v1DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveAccessToken:token
                                           account:account
                                     requestParams:[MSIDTestRequestParams v2DefaultParams]
                                           context:nil
                                             error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testSaveAccessToken_withAccessTokenAndAccount_shouldSaveToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                    request:[MSIDTestRequestParams v1DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveAccessToken:token
                                           account:account
                                     requestParams:[MSIDTestRequestParams v1DefaultParams]
                                           context:nil
                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allLegacyAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
    XCTAssertEqualObjects(accessTokensInCache[0], token);
}

- (void)testSaveAccessToken_withAccessToken_andAccountWithoutUPN_shouldFail
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                    request:[MSIDTestRequestParams v1DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveAccessToken:token
                                           account:account
                                     requestParams:[MSIDTestRequestParams v1DefaultParams]
                                           context:nil
                                             error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertFalse(result);
    
    NSArray *accessTokensInCache = [_dataSource allLegacyAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 0);
}

- (void)testSaveAccessToken_withADFSTokenAndAccount_shouldSaveToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAdfsToken *token = [[MSIDAdfsToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                request:[MSIDTestRequestParams v1DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveAccessToken:token
                                           account:account
                                     requestParams:[MSIDTestRequestParams v1DefaultParams]
                                           context:nil
                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allLegacyADFSTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
    XCTAssertEqualObjects(accessTokensInCache[0], token);
}

- (void)testSaveSharedRTForAccount_withMRRT_shouldSaveOneEntry
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *refreshTokensInCache = [_dataSource allLegacyRefreshTokens];
    XCTAssertEqual([refreshTokensInCache count], 1);
    XCTAssertEqualObjects(refreshTokensInCache[0], token);
}

- (void)testSaveSharedRTForAccount_withMultipleTokensAndDifferentResources_shouldSaveOneEntry
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save first token
    MSIDRefreshToken *firstToken = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                           request:[MSIDTestRequestParams v1DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:firstToken
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
                                                                            tenantId:DEFAULT_TEST_UTID];
    
    MSIDRequestParameters *secondParams = [MSIDTestRequestParams v1ParamsWithAuthority:DEFAULT_TEST_AUTHORITY
                                                                              clientId:DEFAULT_TEST_CLIENT_ID
                                                                              resource:@"resource2"];
    
    MSIDRefreshToken *secondToken = [[MSIDRefreshToken alloc] initWithTokenResponse:secondResponse
                                                                            request:secondParams];
    
    result = [_legacyAccessor saveSharedRTForAccount:account
                                        refreshToken:secondToken
                                             context:nil
                                               error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *refreshTokensInCache = [_dataSource allLegacyRefreshTokens];
    XCTAssertEqual([refreshTokensInCache count], 1);
    // Check that the token got overriden
    XCTAssertEqualObjects(refreshTokensInCache[0], secondToken);
}

- (void)testSaveSharedRTForAccount_withMRRT_andAccountWithoutUPN_shouldFail
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertFalse(result);
    
    NSArray *refreshTokensInCache = [_dataSource allLegacyRefreshTokens];
    XCTAssertEqual([refreshTokensInCache count], 0);
}

#pragma mark - Retrieve

- (void)testGetAccessToken_whenNoItemsInCache_shouldReturnNil
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    MSIDAccessToken *token = [_legacyAccessor getATForAccount:account
                                                requestParams:[MSIDTestRequestParams v1DefaultParams]
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
    MSIDAccessToken *token = [_legacyAccessor getATForAccount:account
                                                requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                      context:nil
                                                        error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertNil(token);
}

- (void)testGetAccessToken_withAccountWithoutUPN_shouldReturnError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    MSIDAccessToken *token = [_legacyAccessor getATForAccount:account
                                                requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                      context:nil
                                                        error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertNil(token);
}

- (void)testGetAccessTokenAfterSaving_withCorrectAccountAndParameters_shouldReturnToken
{
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                    request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save token
    NSError *error = nil;
    [_legacyAccessor saveAccessToken:token
                             account:account
                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                             context:nil
                               error:&error];
    
    MSIDAccessToken *returnedToken = [_legacyAccessor getATForAccount:account
                                                        requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                              context:nil
                                                                error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetAccessToken_withMultipleTokensInCacheWithDifferentResources_andCorrectAccountAndParameters_shouldReturnCorrectToken
{
    // First token
    MSIDAccessToken *firstToken = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                         request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save first token
    NSError *error = nil;
    [_legacyAccessor saveAccessToken:firstToken
                             account:account
                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                             context:nil
                               error:&error];
    
    // Second token
    MSIDTokenResponse *secondResponse = [MSIDTestTokenResponse v1TokenResponseWithAT:@"second_at"
                                                                                  rt:@"second_rt"
                                                                            resource:@"second_resource"
                                                                                 uid:DEFAULT_TEST_UID
                                                                                utid:DEFAULT_TEST_UTID
                                                                                 upn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                            tenantId:DEFAULT_TEST_UTID];
    
    MSIDAccessToken *secondToken = [[MSIDAccessToken alloc] initWithTokenResponse:secondResponse
                                                                          request:[MSIDTestRequestParams v1DefaultParams]];
    
    [_legacyAccessor saveAccessToken:secondToken
                             account:account
                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                             context:nil
                               error:&error];
    
    // Check that correct token is returned
    MSIDAccessToken *returnedToken = [_legacyAccessor getATForAccount:account
                                                        requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                              context:nil
                                                                error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(firstToken);
    XCTAssertEqualObjects(returnedToken, firstToken);
    
    NSArray *allAccessTokens = [_dataSource allLegacyAccessTokens];
    XCTAssertEqual([allAccessTokens count], 2);
}

- (void)testGetAccessToken_withMultipleTokensInCacheWithDifferentAuthorities_andCorrectAccountAndParameters_shouldReturnCorrectToken
{
    // First token
    MSIDAccessToken *firstToken = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                         request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save first token
    NSError *error = nil;
    [_legacyAccessor saveAccessToken:firstToken
                             account:account
                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                             context:nil
                               error:&error];
    
    // Second token
    MSIDRequestParameters *secondParams = [MSIDTestRequestParams v1ParamsWithAuthority:@"https://login.microsoftonline.com/contoso.com/"
                                                                              clientId:DEFAULT_TEST_CLIENT_ID
                                                                              resource:DEFAULT_TEST_RESOURCE];
    
    MSIDAccessToken *secondToken = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                          request:secondParams];
    
    [_legacyAccessor saveAccessToken:secondToken
                             account:account
                       requestParams:secondParams
                             context:nil
                               error:&error];
    
    // Check that correct token is returned
    MSIDAccessToken *returnedToken = [_legacyAccessor getATForAccount:account
                                                  requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                        context:nil
                                                          error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(firstToken);
    XCTAssertEqualObjects(returnedToken, firstToken);
    
    NSArray *allAccessTokens = [_dataSource allLegacyAccessTokens];
    XCTAssertEqual([allAccessTokens count], 2);
}

- (void)testGetAccessToken_withMultipleTokensInCacheWithDifferentClientIds_andCorrectAccountAndParameters_shouldReturnCorrectToken
{
    // First token
    MSIDAccessToken *firstToken = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                         request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save first token
    NSError *error = nil;
    [_legacyAccessor saveAccessToken:firstToken
                             account:account
                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                             context:nil
                               error:&error];
    
    // Second token
    MSIDRequestParameters *secondParams = [MSIDTestRequestParams v1ParamsWithAuthority:DEFAULT_TEST_AUTHORITY
                                                                              clientId:@"client_id_2"
                                                                              resource:DEFAULT_TEST_RESOURCE];
    
    MSIDAccessToken *secondToken = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                          request:secondParams];
    
    [_legacyAccessor saveAccessToken:secondToken
                             account:account
                       requestParams:secondParams
                             context:nil
                               error:&error];
    
    // Check that correct token is returned
    MSIDAccessToken *returnedToken = [_legacyAccessor getATForAccount:account
                                                        requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                              context:nil
                                                                error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(firstToken);
    XCTAssertEqualObjects(returnedToken, firstToken);
    
    NSArray *allAccessTokens = [_dataSource allLegacyAccessTokens];
    XCTAssertEqual([allAccessTokens count], 2);
}

- (void)testGetAccessToken_withMultipleTokensInCacheWithDifferentUsers_andCorrectAccountAndParameters_shouldReturnCorrectToken
{
    // First token
    MSIDAccessToken *firstToken = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                         request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save first token
    NSError *error = nil;
    [_legacyAccessor saveAccessToken:firstToken
                             account:account
                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                             context:nil
                               error:&error];
    
    // Second token
    MSIDAccount *secondAccount = [[MSIDAccount alloc] initWithUpn:@"user2@contoso.com"
                                                             utid:@"utid2"
                                                              uid:@"uid2"];
    
    MSIDAccessToken *secondToken = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                          request:[MSIDTestRequestParams v1DefaultParams]];
    
    [_legacyAccessor saveAccessToken:secondToken
                             account:secondAccount
                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                             context:nil
                               error:&error];
    
    // Check that correct token is returned
    MSIDAccessToken *returnedToken = [_legacyAccessor getATForAccount:account
                                                        requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                              context:nil
                                                                error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(firstToken);
    XCTAssertEqualObjects(returnedToken, firstToken);
    
    NSArray *allAccessTokens = [_dataSource allLegacyAccessTokens];
    XCTAssertEqual([allAccessTokens count], 2);
}

- (void)testGetADFSToken_withCorrectAccountAndParameters_shouldReturnToken
{
    MSIDAdfsToken *token = [[MSIDAdfsToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1SingleResourceTokenResponse]
                                                                request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:@""
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    [_legacyAccessor saveAccessToken:token
                             account:account
                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                             context:nil
                               error:&error];
    
    MSIDAdfsToken *returnedToken = [_legacyAccessor getADFSTokenWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                          context:nil
                                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetSharedRTForAccount_whenNoItemsInCache_shouldReturnNil
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    MSIDRefreshToken *token = [_legacyAccessor getSharedRTForAccount:account
                                                requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                      context:nil
                                                        error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(token);
}

- (void)testGetSharedRTForAccountAfterSaving_whenAccountWithUPNProvided_shouldReturnToken
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    [_legacyAccessor saveSharedRTForAccount:account
                               refreshToken:token
                                    context:nil
                                      error:&error];
    
    MSIDRefreshToken *returnedToken = [_legacyAccessor getSharedRTForAccount:account
                                                               requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                     context:nil
                                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetSharedRTForAccountAfterSaving_whenMultipleRTsWithDifferentAuthorities_shouldReturnCorrectToken
{
    // Save first token
    MSIDRefreshToken *firstToken = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                           request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    [_legacyAccessor saveSharedRTForAccount:account
                               refreshToken:firstToken
                                    context:nil
                                      error:&error];
    
    // Save second token
    MSIDRequestParameters *secondParams = [MSIDTestRequestParams v1ParamsWithAuthority:@"https://login.microsoftonline.com/contoso.com/"
                                                                              clientId:DEFAULT_TEST_CLIENT_ID
                                                                              resource:DEFAULT_TEST_RESOURCE];
    
    MSIDRefreshToken *secondToken = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                            request:secondParams];
    
    [_legacyAccessor saveSharedRTForAccount:account
                               refreshToken:secondToken
                                    context:nil
                                      error:&error];
    
    // Check that correct token is returned
    MSIDRefreshToken *returnedToken = [_legacyAccessor getSharedRTForAccount:account
                                                               requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                     context:nil
                                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(firstToken, returnedToken);
    
    NSArray *allRTs = [_dataSource allLegacyRefreshTokens];
    XCTAssertEqual([allRTs count], 2);
}

- (void)testGetSharedRTForAccountAfterSaving_whenAccountWithUidUtidProvided_shouldReturnToken
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save token
    NSError *error = nil;
    [_legacyAccessor saveSharedRTForAccount:account
                               refreshToken:token
                                    context:nil
                                      error:&error];
    
    account = [[MSIDAccount alloc] initWithUpn:nil
                                          utid:DEFAULT_TEST_UTID
                                           uid:DEFAULT_TEST_UID];
    
    MSIDRefreshToken *returnedToken = [_legacyAccessor getSharedRTForAccount:account
                                                               requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                     context:nil
                                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetSharedRTForAccountAfterSaving_whenLegacyItemsInCache_andAccountWithUidUtidProvided_shouldReturnNil
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    [_legacyAccessor saveSharedRTForAccount:account
                               refreshToken:token
                                    context:nil
                                      error:&error];
    
    account = [[MSIDAccount alloc] initWithUpn:nil
                                          utid:DEFAULT_TEST_UTID
                                           uid:DEFAULT_TEST_UID];
    
    MSIDRefreshToken *returnedToken = [_legacyAccessor getSharedRTForAccount:account
                                                               requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                     context:nil
                                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}

- (void)testGetAllSharedRTs_whenNoItemsInCache_shouldReturnEmptyResult
{
    NSError *error = nil;
    NSArray *results = [_legacyAccessor getAllSharedRTsWithClientId:DEFAULT_TEST_CLIENT_ID
                                                            context:nil
                                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 0);

}

- (void)testGetAllSharedRTsAfterSaving_whenItemsInCacheAccountWithUPNProvided_shouldReturnItems
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    [_legacyAccessor saveSharedRTForAccount:account
                               refreshToken:token
                                    context:nil
                                      error:&error];
    
    NSArray *results = [_legacyAccessor getAllSharedRTsWithClientId:DEFAULT_TEST_CLIENT_ID
                                                            context:nil
                                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], token);
}

- (void)testGetAllSharedRTsAfterSaving_whenBothATandRTinCache_andAccountWithUPNProvided_shouldReturnItems
{
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                          request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save an access token
    NSError *error = nil;
    [_legacyAccessor saveAccessToken:accessToken account:account
                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                             context:nil
                               error:&error];
    
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                             request:[MSIDTestRequestParams v1DefaultParams]];
    
    // Save token
    [_legacyAccessor saveSharedRTForAccount:account
                               refreshToken:refreshToken
                                    context:nil
                                      error:&error];
    
    NSArray *results = [_legacyAccessor getAllSharedRTsWithClientId:DEFAULT_TEST_CLIENT_ID
                                                            context:nil
                                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

- (void)testGetAllSharedRTs_whenLegacyItemsInCache_shouldReturnItems
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    [_legacyAccessor saveSharedRTForAccount:account
                               refreshToken:token
                                    context:nil
                                      error:&error];
    
    NSArray *results = [_legacyAccessor getAllSharedRTsWithClientId:DEFAULT_TEST_CLIENT_ID
                                                            context:nil
                                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], token);
}

#pragma mark - Remove

- (void)testRemovedSharedRTForAccount_whenNoItemsInCacheTokenProvided_shouldReturnYes
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor removeSharedRTForAccount:account
                                                      token:token
                                                    context:nil
                                                      error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testRemovedSharedRTForAccount_whenNoItemsInCache_andAccountWithoutUPNProvided_shouldFail
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor removeSharedRTForAccount:account
                                                      token:token
                                                    context:nil
                                                      error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertFalse(result);
}

- (void)testRemovedSharedRTForAccount_whenNoItemsInCacheNilTokenProvided_shouldReturnFalseAndFillError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor removeSharedRTForAccount:account
                                                      token:nil
                                                    context:nil
                                                      error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
}

- (void)testRemovedSharedRTForAccount_whenItemsInCacheNilTokenProvided_shouldReturnFalseAndFillError
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    result = [_legacyAccessor removeSharedRTForAccount:account
                                                 token:nil
                                               context:nil
                                                 error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    
    NSArray *allRTs = [_dataSource allLegacyRefreshTokens];
    XCTAssertEqual([allRTs count], 1);
    XCTAssertEqualObjects(allRTs[0], token);
}

- (void)testRemoveSharedRTForAccount_whenItemInCache_andAccountAndTokenProvided_shouldRemoveItem
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    result = [_legacyAccessor removeSharedRTForAccount:account
                                                 token:token
                                               context:nil
                                                 error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *allRTs = [_dataSource allLegacyRefreshTokens];
    XCTAssertEqual([allRTs count], 0);
}

- (void)testRemoveSharedRTForAccount_whenItemInCache_butWithDifferentRT_shouldNotRemoveItem
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    
    // Saves refresh token with a default token value
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    // Update token value, so it's different from a saved one
    [token setValue:@"updated_refresh_token" forKey:@"refreshToken"];
    
    result = [_legacyAccessor removeSharedRTForAccount:account
                                                 token:token
                                               context:nil
                                                 error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *allRTs = [_dataSource allLegacyRefreshTokens];
    XCTAssertEqual([allRTs count], 1);
    
    [token setValue:DEFAULT_TEST_REFRESH_TOKEN forKey:@"refreshToken"];
    XCTAssertEqualObjects(allRTs[0], token);
}

@end

