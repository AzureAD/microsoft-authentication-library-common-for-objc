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
#import "MSIDBrokerOperationGetDefaultAccountResponse.h"
#import "MSIDAccount.h"
#import "MSIDAccountIdentifier.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDClientInfo.h"
#import "MSIDBrokerConstants.h"
#import "MSIDJsonSerializableTypes.h"

@interface MSIDBrokerOperationGetDefaultAccountResponseTests : XCTestCase

@end

@implementation MSIDBrokerOperationGetDefaultAccountResponseTests

#if TARGET_OS_OSX

- (void)setUp {
}

- (void)tearDown {
}

- (void)testInitWithJSONDictionary_whenJsonValid_shouldInitWithJson {
    NSDictionary *json = @{
        @"operation" : @"get_default_account",
        @"success" : @1,
        @"home_account_id" : @"uid.utid",
        @"account_type" : @"MSSTS",
        @"alternative_account_id" : @"AltID",
        @"client_info" : @"eyJrZXkiOiJ2YWx1ZSJ9",
        @"environment" : @"login.microsoftonline.com",
        @"family_name" : @"Last",
        @"given_name" : @"Eric",
        @"local_account_id" : @"local",
        @"middle_name" : @"Middle",
        @"name" : @"Eric Middle Last",
        @"realm" : @"common",
        @"storage_environment" : @"login.windows2.net",
        @"username" : @"username",
    };

    NSError *error;
    MSIDBrokerOperationGetDefaultAccountResponse *response = [[MSIDBrokerOperationGetDefaultAccountResponse alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(error);
    XCTAssertEqual(response.success, YES);
    XCTAssertEqualObjects(response.operation, @"get_default_account");
    
    MSIDAccount *account = response.account;
    XCTAssertNotNil(account);
    XCTAssertEqual(account.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account.accountIdentifier.displayableId, @"username");
    XCTAssertEqualObjects(account.localAccountId, @"local");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.realm, @"common");
    XCTAssertEqualObjects(account.storageEnvironment, @"login.windows2.net");
    XCTAssertEqualObjects(account.username, @"username");
    XCTAssertEqualObjects(account.givenName, @"Eric");
    XCTAssertEqualObjects(account.middleName, @"Middle");
    XCTAssertEqualObjects(account.familyName, @"Last");
    XCTAssertEqualObjects(account.name, @"Eric Middle Last");
    XCTAssertEqualObjects(account.clientInfo.rawClientInfo, [@{@"key" : @"value"} msidBase64UrlJson]);
    XCTAssertEqualObjects(account.alternativeAccountId, @"AltID");
}

- (void)testInitWithJSONDictionary_whenSuccessButAccountInvalid_shouldReturnNil {
    NSDictionary *json = @{
        @"operation" : @"get_default_account",
        @"success" : @1,
        @"account_type" : @"MSSTS",
        // Missing required fields like home_account_id
    };

    NSError *error;
    MSIDBrokerOperationGetDefaultAccountResponse *response = [[MSIDBrokerOperationGetDefaultAccountResponse alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(error);
    XCTAssertNil(response);
}

- (void)testInitWithJSONDictionary_whenNotSuccess_shouldInitWithoutAccount {
    NSDictionary *json = @{
        @"operation" : @"get_default_account",
        @"success" : @0,
        @"error" : @"user_not_found",
        @"error_description" : @"No default account found"
    };

    NSError *error;
    MSIDBrokerOperationGetDefaultAccountResponse *response = [[MSIDBrokerOperationGetDefaultAccountResponse alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(error);
    XCTAssertEqual(response.success, NO);
    XCTAssertNil(response.account);
}

- (void)testJsonDictionary_whenSerialize_shouldGenerateCorrectJson {
    MSIDAccount *account = [MSIDAccount new];
    account.accountType = MSIDAccountTypeMSSTS;
    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"username" homeAccountId:@"uid.utid"];
    account.localAccountId = @"local";
    account.environment = @"login.microsoftonline.com";
    account.realm = @"common";
    account.storageEnvironment = @"login.windows2.net";
    account.username = @"username";
    account.givenName = @"Eric";
    account.middleName = @"Middle";
    account.familyName = @"Last";
    account.name = @"Eric Middle Last";
    NSString *base64String = [@{@"key" : @"value"} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
    account.clientInfo = clientInfo;
    account.alternativeAccountId = @"AltID";
    
    MSIDBrokerOperationGetDefaultAccountResponse *response = [[MSIDBrokerOperationGetDefaultAccountResponse alloc] initWithDeviceInfo:nil];
    response.account = account;
    response.operation = @"get_default_account";
    response.success = YES;
    
    NSDictionary *result = response.jsonDictionary;
    
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result[@"operation"], @"get_default_account");
    XCTAssertEqualObjects(result[@"success"], @"1");
    XCTAssertEqualObjects(result[@"operation_response_type"], MSID_JSON_TYPE_BROKER_OPERATION_GET_DEFAULT_ACCOUNT_RESPONSE);
    XCTAssertEqualObjects(result[@"home_account_id"], @"uid.utid");
    XCTAssertEqualObjects(result[@"account_type"], @"MSSTS");
    XCTAssertEqualObjects(result[@"username"], @"username");
    XCTAssertEqualObjects(result[@"environment"], @"login.microsoftonline.com");
    XCTAssertEqualObjects(result[@"realm"], @"common");
}

#endif

@end
