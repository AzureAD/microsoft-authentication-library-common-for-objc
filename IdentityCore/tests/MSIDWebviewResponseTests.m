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
#import "MSIDWebviewResponse.h"

@interface MSIDWebviewResponseTests : XCTestCase

@end

@implementation MSIDWebviewResponseTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInitWithURL_whenNilURL_shouldReturnNilAndError
{
    NSError *error = nil;
    MSIDWebviewResponse *response = [[MSIDWebviewResponse alloc] initWithURL:nil context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testInitWithURL_whenURLWithParams_shouldReturnInstanceWithParams
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"https://contoso.com?key1=val1&key2=val2"];
    
    MSIDWebviewResponse *response = [[MSIDWebviewResponse alloc] initWithURL:url
                                                                     context:nil
                                                                       error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertTrue(response.parameters.allKeys.count == 2);
    XCTAssertEqualObjects(response.parameters[@"key1"], @"val1");
    XCTAssertEqualObjects(response.parameters[@"key2"], @"val2");
    
    XCTAssertEqualObjects(response.url, url);
}


@end
