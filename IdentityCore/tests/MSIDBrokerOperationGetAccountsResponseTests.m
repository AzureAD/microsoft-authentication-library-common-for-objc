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
#import "MSIDBrokerOperationGetAccountsResponse.h"
#import "MSIDAccount.h"
#import "MSIDAccountIdentifier.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDClientInfo.h"
#import "MSIDBrokerConstants.h"
#import "MSIDDeviceInfo.h"

@interface MSIDBrokerOperationGetAccountsResponseTests : XCTestCase

@end

@implementation MSIDBrokerOperationGetAccountsResponseTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testInitWithJSONDictionary_whenJsonValid_shouldInitWithJson {
    
    NSArray *inputAccounts = @[
        @{
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
        },
        @{
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
            @"realm" : @"tenant",
            @"storage_environment" : @"login.windows2.net",
            @"username" : @"username",
        }
    ];
    
    NSString *accountsJsonString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:inputAccounts options:0 error:nil] encoding:NSUTF8StringEncoding];
    
    NSDictionary *json = @{
        @"operation" : @"get_accounts",
        @"success" : @1,
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"accounts" : accountsJsonString
    };

    NSError *error;
    MSIDBrokerOperationGetAccountsResponse *response = [[MSIDBrokerOperationGetAccountsResponse alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(error);
    XCTAssertEqual(response.success, YES);
    XCTAssertEqualObjects(response.operation, @"get_accounts");
    XCTAssertEqual(response.deviceInfo.deviceMode, MSIDDeviceModeShared);
    XCTAssertEqual(response.deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(response.deviceInfo.brokerVersion, @"1.2.3");
    NSArray *accounts = response.accounts;
    XCTAssertEqual(accounts.count, 2);
    MSIDAccount *account1 = accounts[0];
    MSIDAccount *account2 = accounts[1];
    
    XCTAssertEqual(account1.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account1.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account1.accountIdentifier.displayableId, @"username");
    XCTAssertEqualObjects(account1.localAccountId, @"local");
    XCTAssertEqualObjects(account1.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account1.realm, @"common");
    XCTAssertEqualObjects(account1.storageEnvironment, @"login.windows2.net");
    XCTAssertEqualObjects(account1.username, @"username");
    XCTAssertEqualObjects(account1.givenName, @"Eric");
    XCTAssertEqualObjects(account1.middleName, @"Middle");
    XCTAssertEqualObjects(account1.familyName, @"Last");
    XCTAssertEqualObjects(account1.name, @"Eric Middle Last");
    XCTAssertEqualObjects(account1.clientInfo.rawClientInfo, [@{@"key" : @"value"} msidBase64UrlJson]);
    XCTAssertEqualObjects(account1.alternativeAccountId, @"AltID");
    
    XCTAssertEqual(account2.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account2.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account2.accountIdentifier.displayableId, @"username");
    XCTAssertEqualObjects(account2.localAccountId, @"local");
    XCTAssertEqualObjects(account2.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account2.realm, @"tenant");
    XCTAssertEqualObjects(account2.storageEnvironment, @"login.windows2.net");
    XCTAssertEqualObjects(account2.username, @"username");
    XCTAssertEqualObjects(account2.givenName, @"Eric");
    XCTAssertEqualObjects(account2.middleName, @"Middle");
    XCTAssertEqualObjects(account2.familyName, @"Last");
    XCTAssertEqualObjects(account2.name, @"Eric Middle Last");
    XCTAssertEqualObjects(account2.clientInfo.rawClientInfo, [@{@"key" : @"value"} msidBase64UrlJson]);
    XCTAssertEqualObjects(account2.alternativeAccountId, @"AltID");
}

- (void)testInitWithJSONDictionary_whenSomeAccountsWrongType_shouldInitWithCorrectAccounts {
    
    NSArray *inputAccounts = @[
        @{
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
        },
        @{
            @"account_name" : @"abc",
            @"account_id" : @"abc"
        }
    ];
    
    NSString *accountsJsonString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:inputAccounts options:0 error:nil] encoding:NSUTF8StringEncoding];
    
    
    NSDictionary *json = @{
        @"operation" : @"get_accounts",
        @"success" : @1,
        @"accounts" : accountsJsonString
    };

    NSError *error;
    MSIDBrokerOperationGetAccountsResponse *response = [[MSIDBrokerOperationGetAccountsResponse alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(error);
    NSArray *accounts = response.accounts;
    XCTAssertEqual(accounts.count, 1);
    MSIDAccount *account1 = accounts[0];
    
    XCTAssertEqual(account1.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account1.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account1.accountIdentifier.displayableId, @"username");
    XCTAssertEqualObjects(account1.localAccountId, @"local");
    XCTAssertEqualObjects(account1.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account1.realm, @"common");
    XCTAssertEqualObjects(account1.storageEnvironment, @"login.windows2.net");
    XCTAssertEqualObjects(account1.username, @"username");
    XCTAssertEqualObjects(account1.givenName, @"Eric");
    XCTAssertEqualObjects(account1.middleName, @"Middle");
    XCTAssertEqualObjects(account1.familyName, @"Last");
    XCTAssertEqualObjects(account1.name, @"Eric Middle Last");
    XCTAssertEqualObjects(account1.clientInfo.rawClientInfo, [@{@"key" : @"value"} msidBase64UrlJson]);
    XCTAssertEqualObjects(account1.alternativeAccountId, @"AltID");
}

- (void)testInitWithJSONDictionary_whenSomeAccountsNotAbleToInit_shouldInitWithCorrectAccounts {
    
    NSArray *inputAccounts = @[
        @{
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
        },
        @"2"//corrupted accounts
    ];
    
    NSString *accountsJsonString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:inputAccounts options:0 error:nil] encoding:NSUTF8StringEncoding];
    
    NSDictionary *json = @{
        @"operation" : @"get_accounts",
        @"success" : @1,
        @"accounts" : accountsJsonString
    };

    NSError *error;
    MSIDBrokerOperationGetAccountsResponse *response = [[MSIDBrokerOperationGetAccountsResponse alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(error);
    NSArray *accounts = response.accounts;
    XCTAssertEqual(accounts.count, 1);
    MSIDAccount *account1 = accounts[0];
    
    XCTAssertEqual(account1.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account1.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account1.accountIdentifier.displayableId, @"username");
    XCTAssertEqualObjects(account1.localAccountId, @"local");
    XCTAssertEqualObjects(account1.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account1.realm, @"common");
    XCTAssertEqualObjects(account1.storageEnvironment, @"login.windows2.net");
    XCTAssertEqualObjects(account1.username, @"username");
    XCTAssertEqualObjects(account1.givenName, @"Eric");
    XCTAssertEqualObjects(account1.middleName, @"Middle");
    XCTAssertEqualObjects(account1.familyName, @"Last");
    XCTAssertEqualObjects(account1.name, @"Eric Middle Last");
    XCTAssertEqualObjects(account1.clientInfo.rawClientInfo, [@{@"key" : @"value"} msidBase64UrlJson]);
    XCTAssertEqualObjects(account1.alternativeAccountId, @"AltID");
}

- (void)testInitWithJSONDictionary_whenAccountsNotAnArray_shouldReturnNil {
    NSDictionary *json = @{
        @"operation" : @"get_accounts",
        @"success" : @1,
        @"accounts" : @2
    };

    NSError *error;
    MSIDBrokerOperationGetAccountsResponse *response = [[MSIDBrokerOperationGetAccountsResponse alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertNil(response);
}

- (void)testJsonDictionary_whenDeserialize_shouldGenerateCorrectJson {
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
    
    MSIDAccount *account2 = [account copy];
    account2.realm = @"tenant";
    
    MSIDBrokerOperationGetAccountsResponse *response = [[MSIDBrokerOperationGetAccountsResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.accounts = @[account, account2];
    response.operation = @"get_accounts";
    response.success = YES;
    response.deviceInfo = [MSIDDeviceInfo new];
    response.deviceInfo.deviceMode = MSIDDeviceModeShared;
    response.deviceInfo.wpjStatus = MSIDWorkPlaceJoinStatusJoined;
    response.deviceInfo.brokerVersion = @"1.2.3";
    
    NSArray *inputAccounts = @[
        @{
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
        },
        @{
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
            @"realm" : @"tenant",
            @"storage_environment" : @"login.windows2.net",
            @"username" : @"username",
        }
    ];
    
    NSDictionary *result = response.jsonDictionary;
    
    XCTAssertEqualObjects(result[@"operation"], @"get_accounts");
    XCTAssertEqualObjects(result[@"success"] , @"1");
    XCTAssertEqualObjects(result[@"operation_response_type"], @"operation_get_accounts_response");
    XCTAssertEqualObjects(result[MSID_BROKER_DEVICE_MODE_KEY], @"shared");
    XCTAssertEqualObjects(result[MSID_BROKER_WPJ_STATUS_KEY], @"joined");
    XCTAssertEqualObjects(result[MSID_BROKER_BROKER_VERSION_KEY], @"1.2.3");
    
    NSArray *decodedAccounts = [NSJSONSerialization JSONObjectWithData:[result[@"accounts"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    XCTAssertEqualObjects(decodedAccounts, inputAccounts);
}

@end
