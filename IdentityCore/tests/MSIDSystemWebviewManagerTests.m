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

#if !MSID_EXCLUDE_SYSTEMWV

#import <XCTest/XCTest.h>
#import "MSIDSystemWebviewManager.h"
#import "MSIDSystemWebviewController.h"
#import "MSIDError.h"
#import "MSIDTestSwizzle.h"

@interface MSIDSystemWebviewManagerTests : XCTestCase

@end

@implementation MSIDSystemWebviewManagerTests

- (void)setUp
{
    [super setUp];
    // Reset singleton state so tests are isolated from one another.
    [[MSIDSystemWebviewManager sharedInstance] setValue:@NO forKey:@"isSessionInProgress"];
    [[MSIDSystemWebviewManager sharedInstance] setValue:nil forKey:@"webviewController"];
}

- (void)tearDown
{
    [MSIDTestSwizzle reset];
    [[MSIDSystemWebviewManager sharedInstance] setValue:@NO forKey:@"isSessionInProgress"];
    [[MSIDSystemWebviewManager sharedInstance] setValue:nil forKey:@"webviewController"];
    [super tearDown];
}

- (void)testSharedInstance_shouldReturnSameInstance
{
    MSIDSystemWebviewManager *first = [MSIDSystemWebviewManager sharedInstance];
    MSIDSystemWebviewManager *second = [MSIDSystemWebviewManager sharedInstance];
    XCTAssertEqual(first, second);
}

- (void)testLaunch_whenNilCompletionBlock_shouldNotCrash
{
    // Should not crash and isSessionInProgress must remain NO.
    [[MSIDSystemWebviewManager sharedInstance] launchSystemWebviewWithURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                              redirectURI:@"some://redirecturi"
                                                         parentController:nil
                                                 useAuthenticationSession:YES
                                                allowSafariViewController:NO
                                                      useEphemeralSession:NO
                                                        additionalHeaders:nil
                                                                  context:nil
                                                          completionBlock:nil];

    XCTAssertFalse([MSIDSystemWebviewManager sharedInstance].isSessionInProgress);
}

- (void)testLaunch_whenNilURL_shouldCallCompletionWithInternalError
{
    __block NSURL *receivedURL = nil;
    __block NSError *receivedError = nil;

    [[MSIDSystemWebviewManager sharedInstance] launchSystemWebviewWithURL:nil
                                                              redirectURI:@"some://redirecturi"
                                                         parentController:nil
                                                 useAuthenticationSession:YES
                                                allowSafariViewController:NO
                                                      useEphemeralSession:NO
                                                        additionalHeaders:nil
                                                                  context:nil
                                                          completionBlock:^(NSURL *url, NSError *error)
    {
        receivedURL = url;
        receivedError = error;
    }];

    XCTAssertNil(receivedURL);
    XCTAssertNotNil(receivedError);
    XCTAssertEqual(receivedError.code, MSIDErrorInternal);
    XCTAssertFalse([MSIDSystemWebviewManager sharedInstance].isSessionInProgress);
}

- (void)testLaunch_whenSessionAlreadyInProgress_shouldCallCompletionWithAlreadyRunningError
{
    [[MSIDSystemWebviewManager sharedInstance] setValue:@YES forKey:@"isSessionInProgress"];

    __block NSURL *receivedURL = nil;
    __block NSError *receivedError = nil;

    [[MSIDSystemWebviewManager sharedInstance] launchSystemWebviewWithURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                              redirectURI:@"some://redirecturi"
                                                         parentController:nil
                                                 useAuthenticationSession:YES
                                                allowSafariViewController:NO
                                                      useEphemeralSession:NO
                                                        additionalHeaders:nil
                                                                  context:nil
                                                          completionBlock:^(NSURL *url, NSError *error)
    {
        receivedURL = url;
        receivedError = error;
    }];

    XCTAssertNil(receivedURL);
    XCTAssertNotNil(receivedError);
    XCTAssertEqual(receivedError.code, MSIDErrorInteractiveSessionAlreadyRunning);
    // isSessionInProgress should stay YES because the pre-existing session is still live.
    XCTAssertTrue([MSIDSystemWebviewManager sharedInstance].isSessionInProgress);
}

- (void)testLaunch_whenControllerCreationFails_shouldCallCompletionWithInternalErrorAndResetProgress
{
    // A nil redirectURI causes MSIDSystemWebviewController to return nil.
    __block NSURL *receivedURL = nil;
    __block NSError *receivedError = nil;

    [[MSIDSystemWebviewManager sharedInstance] launchSystemWebviewWithURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                              redirectURI:nil
                                                         parentController:nil
                                                 useAuthenticationSession:YES
                                                allowSafariViewController:NO
                                                      useEphemeralSession:NO
                                                        additionalHeaders:nil
                                                                  context:nil
                                                          completionBlock:^(NSURL *url, NSError *error)
    {
        receivedURL = url;
        receivedError = error;
    }];

    XCTAssertNil(receivedURL);
    XCTAssertNotNil(receivedError);
    XCTAssertEqual(receivedError.code, MSIDErrorInternal);
    XCTAssertFalse([MSIDSystemWebviewManager sharedInstance].isSessionInProgress);
}

- (void)testLaunch_whenValidParameters_shouldSetSessionInProgressWhileRunning
{
    __block MSIDWebUICompletionHandler capturedCompletion = nil;

    [MSIDTestSwizzle instanceMethod:@selector(startWithCompletionHandler:)
                              class:[MSIDSystemWebviewController class]
                              block:(id)^(__unused id obj, MSIDWebUICompletionHandler completionHandler)
    {
        capturedCompletion = completionHandler;
    }];

    [[MSIDSystemWebviewManager sharedInstance] launchSystemWebviewWithURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                              redirectURI:@"some://redirecturi"
                                                         parentController:nil
                                                 useAuthenticationSession:YES
                                                allowSafariViewController:NO
                                                      useEphemeralSession:NO
                                                        additionalHeaders:nil
                                                                  context:nil
                                                          completionBlock:^(__unused NSURL *url, __unused NSError *error) {}];

    XCTAssertTrue([MSIDSystemWebviewManager sharedInstance].isSessionInProgress);
    XCTAssertNotNil(capturedCompletion);
}

- (void)testLaunch_whenSessionCompletesSuccessfully_shouldResetSessionInProgressAndForwardCallbackURL
{
    NSURL *expectedCallbackURL = [NSURL URLWithString:@"some://redirecturi?code=auth_code"];
    __block MSIDWebUICompletionHandler capturedCompletion = nil;
    __block NSURL *receivedURL = nil;
    __block NSError *receivedError = nil;

    [MSIDTestSwizzle instanceMethod:@selector(startWithCompletionHandler:)
                              class:[MSIDSystemWebviewController class]
                              block:(id)^(__unused id obj, MSIDWebUICompletionHandler completionHandler)
    {
        capturedCompletion = completionHandler;
    }];

    [[MSIDSystemWebviewManager sharedInstance] launchSystemWebviewWithURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                              redirectURI:@"some://redirecturi"
                                                         parentController:nil
                                                 useAuthenticationSession:YES
                                                allowSafariViewController:NO
                                                      useEphemeralSession:NO
                                                        additionalHeaders:nil
                                                                  context:nil
                                                          completionBlock:^(NSURL *url, NSError *error)
    {
        receivedURL = url;
        receivedError = error;
    }];

    XCTAssertTrue([MSIDSystemWebviewManager sharedInstance].isSessionInProgress);

    // Simulate the session completing with a callback URL.
    capturedCompletion(expectedCallbackURL, nil);

    XCTAssertFalse([MSIDSystemWebviewManager sharedInstance].isSessionInProgress);
    XCTAssertEqualObjects(receivedURL, expectedCallbackURL);
    XCTAssertNil(receivedError);
}

- (void)testLaunch_whenSessionCompletesWithError_shouldResetSessionInProgressAndForwardError
{
    NSError *sessionError = [NSError errorWithDomain:MSIDErrorDomain code:MSIDErrorUserCancel userInfo:nil];
    __block MSIDWebUICompletionHandler capturedCompletion = nil;
    __block NSURL *receivedURL = nil;
    __block NSError *receivedError = nil;

    [MSIDTestSwizzle instanceMethod:@selector(startWithCompletionHandler:)
                              class:[MSIDSystemWebviewController class]
                              block:(id)^(__unused id obj, MSIDWebUICompletionHandler completionHandler)
    {
        capturedCompletion = completionHandler;
    }];

    [[MSIDSystemWebviewManager sharedInstance] launchSystemWebviewWithURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                              redirectURI:@"some://redirecturi"
                                                         parentController:nil
                                                 useAuthenticationSession:YES
                                                allowSafariViewController:NO
                                                      useEphemeralSession:NO
                                                        additionalHeaders:nil
                                                                  context:nil
                                                          completionBlock:^(NSURL *url, NSError *error)
    {
        receivedURL = url;
        receivedError = error;
    }];

    // Simulate the session completing with an error.
    capturedCompletion(nil, sessionError);

    XCTAssertFalse([MSIDSystemWebviewManager sharedInstance].isSessionInProgress);
    XCTAssertNil(receivedURL);
    XCTAssertEqualObjects(receivedError, sessionError);
}

@end

#endif
