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

@interface MSIDWebviewAuthorizationTests : XCTestCase

@end

@implementation MSIDWebviewAuthorizationTests

- (MSIDTestWebviewInteractingViewController *)testViewController:(NSTimeInterval)successAfter
{
    MSIDTestWebviewInteractingViewController *testWebviewController = [MSIDTestWebviewInteractingViewController new];
    testWebviewController.successAfterInterval = successAfter;
    return testWebviewController;
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark - Webview starting
- (void)testStartWebviewAuth_whenNoSessionRunning_shouldStart
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    [MSIDWebviewAuthorization startWebviewAuth:[self testViewController:0.1]
                                       context:nil
                             completionHandler:^(MSIDWebOAuth2Response *response, NSError *error) {
                                 XCTAssertNotNil(response);
                                 XCTAssertNil(error);
                                 [expectation fulfill];
                             }];
    
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}


- (void)testStartWebviewAuth_whenSessionRunning_shouldNotStartAndReturnError
{
    [MSIDWebviewAuthorization startWebviewAuth:[self testViewController:0.5]
                                       context:nil
                             completionHandler:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    [MSIDWebviewAuthorization startWebviewAuth:[self testViewController:0.5]
                                       context:nil
                             completionHandler:^(MSIDWebOAuth2Response *response, NSError *error) {
                                 XCTAssertNil(response);
                                 XCTAssertNotNil(error);
                                 
                                 XCTAssertEqual(error.code, MSIDErrorInteractiveSessionAlreadyRunning);
                                 
                                 [expectation fulfill];
                             }];

    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}


#pragma mark - Session clearing
- (void)testStartWebviewAuth_whenComplete_shouldClearSession
{
    MSIDTestWebviewInteractingViewController *testWebviewController = [MSIDTestWebviewInteractingViewController new];
    testWebviewController.successAfterInterval = 0.1;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    [MSIDWebviewAuthorization startWebviewAuth:testWebviewController
                                       context:nil
                             completionHandler:^(MSIDWebOAuth2Response *response, NSError *error) {
                                 [expectation fulfill];
                             }];
    
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
    
    XCTAssertNil([MSIDWebviewAuthorization currentSession]);
}

- (void)testStartWebviewAuth_whenCompleteWithFail_shouldClearSession
{
    MSIDTestWebviewInteractingViewController *testWebviewController = [MSIDTestWebviewInteractingViewController new];
    testWebviewController.successAfterInterval = 0;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    [MSIDWebviewAuthorization startWebviewAuth:testWebviewController
                                       context:nil
                             completionHandler:^(MSIDWebOAuth2Response *response, NSError *error) {
                                 [expectation fulfill];
                             }];
    
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
    
    XCTAssertNil([MSIDWebviewAuthorization currentSession]);
}

#pragma mark - Response handling
- (void)testResponseWithURL_whenNilURL_shouldReturnNilAndError
{
    NSError *error = nil;
    XCTAssertNil([MSIDWebviewAuthorization responseWithURL:nil
                                              requestState:nil
                                             stateVerifier:nil
                                                   context:nil
                                                     error:&error]);
    XCTAssertNotNil(error);
}

- (void)testResponseWithURL_whenWPJResponseWithBrokerHost_shouldReturnWPJAuthResponse
{
    NSError *error = nil;
    __auto_type response = [MSIDWebviewAuthorization responseWithURL:[NSURL URLWithString:@"msauth://broker?app_link=link&upn=upn"]
                                                        requestState:nil
                                                       stateVerifier:nil
                                                             context:nil
                                                               error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebWPJAuthResponse.class]);
    XCTAssertNil(error);
}

- (void)testResponseWithURL_whenWPJResponseWithWPJHost_shouldReturnWPJAuthResponse
{
    NSError *error = nil;
    __auto_type response = [MSIDWebviewAuthorization responseWithURL:[NSURL URLWithString:@"msauth://wpj?app_link=link&upn=upn"]
                                                        requestState:nil
                                                       stateVerifier:nil
                                                             context:nil
                                                               error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebWPJAuthResponse.class]);
    XCTAssertNil(error);
}

- (void)testResponseWithURL_whenAADResponse_shouldReturnAADAuthResponse
{
    NSError *error = nil;
    __auto_type response = [MSIDWebviewAuthorization responseWithURL:[NSURL URLWithString:@"redirecturi://somepayload?code=authcode"]
                                                        requestState:nil
                                                       stateVerifier:nil
                                                             context:nil
                                                               error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebAADAuthResponse.class]);
    XCTAssertNil(error);
}


#pragma mark - Others
#if TARGET_OS_IPHONE
- (void)testHandleURLResponseForSystemWebviewController_whenCurrentSessionIsSafari_shouldHandleURL
{
    MSIDTestWebviewInteractingViewController *testWebviewController = [MSIDTestWebviewInteractingViewController new];
    testWebviewController.successAfterInterval = 0.1;
    testWebviewController.actSystemWebviewController = YES;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    [MSIDWebviewAuthorization startWebviewAuth:testWebviewController
                                       context:nil
                             completionHandler:^(MSIDWebOAuth2Response *response, NSError *error) {
                                 XCTAssertTrue([MSIDWebviewAuthorization handleURLResponseForSystemWebviewController:nil]);
                                 [expectation fulfill];
                             }];
    
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

- (void)testHandleURLResponseForSystemWebviewController_whenCurrentSessionIsNotSafari_shouldHandleURL
{
    MSIDTestWebviewInteractingViewController *testWebviewController = [MSIDTestWebviewInteractingViewController new];
    testWebviewController.successAfterInterval = 0.1;
    testWebviewController.actSystemWebviewController = NO;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for response"];
    [MSIDWebviewAuthorization startWebviewAuth:testWebviewController
                                       context:nil
                             completionHandler:^(MSIDWebOAuth2Response *response, NSError *error) {
                                 XCTAssertFalse([MSIDWebviewAuthorization handleURLResponseForSystemWebviewController:nil]);
                                 [expectation fulfill];
                             }];
    
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}


#endif


@end
