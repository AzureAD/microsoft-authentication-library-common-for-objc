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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
    XCTAssertNil(result, @"Should return nil for empty flow");
}

#pragma mark - insertTag:triggeringTime:threadId:extraInfo: Tests

- (void)testInsertTagWithValidParameters_shouldAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"TestTag" triggeringTime:[NSDate date] threadId:@(12345) extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"ts", @"tid"]];
    XCTAssertNotNil(result);
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
    XCTAssertNil(result, @"Should not add blob with nil tag");
}

- (void)testInsertTagWithEmptyTag_shouldNotAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"" triggeringTime:[NSDate date] threadId:@(12345) extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
    XCTAssertNil(result, @"Should not add blob with empty tag");
}

- (void)testInsertTagWithNilThreadId_shouldNotAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    NSNumber *nilTid = nil;
    [flow insertTag:@"TestTag" triggeringTime:[NSDate date] threadId:nilTid extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
    XCTAssertNil(result, @"Should not add blob with nil threadId");
}

- (void)testInsertTagWithNilTriggeringTime_shouldNotAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    NSDate *nilTriggeringTime = nil;
    [flow insertTag:@"TestTag" triggeringTime:nilTriggeringTime threadId:@(12345) extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"key1", @"key2", @"key3"]];
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"ts", @"tid"]];
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"ts", @"tid", @"custom"]];
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"ts"]];
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"ts"]];
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"ts"]];
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"ts"]];
    
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"tid"]];
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"tid"]];
    XCTAssertEqual(result.count, 3);
    
    XCTAssertEqualObjects(result[0][@"tid"], @(111));
    XCTAssertEqualObjects(result[1][@"tid"], @(222));
    XCTAssertEqualObjects(result[2][@"tid"], @(333));
}

#pragma mark - executionFlowWithKeys: Tests

- (void)testExecutionFlowWithNilKeys_shouldReturnNil
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    [flow insertTag:@"Tag" triggeringTime:[NSDate date] threadId:@(12345) extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:nil];
    
    XCTAssertNil(result);
}

- (void)testExecutionFlowWithEmptyKeys_shouldReturnNil
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    [flow insertTag:@"Tag" triggeringTime:[NSDate date] threadId:@(12345) extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[]];
    
    XCTAssertNil(result);
}

- (void)testExecutionFlowWithNonExistentKeys_shouldReturnNil
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    [flow insertTag:@"Tag" triggeringTime:[NSDate date] threadId:@(12345) extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"nonexistent1", @"nonexistent2"]];
    
    XCTAssertNil(result, @"Should return nil when no keys match any blob");
}

- (void)testExecutionFlowWithValidKeys_shouldReturnOnlyRequestedKeys
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    NSDictionary *extraInfo = @{
        @"key1": @"value1",
        @"key2": @"value2",
        @"key3": @"value3"
    };
    [flow insertTag:@"Tag" triggeringTime:[NSDate date] threadId:@(12345) extraInfo:extraInfo];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"key1"]];
    XCTAssertEqual(result.count, 1);
    
    NSDictionary *blob = result[0];
    XCTAssertEqual(blob.count, 2);
    XCTAssertEqualObjects(blob[@"t"], @"Tag");
    XCTAssertEqualObjects(blob[@"key1"], @"value1");
    XCTAssertNil(blob[@"key2"], @"key2 should not be included");
    XCTAssertNil(blob[@"key3"], @"key3 should not be included");
}

- (void)testExecutionFlowWithMultipleBlobs_shouldReturnAllMatchingBlobs
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag1" triggeringTime:[NSDate date] threadId:@(111) extraInfo:@{@"custom": @"value1"}];
    [flow insertTag:@"Tag2" triggeringTime:[NSDate date] threadId:@(222) extraInfo:@{@"custom": @"value2"}];
    [flow insertTag:@"Tag3" triggeringTime:[NSDate date] threadId:@(333) extraInfo:@{@"custom": @"value3"}];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"custom"]];
    XCTAssertEqual(result.count, 3);
    
    XCTAssertEqualObjects(result[0][@"t"], @"Tag1");
    XCTAssertEqualObjects(result[0][@"custom"], @"value1");
    XCTAssertEqualObjects(result[1][@"t"], @"Tag2");
    XCTAssertEqualObjects(result[1][@"custom"], @"value2");
    XCTAssertEqualObjects(result[2][@"t"], @"Tag3");
    XCTAssertEqualObjects(result[2][@"custom"], @"value3");
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
    
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
    
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
    XCTAssertEqual(result.count, 20, @"All inserts should succeed");
}

- (void)testConcurrentInsertAndRead_shouldNotCrash
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
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
            [flow executionFlowWithKeys:@[@"t", @"ts", @"tid"]];
        });
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // Should not crash
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
    XCTAssertNotNil(result);
}

#pragma mark - Edge Case Tests

- (void)testInsertTagWithWhitespaceTag_shouldNotAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"   " triggeringTime:[NSDate date] threadId:@(12345) extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
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
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"validString", @"validNumber", @"invalidArray", @"invalidDict"]];
    XCTAssertEqual(result.count, 1);
    
    NSDictionary *blob = result[0];
    XCTAssertEqualObjects(blob[@"validString"], @"value");
    XCTAssertEqualObjects(blob[@"validNumber"], @(123));
    XCTAssertNil(blob[@"invalidArray"], @"Array should be filtered out");
    XCTAssertNil(blob[@"invalidDict"], @"Dictionary should be filtered out");
}

- (void)testExecutionFlowWithMixedExistingAndNonExistentKeys_shouldReturnOnlyExisting
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag" triggeringTime:[NSDate date] threadId:@(12345) extraInfo:@{@"key1": @"value1"}];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"key1", @"nonexistent"]];
    XCTAssertEqual(result.count, 1);
    
    NSDictionary *blob = result[0];
    XCTAssertEqual(blob.count, 2);
    XCTAssertEqualObjects(blob[@"t"], @"Tag");
    XCTAssertEqualObjects(blob[@"key1"], @"value1");
}

- (void)testInsertTagWithZeroThreadId_shouldAcceptZero
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag" triggeringTime:[NSDate date] threadId:@(0) extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"tid"]];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result[0][@"tid"], @(0), @"Zero thread ID should be valid");
}

@end
