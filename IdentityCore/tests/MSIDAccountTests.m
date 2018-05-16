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

#pragma mark - Copy tests

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    MSIDAccount *account = [self createAccount];
    MSIDAccount *accountCopy = [account copy];

    XCTAssertEqualObjects(account, accountCopy);
}

#pragma mark - isEqual tests

- (void)testBaseTokenIsEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    MSIDAccount *lhs = [self createAccount];
    MSIDAccount *rhs = [self createAccount];

    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - Tests

- (void)testInitWithLegacyUserIdUniqueUserId_shouldInitAccountAndSetProperties
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@"legacy user id" uniqueUserId:@"some id"];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"legacy user id");
    XCTAssertEqualObjects(account.uniqueUserId, @"some id");
    XCTAssertNil(account.clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeOther);
    XCTAssertNil(account.username);
    XCTAssertNil(account.givenName);
    XCTAssertNil(account.familyName);
    XCTAssertNil(account.authority);
}

- (void)testInitWithLegacyUserIdClientInfo_shouldInitAccountAndSetProperties

{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@"legacy user id" clientInfo:clientInfo];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"legacy user id");
    XCTAssertEqualObjects(account.uniqueUserId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(account.clientInfo, clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeOther);
    XCTAssertNil(account.username);
    XCTAssertNil(account.givenName);
    XCTAssertNil(account.familyName);
    XCTAssertNil(account.authority);
}

- (void)testInitWithTokenResponseRequestParams_shouldInitAccountAndSetProperties

{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@"legacy user id" clientInfo:clientInfo];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"legacy user id");
    XCTAssertEqualObjects(account.uniqueUserId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(account.clientInfo, clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeOther);
    XCTAssertNil(account.username);
    XCTAssertNil(account.givenName);
    XCTAssertNil(account.familyName);
    XCTAssertNil(account.authority);
}

#pragma mark - MSIDAccountCacheItem <-> MSIDAccount

- (void)testAccountCacheItem_shouldReturnProperCacheItem
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@"legacy user id" uniqueUserId:@"some id"];
    [account setValue:[@"https://login.microsoftonline.com/common" msidUrl] forKey:@"authority"];
    [account setValue:@"eric999" forKey:@"username"];
    [account setValue:@"Eric" forKey:@"givenName"];
    [account setValue:@"Cartman" forKey:@"familyName"];
    [account setValue:@(MSIDAccountTypeMSA) forKey:@"accountType"];
    
    MSIDAccountCacheItem *cacheItem = [account accountCacheItem];
    
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.legacyUserId, @"legacy user id");
    XCTAssertEqualObjects(cacheItem.uniqueUserId, @"some id");
    XCTAssertEqualObjects(cacheItem.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(cacheItem.username, @"eric999");
    XCTAssertEqualObjects(cacheItem.givenName, @"Eric");
    XCTAssertEqualObjects(cacheItem.familyName, @"Cartman");
    XCTAssertEqual(cacheItem.accountType, MSIDAccountTypeMSA);
}

- (void)testInitWithAccountCacheItem_shouldInitAccountAndSetProperties
{
    MSIDAccountCacheItem *cacheItem = [MSIDAccountCacheItem new];
    cacheItem.legacyUserId = @"legacy user id";
    cacheItem.uniqueUserId = @"uid.utid";
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.realm = @"contoso.com";
    cacheItem.username = @"eric999";
    cacheItem.givenName = @"Eric";
    cacheItem.middleName = @"Middle";
    cacheItem.name = @"Eric Middle Cartman";
    cacheItem.familyName = @"Cartman";
    cacheItem.alternativeAccountId = @"AltID";
    cacheItem.accountType = MSIDAccountTypeMSA;
    MSIDClientInfo *clientInfo = [self createClientInfo:@{@"key" : @"value"}];
    cacheItem.clientInfo = clientInfo;
    
    MSIDAccount *account = [[MSIDAccount alloc]  initWithAccountCacheItem:cacheItem];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.legacyUserId, @"legacy user id");
    XCTAssertEqualObjects(account.uniqueUserId, @"uid.utid");
    XCTAssertEqual(account.accountType, MSIDAccountTypeMSA);
    XCTAssertEqualObjects(account.username, @"eric999");
    XCTAssertEqualObjects(account.givenName, @"Eric");
    XCTAssertEqualObjects(account.familyName, @"Cartman");
    XCTAssertEqualObjects(account.middleName, @"Middle");
    XCTAssertEqualObjects(account.alternativeAccountId, @"AltID");
    XCTAssertEqualObjects(account.name, @"Eric Middle Cartman");
    XCTAssertEqualObjects(account.authority.absoluteString, @"https://login.microsoftonline.com/contoso.com");
    XCTAssertEqualObjects(account.clientInfo, clientInfo);
}

- (void)testSetStorageAuthority_shouldUseStorageAuthorityInCacheItem
{
    MSIDAccount *account = [MSIDAccount new];
    account.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    account.storageAuthority = [NSURL URLWithString:@"https://login.windows.net/contoso.com"];

    MSIDAccountCacheItem *cacheItem = [account accountCacheItem];
    XCTAssertEqualObjects(cacheItem.environment, @"login.windows.net");
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

- (MSIDAccount *)createAccount
{
    MSIDAccount *account = [MSIDAccount new];
    account.accountType = MSIDAccountTypeAADV2;
    account.uniqueUserId = @"uid.utid";
    account.legacyUserId = @"legacy";
    account.authority = [NSURL URLWithString:@"https://login.windows.net/contoso.com"];
    account.storageAuthority = [NSURL URLWithString:@"https://login.windows2.net/contoso.com"];
    account.username = @"username";
    account.givenName = @"Eric";
    account.middleName = @"Middle";
    account.familyName = @"Last";
    account.name = @"Eric Middle Last";

    MSIDClientInfo *clientInfo = [self createClientInfo:@{@"key" : @"value"}];

    account.clientInfo = clientInfo;
    account.alternativeAccountId = @"AltID";
    return account;
}

@end
