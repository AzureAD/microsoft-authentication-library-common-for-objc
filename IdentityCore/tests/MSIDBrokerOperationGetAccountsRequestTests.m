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
#import "MSIDBrokerOperationGetAccountsRequest.h"
#import "MSIDConstants.h"

@interface MSIDBrokerOperationGetAccountsRequestTests : XCTestCase

@end

@implementation MSIDBrokerOperationGetAccountsRequestTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testOperationName_whenCalled_shouldReturnCorrectOperationName {
    XCTAssertEqualObjects(@"get_accounts", MSIDBrokerOperationGetAccountsRequest.operation);
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
                                   @"client_id" : @"my-client-id"
                           }
    };
    
    NSError *error;
    MSIDBrokerOperationGetAccountsRequest *request = [[MSIDBrokerOperationGetAccountsRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(request.brokerKey, @"I87KMS");
    XCTAssertEqual(request.protocolVersion, 3);
    XCTAssertEqualObjects(request.clientVersion, @"1.0");
    XCTAssertEqualObjects(request.clientAppVersion, @"10.3.4");
    XCTAssertEqualObjects(request.clientAppName, @"Outlook");
    XCTAssertEqualObjects(request.correlationId.UUIDString, @"A8AAEF5C-6100-4D85-9D8C-B877BDF96043");
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
    MSIDBrokerOperationGetAccountsRequest *request = [[MSIDBrokerOperationGetAccountsRequest alloc] initWithJSONDictionary:json error:&error];

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
                           @"request_parameters" : @{}
    };

    NSError *error;
    MSIDBrokerOperationGetAccountsRequest *request = [[MSIDBrokerOperationGetAccountsRequest alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNotNil(error);
    XCTAssertNil(request);
}

- (void)testJsonDictionary_whenDeserialize_shouldGenerateCorrectJson {
    MSIDBrokerOperationGetAccountsRequest *request = [MSIDBrokerOperationGetAccountsRequest new];
    request.brokerKey = @"I87KMS";
    request.protocolVersion = 3;
    request.clientVersion = @"1.0";
    request.clientAppVersion = @"10.3.4";
    request.clientAppName = @"Outlook";
    request.correlationId = [[NSUUID alloc] initWithUUIDString:@"A8AAEF5C-6100-4D85-9D8C-B877BDF96043"];
    request.clientId = @"my-client-id";
    
    NSDictionary *expectedJson = @{@"operation" : @"get_accounts",
                                   MSID_BROKER_KEY : @"I87KMS",
                                   MSID_BROKER_PROTOCOL_VERSION_KEY : @"3",
                                   MSID_BROKER_CLIENT_VERSION_KEY : @"1.0",
                                   MSID_BROKER_CLIENT_APP_VERSION_KEY : @"10.3.4",
                                   MSID_BROKER_CLIENT_APP_NAME_KEY : @"Outlook",
                                   MSID_BROKER_CORRELATION_ID_KEY : @"A8AAEF5C-6100-4D85-9D8C-B877BDF96043",
                                   @"request_parameters" : @{
                                           @"client_id" : @"my-client-id"
                                   }
    };
    
    XCTAssertEqualObjects(request.jsonDictionary, expectedJson);
}

@end
