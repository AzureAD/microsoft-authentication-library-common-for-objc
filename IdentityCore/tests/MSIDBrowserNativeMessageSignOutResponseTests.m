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
#import "MSIDBrowserNativeMessageSignOutResponse.h"

@interface MSIDBrowserNativeMessageSignOutResponseTests : XCTestCase

@end

@implementation MSIDBrowserNativeMessageSignOutResponseTests

- (void)testResponseType_shouldBeGenericResponse
{
    // We don't use this operation directly, it is wrapped by "BrokerOperationBrowserNativeMessage" operation, so we don't care about response type and return generic response.
    XCTAssertEqualObjects(@"operation_generic_response", [MSIDBrowserNativeMessageSignOutResponse responseType]);
}

- (void)testJsonDictionary_shouldBeEmptyJson
{
    __auto_type response = [[MSIDBrowserNativeMessageSignOutResponse alloc] initWithDeviceInfo:nil];
    
    XCTAssertNotNil([response jsonDictionary]);
    XCTAssertEqualObjects(@{}, [response jsonDictionary]);
}
@end
