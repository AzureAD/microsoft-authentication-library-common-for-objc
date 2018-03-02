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
#import "MSIDAdfsToken.h"
#import "MSIDUserInformation.h"
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

- (void)testSaveTokensWithRequestParams_withMultiResourceResponse_shouldSaveAccessToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                utid:DEFAULT_TEST_UTID
                                                                 uid:DEFAULT_TEST_UID];
    
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponse];
    

    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                       account:account
                                                      response:tokenResponse
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allLegacyAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
    XCTAssertEqualObjects([accessTokensInCache[0] accessToken], tokenResponse.accessToken);
}

- (void)testSaveTokensWithRequestParams_withAccessToken_andAccountWithoutUPN_shouldFail
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                       account:account
                                                      response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertFalse(result);
    
    NSArray *accessTokensInCache = [_dataSource allLegacyAccessTokens];
    XCTAssertEqual([accessTokensInCache count], 0);
}

- (void)testSaveTokensWithRequestParams_withADFSTokenAndAccount_shouldSaveToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@""
                                                                utid:nil
                                                                 uid:nil];
    
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                       account:account
                                                      response:[MSIDTestTokenResponse v1SingleResourceTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *accessTokensInCache = [_dataSource allLegacyADFSTokens];
    XCTAssertEqual([accessTokensInCache count], 1);
    
    MSIDAdfsToken *adfsToken = accessTokensInCache[0];
    XCTAssertEqual(adfsToken.tokenType, MSIDTokenTypeLegacyADFSToken);
    XCTAssertEqualObjects(adfsToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(adfsToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
}

- (void)testSaveRefreshTokenForAccount_withMRRT_shouldSaveOneEntry
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveRefreshToken:token
                                            account:account
                                            context:nil
                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *refreshTokensInCache = [_dataSource allLegacyRefreshTokens];
    XCTAssertEqual([refreshTokensInCache count], 1);
    XCTAssertEqualObjects(refreshTokensInCache[0], token);
}

- (void)testSaveRefreshTokenForAccount_withMultipleTokensAndDifferentResources_shouldSaveOneEntry
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save first token
    MSIDRefreshToken *firstToken = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                           request:[MSIDTestRequestParams v1DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveRefreshToken:firstToken
                                            account:account
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
    
    MSIDRequestParameters *secondParams = [MSIDTestRequestParams paramsWithAuthority:DEFAULT_TEST_AUTHORITY
                                                                            clientId:DEFAULT_TEST_CLIENT_ID
                                                                         redirectUri:nil
                                                                              target:@"resource2"];
    
    MSIDRefreshToken *secondToken = [[MSIDRefreshToken alloc] initWithTokenResponse:secondResponse
                                                                            request:secondParams];
    
    result = [_legacyAccessor saveRefreshToken:secondToken
                                       account:account
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
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveRefreshToken:token
                                            account:account
                                            context:nil
                                              error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertFalse(result);
    
    NSArray *refreshTokensInCache = [_dataSource allLegacyRefreshTokens];
    XCTAssertEqual([refreshTokensInCache count], 0);
}

#pragma mark - Retrieve

- (void)testTokenWithType_withAccessTokenType_whenNoItemsInCache_shouldReturnNil
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    MSIDBaseToken *token = [_legacyAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                     account:account
                                               requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                     context:nil
                                                       error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(token);
}

- (void)testGetAccessToken_withAccountWithoutUPN_shouldReturnError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    MSIDBaseToken *token = [_legacyAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                     account:account
                                               requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                     context:nil
                                                       error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertNil(token);
}

- (void)testGetAccessTokenAfterSaving_withCorrectAccountAndParameters_shouldReturnToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save token
    NSError *error = nil;
    
    [_legacyAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                         account:account
                                        response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                         context:nil
                                           error:&error];
    
    MSIDAccessToken *token = (MSIDAccessToken *)[_legacyAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                                          account:account
                                                                    requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                          context:nil
                                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    
    XCTAssertEqual(token.tokenType, MSIDTokenTypeAccessToken);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
}

- (void)testGetAccessToken_withMultipleTokensInCacheWithDifferentResources_andCorrectAccountAndParameters_shouldReturnCorrectToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save first token
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                       account:account
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
                                                                            tenantId:DEFAULT_TEST_UTID];
    
    result = [_legacyAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                  account:account
                                                 response:secondResponse
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that correct token is returned
    MSIDAccessToken *returnedToken = (MSIDAccessToken *)[_legacyAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                                                  account:account
                                                                            requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                                  context:nil
                                                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    
    XCTAssertEqualObjects(returnedToken.resource, DEFAULT_TEST_RESOURCE);
    
    NSArray *allAccessTokens = [_dataSource allLegacyAccessTokens];
    XCTAssertEqual([allAccessTokens count], 2);
}

- (void)testGetAccessToken_withMultipleTokensInCacheWithDifferentAuthorities_andCorrectAccountAndParameters_shouldReturnCorrectToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save first token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                       account:account
                                                      response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Second token
    MSIDRequestParameters *secondParams = [MSIDTestRequestParams paramsWithAuthority:@"https://login.microsoftonline.com/contoso.com/"
                                                                            clientId:DEFAULT_TEST_CLIENT_ID
                                                                         redirectUri:nil
                                                                              target:DEFAULT_TEST_RESOURCE];
    
    result = [_legacyAccessor saveTokensWithRequestParams:secondParams
                                                  account:account
                                                 response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                  context:nil
                                                    error:&error];
    
    // Check that correct token is returned
    MSIDBaseToken *returnedToken = [_legacyAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                             account:account
                                                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                             context:nil
                                                               error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.authority, [NSURL URLWithString:DEFAULT_TEST_AUTHORITY]);
    NSArray *allAccessTokens = [_dataSource allLegacyAccessTokens];
    XCTAssertEqual([allAccessTokens count], 2);
}

- (void)testGetAccessToken_withMultipleTokensInCacheWithDifferentClientIds_andCorrectAccountAndParameters_shouldReturnCorrectToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save first token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                       account:account
                                                      response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Second token
    MSIDRequestParameters *secondParams = [MSIDTestRequestParams paramsWithAuthority:DEFAULT_TEST_AUTHORITY
                                                                            clientId:@"client_id_2"
                                                                         redirectUri:nil
                                                                              target:DEFAULT_TEST_RESOURCE];
    
    result = [_legacyAccessor saveTokensWithRequestParams:secondParams
                                                  account:account
                                                 response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that correct token is returned
    MSIDBaseToken *returnedToken = [_legacyAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                             account:account
                                                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                             context:nil
                                                               error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.clientId, DEFAULT_TEST_CLIENT_ID);
    
    NSArray *allAccessTokens = [_dataSource allLegacyAccessTokens];
    XCTAssertEqual([allAccessTokens count], 2);
}

- (void)testGetAccessToken_withMultipleTokensInCacheWithDifferentUsers_andCorrectAccountAndParameters_shouldReturnCorrectToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save first token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                       account:account
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
                                                                            tenantId:DEFAULT_TEST_UTID];
    
    // Second token
    MSIDAccount *secondAccount = [[MSIDAccount alloc] initWithTokenResponse:secondResponse request:[MSIDTestRequestParams v1DefaultParams]];
    
    result = [_legacyAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                  account:secondAccount
                                                 response:secondResponse
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that correct token is returned
    MSIDAccessToken *returnedToken = (MSIDAccessToken *)[_legacyAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                                                  account:account
                                                                            requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                                  context:nil
                                                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(returnedToken.uniqueUserId, @"1.1234-5678-90abcdefg");
    
    NSArray *allAccessTokens = [_dataSource allLegacyAccessTokens];
    XCTAssertEqual([allAccessTokens count], 2);
}

- (void)testGetADFSToken_withCorrectAccountAndParameters_shouldReturnToken
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@""
                                                       utid:nil
                                                        uid:nil];
    
    // Save ADFS token response
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                       account:account
                                                      response:[MSIDTestTokenResponse v1SingleResourceTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSIDAdfsToken *returnedToken = (MSIDAdfsToken *) [_legacyAccessor getTokenWithType:MSIDTokenTypeLegacyADFSToken
                                                                               account:account
                                                                         requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                               context:nil
                                                                                 error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    
    XCTAssertEqual(returnedToken.tokenType, MSIDTokenTypeLegacyADFSToken);
    XCTAssertEqualObjects(returnedToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(returnedToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
}

- (void)testGetSharedRTForAccount_whenNoItemsInCache_shouldReturnNil
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    MSIDBaseToken *returnedToken = [_legacyAccessor getTokenWithType:MSIDTokenTypeRefreshToken
                                                             account:account
                                                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                             context:nil
                                                               error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}

- (void)testGetSharedRTForAccountAfterSaving_whenAccountWithUPNProvided_shouldReturnToken
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveRefreshToken:token
                                            account:account
                                            context:nil
                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSIDBaseToken *returnedToken = [_legacyAccessor getTokenWithType:MSIDTokenTypeRefreshToken
                                                             account:account
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
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveRefreshToken:firstToken
                                            account:account
                                            context:nil
                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Save second token
    MSIDRequestParameters *secondParams = [MSIDTestRequestParams paramsWithAuthority:@"https://login.microsoftonline.com/contoso.com/"
                                                                            clientId:DEFAULT_TEST_CLIENT_ID
                                                                         redirectUri:nil
                                                                              target:DEFAULT_TEST_RESOURCE];
    
    MSIDRefreshToken *secondToken = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                            request:secondParams];
    
    result = [_legacyAccessor saveRefreshToken:secondToken
                                       account:account
                                       context:nil
                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that correct token is returned
    MSIDBaseToken *returnedToken = [_legacyAccessor getTokenWithType:MSIDTokenTypeRefreshToken
                                                             account:account
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
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                utid:DEFAULT_TEST_UTID
                                                                 uid:DEFAULT_TEST_UID];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveRefreshToken:token
                                            account:account
                                            context:nil
                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    account = [[MSIDAccount alloc] initWithLegacyUserId:nil
                                                   utid:DEFAULT_TEST_UTID
                                                    uid:DEFAULT_TEST_UID];
    
    // Check that correct token is returned
    MSIDBaseToken *returnedToken = [_legacyAccessor getTokenWithType:MSIDTokenTypeRefreshToken
                                                             account:account
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
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                utid:nil
                                                                 uid:nil];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveRefreshToken:token
                                            account:account
                                            context:nil
                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    account = [[MSIDAccount alloc] initWithLegacyUserId:nil
                                                   utid:DEFAULT_TEST_UTID
                                                    uid:DEFAULT_TEST_UID];
    
    // Check that correct token is returned
    MSIDBaseToken *returnedToken = [_legacyAccessor getTokenWithType:MSIDTokenTypeRefreshToken
                                                             account:account
                                                       requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                             context:nil
                                                               error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}

- (void)testGetAllSharedRTs_whenNoItemsInCache_shouldReturnEmptyResult
{
    NSError *error = nil;
    NSArray *results = [_legacyAccessor getAllTokensOfType:MSIDTokenTypeRefreshToken
                                              withClientId:DEFAULT_TEST_CLIENT_ID
                                                   context:nil
                                                     error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 0);

}

- (void)testGetAllSharedRTsAfterSaving_whenItemsInCacheAccountWithUPNProvided_shouldReturnItems
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveRefreshToken:token
                                            account:account
                                            context:nil
                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *results = [_legacyAccessor getAllTokensOfType:MSIDTokenTypeRefreshToken
                                              withClientId:DEFAULT_TEST_CLIENT_ID
                                                   context:nil
                                                     error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], token);
}

- (void)testGetAllSharedRTsAfterSaving_whenBothATandRTinCache_andAccountWithUPNProvided_shouldReturnItems
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save an access token
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveTokensWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                       account:account
                                                      response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                       context:nil
                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                             request:[MSIDTestRequestParams v1DefaultParams]];
    
    // Save token
    result = [_legacyAccessor saveRefreshToken:refreshToken
                                       account:account
                                       context:nil
                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *results = [_legacyAccessor getAllTokensOfType:MSIDTokenTypeRefreshToken
                                              withClientId:DEFAULT_TEST_CLIENT_ID
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
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                utid:nil
                                                                 uid:nil];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveRefreshToken:token
                                            account:account
                                            context:nil
                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *results = [_legacyAccessor getAllTokensOfType:MSIDTokenTypeRefreshToken
                                              withClientId:DEFAULT_TEST_CLIENT_ID
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
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor removeToken:token
                                       account:account
                                       context:nil
                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testRemovedSharedRTForAccount_whenNoItemsInCache_andAccountWithoutUPNProvided_shouldFail
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor removeToken:token
                                       account:account
                                       context:nil
                                         error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertFalse(result);
}

- (void)testRemovedSharedRTForAccount_whenNoItemsInCacheNilTokenProvided_shouldReturnFalseAndFillError
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor removeToken:nil
                                       account:account
                                       context:nil
                                         error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
}

- (void)testRemovedSharedRTForAccount_whenItemsInCacheNilTokenProvided_shouldReturnFalseAndFillError
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveRefreshToken:token
                                            account:account
                                            context:nil
                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    result = [_legacyAccessor removeToken:nil
                                  account:account
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
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveRefreshToken:token
                                            account:account
                                            context:nil
                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    result = [_legacyAccessor removeToken:token
                                  account:account
                                  context:nil
                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *allRTs = [_dataSource allLegacyRefreshTokens];
    XCTAssertEqual([allRTs count], 0);
}

@end

