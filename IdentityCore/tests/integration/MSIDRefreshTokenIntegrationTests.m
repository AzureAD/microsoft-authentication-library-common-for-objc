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
#import "MSIDTestTokenResponse.h"
#import "MSIDRefreshToken.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDTestRequestParams.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDRequestParameters.h"

@interface MSIDRefreshTokenIntegrationTests : XCTestCase

@end

@implementation MSIDRefreshTokenIntegrationTests

#pragma mark - Init

- (void)testInitWithTokenResponse_whenOIDCTokenResponse_shouldFillToken
{
    MSIDTokenResponse *response = [MSIDTestTokenResponse defaultTokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                           username:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                            subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    
    MSIDRequestParameters *params = [MSIDTestRequestParams defaultParams];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    XCTAssertEqualObjects(token.uniqueUserId, DEFAULT_TEST_ID_TOKEN_SUBJECT);
    XCTAssertNil(token.clientInfo);
    XCTAssertEqualObjects(token.additionaServerlInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
}

- (void)testInitWithTokenResponse_whenAADV1TokenResponse_v1RequestParams_shouldFillToken
{
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionaServerlInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
}

- (void)testInitWithTokenResponse_whenAADV1TokenResponse_v1RequestParams_withFamilyId_shouldFillToken
{
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionaServerlInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertEqualObjects(token.familyId, DEFAULT_TEST_FAMILY_ID);
}

- (void)testInitWithTokenResponse_whenSingleResourceTokenResponse_v1RequestParams_shouldReturnNil
{
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 rt:DEFAULT_TEST_REFRESH_TOKEN
                                                                           resource:nil
                                                                                uid:DEFAULT_TEST_UID
                                                                               utid:DEFAULT_TEST_UTID
                                                                                upn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                           tenantId:DEFAULT_TEST_UTID];
    
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertNil(token);
}

- (void)testInitWithTokenResponse_whenAADV1TokenResponse_v2RequestParams_shouldFillToken
{
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v2DefaultParams];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionaServerlInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
}

- (void)testInitWithTokenResponse_whenAADV2TokenResponse_v1RequestParams_shouldFillToken
{
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionaServerlInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
}

- (void)testInitWithTokenResponse_whenAADV2TokenResponse_v2RequestParams_shouldFillToken
{
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v2DefaultParams];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionaServerlInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
}

@end
