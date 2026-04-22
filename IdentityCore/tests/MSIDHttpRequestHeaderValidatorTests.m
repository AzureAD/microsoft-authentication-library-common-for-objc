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
#import "MSIDHttpRequestHeaderValidator.h"

@interface MSIDHttpRequestHeaderValidatorTests : XCTestCase

@property (nonatomic) MSIDHttpRequestHeaderValidator *validator;

@end

@implementation MSIDHttpRequestHeaderValidatorTests

- (void)setUp
{
    [super setUp];

    self.validator = [MSIDHttpRequestHeaderValidator new];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - validHeadersFromHeaders

- (void)testValidHeadersFromHeaders_whenAllHeadersAreValid_shouldReturnAllHeaders
{
    // define
    NSDictionary<NSString *, NSString *> *headers = @{
        @"x-custom-header" : @"value1",
        @"x-another-header" : @"value2"
    };

    // invoke
    NSDictionary<NSString *, NSString *> *result = [self.validator validHeadersFromHeaders:headers];

    // assert
    XCTAssertEqualObjects(result, headers);
}

- (void)testValidHeadersFromHeaders_whenSomeHeadersAreInvalid_shouldReturnOnlyValidHeaders
{
    // define
    NSDictionary<NSString *, NSString *> *headers = @{
        @"x-custom-header" : @"validValue",
        @"invalid-header" : @"ignoredValue",
        @"x-ms-correlation-id" : @"alsoIgnored"
    };

    // invoke
    NSDictionary<NSString *, NSString *> *result = [self.validator validHeadersFromHeaders:headers];

    // assert
    XCTAssertEqualObjects(result, @{@"x-custom-header" : @"validValue"});
}

- (void)testValidHeadersFromHeaders_whenAllHeadersAreInvalid_shouldReturnEmptyDictionary
{
    // define
    NSDictionary<NSString *, NSString *> *headers = @{
        @"invalid-header" : @"value1",
        @"x-ms-correlation-id" : @"value2",
        @"x-client-sku" : @"value3"
    };

    // invoke
    NSDictionary<NSString *, NSString *> *result = [self.validator validHeadersFromHeaders:headers];

    // assert
    XCTAssertEqualObjects(result, @{});
}

- (void)testValidHeadersFromHeaders_whenHeadersIsEmpty_shouldReturnEmptyDictionary
{
    // define
    NSDictionary<NSString *, NSString *> *headers = @{};

    // invoke
    NSDictionary<NSString *, NSString *> *result = [self.validator validHeadersFromHeaders:headers];

    // assert
    XCTAssertEqualObjects(result, @{});
}

- (void)testValidHeadersFromHeaders_whenHeadersContainAllReservedPrefixes_shouldReturnEmptyDictionary
{
    // define
    NSDictionary<NSString *, NSString *> *headers = @{
        @"x-ms-field" : @"v1",
        @"x-client-field" : @"v2",
        @"x-broker-field" : @"v3",
        @"x-app-field" : @"v4"
    };

    // invoke
    NSDictionary<NSString *, NSString *> *result = [self.validator validHeadersFromHeaders:headers];

    // assert
    XCTAssertEqualObjects(result, @{});
}

- (void)testValidHeadersFromHeaders_whenHeadersContainMixedCaseValidHeader_shouldReturnIt
{
    // define
    NSDictionary<NSString *, NSString *> *headers = @{
        @"X-Custom-Header" : @"mixedCaseValue"
    };

    // invoke
    NSDictionary<NSString *, NSString *> *result = [self.validator validHeadersFromHeaders:headers];

    // assert
    XCTAssertEqualObjects(result, headers);
}

@end
