//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDConstants.h"
#import "MSIDOnboardingBlobFieldKeys.h"
#import "MSIDNTLMHandler.h"
#import "MSIDNTLMHandler+Testing.h"

#if !MSID_EXCLUDE_WEBKIT

// Expose private methods for testing
@interface MSIDOAuth2EmbeddedWebviewController (Testing)
- (BOOL)shouldOpenURLInSystemBrowser:(NSURL *)url targetFrame:(WKFrameInfo *)targetFrame;
- (NSString *)onboardingStepForEndURL:(NSURL *)endURL;
- (void)setMainFrameHostForTesting:(NSString *)host;
@end

@interface MSIDOAuth2EmbeddedWebviewControllerTests : XCTestCase

@end

// Helper: a minimal NSURLAuthenticationChallengeSender that satisfies the protocol requirement
@interface MSIDTestEmbeddedWebviewChallengeSender : NSObject <NSURLAuthenticationChallengeSender>
@end

@implementation MSIDTestEmbeddedWebviewChallengeSender

- (void)useCredential:(__unused NSURLCredential *)credential
   forAuthenticationChallenge:(__unused NSURLAuthenticationChallenge *)challenge {}

- (void)continueWithoutCredentialForAuthenticationChallenge:(__unused NSURLAuthenticationChallenge *)challenge {}

- (void)cancelAuthenticationChallenge:(__unused NSURLAuthenticationChallenge *)challenge {}

@end

@implementation MSIDOAuth2EmbeddedWebviewControllerTests

- (void)setUp {
    [super setUp];

    MSIDFlightManagerMockProvider *flightProvider = [MSIDFlightManagerMockProvider new];
    flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_OPEN_NEW_WINDOW_IN_BROWSER: @NO};
    MSIDFlightManager.sharedInstance.flightProvider = flightProvider;
    [MSIDNTLMHandler resetHandler];
}

- (void)tearDown {
    [MSIDNTLMHandler resetHandler];
    MSIDFlightManager.sharedInstance.flightProvider = nil;
    [super tearDown];
}

- (MSIDOAuth2EmbeddedWebviewController *)createTestWebviewController
{
    return [[MSIDOAuth2EmbeddedWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];
}


- (void)testInitWithStartURL_whenURLisNil_shouldFail
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [[MSIDOAuth2EmbeddedWebviewController alloc] initWithStartURL:nil
                                                                                                        endURL:[NSURL URLWithString:@"endurl://host"]
                                                                                                       webview:nil
                                                                                                 customHeaders:nil
                                                                                                platfromParams:nil
                                                                                                       context:nil];
    
    XCTAssertNil(webVC);
    
}


- (void)testInitWithStartURL_whenEndURLisNil_shouldFail
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [[MSIDOAuth2EmbeddedWebviewController alloc]
                                                  initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                            endURL:nil
                                                           webview:nil
                                                     customHeaders:nil
                                                    platfromParams:nil
                                                           context:nil];
    XCTAssertNil(webVC);
    
}


- (void)testInitWithStartURL_whenStartURLandEndURLValid_shouldSucceed
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [[MSIDOAuth2EmbeddedWebviewController alloc]
                                                  initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                            endURL:[NSURL URLWithString:@"endurl://host"]
                                                           webview:nil
                                                     customHeaders:nil
                                                    platfromParams:nil
                                                           context:nil];
    XCTAssertNotNil(webVC);
    
}

#pragma mark - shouldOpenURLInSystemBrowser tests

- (void)testShouldOpenURL_whenHttpsURLWithNilTargetFrame_shouldReturnYes
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    NSURL *url = [NSURL URLWithString:@"https://support.microsoft.com/help"];
    XCTAssertTrue([webVC shouldOpenURLInSystemBrowser:url targetFrame:nil]);
}

- (void)testShouldOpenURL_whenHttpURL_shouldReturnNo
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    NSURL *url = [NSURL URLWithString:@"http://insecure.example.com"];
    XCTAssertFalse([webVC shouldOpenURLInSystemBrowser:url targetFrame:nil]);
}

- (void)testShouldOpenURL_whenCustomScheme_shouldReturnYes
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    NSURL *url = [NSURL URLWithString:@"msauth://com.contoso.app/callback"];
    XCTAssertTrue([webVC shouldOpenURLInSystemBrowser:url targetFrame:nil]);
}

- (void)testShouldOpenURL_whenSchemelessURL_shouldReturnNo
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    NSURL *url = [NSURL URLWithString:@"/relative/path"];
    XCTAssertFalse([webVC shouldOpenURLInSystemBrowser:url targetFrame:nil]);
}

- (void)testShouldOpenURL_whenNilURL_shouldReturnNo
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    XCTAssertFalse([webVC shouldOpenURLInSystemBrowser:nil targetFrame:nil]);
}

#pragma mark - onboardingStepForFwlinkEndURL tests

- (void)testOnboardingStepForFwlinkEndURL_whenLinkId396941_shouldReturnMdmEnrollmentStarted
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.microsoft.com/fwlink/?LinkId=396941"];
    XCTAssertEqualObjects([webVC onboardingStepForEndURL:url], MSIDOnboardingBlobStepMdmEnrollmentStarted);
}

- (void)testOnboardingStepForFwlinkEndURL_whenLinkId2132314Lowercase_shouldReturnMdmEnrollmentStarted
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.microsoft.com/fwlink/?linkid=2132314"];
    XCTAssertEqualObjects([webVC onboardingStepForEndURL:url], MSIDOnboardingBlobStepMdmEnrollmentStarted);
}

- (void)testOnboardingStepForFwlinkEndURL_whenLinkId2114747Lowercase_shouldReturnMdmEnrollmentStarted
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.microsoft.com/fwlink/?linkid=2114747"];
    XCTAssertEqualObjects([webVC onboardingStepForEndURL:url], MSIDOnboardingBlobStepMdmEnrollmentStarted);
}

- (void)testOnboardingStepForFwlinkEndURL_whenLinkId399153_shouldReturnMdmEnrollmentStarted
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.microsoft.com/fwlink/?LinkId=399153"];
    XCTAssertEqualObjects([webVC onboardingStepForEndURL:url], MSIDOnboardingBlobStepMdmEnrollmentStarted);
}

- (void)testOnboardingStepForFwlinkEndURL_whenNoTrailingSlash_shouldReturnMdmEnrollmentStarted
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.microsoft.com/fwlink?LinkId=396941"];
    XCTAssertEqualObjects([webVC onboardingStepForEndURL:url], MSIDOnboardingBlobStepMdmEnrollmentStarted);
}

- (void)testOnboardingStepForFwlinkEndURL_whenLinkIdKeyUpperCase_shouldReturnMdmEnrollmentStarted
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.microsoft.com/fwlink/?LINKID=396941"];
    XCTAssertEqualObjects([webVC onboardingStepForEndURL:url], MSIDOnboardingBlobStepMdmEnrollmentStarted);
}

- (void)testOnboardingStepForFwlinkEndURL_whenExtraQueryParamsAndReorder_shouldReturnMdmEnrollmentStarted
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.microsoft.com/fwlink/?clcid=0x409&LinkId=396941&foo=bar"];
    XCTAssertEqualObjects([webVC onboardingStepForEndURL:url], MSIDOnboardingBlobStepMdmEnrollmentStarted);
}

- (void)testOnboardingStepForFwlinkEndURL_whenSchemeAndHostMixedCase_shouldReturnMdmEnrollmentStarted
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"BROWSER://Go.Microsoft.com/FwLink/?LinkId=396941"];
    XCTAssertEqualObjects([webVC onboardingStepForEndURL:url], MSIDOnboardingBlobStepMdmEnrollmentStarted);
}

- (void)testOnboardingStepForFwlinkEndURL_whenNilURL_shouldReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNil([webVC onboardingStepForEndURL:nil]);
}

- (void)testOnboardingStepForFwlinkEndURL_whenHttpsScheme_shouldReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"https://go.microsoft.com/fwlink/?LinkId=396941"];
    XCTAssertNil([webVC onboardingStepForEndURL:url]);
}

- (void)testOnboardingStepForFwlinkEndURL_whenWrongHost_shouldReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.example.com/fwlink/?LinkId=396941"];
    XCTAssertNil([webVC onboardingStepForEndURL:url]);
}

- (void)testOnboardingStepForFwlinkEndURL_whenPathHasSuffix_shouldReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.microsoft.com/fwlink2/?LinkId=396941"];
    XCTAssertNil([webVC onboardingStepForEndURL:url]);
}

- (void)testOnboardingStepForFwlinkEndURL_whenPathHasPrefix_shouldReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.microsoft.com/foo/fwlink?LinkId=396941"];
    XCTAssertNil([webVC onboardingStepForEndURL:url]);
}

- (void)testOnboardingStepForFwlinkEndURL_whenUnknownLinkIdValue_shouldReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.microsoft.com/fwlink/?LinkId=12345"];
    XCTAssertNil([webVC onboardingStepForEndURL:url]);
}

- (void)testOnboardingStepForFwlinkEndURL_whenLinkIdMissing_shouldReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.microsoft.com/fwlink/?foo=bar"];
    XCTAssertNil([webVC onboardingStepForEndURL:url]);
}

- (void)testOnboardingStepForFwlinkEndURL_whenLinkIdValueEmpty_shouldReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    NSURL *url = [NSURL URLWithString:@"browser://go.microsoft.com/fwlink/?LinkId="];
    XCTAssertNil([webVC onboardingStepForEndURL:url]);
}

#pragma mark - NTLM challenge host validation tests

- (NSURLAuthenticationChallenge *)ntlmChallengeWithHost:(NSString *)host
{
    NSURLProtectionSpace *space = [[NSURLProtectionSpace alloc] initWithHost:host
                                                                        port:443
                                                                    protocol:NSURLProtectionSpaceHTTPS
                                                                       realm:nil
                                                        authenticationMethod:NSURLAuthenticationMethodNTLM];
    MSIDTestEmbeddedWebviewChallengeSender *sender = [MSIDTestEmbeddedWebviewChallengeSender new];
    return [[NSURLAuthenticationChallenge alloc] initWithProtectionSpace:space
                                                      proposedCredential:nil
                                                    previousFailureCount:0
                                                         failureResponse:nil
                                                                   error:nil
                                                                  sender:sender];
}

- (void)testNTLMChallenge_whenHostMatchesStartURLHost_shouldForwardToHandler
{
    // Controller's startURL host is "contoso.com"; challenge from same host should
    // reach MSIDNTLMHandler (intercepted via test-prompt block).
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    __block BOOL promptReached = NO;
    [MSIDNTLMHandler setTestPromptBlock:^(__unused NSString *host, ChallengeCompletionHandler completionHandler)
    {
        promptReached = YES;
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];
    [webVC webView:nil
        didReceiveAuthenticationChallenge:[self ntlmChallengeWithHost:@"contoso.com"]
                        completionHandler:^(__unused NSURLSessionAuthChallengeDisposition disposition, __unused NSURLCredential *credential)
    {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertTrue(promptReached, @"NTLM challenge from the startURL host should be forwarded to the handler");
}

- (void)testNTLMChallenge_whenHostDoesNotMatchStartURLHost_shouldCancel
{
    // Challenge from a host other than the startURL host must be cancelled immediately.
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    __block BOOL promptReached = NO;
    [MSIDNTLMHandler setTestPromptBlock:^(__unused NSString *host, ChallengeCompletionHandler completionHandler)
    {
        promptReached = YES;
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];
    __block NSURLSessionAuthChallengeDisposition capturedDisposition = NSURLSessionAuthChallengeUseCredential;
    [webVC webView:nil
        didReceiveAuthenticationChallenge:[self ntlmChallengeWithHost:@"evil.example.com"]
                        completionHandler:^(NSURLSessionAuthChallengeDisposition disposition, __unused NSURLCredential *credential)
    {
        capturedDisposition = disposition;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertFalse(promptReached, @"NTLM prompt must not be shown for an untrusted host");
    XCTAssertEqual(capturedDisposition, NSURLSessionAuthChallengeCancelAuthenticationChallenge);
}

- (void)testNTLMChallenge_whenHostMatchesCaseInsensitive_shouldForwardToHandler
{
    // Host comparison must be case-insensitive: "CONTOSO.COM" should match "contoso.com".
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    __block BOOL promptReached = NO;
    [MSIDNTLMHandler setTestPromptBlock:^(__unused NSString *host, ChallengeCompletionHandler completionHandler)
    {
        promptReached = YES;
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];
    [webVC webView:nil
        didReceiveAuthenticationChallenge:[self ntlmChallengeWithHost:@"CONTOSO.COM"]
                        completionHandler:^(__unused NSURLSessionAuthChallengeDisposition disposition, __unused NSURLCredential *credential)
    {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertTrue(promptReached, @"NTLM challenge host comparison must be case-insensitive");
}

- (void)testNTLMChallenge_whenSubResourceHostDiffersFromMainFrameHost_shouldCancel
{
    // After the main frame navigates to a new host, a challenge from the previous host
    // (i.e., a sub-resource or rogue load) must be cancelled.
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    // Simulate the main frame navigating to adfs.contoso.com
    [webVC setMainFrameHostForTesting:@"adfs.contoso.com"];

    __block BOOL promptReached = NO;
    [MSIDNTLMHandler setTestPromptBlock:^(__unused NSString *host, ChallengeCompletionHandler completionHandler)
    {
        promptReached = YES;
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }];

    // Issue a challenge from the original startURL host (no longer the main-frame host).
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];
    __block NSURLSessionAuthChallengeDisposition capturedDisposition = NSURLSessionAuthChallengeUseCredential;
    [webVC webView:nil
        didReceiveAuthenticationChallenge:[self ntlmChallengeWithHost:@"contoso.com"]
                        completionHandler:^(NSURLSessionAuthChallengeDisposition disposition, __unused NSURLCredential *credential)
    {
        capturedDisposition = disposition;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertFalse(promptReached, @"Sub-resource NTLM challenge must not trigger a prompt");
    XCTAssertEqual(capturedDisposition, NSURLSessionAuthChallengeCancelAuthenticationChallenge);
}

@end

#endif
