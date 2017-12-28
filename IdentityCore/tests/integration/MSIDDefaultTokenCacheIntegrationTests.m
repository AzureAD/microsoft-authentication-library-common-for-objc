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
    
    // save 2nd token with intersecting scope
    
    MSIDToken *token2 = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponseWithScopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, @"profile.read", nil]]
                                                         request:[MSIDTestRequestParams v2DefaultParams]
                                                       tokenType:MSIDTokenTypeAccessToken];
    
    NSError *error = nil;
    
    BOOL result = [_cacheAccessor saveAccessToken:token2
                                          account:account
                                    requestParams:[MSIDTestRequestParams v2DefaultParams]
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



- (void)testSaveSharedRTForAccount_withFRT_shouldSaveTwoEntries
{

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
