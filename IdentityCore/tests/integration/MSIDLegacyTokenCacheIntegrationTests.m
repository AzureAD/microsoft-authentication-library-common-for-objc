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

- (void)testSaveSharedRTForAccount_withFRT_shouldSaveTwoEntriesUpdateClientId
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDTokenResponse *tokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:tokenResponse
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    NSError *error = nil;
    
    BOOL result = [_legacyAccessor saveSharedRTForAccount:account
                                             refreshToken:token
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that correct MRRT item was saved
    NSArray *mrrtsInCache = [_dataSource allLegacyRefreshTokensForClientId:DEFAULT_TEST_CLIENT_ID];
    XCTAssertEqual([mrrtsInCache count], 1);
    MSIDToken *mrrtItem = mrrtsInCache[0];
    XCTAssertEqualObjects(mrrtItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(mrrtItem.familyId, DEFAULT_TEST_FAMILY_ID);
    XCTAssertEqualObjects(mrrtItem.token, token.token);
    XCTAssertEqualObjects(mrrtItem.idToken, token.idToken);
    XCTAssertEqualObjects(mrrtItem.resource, token.resource);
    
    // Check that correct FRRT item was saved
    NSString *fociClientId = [NSString stringWithFormat:@"foci-%@", DEFAULT_TEST_FAMILY_ID];
    NSArray *frtsInCache = [_dataSource allLegacyRefreshTokensForClientId:fociClientId];
    XCTAssertEqual([frtsInCache count], 1);
    MSIDToken *frtItem = frtsInCache[0];
    XCTAssertEqualObjects(frtItem.clientId, fociClientId);
    XCTAssertEqualObjects(frtItem.familyId, DEFAULT_TEST_FAMILY_ID);
    XCTAssertEqualObjects(frtItem.token, token.token);
    XCTAssertEqualObjects(frtItem.idToken, token.idToken);
    XCTAssertEqualObjects(frtItem.resource, token.resource);
}

#pragma mark - Retrieve

- (void)testGetAccessToken_whenNoItemsInCache_shouldReturnNil
{
    
}

- (void)testGetAccessToken_withWrongParameters_shouldReturnError
{
    
}

- (void)testGetAccessToken_withCorrectAccountAndParameters_shouldReturnToken
{
    
}

- (void)testGetADFSToken_withCorrectAccountAndParameters_shouldReturnToken
{
    // TODO
}

- (void)testGetSharedRTForAccount_whenNoItemsInCache_shouldReturnNil
{
    
}

- (void)testGetSharedRTForAccount_whenAccountWithUPNProvided_shouldReturnToken
{
    
}

- (void)testGetSharedRTForAccount_whenAccountWithUidUtidProvided_shouldReturnToken
{
    
}

- (void)testGetSharedRTForAccount_whenLegacyItemsInCache_andAccountWithUidUtidProvided_shouldReturnNil
{
    
}

- (void)testGetAllSharedRTs_whenNoItemsInCache_shouldReturnEmptyResult
{
    
}

- (void)testGetAllSharedRTs_whenItemsInCacheAccountWithUPNProvided_shouldReturnItems
{
    
}

- (void)testGetAllSharedRTs_whenItemsInCacheAccountWithUidUtidProvided_shouldReturnItems
{
    
}

- (void)testGetAllSharedRTs_whenLegacyItemsInCache_andAccountWithUidUtidProvided_shouldReturnItems
{
    
}

- (void)testRemovedSharedRTForAccount_whenNoItemsInCache_shouldReturnYes
{
    
}

#pragma mark - Remove

- (void)testRemoveSharedRTForAccount_whenItemInCache_andAccountWithUPNProvided_shouldRemoveItem
{
    
}

- (void)testRemoveSharedRTForAccount_whenItemInCache_andAccountWithUidUtidProvided_shouldRemoveItem
{
    
}

- (void)testRemoveSharedRTForAccount_whenLegacyItemInCache_andAccountWithUidUtidProvided_shouldNotRemoveItems
{
    
}

@end

