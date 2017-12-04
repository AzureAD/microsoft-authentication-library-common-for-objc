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

- (void)test_whenGetAdalAccessGroup_shouldReturnProperGroup
{
    XCTAssertEqualObjects(MSIDKeychainTokenCache.adalAccessGroup, @"com.microsoft.adalcache");
}

- (void)test_whenGetAppDefaultAccessGroup_shouldReturnProperGroup
{
    XCTAssertEqualObjects(MSIDKeychainTokenCache.appDefaultAccessGroup, MSIDKeychainUtil.appDefaultAccessGroup);
}

- (void)test_whenGetDefaultKeychainCache_shouldReturnCacheWithAdalAccessGroup
{
    XCTAssertEqualObjects(MSIDKeychainTokenCache.defaultKeychainCache.accessGroup, MSIDKeychainTokenCache.adalAccessGroup);
}

- (void)test_whenInitWithAccessGroup_shouldReturnProperAccessGroup
{
    MSIDKeychainTokenCache *keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:@"my.group"];
    
    XCTAssertEqualObjects(keychainTokenCache.accessGroup, @"my.group");
}

- (void)test_whenSetDefaultKeychainCache_shouldReturnProperKeychainCache
{
    MSIDKeychainTokenCache *keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:@"my.group"];
    
    MSIDKeychainTokenCache.defaultKeychainCache = keychainTokenCache;
    
    XCTAssertEqualObjects(MSIDKeychainTokenCache.defaultKeychainCache, keychainTokenCache);
}

#pragma mark - MSIDTokenCacheDataSource

- (void)test_whenSetItemWithValidParameters_shouldReturnTrue
{
    MSIDKeychainTokenCache *keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:@"my.group"];
    MSIDToken *token = [MSIDToken new];
    // TODO: fix.
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service"];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    
    BOOL result = [keychainTokenCache setItem:token withKey:key serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertTrue(result);
}

- (void)test_whenSetItem_shouldGetSameItem
{
    MSIDKeychainTokenCache *keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:@"my.group"];
    MSIDToken *token = [MSIDToken new];
    // TODO: fix.
    [token setValue:@"some token" forKey:@"token"];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:@"test_service"];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    
    [keychainTokenCache setItem:token withKey:key serializer:keyedArchiverSerializer context:nil error:nil];
    MSIDToken *token2 = [keychainTokenCache itemWithKey:key serializer:keyedArchiverSerializer context:nil error:nil];
    
    XCTAssertEqualObjects(token, token2);
}

- (void)test_whenSetItemWhenKeysAccountIsNil_shouldReturnFalseAndError
{
    MSIDKeychainTokenCache *keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:@"my.group"];
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
    MSIDKeychainTokenCache *keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:@"my.group"];
    MSIDToken *token = [MSIDToken new];
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:@"test_account" service:nil];
    MSIDKeyedArchiverSerializer *keyedArchiverSerializer = [MSIDKeyedArchiverSerializer new];
    NSError *error;
    
    BOOL result = [keychainTokenCache setItem:token withKey:key serializer:keyedArchiverSerializer context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

@end
