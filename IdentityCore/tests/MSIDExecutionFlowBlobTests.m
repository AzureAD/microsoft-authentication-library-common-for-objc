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
    
    NSSet<NSString *> *blobKeys = [NSSet setWithArray:@[@"t", @"ts", @"tid"]];
    NSString *jsonString = [blob blobToStringWithKeys:blobKeys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertNotNil(result);
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
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"customKey"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

    XCTAssertEqualObjects(result[@"customKey"], @"customValue");
}

- (void)testSetObjectWithNumberValue_shouldAddToDictionary
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@(9999) forKey:@"customNumber"];
    
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"customNumber"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
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
    
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"key1", @"key2", @"key3"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
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
    
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"arrayKey"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertNil(result[@"arrayKey"]);
}

- (void)testSetObjectWithDictionaryType_shouldNotAddToDictionary
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    // Try to set a dictionary (invalid type)
    [blob setObject:@{@"key": @"value"} forKey:@"dictKey"];

    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"dictKey"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
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
    
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"t"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqualObjects(result[@"t"], @"OriginalTag", @"Reserved key 't' should not be overridden");
}

- (void)testSetObjectWithReservedKeyTs_shouldNotOverride
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    // Try to override reserved key
    [blob setObject:@(9999) forKey:@"ts"];
    
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"ts"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqualObjects(result[@"ts"], @(1234), @"Reserved key 'ts' should not be overridden");
}

- (void)testSetObjectWithReservedKeyTid_shouldNotOverride
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    // Try to override reserved key
    [blob setObject:@(9999) forKey:@"tid"];
    
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"tid"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
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
    
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"t", @"key1"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqual(result.count, 4);
    XCTAssertEqualObjects(result[@"t"], @"TestTag");
    XCTAssertEqualObjects(result[@"key1"], @"custom1");
    XCTAssertNil(result[@"key2"], @"key2 was not requested, should not be in result");
}

- (void)testExecutionBlobWithNonExistentKeys_shouldReturnDictionaryWithRequiredFieldOnly
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"nonexistent1", @"nonexistent2"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    XCTAssertNotNil(result);
    XCTAssertEqual(result.allKeys.count, 3, @"Should return empty dictionary when no keys match");
}

- (void)testExecutionBlobWithMixedExistingAndNonExistentKeys_shouldReturnOnlyExistingValues
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"value1" forKey:@"key1"];
    
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"key1", @"nonexistent", @"t"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    XCTAssertEqual(result.allKeys.count, 4);
    XCTAssertEqualObjects(result[@"key1"], @"value1");
    XCTAssertEqualObjects(result[@"t"], @"TestTag");
    XCTAssertNil(result[@"nonexistent"]);
}

- (void)testExecutionBlobWithNilKeys_shouldReturnEverything
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    [blob setObject:@1003 forKey:@"e"];
    NSArray *nilKeys = nil;
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:nilKeys]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.allKeys.count, 4);
}

- (void)testExecutionBlobWithEmptyArray_shouldReturnEverything
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    [blob setObject:@1003 forKey:@"e"];
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.allKeys.count, 4);
}

- (void)testExecutionBlobWithAllKeys_shouldReturnAllValues
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"extra1" forKey:@"extra1"];
    [blob setObject:@(999) forKey:@"extra2"];
    
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"t", @"ts", @"tid", @"extra1", @"extra2"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
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

    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@""]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqualObjects(result[@""], @"value");
}

- (void)testSetObjectWithEmptyStringValue_shouldWork
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"" forKey:@"emptyValue"];
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"emptyValue"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqualObjects(result[@"emptyValue"], @"");
}

- (void)testSetObjectWithZeroNumberValue_shouldWork
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@(0) forKey:@"zeroValue"];
    
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"zeroValue"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqualObjects(result[@"zeroValue"], @(0));
}

- (void)testSetObjectOverwriteExistingCustomKey_shouldUpdate
{
    MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:@"TestTag"
                                                                     timeStep:@(1234)
                                                                     threadId:@(5678)];
    
    [blob setObject:@"originalValue" forKey:@"key"];
    [blob setObject:@"updatedValue" forKey:@"key"];
    
    NSString *jsonString = [blob blobToStringWithKeys:[NSSet setWithArray:@[@"key"]]];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
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
    NSString *expectedJSON = @"{\"t\":\"TestTag\",\"ts\":1234,\"tid\":5678}";
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
