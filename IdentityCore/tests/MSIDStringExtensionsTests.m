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
#import "MSIDIdTokenClaims.h"

@interface ADTestNSStringHelperMethods : XCTestCase

@end

@implementation ADTestNSStringHelperMethods

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testIsStringNilOrBlankNil
{
    XCTAssertTrue([NSString msidIsStringNilOrBlank:nil], "Should return true for nil.");
}

- (void)testIsStringNilOrBlank_whenNSNull_shouldReturnTrue
{
    XCTAssertTrue([NSString msidIsStringNilOrBlank:(NSString *)[NSNull null]]);
}

- (void)testIsStringNilOrBlankSpace
{
    XCTAssertTrue([NSString msidIsStringNilOrBlank:@" "], "Should return true for nil.");
}

- (void)testIsStringNilOrBlankTab
{
    XCTAssertTrue([NSString msidIsStringNilOrBlank:@"\t"], "Should return true for nil.");
}

- (void)testIsStringNilOrBlankEnter
{
    XCTAssertTrue([NSString msidIsStringNilOrBlank:@"\r"], "Should return true for nil.");
    XCTAssertTrue([NSString msidIsStringNilOrBlank:@"\n"], "Should return true for nil.");
}

- (void)testIsStringNilOrBlankMixed
{
    XCTAssertTrue([NSString msidIsStringNilOrBlank:@" \r\n\t  \t\r\n"], "Should return true for nil.");
}

- (void)testIsStringNilOrBlankNonEmpty
{
    //Prefix by white space:
    NSString* str = @"  text";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);
    str = @" \r\n\t  \t\r\n text";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);

    //Suffix with white space:
    str = @"text  ";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);
    str = @"text \r\n\t  \t\r\n";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);
    
    //Surrounded by white space:
    str = @"text  ";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);
    str = @" \r\n\t text  \t\r\n";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);

    //No white space:
    str = @"t";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);
}

- (void)testTrimmedString
{
    XCTAssertEqualObjects([@" \t\r\n  test" msidTrimmedString], @"test");
    XCTAssertEqualObjects([@"test  \t\r\n  " msidTrimmedString], @"test");
    XCTAssertEqualObjects([@"test  \t\r\n  test" msidTrimmedString], @"test  \t\r\n  test");
    XCTAssertEqualObjects([@"  \t\r\n  test  \t\r\n  test  \t\r\n  " msidTrimmedString], @"test  \t\r\n  test");
}

#define VERIFY_BASE64(_ORIGINAL, _EXPECTED) { \
    NSString* encoded = [_ORIGINAL msidBase64UrlEncode]; \
    NSString* decoded = [_EXPECTED msidBase64UrlDecode]; \
    XCTAssertEqualObjects(encoded, _EXPECTED); \
    XCTAssertEqualObjects(decoded, _ORIGINAL); \
}


- (void)testmsidURLFormDecode
{
    NSString* testString = @"Some interesting test/+-)(*&^%$#@!~|";
    NSString* encoded = [testString msidUrlFormEncode];

    XCTAssertEqualObjects(encoded, @"Some+interesting+test%2F%2B-%29%28%2A%26%5E%25%24%23%40%21~%7C");
    XCTAssertEqualObjects([encoded msidUrlFormDecode], testString);
}

- (void)testmsidURLFormEncode_whenHasNewLine_shouldEncode
{
    NSString* testString = @"test\r\ntest2";
    NSString* encoded = [testString msidUrlFormEncode];
    
    XCTAssertEqualObjects(encoded, @"test%0D%0Atest2");
    XCTAssertEqualObjects([encoded msidUrlFormDecode], testString);
}

- (void)testmsidURLFormEncode_whenHasSpace_shouldEncodeWithPlus
{
    NSString* testString = @"test test2";
    NSString* encoded = [testString msidUrlFormEncode];
    
    XCTAssertEqualObjects(encoded, @"test+test2");
    XCTAssertEqualObjects([encoded msidUrlFormDecode], testString);
}

- (void)testmsidURLFormEncode_whenHasIllegalChars_shouldEncodeAll
{
    NSString* testString = @"` # % ^ [ ] { } \\ | \" < > ! # $ & ' ( ) * + , / : ; = ? @ [ ] % | ^";
    NSString* encoded = [testString msidUrlFormEncode];
    
    XCTAssertEqualObjects(encoded, @"%60+%23+%25+%5E+%5B+%5D+%7B+%7D+%5C+%7C+%22+%3C+%3E+%21+%23+%24+%26+%27+%28+%29+%2A+%2B+%2C+%2F+%3A+%3B+%3D+%3F+%40+%5B+%5D+%25+%7C+%5E");
    XCTAssertEqualObjects([encoded msidUrlFormDecode], testString);
}

- (void)testmsidURLFormEncode_whenHasLegalChars_shouldNotEncode
{
    NSString* testString = @"test-test2-test3.test4";
    NSString* encoded = [testString msidUrlFormEncode];
    
    XCTAssertEqualObjects(encoded, @"test-test2-test3.test4");
    XCTAssertEqualObjects([encoded msidUrlFormDecode], testString);
}

- (void)testmsidURLFormEncode_whenHasMixedChars_shouldEncode
{
    NSString* testString = @"CODE: The app needs access to a service (\"https://*.test.com/\") that your organization \"test.onmicrosoft.com\" has not subscribed to or enabled.\r\nTrace ID: 111111-1111-1111-1111-111111111111\r\nCorrelation ID: 111111-1111-1111-1111-111111111111\r\nTimestamp: 2000-01-01 23:59:00Z";
    NSString* encoded = [testString msidUrlFormEncode];
    
    XCTAssertEqualObjects(encoded, @"CODE%3A+The+app+needs+access+to+a+service+%28%22https%3A%2F%2F%2A.test.com%2F%22%29+that+your+organization+%22test.onmicrosoft.com%22+has+not+subscribed+to+or+enabled.%0D%0ATrace+ID%3A+111111-1111-1111-1111-111111111111%0D%0ACorrelation+ID%3A+111111-1111-1111-1111-111111111111%0D%0ATimestamp%3A+2000-01-01+23%3A59%3A00Z");
    XCTAssertEqualObjects([encoded msidUrlFormDecode], testString);
}

@end
