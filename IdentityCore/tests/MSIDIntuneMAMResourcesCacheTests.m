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
#import "MSIDIntuneMAMResourcesCache.h"
#import "MSIDIntuneInMemoryCacheDataSource.h"
#import "MSIDAuthorityMock.h"
#import "MSIDAuthority+Internal.h"

@interface MSIDIntuneMAMResourcesCacheTests : XCTestCase

@property (nonatomic) MSIDIntuneMAMResourcesCache *cache;
@property (nonatomic) MSIDCache *inMemoryStorage;
@property (nonatomic) MSIDAuthorityMock *authority;

@end

@implementation MSIDIntuneMAMResourcesCacheTests

- (void)setUp
{
    self.inMemoryStorage = [MSIDCache new];
    __auto_type dictionary = @{
                               @"login.microsoftonline.com": @"https://www.microsoft.com/intune",
                               @"login.microsoftonline.de": @"https://www.microsoft.com/intune-de",
                               @"login.windows.net": @"https://www.microsoft.com/windowsIntune"
                               };
    [self.inMemoryStorage setObject:dictionary forKey:@"intune_mam_resource_V1"];
    
    __auto_type dataSource = [[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:self.inMemoryStorage];
    self.cache = [[MSIDIntuneMAMResourcesCache alloc] initWithDataSource:dataSource];
    
    __auto_type authorityUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    self.authority = [[MSIDAuthorityMock alloc] initWithURL:authorityUrl context:nil error:nil];
    self.authority.environmentAliases = @[@"login.microsoftonline.com"];
}

- (void)tearDown
{
}

#pragma mark - resourceForAuthority

- (void)testResourceForAuthority_whenCacheEmpty_shoudlReturnNil
{
    [self.inMemoryStorage removeAllObjects];
    
    NSError *error;
    __auto_type resource = [self.cache resourceForAuthority:self.authority context:nil error:&error];
    
    XCTAssertNil(resource);
    XCTAssertNil(error);
}

- (void)testResourceForAuthority_whenAuthorityIsNil_shoudlReturnNil
{
    MSIDAuthority *authority = nil;
    [self.inMemoryStorage removeAllObjects];
    
    NSError *error;
    __auto_type resource = [self.cache resourceForAuthority:authority context:nil error:&error];
    
    XCTAssertNil(resource);
    XCTAssertNil(error);
}

- (void)testResourceForAuthority_whenNoResourceForAuthorityInCache_shoudlReturnNil
{
    __auto_type authorityUrl = [NSURL URLWithString:@"https://example.com/common"];
    __auto_type authority = [[MSIDAuthorityMock alloc] initWithURL:authorityUrl context:nil error:nil];
    authority.environmentAliases = @[@"example.com"];
    
    NSError *error;
    __auto_type resource = [self.cache resourceForAuthority:authority context:nil error:&error];
    
    XCTAssertNil(resource);
    XCTAssertNil(error);
}

- (void)testResourceForAuthority_whenResourceInCache_shoudlReturnResource
{
    NSError *error;
    __auto_type resource = [self.cache resourceForAuthority:self.authority context:nil error:&error];
    
    XCTAssertEqualObjects(resource, @"https://www.microsoft.com/intune");
    XCTAssertNil(error);
}

- (void)testResourceForAuthority_whenResourceAliasInCache_shoudlReturnResource
{
    __auto_type authorityUrl = [NSURL URLWithString:@"https://login.microsoftonlineAlias.com/common"];
    __auto_type authority = [[MSIDAuthorityMock alloc] initWithURL:authorityUrl context:nil error:nil];
    authority.environmentAliases = @[@"login.microsoftonline.com"];
    
    NSError *error;
    __auto_type resource = [self.cache resourceForAuthority:authority context:nil error:&error];
    
    XCTAssertEqualObjects(resource, @"https://www.microsoft.com/intune");
    XCTAssertNil(error);
    XCTAssertEqual(authority.defaultCacheEnvironmentAliasesInvokedCount, 1);
}

#pragma mark - setResourcesJsonDictionary

- (void)testSetResourcesJsonDictionary_whenJsonValid_shouldSetItInCache
{
    __auto_type jsonDicionary = @{@"key": @"value"};
    
    NSError *error;
    [self.cache setResourcesJsonDictionary:jsonDicionary context:nil error:&error];
    
    NSDictionary *jsonDicionaryResult = [self.inMemoryStorage objectForKey:@"intune_mam_resource_V1"];
    XCTAssertEqualObjects(jsonDicionary, jsonDicionaryResult);
    XCTAssertNil(error);
}

- (void)testSetResourcesJsonDictionary_whenJsonInvalidValid_shouldReturnError
{
    __auto_type jsonDicionary = @{@"key": @1};
    [self.inMemoryStorage removeAllObjects];
    
    NSError *error;
    [self.cache setResourcesJsonDictionary:jsonDicionary context:nil error:&error];
    
    NSDictionary *jsonDicionaryResult = [self.inMemoryStorage objectForKey:@"intune_mam_resource_V1"];
    XCTAssertNil(jsonDicionaryResult);
    XCTAssertNotNil(error);
}

#pragma mark - resourcesJsonDictionary

- (void)testResourcesJsonDictionary_whenJsonValidAndInCache_shouldReturnIt
{
    __auto_type jsonDicionary = @{@"key": @"value"};
    [self.inMemoryStorage setObject:jsonDicionary forKey:@"intune_mam_resource_V1"];
    
    NSError *error;
    NSDictionary *jsonDicionaryResult = [self.cache resourcesJsonDictionaryWithContext:nil error:&error];
    XCTAssertEqualObjects(jsonDicionary, jsonDicionaryResult);
    XCTAssertNil(error);
}

- (void)testResourcesJsonDictionary_whenJsonInvalidValidAndInCache_shouldReturnNilAndError
{
    __auto_type jsonDicionary = @{@"key": @1};
    [self.inMemoryStorage setObject:jsonDicionary forKey:@"intune_mam_resource_V1"];
    
    NSError *error;
    NSDictionary *jsonDicionaryResult = [self.cache resourcesJsonDictionaryWithContext:nil error:&error];
    XCTAssertNil(jsonDicionaryResult);
    XCTAssertNotNil(error);
}

#pragma mark - clear

- (void)testClear_whenCacheIsNotEmpty_shouldDeleteOnlyIntuneKeys
{
    [self.inMemoryStorage setObject:@{@"key2": @"value2"} forKey:@"intune_mam_resource_V1"];
    __auto_type jsonDicionary = @{@"key": @"value"};
    [self.inMemoryStorage setObject:jsonDicionary forKey:@"custom_key"];
    
    [self.cache clear];
    
    XCTAssertEqual(self.inMemoryStorage.count, 1);
    XCTAssertEqualObjects(jsonDicionary, [self.inMemoryStorage objectForKey:@"custom_key"]);
}

#pragma mark - Invalid data source

- (void)testResourceForAuthority_whenCacheContainsNotJsonObject_shoudlReturnNilAndError
{
    [self.inMemoryStorage setObject:@"not a json dictionary" forKey:@"intune_mam_resource_V1"];
    
    NSError *error;
    __auto_type resource = [self.cache resourceForAuthority:self.authority context:nil error:&error];
    
    XCTAssertNil(resource);
    XCTAssertNotNil(error);
}

- (void)testResourceForAuthority_whenCacheContainsJsonButKeysAreNotString_shoudlReturnNilAndError
{
    [self.inMemoryStorage setObject:@{@1: @"some string"} forKey:@"intune_mam_resource_V1"];
    
    NSError *error;
    __auto_type resource = [self.cache resourceForAuthority:self.authority context:nil error:&error];
    
    XCTAssertNil(resource);
    XCTAssertNotNil(error);
}

- (void)testResourceForAuthority_whenCacheContainsJsonButValuesAreNotString_shoudlReturnNilAndError
{
    [self.inMemoryStorage setObject:@{@"some string": @1} forKey:@"intune_mam_resource_V1"];
    
    NSError *error;
    __auto_type resource = [self.cache resourceForAuthority:self.authority context:nil error:&error];
    
    XCTAssertNil(resource);
    XCTAssertNotNil(error);
}

@end
