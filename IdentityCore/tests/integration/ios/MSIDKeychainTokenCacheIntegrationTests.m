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
#import "MSIDCredentialCacheItem.h"
#import "MSIDCacheKey.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDTokenCacheItem.h"
#import "MSIDLegacyTokenCacheKey.h"

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
    MSIDKeychainTokenCache *keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:@"my.group"];
    NSString *expected = [NSString stringWithFormat:@"%@.my.group", MSIDKeychainUtil.teamId];
    
    XCTAssertEqualObjects(keychainTokenCache.keychainGroup, expected);
}

- (void)testInitWithGroup_whenGroupHasTemaIdAsPrefix_shoulReturnSameGroupWithTeamId
{
    NSString *group = [NSString stringWithFormat:@"%@.my.group", MSIDKeychainUtil.teamId];
    MSIDKeychainTokenCache *keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:group];
    
    XCTAssertEqualObjects(keychainTokenCache.keychainGroup, group);
}

#pragma mark - MSIDTokenCacheDataSource

- (void)test_whenSetItemWithValidParameters_shouldReturnTrue
{    
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.accessToken = @"some token";
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    
    BOOL result = [keychainTokenCache saveToken:token key:key serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertTrue(result);
}

- (void)test_whenSetItem_shouldGetSameItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.accessToken = @"some token";
    token.credentialType = MSIDCredentialTypeAccessToken;
    token.oauthTokenType = @"token type";
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    
    BOOL result = [keychainTokenCache saveToken:token key:key serializer:keyedArchiverSerializer context:nil error:nil];
    XCTAssertTrue(result);
    
    MSIDCredentialCacheItem *token2 = [keychainTokenCache tokenWithKey:key serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertEqualObjects(token, token2);
}

- (void)testSetItem_whenKeysAccountIsNil_shouldSaveItemWithEmptyAccount
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.oauthTokenType = @"oauth type";
    
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:nil service:@"test_service" generic:self.generic type:nil];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    NSError *error;
    
    BOOL result = [keychainTokenCache saveToken:token key:key serializer:keyedArchiverSerializer context:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    MSIDCredentialCacheItem *token2 = [keychainTokenCache tokenWithKey:key serializer:keyedArchiverSerializer context:nil error:nil];
    XCTAssertEqualObjects(token, token2);
}

- (void)testSetItem_whenKeysServiceIsNil_shouldReturnFalseAndError
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:nil generic:self.generic type:nil];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    NSError *error;
    
    BOOL result = [keychainTokenCache saveToken:token key:key serializer:keyedArchiverSerializer context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)testSetItem_whenItemAlreadyExistInKeychain_shouldUpdateIt
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.accessToken = @"some token";
    token.credentialType = MSIDCredentialTypeAccessToken;
    token.oauthTokenType = @"token type";
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.accessToken = @"some token";
    token2.credentialType = MSIDCredentialTypeAccessToken;
    token2.oauthTokenType = @"token type";
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    
    [keychainTokenCache saveToken:token key:key serializer:keyedArchiverSerializer context:nil error:nil];
    [keychainTokenCache saveToken:token2 key:key serializer:keyedArchiverSerializer context:nil error:nil];
    MSIDCredentialCacheItem *tokenResult = [keychainTokenCache tokenWithKey:key serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertEqualObjects(tokenResult, token2);
}

- (void)testItemsWithKey_whenKeyIsQuery_shouldReturnProperItems
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    // Item 1.
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.oauthTokenType = @"token type";
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token1 key:key1 serializer:keyedArchiverSerializer context:nil error:nil];
    // Item 2.
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.oauthTokenType = @"token type";
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item2" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token2 key:key2 serializer:keyedArchiverSerializer context:nil error:nil];
    // Item 3.
    MSIDCredentialCacheItem *token3 = [MSIDCredentialCacheItem new];
    token3.oauthTokenType = @"token type";
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:@"item3" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token3 key:key3 serializer:keyedArchiverSerializer context:nil error:nil];
    
    MSIDCacheKey *queryKey = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:nil generic:self.generic type:nil];
    NSError *error;
    
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:queryKey serializer:keyedArchiverSerializer context:nil error:&error];
    
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
    token.accessToken = @"some token";
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    [keychainTokenCache saveToken:token key:key serializer:keyedArchiverSerializer context:nil error:nil];
    
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:[MSIDCacheKey new] serializer:keyedArchiverSerializer context:nil error:nil];
    XCTAssertEqual(items.count, 1);
    
    NSError *error;
    
    [keychainTokenCache removeItemsWithKey:key context:nil error:&error];
    
    items = [keychainTokenCache tokensWithKey:[MSIDCacheKey new] serializer:keyedArchiverSerializer context:nil error:nil];
    XCTAssertEqual(items.count, 0);
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsValidWithType_shouldRemoveItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.accessToken = @"some token";
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    [keychainTokenCache saveToken:token key:key serializer:keyedArchiverSerializer context:nil error:nil];
    
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:[MSIDCacheKey new] serializer:keyedArchiverSerializer context:nil error:nil];
    XCTAssertEqual(items.count, 1);
    
    NSError *error;
    
    [keychainTokenCache removeItemsWithKey:key context:nil error:&error];
    
    items = [keychainTokenCache tokensWithKey:[MSIDCacheKey new] serializer:keyedArchiverSerializer context:nil error:nil];
    XCTAssertEqual(items.count, 0);
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsNil_shouldReturnError
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    // Item 1.
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token1 key:key1 serializer:keyedArchiverSerializer context:nil error:nil];
    // Item 2.
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item2" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token2 key:key2 serializer:keyedArchiverSerializer context:nil error:nil];
    // Item 3.
    MSIDCredentialCacheItem *token3 = [MSIDCredentialCacheItem new];
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:@"item3" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token3 key:key3 serializer:keyedArchiverSerializer context:nil error:nil];
    // Item 4.
    MSIDCredentialCacheItem *token4 = [MSIDCredentialCacheItem new];
    MSIDCacheKey *key4 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:@"item4" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token4 key:key4 serializer:keyedArchiverSerializer context:nil error:nil];
    
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:nil serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 4);
    
    NSError *error;
    
    BOOL result = [keychainTokenCache removeItemsWithKey:nil context:nil error:&error];
    items = [keychainTokenCache tokensWithKey:nil serializer:keyedArchiverSerializer context:nil error:nil];
    
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
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    // Item 1.
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.refreshToken = @"<tombstone>";
    token1.credentialType = MSIDCredentialTypeRefreshToken;
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token1 key:key1 serializer:keyedArchiverSerializer context:nil error:nil];
    // Item 2.
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item2" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token2 key:key2 serializer:keyedArchiverSerializer context:nil error:nil];
    // Item 3.
    MSIDCredentialCacheItem *token3 = [MSIDCredentialCacheItem new];
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item3" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token3 key:key3 serializer:keyedArchiverSerializer context:nil error:nil];
    NSError *error;
    
    NSArray<MSIDCredentialCacheItem *> *items = ([keychainTokenCache tokensWithKey:nil serializer:keyedArchiverSerializer context:nil error:nil]);
    
    XCTAssertEqual(items.count, 2);
    XCTAssertNil(error);
}

- (void)testItemsWithKey_whenFindsTombstoneItems_shouldDeleteThemFromKeychain
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.refreshToken = @"<tombstone>";
    token1.credentialType = MSIDCredentialTypeRefreshToken;
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:self.generic type:nil];
    [keychainTokenCache saveToken:token1 key:key1 serializer:keyedArchiverSerializer context:nil error:nil];
    
    [keychainTokenCache tokensWithKey:nil serializer:keyedArchiverSerializer context:nil error:nil];
    
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
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDCredentialTypeAccessToken;
    token1.accessToken = @"at";
    
    NSData *generic1 = [@"generic1" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service" generic:generic1 type:nil];
    [keychainTokenCache saveToken:token1 key:key1 serializer:keyedArchiverSerializer context:nil error:nil];
    
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.credentialType = MSIDCredentialTypeRefreshToken;
    token2.refreshToken = @"rt";
    
    NSData *generic2 = [@"generic2" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service2" generic:generic2 type:nil];
    [keychainTokenCache saveToken:token2 key:key2 serializer:keyedArchiverSerializer context:nil error:nil];
    
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:nil service:nil generic:generic2 type:nil];
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:key3 serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 1);
    XCTAssertEqualObjects(items[0].refreshToken, @"rt");
}

- (void)testTokensWithKey_whenQueryingByType_shouldReturnCorrectItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDCredentialTypeAccessToken;
    token1.accessToken = @"at";
    
    NSData *generic1 = [@"generic1" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service" generic:generic1 type:@1];
    [keychainTokenCache saveToken:token1 key:key1 serializer:keyedArchiverSerializer context:nil error:nil];
    
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.credentialType = MSIDCredentialTypeRefreshToken;
    token2.refreshToken = @"rt";
    
    NSData *generic2 = [@"generic2" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service2" generic:generic2 type:@2];
    [keychainTokenCache saveToken:token2 key:key2 serializer:keyedArchiverSerializer context:nil error:nil];
    
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:nil service:nil generic:nil type:@2];
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:key3 serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 1);
    XCTAssertEqualObjects(items[0].refreshToken, @"rt");
}

- (void)testTokensWithKey_whenQueryingByAccount_shouldReturnCorrectItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDCredentialTypeAccessToken;
    token1.accessToken = @"at";
    
    NSData *generic1 = [@"generic1" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service" generic:generic1 type:@1];
    [keychainTokenCache saveToken:token1 key:key1 serializer:keyedArchiverSerializer context:nil error:nil];
    
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.credentialType = MSIDCredentialTypeRefreshToken;
    token2.refreshToken = @"rt";
    
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:@"service" generic:generic1 type:@1];
    [keychainTokenCache saveToken:token2 key:key2 serializer:keyedArchiverSerializer context:nil error:nil];
    
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:nil generic:nil type:nil];
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:key3 serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 1);
    XCTAssertEqualObjects(items[0].refreshToken, @"rt");
}

- (void)testTokensWithKey_whenQueryingByService_shouldReturnCorrectItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDCredentialTypeAccessToken;
    token1.accessToken = @"at";
    
    NSData *generic1 = [@"generic1" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service" generic:generic1 type:@1];
    [keychainTokenCache saveToken:token1 key:key1 serializer:keyedArchiverSerializer context:nil error:nil];
    
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.credentialType = MSIDCredentialTypeRefreshToken;
    token2.refreshToken = @"rt";
    
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"service2" generic:generic1 type:@1];
    [keychainTokenCache saveToken:token2 key:key2 serializer:keyedArchiverSerializer context:nil error:nil];
    
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:nil service:@"service2" generic:nil type:nil];
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:key3 serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 1);
    XCTAssertEqualObjects(items[0].refreshToken, @"rt");
}

- (void)testTokensWithKey_whenLegacyCacheKey_differentCaseUserIDs_shouldReturnCorrectItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];

    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDCredentialTypeAccessToken;
    token1.accessToken = @"at";

    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    MSIDLegacyTokenCacheKey *key1 = [MSIDLegacyTokenCacheKey keyWithAuthority:authority clientId:@"clientID" resource:@"resource" legacyUserId:@"test_account"];
    [keychainTokenCache saveToken:token1 key:key1 serializer:keyedArchiverSerializer context:nil error:nil];

    MSIDLegacyTokenCacheKey *key2 = [MSIDLegacyTokenCacheKey keyWithAuthority:authority clientId:@"clientID" resource:@"resource" legacyUserId:@"Test_account"];
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:key2 serializer:keyedArchiverSerializer context:nil error:nil];

    XCTAssertEqual(items.count, 1);
}

- (void)testTokensWithKey_whenLegacyCacheKey_differentCaseClientIDsAndResource_shouldReturnCorrectItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];

    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.credentialType = MSIDCredentialTypeAccessToken;
    token1.accessToken = @"at";

    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    MSIDLegacyTokenCacheKey *key1 = [MSIDLegacyTokenCacheKey keyWithAuthority:authority clientId:@"clientID" resource:@"resource" legacyUserId:@"test_account"];
    [keychainTokenCache saveToken:token1 key:key1 serializer:keyedArchiverSerializer context:nil error:nil];

    MSIDLegacyTokenCacheKey *key2 = [MSIDLegacyTokenCacheKey keyWithAuthority:authority clientId:@"ClientID" resource:@"Resource" legacyUserId:@"test_account"];
    NSArray<MSIDCredentialCacheItem *> *items = [keychainTokenCache tokensWithKey:key2 serializer:keyedArchiverSerializer context:nil error:nil];

    XCTAssertEqual(items.count, 1);
}

@end
