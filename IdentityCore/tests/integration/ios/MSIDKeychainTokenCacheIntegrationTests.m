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
#import "MSIDKeychainTokenCache.h"
#import "MSIDKeychainUtil.h"
#import "MSIDLegacyTokenCacheItem.h"
#import "MSIDCacheKey.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDCredentialCacheItem.h"
#import "MSIDLegacyTokenCacheKey.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDAppMetadataCacheKey.h"
#import "MSIDAppMetadataCacheQuery.h"
#import "MSIDAccountMetadataCacheItem.h"
#import "MSIDAccountMetadataCacheKey.h"

@interface MSIDKeychainTokenCacheIntegrationTests : XCTestCase

@property (nonatomic) NSData *generic;

@end

@implementation MSIDKeychainTokenCacheIntegrationTests

- (void)setUp
{
    [super setUp];
    
    [MSIDKeychainTokenCache reset];
    
    self.generic = [@"some value" dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)tearDown
{
    [super tearDown];
    
    [MSIDKeychainTokenCache reset];

    MSIDKeychainTokenCache.defaultKeychainGroup = @"com.microsoft.adalcache";
}

#pragma mark - Tests

- (void)test_whenSetDefaultKeychainGroup_shouldReturnProperGroup
{
    MSIDKeychainTokenCache.defaultKeychainGroup = @"my.group";
    
    XCTAssertEqualObjects(MSIDKeychainTokenCache.defaultKeychainGroup, @"my.group");
}

- (void)testInitWithGroup_shoulReturnGroupWithTeamId
{
    MSIDKeychainTokenCache *keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:@"my.group" error:nil];
    NSString *teamId = [[MSIDKeychainUtil sharedInstance] teamId];
    NSString *expected = [NSString stringWithFormat:@"%@.my.group", teamId];
    
    XCTAssertEqualObjects(keychainTokenCache.keychainGroup, expected);
}

- (void)testInitWithGroup_whenGroupHasTemaIdAsPrefix_shoulReturnSameGroupWithTeamId
{
    NSString *teamId = [[MSIDKeychainUtil sharedInstance] teamId];
    NSString *group = [NSString stringWithFormat:@"%@.my.group", teamId];
    MSIDKeychainTokenCache *keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:group error:nil];
    
    XCTAssertEqualObjects(keychainTokenCache.keychainGroup, group);
}

#pragma mark - MSIDTokenCacheDataSource

- (void)test_whenSetItemWithValidParameters_shouldReturnTrue
{    
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDLegacyTokenCacheItem *token = [MSIDLegacyTokenCacheItem new];
    token.secret = @"some token";
    token.refreshToken = @"refresh token";
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    
    BOOL result = [keychainTokenCache saveToken:token key:key serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertTrue(result);
}

- (void)test_whenSetItem_shouldGetSameItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.secret = @"some token";
    token.credentialType = MSIDAccessTokenType;
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    
    BOOL result = [keychainTokenCache saveToken:token key:key serializer:serializer context:nil error:nil];
    XCTAssertTrue(result);
    
    MSIDCredentialCacheItem *token2 = [keychainTokenCache tokenWithKey:key serializer:serializer context:nil error:nil];
    
    XCTAssertEqualObjects(token, token2);
}

- (void)testSetItem_whenKeysAccountIsNil_shouldSaveItemWithEmptyAccount
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.secret = @"oauth type";
    
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:nil service:@"test_service" generic:self.generic type:nil];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    NSError *error;
    
    BOOL result = [keychainTokenCache saveToken:token key:key serializer:serializer context:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    MSIDCredentialCacheItem *token2 = [keychainTokenCache tokenWithKey:key serializer:serializer context:nil error:nil];
    XCTAssertEqualObjects(token, token2);
}

- (void)testSetItem_whenKeysServiceIsNil_shouldReturnFalseAndError
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:nil generic:self.generic type:nil];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    NSError *error;
    
    BOOL result = [keychainTokenCache saveToken:token key:key serializer:serializer context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)testSetItem_whenItemAlreadyExistInKeychain_shouldUpdateIt
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.secret = @"some token";
    token.credentialType = MSIDAccessTokenType;
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.secret = @"some token";
    token2.credentialType = MSIDAccessTokenType;
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    
    [keychainTokenCache saveToken:token key:key serializer:serializer context:nil error:nil];
    [keychainTokenCache saveToken:token2 key:key serializer:serializer context:nil error:nil];
    MSIDCredentialCacheItem *tokenResult = [keychainTokenCache tokenWithKey:key serializer:serializer context:nil error:nil];
    
    XCTAssertEqualObjects(tokenResult, token2);
}

- (void)testItemsWithKey_whenKeyIsQuery_shouldReturnProperItems
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    // Item 1.
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.secret = @"secret1";
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token1 key:key1 serializer:serializer context:nil error:nil];
    // Item 2.
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.secret = @"secret2";
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item2" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token2 key:key2 serializer:serializer context:nil error:nil];
    // Item 3.
    MSIDCredentialCacheItem *token3 = [MSIDCredentialCacheItem new];
    token3.secret = @"secret3";

    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:@"item3" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token3 key:key3 serializer:serializer context:nil error:nil];
    
    MSIDCacheKey *queryKey = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:nil generic:self.generic type:nil];
    NSError *error;
    
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:queryKey serializer:serializer context:nil error:&error];
    
    XCTAssertEqual(items.count, 2);
    
    XCTAssertTrue([items containsObject:token1]);
    XCTAssertTrue([items containsObject:token2]);
    
    XCTAssertNil(error);
}

- (void)testItemsWithKey_whenKeyIsQueryWithType_shouldReturnProperItems
{
    // Todo: need to create MSIDTokenCacheItem with refreshtoken using response.
}

- (void)testRemoveItemWithKey_whenKeyIsValid_shouldRemoveItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.secret = @"some token";
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    [keychainTokenCache saveToken:token key:key serializer:serializer context:nil error:nil];
    
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:[MSIDCacheKey new] serializer:serializer context:nil error:nil];
    XCTAssertEqual(items.count, 1);
    
    NSError *error;
    
    [keychainTokenCache removeTokensWithKey:key context:nil error:&error];
    
    items = [keychainTokenCache tokensWithKey:[MSIDCacheKey new] serializer:serializer context:nil error:nil];
    XCTAssertEqual(items.count, 0);
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsValidWithType_shouldRemoveItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.secret = @"some token";
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    [keychainTokenCache saveToken:token key:key serializer:serializer context:nil error:nil];
    
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:[MSIDCacheKey new] serializer:serializer context:nil error:nil];
    XCTAssertEqual(items.count, 1);
    
    NSError *error;
    
    [keychainTokenCache removeTokensWithKey:key context:nil error:&error];
    
    items = [keychainTokenCache tokensWithKey:[MSIDCacheKey new] serializer:serializer context:nil error:nil];
    XCTAssertEqual(items.count, 0);
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsNil_shouldReturnError
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    // Item 1.
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.secret = @"secret1";
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token1 key:key1 serializer:serializer context:nil error:nil];
    // Item 2.
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.secret = @"secret2";
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item2" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token2 key:key2 serializer:serializer context:nil error:nil];
    // Item 3.
    MSIDCredentialCacheItem *token3 = [MSIDCredentialCacheItem new];
    token3.secret = @"secret3";
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:@"item3" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token3 key:key3 serializer:serializer context:nil error:nil];
    // Item 4.
    MSIDCredentialCacheItem *token4 = [MSIDCredentialCacheItem new];
    token4.secret = @"secret4";
    MSIDCacheKey *key4 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:@"item4" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token4 key:key4 serializer:serializer context:nil error:nil];
    
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:nil serializer:serializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 4);
    
    NSError *error;
    
    BOOL result = [keychainTokenCache removeTokensWithKey:nil context:nil error:&error];
    items = [keychainTokenCache tokensWithKey:nil serializer:serializer context:nil error:nil];
    
    XCTAssertFalse(result);
    XCTAssertEqual(items.count, 4);
    XCTAssertNotNil(error);
}

- (void)testSaveWipeInfoWithContext_shouldReturnTrueAndNilError
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    NSError *error;
    
    BOOL result = [keychainTokenCache saveWipeInfoWithContext:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)test_whenSaveWipeInfo_shouldReturnBundleIdAndWipeTime
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    NSError *error;
    
    [keychainTokenCache saveWipeInfoWithContext:nil error:nil];
    NSDictionary *resultWipeInfo = [keychainTokenCache wipeInfo:nil error:&error];
    
    XCTAssertNotNil(resultWipeInfo[@"bundleId"]);
    XCTAssertNotNil(resultWipeInfo[@"wipeTime"]);
    
    XCTAssertNil(error);
}

- (void)testItemsWithKey_whenFindsTombstoneItems_shouldSkipThem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    // Item 1.
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.secret = @"<tombstone>";
    token1.credentialType = MSIDRefreshTokenType;
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token1 key:key1 serializer:serializer context:nil error:nil];
    // Item 2.
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.secret = @"secret2";
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item2" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token2 key:key2 serializer:serializer context:nil error:nil];
    // Item 3.
    MSIDCredentialCacheItem *token3 = [MSIDCredentialCacheItem new];
    token3.secret = @"secret3";
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item3" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token3 key:key3 serializer:serializer context:nil error:nil];
    NSError *error;
    
    NSArray<MSIDCredentialCacheItem *> *items = ([keychainTokenCache tokensWithKey:nil serializer:serializer context:nil error:nil]);
    
    XCTAssertEqual(items.count, 2);
    XCTAssertNil(error);
}

- (void)testItemsWithKey_whenFindsTombstoneItems_shouldDeleteThemFromKeychain
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.secret = @"<tombstone>";
    token1.credentialType = MSIDRefreshTokenType;
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token1 key:key1 serializer:serializer context:nil error:nil];
    
    [keychainTokenCache tokensWithKey:nil serializer:serializer context:nil error:nil];
    
    NSMutableDictionary *query = [@{(id)kSecClass : (id)kSecClassGenericPassword} mutableCopy];
    [query setObject:@YES forKey:(id)kSecReturnData];
    [query setObject:@YES forKey:(id)kSecReturnAttributes];
    [query setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
    [query setObject:@"item1" forKey:(id)kSecAttrService];
    [query setObject:@"test_account" forKey:(id)kSecAttrAccount];
    CFTypeRef cfItems = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &cfItems);

    XCTAssertEqual(status, errSecItemNotFound);
}

#pragma mark - Partial queries

- (void)testTokensWithKey_whenQueryingByGeneric_shouldReturnCorrectItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDAccessTokenType;
    token1.secret = @"at";
    
    NSData *generic1 = [@"generic1" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service" generic:generic1 type:nil];
    [keychainTokenCache saveToken:token1 key:key1 serializer:serializer context:nil error:nil];
    
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.credentialType = MSIDRefreshTokenType;
    token2.secret = @"rt";
    
    NSData *generic2 = [@"generic2" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service2" generic:generic2 type:nil];
    [keychainTokenCache saveToken:token2 key:key2 serializer:serializer context:nil error:nil];
    
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:nil service:nil generic:generic2 type:nil];
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:key3 serializer:serializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 1);
    XCTAssertEqualObjects(items[0].secret, @"rt");
}

- (void)testTokensWithKey_whenQueryingByType_shouldReturnCorrectItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDAccessTokenType;
    token1.secret = @"at";
    
    NSData *generic1 = [@"generic1" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service" generic:generic1 type:@1];
    [keychainTokenCache saveToken:token1 key:key1 serializer:serializer context:nil error:nil];
    
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.credentialType = MSIDRefreshTokenType;
    token2.secret = @"rt";
    
    NSData *generic2 = [@"generic2" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service2" generic:generic2 type:@2];
    [keychainTokenCache saveToken:token2 key:key2 serializer:serializer context:nil error:nil];
    
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:nil service:nil generic:nil type:@2];
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:key3 serializer:serializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 1);
    XCTAssertEqualObjects(items[0].secret, @"rt");
}

- (void)testTokensWithKey_whenQueryingByAccount_shouldReturnCorrectItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDAccessTokenType;
    token1.secret = @"at";
    
    NSData *generic1 = [@"generic1" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service" generic:generic1 type:@1];
    [keychainTokenCache saveToken:token1 key:key1 serializer:serializer context:nil error:nil];
    
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.credentialType = MSIDRefreshTokenType;
    token2.secret = @"rt";
    
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:@"service" generic:generic1 type:@1];
    [keychainTokenCache saveToken:token2 key:key2 serializer:serializer context:nil error:nil];
    
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:nil generic:nil type:nil];
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:key3 serializer:serializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 1);
    XCTAssertEqualObjects(items[0].secret, @"rt");
}

- (void)testTokensWithKey_whenQueryingByService_shouldReturnCorrectItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDAccessTokenType;
    token1.secret = @"at";
    
    NSData *generic1 = [@"generic1" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service" generic:generic1 type:@1];
    [keychainTokenCache saveToken:token1 key:key1 serializer:serializer context:nil error:nil];
    
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.credentialType = MSIDRefreshTokenType;
    token2.secret = @"rt";
    
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service2" generic:generic1 type:@1];
    [keychainTokenCache saveToken:token2 key:key2 serializer:serializer context:nil error:nil];
    
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:nil service:@"service2" generic:nil type:nil];
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:key3 serializer:serializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 1);
    XCTAssertEqualObjects(items[0].secret, @"rt");
}

- (void)testTokensWithKey_whenLegacyCacheKey_differentCaseUserIDs_shouldReturnCorrectItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];

    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDAccessTokenType;
    token1.secret = @"at";

    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

    MSIDLegacyTokenCacheKey *key1 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority clientId:@"clientID" resource:@"resource" legacyUserId:@"test_account"];
    [keychainTokenCache saveToken:token1 key:key1 serializer:serializer context:nil error:nil];

    MSIDLegacyTokenCacheKey *key2 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority clientId:@"clientID" resource:@"resource" legacyUserId:@"Test_account"];
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:key2 serializer:serializer context:nil error:nil];

    XCTAssertEqual(items.count, 1);
}

- (void)testTokensWithKey_whenDefaultKey_andDifferentAppKeys_shouldReturnCorrectItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDAccessTokenType;
    token1.secret = @"at";
    
    MSIDDefaultCredentialCacheKey *key1 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid" environment:@"environment" clientId:@"client" credentialType:MSIDRefreshTokenType];
    key1.appKey = @"appkey";
    [keychainTokenCache saveToken:token1 key:key1 serializer:serializer context:nil error:nil];
    
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.credentialType = MSIDAccessTokenType;
    token2.secret = @"at2";
    
    MSIDDefaultCredentialCacheKey *key2 = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid" environment:@"environment" clientId:@"client" credentialType:MSIDRefreshTokenType];
    key2.appKey = @"appkey2";
    [keychainTokenCache saveToken:token2 key:key2 serializer:serializer context:nil error:nil];
    
    NSArray *allItems = [keychainTokenCache tokensWithKey:[MSIDCacheKey new] serializer:serializer context:nil error:nil];
    XCTAssertEqual([allItems count], 2);
    
    NSArray *items = [keychainTokenCache tokensWithKey:key1 serializer:serializer context:nil error:nil];
    XCTAssertEqual([items count], 1);
    XCTAssertEqualObjects(items[0], token1);
    
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.appKey = @"appkey";
    items = [keychainTokenCache tokensWithKey:query serializer:serializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 1);
    XCTAssertEqualObjects(items[0], token1);
}

- (void)testTokensWithKey_whenLegacyCacheKey_differentCaseClientIDsAndResource_shouldReturnCorrectItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];

    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDAccessTokenType;
    token1.secret = @"at";

    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

    MSIDLegacyTokenCacheKey *key1 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority clientId:@"clientID" resource:@"resource" legacyUserId:@"test_account"];
    [keychainTokenCache saveToken:token1 key:key1 serializer:serializer context:nil error:nil];
    MSIDLegacyTokenCacheKey *key2 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority clientId:@"ClientID" resource:@"Resource" legacyUserId:@"test_account"];
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:key2 serializer:serializer context:nil error:nil];

    XCTAssertEqual(items.count, 1);
}

- (void)testSaveAppMetadataWithKey_whenItemAlreadyExistInKeychain_shouldUpdateIt
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
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
    
    [keychainTokenCache saveAppMetadata:appMetadata1 key:key serializer:serializer context:nil error:nil];
    [keychainTokenCache saveAppMetadata:appMetadata2 key:key serializer:serializer context:nil error:nil];
    
    NSArray<MSIDAppMetadataCacheItem *> *appMetadataItems = [keychainTokenCache appMetadataEntriesWithKey:key serializer:serializer context:nil error:nil];
    XCTAssertTrue([appMetadataItems count] == 1);
    XCTAssertEqualObjects(appMetadataItems[0], appMetadata2);
}

- (void)testAppMetadataEntriesWithKey_ShouldReturnCorrectEntries
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDAppMetadataCacheItem *appMetadata = [MSIDAppMetadataCacheItem new];
    appMetadata.clientId = @"clientId1";
    appMetadata.environment = @"environment1";
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    
    MSIDAppMetadataCacheKey *key = [[MSIDAppMetadataCacheKey alloc] initWithClientId:@"clientId1"
                                                                         environment:@"environment1"
                                                                            familyId:nil
                                                                         generalType:MSIDAppMetadataType];
    
    [keychainTokenCache saveAppMetadata:appMetadata key:key serializer:serializer context:nil error:nil];
    appMetadata.environment = @"environment2";
    key.environment = @"environment2";
    [keychainTokenCache saveAppMetadata:appMetadata key:key serializer:serializer context:nil error:nil];
    
    MSIDAppMetadataCacheQuery *cacheQuery = [[MSIDAppMetadataCacheQuery alloc] init];
    cacheQuery.clientId = @"clientId1";
    
    NSArray<MSIDAppMetadataCacheItem *> *appMetadataItems = [keychainTokenCache appMetadataEntriesWithKey:cacheQuery
                                                                                               serializer:serializer
                                                                                                  context:nil
                                                                                                    error:nil];
    XCTAssertTrue([appMetadataItems count] == 2);
    
    cacheQuery.environment = @"environment1";
    appMetadataItems = [keychainTokenCache appMetadataEntriesWithKey:cacheQuery
                                                          serializer:serializer
                                                             context:nil
                                                               error:nil];
    XCTAssertTrue([appMetadataItems count] == 1);
    XCTAssertEqualObjects(appMetadataItems[0].clientId, @"clientId1");
    XCTAssertEqualObjects(appMetadataItems[0].environment, @"environment1");
}

- (void)testSaveAccountMetadata_whenItemAlreadyExists_shouldUpdateItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    
    MSIDAccountMetadataCacheKey *key = [[MSIDAccountMetadataCacheKey alloc] initWitHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    MSIDAccountMetadataCacheItem *item = [[MSIDAccountMetadataCacheItem alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    
    [item setCachedURL:[NSURL URLWithString:@"https://internalContoso.com"] forRequestURL:[NSURL URLWithString:@"https://contoso.com"] instanceAware:NO error:nil];
    
    NSError *error;
    XCTAssertTrue([keychainTokenCache saveAccountMetadata:item key:key serializer:serializer context:nil error:&error]);
    XCTAssertNil(error);
    
    MSIDAccountMetadataCacheItem *cachedItem = [keychainTokenCache accountMetadataWithKey:key serializer:serializer context:nil error:&error];
    XCTAssertNotNil(cachedItem);
    XCTAssertNil(error);
    XCTAssertEqualObjects(item, cachedItem);
    
    // Resave with different item
    XCTAssertTrue([item setCachedURL:[NSURL URLWithString:@"https://internalContoso2.com"] forRequestURL:[NSURL URLWithString:@"https://contoso.com"] instanceAware:NO error:&error]);
    XCTAssertNil(error);
    
    XCTAssertTrue([keychainTokenCache saveAccountMetadata:item key:key serializer:serializer context:nil error:&error]);
    cachedItem = [keychainTokenCache accountMetadataWithKey:key serializer:serializer context:nil error:&error];
    
    XCTAssertNotNil(item);
    XCTAssertNil(error);
    XCTAssertEqualObjects(item, cachedItem);
}

- (void)testRemoveAccountMetadata_shouldRemoveItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCacheItemJsonSerializer *serializer = [MSIDCacheItemJsonSerializer new];
    
    MSIDAccountMetadataCacheKey *key = [[MSIDAccountMetadataCacheKey alloc] initWitHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    MSIDAccountMetadataCacheItem *item = [[MSIDAccountMetadataCacheItem alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    [item setCachedURL:[NSURL URLWithString:@"https://internalContoso.com"] forRequestURL:[NSURL URLWithString:@"https://contoso.com"] instanceAware:NO error:nil];
    [keychainTokenCache saveAccountMetadata:item key:key serializer:serializer context:nil error:nil];
    
    XCTAssertNotNil([keychainTokenCache accountMetadataWithKey:key serializer:serializer context:nil error:nil]);
    
    NSError *error;
    XCTAssertTrue([keychainTokenCache removeAccountMetadataForKey:key context:nil error:&error]);
    XCTAssertNil(error);
    XCTAssertNil([keychainTokenCache accountMetadataWithKey:key serializer:serializer context:nil error:nil]);
    
    
}
@end
