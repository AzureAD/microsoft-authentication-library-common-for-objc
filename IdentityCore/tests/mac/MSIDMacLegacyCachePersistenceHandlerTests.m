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
#import "MSIDMacLegacyCachePersistenceHandler.h"
#import "MSIDMacTokenCache.h"
#import "MSIDCredentialCacheItem.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDMacACLKeychainAccessor.h"
#import "MSIDLegacyTokenCacheKey.h"
#import "MSIDLegacyTokenCacheItem.h"

@interface MSIDMacLegacyCachePersistenceHandlerTests : XCTestCase

@end

@implementation MSIDMacLegacyCachePersistenceHandlerTests

- (void)setUp
{
    [super setUp];
    
    MSIDMacACLKeychainAccessor *accessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:nil accessLabel:@"label" error:nil];
    
    NSDictionary *attributes = @{(id)kSecAttrLabel : @"my-xctest-msal-label"};
    [accessor clearWithAttributes:attributes context:nil error:nil];
}

- (void)testInitWithMissingAccountParameter_shouldReturnNilAndFillError
{
    NSError *error = nil;
    MSIDMacLegacyCachePersistenceHandler *handler = [[MSIDMacLegacyCachePersistenceHandler alloc] initWithTrustedApplications:nil accessLabel:@"test" attributes:@{(id)kSecAttrService : @"myservice"} error:&error];
    
    XCTAssertNil(handler);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
}

- (void)testInitWithMissingServiceParameter_shouldReturnNilAndFillError
{
    NSError *error = nil;
    MSIDMacLegacyCachePersistenceHandler *handler = [[MSIDMacLegacyCachePersistenceHandler alloc] initWithTrustedApplications:nil accessLabel:@"test" attributes:@{(id)kSecAttrAccount : @"myaccount"} error:&error];
    
    XCTAssertNil(handler);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
}

- (void)testInitWithCorrectParameters_shouldReturnCacheAndNilError
{
    NSError *error = nil;
    MSIDMacLegacyCachePersistenceHandler *handler = [[MSIDMacLegacyCachePersistenceHandler alloc] initWithTrustedApplications:nil accessLabel:@"test" attributes:@{(id)kSecAttrAccount : @"myaccount", (id)kSecAttrService : @"myservice"} error:&error];
    
    XCTAssertNotNil(handler);
    XCTAssertNil(error);
}

- (void)testTokenCacheDelegateCallbacks_whenReadingFromSerializedCache_shouldFillCache
{
    MSIDLegacyTokenCacheKey *key1 = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"account" service:@"service" generic:nil type:nil];
    MSIDCredentialCacheItem *item = [self testCredentialItem1];
    BOOL result = [self writeTestDataWithItem:item
                                          key:key1
                          keychainAttrAccount:@"unit-test-account"
                          keychainAttrService:@"unit-test-service"];
    XCTAssertTrue(result);
    
    MSIDMacTokenCache *tokenCache = [MSIDMacTokenCache new];
    [tokenCache clear];
    
    NSError *error = nil;
    
    NSDictionary *attributes = @{(id)kSecAttrAccount : @"unit-test-account",
                                 (id)kSecAttrService : @"unit-test-service",
                                 (id)kSecAttrLabel : @"my-xctest-msal-label"};
    
    MSIDMacLegacyCachePersistenceHandler *handler = [[MSIDMacLegacyCachePersistenceHandler alloc] initWithTrustedApplications:nil accessLabel:@"test" attributes:attributes error:&error];
    
    XCTAssertNotNil(handler);
    XCTAssertNil(error);
    
    tokenCache.delegate = handler;
    
    MSIDCredentialCacheItem *writtenItem = [tokenCache tokenWithKey:key1 serializer:[MSIDKeyedArchiverSerializer new] context:nil error:&error];
    XCTAssertNotNil(writtenItem);
    XCTAssertNil(error);
    XCTAssertEqualObjects(writtenItem, item);
}

- (void)testTokenCacheDelegateCallbacks_whenWritingToSerializedCache_shouldFillCache
{
    MSIDMacTokenCache *tokenCache = [MSIDMacTokenCache new];
    [tokenCache clear];
    
    NSError *error = nil;
    
    NSDictionary *attributes = @{(id)kSecAttrAccount : @"unit-test-account",
                                 (id)kSecAttrService : @"unit-test-service",
                                 (id)kSecAttrLabel : @"my-xctest-msal-label"};
    
    MSIDMacLegacyCachePersistenceHandler *handler = [[MSIDMacLegacyCachePersistenceHandler alloc] initWithTrustedApplications:nil accessLabel:@"test" attributes:attributes error:&error];
    
    XCTAssertNotNil(handler);
    XCTAssertNil(error);
    
    tokenCache.delegate = handler;
    
    MSIDLegacyTokenCacheKey *key1 = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"account" service:@"service" generic:nil type:nil];
    MSIDLegacyTokenCacheKey *key2 = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"account2" service:@"service2" generic:nil type:nil];
    MSIDCredentialCacheItem *item1 = [self testCredentialItem1];
    
    BOOL result = [tokenCache saveToken:item1 key:key1 serializer:[MSIDKeyedArchiverSerializer new] context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    MSIDCredentialCacheItem *item2 = [item1 copy];
    item2.clientId = @"client2";
    
    BOOL result2 = [tokenCache saveToken:item2 key:key2 serializer:[MSIDKeyedArchiverSerializer new] context:nil error:&error];
    XCTAssertTrue(result2);
    XCTAssertNil(error);
    
    MSIDMacTokenCache *newTokenCache = [MSIDMacTokenCache new];
    [newTokenCache clear];
    newTokenCache.delegate = handler;
    
    MSIDCredentialCacheItem *writtenItem1 = [newTokenCache tokenWithKey:key1 serializer:[MSIDKeyedArchiverSerializer new] context:nil error:&error];
    XCTAssertNotNil(writtenItem1);
    XCTAssertNil(error);
    XCTAssertEqualObjects(item1, writtenItem1);
    
    MSIDCredentialCacheItem *writtenItem2 = [newTokenCache tokenWithKey:key2 serializer:[MSIDKeyedArchiverSerializer new] context:nil error:&error];
    XCTAssertNotNil(writtenItem2);
    XCTAssertNil(error);
    XCTAssertEqualObjects(item2, writtenItem2);
}

- (void)testTokenCacheDelegateCallbacks_whenWritingToSerializedCache_andCacheModified_shouldFillCacheWithLatestUpdates
{
    MSIDMacTokenCache *tokenCache = [MSIDMacTokenCache new];
    [tokenCache clear];
    
    NSError *error = nil;
    
    NSDictionary *attributes = @{(id)kSecAttrAccount : @"unit-test-account",
                                 (id)kSecAttrService : @"unit-test-service",
                                 (id)kSecAttrLabel : @"my-xctest-msal-label"};
    
    MSIDMacLegacyCachePersistenceHandler *handler = [[MSIDMacLegacyCachePersistenceHandler alloc] initWithTrustedApplications:nil accessLabel:@"test" attributes:attributes error:&error];
    
    XCTAssertNotNil(handler);
    XCTAssertNil(error);
    
    tokenCache.delegate = handler;
    
    MSIDLegacyTokenCacheKey *key1 = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"account" service:@"service" generic:nil type:nil];
    MSIDLegacyTokenCacheKey *key2 = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"account2" service:@"service2" generic:nil type:nil];
    MSIDLegacyTokenCacheKey *key3 = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@"account3" service:@"service3" generic:nil type:nil];
    MSIDCredentialCacheItem *item1 = [self testCredentialItem1];
    
    BOOL result = [tokenCache saveToken:item1 key:key1 serializer:[MSIDKeyedArchiverSerializer new] context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Modify cache by a different process
    MSIDCredentialCacheItem *item2 = [item1 copy];
    item2.clientId = @"client2";
    [self writeTestDataWithItem:item2 key:key2 keychainAttrAccount:@"unit-test-account" keychainAttrService:@"unit-test-service"];
    
    // Now write new item
    MSIDCredentialCacheItem *item3 = [item1 copy];
    item3.clientId = @"client3";
    result = [tokenCache saveToken:item3 key:key3 serializer:[MSIDKeyedArchiverSerializer new] context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Now read
    MSIDCredentialCacheItem *writtenItem1 = [tokenCache tokenWithKey:key1 serializer:[MSIDKeyedArchiverSerializer new] context:nil error:&error];
    XCTAssertNil(writtenItem1);
    XCTAssertNil(error);
    
    MSIDCredentialCacheItem *writtenItem2 = [tokenCache tokenWithKey:key2 serializer:[MSIDKeyedArchiverSerializer new] context:nil error:&error];
    XCTAssertNotNil(writtenItem2);
    XCTAssertEqualObjects(writtenItem2, item2);
    XCTAssertNil(error);
    
    MSIDCredentialCacheItem *writtenItem3 = [tokenCache tokenWithKey:key3 serializer:[MSIDKeyedArchiverSerializer new] context:nil error:&error];
    XCTAssertNotNil(writtenItem3);
    XCTAssertEqualObjects(writtenItem3, item3);
    XCTAssertNil(error);
}

#pragma mark - Helpers

- (BOOL)writeTestDataWithItem:(MSIDCredentialCacheItem *)item
                          key:(MSIDCacheKey *)key
          keychainAttrAccount:(NSString *)attrAccount
          keychainAttrService:(NSString *)attrService
{
    MSIDMacTokenCache *tokenCache = [MSIDMacTokenCache new];
    [tokenCache clear];
    
    BOOL saveResult = [tokenCache saveToken:item key:key serializer:[MSIDKeyedArchiverSerializer new] context:nil error:nil];
    XCTAssertTrue(saveResult);
    
    NSData *serializedData = [tokenCache serialize];
    
    MSIDMacACLKeychainAccessor *aclKeychain = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:nil accessLabel:@"test" error:nil];
    
    NSDictionary *attributes = @{(id)kSecAttrAccount : attrAccount, (id)kSecAttrService : attrService, (id)kSecAttrLabel : @"my-xctest-msal-label"};
    return [aclKeychain saveData:serializedData attributes:attributes context:nil error:nil];
}

- (MSIDLegacyTokenCacheItem *)testCredentialItem1
{
    MSIDLegacyTokenCacheItem *item = [MSIDLegacyTokenCacheItem new];
    item.clientId = @"client1";
    item.credentialType = MSIDRefreshTokenType;
    item.environment = @"login.microsoftonline.com";
    item.secret = @"rt1";
    item.realm = @"common";
    item.refreshToken = @"rt1";
    item.homeAccountId = @"uid1.utid1";
    item.oauthTokenType = @"Bearer";
    return item;
}

@end
