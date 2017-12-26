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
#import "MSIDTestCacheFormat.h"
#import "MSIDSharedTokenCache.h"
#import "MSIDAADV1RequestParameters.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestRequestParams.h"
#import "MSIDAccount.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDAdfsToken.h"

@interface MSIDSharedTokenCacheIntegrationTests : XCTestCase
{
    MSIDTestCacheFormat *_primaryFormat;
    MSIDTestCacheFormat *_secondaryFormat;
}

@end

@implementation MSIDSharedTokenCacheIntegrationTests

- (void)setUp
{
    _primaryFormat = [[MSIDTestCacheFormat alloc] init];
    _secondaryFormat = [[MSIDTestCacheFormat alloc] init];
}

- (void)testSaveTokens_withOnlyPrimaryFormat_onlySavesToPrimaryFormat
{
    
}

- (void)testSaveTokens_withADFSToken_onlySavesToPrimaryFormat
{
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheFormat:_primaryFormat
                                                                              otherCacheFormats:@[_secondaryFormat]];
    
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

- (void)testSaveTokens_withMRRTToken_savesToMultipleFormats
{
    
}

- (void)testSaveBrokerResponse_withMRRTToken_savesToMultipleFormats
{
    
}

- (void)testGetATForAccount_whenNoATInPrimaryCache_returnsNil
{
    
}

- (void)testGetATForAccount_whenATPresentInPrimaryCache_returnsToken
{
    
}

- (void)testGetRTForAccount_whenRTPresentInPrimaryCache_returnsToken
{
    
}

- (void)testGetRTForAccount_whenRTPresentInSecondaryCache_returnsToken
{
    
}

- (void)testGetRTForAccount_whenRTPresentInPrimaryCacheNoSecondaryCache_returnsToken
{
    
}

- (void)testGetRTForAccount_whenNoRTPresent_returnsNil
{
    
}

- (void)testGetFRTForAccount_whenRTPresentInPrimaryCache_returnsToken
{
    
}

- (void)testGetFRTForAccount_whenRTPresentInSecondaryCache_returnsToken
{
    
}

- (void)testGetFRTForAccount_whenNoRTPresent_returnsNil
{
    
}

- (void)testGetAllClientRTs_whenRTPresentInPrimaryCache_returnsOneToken
{
    
}

- (void)testGetAllClientRTs_whenRTPresentInSecondaryCache_returnsOneToken
{
    
}

- (void)testGetAllClientRTs_whenRTPresentInPrimaryAndSecondaryCache_returnsTwoTokens
{
    
}

- (void)testGetAllClientRTs_whenNoRTsPresent_returnsEmptyArray
{
    
}

- (void)testRemoveRTForAccount_whenNoRTPresent_returnsYes
{
    
}

- (void)testRemoveRTForAccount_whenRTPresentInPrimaryFormat_returnsYesRemovesToken
{
    
}

- (void)testRemoveRTForAccount_whenRTPresentInSecondaryFormat_returnsYesKeepsToken
{
    
}

@end
