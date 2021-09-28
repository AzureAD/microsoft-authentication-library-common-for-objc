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
#import "MSIDBackgroundTaskManager.h"
#import "MSIDCache.h"
#import "MSIDBackgroundTaskData.h"

@interface MSIDBackgroundTaskManagerTests : XCTestCase
    @property (nonatomic) MSIDBackgroundTaskManager *manager;
    @property (atomic) MSIDCache* taskCache;
    @property (nonatomic) MSIDBackgroundTaskType taskType;
@end

@implementation MSIDBackgroundTaskManagerTests
#if TARGET_OS_IOS
- (void)setUp
{
    self.manager = [MSIDBackgroundTaskManager sharedInstance];
    self.taskCache = [self.manager performSelector:@selector(taskCache)];
    self.taskType = MSIDBackgroundTaskTypeSilentRequest;
}

- (void)tearDown
{
    // Expire all Bg tasks for a type
    MSIDBackgroundTaskData *data = [self.taskCache objectForKey:@(self.taskType)];
    data.callerReferenceCount = 1;
    [self.manager stopOperationWithType:self.taskType];
}

- (void)testStartOperationWhenNoneAlreadyExistsForAType
{
    [self.manager startOperationWithType:self.taskType];
    XCTAssertNotNil([self.taskCache objectForKey:@(self.taskType)]);
    [self.manager stopOperationWithType:self.taskType];
    XCTAssertNil([self.taskCache objectForKey:@(self.taskType)]);
}

- (void)testStartOperation_doesNotStartAnother_WhenOnelreadyExistsForAType
{
    [self.manager startOperationWithType:self.taskType];
    XCTAssertNotNil([self.taskCache objectForKey:@(self.taskType)]);
    [self.manager startOperationWithType:self.taskType];
    MSIDBackgroundTaskData *bgTask = [self.taskCache objectForKey:@(self.taskType)];
    XCTAssertTrue(bgTask.callerReferenceCount == 2);
}

- (void)testStartOperation_doesNotStartAnother_doesNotStopBgTaskWhenAnotherRequestExistsForAType
{
    [self.manager startOperationWithType:self.taskType];
    XCTAssertNotNil([self.taskCache objectForKey:@(self.taskType)]);
    [self.manager startOperationWithType:self.taskType];
    MSIDBackgroundTaskData *bgTask = [self.taskCache objectForKey:@(self.taskType)];
    XCTAssertTrue(bgTask.callerReferenceCount == 2);
    [self.manager stopOperationWithType:self.taskType];
    XCTAssertTrue(bgTask.callerReferenceCount == 1);
    [self.manager stopOperationWithType:self.taskType];
    bgTask = nil;
    XCTAssertNil([self.taskCache objectForKey:@(self.taskType)]);
}

- (void)testBackgroundTasks_shouldCreateANewBgTaskForEachType
{
    [self.manager startOperationWithType:self.taskType];
    [self.manager startOperationWithType:self.taskType];
    XCTAssertTrue(((MSIDBackgroundTaskData *) [self.taskCache objectForKey:@(self.taskType)]).callerReferenceCount == 2);
    [self.manager startOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
    XCTAssertTrue(((MSIDBackgroundTaskData *) [self.taskCache objectForKey:@(MSIDBackgroundTaskTypeInteractiveRequest)]).callerReferenceCount == 1);
    XCTAssertTrue(((MSIDBackgroundTaskData *) [self.taskCache objectForKey:@(self.taskType)]).callerReferenceCount == 2);
    [self.manager stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
    [self.manager stopOperationWithType:self.taskType];
    [self.manager stopOperationWithType:self.taskType];
}

// 1. startOp for req A | 2. startOp for req B | stopOp for req B | startOp for req A
- (void)testBackgroundTasks_ForMultipleRequestsOfAType_shouldProvideBgProtectionForA
{
    [self.manager startOperationWithType:self.taskType];  // Start operation for Req A
    XCTAssertNotNil([self.taskCache objectForKey:@(self.taskType)]);
    [self.manager startOperationWithType:self.taskType];  // Start operation for Req B but no new task as 1 already started by A
    MSIDBackgroundTaskData *bgTask = [self.taskCache objectForKey:@(self.taskType)];
    XCTAssertTrue(bgTask.callerReferenceCount == 2);
    [self.manager stopOperationWithType:self.taskType];  // stop operation for req B
    bgTask = [self.taskCache objectForKey:@(self.taskType)];
    XCTAssertNotNil(bgTask);  // task started by A should still be present
    XCTAssertTrue(bgTask.callerReferenceCount == 1);
    [self.manager stopOperationWithType:self.taskType];
    bgTask = nil;
    XCTAssertNil([self.taskCache objectForKey:@(self.taskType)]);
}

// 1. startOp for req A | 2. startOp for req B | stopOp for req A | startOp for req B
- (void)testBackgroundTasks_ForMultipleRequestsOfAType_shouldProvideBgProtectionForB
{
    [self.manager startOperationWithType:self.taskType];  // Start operation for Req A
    XCTAssertNotNil([self.taskCache objectForKey:@(self.taskType)]);
    [self.manager startOperationWithType:self.taskType];  // Start operation for Req B but no new task as 1 already started by A
    MSIDBackgroundTaskData *bgTask = [self.taskCache objectForKey:@(self.taskType)];
    XCTAssertTrue(bgTask.callerReferenceCount == 2);
    [self.manager stopOperationWithType:self.taskType];  // stop operation for req A
    bgTask = [self.taskCache objectForKey:@(self.taskType)];
    XCTAssertNotNil(bgTask);  // task started by A should still be present for B
    XCTAssertTrue(bgTask.callerReferenceCount == 1);
    [self.manager stopOperationWithType:self.taskType];
    bgTask = nil;
    XCTAssertNil([self.taskCache objectForKey:@(self.taskType)]);
}

- (void)testBackgroundTaskProtection_ForMultipleRequestsOfAType_MultipleThreads_shouldProvideProtection
{
    NSBlockOperation *operation = [[NSBlockOperation alloc] init];
    NSBlockOperation *completionOperation = [[NSBlockOperation alloc] init];
    XCTestExpectation *completion = [self expectationWithDescription:@"All requests complete"];
    [completionOperation addExecutionBlock:^{
        [completion fulfill];
        //No BG tasks should remain in cache after all requests are completed.
        XCTAssertEqual([self.taskCache count], 0);
    }];
    [completionOperation addDependency:operation];
    for (int i=0; i < 10; i++)
    {
        [operation addExecutionBlock:^{
            [self.manager startOperationWithType:self.taskType];
            // Authenticator is put in bg when user is performing 3rd party MFA
            // There should be a bg task present in the cache that is providing protection.
            XCTAssertNotNil((MSIDBackgroundTaskData *)[self.taskCache objectForKey:@(self.taskType)]);
            [self.manager stopOperationWithType:self.taskType];
        }];
    }
    [[NSOperationQueue currentQueue] addOperation:operation];
    [[NSOperationQueue currentQueue] addOperation:completionOperation];
    // All 10 threads should be done within 1 second
    [self waitForExpectationsWithTimeout:1 handler:nil];
}
#endif
@end
