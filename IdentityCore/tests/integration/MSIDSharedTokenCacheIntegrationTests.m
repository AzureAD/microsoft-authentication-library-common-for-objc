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
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestRequestParams.h"
#import "MSIDAccount.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDAccessToken.h"
#import "MSIDTestBrokerResponse.h"
#import "MSIDTestBrokerResponse.h"
#import "MSIDAADV1Oauth2Factory.h"
#import "MSIDAADV2Oauth2Factory.h"

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
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:nil];
    
    MSIDRequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponse];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithFactory:factory
                                       requestParams:requestParams
                                            response:tokenResponse
                                             context:nil
                                               error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that we can get back the access token
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    MSIDAccessToken *token = [tokenCache getATForAccount:account
                                           requestParams:requestParams
                                                 context:nil
                                                   error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqual(token.tokenType, MSIDTokenTypeAccessToken);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    
    // Check that a refresh token is returned back
    MSIDRefreshToken *refreshToken = [tokenCache getRTForAccount:account
                                                   requestParams:requestParams
                                                         context:nil
                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqual(refreshToken.tokenType, MSIDTokenTypeRefreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
}

- (void)testSaveTokens_withMRRTTokenAndOnlyPrimaryFormat_savesOnlyToPrimaryFormat
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:nil];
    
    MSIDRequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponse];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithFactory:factory
                                       requestParams:requestParams
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

- (void)testSaveTokens_withMRRTToken_returnsAccessAndRefreshTokens
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDRequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponse];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithFactory:factory
                                       requestParams:requestParams
                                            response:tokenResponse
                                             context:nil
                                               error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // Check that we can get back the access token
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    MSIDAccessToken *token = [tokenCache getATForAccount:account
                                     requestParams:requestParams
                                           context:nil
                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqual(token.tokenType, MSIDTokenTypeAccessToken);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    
    // Check that a refresh token is returned back
    MSIDRefreshToken *refreshToken = [tokenCache getRTForAccount:account
                                                   requestParams:requestParams
                                                         context:nil
                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(refreshToken);
    XCTAssertEqual(refreshToken.tokenType, MSIDTokenTypeRefreshToken);
    XCTAssertEqualObjects(refreshToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
}

- (void)testSaveTokens_withMRRTToken_savesRTsToMultipleFormats
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDRequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponse];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithFactory:factory
                                       requestParams:requestParams
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

- (void)testSaveTokens_withNoLegacyIdForPrimaryFormat_shouldReturnError
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    _primaryAccessor.requireLegacyUserId = YES;
    
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDRequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                      rt:DEFAULT_TEST_REFRESH_TOKEN
                                                                                resource:DEFAULT_TEST_RESOURCE
                                                                                     uid:DEFAULT_TEST_UID
                                                                                    utid:DEFAULT_TEST_UTID
                                                                                 idToken:nil];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithFactory:factory
                                       requestParams:requestParams
                                            response:tokenResponse
                                             context:nil
                                               error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testSaveTokens_withNoLegacyIdForSecondaryFormat_shouldSaveTokensInPrimaryCacheOnly
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    _secondaryAccessor.requireLegacyUserId = YES;
    
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDRequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                      rt:DEFAULT_TEST_REFRESH_TOKEN
                                                                                resource:DEFAULT_TEST_RESOURCE
                                                                                     uid:DEFAULT_TEST_UID
                                                                                    utid:DEFAULT_TEST_UTID
                                                                                 idToken:nil];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithFactory:factory
                                       requestParams:requestParams
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
    XCTAssertEqual([rtsInSecondaryFormat count], 0);
}

- (void)testSaveTokens_withFRTToken_savesFRTsToMultipleFormats
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDRequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithFactory:factory
                                       requestParams:requestParams
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
    XCTAssertEqual([rtsInPrimaryFormat count], 2);
    XCTAssertEqual([rtsInSecondaryFormat count], 2);
    
    // Check MRRTs entries were added
    NSArray *mrrtsInPrimaryFormat = [_primaryAccessor allMRRTTokensWithClientId:DEFAULT_TEST_CLIENT_ID];
    NSArray *mrrtsInSecondaryFormat = [_secondaryAccessor allMRRTTokensWithClientId:DEFAULT_TEST_CLIENT_ID];
    XCTAssertEqual([mrrtsInPrimaryFormat count], 1);
    XCTAssertEqual([mrrtsInSecondaryFormat count], 1);
    XCTAssertEqualObjects(mrrtsInPrimaryFormat[0], mrrtsInSecondaryFormat[0]);
    XCTAssertEqualObjects([mrrtsInPrimaryFormat[0] clientId], DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects([mrrtsInPrimaryFormat[0] familyId], DEFAULT_TEST_FAMILY_ID);
    
    // Check FRT entries were added
    NSArray *frtsInPrimaryFormat = [_primaryAccessor allFRTTokensWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    NSArray *frtsInSecondaryFormat = [_secondaryAccessor allFRTTokensWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    XCTAssertEqual([frtsInPrimaryFormat count], 1);
    XCTAssertEqual([frtsInSecondaryFormat count], 1);
    XCTAssertEqualObjects(frtsInPrimaryFormat[0], frtsInSecondaryFormat[0]);
    
    NSString *fociClientId = [NSString stringWithFormat:@"foci-%@", DEFAULT_TEST_FAMILY_ID];
    XCTAssertEqualObjects([frtsInPrimaryFormat[0] clientId], fociClientId);
    XCTAssertEqualObjects([frtsInPrimaryFormat[0] familyId], DEFAULT_TEST_FAMILY_ID);
}

#pragma mark - Retrieve

- (void)testGetATForAccount_whenNoATInPrimaryCache_returnsNil
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    // Check that no access token is returned
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    MSIDRequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    
    NSError *error = nil;
    MSIDAccessToken *token = [tokenCache getATForAccount:account
                                           requestParams:requestParams
                                                 context:nil
                                                   error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(token);
}

- (void)testGetATForAccount_whenATPresentInPrimaryCache_returnsToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAccessToken *token = [factory accessTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    [_primaryAccessor addToken:token forAccount:account];
    
    // Check that AT is returned
    NSError *error = nil;
    MSIDAccessToken *returnedToken = [tokenCache getATForAccount:account
                                                   requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                         context:nil
                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetATForAccount_whenATInSecondaryCache_returnsNil
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    // Check that no access token is returned
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDAccessToken *token = [factory accessTokenFromResponse:[MSIDTestTokenResponse v2DefaultTokenResponse] request:[MSIDTestRequestParams v2DefaultParams]];
    
    [_secondaryAccessor addToken:token forAccount:account];
    
    NSError *error = nil;
    MSIDAccessToken *returnedToken = [tokenCache getATForAccount:account
                                                   requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                         context:nil
                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}

- (void)testGetLegacyTokenWithoutAccount_whenLegacyTokenPresentInPrimaryCache_returnsToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];

    MSIDLegacySingleResourceToken *token = [factory legacyTokenFromResponse:[MSIDTestTokenResponse v1SingleResourceTokenResponse] request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@""
                                                        uniqueUserId:nil];
    
    [_primaryAccessor addToken:token forAccount:account];
    
    // Check that AT is returned
    NSError *error = nil;
    MSIDLegacySingleResourceToken *returnedToken = [tokenCache getLegacyTokenWithRequestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                                       context:nil
                                                                                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetLegacySingleResourceTokenWithAccount_whenLegacyTokenPresentInPrimaryCache_returnsToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDLegacySingleResourceToken *token = [factory legacyTokenFromResponse:[MSIDTestTokenResponse v1SingleResourceTokenResponse] request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@"legacy ID"
                                                        uniqueUserId:nil];
    
    [_primaryAccessor addToken:token forAccount:account];
    
    // Check that AT is returned
    NSError *error = nil;
    MSIDLegacySingleResourceToken *returnedToken = [tokenCache getLegacyTokenForAccount:account
                                                                          requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                                context:nil
                                                                                  error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetRTForAccount_whenRTPresentInPrimaryCacheOnly_returnsToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    [_primaryAccessor addToken:token forAccount:account];
    
    // Check that RT is returned
    NSError *error = nil;
    MSIDRefreshToken *returnedToken = [tokenCache getRTForAccount:account
                                                    requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                          context:nil
                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetRTForAccount_whenRTPresentInSecondaryCache_returnsToken
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:[MSIDTestTokenResponse v2DefaultTokenResponse] request:[MSIDTestRequestParams v2DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    [_secondaryAccessor addToken:token forAccount:account];
    
    // Check that RT is returned
    NSError *error = nil;
    MSIDRefreshToken *returnedToken = [tokenCache getRTForAccount:account
                                                    requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                          context:nil
                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
}

- (void)testGetRTForAccount_whenRTPresentInBothCachesReturnsFromPrimary_returnsToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDRefreshToken *token = [factory refreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    [_primaryAccessor addToken:token forAccount:account];

    MSIDAADV2Oauth2Factory *v2Factory = [MSIDAADV2Oauth2Factory new];
    MSIDRefreshToken *secondToken = [v2Factory refreshTokenFromResponse:[MSIDTestTokenResponse v2DefaultTokenResponse] request:[MSIDTestRequestParams v2DefaultParams]];

    [secondToken setValue:@"rt-2" forKey:@"refreshToken"];
    [_secondaryAccessor addToken:secondToken forAccount:account];
    
    // Check that RT is returned
    NSError *error = nil;
    MSIDRefreshToken *returnedToken = [tokenCache getRTForAccount:account
                                                    requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                          context:nil
                                                            error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
    XCTAssertEqualObjects(returnedToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
}

- (void)testGetRTForAccount_whenNoRTPresent_returnsNil
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    // Check that no access token is returned
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    NSError *error = nil;
    MSIDRefreshToken *token = [tokenCache getRTForAccount:account
                                            requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                  context:nil
                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(token);
}

- (void)testGetFRTForAccount_whenFRTPresentInPrimaryCacheOnly_returnsToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAADV1TokenResponse *v1TokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:v1TokenResponse request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    [_primaryAccessor addToken:token forAccount:account];
    
    // Check that FRT is returned
    NSError *error = nil;
    MSIDRefreshToken *returnedToken = [tokenCache getFRTforAccount:account
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
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAADV2TokenResponse *v2TokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:v2TokenResponse request:[MSIDTestRequestParams v2DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    [_secondaryAccessor addToken:token forAccount:account];
    
    // Check that FRT is returned
    NSError *error = nil;
    MSIDRefreshToken *returnedToken = [tokenCache getFRTforAccount:account
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
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAADV1TokenResponse *v1TokenResponse = [MSIDTestTokenResponse v1DefaultTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:v1TokenResponse request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    [_primaryAccessor addToken:token forAccount:account];
    
    MSIDAADV2TokenResponse *v2TokenResponse = [MSIDTestTokenResponse v2DefaultTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];

    MSIDAADV2Oauth2Factory *v2Factory = [MSIDAADV2Oauth2Factory new];
    MSIDRefreshToken *secondToken = [v2Factory refreshTokenFromResponse:v2TokenResponse request:[MSIDTestRequestParams v2DefaultParams]];

    [secondToken setValue:@"rt-2" forKey:@"refreshToken"];
    [_secondaryAccessor addToken:secondToken forAccount:account];
    
    // Check that FRT is returned
    NSError *error = nil;
    MSIDRefreshToken *returnedToken = [tokenCache getFRTforAccount:account
                                                     requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                          familyId:DEFAULT_TEST_FAMILY_ID
                                                           context:nil
                                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token, returnedToken);
    XCTAssertEqualObjects(returnedToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(returnedToken.familyId, DEFAULT_TEST_FAMILY_ID);
}

- (void)testGetFRTForAccount_whenNoFRTPresent_returnsNil
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    // Check that no token is returned
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    NSError *error = nil;
    MSIDRefreshToken *returnedToken = [tokenCache getFRTforAccount:account
                                                     requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                          familyId:DEFAULT_TEST_FAMILY_ID
                                                           context:nil
                                                             error:&error];
    
    
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
}

- (void)testGetAllClientRTs_whenRTPresentInPrimaryCache_returnsOneToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];

    MSIDRefreshToken *firstToken = [factory refreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
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
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:[MSIDTestTokenResponse v2DefaultTokenResponse] request:[MSIDTestRequestParams v2DefaultParams]];
    
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
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];

    MSIDRefreshToken *firstToken = [factory refreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] request:[MSIDTestRequestParams v1DefaultParams]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    [_primaryAccessor addToken:firstToken forAccount:account];

    MSIDAADV2Oauth2Factory *v2Factory = [MSIDAADV2Oauth2Factory new];

    MSIDRefreshToken *secondToken = [v2Factory refreshTokenFromResponse:[MSIDTestTokenResponse v2DefaultTokenResponse] request:[MSIDTestRequestParams v2DefaultParams]];
    
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
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] request:[MSIDTestRequestParams v1DefaultParams]];
    
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

    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDRefreshToken *token = [factory refreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] request:[MSIDTestRequestParams v1DefaultParams]];
    
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
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDRefreshToken *token = [factory refreshTokenFromResponse:[MSIDTestTokenResponse v2DefaultTokenResponse] request:[MSIDTestRequestParams v2DefaultParams]];
    
    [_secondaryAccessor addToken:token forAccount:account];
    XCTAssertEqual([[_secondaryAccessor allRefreshTokens] count], 1);
    
    NSError *error = nil;
    BOOL result = [tokenCache removeRTForAccount:account token:token context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    XCTAssertEqual([[_primaryAccessor allRefreshTokens] count], 0);
    XCTAssertEqual([[_secondaryAccessor allRefreshTokens] count], 1);
}

static NSString * extracted() {
    return DEFAULT_TEST_UID;
}

- (void)testRemoveRTForAccount_whenItemInCache_butWithDifferentRT_shouldNotRemoveItem
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];

    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] request:[MSIDTestRequestParams v1DefaultParams]];
    
    [_primaryAccessor addToken:token forAccount:account];
    XCTAssertEqual([[_primaryAccessor allRefreshTokens] count], 1);
    
    MSIDTokenResponse *updatedResponse = [MSIDTestTokenResponse v1TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                   rt:@"updated_refresh_token"
                                                                             resource:DEFAULT_TEST_RESOURCE
                                                                                  uid:extracted()
                                                                                 utid:DEFAULT_TEST_UTID
                                                                                  upn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                             tenantId:DEFAULT_TEST_UTID];

    MSIDRefreshToken *updatedToken = [factory refreshTokenFromResponse:updatedResponse request:[MSIDTestRequestParams v1DefaultParams]];
    
    NSError *error = nil;
    BOOL result = [tokenCache removeRTForAccount:account token:updatedToken context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    XCTAssertEqual([[_primaryAccessor allRefreshTokens] count], 1);
    XCTAssertEqual([[_secondaryAccessor allRefreshTokens] count], 0);
    
    XCTAssertEqualObjects([_primaryAccessor allRefreshTokens][0], token);
}

- (void)testRemoveRTForAccount_whenNilToken_shouldReturnError
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    NSError *error = nil;
    BOOL result = [tokenCache removeRTForAccount:account token:nil context:nil error:&error];
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testRemoveRTForAccount_whenBlankRefreshToken_shouldReturnError
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"1.1234-5678-90abcdefg"];
    
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    [refreshToken setValue:@"" forKey:@"refreshToken"];
    
    NSError *error = nil;
    BOOL result = [tokenCache removeRTForAccount:account token:refreshToken context:nil error:&error];
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testSaveBrokerResponse_withMRRTToken_savesToMultipleFormats
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDBrokerResponse *brokerResponse = [MSIDTestBrokerResponse testBrokerResponse];
    
    NSError *error = nil;
    // Save tokens
    BOOL result = [tokenCache saveTokensWithFactory:factory brokerResponse:brokerResponse saveRefreshTokenOnly:NO context:nil error:&error];
    
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

- (void)testSaveTokensWithRequestParams_whenNoRefreshTokenReturnedInResponse_shouldOnlySaveAccessToken_keepOldRefreshToken
{
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];

    MSIDAccount *account = [factory accountFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] request:[MSIDTestRequestParams v1DefaultParams]];

    MSIDRefreshToken *oldRefreshToken = [factory refreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] request:[MSIDTestRequestParams v1DefaultParams]];
    
    // Add old token
    [_primaryAccessor addToken:oldRefreshToken forAccount:account];
    [_secondaryAccessor addToken:oldRefreshToken forAccount:account];
    
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:_primaryAccessor
                                                                              otherCacheAccessors:@[_secondaryAccessor]];
    
    MSIDRequestParameters *requestParams = [MSIDTestRequestParams v1DefaultParams];
    MSIDAADV1TokenResponse *tokenResponse = [MSIDTestTokenResponse v1TokenResponseWithAT:@"at"
                                                                                      rt:nil
                                                                                resource:@"rt"
                                                                                     uid:@"uid"
                                                                                    utid:@"utid"
                                                                                     upn:@"upn"
                                                                                tenantId:@"tenant"];
    
    NSError *error = nil;

    BOOL result = [tokenCache saveTokensWithFactory:factory requestParams:requestParams response:tokenResponse context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    NSArray *rtsInPrimaryFormat = [_primaryAccessor allRefreshTokens];
    XCTAssertEqual([rtsInPrimaryFormat count], 1);
    XCTAssertEqualObjects(rtsInPrimaryFormat[0], oldRefreshToken);
    
    NSArray *atsInPrimaryFormat = [_primaryAccessor allAccessTokens];
    XCTAssertEqual([atsInPrimaryFormat count], 1);
    XCTAssertEqualObjects([atsInPrimaryFormat[0] accessToken], @"at");
    
    NSArray *rtsInSecondaryFormat = [_secondaryAccessor allRefreshTokens];
    XCTAssertEqual([rtsInSecondaryFormat count], 1);
    XCTAssertEqualObjects(rtsInSecondaryFormat[0], oldRefreshToken);
}

@end
