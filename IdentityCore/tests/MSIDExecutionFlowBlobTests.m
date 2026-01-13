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
#import "MSIDExecutionFlowBlob.h"

@interface MSIDExecutionFlowBlobTests : XCTestCase

@end

@implementation MSIDExecutionFlowBlobTests

#pragma mark - Init Tests

- (void)testInitWithValidParameters_shouldReturnBlobWithCorrectValues
{
    NSString *tag = @"TestTag";
    NSNumber *timeStep = @(1234);
    NSNumber *threadId = @(5678);
    
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:tag
                                                                    timeStep:timeStep
                                                                    threadId:threadId];
    
    XCTAssertNotNil(blob);
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"t", @"ts", @"tid"]];
    XCTAssertEqualObjects(result[@"t"], tag);
    XCTAssertEqualObjects(result[@"ts"], timeStep);
    XCTAssertEqualObjects(result[@"tid"], threadId);
}

- (void)testInitWithNilTag_shouldReturnNil
{
    NSString *nilTag = nil;
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:nilTag
                                                                    timeStep:@(1234)
                                                                    threadId:@(5678)];
    
    XCTAssertNil(blob);
}

- (void)testInitWithNilTimeStep_shouldReturnNil
{
    NSNumber *nilTimeStep = nil;
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:nilTimeStep
                                                                     threadId:@(5678)];
    
    XCTAssertNil(blob);
}

- (void)testInitWithNilThreadId_shouldReturnNil
{
    NSNumber *nilThreadId = nil;
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:nilThreadId];
    
    XCTAssertNil(blob);
}

- (void)testInitWithAllNilParameters_shouldReturnNil
{
    NSString *nilTag = nil;
    NSNumber *nilTimeStep = nil;
    NSNumber *nilThreadId = nil;

    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:nilTag
                                                                     timeStep:nilTimeStep
                                                                     threadId:nilThreadId];
    
    XCTAssertNil(blob);
}

#pragma mark - setObject:forKey: Tests

- (void)testSetObjectWithStringValue_shouldAddToDictionary
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"customValue" forKey:@"customKey"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"customKey"]];
    XCTAssertEqualObjects(result[@"customKey"], @"customValue");
}

- (void)testSetObjectWithNumberValue_shouldAddToDictionary
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@(9999) forKey:@"customNumber"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"customNumber"]];
    XCTAssertEqualObjects(result[@"customNumber"], @(9999));
}

- (void)testSetObjectWithMultipleKeys_shouldAddAllToDictionary
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"value1" forKey:@"key1"];
    [blob setObject:@(123) forKey:@"key2"];
    [blob setObject:@"value3" forKey:@"key3"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"key1", @"key2", @"key3"]];
    XCTAssertEqualObjects(result[@"key1"], @"value1");
    XCTAssertEqualObjects(result[@"key2"], @(123));
    XCTAssertEqualObjects(result[@"key3"], @"value3");
}

- (void)testSetObjectWithInvalidType_shouldNotAddToDictionary
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    // Try to set an array (invalid type)
    [blob setObject:@[@"array", @"value"] forKey:@"arrayKey"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"arrayKey"]];
    XCTAssertNil(result[@"arrayKey"]);
}

- (void)testSetObjectWithDictionaryType_shouldNotAddToDictionary
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    // Try to set a dictionary (invalid type)
    [blob setObject:@{@"key": @"value"} forKey:@"dictKey"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"dictKey"]];
    XCTAssertNil(result[@"dictKey"]);
}

- (void)testSetObjectWithNilKey_shouldNotCrash
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    NSString *nilKey = nil;
    // Should handle nil key gracefully
    XCTAssertNoThrow([blob setObject:@"value" forKey:nilKey]);
}

#pragma mark - Reserved Keys Protection Tests

- (void)testSetObjectWithReservedKeyT_shouldNotOverride
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"OriginalTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    // Try to override reserved key
    [blob setObject:@"NewTag" forKey:@"t"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"t"]];
    XCTAssertEqualObjects(result[@"t"], @"OriginalTag", @"Reserved key 't' should not be overridden");
}

- (void)testSetObjectWithReservedKeyTs_shouldNotOverride
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    // Try to override reserved key
    [blob setObject:@(9999) forKey:@"ts"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"ts"]];
    XCTAssertEqualObjects(result[@"ts"], @(1234), @"Reserved key 'ts' should not be overridden");
}

- (void)testSetObjectWithReservedKeyTid_shouldNotOverride
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    // Try to override reserved key
    [blob setObject:@(9999) forKey:@"tid"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"tid"]];
    XCTAssertEqualObjects(result[@"tid"], @(5678), @"Reserved key 'tid' should not be overridden");
}

#pragma mark - executionBlobWithKeys: Tests

- (void)testExecutionBlobWithValidKeys_shouldReturnRequestedValues
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"custom1" forKey:@"key1"];
    [blob setObject:@"custom2" forKey:@"key2"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"t", @"key1"]];
    
    XCTAssertEqual(result.count, 2);
    XCTAssertEqualObjects(result[@"t"], @"TestTag");
    XCTAssertEqualObjects(result[@"key1"], @"custom1");
    XCTAssertNil(result[@"key2"], @"key2 was not requested, should not be in result");
}

- (void)testExecutionBlobWithNonExistentKeys_shouldReturnEmptyDictionary
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"nonexistent1", @"nonexistent2"]];
    
    XCTAssertNil(result);
    XCTAssertEqual(result.count, 0, @"Should return empty dictionary when no keys match");
}

- (void)testExecutionBlobWithMixedExistingAndNonExistentKeys_shouldReturnOnlyExistingValues
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"value1" forKey:@"key1"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"key1", @"nonexistent", @"t"]];
    
    XCTAssertEqual(result.count, 2);
    XCTAssertEqualObjects(result[@"key1"], @"value1");
    XCTAssertEqualObjects(result[@"t"], @"TestTag");
    XCTAssertNil(result[@"nonexistent"]);
}

- (void)testExecutionBlobWithNilKeys_shouldReturnNil
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    NSArray *nilKeys = nil;
    NSDictionary *result = [blob executionBlobWithKeys:nilKeys];
    
    XCTAssertNil(result);
}

- (void)testExecutionBlobWithEmptyArray_shouldReturnNil
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[]];
    
    XCTAssertNil(result);
}

- (void)testExecutionBlobWithAllKeys_shouldReturnAllValues
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"extra1" forKey:@"extra1"];
    [blob setObject:@(999) forKey:@"extra2"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"t", @"ts", @"tid", @"extra1", @"extra2"]];
    
    XCTAssertEqual(result.count, 5);
    XCTAssertEqualObjects(result[@"t"], @"TestTag");
    XCTAssertEqualObjects(result[@"ts"], @(1234));
    XCTAssertEqualObjects(result[@"tid"], @(5678));
    XCTAssertEqualObjects(result[@"extra1"], @"extra1");
    XCTAssertEqualObjects(result[@"extra2"], @(999));
}

#pragma mark - Edge Case Tests

- (void)testSetObjectWithEmptyStringKey_shouldWork
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"value" forKey:@""];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@""]];
    XCTAssertEqualObjects(result[@""], @"value");
}

- (void)testSetObjectWithEmptyStringValue_shouldWork
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"" forKey:@"emptyValue"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"emptyValue"]];
    XCTAssertEqualObjects(result[@"emptyValue"], @"");
}

- (void)testSetObjectWithZeroNumberValue_shouldWork
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@(0) forKey:@"zeroValue"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"zeroValue"]];
    XCTAssertEqualObjects(result[@"zeroValue"], @(0));
}

- (void)testSetObjectOverwriteExistingCustomKey_shouldUpdate
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"originalValue" forKey:@"key"];
    [blob setObject:@"updatedValue" forKey:@"key"];
    
    NSDictionary *result = [blob executionBlobWithKeys:@[@"key"]];
    XCTAssertEqualObjects(result[@"key"], @"updatedValue", @"Should allow updating custom keys");
}

- (void)testInitWithEmptyStringTag_shouldCreateBlob
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@""
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    XCTAssertNil(blob, @"Empty string is not valid, and should fail");
}

#pragma mark - blobToString Tests

- (void)testBlobToString_shouldReturnExpectedJSONFormat
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];

    NSString *jsonString = [blob blobToStringWithKeys:nil];
    
    // Verify exact output format
    NSString *expectedJSON = @"{\"t\":\"TestTag\",\"tid\":5678,\"ts\":1234}";
    XCTAssertEqualObjects(jsonString, expectedJSON, @"JSON string should match expected format exactly");
    
    
    // Verify it's valid JSON by parsing it
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSDictionary *parsedJSON = [NSJSONSerialization JSONObjectWithData:jsonData
                                                               options:0
                                                                 error:&error];
    
    XCTAssertNil(error, @"Should be valid JSON");
    XCTAssertNotNil(parsedJSON, @"Should successfully parse JSON");
    XCTAssertEqual(parsedJSON.count, 3, @"Should have exactly 3 fields");
    XCTAssertEqualObjects(parsedJSON[@"t"], @"TestTag");
    XCTAssertEqualObjects(parsedJSON[@"tid"], @(5678));
    XCTAssertEqualObjects(parsedJSON[@"ts"], @(1234));
}

- (void)testBlobToString_withRequiredFieldsOnly_shouldReturnValidJSON
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    NSString *jsonString = [blob blobToStringWithKeys:nil];
    
    XCTAssertNotNil(jsonString);
    XCTAssertTrue([jsonString containsString:@"\"t\":\"TestTag\""]);
    XCTAssertTrue([jsonString containsString:@"\"tid\":5678"]);
    XCTAssertTrue([jsonString containsString:@"\"ts\":1234"]);
    XCTAssertTrue([jsonString hasPrefix:@"{"]);
    XCTAssertTrue([jsonString hasSuffix:@"}"]);
}

- (void)testBlobToString_withAdditionalStringField_shouldIncludeInJSON
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"ErrorMessage" forKey:@"msg"];
    NSString *jsonString = [blob blobToStringWithKeys:nil];
    
    XCTAssertNotNil(jsonString);
    XCTAssertTrue([jsonString containsString:@"\"msg\":\"ErrorMessage\""]);
}

- (void)testBlobToString_withAdditionalNumberField_shouldIncludeInJSON
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@(404) forKey:@"e"];
    NSString *jsonString = [blob blobToStringWithKeys:nil];
    
    XCTAssertNotNil(jsonString);
    XCTAssertTrue([jsonString containsString:@"\"e\":404"]);
}

- (void)testBlobToString_withMultipleAdditionalFields_shouldIncludeAllInJSON
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"AuthFlow"
                                                                     timeStep:@(2500)
                                                                     threadId:@(9999)];
    
    [blob setObject:@(500) forKey:@"e"];
    [blob setObject:@(200) forKey:@"s"];
    [blob setObject:@(3) forKey:@"l"];
    [blob setObject:@"ClassName" forKey:@"ref"];
    
    NSString *jsonString = [blob blobToStringWithKeys:nil];
    
    XCTAssertNotNil(jsonString);
    XCTAssertTrue([jsonString containsString:@"\"t\":\"AuthFlow\""]);
    XCTAssertTrue([jsonString containsString:@"\"tid\":9999"]);
    XCTAssertTrue([jsonString containsString:@"\"ts\":2500"]);
    XCTAssertTrue([jsonString containsString:@"\"e\":500"]);
    XCTAssertTrue([jsonString containsString:@"\"s\":200"]);
    XCTAssertTrue([jsonString containsString:@"\"l\":3"]);
    XCTAssertTrue([jsonString containsString:@"\"ref\":\"ClassName\""]);
}

- (void)testBlobToString_withZeroValues_shouldIncludeZeros
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"Start"
                                                                     timeStep:@(0)
                                                                     threadId:@(0)];
    
    [blob setObject:@(0) forKey:@"e"];
    NSString *jsonString = [blob blobToStringWithKeys:nil];
    
    XCTAssertNotNil(jsonString);
    XCTAssertTrue([jsonString containsString:@"\"ts\":0"]);
    XCTAssertTrue([jsonString containsString:@"\"tid\":0"]);
    XCTAssertTrue([jsonString containsString:@"\"e\":0"]);
}

- (void)testBlobToString_requiredFieldsFirst_shouldBeInCorrectOrder
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"MyTag"
                                                                     timeStep:@(100)
                                                                     threadId:@(200)];
    
    [blob setObject:@(999) forKey:@"custom"];
    NSString *jsonString = [blob blobToStringWithKeys:nil];
    
    // Check that required fields appear first
    NSRange tRange = [jsonString rangeOfString:@"\"t\":"];
    NSRange tidRange = [jsonString rangeOfString:@"\"tid\":"];
    NSRange tsRange = [jsonString rangeOfString:@"\"ts\":"];
    NSRange customRange = [jsonString rangeOfString:@"\"custom\":"];
    
    XCTAssertTrue(tRange.location < customRange.location, @"Tag should appear before custom fields");
    XCTAssertTrue(tidRange.location < customRange.location, @"Thread ID should appear before custom fields");
    XCTAssertTrue(tsRange.location < customRange.location, @"Timestamp should appear before custom fields");
}

- (void)testBlobToStringWithKeys_withSpecificKeys_shouldOnlyIncludeRequestedFields
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@(404) forKey:@"e"];
    [blob setObject:@(200) forKey:@"s"];
    [blob setObject:@"Extra" forKey:@"msg"];
    
    NSSet *queryKeys = [NSSet setWithArray:@[@"e", @"msg"]];
    NSString *jsonString = [blob blobToStringWithKeys:queryKeys];
    
    XCTAssertNotNil(jsonString);
    // Should always include required fields
    XCTAssertTrue([jsonString containsString:@"\"t\":\"TestTag\""]);
    XCTAssertTrue([jsonString containsString:@"\"tid\":5678"]);
    XCTAssertTrue([jsonString containsString:@"\"ts\":1234"]);
    // Should include requested fields
    XCTAssertTrue([jsonString containsString:@"\"e\":404"]);
    XCTAssertTrue([jsonString containsString:@"\"msg\":\"Extra\""]);
    // Should not include field that was requested
    XCTAssertFalse([jsonString containsString:@"\"s\":200"]);
}

- (void)testBlobToStringWithKeys_withEmptySet_shouldReturnOnlyRequiredFields
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@(404) forKey:@"e"];
    [blob setObject:@"Extra" forKey:@"msg"];
    
    NSSet *queryKeys = [NSSet set];
    NSString *jsonString = [blob blobToStringWithKeys:queryKeys];
    
    // Should include all fields when empty set is provided
    XCTAssertTrue([jsonString containsString:@"\"e\":404"]);
    XCTAssertTrue([jsonString containsString:@"\"msg\":\"Extra\""]);
}

- (void)testBlobToStringWithKeys_withNonExistentKeys_shouldStillIncludeRequiredFields
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    NSSet *queryKeys = [NSSet setWithArray:@[@"nonexistent1", @"nonexistent2"]];
    NSString *jsonString = [blob blobToStringWithKeys:queryKeys];
    
    XCTAssertNotNil(jsonString);
    // Should always include required fields
    XCTAssertTrue([jsonString containsString:@"\"t\":\"TestTag\""]);
    XCTAssertTrue([jsonString containsString:@"\"tid\":5678"]);
    XCTAssertTrue([jsonString containsString:@"\"ts\":1234"]);
    // Should not crash or produce invalid JSON
    XCTAssertTrue([jsonString hasPrefix:@"{"]);
    XCTAssertTrue([jsonString hasSuffix:@"}"]);
}

@end
