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
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDAccount.h"
#import "MSIDAccountCacheItem.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDRequestParameters.h"
#import "MSIDTokenResponse.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestIdTokenUtil.h"

@interface MSIDAccountTests : XCTestCase

@end

@implementation MSIDAccountTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Tests

- (void)testInitWithLegacyUserIdUniqueUserId_shouldInitAccountAndSetProperties
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@"legacy user id" uniqueUserId:@"some id"];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"legacy user id");
    XCTAssertEqualObjects(account.userIdentifier, @"some id");
    XCTAssertNil(account.clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeOther);
    XCTAssertNil(account.username);
    XCTAssertNil(account.firstName);
    XCTAssertNil(account.lastName);
    XCTAssertNil(account.authority);
}

- (void)testInitWithLegacyUserIdClientInfo_shouldInitAccountAndSetProperties

{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@"legacy user id" clientInfo:clientInfo];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"legacy user id");
    XCTAssertEqualObjects(account.userIdentifier, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(account.clientInfo, clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeOther);
    XCTAssertNil(account.username);
    XCTAssertNil(account.firstName);
    XCTAssertNil(account.lastName);
    XCTAssertNil(account.authority);
}

- (void)testInitWithTokenResponseRequestParams_shouldInitAccountAndSetProperties

{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@"legacy user id" clientInfo:clientInfo];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"legacy user id");
    XCTAssertEqualObjects(account.userIdentifier, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(account.clientInfo, clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeOther);
    XCTAssertNil(account.username);
    XCTAssertNil(account.firstName);
    XCTAssertNil(account.lastName);
    XCTAssertNil(account.authority);
}

- (void)testInitWithTokenResponseRequest_whenTokenResponseIsMSIDAADV2TokenResponse_shouldInitAccountAndSetProperties
{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"eric999" subject:@"subject" givenName:@"Eric" familyName:@"Cartman"];
    NSDictionary *json = @{@"id_token": idToken, @"client_info": base64String};
    MSIDRequestParameters *requestParameters =
    [[MSIDRequestParameters alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY msidUrl]
                                         redirectUri:@"redirect uri"
                                            clientId:@"client id"
                                              target:@"target"];
    MSIDAADV2TokenResponse *tokenResponse = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:json error:nil];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithTokenResponse:tokenResponse request:requestParameters];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"eric999");
    XCTAssertEqualObjects(account.userIdentifier, @"1.1234-5678-90abcdefg");
    XCTAssertNil(account.clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeAADV2);
    XCTAssertEqualObjects(account.username, @"eric999");
    XCTAssertEqualObjects(account.firstName, @"Eric");
    XCTAssertEqualObjects(account.lastName, @"Cartman");
    XCTAssertEqualObjects(account.authority.absoluteString, DEFAULT_TEST_AUTHORITY);
}

- (void)testInitWithTokenResponseRequest_whenTokenResponseIsMSIDAADV1TokenResponse_shouldInitAccountAndSetProperties
{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"eric999" subject:@"subject" givenName:@"Eric" familyName:@"Cartman"];
    NSDictionary *json = @{@"id_token": idToken, @"client_info": base64String};
    MSIDRequestParameters *requestParameters =
    [[MSIDRequestParameters alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY msidUrl]
                                         redirectUri:@"redirect uri"
                                            clientId:@"client id"
                                              target:@"target"];
    MSIDAADV1TokenResponse *tokenResponse = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:json error:nil];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithTokenResponse:tokenResponse request:requestParameters];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"subject");
    XCTAssertEqualObjects(account.userIdentifier, @"1.1234-5678-90abcdefg");
    XCTAssertNil(account.clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeAADV1);
    XCTAssertEqualObjects(account.username, @"eric999");
    XCTAssertEqualObjects(account.firstName, @"Eric");
    XCTAssertEqualObjects(account.lastName, @"Cartman");
    XCTAssertEqualObjects(account.authority.absoluteString, DEFAULT_TEST_AUTHORITY);
}

- (void)testInitWithTokenResponseRequest_whenTokenResponseIsMSIDTokenResponse_shouldInitAccountAndSetProperties
{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"eric999" subject:@"subject" givenName:@"Eric" familyName:@"Cartman"];
    NSDictionary *json = @{@"id_token": idToken, @"client_info": base64String};
    MSIDRequestParameters *requestParameters =
    [[MSIDRequestParameters alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY msidUrl]
                                         redirectUri:@"redirect uri"
                                            clientId:@"client id"
                                              target:@"target"];
    MSIDTokenResponse *tokenResponse = [[MSIDTokenResponse alloc] initWithJSONDictionary:json error:nil];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithTokenResponse:tokenResponse request:requestParameters];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"subject");
    XCTAssertEqualObjects(account.userIdentifier, @"subject.");
    XCTAssertNil(account.clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeOther);
    XCTAssertEqualObjects(account.username, @"eric999");
    XCTAssertEqualObjects(account.firstName, @"Eric");
    XCTAssertEqualObjects(account.lastName, @"Cartman");
    XCTAssertEqualObjects(account.authority.absoluteString, DEFAULT_TEST_AUTHORITY);
}

#pragma mark - MSIDAccountCacheItem <-> MSIDAccount

- (void)testAccountCacheItem_shouldReturnProperCacheItem
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@"legacy user id" uniqueUserId:@"some id"];
    [account setValue:[@"https://login.microsoftonline.com/common" msidUrl] forKey:@"authority"];
    [account setValue:@"eric999" forKey:@"username"];
    [account setValue:@"Eric" forKey:@"firstName"];
    [account setValue:@"Cartman" forKey:@"lastName"];
    [account setValue:@(MSIDAccountTypeMSA) forKey:@"accountType"];
    
    MSIDAccountCacheItem *cacheItem = [account accountCacheItem];
    
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.legacyUserIdentifier, @"legacy user id");
    XCTAssertEqualObjects(cacheItem.uniqueUserId, @"some id");
    XCTAssertEqualObjects(cacheItem.authority.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(cacheItem.username, @"eric999");
    XCTAssertEqualObjects(cacheItem.firstName, @"Eric");
    XCTAssertEqualObjects(cacheItem.lastName, @"Cartman");
    XCTAssertEqual(cacheItem.accountType, MSIDAccountTypeMSA);
}

- (void)testInitWithAccountCacheItem_shouldInitAccountAndSetProperties
{
    MSIDAccountCacheItem *cacheItem = [MSIDAccountCacheItem new];
    cacheItem.legacyUserIdentifier = @"legacy user id";
    cacheItem.uniqueUserId = @"uid.utid";
    cacheItem.authority = [@"https://login.microsoftonline.com/common" msidUrl];
    cacheItem.username = @"eric999";
    cacheItem.firstName = @"Eric";
    cacheItem.lastName = @"Cartman";
    cacheItem.accountType = MSIDAccountTypeMSA;
    
    MSIDAccount *account = [[MSIDAccount alloc]  initWithAccountCacheItem:cacheItem];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"legacy user id");
    XCTAssertEqualObjects(account.userIdentifier, @"uid.utid");
    XCTAssertNil(account.clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeMSA);
    XCTAssertEqualObjects(account.username, @"eric999");
    XCTAssertEqualObjects(account.firstName, @"Eric");
    XCTAssertEqualObjects(account.lastName, @"Cartman");
    XCTAssertEqualObjects(account.authority.absoluteString, @"https://login.microsoftonline.com/common");
}

@end
