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
#import "MSIDTestIdentifiers.h"
#import "MSIDAccount.h"
#import "MSIDAccountCacheItem.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDConfiguration.h"
#import "MSIDTokenResponse.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDAADAuthority.h"
#import "NSString+MSIDTestUtil.h"

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

- (void)testInitWithLegacyUserIdHomeAccountId_shouldInitAccountAndSetProperties
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy user id" homeAccountId:@"some id"];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.displayableId, @"legacy user id");
    XCTAssertEqualObjects(account.homeAccountId, @"some id");
}

- (void)testInitWithLegacyUserIdClientInfo_shouldInitAccountAndSetProperties

{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
    
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy user id" clientInfo:clientInfo];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.displayableId, @"legacy user id");
    XCTAssertEqualObjects(account.homeAccountId, @"1.1234-5678-90abcdefg");
}

- (void)testInitWithTokenResponseRequestParams_shouldInitAccountAndSetProperties
{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
    
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy user id" clientInfo:clientInfo];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.displayableId, @"legacy user id");
    XCTAssertEqualObjects(account.homeAccountId, @"1.1234-5678-90abcdefg");
}

- (void)testAccountIdentifier_whenCopied_shouldReturnSameItem
{
    MSIDAccountIdentifier *account1 = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy account id" homeAccountId:@"home account id"];
    MSIDAccountIdentifier *account2 = [account1 copy];
    XCTAssertEqualObjects(account1, account2);
}

- (void)testAccountIdentifierIsEqual_whenBothAccountsEqual_shouldReturnYES
{
    MSIDAccountIdentifier *account1 = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy account id" homeAccountId:@"home account id"];
    MSIDAccountIdentifier *account2 = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy account id" homeAccountId:@"home account id"];

    XCTAssertEqualObjects(account1, account2);
}

- (void)testAccountIdentifierIsEqual_whenHomeAccountIdNotEqual_shouldReturnNO
{
    MSIDAccountIdentifier *account1 = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy account id" homeAccountId:@"home account id 2"];
    MSIDAccountIdentifier *account2 = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy account id" homeAccountId:@"home account id"];

    XCTAssertNotEqualObjects(account1, account2);
}

- (void)testAccountIdentifierIsEqual_whenLegacyAccountIdNotEqual_shouldReturnNO
{
    MSIDAccountIdentifier *account1 = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy account id" homeAccountId:@"home account id"];
    MSIDAccountIdentifier *account2 = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy account id 2" homeAccountId:@"home account id"];

    XCTAssertNotEqualObjects(account1, account2);
}

#pragma mark - MSIDAccountCacheItem <-> MSIDAccount

- (void)testAccountCacheItem_shouldReturnProperCacheItem
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    
    MSIDAccount *account = [MSIDAccount new];
    account.environment = authority.environment;
    account.realm = authority.realm;
    account.username = @"eric999";
    account.givenName = @"Eric";
    account.familyName = @"Cartman";
    account.accountType = MSIDAccountTypeMSA;
    account.localAccountId = @"local account id";
    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy.id" homeAccountId:@"some id"];

    MSIDAccountCacheItem *cacheItem = [account accountCacheItem];
    
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.localAccountId, @"local account id");
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"some id");
    XCTAssertEqualObjects(cacheItem.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(cacheItem.username, @"eric999");
    XCTAssertEqualObjects(cacheItem.givenName, @"Eric");
    XCTAssertEqualObjects(cacheItem.familyName, @"Cartman");
    XCTAssertEqual(cacheItem.accountType, MSIDAccountTypeMSA);
}

- (void)testInitWithAccountCacheItem_shouldInitAccountAndSetProperties
{
    MSIDAccountCacheItem *cacheItem = [MSIDAccountCacheItem new];
    cacheItem.localAccountId = @"local account id";
    cacheItem.homeAccountId = @"uid.utid";
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
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithAccountCacheItem:cacheItem];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.localAccountId, @"local account id");
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqual(account.accountType, MSIDAccountTypeMSA);
    XCTAssertEqualObjects(account.username, @"eric999");
    XCTAssertEqualObjects(account.givenName, @"Eric");
    XCTAssertEqualObjects(account.familyName, @"Cartman");
    XCTAssertEqualObjects(account.middleName, @"Middle");
    XCTAssertEqualObjects(account.alternativeAccountId, @"AltID");
    XCTAssertEqualObjects(account.name, @"Eric Middle Cartman");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.realm, @"contoso.com");
    XCTAssertEqualObjects(account.clientInfo, clientInfo);
}

- (void)testSetStorageAuthority_shouldUseStorageAuthorityInCacheItem
{
    MSIDAccount *account = [MSIDAccount new];
    account.environment = @"login.microsoftonline.com";
    account.storageEnvironment = @"login.windows.net";
    account.realm = @"contoso.com";

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
    account.accountType = MSIDAccountTypeMSSTS;
    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy id" homeAccountId:@"uid.utid"];
    account.localAccountId = @"local";
    account.environment = @"login.microsoftonline.com";
    account.realm = @"common";
    account.storageEnvironment = @"login.windows2.net";
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

