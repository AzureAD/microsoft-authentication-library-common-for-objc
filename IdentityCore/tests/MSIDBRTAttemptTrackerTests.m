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
#import "MSIDBRTAttemptTracker.h"

@interface MSIDBRTAttemptTrackerTests : XCTestCase

@end

@implementation MSIDBRTAttemptTrackerTests

- (void)testInit_shouldHaveZeroAttempts
{
    MSIDBRTAttemptTracker *tracker = [[MSIDBRTAttemptTracker alloc] init];
    
    XCTAssertNotNil(tracker);
    XCTAssertEqual(tracker.attemptCount, 0);
    XCTAssertTrue(tracker.canAttemptBRT);
}

- (void)testRecordAttempt_firstAttempt_shouldSucceed
{
    MSIDBRTAttemptTracker *tracker = [[MSIDBRTAttemptTracker alloc] init];
    
    BOOL recorded = [tracker recordAttempt];
    
    XCTAssertTrue(recorded);
    XCTAssertEqual(tracker.attemptCount, 1);
    XCTAssertTrue(tracker.canAttemptBRT);
}

- (void)testRecordAttempt_secondAttempt_shouldSucceed
{
    MSIDBRTAttemptTracker *tracker = [[MSIDBRTAttemptTracker alloc] init];
    
    [tracker recordAttempt];
    BOOL recorded = [tracker recordAttempt];
    
    XCTAssertTrue(recorded);
    XCTAssertEqual(tracker.attemptCount, 2);
    XCTAssertFalse(tracker.canAttemptBRT);
}

- (void)testRecordAttempt_thirdAttempt_shouldFail
{
    MSIDBRTAttemptTracker *tracker = [[MSIDBRTAttemptTracker alloc] init];
    
    [tracker recordAttempt];
    [tracker recordAttempt];
    BOOL recorded = [tracker recordAttempt];
    
    XCTAssertFalse(recorded);
    XCTAssertEqual(tracker.attemptCount, 2);
    XCTAssertFalse(tracker.canAttemptBRT);
}

- (void)testReset_shouldResetToZero
{
    MSIDBRTAttemptTracker *tracker = [[MSIDBRTAttemptTracker alloc] init];
    
    [tracker recordAttempt];
    [tracker recordAttempt];
    XCTAssertEqual(tracker.attemptCount, 2);
    
    [tracker reset];
    
    XCTAssertEqual(tracker.attemptCount, 0);
    XCTAssertTrue(tracker.canAttemptBRT);
}

- (void)testCanAttemptBRT_shouldReturnTrueForFirstTwoAttempts
{
    MSIDBRTAttemptTracker *tracker = [[MSIDBRTAttemptTracker alloc] init];
    
    XCTAssertTrue(tracker.canAttemptBRT);
    
    [tracker recordAttempt];
    XCTAssertTrue(tracker.canAttemptBRT);
    
    [tracker recordAttempt];
    XCTAssertFalse(tracker.canAttemptBRT);
}

@end
