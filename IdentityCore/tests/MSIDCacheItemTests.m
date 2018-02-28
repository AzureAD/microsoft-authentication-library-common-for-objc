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

- (void)test_whenKeyedArchivingToken_shouldReturnSameTokenOnDeserialize
{
    MSIDCacheItem *cacheItem = [MSIDCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.environment = DEFAULT_TEST_ENVIRONMENT;
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
    XCTAssertEqualObjects(newItem.environment, DEFAULT_TEST_ENVIRONMENT);
    XCTAssertEqualObjects(newItem.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertEqualObjects(newItem.additionalInfo, @{@"test": @"2"});
    XCTAssertEqualObjects(newItem.clientInfo, clientInfo);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(newItem.uniqueUserId, uniqueUserId);
}

- (void)testJSONDictionary_whenSerializing_shouldReturnJSONDictionary
{
    MSIDCacheItem *cacheItem = [MSIDCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.environment = DEFAULT_TEST_ENVIRONMENT;
    cacheItem.username = DEFAULT_TEST_ID_TOKEN_USERNAME;
    cacheItem.uniqueUserId = @"user_unique_id";
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfoString error:nil];
    cacheItem.clientInfo = clientInfo;
    cacheItem.additionalInfo = @{@"test": @"2"};
    
    NSDictionary *jsonDict = [cacheItem jsonDictionary];
    
    XCTAssertNotNil(jsonDict);
    
    NSDictionary *expectedDict = @{@"unique_id" : @"user_unique_id",
                                   @"environment" : @"login.microsoftonline.com",
                                   @"client_info": clientInfoString,
                                   @"additional_info": @{@"test": @"2"},
                                   @"username": DEFAULT_TEST_ID_TOKEN_USERNAME,
                                   @"authority":DEFAULT_TEST_AUTHORITY
                                   };
    
    XCTAssertEqualObjects(jsonDict, expectedDict);
}

- (void)testJSONDictionary_whenDeSerializing_shouldHaveAllFieldsSet
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
    XCTAssertEqualObjects(newItem.environment, DEFAULT_TEST_ENVIRONMENT);
    XCTAssertEqualObjects(newItem.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertEqualObjects(newItem.additionalInfo, @{@"test": @"2"});
    XCTAssertEqualObjects(newItem.clientInfo, clientInfo);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(newItem.uniqueUserId, uniqueUserId);
}

@end
