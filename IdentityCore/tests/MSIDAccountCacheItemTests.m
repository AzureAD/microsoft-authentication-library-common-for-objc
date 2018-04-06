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
#import "MSIDAccountCacheItem.h"
#import "MSIDTestCacheIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDAccountCacheItemTests : XCTestCase

@end

@implementation MSIDAccountCacheItemTests

#pragma mark - Keyed archiver

- (void)testKeyedArchivingAccount_whenAllFieldsSet_shouldReturnSameAccountOnDeserialize
{
    MSIDAccountCacheItem *cacheItem = [MSIDAccountCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.username = DEFAULT_TEST_ID_TOKEN_USERNAME;
    cacheItem.uniqueUserId = DEFAULT_TEST_ID_TOKEN_USERNAME;
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfoString error:nil];
    cacheItem.clientInfo = clientInfo;
    cacheItem.legacyUserIdentifier = @"legacy-user-id";
    cacheItem.firstName = @"First name";
    cacheItem.lastName = @"Last name";
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cacheItem];
    
    XCTAssertNotNil(data);
    
    MSIDAccountCacheItem *newItem = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertNotNil(newItem);
    
    XCTAssertEqualObjects(newItem.authority, [NSURL URLWithString:DEFAULT_TEST_AUTHORITY]);
    XCTAssertEqualObjects(newItem.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertEqualObjects(newItem.clientInfo, clientInfo);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(newItem.uniqueUserId, uniqueUserId);
    XCTAssertEqualObjects(newItem.legacyUserIdentifier, @"legacy-user-id");
    XCTAssertEqualObjects(newItem.firstName, @"First name");
    XCTAssertEqualObjects(newItem.lastName, @"Last name");
}

#pragma mark - JSON serialization

- (void)testJSONDictionary_whenAccount_andAllFieldsSet_shouldReturnJSONDictionary
{
    MSIDAccountCacheItem *cacheItem = [MSIDAccountCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.additionalAccountFields = @{@"test": @"test2",
                                          @"test3": @"test4"};
    cacheItem.legacyUserIdentifier = @"legacy-user-id";
    cacheItem.firstName = @"First name";
    cacheItem.lastName = @"Last name";
    cacheItem.accountType = MSIDAccountTypeAADV1;
    
    NSDictionary *expectedDictionary = @{@"authority": DEFAULT_TEST_AUTHORITY,
                                         @"authority_type": @"AAD",
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"realm": @"common",
                                         @"authority_account_id": @"legacy-user-id",
                                         @"first_name": @"First name",
                                         @"last_name": @"Last name",
                                         @"test": @"test2",
                                         @"test3": @"test4"
                                         };
    
    XCTAssertEqualObjects(cacheItem.jsonDictionary, expectedDictionary);
}

#pragma mark - JSON deserialization

- (void)testInitWithJSONDictionary_whenAccount_andAllFieldsSet_shouldAccountCacheItem
{
    NSDictionary *jsonDictionary = @{@"authority": DEFAULT_TEST_AUTHORITY,
                                     @"authority_type": @"AAD",
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"realm": @"common",
                                     @"authority_account_id": @"legacy-user-id",
                                     @"first_name": @"First name",
                                     @"last_name": @"Last name",
                                     @"test": @"test2",
                                     @"test3": @"test4"
                                     };
    
    NSError *error = nil;
    MSIDAccountCacheItem *cacheItem = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNotNil(cacheItem);
    NSURL *expectedAuthority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    XCTAssertEqualObjects(cacheItem.authority, expectedAuthority);
    XCTAssertEqualObjects(cacheItem.legacyUserIdentifier, @"legacy-user-id");
    XCTAssertEqualObjects(cacheItem.firstName, @"First name");
    XCTAssertEqualObjects(cacheItem.lastName, @"Last name");
}

#pragma mark - Additional fields handling

- (void)testAddAdditionalFields_whenSerializing_shouldCombineFields
{
    MSIDAccountCacheItem *firstAccount = [MSIDAccountCacheItem new];
    firstAccount.additionalAccountFields = @{@"field1": @"value1",
                                             @"field2": @"value2"};
    
    MSIDAccountCacheItem *secondAccount = [MSIDAccountCacheItem new];
    secondAccount.additionalAccountFields = @{@"field1": @"new_value",
                                              @"field3": @"value3"};
    secondAccount.accountType = MSIDAccountTypeAADV1;
    
    [secondAccount updateFieldsFromAccount:firstAccount];
    
    NSDictionary *jsonDictionary = [secondAccount jsonDictionary];
    
    NSDictionary *expectedDictionary = @{@"field1": @"new_value",
                                         @"field2": @"value2",
                                         @"field3": @"value3",
                                         @"authority_type": @"AAD"
                                         };
    
    XCTAssertEqualObjects(jsonDictionary, expectedDictionary);
}

@end
