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
#import "MSIDToken.h"
#import "MSIDTokenCacheKey.h"
#import "MSIDMacTokenCache.h"

@interface MSIDMacTokenCacheIntegrationTests : XCTestCase

@end

@implementation MSIDMacTokenCacheIntegrationTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - MSIDTokenCacheDataSource

- (void)test_whenSetItemWithValidParameters_shouldReturnTrue
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDToken *token = [MSIDToken new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" type:nil];
    
    BOOL result = [cache setItem:token key:key serializer:nil context:nil error:nil];
    
    XCTAssertTrue(result);
}

- (void)test_whenSetItem_shouldGetSameItem
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDToken *token = [MSIDToken new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" type:nil];
    
    BOOL result = [cache setItem:token key:key serializer:nil context:nil error:nil];
    XCTAssertTrue(result);
    
    MSIDToken *token2 = [cache itemWithKey:key serializer:nil context:nil error:nil];
    
    XCTAssertEqualObjects(token, token2);
}

- (void)testSetItem_whenKeysAccountIsNil_shouldReturnFalseAndError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDToken *token = [MSIDToken new];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:nil service:@"test_service" type:nil];
    NSError *error;
    
    BOOL result = [cache setItem:token key:key serializer:nil context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)testSetItem_whenKeysServiceIsNil_shouldReturnFalseAndError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDToken *token = [MSIDToken new];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:nil type:nil];
    NSError *error;
    
    BOOL result = [cache setItem:token key:key serializer:nil context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)testSetItem_whenItemAlreadyExistInKeychain_shouldUpdateIt
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDToken *token = [MSIDToken new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDToken *token2 = [MSIDToken new];
    [token2 setValue:@"some token2" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" type:nil];
    
    [cache setItem:token key:key serializer:nil context:nil error:nil];
    [cache setItem:token2 key:key serializer:nil context:nil error:nil];
    MSIDToken *tokenResult = [cache itemWithKey:key serializer:nil context:nil error:nil];
    
    XCTAssertEqualObjects(tokenResult, token2);
}

- (void)testItemsWithKey_whenKeyIsQuery_shouldReturnProperItems
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    // Item 1.
    MSIDToken *token1 = [MSIDToken new];
    MSIDTokenCacheKey *key1 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" type:nil];
    [cache setItem:token1 key:key1 serializer:nil context:nil error:nil];
    // Item 2.
    MSIDToken *token2 = [MSIDToken new];
    MSIDTokenCacheKey *key2 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item2" type:nil];
    [cache setItem:token2 key:key2 serializer:nil context:nil error:nil];
    // Item 3.
    MSIDToken *token3 = [MSIDToken new];
    MSIDTokenCacheKey *key3 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account2" service:@"item3" type:nil];
    [cache setItem:token3 key:key3 serializer:nil context:nil error:nil];
    
    MSIDTokenCacheKey *queryKey = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:nil type:nil];
    NSError *error;
    
    NSArray<MSIDToken *> *items = [cache itemsWithKey:queryKey serializer:nil context:nil error:&error];
    
    XCTAssertEqual(items.count, 2);
    
    XCTAssertTrue([items containsObject:token1]);
    XCTAssertTrue([items containsObject:token2]);
    
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsValid_shouldRemoveItem
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDToken *token = [MSIDToken new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" type:nil];
    [cache setItem:token key:key serializer:nil context:nil error:nil];
    
    NSArray<MSIDToken *> *items = [cache itemsWithKey:[MSIDTokenCacheKey new] serializer:nil context:nil error:nil];
    XCTAssertEqual(items.count, 1);
    
    NSError *error;
    
    [cache removeItemsWithKey:key context:nil error:&error];
    
    items = [cache itemsWithKey:[MSIDTokenCacheKey new] serializer:nil context:nil error:nil];
    XCTAssertEqual(items.count, 0);
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsValidWithType_shouldRemoveItem
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDToken *token = [MSIDToken new];
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" type:nil];
    [cache setItem:token key:key serializer:nil context:nil error:nil];
    
    NSArray<MSIDToken *> *items = [cache itemsWithKey:[MSIDTokenCacheKey new] serializer:nil context:nil error:nil];
    XCTAssertEqual(items.count, 1);
    
    NSError *error;
    
    [cache removeItemsWithKey:key context:nil error:&error];
    
    items = [cache itemsWithKey:[MSIDTokenCacheKey new] serializer:nil context:nil error:nil];
    XCTAssertEqual(items.count, 0);
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsNil_shouldReuturnFalseAndDontDeleteItems
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    // Item 1.
    MSIDToken *token1 = [MSIDToken new];
    MSIDTokenCacheKey *key1 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" type:nil];
    [cache setItem:token1 key:key1 serializer:nil context:nil error:nil];
    // Item 2.
    MSIDToken *token2 = [MSIDToken new];
    MSIDTokenCacheKey *key2 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item2" type:nil];
    [cache setItem:token2 key:key2 serializer:nil context:nil error:nil];
    // Item 3.
    MSIDToken *token3 = [MSIDToken new];
    MSIDTokenCacheKey *key3 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account2" service:@"item3" type:nil];
    [cache setItem:token3 key:key3 serializer:nil context:nil error:nil];
    // Item 4.
    MSIDToken *token4 = [MSIDToken new];
    MSIDTokenCacheKey *key4 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account2" service:@"item4" type:nil];
    [cache setItem:token4 key:key4 serializer:nil context:nil error:nil];
    
    NSArray<MSIDToken *> *items = [cache itemsWithKey:nil serializer:nil context:nil error:nil];
    
    XCTAssertEqual(items.count, 4);
    
    NSError *error;
    
    BOOL result = [cache removeItemsWithKey:nil context:nil error:&error];
    items = [cache itemsWithKey:nil serializer:nil context:nil error:nil];
    
    XCTAssertFalse(result);
    XCTAssertEqual(items.count, 4);
    XCTAssertNotNil(error);
}

#pragma mark - Public

- (void)testSerialize_whenCacheIsEmpty_shouldReturnSameOnDeserialize
{
    MSIDMacTokenCache *cache1 = [MSIDMacTokenCache new];
    MSIDMacTokenCache *cache2 = [MSIDMacTokenCache new];
    NSError *error =  nil;
    
    id data = [cache1 serialize];
    BOOL result = [cache2 deserialize:data error:&error];
    
    id rawCache1 = [cache1 valueForKey:@"cache"];
    id rawCache2 = [cache2 valueForKey:@"cache"];
    XCTAssertNil(error);
    XCTAssertTrue(result);
    XCTAssertEqualObjects(rawCache1, rawCache2);
}

- (void)testSerialize_whenCacheHasItems_shouldReturnSameOnDeserialize
{
    MSIDMacTokenCache *cache1 = [MSIDMacTokenCache new];
    // Item 1.
    MSIDToken *token1 = [MSIDToken new];
    MSIDTokenCacheKey *key1 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" type:nil];
    [cache1 setItem:token1 key:key1 serializer:nil context:nil error:nil];
    // Item 2.
    MSIDToken *token2 = [MSIDToken new];
    MSIDTokenCacheKey *key2 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item2" type:nil];
    [cache1 setItem:token2 key:key2 serializer:nil context:nil error:nil];
    // Item 3.
    MSIDToken *token3 = [MSIDToken new];
    MSIDTokenCacheKey *key3 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account2" service:@"item3" type:nil];
    [cache1 setItem:token3 key:key3 serializer:nil context:nil error:nil];
    // Item 4.
    MSIDToken *token4 = [MSIDToken new];
    MSIDTokenCacheKey *key4 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account2" service:@"item4" type:nil];
    [cache1 setItem:token4 key:key4 serializer:nil context:nil error:nil];
    NSError *error = nil;
    MSIDMacTokenCache *cache2 = [MSIDMacTokenCache new];
    
    id data = [cache1 serialize];
    BOOL result = [cache2 deserialize:data error:&error];
    
    id rawCache1 = [cache1 valueForKey:@"cache"];
    id rawCache2 = [cache2 valueForKey:@"cache"];
    XCTAssertNil(error);
    XCTAssertTrue(result);
    XCTAssertEqualObjects(rawCache1, rawCache2);
}

- (void)testClear_whenCacheHasItems_shouldClearCache
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    // Item 1.
    MSIDToken *token1 = [MSIDToken new];
    MSIDTokenCacheKey *key1 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" type:nil];
    [cache setItem:token1 key:key1 serializer:nil context:nil error:nil];
    // Item 2.
    MSIDToken *token2 = [MSIDToken new];
    MSIDTokenCacheKey *key2 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item2" type:nil];
    [cache setItem:token2 key:key2 serializer:nil context:nil error:nil];
    // Item 3.
    MSIDToken *token3 = [MSIDToken new];
    MSIDTokenCacheKey *key3 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account2" service:@"item3" type:nil];
    [cache setItem:token3 key:key3 serializer:nil context:nil error:nil];
    // Item 4.
    MSIDToken *token4 = [MSIDToken new];
    MSIDTokenCacheKey *key4 = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account2" service:@"item4" type:nil];
    [cache setItem:token4 key:key4 serializer:nil context:nil error:nil];

    [cache clear];
    
    NSArray<MSIDToken *> *items = [cache itemsWithKey:nil serializer:nil context:nil error:nil];
    XCTAssertNotNil(items);
    XCTAssertEqual(items.count, 0);
}

@end
