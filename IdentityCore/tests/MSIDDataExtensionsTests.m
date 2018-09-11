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
#import "NSData+MSIDExtensions.h"
#import "MSIDPkce.h"

@interface MSIDDataExtensionsTests : XCTestCase

@end

@implementation MSIDDataExtensionsTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testmsidDataFromBase64UrlEncodedString_encodedLength16_shouldDecode
{
    NSString *test = @"bWljcm9zb2Z0IHRlc3RjYQ";
    NSData *data = [NSData msidDataFromBase64UrlEncodedString:test];
    
    // expected, with a padding and conversion of 62 and 63rd characted
    NSString *expected = @"bWljcm9zb2Z0IHRlc3RjYQ==";
    NSData *expectedData = [[NSData alloc] initWithBase64EncodedString:expected options:0];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(data, expectedData);
}

- (void)testmsidDataFromBase64UrlEncodedString_encodedLength17_shouldDecode
{
    NSString *test = @"bWljcm9zb2Z0IHRlc3RjYXM";
    NSData *data = [NSData msidDataFromBase64UrlEncodedString:test];
    
    // expected, with a padding and conversion of 62 and 63rd characted
    NSString *expected = @"bWljcm9zb2Z0IHRlc3RjYXM=";
    NSData *expectedData = [[NSData alloc] initWithBase64EncodedString:expected options:0];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(data, expectedData);
}

- (void)testmsidDataFromBase64UrlEncodedString_encodedLength18_shouldDecode
{
    NSString *test = @"bWljcm9zb2Z0IHRlc3RjYXNl";
    NSData *data = [NSData msidDataFromBase64UrlEncodedString:test];
    
    // expected, with a padding and conversion of 62 and 63rd characted
    NSString *expected = @"bWljcm9zb2Z0IHRlc3RjYXNl";
    NSData *expectedData = [[NSData alloc] initWithBase64EncodedString:expected options:0];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(data, expectedData);
}
- (void)testmsidDataFromBase64UrlEncodedString_encodedLength19_shouldDecode
{
    NSString *test = @"bWljcm9zb2Z0IHRlc3RjYXNlLg";
    NSData *data = [NSData msidDataFromBase64UrlEncodedString:test];
    
    // expected, with a padding and conversion of 62 and 63rd characted
    NSString *expected = @"bWljcm9zb2Z0IHRlc3RjYXNlLg==";
    NSData *expectedData = [[NSData alloc] initWithBase64EncodedString:expected options:0];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(data, expectedData);
}

- (void)testmsidDataFromBase64UrlEncodedString_encodedLength20_shouldDecode
{
    NSString *test = @"bWljcm9zb2Z0IHRlc3RjYXNlLiE";
    NSData *data = [NSData msidDataFromBase64UrlEncodedString:test];
    
    // expected, with a padding and conversion of 62 and 63rd characted
    NSString *expected = @"bWljcm9zb2Z0IHRlc3RjYXNlLiE=";
    NSData *expectedData = [[NSData alloc] initWithBase64EncodedString:expected options:0];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(data, expectedData);
}



@end
