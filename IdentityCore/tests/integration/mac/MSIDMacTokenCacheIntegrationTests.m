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

@interface MSIDMacTokenCacheMocDelegate : NSObject<MSIDMacTokenCacheDelegate>

@property (nonatomic) NSInteger willAccessCount;
@property (nonatomic) NSInteger didAccessCount;
@property (nonatomic) NSInteger willWriteCount;
@property (nonatomic) NSInteger didWriteCount;

@end

@implementation MSIDMacTokenCacheMocDelegate

#pragma mark - MSIDMacTokenCacheDelegate

- (void)willAccessCache:(nonnull MSIDMacTokenCache *)cache
{
    self.willAccessCount++;
}

- (void)didAccessCache:(nonnull MSIDMacTokenCache *)cache
{
    self.didAccessCount++;
}

- (void)willWriteCache:(nonnull MSIDMacTokenCache *)cache
{
    self.willWriteCount++;
}

- (void)didWriteCache:(nonnull MSIDMacTokenCache *)cache
{
    self.didWriteCount++;
}

@end

@interface MSIDMacTokenCacheIntegrationTests : XCTestCase

@property (nonatomic) MSIDMacTokenCacheMocDelegate *macTokenCacheMocDelegate;

@end

@implementation MSIDMacTokenCacheIntegrationTests

- (void)setUp
{
    [super setUp];
    
    self.macTokenCacheMocDelegate = [MSIDMacTokenCacheMocDelegate new];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Tests

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

#pragma mark - MSIDMacTokenCacheDelegate

- (void)testItemsWithKey_whenDelegateNotNil_shouldNotifyDelegateAbotCacheAccessing
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    cache.delegate = self.macTokenCacheMocDelegate;
    
    [cache itemWithKey:nil serializer:nil context:nil error:nil];
    
    XCTAssertEqual(self.macTokenCacheMocDelegate.willAccessCount, 1);
    XCTAssertEqual(self.macTokenCacheMocDelegate.didAccessCount, 1);
}

- (void)testSetItem_whenDelegateNotNil_shouldNotifyDelegateAbotCacheWriting
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    cache.delegate = self.macTokenCacheMocDelegate;
    
    [cache setItem:nil key:[MSIDTokenCacheKey new] serializer:nil context:nil error:nil];
    
    XCTAssertEqual(self.macTokenCacheMocDelegate.willWriteCount, 1);
    XCTAssertEqual(self.macTokenCacheMocDelegate.didWriteCount, 1);
}

- (void)testRemoveItemsWithKey_whenDelegateNotNil_shouldNotifyDelegateAbotCacheWriting
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    cache.delegate = self.macTokenCacheMocDelegate;
    
    [cache removeItemsWithKey:nil context:nil error:nil];
    
    XCTAssertEqual(self.macTokenCacheMocDelegate.willWriteCount, 1);
    XCTAssertEqual(self.macTokenCacheMocDelegate.didWriteCount, 1);
}

@end
