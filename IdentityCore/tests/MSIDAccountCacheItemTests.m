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
#import "MSIDTestIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDClientInfo.h"

@interface MSIDAccountCacheItemTests : XCTestCase

@end

@implementation MSIDAccountCacheItemTests

#pragma mark - JSON serialization

- (void)testJSONDictionary_whenAccount_andAllFieldsSet_shouldReturnJSONDictionary
{
    NSDictionary *expectedDictionary = @{@"authority_type": @"AAD",
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"realm": @"contoso.com",
                                         @"local_account_id": @"0000004-0000004-000004",
                                         @"given_name": @"First name",
                                         @"family_name": @"Last name",
                                         @"test": @"test2",
                                         @"test3": @"test4",
                                         @"home_account_id": @"uid.utid",
                                         @"username": @"username",
                                         @"alternative_account_id": @"alt",
                                         @"name": @"test user"
                                         };
    MSIDAccountCacheItem *cacheItem = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:expectedDictionary error:nil];
    XCTAssertEqualObjects(cacheItem.jsonDictionary, expectedDictionary);
}

#pragma mark - JSON deserialization

- (void)testInitWithJSONDictionary_whenAccount_andAllFieldsSet_shouldAccountCacheItem
{
    NSDictionary *jsonDictionary = @{@"authority_type": @"AAD",
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"realm": @"contoso.com",
                                     @"local_account_id": @"0000004-0000004-000004",
                                     @"given_name": @"First name",
                                     @"family_name": @"Last name",
                                     @"test": @"test2",
                                     @"test3": @"test4",
                                     @"home_account_id": @"uid.utid",
                                     @"username": @"username",
                                     @"alternative_account_id": @"alt",
                                     @"name": @"test user"
                                     };
    
    NSError *error = nil;
    MSIDAccountCacheItem *cacheItem = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.environment, DEFAULT_TEST_ENVIRONMENT);
    XCTAssertEqualObjects(cacheItem.realm, @"contoso.com");
    XCTAssertEqual(cacheItem.accountType, MSIDAccountTypeAADV1);
    XCTAssertEqualObjects(cacheItem.localAccountId, @"0000004-0000004-000004");
    XCTAssertEqualObjects(cacheItem.givenName, @"First name");
    XCTAssertEqualObjects(cacheItem.familyName, @"Last name");
    XCTAssertEqualObjects(cacheItem.name, @"test user");
    XCTAssertEqualObjects(cacheItem.alternativeAccountId, @"alt");
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(cacheItem.username, @"username");
}

#pragma mark - Additional fields handling

- (void)testAddAdditionalFields_whenSerializing_shouldCombineFields
{
    NSError *error = nil;
    NSDictionary *accountDictionary = @{@"authority_type": @"AAD",
                                        @"environment": DEFAULT_TEST_ENVIRONMENT,
                                        @"realm": @"contoso.com",
                                        @"local_account_id": @"0000004-0000004-000004",
                                        @"given_name": @"First name",
                                        @"family_name": @"Last name",
                                        @"home_account_id": @"uid.utid",
                                        @"username": @"username",
                                        @"alternative_account_id": @"alt",
                                        @"name": @"test user"
                                        };
    NSMutableDictionary *firstDictionary = [accountDictionary mutableCopy];
    [firstDictionary addEntriesFromDictionary:@{@"field1": @"value1",
                                                @"field2": @"value2"}];
    MSIDAccountCacheItem *firstAccount = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:firstDictionary error:&error];
    XCTAssertNil(error);
    
    NSMutableDictionary *secondDictionary = [firstAccount.jsonDictionary mutableCopy];
    [secondDictionary addEntriesFromDictionary:@{@"field1": @"new_value",
                                                 @"field3": @"value3"}];
    MSIDAccountCacheItem *secondAccount = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:secondDictionary error:&error];
    XCTAssertNil(error);
    
    NSDictionary *jsonDictionary = [secondAccount jsonDictionary];
    
    NSMutableDictionary *expectedDictionary = [accountDictionary mutableCopy];
    [expectedDictionary addEntriesFromDictionary:@{@"field1": @"new_value",
                                                   @"field2": @"value2",
                                                   @"field3": @"value3"
                                                   }];
    
    XCTAssertEqualObjects(jsonDictionary, expectedDictionary);
}

- (void)testEqualityForAccountCacheItems_WhenEitherOfTheComparedPropertiesInTheObject_IsNil
{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    NSError *error = nil;
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:&error];
    
    NSDictionary *firstDictionary = @{@"authority_type": @"AAD",
                                      @"environment": DEFAULT_TEST_ENVIRONMENT,
                                      @"realm": @"contoso.com",
                                      @"local_account_id": @"0000004-0000004-000004",
                                      @"given_name": @"First name",
                                      @"family_name": @"Last name",
                                      @"home_account_id": @"uid.utid",
                                      @"username": @"username",
                                      @"alternative_account_id": @"alternative_clientID",
                                      @"name": @"test user",
                                      @"client_info": clientInfo.rawClientInfo,
                                      @"test": @"test2",
                                      @"test3": @"test4"
                                      };
    MSIDAccountCacheItem *firstAccount = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:firstDictionary error:&error];
    XCTAssertNil(error);
    
    NSDictionary* secondDictionary = @{@"authority_type": @"AAD",
                                       @"environment": DEFAULT_TEST_ENVIRONMENT,
                                       @"realm": @"contoso.com",
                                       @"home_account_id": @"uid.utid"
                                       };
    MSIDAccountCacheItem *secondAccount = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:secondDictionary error:&error];
    XCTAssertNil(error);
    XCTAssertNotEqualObjects(firstAccount, secondAccount);
}

@end
