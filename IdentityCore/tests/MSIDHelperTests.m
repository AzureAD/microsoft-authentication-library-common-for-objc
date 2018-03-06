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
#import "MSIDHelpers.h"

@interface MSIDHelperTests : XCTestCase

@end

@implementation MSIDHelperTests

- (void)testMsidIntegerValue_whenParsableNSString_shouldReturnValue
{
    NSString *input = @"3600";
    NSInteger result = [MSIDHelpers msidIntegerValue:input];
    XCTAssertEqual(result, 3600);
}

- (void)testMsidIntegerValue_whenNonParsableNSString_shouldReturnZero
{
    NSString *input = @"xyz";
    NSInteger result = [MSIDHelpers msidIntegerValue:input];
    XCTAssertEqual(result, 0);
}

- (void)testMsidIntegerValue_whenParsableNSNumber_shouldReturnValue
{
    NSNumber *input = @3600;
    NSInteger result = [MSIDHelpers msidIntegerValue:input];
    XCTAssertEqual(result, 3600);
}

- (void)testMsidIntegerValue_whenParsableNegativeNSNumber_shouldReturnNegativeNumber
{
    NSNumber *input = @(-1);
    NSInteger result = [MSIDHelpers msidIntegerValue:input];
    XCTAssertEqual(result, -1);
}

- (void)testMsidIntegerValue_whenNonParsableObject_shouldReturnZero
{
    NSArray *input = [NSArray array];
    NSInteger result = [MSIDHelpers msidIntegerValue:input];
    XCTAssertEqual(result, 0);
}

@end
