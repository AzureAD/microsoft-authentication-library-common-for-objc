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
    MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
    keychainUtil.teamId = @"FakeTeamId";
    _dataSource = [MSIDMacKeychainTokenCache new];
    _cache = [[MSIDAccountCredentialCache alloc] initWithDataSource:_dataSource];
    _serializer = [MSIDCacheItemJsonSerializer new];
    [_cache clearWithContext:nil error:nil];

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

    _accountA = [MSIDAccountCacheItem new];
    _accountB = [MSIDAccountCacheItem new];
    _accountC = [MSIDAccountCacheItem new];

    _accountA.environment = DEFAULT_TEST_ENVIRONMENT;
    _accountA.realm = @"realmA";
    _accountA.homeAccountId = @"uidA.utidA";
    _accountA.localAccountId = @"localAccountIdA";
    _accountA.accountType = MSIDAccountTypeMSSTS;
    _accountA.username = @"UsernameA";
    _accountA.givenName = @"GivenNameA";
    _accountA.familyName = @"FamilyNameA";
    _accountA.middleName = @"MiddleNameA";
    _accountA.name = @"NameA";
    _accountA.alternativeAccountId = @"AltIdA";

    _accountB.environment = _accountA.environment;
    _accountB.realm = _accountA.realm;
    _accountB.homeAccountId = @"uidB.utidB";
    _accountB.localAccountId = @"localAccountIdB";
    _accountB.accountType = _accountA.accountType;
    _accountB.username = @"UsernameB";
    _accountB.givenName = @"GivenNameB";
    _accountB.familyName = @"FamilyNameB";
    _accountB.middleName = @"MiddleNameB";
    _accountB.name = @"NameB";
    _accountB.alternativeAccountId = @"AltIdB";

    _accountC.environment = _accountA.environment;
    _accountC.realm = _accountA.realm;
    _accountC.homeAccountId = @"uidC.utidC";
    _accountC.localAccountId = @"localAccountIdC";
    _accountC.accountType = MSIDAccountTypeMSA;
    _accountC.username = @"UsernameC";
    _accountC.givenName = @"GivenNameC";
    _accountC.familyName = @"FamilyNameC";
    _accountC.middleName = @"MiddleNameC";
    _accountC.name = @"NameC";
    _accountC.alternativeAccountId = @"AltIdC";

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
    NSError* error;
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
    MSIDAccountCacheItem* account1 = [MSIDAccountCacheItem new];
    MSIDAccountCacheItem* account2 = [MSIDAccountCacheItem new];

    account1.environment = DEFAULT_TEST_ENVIRONMENT;
    account1.realm = @"Contoso.COM";
    account1.homeAccountId = @"uid.utid";
    account1.localAccountId = @"homeAccountIdA";
    account1.accountType = MSIDAccountTypeAADV1;
    account1.username = @"UsernameA";
    account1.givenName = @"GivenNameA";
    account1.familyName = @"FamilyNameA";
    account1.middleName = @"MiddleNameA";
    account1.name = @"NameA";
    account1.alternativeAccountId = @"AltIdA";
    account1.additionalAccountFields = @{@"key1": @"value1", @"key2": @"value2"};

    account2.environment = account1.environment;
    account2.realm = account1.realm;
    account2.homeAccountId = account1.homeAccountId;
    account2.localAccountId = @"homeAccountIdB";
    account2.accountType = MSIDAccountTypeMSSTS;
    account2.username = @"UsernameB";
    account2.givenName = @"GivenNameB";
    account2.familyName = @"FamilyNameB";
    account2.middleName = @"MiddleNameB";
    account2.name = @"NameB";
    account2.alternativeAccountId = @"AltIdB";
    account2.additionalAccountFields = @{@"key1": @"VALUE1", @"key3": @"VALUE3"};
    [account2 updateFieldsFromAccount:account1]; // merge the additionalAccountFields dictionaries

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

    BOOL result = [_dataSource saveAccount:account1 key:key1 serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    result = [_dataSource saveAccount:account2 key:key2 serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    MSIDAccountCacheItem* expectedAccount = account2;
    [expectedAccount setAdditionalAccountFields:@{@"key1": @"VALUE1", @"key2": @"value2", @"key3": @"VALUE3"}];

    MSIDAccountCacheItem *actualAccount = [_dataSource accountWithKey:key2
                                                           serializer:_serializer
                                                              context:nil
                                                                error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(actualAccount);
    XCTAssertTrue([expectedAccount isEqual:actualAccount]);

    result = [_dataSource removeAccountsWithKey:key2 context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    // removing with keyB should delete the same keychain item referred to by keyA since they
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
    
    // Verify that the account was written to the keychain by reading it back and comparing:
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
    
    // Verify that the account was written to the keychain by reading it back and comparing:
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
    token1.secret = @"secret1";
    MSIDDefaultCredentialCacheKey *key1 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                           environment:@"environment"
                                                                                              clientId:@"clientId"
                                                                                        credentialType:MSIDAccessTokenType];
    key1.target = @"user.read user.write";
    [_dataSource saveToken:token1 key:key1 serializer:_serializer context:nil error:nil];
    
    // Item 2.
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.secret = @"secret2";
    MSIDDefaultCredentialCacheKey *key2 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                           environment:@"login.microsoftonline.com"
                                                                                              clientId:@"clientId"
                                                                                        credentialType:MSIDIDTokenType];
    
    [_dataSource saveToken:token2 key:key2 serializer:_serializer context:nil error:nil];
    
    // Item 3.
    MSIDCredentialCacheItem *token3 = [MSIDCredentialCacheItem new];
    token3.secret = @"secret3";
    MSIDDefaultCredentialCacheKey *key3 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                           environment:@"login.microsoftonline.com"
                                                                                              clientId:@"clientId"
                                                                                        credentialType:MSIDRefreshTokenType];
    
    [_dataSource saveToken:token3 key:key3 serializer:_serializer context:nil error:nil];
    
    MSIDDefaultCredentialCacheKey *query = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                            environment:@"login.microsoftonline.com"
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
    account.additionalAccountFields = @{@"key1": @"value1", @"key2": @"value2"};
    
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

@end
