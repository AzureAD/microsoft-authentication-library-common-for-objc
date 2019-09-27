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
#import "MSIDWebviewAuthorization.h"
#import "MSIDTestWebviewInteractingViewController.h"
#import "MSIDOauth2Factory.h"
#import "MSIDWebviewFactory.h"

#if !MSID_EXCLUDE_WEBKIT

@interface MSIDWebviewAuthorizationTests : XCTestCase

@end

@implementation MSIDWebviewAuthorizationTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    
    [MSIDWebviewAuthorization cancelCurrentSession];
}


- (MSIDWebviewSession *)sessionWithSuccessfulResponse
{
    MSIDTestWebviewInteractingViewController *testWebviewController = [MSIDTestWebviewInteractingViewController new];
    testWebviewController.successAfterInterval = 0.1;
    
    MSIDWebviewSession *session = [[MSIDWebviewSession alloc] initWithWebviewController:testWebviewController
                                                                                factory:[MSIDWebviewFactory new]
                                                                           requestState:nil
                                                                     ignoreInvalidState:NO];
    return session;
}


- (MSIDWebviewSession *)sessionWithFailedResponse
{
    MSIDTestWebviewInteractingViewController *testWebviewController = [MSIDTestWebviewInteractingViewController new];
    testWebviewController.successAfterInterval = 0.0;

    MSIDWebviewSession *session = [[MSIDWebviewSession alloc] initWithWebviewController:testWebviewController
                                                                                factory:[MSIDWebviewFactory new]
                                                                           requestState:nil
                                                                     ignoreInvalidState:NO];
    return session;
}

#pragma mark - Webview starting
- (void)testStartSession_whenSessionIsNil_shouldReturnErrorAtCompletionHandler
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    
    [MSIDWebviewAuthorization startSession:nil
                                   context:nil
                         completionHandler:^(MSIDWebviewResponse *response, NSError *error) {
                             XCTAssertNil(response);
                             XCTAssertNotNil(error);
                             XCTAssertEqual(error.code, MSIDErrorInternal);
                             
                             [expectation fulfill];
                         }];
    
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

- (void)testStartSession_whenNoSessionRunning_shouldStart
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];

    [MSIDWebviewAuthorization startSession:[self sessionWithSuccessfulResponse]
                                   context:nil
                         completionHandler:^(MSIDWebviewResponse *response, NSError *error) {
                             XCTAssertNotNil(response);
                             XCTAssertNil(error);
                             [expectation fulfill];
                         }];

    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}


- (void)testStartSession_whenNewSessionAfterCompletion_shouldStart
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];

    [MSIDWebviewAuthorization startSession:[self sessionWithSuccessfulResponse]
                                   context:nil
                         completionHandler:^(MSIDWebviewResponse *response, NSError *error) {
                             [expectation fulfill];
                         }];

    [self waitForExpectationsWithTimeout:0.5 handler:nil];

    expectation = [self expectationWithDescription:@"wait for response"];
    [MSIDWebviewAuthorization startSession:[self sessionWithSuccessfulResponse]
                                   context:nil
                         completionHandler:^(MSIDWebviewResponse *response, NSError *error) {
                             XCTAssertNotNil(response);
                             XCTAssertNil(error);
                             [expectation fulfill];
                         }];

    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}


- (void)testStartSession_whenSessionRunning_shouldNotStartAndReturnError
{
    MSIDWebviewSession *session = [[MSIDWebviewSession alloc] initWithWebviewController:nil factory:nil requestState:nil ignoreInvalidState:NO];
    XCTAssertTrue([MSIDWebviewAuthorization setCurrentSession:session]);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    
    [MSIDWebviewAuthorization startSession:[self sessionWithSuccessfulResponse]
                                   context:nil
                         completionHandler:^(MSIDWebviewResponse *response, NSError *error) {
                             XCTAssertNil(response);
                             XCTAssertNotNil(error);

                             XCTAssertEqual(error.code, MSIDErrorInteractiveSessionAlreadyRunning);
                             
                             [expectation fulfill];
                         }];
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}


#pragma mark - Session clearing
- (void)testStartSession_whenComplete_shouldClearSession
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    [MSIDWebviewAuthorization startSession:[self sessionWithSuccessfulResponse]
                                   context:nil
                         completionHandler:^(MSIDWebviewResponse *response, NSError *error) {
                             [expectation fulfill];
                         }];

    [self waitForExpectationsWithTimeout:0.5 handler:nil];

    XCTAssertNil([MSIDWebviewAuthorization currentSession]);
}

- (void)testStartSession_whenCompleteWithFail_shouldClearSession
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    [MSIDWebviewAuthorization startSession:[self sessionWithFailedResponse]
                                   context:nil
                         completionHandler:^(MSIDWebviewResponse *response, NSError *error) {
                             [expectation fulfill];
                         }];


    [self waitForExpectationsWithTimeout:0.5 handler:nil];

    XCTAssertNil([MSIDWebviewAuthorization currentSession]);
}


- (void)testCancelCurrentSession_whenCurrentSession_shouldClearCurrentSession
{
    MSIDWebviewSession *session = [[MSIDWebviewSession alloc] initWithWebviewController:nil factory:nil requestState:nil ignoreInvalidState:NO];
    [MSIDWebviewAuthorization setCurrentSession:session];
    
    [MSIDWebviewAuthorization cancelCurrentSession];
    
    XCTAssertNil([MSIDWebviewAuthorization currentSession]);
}


#pragma mark - Handle response
#if TARGET_OS_IPHONE && !MSID_EXCLUDE_SYSTEMWV
- (void)testHandleURLResponseForSystemWebviewController_whenCurrentSessionIsSafari_shouldHandleURL
{
    MSIDTestWebviewInteractingViewController *testWebviewController = [MSIDTestWebviewInteractingViewController new];
    testWebviewController.successAfterInterval = 0.5;
    testWebviewController.actAsSafariViewController = YES;

    MSIDWebviewSession *session = [[MSIDWebviewSession alloc] initWithWebviewController:testWebviewController
                                                                                factory:[MSIDWebviewFactory new]
                                                                           requestState:nil
                                                                     ignoreInvalidState:YES];

    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    [MSIDWebviewAuthorization startSession:session
                                   context:nil
                         completionHandler:^(MSIDWebviewResponse *response, NSError *error) {
                             [expectation fulfill];
                         }];

    XCTAssertTrue([MSIDWebviewAuthorization handleURLResponseForSystemWebviewController:[NSURL URLWithString:@"some://urlhere"]]);
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

- (void)testHandleURLResponseForSystemWebviewController_whenCurrentSessionIsAuthenticationSession_shouldHandleURL
{
    MSIDTestWebviewInteractingViewController *testWebviewController = [MSIDTestWebviewInteractingViewController new];
    testWebviewController.successAfterInterval = 0.5;
    testWebviewController.actAsAuthenticationSession = YES;
    
    MSIDWebviewSession *session = [[MSIDWebviewSession alloc] initWithWebviewController:testWebviewController
                                                                                factory:[MSIDWebviewFactory new]
                                                                           requestState:nil
                                                                     ignoreInvalidState:YES];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    [MSIDWebviewAuthorization startSession:session
                                   context:nil
                         completionHandler:^(MSIDWebviewResponse *response, NSError *error) {
                             [expectation fulfill];
                         }];
    
    XCTAssertTrue([MSIDWebviewAuthorization handleURLResponseForSystemWebviewController:[NSURL URLWithString:@"some://urlhere"]]);
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

- (void)testHandleURLResponseForSystemWebviewController_whenCurrentSessionIsNotSafari_shouldHandleURL
{
    MSIDTestWebviewInteractingViewController *testWebviewController = [MSIDTestWebviewInteractingViewController new];
    testWebviewController.successAfterInterval = 0.5;
    testWebviewController.actAsSafariViewController = NO;

    MSIDWebviewSession *session = [[MSIDWebviewSession alloc] initWithWebviewController:testWebviewController
                                                                                factory:[MSIDWebviewFactory new]
                                                                           requestState:nil
                                                                     ignoreInvalidState:YES];

    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    [MSIDWebviewAuthorization startSession:session
                                   context:nil
                         completionHandler:^(MSIDWebviewResponse *response, NSError *error) {
                             [expectation fulfill];
                         }];

    XCTAssertFalse([MSIDWebviewAuthorization handleURLResponseForSystemWebviewController:nil]);
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

#endif

@end

#endif
