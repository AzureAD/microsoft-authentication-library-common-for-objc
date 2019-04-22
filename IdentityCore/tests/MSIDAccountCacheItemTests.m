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
    MSIDAccountCacheItem *cacheItem = [MSIDAccountCacheItem new];
    cacheItem.environment = DEFAULT_TEST_ENVIRONMENT;
    cacheItem.realm = @"contoso.com";
    cacheItem.additionalAccountFields = @{@"test": @"test2",
                                          @"test3": @"test4"};
    cacheItem.localAccountId = @"0000004-0000004-000004";
    cacheItem.givenName = @"First name";
    cacheItem.familyName = @"Last name";
    cacheItem.accountType = MSIDAccountTypeAADV1;
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.username = @"username";
    cacheItem.alternativeAccountId = @"alt";
    cacheItem.name = @"test user";
    
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

- (void)testEqualityForAccountCacheItems_WhenEitherOfTheComparedPropertiesInTheObject_IsNil
{
    MSIDAccountCacheItem *firstAccount = [MSIDAccountCacheItem new];
    firstAccount.environment = DEFAULT_TEST_ENVIRONMENT;
    firstAccount.homeAccountId = @"uid.utid";
    firstAccount.localAccountId = @"0000004-0000004-000004";
    firstAccount.username = @"username";
    firstAccount.givenName = @"First name";
    firstAccount.middleName = @"Middle name";
    firstAccount.familyName = @"Last name";
    firstAccount.accountType = MSIDAccountTypeAADV1;
    firstAccount.homeAccountId = @"uid.utid";
    firstAccount.alternativeAccountId = @"alt";
    firstAccount.name = @"test user";
    firstAccount.realm = @"contoso.com";
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    NSError *error = nil;
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:&error];
    firstAccount.clientInfo = clientInfo;
    firstAccount.alternativeAccountId = @"alternative_clientID";
    firstAccount.additionalAccountFields = @{@"test": @"test2",
                                             @"test3": @"test4"};
    
    MSIDAccountCacheItem *secondAccount = [MSIDAccountCacheItem new];
    secondAccount.accountType = MSIDAccountTypeAADV1;
    secondAccount.environment = DEFAULT_TEST_ENVIRONMENT;
    secondAccount.homeAccountId = @"uid.utid";
    XCTAssertNotEqualObjects(firstAccount, secondAccount);
}

@end
