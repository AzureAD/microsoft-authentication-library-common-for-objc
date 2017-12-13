//
//  MSIDKeychainTokenCacheIntegrationTests.m
//  IdentityCore
//
//  Created by Sergey Demchenko on 12/4/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MSIDKeychainTokenCache.h"
#import "MSIDKeychainUtil.h"
#import "MSIDToken.h"
#import "MSIDTokenCacheKey.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"

@interface MSIDKeychainTokenCacheIntegrationTests : XCTestCase

@end

@implementation MSIDKeychainTokenCacheIntegrationTests

- (void)setUp
{
    [super setUp];
    
    [MSIDKeychainTokenCache reset];
}

- (void)tearDown
{
    [super tearDown];
    
    [MSIDKeychainTokenCache reset];
}

- (void)test_whenGetDefaultKeychainGroup_shouldReturnAdalGroup
{
    XCTAssertEqualObjects(MSIDKeychainTokenCache.defaultKeychainGroup, @"com.microsoft.adalcache");
}

- (void)test_whenSetDefaultKeychainGroup_shouldReturnProperGroup
{
    MSIDKeychainTokenCache.defaultKeychainGroup = @"my.group";
    
    XCTAssertEqualObjects(MSIDKeychainTokenCache.defaultKeychainGroup, @"my.group");
}

- (void)test_whenSetDefaultKeychainGroupAfterDefaultCacheInitialization_shouldThrow
{
    // Init default cache.
    MSIDKeychainTokenCache * __unused tokenCache = MSIDKeychainTokenCache.defaultKeychainCache;
    
    XCTAssertThrows(MSIDKeychainTokenCache.defaultKeychainGroup = @"my.group");
}

#pragma mark - MSIDTokenCacheDataSource

- (void)test_whenSetItemWithValidParameters_shouldReturnTrue
{    
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDToken *token = [MSIDToken new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service"];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    
    BOOL result = [keychainTokenCache setItem:token withKey:key serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertTrue(result);
}

- (void)test_whenSetItem_shouldGetSameItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDToken *token = [MSIDToken new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service"];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    
    [keychainTokenCache setItem:token withKey:key serializer:keyedArchiverSerializer context:nil error:nil];
    MSIDToken *token2 = [keychainTokenCache itemWithKey:key serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertEqualObjects(token, token2);
}

- (void)test_whenSetItemWhenKeysAccountIsNil_shouldReturnFalseAndError
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDToken *token = [MSIDToken new];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:nil service:@"test_service"];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    NSError *error;
    
    BOOL result = [keychainTokenCache setItem:token withKey:key serializer:keyedArchiverSerializer context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)test_whenSetItemWhenKeysServiceIsNil_shouldReturnFalseAndError
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDToken *token = [MSIDToken new];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:nil];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    NSError *error;
    
    BOOL result = [keychainTokenCache setItem:token withKey:key serializer:keyedArchiverSerializer context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)test_whenItemsWithQueryKey_shouldReturnProperItems
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    // Item 1.
    MSIDToken *token1 = [MSIDToken new];
    MSIDTokenCacheKey *key1 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1"];
    [keychainTokenCache setItem:token1 withKey:key1 serializer:keyedArchiverSerializer context:nil error:nil];
    // Item 2.
    MSIDToken *token2 = [MSIDToken new];
    MSIDTokenCacheKey *key2 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item2"];
    [keychainTokenCache setItem:token2 withKey:key2 serializer:keyedArchiverSerializer context:nil error:nil];
    // Item 3.
    MSIDToken *token3 = [MSIDToken new];
    MSIDTokenCacheKey *key3 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account2" service:@"item3"];
    [keychainTokenCache setItem:token3 withKey:key3 serializer:keyedArchiverSerializer context:nil error:nil];
    MSIDTokenCacheKey *queryKey = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:nil];
    NSError *error;
    
    NSArray<MSIDToken *> *items = [keychainTokenCache itemsWithKey:queryKey serializer:keyedArchiverSerializer context:nil error:&error];
    
    XCTAssertEqual(items.count, 2);
    
    XCTAssertTrue([items containsObject:token1]);
    XCTAssertTrue([items containsObject:token2]);
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsValid_shouldRemoveItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDToken *token = [MSIDToken new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service"];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    [keychainTokenCache setItem:token withKey:key serializer:keyedArchiverSerializer context:nil error:nil];
    NSError *error;
    
    [keychainTokenCache removeItemsWithKey:key context:nil error:&error];
    
    NSArray<MSIDToken *> *items = [keychainTokenCache itemsWithKey:[MSIDTokenCacheKey new] serializer:keyedArchiverSerializer context:nil error:nil];
    XCTAssertEqual(items.count, 0);
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsNil_shouldRemoveAllItems
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    // Item 1.
    MSIDToken *token1 = [MSIDToken new];
    MSIDTokenCacheKey *key1 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1"];
    [keychainTokenCache setItem:token1 withKey:key1 serializer:keyedArchiverSerializer context:nil error:nil];
    // Item 2.
    MSIDToken *token2 = [MSIDToken new];
    MSIDTokenCacheKey *key2 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item2"];
    [keychainTokenCache setItem:token2 withKey:key2 serializer:keyedArchiverSerializer context:nil error:nil];
    // Item 3.
    MSIDToken *token3 = [MSIDToken new];
    MSIDTokenCacheKey *key3 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account2" service:@"item3"];
    [keychainTokenCache setItem:token3 withKey:key3 serializer:keyedArchiverSerializer context:nil error:nil];
    NSError *error;
    
    BOOL result = [keychainTokenCache removeItemsWithKey:nil context:nil error:&error];
    NSArray<MSIDToken *> *items = [keychainTokenCache itemsWithKey:nil serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertTrue(result);
    XCTAssertEqual(items.count, 0);
    XCTAssertNil(error);
}

- (void)testSaveWipeInfo_whenNotNilInfo_shouldReturnTrueAndNilError
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    NSDictionary *wipeInfo = @{@"key": @"value"};
    NSError *error;
    
    BOOL result = [keychainTokenCache saveWipeInfo:wipeInfo context:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testSaveWipeInfo_whenNilInfo_shouldReturnFalseAndError
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    NSError *error;
    
    BOOL result = [keychainTokenCache saveWipeInfo:nil context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)test_whenSaveWipeInfo_shouldReturnSameWipeInfoOnGet
{
    MSIDKeychainTokenCache *keychainTokenCache = [MSIDKeychainTokenCache new];
    NSDictionary *expectedWipeInfo = @{@"key2": @"value2"};
    NSError *error;
    
    [keychainTokenCache saveWipeInfo:expectedWipeInfo context:nil error:nil];
    NSDictionary *resultWipeInfo = [keychainTokenCache wipeInfo:nil error:&error];
    
    XCTAssertEqualObjects(resultWipeInfo, expectedWipeInfo);
    XCTAssertNil(error);
}

@end
