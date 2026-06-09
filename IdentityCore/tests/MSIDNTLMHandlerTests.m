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
#import "MSIDNTLMHandler.h"
#import "MSIDNTLMHandler+Testing.h"
#import "MSIDTestContext.h"

@interface MSIDTestNTLMChallengeSender : NSObject <NSURLAuthenticationChallengeSender>
@end

@implementation MSIDTestNTLMChallengeSender

- (void)useCredential:(__unused NSURLCredential *)credential
   forAuthenticationChallenge:(__unused NSURLAuthenticationChallenge *)challenge
{
}

- (void)continueWithoutCredentialForAuthenticationChallenge:(__unused NSURLAuthenticationChallenge *)challenge
{
}

- (void)cancelAuthenticationChallenge:(__unused NSURLAuthenticationChallenge *)challenge
{
}

@end

@interface MSIDNTLMHandlerTests : XCTestCase

@end

@implementation MSIDNTLMHandlerTests

- (void)setUp
{
    [super setUp];
    [MSIDNTLMHandler resetHandler];
}

- (void)tearDown
{
    [MSIDNTLMHandler resetHandler];
    [super tearDown];
}

#pragma mark - Helpers

- (NSURLAuthenticationChallenge *)challengeWithHost:(NSString *)host
{
    NSURLProtectionSpace *space = [[NSURLProtectionSpace alloc] initWithHost:host
                                                                       port:443
                                                                   protocol:NSURLProtectionSpaceHTTPS
                                                                      realm:nil
                                                       authenticationMethod:NSURLAuthenticationMethodNTLM];
    MSIDTestNTLMChallengeSender *sender = [MSIDTestNTLMChallengeSender new];
    return [[NSURLAuthenticationChallenge alloc] initWithProtectionSpace:space
                                                     proposedCredential:nil
                                                    previousFailureCount:0
                                                        failureResponse:nil
                                                                  error:nil
                                                                 sender:sender];
}

#pragma mark - Prompt-display tests

- (void)testHandleChallenge_shouldPresentPromptWithHostName
{
    __block NSString *capturedHost = nil;
    __block BOOL promptCalled = NO;

    [MSIDNTLMHandler setTestPromptBlock:^(NSString *host, ChallengeCompletionHandler completionHandler)
    {
        capturedHost = host;
        promptCalled = YES;
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }];

    MSIDTestContext *context = [MSIDTestContext new];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];

    BOOL handled = [MSIDNTLMHandler handleChallenge:[self challengeWithHost:@"login.contoso.com"]
                                            webview:nil
#if TARGET_OS_IPHONE
                                   parentController:nil
#endif
                                            context:context
                                  completionHandler:^(__unused NSURLSessionAuthChallengeDisposition disposition, __unused NSURLCredential *credential)
    {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertTrue(handled);
    XCTAssertTrue(promptCalled);
    XCTAssertEqualObjects(capturedHost, @"login.contoso.com");
}

- (void)testHandleChallenge_whenEmptyHost_shouldCallPromptWithEmptyHost
{
    __block NSString *capturedHost = @"non-nil-sentinel";

    [MSIDNTLMHandler setTestPromptBlock:^(NSString *host, ChallengeCompletionHandler completionHandler)
    {
        capturedHost = host;
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }];

    NSURLProtectionSpace *space = [[NSURLProtectionSpace alloc] initWithHost:@""
                                                                       port:443
                                                                   protocol:NSURLProtectionSpaceHTTPS
                                                                      realm:nil
                                                       authenticationMethod:NSURLAuthenticationMethodNTLM];
    MSIDTestNTLMChallengeSender *sender = [MSIDTestNTLMChallengeSender new];
    NSURLAuthenticationChallenge *challenge = [[NSURLAuthenticationChallenge alloc]
                                               initWithProtectionSpace:space
                                               proposedCredential:nil
                                               previousFailureCount:0
                                               failureResponse:nil
                                               error:nil
                                               sender:sender];

    MSIDTestContext *context = [MSIDTestContext new];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];

    [MSIDNTLMHandler handleChallenge:challenge
                             webview:nil
#if TARGET_OS_IPHONE
                    parentController:nil
#endif
                             context:context
                   completionHandler:^(__unused NSURLSessionAuthChallengeDisposition disposition, __unused NSURLCredential *credential)
    {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertEqualObjects(capturedHost, @"");
}

#pragma mark - Reset tests

- (void)testResetHandler_shouldClearTestPromptBlock
{
    __block BOOL firstBlockCalled = NO;
    __block BOOL secondBlockCalled = NO;

    [MSIDNTLMHandler setTestPromptBlock:^(__unused NSString *host, ChallengeCompletionHandler completionHandler)
    {
        firstBlockCalled = YES;
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }];

    [MSIDNTLMHandler resetHandler];

    // After reset, install a new block and issue a challenge — only the new block should fire.
    [MSIDNTLMHandler setTestPromptBlock:^(__unused NSString *host, ChallengeCompletionHandler completionHandler)
    {
        secondBlockCalled = YES;
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }];

    MSIDTestContext *context = [MSIDTestContext new];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];

    [MSIDNTLMHandler handleChallenge:[self challengeWithHost:@"host.example.com"]
                             webview:nil
#if TARGET_OS_IPHONE
                    parentController:nil
#endif
                             context:context
                   completionHandler:^(__unused NSURLSessionAuthChallengeDisposition disposition, __unused NSURLCredential *credential)
    {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertFalse(firstBlockCalled);
    XCTAssertTrue(secondBlockCalled);
}

@end
