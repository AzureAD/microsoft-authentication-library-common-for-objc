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
#import "MSIDCredentialCacheItem.h"
#import "MSIDAppMetadataCacheItem.h"
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
#import "MSIDKeychainUtil.h"
#import "MSIDKeychainUtil+Internal.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAppMetadataCacheKey.h"

@interface MSIDMacKeychainTokenCache (Internal)

// Provide access to this internal method for testing:
- (BOOL)checkIfRecentlyModifiedItem:(nullable id<MSIDRequestContext>)context
                               time:(NSDate *)lastModificationTime
                                app:(NSString *)lastModificationApp;

@end

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
    MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
    keychainUtil.teamId = @"FakeTeamId";
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
    BOOL result = [_dataSource removeAccountsWithKey:_keyA context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_dataSource removeAccountsWithKey:_keyB context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_dataSource removeAccountsWithKey:_keyC context:nil error:&error];
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
    BOOL result = [_dataSource removeAccountsWithKey:_keyA context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_dataSource removeAccountsWithKey:_keyB context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    result = [_dataSource removeAccountsWithKey:_keyC context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    NSArray<MSIDAccountCacheItem *> *accountList = [_dataSource accountsWithKey:_queryAll serializer:_serializer context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(accountList.count == 0);
}

- (void)tearDown
{
    [_dataSource removeAccountsWithKey:_testAccountKey context:nil error:nil];
    [_cache clearWithContext:nil error:nil];
    _dataSource = nil;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"LoginKeychainEmpty"];
}

- (void)testInitWithGroup_whenNoLoginKeychainEmptyKeySet_shouldReturnNonNil
{
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"LoginKeychainEmpty"];
    
    NSError *error = nil;
    MSIDMacKeychainTokenCache *keychainTokenCache = [[MSIDMacKeychainTokenCache alloc] initWithGroup:nil trustedApplications:nil error:&error];
    
    XCTAssertNotNil(keychainTokenCache);
    XCTAssertNil(error);
}

- (void)testInitWithGroup_whenLoginKeychainEmptyKeySet_shouldReturnNilFillError
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"LoginKeychainEmpty"];
    
    NSError *error = nil;
    MSIDMacKeychainTokenCache *keychainTokenCache = [[MSIDMacKeychainTokenCache alloc] initWithGroup:nil trustedApplications:nil error:&error];
    
    if (@available(macOS 10.15, *)) {
        
        XCTAssertNil(keychainTokenCache);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Not creating login keychain for performance optimization on macOS 10.15, because no items where previously found in it");
    }
    else
    {
        XCTAssertNotNil(keychainTokenCache);
        XCTAssertNil(error);
    }
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
    XCTAssertEqualObjects(expectedAccount, actualAccount);

    result = [_dataSource removeAccountsWithKey:key2 context:nil error:&error];
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

- (void)testRemoveAccountsWithKey_whenKeyIsValid_shouldRemoveItem
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

    result = [_dataSource removeAccountsWithKey:_testAccountKey context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    account2 = [_dataSource accountWithKey:_testAccountKey serializer:_serializer context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNil(account2);
}

- (void)testAccountsWithKey_whenAccountMissing_shouldNotReturnError
{
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"LoginKeychainEmpty"];
    
    NSError *error;
    NSString* accountId = @"AnotherTestAccountId";
    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:accountId
                                                                                    environment:_testAccount.environment
                                                                                          realm:_testAccount.realm
                                                                                           type:_testAccount.accountType];
    _testAccountKey.username = _testAccount.username;

    // make sure it's not there
    BOOL result = [_dataSource removeAccountsWithKey:key context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    // verify we can't retrieve it
    MSIDAccountCacheItem *account2 = [_dataSource accountWithKey:key serializer:_serializer context:nil error:&error];
    XCTAssertNil(error); // "not found" isn't an error
    XCTAssertNil(account2);
    
    BOOL loginKeychainEmptyKeySet = [[NSUserDefaults standardUserDefaults] boolForKey:@"LoginKeychainEmpty"];
    
    if (@available(macOS 10.15, *)) {
        XCTAssertEqual(loginKeychainEmptyKeySet, YES);
    }
    else
    {
        XCTAssertEqual(loginKeychainEmptyKeySet, NO);
    }
}

- (void)testAccountsWithKey_whenLoginKeychainEmptyKeySet_andAccountPresent_shouldNotReturnAccounts
{
    if (@available(macOS 10.15, *)) {
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"LoginKeychainEmpty"];
        
        [self multiAccountTestSetup];
        
        NSError *error;
        NSArray<MSIDAccountCacheItem *> *foundAccounts = [_cache getAccountsWithQuery:_queryAll context:nil error:&error];
        XCTAssertNil(error);
        XCTAssertEqual([foundAccounts count], 0);
        
    }
}

- (void)testAccountsWithQuery_whenMultipleAccountsPresent_shouldReturnExpectedAccounts
{
    [self multiAccountTestSetup];

    // Verify reading multiple accounts returns the expected accounts:
    NSError *error;
    NSArray<MSIDAccountCacheItem *> *foundAccounts = [_cache getAccountsWithQuery:_queryAll context:nil error:&error];
    XCTAssertNil(error);
    NSArray<MSIDAccountCacheItem *> *expectedAccounts = [[NSArray alloc] initWithObjects:_accountA, _accountB, _accountC, nil];
    BOOL isAccountListSame = [self arraysContainSameObjects:foundAccounts andOtherArray:expectedAccounts];
    XCTAssertTrue(isAccountListSame);
    [self multiAccountTestCleanup];
}

- (void)testAccountsWithQuery_whenRealmSpecified_shouldReturnExpectedAccounts
{
    [self multiAccountTestSetup];

    // Verify a smaller subset is retrieved with a different query
    NSError *error;
    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.realm = _accountA.realm;
    query.accountType = _accountA.accountType;
    NSArray<MSIDAccountCacheItem *> *foundAccounts = [_cache getAccountsWithQuery:query context:nil error:&error];
    XCTAssertNil(error);
    NSArray<MSIDAccountCacheItem *> *expectedAccounts = [[NSArray alloc] initWithObjects:_accountA, _accountB, nil];
    BOOL isAccountListSame = [self arraysContainSameObjects:foundAccounts andOtherArray:expectedAccounts];
    XCTAssertTrue(isAccountListSame);
    
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

- (void)testMacKeychainCache_whenAccessTokenWritten_writesAccessTokenToKeychain
{
    NSError *error;
    MSIDCredentialCacheItem *token1 = [self createTestAccessTokenCacheItem];
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:token1.homeAccountId
                                                                                          environment:token1.environment
                                                                                             clientId:token1.clientId
                                                                                       credentialType:MSIDAccessTokenType];
    
    key.realm = @"contoso.com";
    key.target = @"user.read user.write";
    BOOL result = [_dataSource saveToken:token1 key:key serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Verify that the account was written to the keychain by reading it back and comparing:
    MSIDCredentialCacheItem *token2 = [_dataSource tokenWithKey:key
                                                   serializer:_serializer
                                                      context:nil
                                                        error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(token1, token2);
}

- (void)testMacKeychainCache_whenIdTokenWritten_writesIdTokenToKeychain
{
    NSError *error;
    MSIDCredentialCacheItem *token1 = [self createTestIDTokenCacheItem];
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:token1.homeAccountId
                                                                                          environment:token1.environment
                                                                                             clientId:token1.clientId
                                                                                       credentialType:MSIDIDTokenType];
    
    key.realm = @"contoso.com";
    BOOL result = [_dataSource saveToken:token1 key:key serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Verify that the idtoken was written to the keychain by reading it back and comparing:
    MSIDCredentialCacheItem *token2 = [_dataSource tokenWithKey:key
                                                     serializer:_serializer
                                                        context:nil
                                                          error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(token1, token2);
}

- (void)testMacKeychainCache_whenAppMetadataWritten_writesAppMetadataToKeychain
{
    NSError *error;
    MSIDAppMetadataCacheItem *appMetadata1 = [self createAppMetadataCacheItem:nil];
    MSIDAppMetadataCacheKey *key = [[MSIDAppMetadataCacheKey alloc] initWithClientId:appMetadata1.clientId
                                                                         environment:appMetadata1.environment
                                                                            familyId:appMetadata1.familyId
                                                                         generalType:MSIDAppMetadataType];
    
    BOOL result = [_dataSource saveAppMetadata:appMetadata1 key:key serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Verify that the appmetadata was written to the keychain by reading it back and comparing:
    NSArray<MSIDAppMetadataCacheItem *> *appMetadataItems = [_dataSource appMetadataEntriesWithKey:key serializer:_serializer context:nil error:&error];
    XCTAssertTrue([appMetadataItems count] == 1);
    XCTAssertEqualObjects(appMetadataItems[0], appMetadata1);
    XCTAssertNil(error);
}

- (void)testSaveAppMetadataWithKey_whenItemAlreadyExistInKeychain_shouldUpdateIt
{
    MSIDAppMetadataCacheItem *appMetadata1 = [MSIDAppMetadataCacheItem new];
    appMetadata1.clientId = @"clientId";
    appMetadata1.environment = @"login.microsoftonline.com";
    appMetadata1.familyId = @"1";
    MSIDAppMetadataCacheItem *appMetadata2 = [MSIDAppMetadataCacheItem new];
    appMetadata2.clientId = @"clientId";
    appMetadata2.environment = @"login.microsoftonline.com";
    appMetadata2.familyId = nil;
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    
    MSIDAppMetadataCacheKey *key = [[MSIDAppMetadataCacheKey alloc] initWithClientId:@"clientId"
                                                                         environment:@"login.microsoftonline.com"
                                                                            familyId:nil
                                                                         generalType:MSIDAppMetadataType];
    
    [_dataSource saveAppMetadata:appMetadata1 key:key serializer:serializer context:nil error:nil];
    [_dataSource saveAppMetadata:appMetadata2 key:key serializer:serializer context:nil error:nil];
    
    NSArray<MSIDAppMetadataCacheItem *> *appMetadataItems = [_dataSource appMetadataEntriesWithKey:key serializer:serializer context:nil error:nil];
    XCTAssertTrue([appMetadataItems count] == 1);
    XCTAssertEqualObjects(appMetadataItems[0], appMetadata2);
}

- (void)testRemoveTokensWithKey_whenKeysServiceAndAccountIsNil_shouldReturnFalseAndError
{
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:nil service:nil generic:nil type:nil];
    NSError *error;
    
    BOOL result = [_dataSource removeTokensWithKey:key context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)testRemoveMetadataItemsWithKey_whenKeysServiceAndAccountIsNil_shouldReturnFalseAndError
{
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:nil service:nil generic:nil type:nil];
    NSError *error;
    
    BOOL result = [_dataSource removeMetadataItemsWithKey:key context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)testTokensWithKey_whenBothSharedAndNonSharedCredentialsExist_shouldReturnCorrectSharedCredential
{
    // Item 1.
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.clientId = @"clientId";
    token1.environment = @"environment";
    token1.homeAccountId = @"uid.utid";
    token1.secret = @"secret1";
    token1.target = @"user.read user.write";
    token1.credentialType = MSIDAccessTokenType;
    MSIDDefaultCredentialCacheKey *key1 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                           environment:@"environment"
                                                                                              clientId:@"clientId"
                                                                                        credentialType:MSIDAccessTokenType];
    key1.target = @"user.read user.write";
    [_dataSource saveToken:token1 key:key1 serializer:_serializer context:nil error:nil];
    
    // Item 2.
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.clientId = @"clientId";
    token2.environment = @"environment";
    token2.homeAccountId = @"uid.utid";
    token2.secret = @"secret2";
    token2.credentialType = MSIDIDTokenType;
    
    MSIDDefaultCredentialCacheKey *key2 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                           environment:@"environment"
                                                                                              clientId:@"clientId"
                                                                                        credentialType:MSIDIDTokenType];
    
    [_dataSource saveToken:token2 key:key2 serializer:_serializer context:nil error:nil];
    
    // Item 3.
    MSIDCredentialCacheItem *token3 = [MSIDCredentialCacheItem new];
    token3.secret = @"secret3";
    token3.clientId = @"clientId";
    token3.environment = @"environment";
    token3.homeAccountId = @"uid.utid";
    token3.credentialType = MSIDRefreshTokenType;
    
    MSIDDefaultCredentialCacheKey *key3 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                           environment:@"environment"
                                                                                              clientId:@"clientId"
                                                                                        credentialType:MSIDRefreshTokenType];
    
    [_dataSource saveToken:token3 key:key3 serializer:_serializer context:nil error:nil];
    
    MSIDDefaultCredentialCacheKey *query = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                            environment:@"environment"
                                                                                               clientId:@"clientId"
                                                                                         credentialType:MSIDRefreshTokenType];
    NSError *error;
    
    NSArray<MSIDCredentialCacheItem *> *items = [_dataSource tokensWithKey:query serializer:_serializer context:nil error:&error];
    
    XCTAssertEqual(items.count, 1);
    XCTAssertTrue([items containsObject:token3]);
    XCTAssertNil(error);
}

- (void)testSaveAccount_whenAccountSaved_shouldSaveValidLastModInfo
{
    MSIDAccountCacheItem *account = [MSIDAccountCacheItem new];
    account.environment = DEFAULT_TEST_ENVIRONMENT;
    account.realm = @"Contoso.COM";
    account.homeAccountId = @"uid.utid";
    account.localAccountId = @"homeAccountIdA";
    account.accountType = MSIDAccountTypeAADV1;
    account.username = @"UsernameA";
    account.givenName = @"GivenNameA";
    account.familyName = @"FamilyNameA";
    account.middleName = @"MiddleNameA";
    account.name = @"NameA";
    account.alternativeAccountId = @"AltIdA";
    
    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:account.homeAccountId
                                                                                    environment:account.environment
                                                                                          realm:account.realm
                                                                                           type:account.accountType];
    
    NSError *error = nil;
    BOOL result = [_dataSource saveAccount:account key:key serializer:_serializer context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // read the same account we just wrote
    account = [_dataSource accountWithKey:key serializer:_serializer context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(account);
    NSString *lastModApp = [NSString stringWithFormat:@"%@;%d", NSBundle.mainBundle.bundleIdentifier,
                            NSProcessInfo.processInfo.processIdentifier];
    XCTAssertEqualObjects(account.lastModificationApp, lastModApp);
    XCTAssertTrue([account.lastModificationTime timeIntervalSinceNow] <= 0.0); // NSTimeInterval in the past is negative
    result = [_dataSource checkIfRecentlyModifiedItem:nil
                                                 time:account.lastModificationTime
                                                  app:account.lastModificationApp];
    XCTAssertFalse(result); // this check should ignore items our process has written
    
    // check behavior if item had been written by a different process:
    account.lastModificationApp = [NSString stringWithFormat:@"%@;%d", NSBundle.mainBundle.bundleIdentifier,
                                   (NSProcessInfo.processInfo.processIdentifier + 1)];
    result = [_dataSource checkIfRecentlyModifiedItem:nil
                                                 time:account.lastModificationTime
                                                  app:account.lastModificationApp];
    XCTAssertTrue(result); // a different process id, so it should be considered as recent
    
    [NSThread sleepForTimeInterval:1.0];
    result = [_dataSource checkIfRecentlyModifiedItem:nil
                                                 time:account.lastModificationTime
                                                  app:account.lastModificationApp];
    XCTAssertFalse(result); // no longer "recent" due to the above delay
}

- (void)testSaveToken_whenTokenSaved_shouldSaveValidLastModInfo
{
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.secret = @"secret";
    token.clientId = @"clientId";
    token.environment = @"login.microsoftonline.com";
    token.homeAccountId = @"uid.utid";
    token.credentialType = MSIDRefreshTokenType;
    
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                          environment:@"login.microsoftonline.com"
                                                                                             clientId:@"clientId"
                                                                                       credentialType:MSIDRefreshTokenType];
    
    NSError *error = nil;
    BOOL result = [_dataSource saveToken:token key:key serializer:_serializer context:nil error:nil];
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    // read the same token we just wrote
    token = [_dataSource tokenWithKey:key serializer:_serializer context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(token);
    NSString *lastModApp = [NSString stringWithFormat:@"%@;%d", NSBundle.mainBundle.bundleIdentifier,
                            NSProcessInfo.processInfo.processIdentifier];
    XCTAssertEqualObjects(token.lastModificationApp, lastModApp);
    XCTAssertTrue([token.lastModificationTime timeIntervalSinceNow] <= 0.0); // NSTimeInterval in the past is negative

    result = [_dataSource checkIfRecentlyModifiedItem:nil
                                                 time:token.lastModificationTime
                                                  app:token.lastModificationApp];
    XCTAssertFalse(result); // this check should ignore items our process has written
    
    // check behavior if item had been written by a different process:
    token.lastModificationApp = [NSString stringWithFormat:@"%@;%d", NSBundle.mainBundle.bundleIdentifier,
                                 (NSProcessInfo.processInfo.processIdentifier + 1)];
    result = [_dataSource checkIfRecentlyModifiedItem:nil
                                                 time:token.lastModificationTime
                                                  app:token.lastModificationApp];
    XCTAssertTrue(result); // a different process id, so it should be considered as recent
    
    [NSThread sleepForTimeInterval:1.0];
    result = [_dataSource checkIfRecentlyModifiedItem:nil
                                                 time:token.lastModificationTime
                                                  app:token.lastModificationApp];
    XCTAssertFalse(result); // no longer "recent" due to the above delay
}

- (void)testTokensWithKey_whenQueryMatchesAnyCredentialType_shouldReturnAllTokens
{
    // Item 1.
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    MSIDDefaultCredentialCacheKey *key1 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                           environment:@"login.microsoftonline.com"
                                                                                              clientId:@"client"
                                                                                        credentialType:MSIDAccessTokenType];
    key1.target = @"user.read user.write";
    key1.realm = @"contoso.com";
    [_dataSource saveToken:accessToken key:key1 serializer:_serializer context:nil error:nil];
    
    // Item 2.
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];
    MSIDDefaultCredentialCacheKey *key2 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                           environment:@"login.microsoftonline.com"
                                                                                              clientId:@"client"
                                                                                        credentialType:MSIDIDTokenType];
    key2.realm = @"contoso.com";
    
    [_dataSource saveToken:idToken key:key2 serializer:_serializer context:nil error:nil];
    
    // Item 3.
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshToken:nil];
    MSIDDefaultCredentialCacheKey *key3 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                           environment:@"login.microsoftonline.com"
                                                                                              clientId:@"client"
                                                                                        credentialType:MSIDRefreshTokenType];
    
    [_dataSource saveToken:refreshToken key:key3 serializer:_serializer context:nil error:nil];
    
    //Item 4
    MSIDAppMetadataCacheItem *appMetadata1 = [self createAppMetadataCacheItem:nil];
    MSIDAppMetadataCacheKey *key4 = [[MSIDAppMetadataCacheKey alloc] initWithClientId:appMetadata1.clientId
                                                                         environment:appMetadata1.environment
                                                                            familyId:appMetadata1.familyId
                                                                         generalType:MSIDAppMetadataType];
    
    [_dataSource saveAppMetadata:appMetadata1 key:key4 serializer:_serializer context:nil error:nil];
    
    //Item 5
    MSIDDefaultAccountCacheKey *key5 = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:@"uid.utid" environment:@"login.microsoftonline.com" realm:@"realm" type:MSIDAccountTypeMSSTS];
    
    MSIDAccountCacheItem *account = [MSIDAccountCacheItem new];
    account.homeAccountId = @"uid.utid";
    account.environment = @"login.microsoftonline.com";
    account.accountType = MSIDAccountTypeMSSTS;
    [_dataSource saveAccount:account key:key5 serializer:_serializer context:nil error:nil];
    
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.matchAnyCredentialType = YES;
    NSError *error = nil;
    NSArray<MSIDCredentialCacheItem *> *items = [_dataSource tokensWithKey:query serializer:_serializer context:nil error:&error];
    
    XCTAssertEqual(items.count, 3);
    XCTAssertTrue([items containsObject:accessToken]);
    XCTAssertTrue([items containsObject:idToken]);
    XCTAssertTrue([items containsObject:refreshToken]);
    XCTAssertNil(error);
}

- (void)testRemoveCredentialsWithQuery_whenQueryMatchesAnyCredentialType_shouldDeleteAllTokensWhichMatchesQuery
{
    // Item 1.
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    MSIDDefaultCredentialCacheKey *key1 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                           environment:@"login.microsoftonline.com"
                                                                                              clientId:@"client"
                                                                                        credentialType:MSIDAccessTokenType];
    key1.target = @"user.read user.write";
    key1.realm = @"contoso.com";
    [_dataSource saveToken:accessToken key:key1 serializer:_serializer context:nil error:nil];
    
    // Item 2.
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];
    MSIDDefaultCredentialCacheKey *key2 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                           environment:@"login.microsoftonline.com"
                                                                                              clientId:@"client"
                                                                                        credentialType:MSIDIDTokenType];
    key2.realm = @"contoso.com";
    
    [_dataSource saveToken:idToken key:key2 serializer:_serializer context:nil error:nil];
    
    // Item 3.
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshToken:nil];
    MSIDDefaultCredentialCacheKey *key3 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                           environment:@"login.microsoftonline.com"
                                                                                              clientId:@"client"
                                                                                        credentialType:MSIDRefreshTokenType];
    
    [_dataSource saveToken:refreshToken key:key3 serializer:_serializer context:nil error:nil];
    
    //Item 4
    MSIDAppMetadataCacheItem *appMetadata1 = [self createAppMetadataCacheItem:nil];
    MSIDAppMetadataCacheKey *key4 = [[MSIDAppMetadataCacheKey alloc] initWithClientId:appMetadata1.clientId
                                                                          environment:appMetadata1.environment
                                                                             familyId:appMetadata1.familyId
                                                                          generalType:MSIDAppMetadataType];
    
    [_dataSource saveAppMetadata:appMetadata1 key:key4 serializer:_serializer context:nil error:nil];
    
    //Item 5
    MSIDDefaultAccountCacheKey *key5 = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:@"uid.utid" environment:@"login.microsoftonline.com" realm:@"realm" type:MSIDAccountTypeMSSTS];
    
    MSIDAccountCacheItem *account = [MSIDAccountCacheItem new];
    account.homeAccountId = @"uid.utid";
    account.environment = @"login.microsoftonline.com";
    account.accountType = MSIDAccountTypeMSSTS;
    [_dataSource saveAccount:account key:key5 serializer:_serializer context:nil error:nil];
    
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.matchAnyCredentialType = YES;
    NSArray<MSIDCredentialCacheItem *> *items = [_dataSource tokensWithKey:query serializer:_serializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 3);
    XCTAssertTrue([items containsObject:accessToken]);
    XCTAssertTrue([items containsObject:idToken]);
    XCTAssertTrue([items containsObject:refreshToken]);
    
    [_dataSource removeTokensWithKey:query context:nil error:nil];
    
    items = [_dataSource tokensWithKey:query serializer:_serializer context:nil error:nil];
    XCTAssertEqual(items.count, 0);

    // Verify that the appmetadata was written to the keychain by reading it back and comparing:
    NSArray<MSIDAppMetadataCacheItem *> *appMetadataItems = [_dataSource appMetadataEntriesWithKey:key4 serializer:_serializer context:nil error:nil];
    XCTAssertTrue([appMetadataItems count] == 1);
    XCTAssertEqualObjects(appMetadataItems[0], appMetadata1);
}
#pragma mark - Helpers

- (MSIDCredentialCacheItem *)createTestAccessTokenCacheItem
{
    MSIDCredentialCacheItem *item = [MSIDCredentialCacheItem new];
    item.credentialType = MSIDAccessTokenType;
    item.homeAccountId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.realm = @"contoso.com";
    item.clientId = @"client";
    item.target = @"user.read user.write";
    item.secret = @"at";
    return item;
}

- (MSIDCredentialCacheItem *)createTestIDTokenCacheItem
{
    return [self createTestIDTokenCacheItemWithUPN:@"user@upn.com"];
}

- (MSIDCredentialCacheItem *)createTestIDTokenCacheItemWithUPN:(NSString *)upn
{
    MSIDCredentialCacheItem *item = [MSIDCredentialCacheItem new];
    item.credentialType = MSIDIDTokenType;
    item.homeAccountId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.clientId = @"client";
    item.realm = @"contoso.com";
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Name" upn:upn oid:nil tenantId:@"tid"];
    item.secret = idToken;
    
    return item;
}

- (MSIDAppMetadataCacheItem *)createAppMetadataCacheItem:(NSString *)familyId
{
    MSIDAppMetadataCacheItem *item = [MSIDAppMetadataCacheItem new];
    item.clientId = @"client";
    item.environment = @"login.microsoftonline.com";
    item.familyId = familyId;
    return item;
}

- (MSIDCredentialCacheItem *)createTestRefreshToken:(NSString *)familyId
{
    MSIDCredentialCacheItem *item = [MSIDCredentialCacheItem new];
    item.credentialType = MSIDRefreshTokenType;
    item.homeAccountId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.clientId = @"client";
    item.familyId = familyId;
    return item;
}

- (BOOL)arraysContainSameObjects:(NSArray *)array1 andOtherArray:(NSArray *)array2 {
    // quit if array count is different
    if ([array1 count] != [array2 count]) return NO;
    
    BOOL bothArraysContainTheSameObjects = YES;
    
    for (id objectInArray1 in array1) {
        
        if (![array2 containsObject:objectInArray1])
        {
            bothArraysContainTheSameObjects = NO;
            break;
        }
        
    }
    
    return bothArraysContainTheSameObjects;
}

@end
