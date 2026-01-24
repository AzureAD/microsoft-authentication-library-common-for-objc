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
#import "MSIDWebviewResponseEvent.h"

@interface MSIDWebviewResponseEventTests : XCTestCase

@end

@implementation MSIDWebviewResponseEventTests

- (void)testInitWithURL_shouldSetProperties
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com"];
    NSDictionary *headers = @{@"X-Custom-Header": @"value"};
    NSInteger statusCode = 302;
    
    MSIDWebviewResponseEvent *event = [[MSIDWebviewResponseEvent alloc] initWithURL:url
                                                                         httpHeaders:headers
                                                                          statusCode:statusCode];
    
    XCTAssertNotNil(event);
    XCTAssertEqualObjects(event.url, url);
    XCTAssertEqualObjects(event.httpHeaders, headers);
    XCTAssertEqual(event.statusCode, statusCode);
}

- (void)testInitWithURL_withNilHeaders_shouldSetPropertiesCorrectly
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com"];
    NSInteger statusCode = 200;
    
    MSIDWebviewResponseEvent *event = [[MSIDWebviewResponseEvent alloc] initWithURL:url
                                                                         httpHeaders:nil
                                                                          statusCode:statusCode];
    
    XCTAssertNotNil(event);
    XCTAssertEqualObjects(event.url, url);
    XCTAssertNil(event.httpHeaders);
    XCTAssertEqual(event.statusCode, statusCode);
}

- (void)testInitWithURL_withMultipleHeaders_shouldStoreAllHeaders
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com"];
    NSDictionary *headers = @{
        @"X-Intune-AuthToken": @"token123",
        @"X-Install-Url": @"https://install.com",
        @"x-ms-clitelem": @"telemetry"
    };
    NSInteger statusCode = 302;
    
    MSIDWebviewResponseEvent *event = [[MSIDWebviewResponseEvent alloc] initWithURL:url
                                                                         httpHeaders:headers
                                                                          statusCode:statusCode];
    
    XCTAssertNotNil(event);
    XCTAssertEqual(event.httpHeaders.count, 3);
    XCTAssertEqualObjects(event.httpHeaders[@"X-Intune-AuthToken"], @"token123");
    XCTAssertEqualObjects(event.httpHeaders[@"X-Install-Url"], @"https://install.com");
    XCTAssertEqualObjects(event.httpHeaders[@"x-ms-clitelem"], @"telemetry");
}

@end
