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
#import "MSIDMacCredentialStorageItem.h"

@interface MSIDMacCredentialStorageItemTests : XCTestCase

@end

@implementation MSIDMacCredentialStorageItemTests

- (MSIDCredentialCacheItem *)credentialForAccount:(NSString *)account type:(MSIDCredentialType)type secret:(NSString *)secret
{
    MSIDCredentialCacheItem *item = [MSIDCredentialCacheItem new];
    item.homeAccountId = account;
    item.environment = @"login.microsoftonline.com";
    item.clientId = @"storage-test-client";
    item.realm = @"tenant";
    item.target = @"user.read";
    item.credentialType = type;
    item.secret = secret;
    item.tokenType = @"Bearer";
    return item;
}

- (MSIDAppMetadataCacheItem *)metadataForFamily:(NSString *)family
{
    MSIDAppMetadataCacheItem *item = [MSIDAppMetadataCacheItem new];
    item.clientId = @"storage-test-client";
    item.environment = @"login.microsoftonline.com";
    item.familyId = family;
    return item;
}

- (void)testSerialization_roundTripsCredentialTypesAndMetadataWithoutMixingAccounts
{
    MSIDMacCredentialStorageItem *storage = [MSIDMacCredentialStorageItem new];
    NSArray<MSIDCredentialCacheItem *> *credentials = @[
        [self credentialForAccount:@"first.tenant" type:MSIDAccessTokenType secret:@"access-first"],
        [self credentialForAccount:@"first.tenant" type:MSIDRefreshTokenType secret:@"refresh-first"],
        [self credentialForAccount:@"second.tenant" type:MSIDIDTokenType secret:@"id-second"]
    ];
    for (MSIDCredentialCacheItem *item in credentials)
    {
        [storage storeItem:item forKey:item.generateCacheKey];
    }
    MSIDAppMetadataCacheItem *metadata = [self metadataForFamily:@"1"];
    [storage storeItem:metadata forKey:metadata.generateCacheKey];
    NSError *error = nil;
    NSData *encoded = [NSJSONSerialization dataWithJSONObject:storage.jsonDictionary options:0 error:&error];
    XCTAssertNotNil(encoded);
    XCTAssertNil(error);
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:encoded options:0 error:&error];
    XCTAssertNotNil(json);
    XCTAssertNil(error);
    MSIDMacCredentialStorageItem *decoded = [[MSIDMacCredentialStorageItem alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNotNil(decoded);
    XCTAssertNil(error);
    for (MSIDCredentialCacheItem *item in credentials)
    {
        NSArray<MSIDCredentialCacheItem *> *items = (NSArray *)[decoded storedItemsForKey:item.generateCacheKey];
        XCTAssertEqual(items.count, 1u);
        XCTAssertEqualObjects(items.firstObject.secret, item.secret);
        XCTAssertEqualObjects(items.firstObject.homeAccountId, item.homeAccountId);
        XCTAssertEqual(items.firstObject.credentialType, item.credentialType);
    }
    NSArray<MSIDAppMetadataCacheItem *> *items = (NSArray *)[decoded storedItemsForKey:metadata.generateCacheKey];
    XCTAssertEqual(items.count, 1u);
    XCTAssertEqualObjects(items.firstObject.familyId, @"1");
    XCTAssertEqualObjects(decoded.jsonDictionary, json);
}

- (void)testMerge_replacesCollidingCredentialAndPreservesOtherAccountAndNewMetadataBucket
{
    MSIDCredentialCacheItem *first = [self credentialForAccount:@"first.tenant" type:MSIDRefreshTokenType secret:@"original"];
    MSIDCredentialCacheItem *other = [self credentialForAccount:@"second.tenant" type:MSIDRefreshTokenType secret:@"other"];
    MSIDCredentialCacheItem *replacement = [self credentialForAccount:@"first.tenant" type:MSIDRefreshTokenType secret:@"rotated"];
    MSIDMacCredentialStorageItem *storage = [MSIDMacCredentialStorageItem new];
    [storage storeItem:first forKey:first.generateCacheKey];
    [storage storeItem:other forKey:other.generateCacheKey];
    MSIDMacCredentialStorageItem *incoming = [MSIDMacCredentialStorageItem new];
    [incoming storeItem:replacement forKey:replacement.generateCacheKey];
    MSIDAppMetadataCacheItem *metadata = [self metadataForFamily:@"1"];
    [incoming storeItem:metadata forKey:metadata.generateCacheKey];
    NSDictionary *incomingJson = incoming.jsonDictionary;
    [storage mergeStorageItem:incoming];
    NSArray<MSIDCredentialCacheItem *> *updated = (NSArray *)[storage storedItemsForKey:first.generateCacheKey];
    XCTAssertEqual(updated.count, 1u);
    XCTAssertEqualObjects(updated.firstObject.secret, @"rotated");
    NSArray<MSIDCredentialCacheItem *> *unchanged = (NSArray *)[storage storedItemsForKey:other.generateCacheKey];
    XCTAssertEqual(unchanged.count, 1u);
    XCTAssertEqualObjects(unchanged.firstObject.secret, @"other");
    NSArray<MSIDAppMetadataCacheItem *> *newMetadata = (NSArray *)[storage storedItemsForKey:metadata.generateCacheKey];
    XCTAssertEqual(newMetadata.count, 1u);
    XCTAssertEqualObjects(newMetadata.firstObject.familyId, @"1");
    XCTAssertEqualObjects(incoming.jsonDictionary, incomingJson);
}

- (void)testAccountScopedRemoval_removesEveryCredentialTypeButPreservesOtherAccountAndMetadata
{
    MSIDMacCredentialStorageItem *storage = [MSIDMacCredentialStorageItem new];
    MSIDCredentialCacheItem *access = [self credentialForAccount:@"first.tenant" type:MSIDAccessTokenType secret:@"access"];
    MSIDCredentialCacheItem *refresh = [self credentialForAccount:@"first.tenant" type:MSIDRefreshTokenType secret:@"refresh"];
    MSIDCredentialCacheItem *other = [self credentialForAccount:@"second.tenant" type:MSIDRefreshTokenType secret:@"other"];
    for (MSIDCredentialCacheItem *item in @[access, refresh, other])
    {
        [storage storeItem:item forKey:item.generateCacheKey];
    }
    MSIDAppMetadataCacheItem *metadata = [self metadataForFamily:@"1"];
    [storage storeItem:metadata forKey:metadata.generateCacheKey];
    MSIDCacheKey *accountQuery = [[MSIDCacheKey alloc] initWithAccount:access.generateCacheKey.account
                                                                service:nil generic:nil type:nil];
    XCTAssertEqual([storage storedItemsForKey:accountQuery].count, 2u);
    [storage removeStoredItemForKey:accountQuery];
    XCTAssertEqual([storage storedItemsForKey:access.generateCacheKey].count, 0u);
    XCTAssertEqual([storage storedItemsForKey:refresh.generateCacheKey].count, 0u);
    NSArray<MSIDCredentialCacheItem *> *remaining = (NSArray *)[storage storedItemsForKey:other.generateCacheKey];
    XCTAssertEqual(remaining.count, 1u);
    XCTAssertEqualObjects(remaining.firstObject.secret, @"other");
    XCTAssertEqual([storage storedItemsForKey:metadata.generateCacheKey].count, 1u);
    [storage removeStoredItemForKey:accountQuery];
    XCTAssertEqual([storage storedItemsForKey:other.generateCacheKey].count, 1u);
}

- (void)testDeserialization_skipsMalformedBucketWithoutDiscardingValidCredential
{
    MSIDMacCredentialStorageItem *storage = [MSIDMacCredentialStorageItem new];
    MSIDCredentialCacheItem *credential = [self credentialForAccount:@"first.tenant" type:MSIDRefreshTokenType secret:@"retained"];
    [storage storeItem:credential forKey:credential.generateCacheKey];
    NSMutableDictionary *json = [storage.jsonDictionary mutableCopy];
    json[@"malformed-bucket"] = @"not-a-dictionary";
    NSError *error = nil;
    MSIDMacCredentialStorageItem *decoded = [[MSIDMacCredentialStorageItem alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNotNil(decoded);
    XCTAssertNil(error);
    NSArray<MSIDCredentialCacheItem *> *items = (NSArray *)[decoded storedItemsForKey:credential.generateCacheKey];
    XCTAssertEqual(items.count, 1u);
    XCTAssertEqualObjects(items.firstObject.secret, @"retained");
    XCTAssertNil(decoded.jsonDictionary[@"malformed-bucket"]);
    XCTAssertEqualObjects(decoded.jsonDictionary, storage.jsonDictionary);
}

@end
