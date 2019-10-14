//
//  MSIDBrokerOperationGetAccountsRequestTests.m
//  IdentityCoreTests iOS
//
//  Created by JZ on 10/14/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MSIDBrokerOperationGetAccountsRequest.h"
#import "MSIDConstants.h"

@interface MSIDBrokerOperationGetAccountsRequestTests : XCTestCase

@end

@implementation MSIDBrokerOperationGetAccountsRequestTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testOperationName {
    XCTAssertEqualObjects(@"get_accounts", MSIDBrokerOperationGetAccountsRequest.operation);
}

- (void)testInitWithJSONDictionary {
    NSDictionary *json = @{@"operation" : @"get_accounts",
                           MSID_BROKER_KEY : @"I87KMS",
                           MSID_BROKER_PROTOCOL_VERSION_KEY : @"3",
                           MSID_BROKER_CLIENT_VERSION_KEY : @"1.0",
                           MSID_BROKER_CLIENT_APP_VERSION_KEY : @"10.3.4",
                           MSID_BROKER_CLIENT_APP_NAME_KEY : @"Outlook",
                           MSID_BROKER_CORRELATION_ID_KEY : @"A8AAEF5C-6100-4D85-9D8C-B877BDF96043"};
    
    NSError *error;
    MSIDBrokerOperationGetAccountsRequest *request = [[MSIDBrokerOperationGetAccountsRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(request.brokerKey, @"I87KMS");
    XCTAssertEqual(request.protocolVersion, 3);
    XCTAssertEqualObjects(request.clientVersion, @"1.0");
    XCTAssertEqualObjects(request.clientAppVersion, @"10.3.4");
    XCTAssertEqualObjects(request.clientAppName, @"Outlook");
    XCTAssertEqualObjects(request.correlationId.UUIDString, @"A8AAEF5C-6100-4D85-9D8C-B877BDF96043");
}

- (void)testJsonDictionary {
    MSIDBrokerOperationGetAccountsRequest *request = [MSIDBrokerOperationGetAccountsRequest new];
    request.brokerKey = @"I87KMS";
    request.protocolVersion = 3;
    request.clientVersion = @"1.0";
    request.clientAppVersion = @"10.3.4";
    request.clientAppName = @"Outlook";
    request.correlationId = [[NSUUID alloc] initWithUUIDString:@"A8AAEF5C-6100-4D85-9D8C-B877BDF96043"];
    
    NSDictionary *expectedJson = @{@"operation" : @"get_accounts",
                                   MSID_BROKER_KEY : @"I87KMS",
                                   MSID_BROKER_PROTOCOL_VERSION_KEY : @"3",
                                   MSID_BROKER_CLIENT_VERSION_KEY : @"1.0",
                                   MSID_BROKER_CLIENT_APP_VERSION_KEY : @"10.3.4",
                                   MSID_BROKER_CLIENT_APP_NAME_KEY : @"Outlook",
                                   MSID_BROKER_CORRELATION_ID_KEY : @"A8AAEF5C-6100-4D85-9D8C-B877BDF96043"};
    
    XCTAssertEqualObjects(request.jsonDictionary, expectedJson);
}

@end
