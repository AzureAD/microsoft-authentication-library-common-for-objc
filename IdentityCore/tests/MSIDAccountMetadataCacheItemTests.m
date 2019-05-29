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
#import "MSIDAccountMetadataCacheItem.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDAccountMetadataCacheItemTests : XCTestCase

@end

@implementation MSIDAccountMetadataCacheItemTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}


- (void)testJSONDictionary_whenAllFieldsSet_shouldReturnJSONDictionaryWithAccountKey
{
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    
    NSError *error;
    
    XCTAssertTrue([cacheItem setCachedURL:[NSURL URLWithString:@"https://contoso.com"]
                            forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"] error:&error]);
    XCTAssertNil(error);
    
    __auto_type *expected = @{ @"account_metadata" : @{ @"URLMap" : @{ @"https://testAuthority.com" : @"https://contoso.com"} },
                               @"client_id" : @"clientId",
                               @"home_account_id" : @"homeAccountId" };
    
    XCTAssertEqualObjects(cacheItem.jsonDictionary, expected);
}

#pragma mark - JSON deserialization

- (void)testInitWithJSONDictionary_whenAllJSONFieldsSet_shouldAccountMetadataItemWithNilAuthorityMapping
{
    NSDictionary *jsonDictionary = @{ @"client_id" : @"clientId",
                                      @"home_account_id" : @"homeAccountId" };

    NSError *error = nil;
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"homeAccountId");
    XCTAssertEqualObjects(cacheItem.clientId, @"clientId");
    XCTAssertNil([cacheItem cachedURL:[NSURL URLWithString:@"https://testAuthority.com"]]);
}

#pragma mark - Authority map caching

- (void)testSetCachedURL_whenCacheURLAndRequestURLPresent_shouldSaveMapping
{
    NSError *error = nil;
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertTrue([cacheItem setCachedURL:[NSURL URLWithString:@"https://contoso.com"]
                            forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"] error:&error]);
    XCTAssertEqualObjects(cacheItem->_internalMap,
                          @{ @"URLMap" : @{ @"https://testAuthority.com" : @"https://contoso.com"}});
}

- (void)testSetCachedURL_whenCacheURLAndRequestURLPresentWhenRecordAlreadyExists_shouldOverwriteAndSaveMapping
{
    NSError *error = nil;
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertTrue([cacheItem setCachedURL:[NSURL URLWithString:@"https://contoso.com"]
                            forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"] error:&error]);
    XCTAssertTrue([cacheItem setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                            forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"] error:&error]);
    XCTAssertEqualObjects(cacheItem->_internalMap,
                          @{ @"URLMap" : @{ @"https://testAuthority.com" : @"https://contoso2.com"}});
}

- (void)testCachedURL_withCachedRequestURLNotMapped_shouldReturnNil
{
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertNil([cacheItem cachedURL:[NSURL URLWithString:@"https://contoso.com"]]);
}



@end
