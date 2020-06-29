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
#import "MSIDCacheKey.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDCredentialCacheItem.h"
#import "MSIDLegacyTokenCacheKey.h"

#if TARGET_OS_IPHONE
#import "MSIDKeychainTokenCache.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#else
#import "MSIDMacTokenCache.h"
#endif

@interface MSIDTokenCacheDataSourceIntegrationTests : XCTestCase

@property (nonatomic) id<MSIDTokenCacheDataSource> dataSource;
@property (nonatomic) id<MSIDCacheItemSerializing> serializer;
@property (nonatomic) NSData *generic;

@end

@implementation MSIDTokenCacheDataSourceIntegrationTests

- (void)setUp
{
    [super setUp];
    
#if TARGET_OS_IPHONE
    self.dataSource = [MSIDKeychainTokenCache new];
    self.serializer = [MSIDCacheItemJsonSerializer new];
    self.generic = [@"some value" dataUsingEncoding:NSUTF8StringEncoding];
    
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
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.secret = @"some token";
    MSIDCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    
    BOOL result = [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:nil];
    
    XCTAssertTrue(result);
}

- (void)test_whenSetItem_shouldGetSameItem
{
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.secret = @"some token";
    token.credentialType = MSIDAccessTokenType;
    MSIDCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    
    BOOL result = [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:nil];
    XCTAssertTrue(result);
    
    MSIDCredentialCacheItem *token2 = [self.dataSource tokenWithKey:key serializer:self.serializer context:nil error:nil];
    
    XCTAssertEqualObjects(token, token2);
}

- (void)testSetItem_whenKeysServiceIsNil_shouldReturnFalseAndError
{
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:nil generic:self.generic type:nil];
    NSError *error;
    
    BOOL result = [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)testSetItem_whenItemAlreadyExistInKeychain_shouldUpdateIt
{
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.secret = @"some token";
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.secret = @"some token 2";
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    
    BOOL result = [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:nil];
    XCTAssertTrue(result);

    BOOL result2 = [self.dataSource saveToken:token2 key:key serializer:self.serializer context:nil error:nil];
    XCTAssertTrue(result2);

    MSIDCredentialCacheItem *tokenResult = [self.dataSource tokenWithKey:key serializer:self.serializer context:nil error:nil];
    
    XCTAssertEqualObjects(tokenResult, token2);
}

- (void)testItemsWithKey_whenKeyIsQuery_shouldReturnProperItems
{
    // Item 1.
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.secret = @"secret1";
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:self.generic type:nil];
    [self.dataSource saveToken:token1 key:key1 serializer:self.serializer context:nil error:nil];
    // Item 2.
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.secret = @"secret2";
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item2" generic:self.generic type:nil];
    [self.dataSource saveToken:token2 key:key2 serializer:self.serializer context:nil error:nil];
    // Item 3.
    MSIDCredentialCacheItem *token3 = [MSIDCredentialCacheItem new];
    token3.secret = @"secret3";
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:@"item3" generic:self.generic type:nil];
    [self.dataSource saveToken:token3 key:key3 serializer:self.serializer context:nil error:nil];
    
    MSIDCacheKey *queryKey = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:nil generic:self.generic type:nil];
    NSError *error;
    
    NSArray<MSIDCredentialCacheItem *> *items = [self.dataSource tokensWithKey:queryKey serializer:self.serializer context:nil error:&error];
    
    XCTAssertEqual(items.count, 2);
    
    XCTAssertTrue([items containsObject:token1]);
    XCTAssertTrue([items containsObject:token2]);
    
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsValid_shouldRemoveItem
{
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.secret = @"some token";
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:nil];
    
    NSArray<MSIDCredentialCacheItem *> *items = [self.dataSource tokensWithKey:[MSIDCacheKey new] serializer:self.serializer context:nil error:nil];
    XCTAssertEqual(items.count, 1);
    
    NSError *error;
    
    [self.dataSource removeTokensWithKey:key context:nil error:&error];
    
    items = [self.dataSource tokensWithKey:[MSIDCacheKey new] serializer:self.serializer context:nil error:nil];
    XCTAssertEqual(items.count, 0);
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsValidWithType_shouldRemoveItem
{
    MSIDCredentialCacheItem *token = [MSIDCredentialCacheItem new];
    token.secret = @"some token";
    MSIDCacheKey *key = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"test_service" generic:self.generic type:nil];
    [self.dataSource saveToken:token key:key serializer:self.serializer context:nil error:nil];
    
    NSArray<MSIDCredentialCacheItem *> *items = [self.dataSource tokensWithKey:[MSIDCacheKey new] serializer:self.serializer context:nil error:nil];
    XCTAssertEqual(items.count, 1);
    
    NSError *error;
    
    [self.dataSource removeTokensWithKey:key context:nil error:&error];
    
    items = [self.dataSource tokensWithKey:[MSIDCacheKey new] serializer:self.serializer context:nil error:nil];
    XCTAssertEqual(items.count, 0);
    XCTAssertNil(error);
}

- (void)testRemoveItemWithKey_whenKeyIsNil_shouldReuturnFalseAndDontDeleteItems
{
    // Item 1.
    MSIDCredentialCacheItem *token1 = [MSIDCredentialCacheItem new];
    token1.secret = @"secret1";
    MSIDCacheKey *key1 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item1" generic:self.generic type:nil];
    [self.dataSource saveToken:token1 key:key1 serializer:self.serializer context:nil error:nil];
    // Item 2.
    MSIDCredentialCacheItem *token2 = [MSIDCredentialCacheItem new];
    token2.secret = @"secret2";
    MSIDCacheKey *key2 = [[MSIDCacheKey alloc] initWithAccount:@"test_account" service:@"item2" generic:self.generic type:nil];
    [self.dataSource saveToken:token2 key:key2 serializer:self.serializer context:nil error:nil];
    // Item 3.
    MSIDCredentialCacheItem *token3 = [MSIDCredentialCacheItem new];
    token3.secret = @"secret3";
    MSIDCacheKey *key3 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:@"item3" generic:self.generic type:nil];
    [self.dataSource saveToken:token3 key:key3 serializer:self.serializer context:nil error:nil];
    // Item 4.
    MSIDCredentialCacheItem *token4 = [MSIDCredentialCacheItem new];
    token4.secret = @"secret4";
    MSIDCacheKey *key4 = [[MSIDCacheKey alloc] initWithAccount:@"test_account2" service:@"item4" generic:self.generic type:nil];
    [self.dataSource saveToken:token4 key:key4 serializer:self.serializer context:nil error:nil];
    
    NSArray<MSIDCredentialCacheItem *> *items = [self.dataSource tokensWithKey:nil serializer:self.serializer context:nil error:nil];
    
    XCTAssertEqual(items.count, 4);
    
    NSError *error;
    
    BOOL result = [self.dataSource removeTokensWithKey:nil context:nil error:&error];
    items = [self.dataSource tokensWithKey:nil serializer:self.serializer context:nil error:nil];
    
    XCTAssertFalse(result);
    XCTAssertEqual(items.count, 4);
    XCTAssertNotNil(error);
}

@end
