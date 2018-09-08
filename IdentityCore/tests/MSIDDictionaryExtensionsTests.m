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
#import "NSDictionary+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"

@interface MSIDDictionaryExtensionsTests : XCTestCase

@end

@implementation MSIDDictionaryExtensionsTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testMsidDictionaryFromQueryString_whenStringContainsQuery_shouldReturnDictWithoutDecoding
{
    NSString *string = @"key=val+val";
    NSDictionary *dict = [NSDictionary msidDictionaryFromQueryString:string];
    
    XCTAssertTrue([[dict allKeys] containsObject:@"key"]);
    XCTAssertEqualObjects(dict[@"key"], @"val+val");
}

- (void)testmsidDictionaryFromWwwUrlFormEncodedString_whenStringContainsQuery_shouldReturnDictWithDecoding
{
    NSString *string = @"key=Some+interesting+test%2F%2B-%29%28%2A%26%5E%25%24%23%40%21~%7C";
    NSDictionary *dict = [NSDictionary msidDictionaryFromWwwUrlFormEncodedString:string];
    
    XCTAssertTrue([[dict allKeys] containsObject:@"key"]);
    XCTAssertEqualObjects(dict[@"key"], @"Some interesting test/+-)(*&^%$#@!~|");
}

- (void)testMsidDictionaryFromQueryString_whenMalformedQuery_shouldReturnDictWithoutBadQuery
{
    NSString *string = @"key=val+val&malformed=v1=v2&=noval";
    NSDictionary *dict = [NSDictionary msidDictionaryFromQueryString:string];
    
    XCTAssertTrue(dict.count == 1);
    XCTAssertTrue([dict.allKeys containsObject:@"key"]);
    
    XCTAssertEqualObjects(dict[@"key"], @"val+val");
}


- (void)testMsidDictionaryByRemovingFields_whenNilKeysArray_shouldNotRemoveFields
{
    NSDictionary *inputDictionary = @{@"key":@"",
                                      @"key1": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    NSDictionary *resultDictionary = [inputDictionary dictionaryByRemovingFields:nil];
    XCTAssertEqualObjects(inputDictionary, resultDictionary);
}

- (void)testMsidDictionaryByRemovingFields_whenEmptyKeysArray_shouldNotRemoveFields
{
    NSDictionary *inputDictionary = @{@"key1": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSDictionary *resultDictionary = [inputDictionary dictionaryByRemovingFields:@[]];
    XCTAssertEqualObjects(inputDictionary, resultDictionary);
}

- (void)testMsidDictionaryByRemovingFields_whenDictionaryWithFields_shouldRemoveFields
{
    NSDictionary *inputDictionary = @{@"key1": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSArray *keysArray = @[@"key2", @"key1"];
    NSDictionary *resultDictionary = [inputDictionary dictionaryByRemovingFields:keysArray];
    
    NSDictionary *expectedDictionary = @{@"key3": @"value3"};
    XCTAssertEqualObjects(resultDictionary, expectedDictionary);
}

- (void)testAssertContainsField_whenFieldIsInDictionary_shouldReturnTrue
{
    NSDictionary *inputDictionary = @{@"key1": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSError *error;
    BOOL result = [inputDictionary msidAssertContainsField:@"key1" context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testAssertContainsField_whenFieldIsNotInDictionary_shouldReturnFalse
{
    NSDictionary *inputDictionary = @{@"key4": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSError *error;
    BOOL result = [inputDictionary msidAssertContainsField:@"key1" context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"key1 is missing.");
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testAssertType_whenFieldOfCorrectType_shouldReturnTrue
{
    NSDictionary *inputDictionary = @{@"key1": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSError *error;
    BOOL result = [inputDictionary msidAssertType:NSString.class ofField:@"key1" context:nil errorCode:1 error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testAssertType_whenFieldOfIncorrectType_shouldReturnFalse
{
    NSDictionary *inputDictionary = @{@"key1": @1,
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSError *error;
    BOOL result = [inputDictionary msidAssertType:NSString.class ofField:@"key1" context:nil errorCode:1 error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"key1 is not a NSString.");
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, 1);
}

@end
