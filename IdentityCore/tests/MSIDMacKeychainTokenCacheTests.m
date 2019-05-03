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

#import "MSIDBasicContext.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDCacheKey.h"
#import "MSIDClientInfo.h"
#import "MSIDDefaultAccountCacheKey.h"
#import "MSIDDefaultAccountCacheQuery.h"
#import "MSIDMacKeychainTokenCache.h"
#import "MSIDTestIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "NSString+MSIDExtensions.h"
#import <XCTest/XCTest.h>

@interface MSIDMacKeychainTokenCacheTests : XCTestCase
{
    MSIDMacKeychainTokenCache *_dataSource;
    MSIDAccountCredentialCache *_cache;
    MSIDCacheItemJsonSerializer *_serializer;
    MSIDAccountCacheItem *_testAccount;
    MSIDDefaultAccountCacheKey *_testAccountKey;

    MSIDAccountCacheItem* _accountA;
    MSIDAccountCacheItem* _accountB;
    MSIDAccountCacheItem* _accountC;
    MSIDDefaultAccountCacheKey *_keyA;
    MSIDDefaultAccountCacheKey *_keyB;
    MSIDDefaultAccountCacheKey *_keyC;
    MSIDDefaultAccountCacheQuery *_queryAll;
}
@end

@implementation MSIDMacKeychainTokenCacheTests

- (void)setUp
{
    NSError *error;
    _dataSource = [MSIDMacKeychainTokenCache new];
    _cache = [[MSIDAccountCredentialCache alloc] initWithDataSource:_dataSource];
    _serializer = [MSIDCacheItemJsonSerializer new];
    [_cache clearWithContext:nil error:nil];

    NSDictionary *accountDictionary = @{@"authority_type": @"MSSTS",
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"realm": @"contoso.com",
                                         @"local_account_id": @"0000004-0000004-000004",
                                         @"given_name": @"First name",
                                         @"family_name": @"Last name",
                                         @"test": @"test2",
                                         @"test3": @"test4",
                                         @"home_account_id": @"uid.utid",
                                         @"username": @"username",
                                         @"alternative_account_id": @"alt",
                                         @"name": @"test user"
                                         };
    _testAccount = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:accountDictionary error:&error];
    XCTAssertNil(error);
    _testAccountKey = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:_testAccount.homeAccountId
                                                                    environment:_testAccount.environment
                                                                          realm:_testAccount.realm
                                                                           type:_testAccount.accountType];
    _testAccountKey.username = _testAccount.username;

    NSDictionary *accountDictionaryA = @{@"authority_type": @"MSSTS",
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"realm": @"realmA",
                                         @"local_account_id": @"localAccountIdA",
                                         @"given_name": @"GivenNameA",
                                         @"family_name": @"FamilyNameA",
                                         @"middle_name": @"MiddleNameA",
                                         @"home_account_id": @"uidA.utidA",
                                         @"username": @"usernameA",
                                         @"alternative_account_id": @"AltIdA",
                                         @"name": @"NameA"
                                         };
    NSDictionary *accountDictionaryB = @{@"authority_type": accountDictionaryA[@"authority_type"],
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"realm": accountDictionaryA[@"realm"],
                                         @"local_account_id": @"localAccountIdB",
                                         @"given_name": @"GivenNameB",
                                         @"family_name": @"FamilyNameB",
                                         @"middle_name": @"MiddleNameB",
                                         @"home_account_id": @"uidB.utidB",
                                         @"username": @"usernameB",
                                         @"alternative_account_id": @"AltIdB",
                                         @"name": @"NameB"
                                         };
    NSDictionary *accountDictionaryC = @{@"authority_type": @"MSA",
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"realm": accountDictionaryA[@"realm"],
                                         @"local_account_id": @"localAccountIdC",
                                         @"given_name": @"GivenNameC",
                                         @"family_name": @"FamilyNameC",
                                         @"middle_name": @"MiddleNameC",
                                         @"home_account_id": @"uidA.utidC",
                                         @"username": @"usernameC",
                                         @"alternative_account_id": @"AltIdC",
                                         @"name": @"NameC"
                                         };
    _accountA = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:accountDictionaryA error:&error];
    XCTAssertNil(error);
    _accountB = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:accountDictionaryB error:&error];
    XCTAssertNil(error);
    _accountC = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:accountDictionaryC error:&error];
    XCTAssertNil(error);

    _keyA = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:_accountA.homeAccountId
                                                          environment:_accountA.environment
                                                                realm:_accountA.realm
                                                                 type:_accountA.accountType];
    _keyB = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:_accountB.homeAccountId
                                                          environment:_accountB.environment
                                                                realm:_accountB.realm
                                                                 type:_accountB.accountType];
    _keyC = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:_accountC.homeAccountId
                                                          environment:_accountC.environment
                                                                realm:_accountC.realm
                                                                 type:_accountC.accountType];
    _keyA.username = _accountA.username;
    _keyB.username = _accountB.username;
    _keyC.username = _accountC.username;

    // Ensure these test accounts don't already exist:
    BOOL result = [_dataSource removeItemsWithAccountKey:_keyA context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_dataSource removeItemsWithAccountKey:_keyB context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_dataSource removeItemsWithAccountKey:_keyC context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    _queryAll = [MSIDDefaultAccountCacheQuery new];
    _queryAll.realm = _accountA.realm;
    // Ensure accounts don't already match the queryAll search key:
    NSArray<MSIDAccountCacheItem *> *accountList = [_cache getAccountsWithQuery:_queryAll context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(accountList.count == 0);
}

// Several tests utilize multiple accounts
- (void)multiAccountTestSetup
{
    // Write multiple accounts:
    NSError *error;
    BOOL result = [_dataSource saveAccount:_accountA key:_keyA serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_dataSource saveAccount:_accountB key:_keyB serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_dataSource saveAccount:_accountC key:_keyC serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)multiAccountTestCleanup
{
    // Post-test cleanup:
    NSError *error;
    BOOL result = [_dataSource removeItemsWithAccountKey:_keyA context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_dataSource removeItemsWithAccountKey:_keyB context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_dataSource removeItemsWithAccountKey:_keyC context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    NSArray<MSIDAccountCacheItem *> *accountList = [_dataSource accountsWithKey:_queryAll serializer:_serializer context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(accountList.count == 0);
}

- (void)tearDown
{
    [_dataSource removeItemsWithAccountKey:_testAccountKey context:nil error:nil];
    [_cache clearWithContext:nil error:nil];
    _dataSource = nil;
}

- (void)testMacKeychainCache_whenAccountWritten_writesAccountToKeychain
{
    NSError *error;
    BOOL result = [_dataSource saveAccount:_testAccount key:_testAccountKey serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    // Verify that the account was written to the keychain by reading it back and comparing:
    MSIDAccountCacheItem *account2 = [_dataSource accountWithKey:_testAccountKey
                                                      serializer:_serializer
                                                         context:nil
                                                           error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(_testAccount, account2);
}

- (void)testMacKeychainCache_whenAccountOverwritten_writesMergedAccountToKeychain
{
    NSError *error;
    NSDictionary *accountDictionary1 = @{@"authority_type": @"MSSTS",
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"realm": @"realmA",
                                         @"local_account_id": @"localAccountIdA",
                                         @"given_name": @"GivenNameA",
                                         @"family_name": @"FamilyNameA",
                                         @"middle_name": @"MiddleNameA",
                                         @"home_account_id": @"uidA.utidA",
                                         @"username": @"usernameA",
                                         @"alternative_account_id": @"AltIdA",
                                         @"name": @"NameA",
                                         @"key1": @"value1",
                                         @"key2": @"value2",
                                         };
    NSDictionary *accountDictionary2 = @{@"authority_type": @"MSSTS",
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"realm": accountDictionary1[@"realm"],
                                         @"local_account_id": @"localAccountIdB",
                                         @"given_name": @"GivenNameB",
                                         @"family_name": @"FamilyNameB",
                                         @"middle_name": @"MiddleNameB",
                                         @"home_account_id": accountDictionary1[@"home_account_id"],
                                         @"username": @"usernameB",
                                         @"alternative_account_id": @"AltIdB",
                                         @"name": @"NameB",
                                         @"key1": @"VALUE1",
                                         @"key3": @"VALUE3",
                                         };
    MSIDAccountCacheItem* account1 = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:accountDictionary1 error:&error];
    XCTAssertNil(error);
    MSIDAccountCacheItem* account2 = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:accountDictionary2 error:&error];
    XCTAssertNil(error);

    MSIDDefaultAccountCacheKey *key1 = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:account1.homeAccountId
                                                                                     environment:account1.environment
                                                                                           realm:account1.realm
                                                                                            type:account1.accountType];
    MSIDDefaultAccountCacheKey *key2 = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:account2.homeAccountId
                                                                                     environment:account2.environment
                                                                                           realm:account2.realm
                                                                                            type:account2.accountType];
    key1.username = account1.username;
    key2.username = account2.username;

    BOOL result = [_cache saveAccount:account1 context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    result = [_cache saveAccount:account2 context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    // merge the dictionaries
    NSMutableDictionary *expectedDictionary = [accountDictionary1 mutableCopy];
    [expectedDictionary addEntriesFromDictionary:accountDictionary2];
    MSIDAccountCacheItem* expectedAccount = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:expectedDictionary error:&error];
    XCTAssertNil(error);

    MSIDAccountCacheItem *actualAccount = [_cache getAccount:key2
                                                     context:nil
                                                       error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(actualAccount);
    XCTAssertTrue([expectedAccount.jsonDictionary isEqual:actualAccount.jsonDictionary]);

    result = [_dataSource removeItemsWithAccountKey:key2 context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    // removing with key2 should delete the same keychain item referred to by key1 since they
    // have the same primary key values
    MSIDAccountCacheItem *deletedAccountA = [_dataSource accountWithKey:key1
                                                             serializer:_serializer
                                                                context:nil
                                                                  error:&error];
    XCTAssertNil(deletedAccountA);
}

- (void)testRemoveItemsWithAccountKey_whenKeyIsValid_shouldRemoveItem
{
    NSError *error;
    BOOL result = [_dataSource saveAccount:_testAccount key:_testAccountKey serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    MSIDAccountCacheItem *account2 = [_dataSource accountWithKey:_testAccountKey
                                                      serializer:_serializer
                                                         context:nil
                                                           error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(_testAccount, account2);

    result = [_dataSource removeItemsWithAccountKey:_testAccountKey context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    account2 = [_dataSource accountWithKey:_testAccountKey serializer:_serializer context:nil error:&error];
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
    BOOL result = [_dataSource removeItemsWithAccountKey:key context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    // verify we can't retrieve it
    MSIDAccountCacheItem *account2 = [_dataSource accountWithKey:key serializer:_serializer context:nil error:&error];
    XCTAssertNil(error); // "not found" isn't an error
    XCTAssertNil(account2);
}

- (void)testAccountsWithQuery_whenMultipleAccountsPresent_shouldReturnExpectedAccounts
{
    [self multiAccountTestSetup];

    // Verify reading multiple accounts returns the expected accounts:
    NSError *error;
    NSArray<MSIDAccountCacheItem *> *accountList;
    accountList = [_cache getAccountsWithQuery:_queryAll context:nil error:&error];
    XCTAssertNil(error);
    NSOrderedSet *foundAccounts = [[NSOrderedSet alloc] initWithArray:accountList];
    NSOrderedSet *expectedAccounts = [[NSOrderedSet alloc] initWithArray:@[ _accountA, _accountB, _accountC ]];
    XCTAssertEqualObjects(foundAccounts, expectedAccounts);

    [self multiAccountTestCleanup];
}

- (void)testAccountsWithQuery_whenRealmSpecified_shouldReturnExpectedAccounts
{
    [self multiAccountTestSetup];

    // Verify a smaller subset is retrieved with a different query
    NSError *error;
    NSArray<MSIDAccountCacheItem *> *accountList;
    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.realm = _accountA.realm;
    query.accountType = _accountA.accountType;
    accountList = [_cache getAccountsWithQuery:query context:nil error:&error];
    XCTAssertNil(error);
    NSOrderedSet *foundAccounts = [[NSOrderedSet alloc] initWithArray:accountList];
    NSOrderedSet *expectedAccounts = [[NSOrderedSet alloc] initWithArray:@[ _accountA, _accountB ]];
    XCTAssertEqualObjects(foundAccounts, expectedAccounts);

    [self multiAccountTestCleanup];
}

- (void)testAccountsWithQuery_whenHomeAccountIdSpecified_shouldReturnExpectedAccount
{
    [self multiAccountTestSetup];

    // Verify a partial account key query
    NSError *error;
    NSArray<MSIDAccountCacheItem *> *accountList;
    MSIDAccountCacheItem *expectedAccount = _accountB;
    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.homeAccountId = _accountB.homeAccountId;
    accountList = [_cache getAccountsWithQuery:query context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(accountList.count == 1);
    MSIDAccountCacheItem *actualAccount = accountList.firstObject;
    XCTAssertNotNil(actualAccount);
    XCTAssertTrue([expectedAccount isEqual:actualAccount]);

    [self multiAccountTestCleanup];
}

- (void)testAccountWithKey_whenAccountPresent_shouldReturnExpectedAccount
{
    [self multiAccountTestSetup];

    // Verify reading accounts with one key returns only the one expected account:
    NSError *error;
    MSIDAccountCacheItem *expectedAccount = _accountC;
    MSIDAccountCacheItem *actualAccount = [_dataSource accountWithKey:_keyC serializer:_serializer context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(actualAccount);
    XCTAssertTrue([expectedAccount isEqual:actualAccount]);

    [self multiAccountTestCleanup];
}
@end
