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

#pragma mark - isMissingRequiredXPrefix

- (void)testIsMissingRequiredXPrefix_whenFieldHasXPrefix_shouldReturnNO
{
    // define
    NSString *fieldName = @"x-custom-header";

    // invoke
    BOOL result = [self.validator isMissingRequiredXPrefix:fieldName];

    // assert
    XCTAssertFalse(result);
}

- (void)testIsMissingRequiredXPrefix_whenFieldHasUppercaseXPrefix_shouldReturnNO
{
    // define
    NSString *fieldName = @"X-Custom-Header";

    // invoke
    BOOL result = [self.validator isMissingRequiredXPrefix:fieldName];

    // assert
    XCTAssertFalse(result);
}

- (void)testIsMissingRequiredXPrefix_whenFieldLacksXPrefix_shouldReturnYES
{
    // define
    NSString *fieldName = @"custom-header";

    // invoke
    BOOL result = [self.validator isMissingRequiredXPrefix:fieldName];

    // assert
    XCTAssertTrue(result);
}

- (void)testIsMissingRequiredXPrefix_whenFieldIsEmpty_shouldReturnYES
{
    // define
    NSString *fieldName = @"";

    // invoke
    BOOL result = [self.validator isMissingRequiredXPrefix:fieldName];

    // assert
    XCTAssertTrue(result);
}

- (void)testIsMissingRequiredXPrefix_whenFieldStartsWithXButNoHyphen_shouldReturnYES
{
    // define
    NSString *fieldName = @"xcustom";

    // invoke
    BOOL result = [self.validator isMissingRequiredXPrefix:fieldName];

    // assert
    XCTAssertTrue(result);
}

#pragma mark - reservedPrefixForFieldName

- (void)testReservedPrefixForFieldName_whenFieldHasXMsPrefix_shouldReturnReservedPrefix
{
    // define
    NSString *fieldName = @"x-ms-correlation-id";

    // invoke
    NSString *reservedPrefix = [self.validator reservedPrefixForFieldName:fieldName];

    // assert
    XCTAssertEqualObjects(reservedPrefix, @"x-ms-");
}

- (void)testReservedPrefixForFieldName_whenFieldHasXClientPrefix_shouldReturnReservedPrefix
{
    // define
    NSString *fieldName = @"x-client-sku";

    // invoke
    NSString *reservedPrefix = [self.validator reservedPrefixForFieldName:fieldName];

    // assert
    XCTAssertEqualObjects(reservedPrefix, @"x-client-");
}

- (void)testReservedPrefixForFieldName_whenFieldHasXBrokerPrefix_shouldReturnReservedPrefix
{
    // define
    NSString *fieldName = @"x-broker-version";

    // invoke
    NSString *reservedPrefix = [self.validator reservedPrefixForFieldName:fieldName];

    // assert
    XCTAssertEqualObjects(reservedPrefix, @"x-broker-");
}

- (void)testReservedPrefixForFieldName_whenFieldHasXAppPrefix_shouldReturnReservedPrefix
{
    // define
    NSString *fieldName = @"x-app-name";

    // invoke
    NSString *reservedPrefix = [self.validator reservedPrefixForFieldName:fieldName];

    // assert
    XCTAssertEqualObjects(reservedPrefix, @"x-app-");
}

- (void)testReservedPrefixForFieldName_whenFieldHasUppercaseReservedPrefix_shouldReturnReservedPrefix
{
    // define
    NSString *fieldName = @"X-MS-CorrelationId";

    // invoke
    NSString *reservedPrefix = [self.validator reservedPrefixForFieldName:fieldName];

    // assert
    XCTAssertEqualObjects(reservedPrefix, @"x-ms-");
}

- (void)testReservedPrefixForFieldName_whenFieldHasNoReservedPrefix_shouldReturnNil
{
    // define
    NSString *fieldName = @"x-custom-header";

    // invoke
    NSString *reservedPrefix = [self.validator reservedPrefixForFieldName:fieldName];

    // assert
    XCTAssertNil(reservedPrefix);
}

- (void)testReservedPrefixForFieldName_whenFieldLacksXPrefix_shouldReturnNil
{
    // define
    NSString *fieldName = @"content-type";

    // invoke
    NSString *reservedPrefix = [self.validator reservedPrefixForFieldName:fieldName];

    // assert
    XCTAssertNil(reservedPrefix);
}

#pragma mark - isValidHeaderFieldName

- (void)testIsValidHeaderFieldName_whenFieldHasValidXPrefix_shouldReturnYES
{
    // define
    NSString *fieldName = @"x-custom-header";

    // invoke
    BOOL result = [self.validator isValidHeaderFieldName:fieldName];

    // assert
    XCTAssertTrue(result);
}

- (void)testIsValidHeaderFieldName_whenFieldHasUppercaseValidXPrefix_shouldReturnYES
{
    // define
    NSString *fieldName = @"X-Custom-Header";

    // invoke
    BOOL result = [self.validator isValidHeaderFieldName:fieldName];

    // assert
    XCTAssertTrue(result);
}

- (void)testIsValidHeaderFieldName_whenFieldLacksXPrefix_shouldReturnNO
{
    // define
    NSString *fieldName = @"content-type";

    // invoke
    BOOL result = [self.validator isValidHeaderFieldName:fieldName];

    // assert
    XCTAssertFalse(result);
}

- (void)testIsValidHeaderFieldName_whenFieldUsesXMsReservedPrefix_shouldReturnNO
{
    // define
    NSString *fieldName = @"x-ms-correlation-id";

    // invoke
    BOOL result = [self.validator isValidHeaderFieldName:fieldName];

    // assert
    XCTAssertFalse(result);
}

- (void)testIsValidHeaderFieldName_whenFieldUsesXClientReservedPrefix_shouldReturnNO
{
    // define
    NSString *fieldName = @"x-client-sku";

    // invoke
    BOOL result = [self.validator isValidHeaderFieldName:fieldName];

    // assert
    XCTAssertFalse(result);
}

- (void)testIsValidHeaderFieldName_whenFieldUsesXBrokerReservedPrefix_shouldReturnNO
{
    // define
    NSString *fieldName = @"x-broker-version";

    // invoke
    BOOL result = [self.validator isValidHeaderFieldName:fieldName];

    // assert
    XCTAssertFalse(result);
}

- (void)testIsValidHeaderFieldName_whenFieldUsesXAppReservedPrefix_shouldReturnNO
{
    // define
    NSString *fieldName = @"x-app-name";

    // invoke
    BOOL result = [self.validator isValidHeaderFieldName:fieldName];

    // assert
    XCTAssertFalse(result);
}

- (void)testIsValidHeaderFieldName_whenFieldUsesUppercaseReservedPrefix_shouldReturnNO
{
    // define
    NSString *fieldName = @"X-MS-CorrelationId";

    // invoke
    BOOL result = [self.validator isValidHeaderFieldName:fieldName];

    // assert
    XCTAssertFalse(result);
}

- (void)testIsValidHeaderFieldName_whenFieldIsEmpty_shouldReturnNO
{
    // define
    NSString *fieldName = @"";

    // invoke
    BOOL result = [self.validator isValidHeaderFieldName:fieldName];

    // assert
    XCTAssertFalse(result);
}

@end
