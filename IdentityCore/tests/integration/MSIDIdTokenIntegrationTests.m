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
#import "MSIDIdToken.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDTestRequestParams.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDRequestParameters.h"

@interface MSIDIdTokenIntegrationTests : XCTestCase

@end

@implementation MSIDIdTokenIntegrationTests

#pragma mark - Init

- (void)testInitWithTokenResponse_whenOIDCTokenResponse_shouldFillToken
{
    MSIDTokenResponse *response = [MSIDTestTokenResponse defaultTokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:DEFAULT_TEST_REFRESH_TOKEN
                                                                             scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                                                           username:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                            subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    
    MSIDRequestParameters *params = [MSIDTestRequestParams defaultParams];
    
    MSIDIdToken *token = [[MSIDIdToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    XCTAssertEqualObjects(token.uniqueUserId, DEFAULT_TEST_ID_TOKEN_SUBJECT);
    XCTAssertNil(token.clientInfo);
    XCTAssertEqualObjects(token.additionalInfo, [NSMutableDictionary dictionary]);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    XCTAssertEqualObjects(token.rawIdToken, idToken);
}

- (void)testInitWithTokenResponse_whenAADV1TokenResponse_v1RequestParams_shouldFillToken
{
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];
    
    MSIDIdToken *token = [[MSIDIdToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalInfo, [NSMutableDictionary dictionary]);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.rawIdToken, idToken);
}

- (void)testInitWithTokenResponse_whenAADV1TokenResponse_v2RequestParams_shouldFillToken
{
    MSIDAADV1TokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v2DefaultParams];
    
    MSIDIdToken *token = [[MSIDIdToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalInfo, [NSMutableDictionary dictionary]);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.rawIdToken, idToken);
}

- (void)testInitWithTokenResponse_whenAADV2TokenResponse_v1RequestParams_shouldFillToken
{
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v1DefaultParams];
    
    MSIDIdToken *token = [[MSIDIdToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalInfo, [NSMutableDictionary dictionary]);
    
    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];
    XCTAssertEqualObjects(token.rawIdToken, idToken);
}

- (void)testInitWithTokenResponse_whenAADV2TokenResponse_v2RequestParams_shouldFillToken
{
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDRequestParameters *params = [MSIDTestRequestParams v2DefaultParams];
    
    MSIDIdToken *token = [[MSIDIdToken alloc] initWithTokenResponse:response request:params];
    
    XCTAssertEqualObjects(token.authority, params.authority);
    XCTAssertEqualObjects(token.clientId, params.clientId);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.uniqueUserId, uniqueUserId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalInfo, [NSMutableDictionary dictionary]);
    
    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];
    XCTAssertEqualObjects(token.rawIdToken, idToken);
}

#pragma mark - Init with JSON

- (void)testInitWithJSONDictionary_shouldFillData
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    NSDictionary *jsonDict = @{@"credential_type" : @"IdToken",
                               @"unique_id" : @"user_unique_id",
                               @"environment" : @"login.microsoftonline.com",
                               @"client_id": @"test_client_id",
                               @"client_info": clientInfoString,
                               @"secret":@"id token"
                               };
    
    MSIDIdToken *token = [[MSIDIdToken alloc] initWithJSONDictionary:jsonDict error:nil];
    
    XCTAssertNotNil(token);
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    XCTAssertEqualObjects(token.authority, authority);
    XCTAssertEqualObjects(token.uniqueUserId, @"user_unique_id");
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalInfo, [NSDictionary dictionary]);
    XCTAssertEqualObjects(token.rawIdToken, @"id token");
}

#pragma mark - JSON dictionary

- (void)testSerializeToJSON_afterDeserialization_shouldReturnData
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    NSDictionary *jsonDict = @{@"credential_type" : @"IdToken",
                               @"unique_id" : @"user_unique_id",
                               @"environment" : @"login.microsoftonline.com",
                               @"client_id": @"test_client_id",
                               @"client_info": clientInfoString,
                               @"secret":@"id token"
                               };
    
    MSIDIdToken *token = [[MSIDIdToken alloc] initWithJSONDictionary:jsonDict error:nil];
    
    NSDictionary *serializedDict = [token jsonDictionary];
    XCTAssertEqualObjects(serializedDict, jsonDict);
}

@end
