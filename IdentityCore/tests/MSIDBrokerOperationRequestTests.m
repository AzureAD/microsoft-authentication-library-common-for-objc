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
#import "MSIDBrokerOperationRequest.h"

@interface MSIDBrokerOperationRequestTests : XCTestCase

@end

@implementation MSIDBrokerOperationRequestTests

- (void)testJsonDictionary_whenNoBrokerKey_shouldReturnNilJson
{
    __auto_type request = [MSIDBrokerOperationRequest new];
    request.protocolVersion = 99;
    
    NSDictionary *json = [request jsonDictionary];
    
    XCTAssertNil(json);
}

- (void)testInitWithJSONDictionary_whenNoBrokerKey_shouldReturnError
{
    NSDictionary *json = @{
        @"msg_protocol_ver": @"99",
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"broker_key key is missing in dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testJsonDictionary_whenNoProtocolVersion_shouldReturnNilJson
{
    __auto_type request = [MSIDBrokerOperationRequest new];
    request.brokerKey = @"broker_key_value";
    
    NSDictionary *json = [request jsonDictionary];
    
    XCTAssertNil(json);
}

- (void)testInitWithJSONDictionary_whenNoProtocolVersion_shouldReturnError
{
    NSDictionary *json = @{
        @"broker_key": @"broker_key_value",
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"msg_protocol_ver key is missing in dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
}

@end
