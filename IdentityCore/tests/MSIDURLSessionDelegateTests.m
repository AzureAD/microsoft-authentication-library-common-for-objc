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
#import "MSIDURLSessionDelegate.h"

@interface MSIDURLSessionDelegateTests : XCTestCase

@end

@implementation MSIDURLSessionDelegateTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Tests

- (void)testSessionDidReceiveChallenge_whenNoBlockProvided_shouldPerformDefaultHandling
{
    __auto_type delegate = [MSIDURLSessionDelegate new];
    __auto_type session = [NSURLSession new];
    __auto_type challendge = [NSURLAuthenticationChallenge new];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"session:didReceiveChallenge:completionHandler"];
    [delegate URLSession:session didReceiveChallenge:challendge
       completionHandler:^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential)
    {
        XCTAssertEqual(disposition, NSURLSessionAuthChallengePerformDefaultHandling);
        XCTAssertNil(credential);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSessionDidReceiveChallenge_whenBlockProvided_shouldUseHandlingProvidedByBlock
{
    __auto_type delegate = [MSIDURLSessionDelegate new];
    __auto_type session = [NSURLSession new];
    __auto_type challendge = [NSURLAuthenticationChallenge new];
    __auto_type credential = [NSURLCredential new];
    
    delegate.sessionDidReceiveAuthenticationChallengeBlock = ^void (NSURLSession *s, NSURLAuthenticationChallenge *ch, ChallengeCompletionHandler completionHandler)
    {
        XCTAssertEqual(session, s);
        XCTAssertEqual(challendge, ch);
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    };
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"session:didReceiveChallenge:completionHandler"];
    [delegate URLSession:session didReceiveChallenge:challendge
       completionHandler:^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable cr)
     {
         XCTAssertEqual(disposition, NSURLSessionAuthChallengeUseCredential);
         XCTAssertEqual(credential, cr);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSessionTaskDidReceiveChallenge_whenNoBlockProvided_shouldPerformDefaultHandling
{
    __auto_type delegate = [MSIDURLSessionDelegate new];
    __auto_type session = [NSURLSession new];
    __auto_type challendge = [NSURLAuthenticationChallenge new];
    __auto_type task = [NSURLSessionTask new];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"session:task:didReceiveChallenge:completionHandler"];
    [delegate URLSession:session task:task didReceiveChallenge:challendge completionHandler:^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential)
    {
        XCTAssertEqual(disposition, NSURLSessionAuthChallengePerformDefaultHandling);
        XCTAssertNil(credential);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSessionTaskDidReceiveChallenge_whenBlockProvided_shouldUseHandlingProvidedByBlock
{
    __auto_type delegate = [MSIDURLSessionDelegate new];
    __auto_type session = [NSURLSession new];
    __auto_type challendge = [NSURLAuthenticationChallenge new];
    __auto_type credential = [NSURLCredential new];
    __auto_type task = [NSURLSessionTask new];
    
    delegate.taskDidReceiveAuthenticationChallengeBlock = ^void (NSURLSession *s, NSURLSessionTask *t, NSURLAuthenticationChallenge *ch, ChallengeCompletionHandler completionHandler)
    {
        XCTAssertEqual(session, s);
        XCTAssertEqual(task, t);
        XCTAssertEqual(challendge, ch);
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    };
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"session:didReceiveChallenge:completionHandler"];
    [delegate URLSession:session task:task didReceiveChallenge:challendge
       completionHandler:^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable cr)
     {
         XCTAssertEqual(disposition, NSURLSessionAuthChallengeUseCredential);
         XCTAssertEqual(credential, cr);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
