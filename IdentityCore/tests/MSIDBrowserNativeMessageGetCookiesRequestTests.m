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
#import "MSIDBrowserNativeMessageGetCookiesRequest.h"

@interface MSIDBrowserNativeMessageGetCookiesRequestTests : XCTestCase

@end

@implementation MSIDBrowserNativeMessageGetCookiesRequestTests

- (void)setUp
{

}

- (void)tearDown
{
}

- (void)testOperation_shouldBeCorrect
{
    XCTAssertEqualObjects(@"GetCookies", [MSIDBrowserNativeMessageGetCookiesRequest operation]);
}

- (void)testJsonDictionary_shouldThrow
{
    __auto_type request = [MSIDBrowserNativeMessageGetCookiesRequest new];

    XCTAssertThrows([request jsonDictionary]);
}

- (void)testInitWithJSONDictionary_whenJsonValid_shouldInit
{
    __auto_type json = @{
        @"sender": @"https://login.microsoft.com",
        @"uri": @"uri"
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrowserNativeMessageGetCookiesRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(request);
    XCTAssertEqualObjects(@"https://login.microsoft.com", request.sender.absoluteString);
    XCTAssertEqualObjects(@"uri", request.uri);
}

- (void)testInitWithJSONDictionary_whenNoSender_shouldFail
{
    __auto_type json = @{
        @"uri": @"uri"
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrowserNativeMessageGetCookiesRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"sender key is missing in dictionary.");
}

- (void)testInitWithJSONDictionary_whenNoUri_shouldFail
{
    __auto_type json = @{
        @"sender": @"https://login.microsoft.com",
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrowserNativeMessageGetCookiesRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"uri key is missing in dictionary.");
}

@end
