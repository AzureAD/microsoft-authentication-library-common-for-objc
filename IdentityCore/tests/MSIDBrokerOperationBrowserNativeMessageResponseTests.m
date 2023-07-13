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
#import "MSIDBrokerOperationBrowserNativeMessageResponse.h"

@interface MSIDBrokerOperationBrowserNativeMessageResponseTests : XCTestCase

@end

@implementation MSIDBrokerOperationBrowserNativeMessageResponseTests

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testResponseType_shouldBeCorrect
{
    XCTAssertEqualObjects(@"operation_browser_native_message_response", [MSIDBrokerOperationBrowserNativeMessageResponse responseType]);
}

- (void)testJsonDictionary_whenNoPayload_shouldBeNil
{
    __auto_type response = [[MSIDBrokerOperationBrowserNativeMessageResponse alloc] initWithDeviceInfo:nil];

    XCTAssertNil([response jsonDictionary]);
}

- (void)testJsonDictionary_whenPayloadExist_shouldBeCorrect
{
    __auto_type response = [[MSIDBrokerOperationBrowserNativeMessageResponse alloc] initWithDeviceInfo:nil];
    response.operation = @"browser_native_message_operation";
    response.payload = @"payload_json_string";

    __auto_type expectedJson = @{@"operation": @"browser_native_message_operation",
                                 @"operation_response_type": @"operation_browser_native_message_response",
                                 @"payload": @"payload_json_string",
                                 @"success":@"0"};
    XCTAssertEqualObjects(expectedJson, [response jsonDictionary]);
}

@end
