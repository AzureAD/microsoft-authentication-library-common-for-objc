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

@interface MSIDBrokerOperationGetAccountsResponseTests : XCTestCase

@end

@implementation MSIDBrokerOperationGetAccountsResponseTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testInitWithJSONDictionary_whenJsonValid_shouldInitWithJson {
    NSDictionary *json = @{
//        @"application_token" : @"app_token",
        @"operation" : @"get_accounts",
        @"success" : @1,
        @"response_data" : @{
                @"accounts" :
                    @[
                        @{
                            @"account_identifier" : @{
                                    @"account_home_id" : @"uid.utid",
                                    @"account_displayable_id" : @"legacy id",
                            },
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
                            @"account_identifier" : @{
                                    @"account_home_id" : @"uid.utid",
                                    @"account_displayable_id" : @"legacy id",
                            },
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
                    ]
        },
    };

    NSError *error;
    MSIDBrokerOperationGetAccountsResponse *response = [[MSIDBrokerOperationGetAccountsResponse alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(error);
//    XCTAssertEqualObjects(response.applicationToken, @"app_token");
//    XCTAssertEqual(response.success, YES);
//    XCTAssertEqualObjects(response.operation, @"get_accounts");
    NSArray *accounts = response.accounts;
    XCTAssertEqual(accounts.count, 2);
    MSIDAccount *account1 = accounts[0];
    MSIDAccount *account2 = accounts[1];
    
    XCTAssertEqual(account1.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account1.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(account1.accountIdentifier.displayableId, @"legacy id");
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
    XCTAssertEqualObjects(account2.accountIdentifier.displayableId, @"legacy id");
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

- (void)testJsonDictionary_whenDeserialize_shouldGenerateCorrectJson {
    MSIDAccount *account = [MSIDAccount new];
    account.accountType = MSIDAccountTypeMSSTS;
    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy id" homeAccountId:@"uid.utid"];
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
    
    MSIDBrokerOperationGetAccountsResponse *response = [MSIDBrokerOperationGetAccountsResponse new];
    response.accounts = @[account, account2];
    response.operation = @"get_accounts";
//    response.applicationToken = @"app_token";
    response.success = YES;
    
    NSDictionary *expectedJson = @{
        @"operation" : @"get_accounts",
        @"success" : @"1",
        @"response_data" : @{
                @"accounts" :
                    @[
                        @{
                            @"account_identifier" : @{
                                    @"account_home_id" : @"uid.utid",
                                    @"account_displayable_id" : @"legacy id",
                            },
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
                            @"account_identifier" : @{
                                    @"account_home_id" : @"uid.utid",
                                    @"account_displayable_id" : @"legacy id",
                            },
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
                    ]
        },
    };

    XCTAssertEqualObjects(expectedJson, response.jsonDictionary);
}

@end
