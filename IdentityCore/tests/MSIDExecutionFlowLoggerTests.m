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
#import "MSIDExecutionFlowLogger.h"
#import "MSIDExecutionFlow.h"

@interface MSIDExecutionFlowLoggerTests : XCTestCase

@end

@implementation MSIDExecutionFlowLoggerTests

- (void)setUp
{
    [super setUp];
    // Flush logger before each test to ensure clean state
    [[MSIDExecutionFlowLogger sharedInstance] flush];
    // Give async flush time to complete
    [NSThread sleepForTimeInterval:0.1];
}

- (void)tearDown
{
    [[MSIDExecutionFlowLogger sharedInstance] flush];
    [super tearDown];
}

#pragma mark - Singleton Tests

- (void)testSharedInstance_shouldReturnSameInstance
{
    MSIDExecutionFlowLogger *logger1 = [MSIDExecutionFlowLogger sharedInstance];
    MSIDExecutionFlowLogger *logger2 = [MSIDExecutionFlowLogger sharedInstance];
    
    XCTAssertNotNil(logger1);
    XCTAssertNotNil(logger2);
    XCTAssertEqual(logger1, logger2, @"Should return the same singleton instance");
}

#pragma mark - registerExecutionFlowWithCorrelationId: Tests

- (void)testRegisterExecutionFlowWithValidCorrelationId_shouldSucceed
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    XCTAssertNoThrow([logger registerExecutionFlowWithCorrelationId:correlationId]);
    
    // Verify by inserting a tag
    [logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    NSString *flow = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    XCTAssertNotNil(flow, @"Flow should be created after registration");
}

- (void)testRegisterExecutionFlowWithNilCorrelationId_shouldNotCrash
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *nilCorrelationId = nil;
    XCTAssertNoThrow([logger registerExecutionFlowWithCorrelationId:nilCorrelationId]);
}

- (void)testRegisterExecutionFlowWithEmptyCorrelationId_shouldNotCrash
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSString *uuidString = @"";
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
    XCTAssertNoThrow([logger registerExecutionFlowWithCorrelationId:uuid]);
}

- (void)testRegisterExecutionFlowTwice_shouldNotCreateDuplicateFlow
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger registerExecutionFlowWithCorrelationId:correlationId]; // Second registration should be ignored
    
    [logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    NSString *flow = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    XCTAssertNotNil(flow, @"Should still have one flow");
}

- (void)testRegisterExecutionFlowAfterFlush_reRegister_shouldSucceed
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    // Register and flush
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    [NSThread sleepForTimeInterval:0.1];
    
    // Try to register again after flush
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"TestTag2" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    // Should not create new flow
    NSString *flow = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    XCTAssertNotNil(flow, @"Should allow re-registration after flush");
}

- (void)testAddNewExecutionFlowBlobAfterFlush_shouldFail
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    // Register and flush
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    [NSThread sleepForTimeInterval:0.1];
    
    // Try to register again after flush
    [logger insertTag:@"TestTag2" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    // Should not create new flow
    NSString *flow = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    XCTAssertNil(flow, @"Should not add new event blob after flush");
}

#pragma mark - insertTag:extraInfo:withCorrelationId: Tests

- (void)testInsertTagWithValidParameters_shouldCreateAndStoreFlow
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:correlationId];
    
    // Give async operation time to complete
    [NSThread sleepForTimeInterval:0.1];
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *jsonString = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:keys];
    XCTAssertNotNil(jsonString);
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0][@"t"], @"TestTag");
}

- (void)testInsertTagWithExtraInfo_shouldStoreAllInformation
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    NSDictionary *extraInfo = @{
        @"key1": @"value1",
        @"key2": @(123)
    };
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"TestTag" extraInfo:extraInfo withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"key1", @"key2"]];
    NSString *jsonString = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:keys];

    XCTAssertNotNil(jsonString);
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0][@"t"], @"TestTag");
    XCTAssertEqualObjects(result[0][@"key1"], @"value1");
    XCTAssertEqualObjects(result[0][@"key2"], @(123));
}

- (void)testInsertTagWithoutRegistration_shouldFailSilently
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    // Insert without registering
    [logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    NSString *flow = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    XCTAssertNil(flow, @"Should not create flow without registration");
}

- (void)testInsertTagWithNilTag_shouldNotCreateFlow
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    
    NSString *nilTag = nil;
    [logger insertTag:nilTag extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *jsonString = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:keys];
    XCTAssertNil(jsonString, @"Should not add tag with nil tag");
}

- (void)testInsertTagWithEmptyTag_shouldNotCreateFlow
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *jsonString = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:keys];

    XCTAssertNil(jsonString, @"Should not add empty tag");
}

- (void)testInsertTagWithWhitespaceTag_shouldNotCreateFlow
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"   " extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *jsonString = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:keys];

    XCTAssertNil(jsonString, @"Should not add whitespace-only tag");
}

- (void)testInsertTagWithNilCorrelationId_shouldNotCreateFlow
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    
    // Should not crash
    NSUUID *nilCorrelationId = nil;
    XCTAssertNoThrow([logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:nilCorrelationId]);
    [NSThread sleepForTimeInterval:0.1];
}

- (void)testInsertTagWithEmptyCorrelationId_shouldNotCreateFlow
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSString *uuidString = @"";
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
    [logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:uuid];
    [NSThread sleepForTimeInterval:0.1];
    
    NSString *jsonString = [logger retrieveAndFlushExecutionFlowWithCorrelationId:uuid queryKeys:nil];

    XCTAssertNil(jsonString, @"Should not create flow with empty correlationId");
}

- (void)testInsertMultipleTagsWithSameCorrelationId_shouldAddToSameFlow
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"Tag1" extraInfo:nil withCorrelationId:correlationId];
    [logger insertTag:@"Tag2" extraInfo:nil withCorrelationId:correlationId];
    [logger insertTag:@"Tag3" extraInfo:nil withCorrelationId:correlationId];
    
    [NSThread sleepForTimeInterval:0.2];
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *jsonString = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:keys];
    XCTAssertNotNil(jsonString);
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 3, @"Should have 3 tags in the same flow");
    XCTAssertEqualObjects(result[0][@"t"], @"Tag1");
    XCTAssertEqualObjects(result[1][@"t"], @"Tag2");
    XCTAssertEqualObjects(result[2][@"t"], @"Tag3");
}

- (void)testInsertTagsWithDifferentCorrelationIds_shouldCreateSeparateFlows
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId1 = [NSUUID UUID];
    NSUUID *correlationId2 = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId1];
    [logger registerExecutionFlowWithCorrelationId:correlationId2];
    [logger insertTag:@"Tag1" extraInfo:nil withCorrelationId:correlationId1];
    [logger insertTag:@"Tag2" extraInfo:nil withCorrelationId:correlationId2];
    
    [NSThread sleepForTimeInterval:0.1];
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *jsonString1 = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId1 queryKeys:keys];
    NSString *jsonString2 = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId2 queryKeys:nil];
    
    NSData *jsonData1 = [jsonString1 dataUsingEncoding:NSUTF8StringEncoding];
    NSData *jsonData2 = [jsonString2 dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result1 = [NSJSONSerialization JSONObjectWithData:jsonData1 options:0 error:nil];
    NSArray *result2 = [NSJSONSerialization JSONObjectWithData:jsonData2 options:0 error:nil];
    
    XCTAssertEqual(result1.count, 1);
    XCTAssertEqual(result2.count, 1);
    XCTAssertEqualObjects(result1[0][@"t"], @"Tag1");
    XCTAssertEqualObjects(result2[0][@"t"], @"Tag2");
}

- (void)testInsertTagWithThreadId_shouldPreserveThreadId
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    NSSet *keys = [NSSet setWithArray:@[@"tid"]];
    NSString *jsonString = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:keys];
    XCTAssertNotNil(jsonString);
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    XCTAssertNotNil(result);
    XCTAssertNotNil(result[0][@"tid"], @"Thread ID should be present");
    XCTAssertTrue([result[0][@"tid"] unsignedLongLongValue] > 0, @"Thread ID should be positive");
}

#pragma mark - retrieveAndFlushExecutionFlowWithCorrelationId: Tests

- (void)testRetrieveAndFlushWithValidCorrelationId_shouldReturnFlow
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    NSString *flow = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    
    XCTAssertNotNil(flow);
}

- (void)testRetrieveAndFlushWithNonExistentCorrelationId_shouldReturnNil
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    NSString *flow = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    
    XCTAssertNil(flow, @"Should return nil for non-existent correlationId");
}

- (void)testRetrieveAndFlushWithNilCorrelationId_shouldReturnNil
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *nilCorrelationId = nil;
    NSString *flow = [logger retrieveAndFlushExecutionFlowWithCorrelationId:nilCorrelationId queryKeys:nil];
    
    XCTAssertNil(flow, @"Should return nil for nil correlationId");
}

- (void)testRetrieveAndFlushWithEmptyCorrelationId_shouldReturnNil
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSString *uuidString = @"";
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
    NSString *flow = [logger retrieveAndFlushExecutionFlowWithCorrelationId:uuid queryKeys:nil];
    
    XCTAssertNil(flow, @"Should return nil for empty correlationId");
}

- (void)testRetrieveAndFlush_shouldRemoveFlowFromCache
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    NSString *flow1 = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    XCTAssertNotNil(flow1);
    
    // Give flush time to complete
    [NSThread sleepForTimeInterval:0.1];
    
    // Try to retrieve again - should be nil since it was flushed
    NSString *flow2 = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    XCTAssertNil(flow2, @"Flow should be removed after first retrieve and flush");
}

- (void)testRetrieveAndFlushMultipleTimes_shouldOnlyReturnFirstTime
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    NSString *flow1 = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    [NSThread sleepForTimeInterval:0.1];
    
    NSString *flow2 = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    NSString *flow3 = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    
    XCTAssertNotNil(flow1);
    XCTAssertNil(flow2);
    XCTAssertNil(flow3);
}

- (void)testInsertAfterFlush_shouldBeRejected
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"Tag1" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    NSString *flow = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    XCTAssertNotNil(flow);
    
    // Give flush time to add correlationId to eliminated pool
    [NSThread sleepForTimeInterval:0.1];
    
    // Try to insert after flush
    [logger insertTag:@"Tag2" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    // Should not create new flow
    NSString *flow2 = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    XCTAssertNil(flow2, @"Should reject inserts after flush");
}

#pragma mark - Eliminated Pool Tests

- (void)testEliminatedPool_shouldPreventReaddingSameFlow
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    // Insert and flush
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"Tag1" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    [NSThread sleepForTimeInterval:0.1];
    
    // Try to insert again with same correlationId
    [logger insertTag:@"Tag2" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    // Should not create new flow
    NSString *flow = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    XCTAssertNil(flow);
}

#pragma mark - flush Tests

- (void)testFlush_shouldRemoveAllFlows
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId1 = [NSUUID UUID];
    NSUUID *correlationId2 = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId1];
    [logger registerExecutionFlowWithCorrelationId:correlationId2];
    [logger insertTag:@"Tag1" extraInfo:nil withCorrelationId:correlationId1];
    [logger insertTag:@"Tag2" extraInfo:nil withCorrelationId:correlationId2];
    [NSThread sleepForTimeInterval:0.1];
    
    [logger flush];
    [NSThread sleepForTimeInterval:0.1];
    
    NSString *flow1 = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId1 queryKeys:nil];
    NSString *flow2 = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId2 queryKeys:nil];
    
    XCTAssertNil(flow1);
    XCTAssertNil(flow2);
}

- (void)testFlush_shouldClearEliminatedPool
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    // Insert, flush, and verify it's in eliminated pool
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"Tag1" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    [NSThread sleepForTimeInterval:0.1];
    
    // Call flush
    [logger flush];
    [NSThread sleepForTimeInterval:0.1];
    
    // Should be able to use same correlationId again
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    [logger insertTag:@"Tag2" extraInfo:nil withCorrelationId:correlationId];
    [NSThread sleepForTimeInterval:0.1];
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *jsonString = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:keys];
    XCTAssertNotNil(jsonString);
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0][@"t"], @"Tag2");
}

#pragma mark - Thread Safety Tests

- (void)testConcurrentInsertsWithSameCorrelationId_shouldHandleThreadSafely
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // Insert from multiple threads
    for (int i = 0; i < 20; i++) {
        dispatch_group_async(group, queue, ^{
            [logger insertTag:[NSString stringWithFormat:@"Tag%d", i] 
                    extraInfo:nil 
            withCorrelationId:correlationId];
        });
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    [NSThread sleepForTimeInterval:0.2];
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    NSString *jsonString = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:keys];
    XCTAssertNotNil(jsonString);
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    XCTAssertEqual(result.count, 20, @"All concurrent inserts should succeed");
}

- (void)testConcurrentInsertsWithDifferentCorrelationIds_shouldNotInterfere
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    NSMutableArray *correlationIds = [NSMutableArray new];
    for (int i = 0; i < 10; i++) {
        NSUUID *correlationId = [NSUUID UUID];
        [correlationIds addObject:correlationId];
        [logger registerExecutionFlowWithCorrelationId:correlationId];
    }
    
    // Insert from multiple threads with different correlationIds
    for (int i = 0; i < 10; i++) {
        dispatch_group_async(group, queue, ^{
            [logger insertTag:[NSString stringWithFormat:@"Tag%d", i] 
                    extraInfo:nil 
            withCorrelationId:correlationIds[i]];
        });
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    [NSThread sleepForTimeInterval:0.2];
    
    // Verify all flows were created
    for (int i = 0; i < 10; i++) {
        NSString *flow = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationIds[i] queryKeys:nil];
        XCTAssertNotNil(flow, @"Flow should exist for correlationId %d", i);
    }
}

- (void)testConcurrentInsertAndRetrieve_shouldNotCrash
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // Concurrent inserts
    for (int i = 0; i < 10; i++) {
        dispatch_group_async(group, queue, ^{
            [logger insertTag:[NSString stringWithFormat:@"Tag%d", i] 
                    extraInfo:nil 
            withCorrelationId:correlationId];
        });
    }
    
    // Concurrent retrieve (may or may not get data depending on timing)
    dispatch_group_async(group, queue, ^{
        [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    });
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // Test passes if no crash occurs
}

- (void)testConcurrentRegistrations_shouldHandleThreadSafely
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    NSMutableArray *correlationIds = [NSMutableArray new];
    for (int i = 0; i < 20; i++) {
        [correlationIds addObject:[NSUUID UUID]];
    }
    
    // Register from multiple threads
    for (int i = 0; i < 20; i++) {
        dispatch_group_async(group, queue, ^{
            [logger registerExecutionFlowWithCorrelationId:correlationIds[i]];
        });
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // Test passes if no crash occurs
}

#pragma mark - Integration Tests

- (void)testFullWorkflow_registerInsertRetrieveAndFlush
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    // Register first
    [logger registerExecutionFlowWithCorrelationId:correlationId];
    
    // Insert multiple tags
    [logger insertTag:@"Start" extraInfo:@{@"step": @"1"} withCorrelationId:correlationId];
    [logger insertTag:@"Middle" extraInfo:@{@"step": @"2"} withCorrelationId:correlationId];
    [logger insertTag:@"End" extraInfo:@{@"step": @"3"} withCorrelationId:correlationId];
    
    [NSThread sleepForTimeInterval:0.2];
    
    // Retrieve and verify
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"step", @"ts", @"tid"]];
    NSString *jsonString = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:keys];
    XCTAssertNotNil(jsonString);
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    XCTAssertEqual(result.count, 3);
    
    // Verify order and content
    XCTAssertEqualObjects(result[0][@"t"], @"Start");
    XCTAssertEqualObjects(result[0][@"step"], @"1");
    XCTAssertNotNil(result[0][@"ts"]);
    XCTAssertNotNil(result[0][@"tid"]);
    
    XCTAssertEqualObjects(result[1][@"t"], @"Middle");
    XCTAssertEqualObjects(result[2][@"t"], @"End");
    
    // Verify timestamps are increasing
    NSNumber *ts0 = result[0][@"ts"];
    NSNumber *ts1 = result[1][@"ts"];
    NSNumber *ts2 = result[2][@"ts"];
    XCTAssertLessThanOrEqual(ts0.longLongValue, ts1.longLongValue);
    XCTAssertLessThanOrEqual(ts1.longLongValue, ts2.longLongValue);
    
    [NSThread sleepForTimeInterval:0.1];
    
    // Verify flow is flushed
    NSString *flow2 = [logger retrieveAndFlushExecutionFlowWithCorrelationId:correlationId queryKeys:nil];
    XCTAssertNil(flow2);
}

@end
