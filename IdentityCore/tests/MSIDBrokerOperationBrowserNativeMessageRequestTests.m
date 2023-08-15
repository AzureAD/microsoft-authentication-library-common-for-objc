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
#import "MSIDBrokerOperationBrowserNativeMessageRequest.h"

@interface MSIDBrokerOperationBrowserNativeMessageRequestTests : XCTestCase

@end

@implementation MSIDBrokerOperationBrowserNativeMessageRequestTests

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testOperation_shouldBeCorrect
{
    XCTAssertEqualObjects(@"browser_native_message_operation", [MSIDBrokerOperationBrowserNativeMessageRequest operation]);
}

- (void)testJsonDictionary_whenNoPayload_shouldBeNil
{
    __auto_type request = [MSIDBrokerOperationBrowserNativeMessageRequest new];
    request.brokerKey = @"some key";
    request.protocolVersion = 1;

    XCTAssertNil([request jsonDictionary]);
}

- (void)testJsonDictionary_whenPayloadExist_shouldBeCorrect
{
    __auto_type request = [MSIDBrokerOperationBrowserNativeMessageRequest new];
    request.payloadJson = @{@"a": @"b"};
    request.brokerKey = @"some key";
    request.protocolVersion = 1;

    __auto_type expectedJson = @{@"broker_key": @"some key",
                                 @"msg_protocol_ver": @"1",
                                 @"payload": @"{\"a\":\"b\"}"};
    XCTAssertEqualObjects(expectedJson, [request jsonDictionary]);
}


@end
