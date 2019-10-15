//
//  MSIDBrokerOperationRemoveAccountRequestTests.m
//  IdentityCoreTests iOS
//
//  Created by JZ on 10/14/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MSIDBrokerOperationRemoveAccountRequest.h"
#import "MSIDConstants.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDBrokerOperationRemoveAccountRequestTests : XCTestCase

@end

@implementation MSIDBrokerOperationRemoveAccountRequestTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testOperationName {
    XCTAssertEqualObjects(@"remove_account", MSIDBrokerOperationRemoveAccountRequest.operation);
}

- (void)testInitWithJSONDictionary_whenAllRequiredFieldsAvailable_shouldSucceed {
    NSDictionary *json = @{@"operation" : @"get_accounts",
                           MSID_BROKER_KEY : @"I87KMS",
                           MSID_BROKER_PROTOCOL_VERSION_KEY : @"3",
                           MSID_BROKER_CLIENT_VERSION_KEY : @"1.0",
                           MSID_BROKER_CLIENT_APP_VERSION_KEY : @"10.3.4",
                           MSID_BROKER_CLIENT_APP_NAME_KEY : @"Outlook",
                           MSID_BROKER_CORRELATION_ID_KEY : @"A8AAEF5C-6100-4D85-9D8C-B877BDF96043",
                           @"request_parameters" : @{
                                   @"account_identifier" : @{
                                           @"home_account_id" : @"uid.utid",
                                           @"username" : @"legacy id",
                                   },
                                   @"client_id" : @"my-client-id"
                           }
    };

    NSError *error;
    MSIDBrokerOperationRemoveAccountRequest *request = [[MSIDBrokerOperationRemoveAccountRequest alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(error);
    XCTAssertEqualObjects(request.brokerKey, @"I87KMS");
    XCTAssertEqual(request.protocolVersion, 3);
    XCTAssertEqualObjects(request.clientVersion, @"1.0");
    XCTAssertEqualObjects(request.clientAppVersion, @"10.3.4");
    XCTAssertEqualObjects(request.clientAppName, @"Outlook");
    XCTAssertEqualObjects(request.correlationId.UUIDString, @"A8AAEF5C-6100-4D85-9D8C-B877BDF96043");
    XCTAssertEqualObjects(request.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(request.accountIdentifier.displayableId, @"legacy id");
    XCTAssertEqualObjects(request.clientId, @"my-client-id");
}

- (void)testInitWithJSONDictionary_whenRequestParametersMissing_shouldReturnNil {
    NSDictionary *json = @{@"operation" : @"get_accounts",
                           MSID_BROKER_KEY : @"I87KMS",
                           MSID_BROKER_PROTOCOL_VERSION_KEY : @"3",
                           MSID_BROKER_CLIENT_VERSION_KEY : @"1.0",
                           MSID_BROKER_CLIENT_APP_VERSION_KEY : @"10.3.4",
                           MSID_BROKER_CLIENT_APP_NAME_KEY : @"Outlook",
                           MSID_BROKER_CORRELATION_ID_KEY : @"A8AAEF5C-6100-4D85-9D8C-B877BDF96043",
    };

    NSError *error;
    MSIDBrokerOperationRemoveAccountRequest *request = [[MSIDBrokerOperationRemoveAccountRequest alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(error);
    XCTAssertNil(request);
}

- (void)testInitWithJSONDictionary_whenHomeAccountIdMissing_shouldReturnNil {
    NSDictionary *json = @{@"operation" : @"get_accounts",
                           MSID_BROKER_KEY : @"I87KMS",
                           MSID_BROKER_PROTOCOL_VERSION_KEY : @"3",
                           MSID_BROKER_CLIENT_VERSION_KEY : @"1.0",
                           MSID_BROKER_CLIENT_APP_VERSION_KEY : @"10.3.4",
                           MSID_BROKER_CLIENT_APP_NAME_KEY : @"Outlook",
                           MSID_BROKER_CORRELATION_ID_KEY : @"A8AAEF5C-6100-4D85-9D8C-B877BDF96043",
                           @"request_parameters" : @{
                                   @"account_identifier" : @{
                                           @"username" : @"legacy id"
                                   },
                                   @"client_id" : @"my-client-id"
                           }
    };

    NSError *error;
    MSIDBrokerOperationRemoveAccountRequest *request = [[MSIDBrokerOperationRemoveAccountRequest alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(error);
    XCTAssertNil(request);
}

- (void)testInitWithJSONDictionary_whenClientIdMissing_shouldReturnNil {
    NSDictionary *json = @{@"operation" : @"get_accounts",
                           MSID_BROKER_KEY : @"I87KMS",
                           MSID_BROKER_PROTOCOL_VERSION_KEY : @"3",
                           MSID_BROKER_CLIENT_VERSION_KEY : @"1.0",
                           MSID_BROKER_CLIENT_APP_VERSION_KEY : @"10.3.4",
                           MSID_BROKER_CLIENT_APP_NAME_KEY : @"Outlook",
                           MSID_BROKER_CORRELATION_ID_KEY : @"A8AAEF5C-6100-4D85-9D8C-B877BDF96043",
                           @"request_parameters" : @{
                                   @"account_identifier" : @{
                                           @"home_account_id" : @"uid.utid",
                                           @"username" : @"legacy id"
                                   }
                           }
    };

    NSError *error;
    MSIDBrokerOperationRemoveAccountRequest *request = [[MSIDBrokerOperationRemoveAccountRequest alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(error);
    XCTAssertNil(request);
}

- (void)testJsonDictionary {
    MSIDBrokerOperationRemoveAccountRequest *request = [MSIDBrokerOperationRemoveAccountRequest new];
    request.brokerKey = @"I87KMS";
    request.protocolVersion = 3;
    request.clientVersion = @"1.0";
    request.clientAppVersion = @"10.3.4";
    request.clientAppName = @"Outlook";
    request.correlationId = [[NSUUID alloc] initWithUUIDString:@"A8AAEF5C-6100-4D85-9D8C-B877BDF96043"];
    request.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy id" homeAccountId:@"uid.utid"];
    request.clientId = @"my-client-id";

    NSDictionary *expectedJson = @{@"operation" : @"remove_account",
                                   MSID_BROKER_KEY : @"I87KMS",
                                   MSID_BROKER_PROTOCOL_VERSION_KEY : @"3",
                                   MSID_BROKER_CLIENT_VERSION_KEY : @"1.0",
                                   MSID_BROKER_CLIENT_APP_VERSION_KEY : @"10.3.4",
                                   MSID_BROKER_CLIENT_APP_NAME_KEY : @"Outlook",
                                   MSID_BROKER_CORRELATION_ID_KEY : @"A8AAEF5C-6100-4D85-9D8C-B877BDF96043",
                                   @"request_parameters" : @{
                                           @"account_identifier" : @{
                                                   @"home_account_id" : @"uid.utid",
                                                   @"username" : @"legacy id",
                                           },
                                           @"client_id" : @"my-client-id"
                                   }
    };

    XCTAssertEqualObjects(request.jsonDictionary, expectedJson);
}

@end
