//
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
#import "MSIDBrowserNativeMessageGetSupportedContractsResponse.h"
#import "MSIDBrowserNativeMessageGetSupportedContractsRequest.h"

@interface MSIDBrowserNativeMessageGetSupportedContractsResponseTests : XCTestCase

@end

@implementation MSIDBrowserNativeMessageGetSupportedContractsResponseTests

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testResponseType_shouldBeGenericResponse
{
    XCTAssertEqualObjects(@"operation_browser_native_get_supported_contracts_response", [MSIDBrowserNativeMessageGetSupportedContractsResponse responseType]);
}

- (void)testInitWithJSONDictionary_whenJSONValid_shouldReturnResponse
{
    __auto_type json = @{
        @"contracts": @"contract1,contract2",
        @"operation": @"browser_native_get_supported_contracts_operation",
        @"operation_response_type": @"operation_browser_native_get_supported_contracts_response",
        @"success": @"1"
    };
    NSArray *expectedContracts = @[@"contract1", @"contract2"];
    
    NSError *error = nil;
    __auto_type response = [[MSIDBrowserNativeMessageGetSupportedContractsResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(expectedContracts, response.supportedContracts);
}


- (void)testJsonDictionary_whenContractsSet_shouldReturnJson
{
    __auto_type response = [[MSIDBrowserNativeMessageGetSupportedContractsResponse alloc] initWithDeviceInfo:nil];
    response.operation = MSIDBrowserNativeMessageGetSupportedContractsRequest.operation;
    response.success = YES;
    response.supportedContracts = @[@"contract1", @"contract2"];
    
    XCTAssertNotNil([response jsonDictionary]);
    
    __auto_type expectedJson = @{
        @"contracts": @"contract1,contract2",
        @"operation": @"browser_native_get_supported_contracts_operation",
        @"operation_response_type": @"operation_browser_native_get_supported_contracts_response",
        @"success": @"1"
    };
    
    XCTAssertEqualObjects(expectedJson, [response jsonDictionary]);
}

- (void)testJsonDictionary_whenNoContractsSet_shouldReturnNil
{
    __auto_type response = [[MSIDBrowserNativeMessageGetSupportedContractsResponse alloc] initWithDeviceInfo:nil];
    
    XCTAssertNil([response jsonDictionary]);
}

@end
