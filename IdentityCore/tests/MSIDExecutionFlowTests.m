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

#pragma mark - insertTag:extraInfo: Tests

- (void)testInsertTagWithValidTag_shouldAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"TestTag" extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"ts", @"tid"]];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    
    NSDictionary *blob = result[0];
    XCTAssertEqualObjects(blob[@"t"], @"TestTag");
    XCTAssertNotNil(blob[@"ts"], @"Timestamp should be present");
    XCTAssertNotNil(blob[@"tid"], @"Thread ID should be present");
}

- (void)testInsertTagWithNilTag_shouldNotAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    NSString *nilTag = nil;
    NSDictionary *nilExtraInfo = nil;
    [flow insertTag:nilTag extraInfo:nilExtraInfo];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
    XCTAssertNil(result, @"Should not add blob with nil tag");
}

- (void)testInsertTagWithExtraInfo_shouldAddAllInfoToBlob
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    NSDictionary *extraInfo = @{
        @"key1": @"value1",
        @"key2": @(123),
        @"key3": @"value3"
    };
    
    [flow insertTag:@"TestTag" extraInfo:extraInfo];
    
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
    
    [flow insertTag:@"TestTag" extraInfo:@{}];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"ts", @"tid"]];
    XCTAssertEqual(result.count, 1);
    
    NSDictionary *blob = result[0];
    XCTAssertEqualObjects(blob[@"t"], @"TestTag");
    XCTAssertNotNil(blob[@"ts"]);
    XCTAssertNotNil(blob[@"tid"]);
}

- (void)testInsertTagMultipleTimes_shouldMaintainOrder
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag1" extraInfo:nil];
    [flow insertTag:@"Tag2" extraInfo:nil];
    [flow insertTag:@"Tag3" extraInfo:nil];
    
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
    
    [flow insertTag:@"OriginalTag" extraInfo:extraInfo];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"ts", @"tid", @"custom"]];
    XCTAssertEqual(result.count, 1);
    
    NSDictionary *blob = result[0];
    XCTAssertEqualObjects(blob[@"t"], @"OriginalTag", @"Tag should not be overridden");
    XCTAssertNotEqualObjects(blob[@"ts"], @(9999), @"Timestamp should not be overridden");
    XCTAssertNotEqualObjects(blob[@"tid"], @(8888), @"Thread ID should not be overridden");
    XCTAssertEqualObjects(blob[@"custom"], @"value", @"Custom key should be added");
}

#pragma mark - Timestamp Tests

- (void)testInsertTag_shouldHaveIncreasingTimestamps
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag1" extraInfo:nil];
    [NSThread sleepForTimeInterval:0.01]; // Sleep 10ms
    [flow insertTag:@"Tag2" extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"ts"]];
    XCTAssertEqual(result.count, 2);
    
    NSNumber *ts1 = result[0][@"ts"];
    NSNumber *ts2 = result[1][@"ts"];
    
    XCTAssertNotNil(ts1);
    XCTAssertNotNil(ts2);
    XCTAssertGreaterThan(ts2.longLongValue, ts1.longLongValue, @"Second timestamp should be greater");
}

- (void)testInsertTag_timestampShouldBeInMilliseconds
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [NSThread sleepForTimeInterval:0.1]; // Sleep 100ms
    [flow insertTag:@"Tag" extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"ts"]];
    NSDictionary *blob = result[0];
    NSNumber *ts = blob[@"ts"];
    
    // Should be approximately 100ms (with some tolerance)
    XCTAssertGreaterThanOrEqual(ts.longLongValue, 90);
    XCTAssertLessThanOrEqual(ts.longLongValue, 200);
}

#pragma mark - Thread ID Tests

- (void)testInsertTag_shouldHaveValidThreadId
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"Tag" extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"tid"]];
    NSDictionary *blob = result[0];
    NSNumber *tid = blob[@"tid"];
    
    XCTAssertNotNil(tid);
    XCTAssertGreaterThan(tid.unsignedLongLongValue, 0, @"Thread ID should be positive");
}

#pragma mark - executionFlowWithKeys: Tests

- (void)testExecutionFlowWithNilKeys_shouldReturnNil
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    [flow insertTag:@"Tag" extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:nil];
    
    XCTAssertNil(result);
}

- (void)testExecutionFlowWithEmptyKeys_shouldReturnNil
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    [flow insertTag:@"Tag" extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[]];
    
    XCTAssertNil(result);
}

- (void)testExecutionFlowWithNonExistentKeys_shouldReturnNil
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    [flow insertTag:@"Tag" extraInfo:nil];
    
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
    [flow insertTag:@"Tag" extraInfo:extraInfo];
    
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
    
    [flow insertTag:@"Tag1" extraInfo:@{@"custom": @"value1"}];
    [flow insertTag:@"Tag2" extraInfo:@{@"custom": @"value2"}];
    [flow insertTag:@"Tag3" extraInfo:@{@"custom": @"value3"}];
    
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
        [flow insertTag:[NSString stringWithFormat:@"Tag%d", i] extraInfo:nil];
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
        [flow insertTag:[NSString stringWithFormat:@"Tag%d", i] extraInfo:nil];
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
            [flow insertTag:[NSString stringWithFormat:@"Tag%d", i] extraInfo:nil];
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
            [flow insertTag:[NSString stringWithFormat:@"Tag%d", i] extraInfo:nil];
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

- (void)testInsertTagWithEmptyString_shouldAddToFlow
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    
    [flow insertTag:@"" extraInfo:nil];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t"]];
    XCTAssertNil(result, @"return nil since empty tag is provided");
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
    
    [flow insertTag:@"Tag" extraInfo:extraInfo];
    
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
    
    [flow insertTag:@"Tag" extraInfo:@{@"key1": @"value1"}];
    
    NSArray *result = [flow executionFlowWithKeys:@[@"t", @"key1", @"nonexistent"]];
    XCTAssertEqual(result.count, 1);
    
    NSDictionary *blob = result[0];
    XCTAssertEqual(blob.count, 2);
    XCTAssertEqualObjects(blob[@"t"], @"Tag");
    XCTAssertEqualObjects(blob[@"key1"], @"value1");
}

@end
