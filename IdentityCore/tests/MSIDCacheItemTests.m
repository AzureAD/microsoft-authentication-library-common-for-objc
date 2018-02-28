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
#import "MSIDCacheItem.h"
#import "MSIDTestCacheIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDCacheItemTests : XCTestCase

@end

@implementation MSIDCacheItemTests

#pragma mark - Keyed archiver

- (void)testKeyedArchivingToken_whenAllFieldsSet_shouldReturnSameTokenOnDeserialize
{
    MSIDCacheItem *cacheItem = [MSIDCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.username = DEFAULT_TEST_ID_TOKEN_USERNAME;
    cacheItem.uniqueUserId = DEFAULT_TEST_ID_TOKEN_USERNAME;
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfoString error:nil];
    cacheItem.clientInfo = clientInfo;
    cacheItem.additionalInfo = @{@"test": @"2"};
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cacheItem];
    
    XCTAssertNotNil(data);
    
    MSIDCacheItem *newItem = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertNotNil(newItem);
    
    XCTAssertEqualObjects(newItem.authority, [NSURL URLWithString:DEFAULT_TEST_AUTHORITY]);
    XCTAssertEqualObjects(newItem.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertEqualObjects(newItem.additionalInfo, @{@"test": @"2"});
    XCTAssertEqualObjects(newItem.clientInfo, clientInfo);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(newItem.uniqueUserId, uniqueUserId);
}

- (void)testKeyedArchivingToken_whenNoClientInfo_shouldReturnTokenWithoutClientInfoUniqueId
{
    MSIDCacheItem *cacheItem = [MSIDCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.uniqueUserId = @"unique_id";
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cacheItem];
    
    XCTAssertNotNil(data);
    
    MSIDCacheItem *newItem = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertNotNil(newItem);
    
    XCTAssertEqualObjects(newItem.authority, [NSURL URLWithString:DEFAULT_TEST_AUTHORITY]);
    XCTAssertNil(newItem.clientInfo);
    XCTAssertNil(newItem.uniqueUserId);
}

#pragma mark - JSON serialization

- (void)testJSONDictionary_whenAllFieldsSet_shouldReturnJSONDictionary
{
    MSIDCacheItem *cacheItem = [MSIDCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.username = DEFAULT_TEST_ID_TOKEN_USERNAME;
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfoString error:nil];
    cacheItem.clientInfo = clientInfo;
    cacheItem.additionalInfo = @{@"test": @"2"};
    
    NSDictionary *jsonDict = [cacheItem jsonDictionary];
    
    XCTAssertNotNil(jsonDict);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    
    NSDictionary *expectedDict = @{@"unique_id" : uniqueUserId,
                                   @"environment" : @"login.microsoftonline.com",
                                   @"client_info": clientInfoString,
                                   @"additional_info": @{@"test": @"2"},
                                   @"username": DEFAULT_TEST_ID_TOKEN_USERNAME,
                                   @"authority":DEFAULT_TEST_AUTHORITY
                                   };
    
    XCTAssertEqualObjects(jsonDict, expectedDict);
}

- (void)testJSONDictionary_whenBothUniqueIdAndClientInfoSet_shouldUseClientInfo
{
    MSIDCacheItem *cacheItem = [MSIDCacheItem new];
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfoString error:nil];
    cacheItem.clientInfo = clientInfo;
    cacheItem.uniqueUserId = @"unique_id";
    
    NSDictionary *jsonDict = [cacheItem jsonDictionary];
    
    XCTAssertNotNil(jsonDict);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    
    NSDictionary *expectedDict = @{@"unique_id" : uniqueUserId,
                                   @"client_info": clientInfoString,
                                   };
    
    XCTAssertEqualObjects(jsonDict, expectedDict);
}

- (void)testJSONDictionary_whenOnlyUniqueIdIsSet_shouldSaveUniqueId
{
    MSIDCacheItem *cacheItem = [MSIDCacheItem new];
    cacheItem.uniqueUserId = @"unique_id";
    
    NSDictionary *jsonDict = [cacheItem jsonDictionary];
    XCTAssertNotNil(jsonDict);
    
    NSDictionary *expectedDict = @{@"unique_id" : @"unique_id"};
    XCTAssertEqualObjects(jsonDict, expectedDict);
}

- (void)testJSONDictionary_whenOnlyClientInfoSet_shouldUseClientInfo
{
    MSIDCacheItem *cacheItem = [MSIDCacheItem new];
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfoString error:nil];
    cacheItem.clientInfo = clientInfo;
    
    NSDictionary *jsonDict = [cacheItem jsonDictionary];
    
    XCTAssertNotNil(jsonDict);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    
    NSDictionary *expectedDict = @{@"unique_id" : uniqueUserId,
                                   @"client_info": clientInfoString,
                                   };
    
    XCTAssertEqualObjects(jsonDict, expectedDict);
}

#pragma mark - JSON deserialization

- (void)testInitWithJSONDictionary_whenAllFieldsSet_shouldReturnCacheItem
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfoString error:nil];
    
    NSDictionary *jsonDict = @{@"unique_id" : @"user_unique_id",
                               @"environment" : @"login.microsoftonline.com",
                               @"client_info": clientInfoString,
                               @"additional_info": @{@"test": @"2"},
                               @"username": DEFAULT_TEST_ID_TOKEN_USERNAME,
                               @"authority":DEFAULT_TEST_AUTHORITY
                               };
    
    NSError *error = nil;
    MSIDCacheItem *newItem = [[MSIDCacheItem alloc] initWithJSONDictionary:jsonDict error:nil];
    
    XCTAssertNil(error);
    XCTAssertNotNil(newItem);
    
    XCTAssertEqualObjects(newItem.authority, [NSURL URLWithString:DEFAULT_TEST_AUTHORITY]);
    XCTAssertEqualObjects(newItem.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertEqualObjects(newItem.additionalInfo, @{@"test": @"2"});
    XCTAssertEqualObjects(newItem.clientInfo, clientInfo);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(newItem.uniqueUserId, uniqueUserId);
}

- (void)testInitWithJSONDictionary_whenNoClientInfo_shouldReturnUniqueUserId
{
    NSDictionary *jsonDict = @{@"unique_id" : @"user_unique_id"};
    
    NSError *error = nil;
    MSIDCacheItem *newItem = [[MSIDCacheItem alloc] initWithJSONDictionary:jsonDict error:nil];
    
    XCTAssertNil(error);
    XCTAssertNotNil(newItem);
    XCTAssertEqualObjects(newItem.uniqueUserId, @"user_unique_id");
    XCTAssertNil(newItem.clientInfo);
}

- (void)testInitWithJSONDictionary_whenNoAuthorityNoTenant_shouldReturnCommonAuthority
{
    NSDictionary *jsonDict = @{@"environment" : @"login.microsoftonline.com"};
    
    NSError *error = nil;
    MSIDCacheItem *newItem = [[MSIDCacheItem alloc] initWithJSONDictionary:jsonDict error:nil];
    
    XCTAssertNil(error);
    XCTAssertNotNil(newItem);
    
    XCTAssertEqualObjects(newItem.authority, [NSURL URLWithString:@"https://login.microsoftonline.com/common"]);
}

- (void)testInitWithJSONDictionary_whenNoAuthorityAndTenant_shouldReturnTenantedAuthority
{
    NSDictionary *jsonDict = @{@"environment" : @"login.microsoftonline.com",
                               @"realm" : @"contoso.com"
                               };
    
    NSError *error = nil;
    MSIDCacheItem *newItem = [[MSIDCacheItem alloc] initWithJSONDictionary:jsonDict error:nil];
    
    XCTAssertNil(error);
    XCTAssertNotNil(newItem);
    
    XCTAssertEqualObjects(newItem.authority, [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"]);
}

@end
