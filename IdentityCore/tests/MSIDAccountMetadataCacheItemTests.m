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
                            forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"]
                            instanceAware:NO
                                    error:&error]);
    XCTAssertNil(error);

    XCTAssertTrue([cacheItem setCachedURL:[NSURL URLWithString:@"https://contoso3.com"]
                            forRequestURL:[NSURL URLWithString:@"https://testAuthority3.com"]
                            instanceAware:YES
                                    error:&error]);
    XCTAssertNil(error);

    XCTAssertTrue([cacheItem setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                            forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                            instanceAware:NO
                                    error:&error]);
    XCTAssertNil(error);
    
    __auto_type *expected = @{ @"account_metadata" : @{ @"URLMap-" : @{ @"https://testAuthority.com" : @"https://contoso.com", @"https://testAuthority2.com" : @"https://contoso2.com"}, @"URLMap-instance_aware=YES" :  @{ @"https://testAuthority3.com" : @"https://contoso3.com"} },
                               @"client_id" : @"clientId",
                               @"home_account_id" : @"homeAccountId" };
    
    XCTAssertEqualObjects(cacheItem.jsonDictionary, expected);
}

#pragma mark - JSON deserialization

- (void)testInitWithJSONDictionary_whenAllJSONFieldsSet_shouldHaveCorrectItem
{
    NSDictionary *jsonDictionary = @{ @"client_id" : @"clientId",
                                      @"home_account_id" : @"homeAccountId" };

    NSError *error = nil;
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"homeAccountId");
    XCTAssertEqualObjects(cacheItem.clientId, @"clientId");
    XCTAssertNil([cacheItem cachedURL:[NSURL URLWithString:@"https://testAuthority.com"] instanceAware:NO]);
}

- (void)testInitWithJSONDictionary_whenEmptyAccountMetadata_shouldReturnNilItem
{
    NSDictionary *jsonDictionary = @{ @"client_id" : @"clientId",
                                      @"home_account_id" : @"homeAccountId",
                                      @"account_metadata" : @{}
                                      };
    
    NSError *error = nil;
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"homeAccountId");
    XCTAssertEqualObjects(cacheItem.clientId, @"clientId");
    XCTAssertNil([cacheItem cachedURL:[NSURL URLWithString:@"https://testAuthority.com"] instanceAware:NO]);
}

- (void)testInitWithJSONDictionary_whenAccountMetadataAvailable_shouldReturnCorrectItem
{
    NSDictionary *jsonDictionary = @{ @"client_id" : @"clientId",
                                      @"home_account_id" : @"homeAccountId",
                                      @"account_metadata" : @{ @"URLMap-" : @{
                                                                       @"https://testAuthority1.com" : @"https://contoso1.com",
                                                                       @"https://testAuthority2.com" : @"https://contoso2.com"},
                                                               @"URLMap-instance_aware=YES" : @{
                                                                       @"https://testAuthority3.com" : @"https://contoso3.com"}
                                                               }
                                      };
    
    NSError *error = nil;
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"homeAccountId");
    XCTAssertEqualObjects(cacheItem.clientId, @"clientId");
    //not available because of url
    XCTAssertNil([cacheItem cachedURL:[NSURL URLWithString:@"https://notexist.com"] instanceAware:NO]);
    //not available because of instance aware
    XCTAssertNil([cacheItem cachedURL:[NSURL URLWithString:@"https://testAuthority1.com"] instanceAware:YES]);
    XCTAssertNil([cacheItem cachedURL:[NSURL URLWithString:@"https://testAuthority3.com"] instanceAware:NO]);
    //available
    XCTAssertEqualObjects([cacheItem cachedURL:[NSURL URLWithString:@"https://testAuthority1.com"] instanceAware:NO].absoluteString, @"https://contoso1.com");
    XCTAssertEqualObjects([cacheItem cachedURL:[NSURL URLWithString:@"https://testAuthority3.com"] instanceAware:YES].absoluteString, @"https://contoso3.com");
}

#pragma mark - Authority map caching

- (void)testSetCachedURL_whenCacheURLAndRequestURLPresent_shouldSaveMapping
{
    NSError *error = nil;
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertTrue([cacheItem setCachedURL:[NSURL URLWithString:@"https://contoso1.com"]
                            forRequestURL:[NSURL URLWithString:@"https://testAuthority1.com"]
                            instanceAware:NO
                                    error:&error]);
    XCTAssertTrue([cacheItem setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                            forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                            instanceAware:YES
                                    error:&error]);
    NSDictionary *expectedMap = @{ @"URLMap-" : @{ @"https://testAuthority1.com" : @"https://contoso1.com"},
                                   @"URLMap-instance_aware=YES" : @{ @"https://testAuthority2.com" : @"https://contoso2.com"}
                                   };
    XCTAssertEqualObjects(cacheItem.internalMap, expectedMap);
}

- (void)testSetCachedURL_whenCacheURLAndRequestURLPresentWhenRecordAlreadyExists_shouldOverwriteAndSaveMapping
{
    NSError *error = nil;
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertTrue([cacheItem setCachedURL:[NSURL URLWithString:@"https://contoso.com"]
                            forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"]
                            instanceAware:NO
                                    error:&error]);
    XCTAssertTrue([cacheItem setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                            forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                            instanceAware:YES
                                    error:&error]);
    XCTAssertTrue([cacheItem setCachedURL:[NSURL URLWithString:@"https://contoso3.com"]
                            forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"]
                            instanceAware:NO
                                    error:&error]);
    
    NSDictionary *expectedMap = @{ @"URLMap-" : @{ @"https://testAuthority.com" : @"https://contoso3.com"},
                                   @"URLMap-instance_aware=YES" : @{ @"https://testAuthority2.com" : @"https://contoso2.com"}
                                   };
    XCTAssertEqualObjects(cacheItem.internalMap, expectedMap);
}

- (void)testCachedURL_withCachedRequestURLNotMapped_shouldReturnNil
{
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertNil([cacheItem cachedURL:[NSURL URLWithString:@"https://contoso.com"] instanceAware:NO]);
}

- (void)testAccountMetadataCopy_withOriginalObjectChanged_shouldNotChangeCopiedObject
{
    NSError *error = nil;
    MSIDAccountMetadataCacheItem *item1 = [[MSIDAccountMetadataCacheItem alloc] initWithHomeAccountId:@"home_account_id" clientId:@"clientId"];
    
    XCTAssertTrue([item1 setCachedURL:[NSURL URLWithString:@"https://contoso1.com"]
                        forRequestURL:[NSURL URLWithString:@"https://testAuthority1.com"]
                        instanceAware:NO
                                error:&error]);
    XCTAssertTrue([item1 setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                        forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                        instanceAware:YES
                                error:&error]);
    
    MSIDAccountMetadataCacheItem *item2 = [item1 copy];
    
    XCTAssertTrue([item1 setCachedURL:[NSURL URLWithString:@"https://contoso3.com"]
                        forRequestURL:[NSURL URLWithString:@"https://testAuthority1.com"]
                        instanceAware:NO
                                error:&error]);
    
    NSURL *cacheURLForItem1 = [item1 cachedURL:[NSURL URLWithString:@"https://testAuthority1.com"] instanceAware:NO];
    XCTAssertNotNil(cacheURLForItem1);
    
    NSURL *cacheURLForItem2 = [item2 cachedURL:[NSURL URLWithString:@"https://testAuthority1.com"] instanceAware:NO];
    XCTAssertNotNil(cacheURLForItem2);
    
    XCTAssertNotEqualObjects(cacheURLForItem1, cacheURLForItem2);
}

- (void)testAccountMetadataIsEqual_withOriginalObjectChanged_shouldNotBeEqual
{
    NSError *error = nil;
    MSIDAccountMetadataCacheItem *item1 = [[MSIDAccountMetadataCacheItem alloc] initWithHomeAccountId:@"home_account_id" clientId:@"clientId"];
    
    XCTAssertTrue([item1 setCachedURL:[NSURL URLWithString:@"https://contoso1.com"]
                        forRequestURL:[NSURL URLWithString:@"https://testAuthority1.com"]
                        instanceAware:NO
                                error:&error]);
    XCTAssertTrue([item1 setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                        forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                        instanceAware:YES
                                error:&error]);
    
    MSIDAccountMetadataCacheItem *item2 = [item1 copy];
    
    XCTAssertEqualObjects(item1, item2);
    
    XCTAssertTrue([item1 setCachedURL:[NSURL URLWithString:@"https://contoso3.com"]
                        forRequestURL:[NSURL URLWithString:@"https://testAuthority1.com"]
                        instanceAware:NO
                                error:&error]);
    
    XCTAssertNotEqualObjects(item1, item2);
}

@end
