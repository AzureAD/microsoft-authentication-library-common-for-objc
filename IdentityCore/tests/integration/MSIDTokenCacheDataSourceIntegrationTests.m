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
#import "MSIDTokenCacheDataSource.h"
#import "MSIDTokenCacheKey.h"
#import "MSIDCacheItemSerializer.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDBaseCacheItem.h"

#if TARGET_OS_IPHONE
#import "MSIDKeychainTokenCache.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#else
#import "MSIDMacTokenCache.h"
#endif

@interface MSIDTokenCacheDataSourceIntegrationTests : XCTestCase

@property (nonatomic) id<MSIDTokenCacheDataSource> dataSource;
@property (nonatomic) id<MSIDCacheItemSerializer> serializer;

@end

@implementation MSIDTokenCacheDataSourceIntegrationTests

- (void)setUp
{
    [super setUp];
    
#if TARGET_OS_IPHONE
    self.dataSource = [MSIDKeychainTokenCache new];
    self.serializer = [MSIDKeyedArchiverSerializer new];
    
    [MSIDKeychainTokenCache reset];
#else
    self.dataSource = [MSIDMacTokenCache new];
#endif
}

- (void)tearDown
{
    [super tearDown];
    
    self.dataSource = nil;
    self.serializer = nil;
}

#pragma mark - Tests

- (void)test_whenSetItemWithValidParameters_shouldReturnTrue
{
    MSIDBaseCacheItem *token = [MSIDBaseCacheItem new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:nil type:nil];
    
    BOOL result = [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:nil];
    
    XCTAssertTrue(result);
}

- (void)test_whenSetItem_shouldGetSameItem
{
    MSIDBaseCacheItem *token = [MSIDBaseCacheItem new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:nil type:nil];
    
    BOOL result = [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:nil];
    XCTAssertTrue(result);
    
    MSIDBaseCacheItem *token2 = [self.dataSource tokenWithKey:key serializer:self.serializer context:nil error:nil];
    
    XCTAssertEqualObjects(token, token2);
}

- (void)testSetItem_whenKeysAccountIsNil_shouldReturnFalseAndError
{
    MSIDBaseCacheItem *token = [MSIDBaseCacheItem new];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:nil service:@"test_service" generic:nil type:nil];
    NSError *error;
    
    BOOL result = [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)testSetItem_whenKeysServiceIsNil_shouldReturnFalseAndError
{
    MSIDBaseCacheItem *token = [MSIDBaseCacheItem new];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:nil generic:nil type:nil];
    NSError *error;
    
    BOOL result = [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)testSetItem_whenItemAlreadyExistInKeychain_shouldUpdateIt
{
    MSIDBaseCacheItem *token = [MSIDBaseCacheItem new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDBaseCacheItem *token2 = [MSIDBaseCacheItem new];
    [token2 setValue:@"some token2" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:nil type:nil];
    
    [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:nil];
    [self.dataSource saveToken:token2 key:key serializer:self.serializer context:nil error:nil];
    MSIDBaseCacheItem *tokenResult = [self.dataSource tokenWithKey:key serializer:self.serializer context:nil error:nil];
    
    XCTAssertEqualObjects(tokenResult, token2);
}

- (void)testItemsWithKey_whenKeyIsQuery_shouldReturnProperItems
{
    // Item 1.
    MSIDBaseCacheItem *token1 = [MSIDBaseCacheItem new];
    MSIDTokenCacheKey *key1 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:nil type:nil];
    [self.dataSource saveToken:token1 key:key1 serializer:self.serializer context:nil error:nil];
    // Item 2.
    MSIDBaseCacheItem *token2 = [MSIDBaseCacheItem new];
    MSIDTokenCacheKey *key2 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item2" generic:nil type:nil];
    [self.dataSource saveToken:token2 key:key2 serializer:self.serializer context:nil error:nil];
    // Item 3.
    MSIDBaseCacheItem *token3 = [MSIDBaseCacheItem new];
    MSIDTokenCacheKey *key3 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account2" service:@"item3" generic:nil type:nil];
    [self.dataSource saveToken:token3 key:key3 serializer:self.serializer context:nil error:nil];
    
    MSIDTokenCacheKey *queryKey = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:nil generic:nil type:nil];
    NSError *error;
    
    NSArray<MSIDBaseCacheItem *> *items = [self.dataSource tokensWithKey:queryKey serializer:self.serializer context:nil error:&error];
    
    XCTAssertEqual(items.count, 2);
    
    XCTAssertTrue([items containsObject:token1]);
    XCTAssertTrue([items containsObject:token2]);
    
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsValid_shouldRemoveItem
{
    MSIDBaseCacheItem *token = [MSIDBaseCacheItem new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:nil type:nil];
    [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:nil];
    
    NSArray<MSIDBaseCacheItem *> *items = [self.dataSource tokensWithKey:[MSIDTokenCacheKey new] serializer:self.serializer context:nil error:nil];
    XCTAssertEqual(items.count, 1);
    
    NSError *error;
    
    [self.dataSource removeItemsWithKey:key context:nil error:&error];
    
    items = [self.dataSource tokensWithKey:[MSIDTokenCacheKey new] serializer:self.serializer context:nil error:nil];
    XCTAssertEqual(items.count, 0);
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsValidWithType_shouldRemoveItem
{
    MSIDBaseCacheItem *token = [MSIDBaseCacheItem new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:nil type:nil];
    [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:nil];
    
    NSArray<MSIDBaseCacheItem *> *items = [self.dataSource tokensWithKey:[MSIDTokenCacheKey new] serializer:self.serializer context:nil error:nil];
    XCTAssertEqual(items.count, 1);
    
    NSError *error;
    
    [self.dataSource removeItemsWithKey:key context:nil error:&error];
    
    items = [self.dataSource tokensWithKey:[MSIDTokenCacheKey new] serializer:self.serializer context:nil error:nil];
    XCTAssertEqual(items.count, 0);
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsNil_shouldReuturnFalseAndDontDeleteItems
{
    // Item 1.
    MSIDBaseCacheItem *token1 = [MSIDBaseCacheItem new];
    MSIDTokenCacheKey *key1 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:nil type:nil];
    [self.dataSource saveToken:token1 key:key1 serializer:self.serializer context:nil error:nil];
    // Item 2.
    MSIDBaseCacheItem *token2 = [MSIDBaseCacheItem new];
    MSIDTokenCacheKey *key2 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item2" generic:nil type:nil];
    [self.dataSource saveToken:token2 key:key2 serializer:self.serializer context:nil error:nil];
    // Item 3.
    MSIDBaseCacheItem *token3 = [MSIDBaseCacheItem new];
    MSIDTokenCacheKey *key3 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account2" service:@"item3" generic:nil type:nil];
    [self.dataSource saveToken:token3 key:key3 serializer:self.serializer context:nil error:nil];
    // Item 4.
    MSIDBaseCacheItem *token4 = [MSIDBaseCacheItem new];
    MSIDTokenCacheKey *key4 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account2" service:@"item4" generic:nil type:nil];
    [self.dataSource saveToken:token4 key:key4 serializer:self.serializer context:nil error:nil];
    
    NSArray<MSIDBaseCacheItem *> *items = [self.dataSource tokensWithKey:nil serializer:self.serializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 4);
    
    NSError *error;
    
    BOOL result = [self.dataSource removeItemsWithKey:nil context:nil error:&error];
    items = [self.dataSource tokensWithKey:nil serializer:self.serializer context:nil error:nil];
    
    XCTAssertFalse(result);
    XCTAssertEqual(items.count, 4);
    XCTAssertNotNil(error);
}

@end
