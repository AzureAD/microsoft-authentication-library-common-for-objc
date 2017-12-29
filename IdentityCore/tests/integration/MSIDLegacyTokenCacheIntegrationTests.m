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
#import "MSIDToken.h"
#import "MSIDAccount.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAADV1RequestParameters.h"
#import "MSIDAADV2RequestParameters.h"
#import "MSIDAdfsToken.h"

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
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
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
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeAccessToken];
    
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
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeAccessToken];
    
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
                                                                request:[MSIDTestRequestParams v1DefaultParams]
                                                              tokenType:MSIDTokenTypeAdfsUserToken];
    
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
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
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

- (void)testSaveSharedRTForAccount_withMRRT_andAccountWithoutUPN_shouldFail
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:nil
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
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
    MSIDToken *token = [_legacyAccessor getATForAccount:account
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
    MSIDToken *token = [_legacyAccessor getATForAccount:account
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
    MSIDToken *token = [_legacyAccessor getATForAccount:account
                                          requestParams:[MSIDTestRequestParams v2DefaultParams]
                                                context:nil
                                                  error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertNil(token);
}

- (void)testGetAccessTokenAfterSaving_withCorrectAccountAndParameters_shouldReturnToken
{
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeAccessToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveAccessToken:token
                                           account:account
                                     requestParams:[MSIDTestRequestParams v1DefaultParams]
                                           context:nil
                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSIDToken *returnedToken = [_legacyAccessor getATForAccount:account
                                                  requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                        context:nil
                                                          error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetADFSToken_withCorrectAccountAndParameters_shouldReturnToken
{
    MSIDAdfsToken *token = [[MSIDAdfsToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1SingleResourceTokenResponse]
                                                                request:[MSIDTestRequestParams v1DefaultParams]
                                                              tokenType:MSIDTokenTypeAdfsUserToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:@""
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveAccessToken:token
                                           account:account
                                     requestParams:[MSIDTestRequestParams v1DefaultParams]
                                           context:nil
                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
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
    MSIDToken *token = [_legacyAccessor getSharedRTForAccount:account
                                                requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                      context:nil
                                                        error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(token);
}

- (void)testGetSharedRTForAccountAfterSaving_whenAccountWithUPNProvided_shouldReturnToken
{
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSIDToken *returnedToken = [_legacyAccessor getSharedRTForAccount:account
                                                        requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                              context:nil
                                                                error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetSharedRTForAccountAfterSaving_whenAccountWithUidUtidProvided_shouldReturnToken
{
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    account = [[MSIDAccount alloc] initWithUpn:nil
                                          utid:DEFAULT_TEST_UTID
                                           uid:DEFAULT_TEST_UID];
    
    MSIDToken *returnedToken = [_legacyAccessor getSharedRTForAccount:account
                                                        requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                              context:nil
                                                                error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(returnedToken);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetSharedRTForAccountAfterSaving_whenLegacyItemsInCache_andAccountWithUidUtidProvided_shouldReturnNil
{
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    account = [[MSIDAccount alloc] initWithUpn:nil
                                          utid:DEFAULT_TEST_UTID
                                           uid:DEFAULT_TEST_UID];
    
    MSIDToken *returnedToken = [_legacyAccessor getSharedRTForAccount:account
                                                        requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                              context:nil
                                                                error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}

- (void)testGetAllSharedRTs_whenNoItemsInCache_shouldReturnEmptyResult
{
    NSError *error = nil;
    NSArray *results = [_legacyAccessor getAllSharedRTsWithParams:[MSIDTestRequestParams v1DefaultParams]
                                                              context:nil
                                                                error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 0);

}

- (void)testGetAllSharedRTsAfterSaving_whenItemsInCacheAccountWithUPNProvided_shouldReturnItems
{
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *results = [_legacyAccessor getAllSharedRTsWithParams:[MSIDTestRequestParams v1DefaultParams]
                                                          context:nil
                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], token);
}

- (void)testGetAllSharedRTsAfterSaving_whenBothATandRTinCache_andAccountWithUPNProvided_shouldReturnItems
{
    MSIDToken *accessToken = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                              request:[MSIDTestRequestParams v1DefaultParams]
                                                            tokenType:MSIDTokenTypeAccessToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    // Save an access token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveAccessToken:accessToken account:account
                                     requestParams:[MSIDTestRequestParams v1DefaultParams]
                                           context:nil
                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSIDToken *refreshToken = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                               request:[MSIDTestRequestParams v1DefaultParams]
                                                             tokenType:MSIDTokenTypeRefreshToken];
    
    // Save token
    result = [_legacyAccessor saveSharedRTForAccount:account
                                        refreshToken:refreshToken
                                             context:nil
                                               error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *results = [_legacyAccessor getAllSharedRTsWithParams:[MSIDTestRequestParams v1DefaultParams]
                                                          context:nil
                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

- (void)testGetAllSharedRTs_whenLegacyItemsInCache_shouldReturnItems
{
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:nil
                                                        uid:nil];
    
    // Save token
    NSError *error = nil;
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *results = [_legacyAccessor getAllSharedRTsWithParams:[MSIDTestRequestParams v1DefaultParams]
                                                          context:nil
                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], token);
}

#pragma mark - Remove

- (void)testRemovedSharedRTForAccount_whenNoItemsInCacheTokenProvided_shouldReturnYes
{
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
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
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
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
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
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
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponseWithoutClientInfo]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    result = [_legacyAccessor removeSharedRTForAccount:account
                                                 token:token
                                               context:nil
                                                 error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *allRTs = [_dataSource allLegacyRefreshTokens];
    XCTAssertEqual([allRTs count], 0);
}

@end

