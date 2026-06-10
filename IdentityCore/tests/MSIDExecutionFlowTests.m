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
#import "MSIDExecutionFlow.h"

@interface MSIDExecutionFlowTests : XCTestCase

@end

@implementation MSIDExecutionFlowTests

#pragma mark - Init Tests

- (void)testInit_shouldCreateInstanceWithEmptyFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    XCTAssertNotNil(flow);
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *result = [flow exportExecutionFlowToJSONsWithKeys:keys];
    XCTAssertNil(result, @"Should return nil for empty flow");
}

#pragma mark - insertTag:triggeringTime:threadId:extraInfo: Tests

- (void)testInsertTagWithValidParameters_shouldAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"TestTag" triggeringTime:[NSDate date] threadId:@(12345) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"ts", @"tid"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    XCTAssertNotNil(jsonString);
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqual(result.count, 1);
    
    NSDictionary *blob = result[0];
    XCTAssertEqualObjects(blob[@"t"], @"TestTag");
    XCTAssertNotNil(blob[@"ts"], @"Timestamp should be present");
    XCTAssertEqualObjects(blob[@"tid"], @(12345));
}

- (void)testInsertTagWithNilTag_shouldNotAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    NSString *nilTag = nil;
    [flow insertTag:nilTag triggeringTime:[NSDate date] threadId:@(12345) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *result = [flow exportExecutionFlowToJSONsWithKeys:keys];
    XCTAssertNil(result, @"Should not add blob with nil tag");
}

- (void)testInsertTagWithEmptyTag_shouldNotAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"" triggeringTime:[NSDate date] threadId:@(12345) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *result = [flow exportExecutionFlowToJSONsWithKeys:keys];
    XCTAssertNil(result, @"Should not add blob with empty tag");
}

- (void)testInsertTagWithNilThreadId_shouldNotAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    NSNumber *nilTid = nil;
    [flow insertTag:@"TestTag" triggeringTime:[NSDate date] threadId:nilTid extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *result = [flow exportExecutionFlowToJSONsWithKeys:keys];
    XCTAssertNil(result, @"Should not add blob with nil threadId");
}

- (void)testInsertTagWithNilTriggeringTime_shouldNotAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    NSDate *nilTriggeringTime = nil;
    [flow insertTag:@"TestTag" triggeringTime:nilTriggeringTime threadId:@(12345) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *result = [flow exportExecutionFlowToJSONsWithKeys:keys];
    XCTAssertNil(result, @"Should not add blob with nil triggeringTime");
}

- (void)testInsertTagWithExtraInfo_shouldAddAllInfoToBlob
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    NSDictionary *extraInfo = @{
        @"key1": @"value1",
        @"key2": @(123),
        @"key3": @"value3"
    };
    
    [flow insertTag:@"TestTag" triggeringTime:[NSDate date] threadId:@(12345) extraInfo:extraInfo];
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"key1", @"key2", @"key3"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqual(result.count, 1);
    
    NSDictionary *blob = result[0];
    XCTAssertEqualObjects(blob[@"t"], @"TestTag");
    XCTAssertEqualObjects(blob[@"key1"], @"value1");
    XCTAssertEqualObjects(blob[@"key2"], @(123));
    XCTAssertEqualObjects(blob[@"key3"], @"value3");
}

- (void)testInsertTagWithEmptyExtraInfo_shouldOnlyAddRequiredFields
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"TestTag" triggeringTime:[NSDate date] threadId:@(12345) extraInfo:@{}];
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"ts", @"tid"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqual(result.count, 1);
    
    NSDictionary *blob = result[0];
    XCTAssertEqualObjects(blob[@"t"], @"TestTag");
    XCTAssertNotNil(blob[@"ts"]);
    XCTAssertEqualObjects(blob[@"tid"], @(12345));
}

- (void)testInsertTagMultipleTimes_shouldMaintainOrder
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag1" triggeringTime:[NSDate date] threadId:@(111) extraInfo:nil];
    [flow insertTag:@"Tag2" triggeringTime:[NSDate date] threadId:@(222) extraInfo:nil];
    [flow insertTag:@"Tag3" triggeringTime:[NSDate date] threadId:@(333) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqual(result.count, 3);
    XCTAssertEqualObjects(result[0][@"t"], @"Tag1");
    XCTAssertEqualObjects(result[1][@"t"], @"Tag2");
    XCTAssertEqualObjects(result[2][@"t"], @"Tag3");
}

- (void)testInsertTagWithExtraInfoContainingReservedKeys_shouldNotOverrideReservedKeys
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    NSDictionary *extraInfo = @{
        @"t": @"ShouldNotOverride",
        @"ts": @(9999),
        @"tid": @(8888),
        @"custom": @"value"
    };
    
    [flow insertTag:@"OriginalTag" triggeringTime:[NSDate date] threadId:@(5678) extraInfo:extraInfo];
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"ts", @"tid", @"custom"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqual(result.count, 1);
    
    NSDictionary *blob = result[0];
    XCTAssertEqualObjects(blob[@"t"], @"OriginalTag", @"Tag should not be overridden");
    XCTAssertNotEqualObjects(blob[@"ts"], @(9999), @"Timestamp should not be overridden");
    XCTAssertEqualObjects(blob[@"tid"], @(5678), @"Thread ID should match the provided one");
    XCTAssertEqualObjects(blob[@"custom"], @"value", @"Custom key should be added");
}

#pragma mark - Timestamp Tests

- (void)testInsertTag_firstTagShouldHaveZeroTimestamp
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag1" triggeringTime:[NSDate date] threadId:@(111) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"ts"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqual(result.count, 1);
    
    NSNumber *ts1 = result[0][@"ts"];
    XCTAssertEqual(ts1.longLongValue, 0, @"First tag should have timestamp 0");
}

- (void)testInsertTag_subsequentTagsShouldHaveIncreasingTimestamps
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    NSDate *baseTime = [NSDate date];
    [flow insertTag:@"Tag1" triggeringTime:baseTime threadId:@(111) extraInfo:nil];
    
    [NSThread sleepForTimeInterval:0.05]; // Sleep 50ms
    NSDate *time2 = [NSDate date];
    [flow insertTag:@"Tag2" triggeringTime:time2 threadId:@(222) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"ts"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqual(result.count, 2);
    
    NSNumber *ts1 = result[0][@"ts"];
    NSNumber *ts2 = result[1][@"ts"];
    
    XCTAssertEqual(ts1.longLongValue, 0, @"First tag should have timestamp 0");
    XCTAssertGreaterThan(ts2.longLongValue, ts1.longLongValue, @"Second timestamp should be greater");
}

- (void)testInsertTagWithSpecificTriggeringTime_shouldUseProvidedTime
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    NSDate *baseTime = [NSDate date];
    NSDate *specificTime1 = baseTime;
    NSDate *specificTime2 = [NSDate dateWithTimeInterval:0.1 sinceDate:baseTime]; // 100ms later
    
    [flow insertTag:@"Tag1" triggeringTime:specificTime1 threadId:@(111) extraInfo:nil];
    [flow insertTag:@"Tag2" triggeringTime:specificTime2 threadId:@(222) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"ts"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqual(result.count, 2);
    
    NSNumber *ts1 = result[0][@"ts"];
    NSNumber *ts2 = result[1][@"ts"];
    
    XCTAssertEqual(ts1.longLongValue, 0, @"First tag should have timestamp 0");
    XCTAssertGreaterThanOrEqual(ts2.longLongValue, 90, @"Second tag should be ~100ms later");
    XCTAssertLessThanOrEqual(ts2.longLongValue, 110, @"Second tag should be ~100ms later with tolerance");
}

- (void)testInsertTag_timestampShouldBeInMilliseconds
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    NSDate *baseTime = [NSDate date];
    [flow insertTag:@"Tag1" triggeringTime:baseTime threadId:@(111) extraInfo:nil];
    
    NSDate *laterTime = [NSDate dateWithTimeInterval:0.1 sinceDate:baseTime];
    [flow insertTag:@"Tag2" triggeringTime:laterTime threadId:@(222) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"ts"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    NSNumber *ts1 = result[0][@"ts"];
    NSNumber *ts2 = result[1][@"ts"];
    
    XCTAssertEqual(ts1.longLongValue, 0);
    XCTAssertGreaterThanOrEqual(ts2.longLongValue, 90, @"Should be approximately 100ms");
    XCTAssertLessThanOrEqual(ts2.longLongValue, 110, @"Should be approximately 100ms with tolerance");
}

#pragma mark - Thread ID Tests

- (void)testInsertTagWithSpecificThreadId_shouldUseProvidedThreadId
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag" triggeringTime:[NSDate date] threadId:@(99999) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"tid"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    NSDictionary *blob = result[0];
    NSNumber *tid = blob[@"tid"];
    
    XCTAssertEqualObjects(tid, @(99999));
}

- (void)testInsertTagWithDifferentThreadIds_shouldPreserveEachThreadId
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag1" triggeringTime:[NSDate date] threadId:@(111) extraInfo:nil];
    [flow insertTag:@"Tag2" triggeringTime:[NSDate date] threadId:@(222) extraInfo:nil];
    [flow insertTag:@"Tag3" triggeringTime:[NSDate date] threadId:@(333) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"tid"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqual(result.count, 3);
    
    XCTAssertEqualObjects(result[0][@"tid"], @(111));
    XCTAssertEqualObjects(result[1][@"tid"], @(222));
    XCTAssertEqualObjects(result[2][@"tid"], @(333));
}

#pragma mark - Max Capacity Tests

- (void)testInsertTag_whenExceedingMaxCapacity_shouldRemoveOldestEntries
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    // Insert more than MAX_EXECUTION_FLOW_SIZE (50) entries
    for (int i = 0; i < 55; i++) {
        [flow insertTag:[NSString stringWithFormat:@"Tag%d", i] 
         triggeringTime:[NSDate date]
               threadId:@(i) 
              extraInfo:nil];
    }
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    // Should only have 50 entries
    XCTAssertEqual(result.count, 50);
    
    // First entry should be Tag5 (0-4 should be removed)
    XCTAssertEqualObjects(result[0][@"t"], @"Tag5");
    
    // Last entry should be Tag54
    XCTAssertEqualObjects(result[49][@"t"], @"Tag54");
}

- (void)testInsertTag_atExactlyMaxCapacity_shouldNotRemoveEntries
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    // Insert exactly MAX_EXECUTION_FLOW_SIZE (50) entries
    for (int i = 0; i < 50; i++) {
        [flow insertTag:[NSString stringWithFormat:@"Tag%d", i] 
         triggeringTime:[NSDate date]
               threadId:@(i) 
              extraInfo:nil];
    }
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    XCTAssertEqual(result.count, 50);
    XCTAssertEqualObjects(result[0][@"t"], @"Tag0");
    XCTAssertEqualObjects(result[49][@"t"], @"Tag49");
}

#pragma mark - Thread Safety Tests

- (void)testConcurrentInserts_shouldHandleThreadSafely
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // Insert from multiple threads
    for (int i = 0; i < 20; i++) {
        dispatch_group_async(group, queue, ^{
            [flow insertTag:[NSString stringWithFormat:@"Tag%d", i] 
             triggeringTime:[NSDate date]
                   threadId:@(i) 
                  extraInfo:nil];
        });
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqual(result.count, 20, @"All inserts should succeed");
}

- (void)testConcurrentInsertAndRead_shouldNotCrash
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"ts", @"tid"]];
    
    // Concurrent inserts
    for (int i = 0; i < 10; i++) {
        dispatch_group_async(group, queue, ^{
            [flow insertTag:[NSString stringWithFormat:@"Tag%d", i] 
             triggeringTime:[NSDate date]
                   threadId:@(i) 
                  extraInfo:nil];
        });
    }
    
    // Concurrent reads
    for (int i = 0; i < 10; i++) {
        dispatch_group_async(group, queue, ^{
            [flow exportExecutionFlowToJSONsWithKeys:keys];
        });
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // Should not crash
    NSString *result = [flow exportExecutionFlowToJSONsWithKeys:keys];
    XCTAssertNotNil(result);
}

#pragma mark - Edge Case Tests

- (void)testInsertTagWithWhitespaceTag_shouldNotAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"   " triggeringTime:[NSDate date] threadId:@(12345) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *result = [flow exportExecutionFlowToJSONsWithKeys:keys];
    XCTAssertNil(result, @"Should not add blob with whitespace-only tag");
}

- (void)testInsertTagWithExtraInfoContainingInvalidTypes_shouldFilterOutInvalidValues
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    NSDictionary *extraInfo = @{
        @"validString": @"value",
        @"validNumber": @(123),
        @"invalidArray": @[@"array"],
        @"invalidDict": @{@"key": @"value"}
    };
    
    [flow insertTag:@"Tag" triggeringTime:[NSDate date] threadId:@(12345) extraInfo:extraInfo];
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"validString", @"validNumber", @"invalidArray", @"invalidDict"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertEqual(result.count, 1);
    
    NSDictionary *blob = result[0];
    XCTAssertEqualObjects(blob[@"validString"], @"value");
    XCTAssertEqualObjects(blob[@"validNumber"], @(123));
    XCTAssertNil(blob[@"invalidArray"], @"Array should be filtered out");
    XCTAssertNil(blob[@"invalidDict"], @"Dictionary should be filtered out");
}

- (void)testInsertTagWithZeroThreadId_shouldAcceptZero
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag" triggeringTime:[NSDate date] threadId:@(0) extraInfo:nil];
    
    NSSet *keys = [NSSet setWithArray:@[@"tid"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:keys];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result[0][@"tid"], @(0), @"Zero thread ID should be valid");
}

#pragma mark - exportExecutionFlowToJSONsWithKeys: Tests

- (void)testExportExecutionFlowToJSONs_withValidKeys_shouldReturnJSONArray
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag1" triggeringTime:[NSDate date] threadId:@(111) extraInfo:@{@"e": @(404)}];
    [flow insertTag:@"Tag2" triggeringTime:[NSDate date] threadId:@(222) extraInfo:@{@"e": @(500)}];
    
    NSSet *queryKeys = [NSSet setWithArray:@[@"e"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:queryKeys];
    
    XCTAssertNotNil(jsonString);
    XCTAssertTrue([jsonString hasPrefix:@"["]);
    XCTAssertTrue([jsonString hasSuffix:@"]"]);
    XCTAssertTrue([jsonString containsString:@"\"t\":\"Tag1\""]);
    XCTAssertTrue([jsonString containsString:@"\"t\":\"Tag2\""]);
    XCTAssertTrue([jsonString containsString:@"\"e\":404"]);
    XCTAssertTrue([jsonString containsString:@"\"e\":500"]);
}

- (void)testExportExecutionFlowToJSONs_withNilKeys_shouldReturnDefault
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag1" triggeringTime:[NSDate date] threadId:@(111) extraInfo:nil];
    
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:nil];
    
    XCTAssertNotNil(jsonString);
}

- (void)testExportExecutionFlowToJSONs_withEmptySet_shouldReturnDefault
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag1" triggeringTime:[NSDate date] threadId:@(111) extraInfo:nil];
    
    NSSet *emptySet = [NSSet set];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:emptySet];
    
    XCTAssertNotNil(jsonString);
}

- (void)testExportExecutionFlowToJSONs_withEmptyFlow_shouldReturnNil
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    NSSet *queryKeys = [NSSet setWithArray:@[@"t", @"ts", @"tid"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:queryKeys];
    
    XCTAssertNil(jsonString, @"Should return nil for empty flow");
}

- (void)testExportExecutionFlowToJSONs_shouldReturnValidJSON
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    NSDate *baseTime = [NSDate date];
    [flow insertTag:@"Tag1" triggeringTime:baseTime threadId:@(111) extraInfo:@{@"e": @(404)}];
    [flow insertTag:@"Tag2" triggeringTime:[NSDate dateWithTimeInterval:0.1 sinceDate:baseTime] threadId:@(222) extraInfo:@{@"s": @(200)}];
    
    NSSet *queryKeys = [NSSet setWithArray:@[@"e", @"s"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:queryKeys];
    
    XCTAssertNotNil(jsonString);
    
    // Verify it's valid JSON by parsing it
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSArray *parsedJSON = [NSJSONSerialization JSONObjectWithData:jsonData
                                                          options:0
                                                            error:&error];
    
    XCTAssertNil(error, @"Should be valid JSON");
    XCTAssertNotNil(parsedJSON, @"Should successfully parse JSON");
    XCTAssertEqual(parsedJSON.count, 2, @"Should have 2 blob entries");
    
    // Verify first blob
    NSDictionary *blob1 = parsedJSON[0];
    XCTAssertEqualObjects(blob1[@"t"], @"Tag1");
    XCTAssertEqualObjects(blob1[@"tid"], @(111));
    XCTAssertEqualObjects(blob1[@"e"], @(404));
    
    // Verify second blob
    NSDictionary *blob2 = parsedJSON[1];
    XCTAssertEqualObjects(blob2[@"t"], @"Tag2");
    XCTAssertEqualObjects(blob2[@"tid"], @(222));
    XCTAssertEqualObjects(blob2[@"s"], @(200));
}

- (void)testExportExecutionFlowToJSONs_withMultipleBlobs_shouldMaintainOrder
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    for (int i = 0; i < 5; i++) {
        [flow insertTag:[NSString stringWithFormat:@"Tag%d", i] 
         triggeringTime:[NSDate date]
               threadId:@(i * 100) 
              extraInfo:@{@"index": @(i)}];
    }
    
    NSSet *queryKeys = [NSSet setWithArray:@[@"index"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:queryKeys];
    
    XCTAssertNotNil(jsonString);
    
    // Parse and verify order
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *parsedJSON = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    XCTAssertEqual(parsedJSON.count, 5);
    for (int i = 0; i < 5; i++) {
        NSDictionary *blob = parsedJSON[i];
        NSString *expectedResult = [NSString stringWithFormat:@"Tag%d", i];
        XCTAssertEqualObjects(blob[@"t"], expectedResult);
        XCTAssertEqualObjects(blob[@"index"], @(i));
    }
}

- (void)testExportExecutionFlowToJSONs_withSpecificKeys_shouldFilterFields
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    NSDictionary *extraInfo = @{
        @"e": @(404),
        @"s": @(200),
        @"l": @(3),
        @"msg": @"error"
    };
    [flow insertTag:@"Tag1" triggeringTime:[NSDate date] threadId:@(111) extraInfo:extraInfo];
    
    // Only request specific keys
    NSSet *queryKeys = [NSSet setWithArray:@[@"e", @"msg", @"s"]];
    NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:queryKeys];
    
    XCTAssertNotNil(jsonString);
    
    // Parse and verify only requested keys are included (plus required fields)
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *parsedJSON = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    NSDictionary *blob = parsedJSON[0];
    // Should have required fields always
    XCTAssertNotNil(blob[@"t"]);
    XCTAssertNotNil(blob[@"tid"]);
    XCTAssertNotNil(blob[@"ts"]);
    // Should have requested fields
    XCTAssertEqualObjects(blob[@"e"], @(404));
    XCTAssertEqualObjects(blob[@"msg"], @"error");
    XCTAssertEqualObjects(blob[@"s"], @(200));
    // Should not have non-requested fields
    XCTAssertNil(blob[@"l"]);
}

- (void)testExportExecutionFlowToJSONs_concurrentAccess_shouldNotCrash
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    // Add some initial data
    for (int i = 0; i < 10; i++) {
        [flow insertTag:[NSString stringWithFormat:@"Tag%d", i] 
         triggeringTime:[NSDate date]
               threadId:@(i) 
              extraInfo:nil];
    }
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    NSSet *queryKeys = [NSSet setWithArray:@[@"t"]];
    
    // Concurrent reads
    for (int i = 0; i < 10; i++) {
        dispatch_group_async(group, queue, ^{
            NSString *jsonString = [flow exportExecutionFlowToJSONsWithKeys:queryKeys];
            XCTAssertNotNil(jsonString);
        });
    }
    
    // Concurrent inserts
    for (int i = 0; i < 10; i++) {
        dispatch_group_async(group, queue, ^{
            [flow insertTag:[NSString stringWithFormat:@"NewTag%d", i] 
             triggeringTime:[NSDate date]
                   threadId:@(i + 100) 
                  extraInfo:nil];
        });
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // Should not crash and should return valid result
    NSString *finalResult = [flow exportExecutionFlowToJSONsWithKeys:queryKeys];
    XCTAssertNotNil(finalResult);
}

@end
