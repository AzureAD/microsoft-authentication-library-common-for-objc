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
#import "MSIDMacTokenCache.h"
#import "MSIDCacheKey.h"
#import "MSIDLegacyTokenCacheKey.h"
#import "MSIDLegacyTokenCacheItem.h"

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

@interface MSIDMacTokenCacheTests : XCTestCase

@property (nonatomic) MSIDMacTokenCacheMocDelegate *macTokenCacheMocDelegate;

@end

@implementation MSIDMacTokenCacheTests

- (void)setUp
{
    [super setUp];
    
    self.macTokenCacheMocDelegate = [MSIDMacTokenCacheMocDelegate new];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testDeserialize_whenCacheValid_shouldReturnTrueAndNilError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDLegacyTokenCacheItem *token = [MSIDLegacyTokenCacheItem alloc];
    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:nil type:nil];
    NSDictionary *wrapper = @{@"tokenCache" : [@{
                                                 @"tokens" : [@{
                                                                @"test_account" : [@{
                                                                                     key : token
                                                                                     } mutableCopy]
                                                                } mutableCopy]
                                                 } mutableCopy],
                              @"version": @1};
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:wrapper];
    NSError *error;
    
    BOOL result = [cache deserialize:data error:&error];
    
    XCTAssertNotNil(data);
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testDeserialize_whenKeyInvalid_shouldReturnFalseAndError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDLegacyTokenCacheItem *token = [MSIDLegacyTokenCacheItem new];
    NSDictionary *wrapper = @{@"tokenCache" : [@{
                                                 @"tokens" : [@{
                                                                @"test_account" : [@{
                                                                                     @"some key" : token
                                                                                     } mutableCopy]
                                                                } mutableCopy]
                                                 } mutableCopy],
                              @"version": @1};
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:wrapper];
    NSError *error;
    
    BOOL result = [cache deserialize:data error:&error];
    
    XCTAssertNotNil(data);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Key is not of the expected class type.", error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertFalse(result);
}

- (void)testDeserialize_whenTokenInvalid_shouldReturnFalseAndError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:nil type:nil];
    NSDictionary *wrapper = @{@"tokenCache" : [@{
                                                 @"tokens" : [@{
                                                                @"test_account" : [@{
                                                                                     key : @"some token"
                                                                                     } mutableCopy]
                                                                } mutableCopy]
                                                 } mutableCopy],
                              @"version": @1};
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:wrapper];
    NSError *error;
    
    BOOL result = [cache deserialize:data error:&error];
    
    XCTAssertNotNil(data);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Token is not of the expected class type.", error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertFalse(result);
}

- (void)testDeserialize_whenUserIdInvalid_shouldReturnFalseAndError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:nil type:nil];
    NSDictionary *wrapper = @{@"tokenCache" : [@{
                                                 @"tokens" : [@{
                                                                @0 : [@{
                                                                        key : @"some token"
                                                                        } mutableCopy]
                                                                } mutableCopy]
                                                 } mutableCopy],
                              @"version": @1};
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:wrapper];
    NSError *error;
    
    BOOL result = [cache deserialize:data error:&error];
    
    XCTAssertNotNil(data);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"User ID key is not of the expected class type.", error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertFalse(result);
}

- (void)testDeserialize_whenUserIdDictionaryIsNotMutable_shouldReturnFalseAndError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDLegacyTokenCacheItem *token = [MSIDLegacyTokenCacheItem new];
    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:nil type:nil];
    NSDictionary *wrapper = @{@"tokenCache" : [@{
                                                 @"tokens" : [@{
                                                                @"test_account" : @{
                                                                        key : token
                                                                        }
                                                                } mutableCopy]
                                                 } mutableCopy],
                              @"version": @1};
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:wrapper];
    NSError *error;
    
    BOOL result = [cache deserialize:data error:&error];
    
    XCTAssertNotNil(data);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"User ID should have mutable dictionaries in the cache.", error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertFalse(result);
}

- (void)testDeserialize_whenTokensDictionaryIsNotMutable_shouldReturnFalseAndError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:nil type:nil];
    NSDictionary *wrapper = @{@"tokenCache" : [@{
                                                 @"tokens" : @{
                                                                @"test_account" : [@{
                                                                                     key : @"some token"
                                                                                     } mutableCopy]
                                                                }
                                                 } mutableCopy],
                              @"version": @1};
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:wrapper];
    NSError *error;
    
    BOOL result = [cache deserialize:data error:&error];
    
    XCTAssertNotNil(data);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Tokens must be a mutable dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertFalse(result);
}

- (void)testDeserialize_whenTokenCacheDictionaryIsNotMutable_shouldReturnFalseAndError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:nil type:nil];
    NSDictionary *wrapper = @{@"tokenCache" : @{
                                      @"tokens" : [@{
                                              @"test_account" : [@{
                                                                   key : @"some token"
                                                                   } mutableCopy]
                                              } mutableCopy]
                                      },
                              @"version": @1};
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:wrapper];
    NSError *error;
    
    BOOL result = [cache deserialize:data error:&error];
    
    XCTAssertNotNil(data);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Cache is not a mutable dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertFalse(result);
}

- (void)testDeserialize_whenTokenCacheIsMissed_shouldReturnFalseAndError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    NSDictionary *wrapper = @{ @"version": @1};
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:wrapper];
    NSError *error;
    
    BOOL result = [cache deserialize:data error:&error];
    
    XCTAssertNotNil(data);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Missing token cache from data.", error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertFalse(result);
}

- (void)testDeserialize_whenTokenCacheIsNotDicitonary_shouldReturnFalseAndError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@"some"];
    NSError *error;
    
    BOOL result = [cache deserialize:data error:&error];
    
    XCTAssertNotNil(data);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Root level object of cache is not a NSDictionary.", error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertFalse(result);
}

- (void)testDeserialize_whenCacheDoesntHaveVersion_shouldReturnFalseAndError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDLegacyTokenCacheItem *token = [MSIDLegacyTokenCacheItem new];
    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:nil type:nil];
    NSDictionary *wrapper = @{@"tokenCache" : [@{
                                                 @"tokens" : [@{
                                                                @"test_account" : [@{
                                                                                     key : token
                                                                                     } mutableCopy]
                                                                } mutableCopy]
                                                 } mutableCopy]
                              };
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:wrapper];
    NSError *error;
    
    BOOL result = [cache deserialize:data error:&error];
    
    XCTAssertNotNil(data);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Missing version number from cache.", error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertFalse(result);
}

- (void)testDeserialize_whenCacheVersionMoreThenCurrent_shouldReturnTrueAndNilError
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    MSIDLegacyTokenCacheItem *token = [MSIDLegacyTokenCacheItem new];
    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:nil type:nil];
    NSDictionary *wrapper = @{@"tokenCache" : [@{
                                                 @"tokens" : [@{
                                                                @"test_account" : [@{
                                                                                     key : token
                                                                                     } mutableCopy]
                                                                } mutableCopy]
                                                 } mutableCopy],
                              @"version": @99};
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:wrapper];
    NSError *error;
    
    BOOL result = [cache deserialize:data error:&error];
    
    XCTAssertNotNil(data);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Cache is a future unsupported version.", error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertFalse(result);
}

#pragma mark - MSIDMacTokenCacheDelegate Tests

- (void)testItemsWithKey_whenDelegateNotNil_shouldNotifyDelegateAbotCacheAccessing
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    cache.delegate = self.macTokenCacheMocDelegate;
    
    [cache tokenWithKey:nil serializer:nil context:nil error:nil];
    
    XCTAssertEqual(self.macTokenCacheMocDelegate.willAccessCount, 1);
    XCTAssertEqual(self.macTokenCacheMocDelegate.didAccessCount, 1);
}

- (void)testSetItem_whenDelegateNotNil_shouldNotifyDelegateAbotCacheWriting
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    cache.delegate = self.macTokenCacheMocDelegate;
    
    [cache saveToken:nil key:[MSIDCacheKey new] serializer:nil context:nil error:nil];
    
    XCTAssertEqual(self.macTokenCacheMocDelegate.willWriteCount, 1);
    XCTAssertEqual(self.macTokenCacheMocDelegate.didWriteCount, 1);
}

- (void)testRemoveItemsWithKey_whenDelegateNotNil_shouldNotifyDelegateAbotCacheWriting
{
    MSIDMacTokenCache *cache = [MSIDMacTokenCache new];
    cache.delegate = self.macTokenCacheMocDelegate;
    
    [cache removeTokensWithKey:nil context:nil error:nil];
    
    XCTAssertEqual(self.macTokenCacheMocDelegate.willWriteCount, 1);
    XCTAssertEqual(self.macTokenCacheMocDelegate.didWriteCount, 1);
}

@end
