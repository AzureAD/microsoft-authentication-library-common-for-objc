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
#import "MSIDTestCacheAccessor.h"
#import "MSIDSharedTokenCache.h"
#import "MSIDAADV1RequestParameters.h"
#import "MSIDAADV2RequestParameters.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestRequestParams.h"
#import "MSIDAccount.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDAdfsToken.h"

@interface MSIDSharedTokenCacheIntegrationTests : XCTestCase
{
    MSIDTestCacheAccessor *_primaryAccessor;
    MSIDTestCacheAccessor *_secondaryAccessor;
}

@end

@implementation MSIDSharedTokenCacheIntegrationTests

#pragma mark - Setup

- (void)setUp
{
    _primaryAccessor = [[MSIDTestCacheAccessor alloc] init];
    _secondaryAccessor = [[MSIDTestCacheAccessor alloc] init];
    
    [super setUp];
}

#pragma mark - Save

- (void)testSaveTokens_withMRRTTokenAndOnlyPrimaryFormat_returnsAccessAndRefreshTokens
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:nil];
    
    MSIDAADV1RequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponse];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithRequestParams:requestParams
                                                 response:tokenResponse
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that we can get back the access token
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDToken *token = [tokenCache getATForAccount:account
                                     requestParams:requestParams
                                           context:nil
                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqual(token.tokenType, MSIDTokenTypeAccessToken);
    XCTAssertEqualObjects(token.token, DEFAULT_TEST_ACCESS_TOKEN);
    
    // Check that a refresh token is returned back
    MSIDToken *refreshToken = [tokenCache getRTForAccount:account
                                            requestParams:requestParams
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqual(refreshToken.tokenType, MSIDTokenTypeRefreshToken);
    XCTAssertEqualObjects(refreshToken.token, DEFAULT_TEST_REFRESH_TOKEN);
}

- (void)testSaveTokens_withMRRTTokenAndOnlyPrimaryFormat_savesOnlyToPrimaryFormat
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:nil];
    
    MSIDAADV1RequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponse];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithRequestParams:requestParams
                                                 response:tokenResponse
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that access token is only stored to the primary cache
    NSArray *atsInPrimaryFormat = [_primaryAccessor allAccessTokens];
    XCTAssertEqual([atsInPrimaryFormat count], 1);
    
    NSArray *atsInSecondaryFormat = [_secondaryAccessor allAccessTokens];
    XCTAssertEqual([atsInSecondaryFormat count], 0);
    
    // Check that refresh tokens are stored only in the primary cache
    NSArray *rtsInPrimaryFormat = [_primaryAccessor allRefreshTokens];
    NSArray *rtsInSecondaryFormat = [_secondaryAccessor allRefreshTokens];
    XCTAssertEqual([rtsInPrimaryFormat count], 1);
    XCTAssertEqual([rtsInSecondaryFormat count], 0);
}

- (void)testSaveTokens_withADFSToken_returnsADFSToken
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAADV1RequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1SingleResourceTokenResponse];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithRequestParams:requestParams
                                                 response:tokenResponse
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that we can get back the ADFS token
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:@"" utid:nil uid:nil];
    MSIDAdfsToken *token = (MSIDAdfsToken *)[tokenCache getATForAccount:account
                                                          requestParams:requestParams
                                                                context:nil
                                                                  error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqual(token.tokenType, MSIDTokenTypeAdfsUserToken);
    XCTAssertEqualObjects(token.token, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(token.additionalToken, DEFAULT_TEST_ACCESS_TOKEN);
    
    // Check that no refresh token is returned back
    MSIDToken *refreshToken = [tokenCache getRTForAccount:account
                                            requestParams:requestParams
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(refreshToken);
}

- (void)testSaveTokens_withADFSToken_onlySavesToPrimaryCache
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAADV1RequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1SingleResourceTokenResponse];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithRequestParams:requestParams
                                                 response:tokenResponse
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that token was only saved to the primary format
    NSArray *atsInPrimaryFormat = [_primaryAccessor allAccessTokens];
    XCTAssertEqual([atsInPrimaryFormat count], 1);
    
    // Check that no tokens were stored in the secondary format
    NSArray *atsInSecondaryFormat = [_secondaryAccessor allAccessTokens];
    XCTAssertEqual([atsInSecondaryFormat count], 0);
    
    // Check that no refresh tokens were stored
    NSArray *rtsInPrimaryFormat = [_primaryAccessor allRefreshTokens];
    NSArray *rtsInSecondaryFormat = [_secondaryAccessor allRefreshTokens];
    XCTAssertEqual([rtsInPrimaryFormat count], 0);
    XCTAssertEqual([rtsInSecondaryFormat count], 0);
}

- (void)testSaveTokens_withMRRTToken_returnsAccessAndRefreshTokens
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAADV1RequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponse];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithRequestParams:requestParams
                                                 response:tokenResponse
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that we can get back the access token
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDToken *token = [tokenCache getATForAccount:account
                                     requestParams:requestParams
                                           context:nil
                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqual(token.tokenType, MSIDTokenTypeAccessToken);
    XCTAssertEqualObjects(token.token, DEFAULT_TEST_ACCESS_TOKEN);
    
    // Check that a refresh token is returned back
    MSIDToken *refreshToken = [tokenCache getRTForAccount:account
                                            requestParams:requestParams
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqual(refreshToken.tokenType, MSIDTokenTypeRefreshToken);
    XCTAssertEqualObjects(refreshToken.token, DEFAULT_TEST_REFRESH_TOKEN);
}

- (void)testSaveTokens_withMRRTToken_savesRTsToMultipleFormats
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAADV1RequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponse];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithRequestParams:requestParams
                                                 response:tokenResponse
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that access token is only stored to the primary cache
    NSArray *atsInPrimaryFormat = [_primaryAccessor allAccessTokens];
    XCTAssertEqual([atsInPrimaryFormat count], 1);
    
    NSArray *atsInSecondaryFormat = [_secondaryAccessor allAccessTokens];
    XCTAssertEqual([atsInSecondaryFormat count], 0);
    
    // Check that refresh tokens are stored in both caches
    NSArray *rtsInPrimaryFormat = [_primaryAccessor allRefreshTokens];
    NSArray *rtsInSecondaryFormat = [_secondaryAccessor allRefreshTokens];
    XCTAssertEqual([rtsInPrimaryFormat count], 1);
    XCTAssertEqual([rtsInSecondaryFormat count], 1);
    XCTAssertEqualObjects(rtsInPrimaryFormat[0], rtsInSecondaryFormat[0]);
}

#pragma mark - Retrieve

- (void)testGetATForAccount_whenNoATInPrimaryCache_returnsNil
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    // Check that no access token is returned
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDAADV1RequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    
    NSError *error = nil;
    MSIDToken *token = [tokenCache getATForAccount:account
                                     requestParams:requestParams
                                           context:nil
                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(token);
}

- (void)testGetATForAccount_whenATPresentInPrimaryCache_returnsToken
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeAccessToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_primaryAccessor addToken:token forAccount:account];
    
    // Check that AT is returned
    NSError *error = nil;
    MSIDToken *returnedToken = [tokenCache getATForAccount:account
                                             requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                   context:nil
                                                     error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetATForAccount_whenATInSecondaryCache_returnsNil
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    // Check that no access token is returned
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeAccessToken];
    
    [_secondaryAccessor addToken:token forAccount:account];
    
    NSError *error = nil;
    MSIDToken *returnedToken = [tokenCache getATForAccount:account
                                             requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                   context:nil
                                              error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}

- (void)testGetRTForAccount_whenRTPresentInPrimaryCacheOnly_returnsToken
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_primaryAccessor addToken:token forAccount:account];
    
    // Check that RT is returned
    NSError *error = nil;
    MSIDToken *returnedToken = [tokenCache getRTForAccount:account
                                             requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                   context:nil
                                                     error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetRTForAccount_whenRTPresentInSecondaryCache_returnsToken
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_secondaryAccessor addToken:token forAccount:account];
    
    // Check that RT is returned
    NSError *error = nil;
    MSIDToken *returnedToken = [tokenCache getRTForAccount:account
                                             requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                   context:nil
                                                     error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetRTForAccount_whenRTPresentInBothCachesReturnsFromPrimary_returnsToken
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_primaryAccessor addToken:token forAccount:account];
    
    MSIDToken *secondToken = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                              request:[MSIDTestRequestParams v2DefaultParams]
                                                            tokenType:MSIDTokenTypeRefreshToken];
    [secondToken setValue:@"rt-2" forKey:@"token"];
    [_secondaryAccessor addToken:secondToken forAccount:account];
    
    // Check that RT is returned
    NSError *error = nil;
    MSIDToken *returnedToken = [tokenCache getRTForAccount:account
                                             requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                   context:nil
                                                     error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
    XCTAssertEqualObjects(returnedToken.token, DEFAULT_TEST_REFRESH_TOKEN);
}

- (void)testGetRTForAccount_whenNoRTPresent_returnsNil
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    // Check that no access token is returned
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    MSIDToken *token = [tokenCache getRTForAccount:account
                                     requestParams:[MSIDTestRequestParams v1DefaultParams]
                                           context:nil
                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(token);
}

- (void)testGetFRTForAccount_whenFRTPresentInPrimaryCacheOnly_returnsToken
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAADV1TokenResponse *v1TokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:v1TokenResponse
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_primaryAccessor addToken:token forAccount:account];
    
    // Check that FRT is returned
    NSError *error = nil;
    MSIDToken *returnedToken = [tokenCache getFRTforAccount:account
                                              requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                   familyId:DEFAULT_TEST_FAMILY_ID
                                                    context:nil
                                                      error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
    XCTAssertEqualObjects(returnedToken.familyId, DEFAULT_TEST_FAMILY_ID);
}

- (void)testGetFRTForAccount_whenFRTPresentInSecondaryCache_returnsToken
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAADV2TokenResponse *v2TokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:v2TokenResponse
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_secondaryAccessor addToken:token forAccount:account];
    
    // Check that FRT is returned
    NSError *error = nil;
    MSIDToken *returnedToken = [tokenCache getFRTforAccount:account
                                              requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                   familyId:DEFAULT_TEST_FAMILY_ID
                                                    context:nil
                                                      error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
    XCTAssertEqualObjects(returnedToken.familyId, DEFAULT_TEST_FAMILY_ID);
}

- (void)testGetFRTForAccount_whenFRTPresentInBothCachesReturnsFromPrimary_returnsToken
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAADV1TokenResponse *v1TokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:v1TokenResponse
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_primaryAccessor addToken:token forAccount:account];
    
    MSIDAADV2TokenResponse *v2TokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    MSIDToken *secondToken = [[MSIDToken alloc] initWithTokenResponse:v2TokenResponse
                                                              request:[MSIDTestRequestParams v2DefaultParams]
                                                            tokenType:MSIDTokenTypeRefreshToken];
    [secondToken setValue:@"rt-2" forKey:@"token"];
    [_secondaryAccessor addToken:secondToken forAccount:account];
    
    // Check that FRT is returned
    NSError *error = nil;
    MSIDToken *returnedToken = [tokenCache getFRTforAccount:account
                                              requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                   familyId:DEFAULT_TEST_FAMILY_ID
                                                    context:nil
                                                      error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
    XCTAssertEqualObjects(returnedToken.token, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(returnedToken.familyId, DEFAULT_TEST_FAMILY_ID);
}

- (void)testGetFRTForAccount_whenNoFRTPresent_returnsNil
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    // Check that no token is returned
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    NSError *error = nil;
    MSIDToken *returnedToken = [tokenCache getFRTforAccount:account
                                              requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                   familyId:DEFAULT_TEST_FAMILY_ID
                                                    context:nil
                                                      error:&error];
    
    
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}

- (void)testGetAllClientRTs_whenRTPresentInPrimaryCache_returnsOneToken
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDToken *firstToken = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                             request:[MSIDTestRequestParams v1DefaultParams]
                                                           tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_primaryAccessor addToken:firstToken forAccount:account];
    
    // Check that 1 RT is returned
    NSError *error = nil;
    NSArray *tokens = [tokenCache getAllClientRTs:[MSIDTestRequestParams v1DefaultParams].clientId
                                          context:nil
                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([tokens count], 1);
    XCTAssertEqualObjects(tokens[0], firstToken);
}

- (void)testGetAllClientRTs_whenRTPresentInSecondaryCache_returnsOneToken
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    [_secondaryAccessor addToken:token forAccount:account];
    
    // Check that 1 RT is returned
    NSError *error = nil;
    NSArray *tokens = [tokenCache getAllClientRTs:[MSIDTestRequestParams v1DefaultParams].clientId
                                          context:nil
                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([tokens count], 1);
    XCTAssertEqualObjects(tokens[0], token);
}

- (void)testGetAllClientRTs_whenRTPresentInPrimaryAndSecondaryCache_returnsTwoTokens
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDToken *firstToken = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                             request:[MSIDTestRequestParams v1DefaultParams]
                                                           tokenType:MSIDTokenTypeRefreshToken];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    [_primaryAccessor addToken:firstToken forAccount:account];
    
    MSIDToken *secondToken = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                              request:[MSIDTestRequestParams v2DefaultParams]
                                                            tokenType:MSIDTokenTypeRefreshToken];
    
    [_secondaryAccessor addToken:secondToken forAccount:account];
    
    // Check that 2 RTs are returned
    NSError *error = nil;
    NSArray *tokens = [tokenCache getAllClientRTs:[MSIDTestRequestParams v1DefaultParams].clientId
                                          context:nil
                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([tokens count], 2);
    XCTAssertEqualObjects(tokens[0], firstToken);
    XCTAssertEqualObjects(tokens[1], secondToken);
}

- (void)testGetAllClientRTs_whenNoRTsPresent_returnsEmptyArray
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    // Check that no RT is returned
    NSError *error = nil;
    NSArray *tokens = [tokenCache getAllClientRTs:[MSIDTestRequestParams v1DefaultParams].clientId
                                          context:nil
                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([tokens count], 0);
}

- (void)testRemoveRTForAccount_whenNoRTPresent_returnsYes
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    NSError *error = nil;
    BOOL result = [tokenCache removeRTForAccount:account token:token context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    XCTAssertEqual([[_primaryAccessor allRefreshTokens] count], 0);
}

- (void)testRemoveRTForAccount_whenRTPresentInPrimaryFormat_returnsYesRemovesToken
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];

    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v1DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    [_primaryAccessor addToken:token forAccount:account];
    XCTAssertEqual([[_primaryAccessor allRefreshTokens] count], 1);
    
    NSError *error = nil;
    BOOL result = [tokenCache removeRTForAccount:account token:token context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    XCTAssertEqual([[_primaryAccessor allRefreshTokens] count], 0);
    XCTAssertEqual([[_secondaryAccessor allRefreshTokens] count], 0);
}

- (void)testRemoveRTForAccount_whenRTPresentInSecondaryFormat_returnsYesKeepsToken
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                       utid:DEFAULT_TEST_UTID
                                                        uid:DEFAULT_TEST_UID];
    
    MSIDToken *token = [[MSIDToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v2DefaultTokenResponse]
                                                        request:[MSIDTestRequestParams v2DefaultParams]
                                                      tokenType:MSIDTokenTypeRefreshToken];
    
    [_secondaryAccessor addToken:token forAccount:account];
    XCTAssertEqual([[_secondaryAccessor allRefreshTokens] count], 1);
    
    NSError *error = nil;
    BOOL result = [tokenCache removeRTForAccount:account token:token context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    XCTAssertEqual([[_primaryAccessor allRefreshTokens] count], 0);
    XCTAssertEqual([[_secondaryAccessor allRefreshTokens] count], 1);
}

- (void)testSaveBrokerResponse_withMRRTToken_savesToMultipleFormats
{
    // TODO
}

@end
