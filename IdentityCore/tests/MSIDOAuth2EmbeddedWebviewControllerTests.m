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
#import "MSIDWKNavigationActionMock.h"
#import "MSIDCustomHeaderProviding.h"
#import "MSIDExecutionFlowLogger.h"
#import "MSIDExecutionFlowConstants.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDOAuth2Constants.h"

#if !MSID_EXCLUDE_WEBKIT

// Expose private methods for testing
@interface MSIDOAuth2EmbeddedWebviewController (Testing)
- (BOOL)shouldOpenURLInSystemBrowser:(NSURL *)url targetFrame:(WKFrameInfo *)targetFrame;
- (NSString *)onboardingStepForEndURL:(NSURL *)endURL;
@end

// Test double that records how it was consulted and returns configurable headers.
@interface MSIDTestCustomHeaderProvider : NSObject <MSIDCustomHeaderProviding>

@property (nonatomic) NSDictionary<NSString *, NSString *> *headersToReturn;
@property (nonatomic) NSError *errorToReturn;
@property (nonatomic) BOOL wasCalled;
@property (nonatomic) NSString *capturedHost;

@end

@implementation MSIDTestCustomHeaderProvider

- (void)getCustomHeaders:(__unused NSURLRequest *)request
                 forHost:(NSString *)host
         completionBlock:(MSIDCustomHeaderBlock)completionBlock
{
    self.wasCalled = YES;
    self.capturedHost = host;

    if (completionBlock)
    {
        completionBlock(self.headersToReturn, self.errorToReturn);
    }
}

@end

// Controller subclass that captures the reloaded request instead of driving a real web view.
@interface MSIDCustomHeaderCapturingWebviewController : MSIDOAuth2EmbeddedWebviewController

@property (nonatomic) NSURLRequest *capturedLoadRequest;

@end

@implementation MSIDCustomHeaderCapturingWebviewController

- (void)loadRequest:(NSURLRequest *)request
{
    self.capturedLoadRequest = request;
}

@end

@interface MSIDOAuth2EmbeddedWebviewControllerTests : XCTestCase

@end

@implementation MSIDOAuth2EmbeddedWebviewControllerTests

- (void)setUp {
    [super setUp];

    MSIDFlightManagerMockProvider *flightProvider = [MSIDFlightManagerMockProvider new];
    flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_OPEN_NEW_WINDOW_IN_BROWSER: @NO};
    MSIDFlightManager.sharedInstance.flightProvider = flightProvider;
}

- (void)tearDown {
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

#pragma mark - customHeaderProvider host gating tests

- (void)testDecidePolicyForNavigationAction_whenKnownAADHost_andProviderReturnsHeaders_shouldInjectHeadersAndReload
{
    MSIDInteractiveTokenRequestParameters *context = [MSIDInteractiveTokenRequestParameters new];
    context.appRequestMetadata = nil;
    context.correlationId = [NSUUID UUID];
    MSIDExecutionFlowRegister(context.correlationId);

    MSIDCustomHeaderCapturingWebviewController *webVC = [[MSIDCustomHeaderCapturingWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:context];

    MSIDTestCustomHeaderProvider *provider = [MSIDTestCustomHeaderProvider new];
    provider.headersToReturn = @{ MSID_REFRESH_TOKEN_CREDENTIAL : @"FakeHeaderValue" };
    webVC.customHeaderProvider = provider;

    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/authorize"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];
    __block WKNavigationActionPolicy capturedDecision = WKNavigationActionPolicyAllow;
    [webVC decidePolicyForNavigationAction:action webview:nil decisionHandler:^(WKNavigationActionPolicy decision) {
        capturedDecision = decision;
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertTrue(provider.wasCalled);
    XCTAssertEqualObjects(provider.capturedHost, @"login.microsoftonline.com");
    XCTAssertEqual(capturedDecision, WKNavigationActionPolicyCancel);
    XCTAssertNotNil(webVC.capturedLoadRequest);
    XCTAssertEqualObjects([[webVC.capturedLoadRequest allHTTPHeaderFields] objectForKey:MSID_REFRESH_TOKEN_CREDENTIAL], @"FakeHeaderValue");

    XCTestExpectation *flowExpectation = [self expectationWithDescription:@"execution flow should contain the added tag"];
    MSIDExecutionFlowRetrieve(context.correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        // Assert presence only: both tags share the placeholder string until unique codes are assigned.
        XCTAssertTrue([executionFlow containsString:MSIDCustomHeaderTagToString(MSIDCustomHeaderAddedTag)]);
        [flowExpectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testDecidePolicyForNavigationAction_whenUntrustedHost_shouldSkipProviderAndAllowNavigation
{
    MSIDInteractiveTokenRequestParameters *context = [MSIDInteractiveTokenRequestParameters new];
    context.appRequestMetadata = nil;
    context.correlationId = [NSUUID UUID];
    MSIDExecutionFlowRegister(context.correlationId);

    MSIDCustomHeaderCapturingWebviewController *webVC = [[MSIDCustomHeaderCapturingWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:context];

    MSIDTestCustomHeaderProvider *provider = [MSIDTestCustomHeaderProvider new];
    provider.headersToReturn = @{ MSID_REFRESH_TOKEN_CREDENTIAL : @"FakeHeaderValue" };
    webVC.customHeaderProvider = provider;

    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://contoso.untrusted.com/oauth/authorize"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];
    __block WKNavigationActionPolicy capturedDecision = WKNavigationActionPolicyCancel;
    [webVC decidePolicyForNavigationAction:action webview:nil decisionHandler:^(WKNavigationActionPolicy decision) {
        capturedDecision = decision;
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertFalse(provider.wasCalled);
    XCTAssertEqual(capturedDecision, WKNavigationActionPolicyAllow);
    XCTAssertNil(webVC.capturedLoadRequest);

    XCTestExpectation *flowExpectation = [self expectationWithDescription:@"execution flow should contain the skipped tag"];
    MSIDExecutionFlowRetrieve(context.correlationId, nil, YES, ^(NSString * _Nullable executionFlow) {
        XCTAssertNotNil(executionFlow);
        // Assert presence only: both tags share the placeholder string until unique codes are assigned.
        XCTAssertTrue([executionFlow containsString:MSIDCustomHeaderTagToString(MSIDCustomHeaderSkippedUntrustedHostTag)]);
        [flowExpectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testDecidePolicyForNavigationAction_whenRedirectChangesHostToUntrusted_shouldSkipProviderOnUntrustedHost
{
    MSIDCustomHeaderCapturingWebviewController *webVC = [[MSIDCustomHeaderCapturingWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    MSIDTestCustomHeaderProvider *provider = [MSIDTestCustomHeaderProvider new];
    provider.headersToReturn = @{ MSID_REFRESH_TOKEN_CREDENTIAL : @"FakeHeaderValue" };
    webVC.customHeaderProvider = provider;

    // Initial navigation to a known AAD host: the provider is consulted and headers are injected.
    NSURLRequest *trustedRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/authorize"]];
    MSIDWKNavigationActionMock *trustedAction = [[MSIDWKNavigationActionMock alloc] initWithRequest:trustedRequest];

    XCTestExpectation *trustedExpectation = [self expectationWithDescription:@"trusted decision handler"];
    __block WKNavigationActionPolicy trustedDecision = WKNavigationActionPolicyAllow;
    [webVC decidePolicyForNavigationAction:trustedAction webview:nil decisionHandler:^(WKNavigationActionPolicy decision) {
        trustedDecision = decision;
        [trustedExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertTrue(provider.wasCalled);
    XCTAssertEqual(trustedDecision, WKNavigationActionPolicyCancel);

    // Redirect that changes the host to an untrusted one: the provider must not be consulted.
    provider.wasCalled = NO;
    webVC.capturedLoadRequest = nil;

    NSURLRequest *untrustedRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://contoso.untrusted.com/redirected"]];
    MSIDWKNavigationActionMock *untrustedAction = [[MSIDWKNavigationActionMock alloc] initWithRequest:untrustedRequest];

    XCTestExpectation *untrustedExpectation = [self expectationWithDescription:@"untrusted decision handler"];
    __block WKNavigationActionPolicy untrustedDecision = WKNavigationActionPolicyCancel;
    [webVC decidePolicyForNavigationAction:untrustedAction webview:nil decisionHandler:^(WKNavigationActionPolicy decision) {
        untrustedDecision = decision;
        [untrustedExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertFalse(provider.wasCalled);
    XCTAssertEqual(untrustedDecision, WKNavigationActionPolicyAllow);
    XCTAssertNil(webVC.capturedLoadRequest);
}

@end

#endif
