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

- (void)testMsidURLFormEncode_whenKeyAndValueAreStrings_shouldReturnUrlEncodedString
{
    NSDictionary *dictionary = @{@"key": @"value"};
    
    id result = [dictionary msidURLFormEncode];

    XCTAssertEqualObjects(result, @"key=value");
}

- (void)testMsidURLFormEncode_whenKeyStringValueUUID_shouldReturnUrlEncodedString
{
    NSDictionary *dictionary = @{@"key": [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"]};
    
    id result = [dictionary msidURLFormEncode];
    
    XCTAssertEqualObjects(result, @"key=E621E1F8-C36C-495A-93FC-0C247A3E6E5F");
}

- (void)testDictionaryByRemovingFields_whenNilKeysArray_shouldNotRemoveFields
{
    NSDictionary *inputDictionary = @{@"key1": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSDictionary *resultDictionary = [inputDictionary dictionaryByRemovingFields:nil];
    XCTAssertEqualObjects(inputDictionary, resultDictionary);
}

- (void)testDictionaryByRemovingFields_whenEmptyKeysArray_shouldNotRemoveFields
{
    NSDictionary *inputDictionary = @{@"key1": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSDictionary *resultDictionary = [inputDictionary dictionaryByRemovingFields:@[]];
    XCTAssertEqualObjects(inputDictionary, resultDictionary);
}

- (void)testDictionaryByRemovingFields_whenDictionaryWithFields_shouldRemoveFields
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
    BOOL result = [inputDictionary assertContainsField:@"key1" context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testAssertContainsField_whenFieldIsNotInDictionary_shouldReturnFalse
{
    NSDictionary *inputDictionary = @{@"key4": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSError *error;
    BOOL result = [inputDictionary assertContainsField:@"key1" context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
}

- (void)testAssertType_whenFieldOfCorrectType_shouldReturnTrue
{
    NSDictionary *inputDictionary = @{@"key1": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSError *error;
    BOOL result = [inputDictionary assertType:NSString.class ofField:@"key1" context:nil errorCode:1 error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testAssertType_whenFieldOfIncorrectType_shouldReturnFalse
{
    NSDictionary *inputDictionary = @{@"key1": @1,
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSError *error;
    BOOL result = [inputDictionary assertType:NSString.class ofField:@"key1" context:nil errorCode:1 error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertFalse(result);
}

@end
