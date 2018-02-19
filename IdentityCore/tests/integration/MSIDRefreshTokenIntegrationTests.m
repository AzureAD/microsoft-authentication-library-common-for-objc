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
#import "MSIDAADV1RequestParameters.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAADV2RequestParameters.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDTestIdTokenUtil.h"

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
    XCTAssertEqualObjects(token.additionalInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
}

- (void)testInitWithTokenResponse_whenAADV1TokenResponse_v1RequestParams_shouldFillToken
{
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDAADV1RequestParameters *params = [MSIDTestRequestParams v1DefaultParams];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
}

- (void)testInitWithTokenResponse_whenAADV1TokenResponse_v1RequestParams_withFamilyId_shouldFillToken
{
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    MSIDAADV1RequestParameters *params = [MSIDTestRequestParams v1DefaultParams];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertEqualObjects(token.familyId, DEFAULT_TEST_FAMILY_ID);
}

- (void)testInitWithTokenResponse_whenAADV1TokenResponse_v2RequestParams_shouldFillToken
{
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDAADV2RequestParameters *params = [MSIDTestRequestParams v2DefaultParams];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
}

- (void)testInitWithTokenResponse_whenAADV2TokenResponse_v1RequestParams_shouldFillToken
{
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDAADV1RequestParameters *params = [MSIDTestRequestParams v1DefaultParams];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
}

- (void)testInitWithTokenResponse_whenAADV2TokenResponse_v2RequestParams_shouldFillToken
{
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDAADV2RequestParameters *params = [MSIDTestRequestParams v2DefaultParams];
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    
    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    
    XCTAssertEqualObjects(token.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertNil(token.familyId);
}

#pragma mark - Init with JSON

- (void)testInitWithJSONDictionary_whenFamilyIdProvided_shouldFillData
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    NSDictionary *jsonDict = @{@"credential_type" : @"RefreshToken",
                               @"unique_id" : @"user_unique_id",
                               @"environment" : @"login.microsoftonline.com",
                               @"client_id": @"test_client_id",
                               @"client_info": clientInfoString,
                               @"id_token": @"id token",
                               @"secret":@"refresh token",
                               @"family_id":@"family id",
                               @"username":@"test user"
                               };
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithJSONDictionary:jsonDict error:nil];
    
    XCTAssertNotNil(token);
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    XCTAssertEqualObjects(token.authority, authority);
    XCTAssertEqualObjects(token.uniqueUserId, @"user_unique_id");
    XCTAssertEqualObjects(token.clientId, @"test_client_id");
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.idToken, @"id token");
    XCTAssertEqualObjects(token.refreshToken, @"refresh token");
    XCTAssertEqualObjects(token.username, @"test user");
    XCTAssertEqualObjects(token.familyId, @"family id");
}

- (void)testInitWithJSONDictionary_whenNoFamilyIdProvided_shouldFillData
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    NSDictionary *jsonDict = @{@"credential_type" : @"RefreshToken",
                               @"unique_id" : @"user_unique_id",
                               @"environment" : @"login.microsoftonline.com",
                               @"client_id": @"test_client_id",
                               @"client_info": clientInfoString,
                               @"id_token": @"id token",
                               @"secret":@"refresh token",
                               @"username":@"test user"
                               };
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithJSONDictionary:jsonDict error:nil];
    
    XCTAssertNotNil(token);
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    XCTAssertEqualObjects(token.authority, authority);
    XCTAssertEqualObjects(token.uniqueUserId, @"user_unique_id");
    XCTAssertEqualObjects(token.clientId, @"test_client_id");
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.idToken, @"id token");
    XCTAssertEqualObjects(token.refreshToken, @"refresh token");
    XCTAssertEqualObjects(token.username, @"test user");
    XCTAssertNil(token.familyId);
}

#pragma mark - JSON dictionary

- (void)testSerializeToJSON_afterDeserialization_shouldReturnData
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    NSDictionary *jsonDict = @{@"credential_type" : @"RefreshToken",
                               @"unique_id" : @"user_unique_id",
                               @"environment" : @"login.microsoftonline.com",
                               @"client_id": @"test_client_id",
                               @"client_info": clientInfoString,
                               @"id_token": @"id token",
                               @"secret":@"refresh token",
                               @"family_id":@"family id",
                               @"username":@"test user"
                               };
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithJSONDictionary:jsonDict error:nil];
    
    NSDictionary *serializedDict = [token jsonDictionary];
    XCTAssertEqualObjects(serializedDict, jsonDict);
}

@end
