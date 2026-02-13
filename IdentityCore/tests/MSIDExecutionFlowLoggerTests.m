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
#import "MSIDExecutionFlowLogger+Test.h"

@interface MSIDExecutionFlowLoggerTests : XCTestCase

@end

@implementation MSIDExecutionFlowLoggerTests

- (void)setUp
{
    [super setUp];
    // Flush logger before each test to ensure clean state
    [[MSIDExecutionFlowLogger sharedInstance] flush];
    // Give async flush time to complete
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
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", nil, correlationId);

    XCTestExpectation *flowExpectation = [self expectationWithDescription:@"flow should exist after register"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow, @"Flow should be created after registration");
        [flowExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
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
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_REGISTER(correlationId); // Second registration should be ignored
    
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", nil, correlationId);

    XCTestExpectation *flowExpectation = [self expectationWithDescription:@"flow should still exist after duplicate register"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow, @"Should still have one flow");
        [flowExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testRegisterExecutionFlowAfterFlush_reRegister_shouldSucceed
{
    NSUUID *correlationId = [NSUUID UUID];
    
    // Register and flush
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", nil, correlationId);

    XCTestExpectation *firstFlowExpectation = [self expectationWithDescription:@"first flow before re-registration"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow, @"Should allow re-registration after flush");
        [firstFlowExpectation fulfill];
    });
    
    // Try to register again after flush
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag2", nil, correlationId);
    
    // Should not create new flow
    XCTestExpectation *secondFlowExpectation = [self expectationWithDescription:@"second flow after re-registration"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow, @"Should allow re-registration after flush");
        [secondFlowExpectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAddNewExecutionFlowBlobAfterFlush_shouldFail
{
    NSUUID *correlationId = [NSUUID UUID];
    
    // Register and flush
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", nil, correlationId);

    XCTestExpectation *firstFlowExpectation = [self expectationWithDescription:@"first blob before flush"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow, @"Should add new event blob after flush");
        [firstFlowExpectation fulfill];
    });
    
    // Try to register again after flush
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag2", nil, correlationId);

    // Should not create new flow

    XCTestExpectation *secondFlowExpectation = [self expectationWithDescription:@"no blob after flush"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow, @"Should not add new event blob after flush");
        [secondFlowExpectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - insertTag:extraInfo:withCorrelationId: Tests

- (void)testInsertTagWithValidParameters_shouldCreateAndStoreFlow
{
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", nil, correlationId);
    
    // Give async operation time to complete
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];

    XCTestExpectation *tagsExpectation = [self expectationWithDescription:@"tag stored expectation"];
    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, keys, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);

        NSData *jsonData = [executionFlow dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        XCTAssertNotNil(result);
        XCTAssertEqual(result.count, 1);
        XCTAssertEqualObjects(result[0][@"t"], @"TestTag");

        [tagsExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInsertTagWithExtraInfo_shouldStoreAllInformation
{
    NSUUID *correlationId = [NSUUID UUID];
    
    NSDictionary *extraInfo = @{
        @"key1": @"value1",
        @"key2": @(123)
    };
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", extraInfo, correlationId);
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"key1", @"key2"]];
    
    XCTestExpectation *extraInfoExpectation = [self expectationWithDescription:@"extra info stored"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, keys, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);

        NSData *jsonData = [executionFlow dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

        XCTAssertNotNil(result);
        XCTAssertEqual(result.count, 1);
        XCTAssertEqualObjects(result[0][@"t"], @"TestTag");
        XCTAssertEqualObjects(result[0][@"key1"], @"value1");
        XCTAssertEqualObjects(result[0][@"key2"], @(123));

        [extraInfoExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInsertTagWithoutRegistration_shouldFailSilently
{
    NSUUID *correlationId = [NSUUID UUID];
    
    // Insert without registering
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", nil, correlationId);

    XCTestExpectation *noRegistrationExpectation = [self expectationWithDescription:@"no flow without registration"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow, @"Should not create flow without registration");
        [noRegistrationExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInsertTagWithNilTag_shouldNotCreateFlow
{
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    
    NSString *nilTag = nil;
    MSID_EXECUTION_FLOW_INSERT_TAG(nilTag, nil, correlationId);
    NSSet *keys = [NSSet setWithArray:@[@"t"]];

    XCTestExpectation *nilTagExpectation = [self expectationWithDescription:@"no flow with nil tag"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, keys, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow, @"Should not add tag with nil tag");
        [nilTagExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInsertTagWithEmptyTag_shouldNotCreateFlow
{
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"", nil, correlationId);
    NSSet *keys = [NSSet setWithArray:@[@"t"]];

    XCTestExpectation *emptyTagExpectation = [self expectationWithDescription:@"no flow with empty tag"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, keys, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow, @"Should not add empty tag");
        [emptyTagExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInsertTagWithWhitespaceTag_shouldNotCreateFlow
{
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"   ", nil, correlationId);
    NSSet *keys = [NSSet setWithArray:@[@"t"]];

    XCTestExpectation *whitespaceTagExpectation = [self expectationWithDescription:@"no flow with whitespace tag"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, keys, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow, @"Should not add whitespace-only tag");
        [whitespaceTagExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInsertTagWithNilCorrelationId_shouldNotCreateFlow
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    
    // Should not crash
    NSUUID *nilCorrelationId = nil;
    XCTAssertNoThrow([logger insertTag:@"TestTag" extraInfo:nil withCorrelationId:nilCorrelationId]);
}

- (void)testInsertTagWithEmptyCorrelationId_shouldNotCreateFlow
{
    NSString *uuidString = @"";
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", nil, uuid);
    
    XCTestExpectation *emptyCorrelationExpectation = [self expectationWithDescription:@"no flow with empty correlation id"];

    MSID_EXECUTION_FLOW_RETRIEVE(uuid, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow, @"Should not create flow with empty correlationId");
        [emptyCorrelationExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInsertMultipleTagsWithSameCorrelationId_shouldAddToSameFlow
{
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag1", nil, correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag2", nil, correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag3", nil, correlationId);
    
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];

    XCTestExpectation *multiTagExpectation = [self expectationWithDescription:@"multiple tags recorded"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, keys, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);

        NSData *jsonData = [executionFlow dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

        XCTAssertNotNil(result);
        XCTAssertEqual(result.count, 3, @"Should have 3 tags in the same flow");
        XCTAssertEqualObjects(result[0][@"t"], @"Tag1");
        XCTAssertEqualObjects(result[1][@"t"], @"Tag2");
        XCTAssertEqualObjects(result[2][@"t"], @"Tag3");

        [multiTagExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInsertTagsWithDifferentCorrelationIds_shouldCreateSeparateFlows
{
    NSUUID *correlationId1 = [NSUUID UUID];
    NSUUID *correlationId2 = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId1);
    MSID_EXECUTION_FLOW_REGISTER(correlationId2);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag1", nil, correlationId1);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag2", nil, correlationId2);
    
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];

    XCTestExpectation *flow1Expectation = [self expectationWithDescription:@"flow1 different correlation"];
    XCTestExpectation *flow2Expectation = [self expectationWithDescription:@"flow2 different correlation"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId1, keys, YES, ^(NSString * _Nullable executionFlow) {
        NSData *jsonData1 = [executionFlow dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *result1 = [NSJSONSerialization JSONObjectWithData:jsonData1 options:0 error:nil];
        XCTAssertEqual(result1.count, 1);
        XCTAssertEqualObjects(result1[0][@"t"], @"Tag1");

        [flow1Expectation fulfill];
    });
    
    MSID_EXECUTION_FLOW_RETRIEVE(correlationId2, nil, YES, ^(NSString * _Nullable executionFlow) {
        NSData *jsonData2 = [executionFlow dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *result2 = [NSJSONSerialization JSONObjectWithData:jsonData2 options:0 error:nil];
        XCTAssertEqual(result2.count, 1);
        XCTAssertEqualObjects(result2[0][@"t"], @"Tag2");

        [flow2Expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInsertTagWithThreadId_shouldPreserveThreadId
{
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", nil, correlationId);
    
    NSSet *keys = [NSSet setWithArray:@[@"tid"]];

    XCTestExpectation *threadIdExpectation = [self expectationWithDescription:@"thread id stored"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, keys, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        
        NSData *jsonData = [executionFlow dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        
        XCTAssertNotNil(result);
        XCTAssertNotNil(result[0][@"tid"], @"Thread ID should be present");
        XCTAssertTrue([result[0][@"tid"] unsignedLongLongValue] > 0, @"Thread ID should be positive");

        [threadIdExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - retrieveExecutionFlowWithCorrelationId: Tests

- (void)testRetrieveAndFlushWithValidCorrelationId_shouldReturnFlow
{
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", nil, correlationId);

    XCTestExpectation *validFlowExpectation = [self expectationWithDescription:@"valid execution flow retrieved"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        [validFlowExpectation fulfill];

    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testRetrieveAndFlushWithNonExistentCorrelationId_shouldReturnNil
{
    NSUUID *correlationId = [NSUUID UUID];

    XCTestExpectation *nonexistentExpectation = [self expectationWithDescription:@"flow should be nil for missing correlation"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow, @"Should return nil for non-existent correlationId");
        [nonexistentExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testRetrieveAndFlushWithNilCorrelationId_shouldReturnNil
{
    NSUUID *nilCorrelationId = nil;
    XCTestExpectation *nilExpectation = [self expectationWithDescription:@"flow should be nil for nil correlation"];

    MSID_EXECUTION_FLOW_RETRIEVE(nilCorrelationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow, @"Should return nil for nil correlationId");
        [nilExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testRetrieveAndFlushWithEmptyCorrelationId_shouldReturnNil
{
    NSString *uuidString = @"";
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
    XCTestExpectation *emptyExpectation = [self expectationWithDescription:@"flow should be nil for empty correlation"];

    MSID_EXECUTION_FLOW_RETRIEVE(uuid, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow, @"Should return nil for nil correlationId");
        [emptyExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testRetrieveAndFlush_shouldRemoveFlowFromCache
{
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", nil, correlationId);
    XCTestExpectation *firstRetrieveExpectation = [self expectationWithDescription:@"flow removed after first retrieve"];
    XCTestExpectation *secondRetrieveExpectation = [self expectationWithDescription:@"flow nil after flush"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        [firstRetrieveExpectation fulfill];

    });
    
    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow, @"Flow should be removed after first retrieve and flush");
        [secondRetrieveExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testRetrieveAndFlushMultipleTimes_shouldOnlyReturnFirstTime
{
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", nil, correlationId);
    
    XCTestExpectation *firstExpectation = [self expectationWithDescription:@"flow only first time"];
    XCTestExpectation *secondExpectation = [self expectationWithDescription:@"second retrieve nil"];
    XCTestExpectation *thirdExpectation = [self expectationWithDescription:@"third retrieve nil"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        [firstExpectation fulfill];
    });
    
    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow);
        [secondExpectation fulfill];
    });
    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow);
        [thirdExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testRetrieveWithoutFlush_shouldKeepFlowAvailable
{
    NSUUID *correlationId = [NSUUID UUID];

    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag1", nil, correlationId);

    XCTestExpectation *firstRetrieveExpectation = [self expectationWithDescription:@"flow returned without flush"];
    XCTestExpectation *secondRetrieveExpectation = [self expectationWithDescription:@"flow still present after no-flush retrieve"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, NO, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        [firstRetrieveExpectation fulfill];
    });

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow, @"Flow should remain when shouldFlush is NO");
        [secondRetrieveExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testRetrieveWithoutFlush_shouldAllowAdditionalTags
{
    NSUUID *correlationId = [NSUUID UUID];

    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag1", nil, correlationId);

    XCTestExpectation *firstRetrieveExpectation = [self expectationWithDescription:@"flow retrieved without flush"];
    XCTestExpectation *finalRetrieveExpectation = [self expectationWithDescription:@"flow includes tags added after no-flush retrieve"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, NO, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        [firstRetrieveExpectation fulfill];
    });

    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag2", nil, correlationId);

    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, keys, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);

        NSData *jsonData = [executionFlow dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

        XCTAssertEqual(result.count, 2);
        XCTAssertEqualObjects(result[0][@"t"], @"Tag1");
        XCTAssertEqualObjects(result[1][@"t"], @"Tag2");

        [finalRetrieveExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInsertAfterFlush_shouldBeRejected
{
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag1", nil, correlationId);
    
    XCTestExpectation *firstRetrieveExpectation = [self expectationWithDescription:@"flow present before flush rejection"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        [firstRetrieveExpectation fulfill];
    });

    // Give flush time to add correlationId to eliminated pool

    // Try to insert after flush
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag2", nil, correlationId);

    // Should not create new flow
    XCTestExpectation *secondRetrieveExpectation = [self expectationWithDescription:@"flow nil after flush rejection"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow, @"Should reject inserts after flush");
        [secondRetrieveExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - Eliminated Pool Tests

- (void)testEliminatedPool_shouldPreventReaddingSameFlow
{
    NSUUID *correlationId = [NSUUID UUID];
    
    // Insert and flush
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag1", nil, correlationId);

    XCTestExpectation *firstPoolExpectation = [self expectationWithDescription:@"first flow before eliminated pool test"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        [firstPoolExpectation fulfill];
    });
    
    // Try to insert again with same correlationId
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag2", nil, correlationId);
    
    // Should not create new flow
    XCTestExpectation *secondPoolExpectation = [self expectationWithDescription:@"no flow after eliminated pool"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow);
        [secondPoolExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - flush Tests

- (void)testFlush_shouldRemoveAllFlows
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId1 = [NSUUID UUID];
    NSUUID *correlationId2 = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId1);
    MSID_EXECUTION_FLOW_REGISTER(correlationId2);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag1", nil, correlationId1);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag2", nil, correlationId2);
    
    [logger flush];
    
    XCTestExpectation *firstFlushExpectation = [self expectationWithDescription:@"first flow nil after flush"];
    XCTestExpectation *secondFlushExpectation = [self expectationWithDescription:@"second flow nil after flush"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId1, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow);
        [firstFlushExpectation fulfill];
    });
    MSID_EXECUTION_FLOW_RETRIEVE(correlationId2, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow);
        [secondFlushExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testFlush_shouldClearEliminatedPool
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];
    
    // Insert, flush, and verify it's in eliminated pool
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag1", nil, correlationId);

    XCTestExpectation *initialFlowExpectation = [self expectationWithDescription:@"flow before flush clears pool"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        [initialFlowExpectation fulfill];
    });
    
    // Call flush
    [logger flush];
    
    // Should be able to use same correlationId again
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Tag2", nil, correlationId);
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];
    XCTestExpectation *secondFlowExpectation = [self expectationWithDescription:@"flow after flush clears pool"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, keys, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        
        NSData *jsonData = [executionFlow dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        
        XCTAssertEqual(result.count, 1);
        XCTAssertEqualObjects(result[0][@"t"], @"Tag2");

        [secondFlowExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - Enabled State Tests

- (void)testSetEnabledNO_shouldIgnoreOperations
{
    MSIDExecutionFlowLogger *logger = [MSIDExecutionFlowLogger sharedInstance];
    NSUUID *correlationId = [NSUUID UUID];

    @try {
        [logger setEnabled:NO];

        XCTAssertNoThrow([logger registerExecutionFlowWithCorrelationId:correlationId]);
        XCTAssertNoThrow([logger insertTag:@"Tag1" extraInfo:nil withCorrelationId:correlationId]);

        XCTestExpectation *disabledExpectation = [self expectationWithDescription:@"disabled logger returns nil flow"];
        MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
            XCTAssertNil(executionFlow, @"Logger should ignore operations when disabled");
            [disabledExpectation fulfill];
        });

        [self waitForExpectationsWithTimeout:1 handler:nil];
    }
    @finally {
        [logger setEnabled:YES];
    }
}

- (void)testRetrieveWithQueryKeys_shouldFilterExtraInfoButKeepReservedKeys
{
    NSUUID *correlationId = [NSUUID UUID];

    NSDictionary *extraInfo = @{
        @"key1": @"value1",
        @"key2": @"value2"
    };

    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"TestTag", extraInfo, correlationId);

    NSSet *keys = [NSSet setWithArray:@[@"key1"]];

    XCTestExpectation *filterExpectation = [self expectationWithDescription:@"filtered keys returned"];
    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, keys, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);

        NSData *jsonData = [executionFlow dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

        XCTAssertEqual(result.count, 1);
        XCTAssertEqualObjects(result[0][@"t"], @"TestTag");
        XCTAssertNotNil(result[0][@"ts"]);
        XCTAssertNotNil(result[0][@"tid"]);
        XCTAssertEqualObjects(result[0][@"key1"], @"value1");
        XCTAssertNil(result[0][@"key2"]);

        [filterExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - Thread Safety Tests

- (void)testConcurrentInsertsWithSameCorrelationId_shouldHandleThreadSafely
{
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // Insert from multiple threads
    for (int i = 0; i < 20; i++) {
        dispatch_group_async(group, queue, ^{
            MSID_EXECUTION_FLOW_INSERT_TAG(([NSString stringWithFormat:@"Tag%d", i]), nil, correlationId);
        });
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    NSSet *keys = [NSSet setWithArray:@[@"t"]];

    XCTestExpectation *concurrentExpectation = [self expectationWithDescription:@"concurrent inserts completed"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, keys, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        
        NSData *jsonData = [executionFlow dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        
        XCTAssertEqual(result.count, 20, @"All concurrent inserts should succeed");

        [concurrentExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testConcurrentInsertsWithDifferentCorrelationIds_shouldNotInterfere
{
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    NSMutableArray *correlationIds = [NSMutableArray new];
    for (int i = 0; i < 10; i++) {
        NSUUID *correlationId = [NSUUID UUID];
        [correlationIds addObject:correlationId];
        MSID_EXECUTION_FLOW_REGISTER(correlationId);
    }
    
    // Insert from multiple threads with different correlationIds
    for (int i = 0; i < 10; i++) {
        dispatch_group_async(group, queue, ^{
            MSID_EXECUTION_FLOW_INSERT_TAG(([NSString stringWithFormat:@"Tag%d", i]), nil, correlationIds[i]);
        });
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // Verify all flows were created
    XCTestExpectation *allFlowsExpectation = [self expectationWithDescription:@"all separate flows retrieved"];
    allFlowsExpectation.expectedFulfillmentCount = 10;

    for (int i = 0; i < 10; i++) {
        MSID_EXECUTION_FLOW_RETRIEVE(correlationIds[i], nil, YES, ^(NSString * _Nullable executionFlow) {
            XCTAssertNotNil(executionFlow, @"Flow should exist for correlationId %d", i);
            [allFlowsExpectation fulfill];
        });
    }

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testConcurrentInsertAndRetrieve_shouldNotCrash
{
    NSUUID *correlationId = [NSUUID UUID];
    
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // Concurrent inserts
    for (int i = 0; i < 10; i++)
    {
        dispatch_async(queue, ^{
            MSID_EXECUTION_FLOW_INSERT_TAG(([NSString stringWithFormat:@"Tag%d", i]), nil, correlationId);
        });
    }
    
    // Concurrent retrieve; test passes if it completes without crashing
    XCTestExpectation *retrieveExpectation = [self expectationWithDescription:@"retrieve finishes"];
    dispatch_async(queue, ^{
        MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(__unused NSString * _Nullable executionFlow) {
            [retrieveExpectation fulfill];
        });
    });
    
    [self waitForExpectationsWithTimeout:3 handler:nil];

    // Test passes if no crash occurs
}

- (void)testConcurrentRegistrations_shouldHandleThreadSafely
{
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    NSMutableArray *correlationIds = [NSMutableArray new];
    for (int i = 0; i < 20; i++)
    {
        [correlationIds addObject:[NSUUID UUID]];
    }
    
    // Register from multiple threads
    for (int i = 0; i < 20; i++) {
        dispatch_async(queue, ^{
            MSID_EXECUTION_FLOW_REGISTER(correlationIds[i]);
        });
    }
    
    XCTestExpectation *allFlowsExpectation = [self expectationWithDescription:@"all separate flows retrieved"];
    allFlowsExpectation.expectedFulfillmentCount = 20;
    for (int i = 0; i < 20; i++)
    {
        dispatch_async(queue, ^{
            MSID_EXECUTION_FLOW_RETRIEVE(correlationIds[i], nil, YES, ^(__unused NSString * _Nullable executionFlow) {
                [allFlowsExpectation fulfill];
            });
        });
    }
    
    [self waitForExpectationsWithTimeout:3 handler:nil];
    // Test passes if no crash occurs
}

#pragma mark - Integration Tests

- (void)testFullWorkflow_registerInsertRetrieveAndFlush
{
    NSUUID *correlationId = [NSUUID UUID];
    
    // Register first
    MSID_EXECUTION_FLOW_REGISTER(correlationId);
    
    // Insert multiple tags
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Start", @{@"step": @"1"}, correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"Middle", @{@"step": @"2"}, correlationId);
    MSID_EXECUTION_FLOW_INSERT_TAG(@"End", @{@"step": @"3"}, correlationId);
    
    
    // Retrieve and verify
    
    NSSet *keys = [NSSet setWithArray:@[@"t", @"step", @"ts", @"tid"]];

    XCTestExpectation *workflowExpectation = [self expectationWithDescription:@"integration flow verified"];
    XCTestExpectation *flushExpectation = [self expectationWithDescription:@"flow flushed after integration"];

    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, keys, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        
        NSData *jsonData = [executionFlow dataUsingEncoding:NSUTF8StringEncoding];
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

        [workflowExpectation fulfill];
    });
        
    // Verify flow is flushed
    MSID_EXECUTION_FLOW_RETRIEVE(correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNil(executionFlow);
        [flushExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
