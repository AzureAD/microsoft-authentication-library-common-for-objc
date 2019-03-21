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

#import "MSIDAccountCacheItem.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDCacheKey.h"
#import "MSIDClientInfo.h"
#import "MSIDDefaultAccountCacheKey.h"
#import "MSIDMacKeychainTokenCache.h"
#import "MSIDTestIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "NSString+MSIDExtensions.h"
#import <XCTest/XCTest.h>

@interface MSIDMacKeychainTokenCacheTests : XCTestCase
{
    MSIDMacKeychainTokenCache *_cache;
    MSIDCacheItemJsonSerializer *_serializer;
    MSIDAccountCacheItem *_testAccount;
    MSIDDefaultAccountCacheKey *_testAccountKey;
}
@end

@implementation MSIDMacKeychainTokenCacheTests

- (void)setUp
{
    _cache = [MSIDMacKeychainTokenCache new];
    _serializer = [MSIDCacheItemJsonSerializer new];

    _testAccount = [MSIDAccountCacheItem new];
    _testAccount.environment = DEFAULT_TEST_ENVIRONMENT;
    _testAccount.realm = @"Contoso.COM";
    _testAccount.additionalAccountFields = @{@"test": @"test2", @"test3": @"test4"};
    _testAccount.localAccountId = @"0000004-0000004-000004";
    _testAccount.givenName = @"First name";
    _testAccount.familyName = @"Last name";
    _testAccount.accountType = MSIDAccountTypeMSSTS;
    _testAccount.homeAccountId = @"uid.utid";
    _testAccount.username = @"username";
    _testAccount.alternativeAccountId = @"alt";
    _testAccount.name = @"test user";

    _testAccountKey = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:_testAccount.homeAccountId
                                                                    environment:_testAccount.environment
                                                                          realm:_testAccount.realm
                                                                           type:_testAccount.accountType];
    _testAccountKey.username = _testAccount.username;

}

- (void)tearDown
{
    [_cache removeItemsWithAccountKey:_testAccountKey context:nil error:nil];
    _cache = nil;
}

- (void)testMacKeychainCache_whenAccountWritten_writesAccountToKeychain
{
    NSError *error;
    BOOL result = [_cache saveAccount:_testAccount key:_testAccountKey serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    // Verify that the account was written to the keychain by reading it back and comparing:
    MSIDAccountCacheItem *account2 = [_cache accountWithKey:_testAccountKey
                                                 serializer:_serializer
                                                    context:nil
                                                      error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(_testAccount, account2);
}

- (void)testMacKeychainCache_whenAccountOverwritten_writesMergedAccountToKeychain
{
    NSError *error;
    MSIDAccountCacheItem* accountA = [MSIDAccountCacheItem new];
    MSIDAccountCacheItem* accountB = [MSIDAccountCacheItem new];

    accountA.environment = DEFAULT_TEST_ENVIRONMENT;
    accountA.realm = @"Contoso.COM";
    accountA.homeAccountId = @"uid.utid";
    accountA.localAccountId = @"homeAccountIdA";
    accountA.accountType = MSIDAccountTypeAADV1;
    accountA.username = @"UsernameA";
    accountA.givenName = @"GivenNameA";
    accountA.familyName = @"FamilyNameA";
    accountA.middleName = @"MiddleNameA";
    accountA.name = @"NameA";
    accountA.alternativeAccountId = @"AltIdA";
    accountA.additionalAccountFields = @{@"key1": @"value1", @"key2": @"value2"};

    accountB.environment = accountA.environment;
    accountB.realm = accountA.realm;
    accountB.homeAccountId = accountA.homeAccountId;
    accountB.localAccountId = @"homeAccountIdB";
    accountB.accountType = MSIDAccountTypeMSSTS;
    accountB.username = @"UsernameB";
    accountB.givenName = @"GivenNameB";
    accountB.familyName = @"FamilyNameB";
    accountB.middleName = @"MiddleNameB";
    accountB.name = @"NameB";
    accountB.alternativeAccountId = @"AltIdB";
    accountB.additionalAccountFields = @{@"key1": @"VALUE1", @"key3": @"VALUE3"};
    [accountB updateFieldsFromAccount:accountA]; // merge the additionalAccountFields dictionaries

    MSIDDefaultAccountCacheKey *keyA = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:accountA.homeAccountId
                                                                                     environment:accountA.environment
                                                                                           realm:accountA.realm
                                                                                            type:accountA.accountType];
    MSIDDefaultAccountCacheKey *keyB = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:accountB.homeAccountId
                                                                                     environment:accountB.environment
                                                                                           realm:accountB.realm
                                                                                            type:accountB.accountType];
    keyA.username = accountA.username;
    keyB.username = accountB.username;

    BOOL result = [_cache saveAccount:accountA key:keyA serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    result = [_cache saveAccount:accountB key:keyB serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    MSIDAccountCacheItem* expectedAccount = accountB;
    [expectedAccount setAdditionalAccountFields:@{@"key1": @"VALUE1", @"key2": @"value2", @"key3": @"VALUE3"}];

    MSIDAccountCacheItem *actualAccount = [_cache accountWithKey:keyB
                                                      serializer:_serializer
                                                         context:nil
                                                           error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(actualAccount);
    XCTAssertTrue([expectedAccount isEqual:actualAccount]);

    result = [_cache removeItemsWithAccountKey:keyB context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    // removing with keyB should delete the same keychain item referred to by keyA since they
    // have the same primary key values
    MSIDAccountCacheItem *deletedAccountA = [_cache accountWithKey:keyA
                                                        serializer:_serializer
                                                           context:nil
                                                             error:&error];
    XCTAssertNil(deletedAccountA);
}

- (void)testRemoveItemsWithAccountKey_whenKeyIsValid_shouldRemoveItem
{
    NSError *error;
    BOOL result = [_cache saveAccount:_testAccount key:_testAccountKey serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    MSIDAccountCacheItem *account2 = [_cache accountWithKey:_testAccountKey
                                                 serializer:_serializer
                                                    context:nil
                                                      error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(_testAccount, account2);

    result = [_cache removeItemsWithAccountKey:_testAccountKey context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    account2 = [_cache accountWithKey:_testAccountKey serializer:_serializer context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNil(account2);
}

- (void)testAccountsWithKey_whenAccountMissing_shouldNotReturnError
{
    NSError *error;
    NSString* accountId = @"AnotherTestAccountId";
    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:accountId
                                                                                    environment:_testAccount.environment
                                                                                          realm:_testAccount.realm
                                                                                           type:_testAccount.accountType];
    _testAccountKey.username = _testAccount.username;

    // make sure it's not there
    BOOL result = [_cache removeItemsWithAccountKey:key context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    // verify we can't retrieve it
    MSIDAccountCacheItem *account2 = [_cache accountWithKey:key serializer:_serializer context:nil error:&error];
    XCTAssertNil(error); // "not found" isn't an error
    XCTAssertNil(account2);
}

- (void)testAccountsWithKey_whenMultipleAccountsPresent_shouldReturnExpectedAccounts
{
    NSError *error;
    BOOL result;
    MSIDAccountCacheItem* accountA = [MSIDAccountCacheItem new];
    MSIDAccountCacheItem* accountB = [MSIDAccountCacheItem new];
    MSIDAccountCacheItem* accountC = [MSIDAccountCacheItem new];

    accountA.environment = DEFAULT_TEST_ENVIRONMENT;
    accountA.realm = @"realmA";
    accountA.homeAccountId = @"uidA.utidA";
    accountA.localAccountId = @"localAccountIdA";
    accountA.accountType = MSIDAccountTypeMSSTS;
    accountA.username = @"UsernameA";
    accountA.givenName = @"GivenNameA";
    accountA.familyName = @"FamilyNameA";
    accountA.middleName = @"MiddleNameA";
    accountA.name = @"NameA";
    accountA.alternativeAccountId = @"AltIdA";

    accountB.environment = accountA.environment;
    accountB.realm = accountA.realm;
    accountB.homeAccountId = @"uidB.utidB";
    accountB.localAccountId = @"localAccountIdB";
    accountB.accountType = accountA.accountType;
    accountB.username = @"UsernameB";
    accountB.givenName = @"GivenNameB";
    accountB.familyName = @"FamilyNameB";
    accountB.middleName = @"MiddleNameB";
    accountB.name = @"NameB";
    accountB.alternativeAccountId = @"AltIdB";

    accountC.environment = accountA.environment;
    accountC.realm = accountA.realm;
    accountC.homeAccountId = @"uidC.utidC";
    accountC.localAccountId = @"localAccountIdC";
    accountC.accountType = accountA.accountType;
    accountC.username = @"UsernameC";
    accountC.givenName = @"GivenNameC";
    accountC.familyName = @"FamilyNameC";
    accountC.middleName = @"MiddleNameC";
    accountC.name = @"NameC";
    accountC.alternativeAccountId = @"AltIdC";

    MSIDDefaultAccountCacheKey *keyA = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:accountA.homeAccountId
                                                                                     environment:accountA.environment
                                                                                           realm:accountA.realm
                                                                                            type:accountA.accountType];
    MSIDDefaultAccountCacheKey *keyB = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:accountB.homeAccountId
                                                                                     environment:accountB.environment
                                                                                           realm:accountB.realm
                                                                                            type:accountB.accountType];
    MSIDDefaultAccountCacheKey *keyC = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:accountC.homeAccountId
                                                                                     environment:accountC.environment
                                                                                           realm:accountC.realm
                                                                                            type:accountC.accountType];
    keyA.username = accountA.username;
    keyB.username = accountB.username;
    keyC.username = accountC.username;

    // Ensure these test accounts don't already exist:
    result = [_cache removeItemsWithAccountKey:keyA context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_cache removeItemsWithAccountKey:keyB context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_cache removeItemsWithAccountKey:keyC context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    MSIDDefaultAccountCacheKey *keyMultiple = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:@""
                                                                                            environment:@""
                                                                                                  realm:accountA.realm
                                                                                                   type:0];
    // Ensure accounts don't already match the search key:
    NSArray<MSIDAccountCacheItem *> *accountList = [_cache accountsWithKey:keyMultiple serializer:_serializer context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(accountList.count == 0);
    accountList = nil;

    // Write multiple accounts:
    result = [_cache saveAccount:accountA key:keyA serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_cache saveAccount:accountB key:keyB serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_cache saveAccount:accountC key:keyC serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    // Verify reading multiple accounts returns the expected accounts:
    accountList = [_cache accountsWithKey:keyMultiple serializer:_serializer context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(accountList.count == 3);
    for (MSIDAccountCacheItem *account in accountList)
    {
        if ([account.homeAccountId isEqualToString:accountA.homeAccountId])
        {
            XCTAssertTrue([account isEqual:accountA]);
        }
        else if ([account.homeAccountId isEqualToString:accountB.homeAccountId])
        {
            XCTAssertTrue([account isEqual:accountB]);
        }
        else if ([account.homeAccountId isEqualToString:accountC.homeAccountId])
        {
            XCTAssertTrue([account isEqual:accountC]);
        }
        else
        {
            XCTAssertNil(@"unexpected account");
        }
    }
    accountList = nil;

    // Verify reading accounts with one key returns only the one expected account:
    MSIDAccountCacheItem *expectedAccount = accountB;
    accountList = [_cache accountsWithKey:keyB serializer:_serializer context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(accountList.count == 1);
    MSIDAccountCacheItem *actualAccount = accountList.firstObject;
    XCTAssertNotNil(actualAccount);
    XCTAssertTrue([expectedAccount isEqual:actualAccount]);

    // Post-test cleanup:
    result = [_cache removeItemsWithAccountKey:keyA context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_cache removeItemsWithAccountKey:keyB context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_cache removeItemsWithAccountKey:keyC context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    accountList = [_cache accountsWithKey:keyMultiple serializer:_serializer context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(accountList.count == 0);
}
@end
