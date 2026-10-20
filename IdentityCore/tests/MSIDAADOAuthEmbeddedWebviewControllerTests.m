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
#import "MSIDAADOAuthEmbeddedWebviewController.h"
#import "MSIDOpenIdVcHandling.h"
#import "MSIDWKNavigationActionMock.h"
#import "MSIDWebAuthNUtil.h"
#import "MSIDTestBundle.h"
#import "MSIDWebviewConstants.h"
#import "MSIDConstants.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDOnboardingBlobBuilder.h"
#import "MSIDOnboardingBlobBuilder+MSIDTestUtil.h"
#import "MSIDOnboardingBlobFieldKeys.h"
#import "MSIDWebviewNavigationDelegate.h"
#import "MSIDWebviewNavigationDecision.h"
#import "MSIDAppExtensionUtil.h"
#import "MSIDDIContainer.h"
#import "MSIDCustomHeaderProviding.h"

#if !MSID_EXCLUDE_WEBKIT

@interface MSIDOnboardingNavigationDelegateSpy : NSObject <MSIDWebviewNavigationDelegate>
@property (nonatomic) NSUInteger invocationCount;
@property (nonatomic) XCTestExpectation *redirectExpectation;
@end

@implementation MSIDOnboardingNavigationDelegateSpy

- (void)handleSpecialRedirectURL:(__unused NSURL *)URL
       embeddedWebviewController:(__unused MSIDOAuth2EmbeddedWebviewController *)embeddedWebviewController
                      completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable, NSError * _Nullable))completion
{
    self.invocationCount += 1;
    [self.redirectExpectation fulfill];
    completion([MSIDWebviewNavigationDecision continueDefault], nil);
}

@end

#if TARGET_OS_IPHONE
/// Test-only subclass that captures the URL passed to `openOpenIdVcHandoffURL:`
/// instead of invoking UIApplication. Lets logic-test targets exercise the
/// openid-vc decision path without crashing on a nil `[UIApplication sharedApplication]`.
@interface MSIDOpenIdVcWebViewControllerSpy : MSIDAADOAuthEmbeddedWebviewController
@property (nonatomic, copy, readonly) NSURL *capturedHandoffURL;
@property (nonatomic, readonly) BOOL didOpenHandoffURL;
@end

@implementation MSIDOpenIdVcWebViewControllerSpy

- (void)openOpenIdVcHandoffURL:(NSURL *)url
{
    _capturedHandoffURL = [url copy];
    _didOpenHandoffURL = YES;
}

@end

/// Test stub conforming to `MSIDOpenIdVcHandling`. Captures every argument it
/// receives and lets the test choose when (and with what error) to invoke the
/// controller's completion block.
@interface MSIDOpenIdVcHandlerStub : NSObject <MSIDOpenIdVcHandling>
@property (nonatomic, readonly) NSInteger invocationCount;
@property (nonatomic, copy, readonly, nullable) NSURL *receivedURL;
@property (nonatomic, weak, readonly, nullable) MSIDAADOAuthEmbeddedWebviewController *receivedWebviewController;
@property (nonatomic, copy, readonly, nullable) NSString *receivedCallerRedirectUri;
@property (nonatomic, copy, readonly, nullable) NSUUID *receivedCorrelationId;
@property (nonatomic, copy, nullable) NSError *errorToReportInCompletion;
@property (nonatomic, copy, nullable) void (^onHandle)(void);
@end

@implementation MSIDOpenIdVcHandlerStub

- (void)handleOpenIdVcURL:(NSURL *)url
        webviewController:(MSIDAADOAuthEmbeddedWebviewController *)webviewController
        callerRedirectUri:(NSString *)callerRedirectUri
            correlationId:(NSUUID *)correlationId
               completion:(void (^)(NSError * _Nullable))completion
{
    _invocationCount += 1;
    _receivedURL = [url copy];
    _receivedWebviewController = webviewController;
    _receivedCallerRedirectUri = [callerRedirectUri copy];
    _receivedCorrelationId = [correlationId copy];

    if (self.onHandle) self.onHandle();

    completion(self.errorToReportInCompletion);
}

@end
#endif

#if TARGET_OS_IPHONE
@interface MSIDAADOAuthEmbeddedWebviewController (ActivationTesting)
@property (nonatomic, readonly) BOOL activationHandoffInProgress;
@end

@interface MSIDActivationFrameMock : NSObject
@property (nonatomic) BOOL mainFrameValue;
- (WKFrameInfo *)frameInfo;
@end

@implementation MSIDActivationFrameMock
- (BOOL)isMainFrame
{
    return self.mainFrameValue;
}

- (WKFrameInfo *)frameInfo
{
    // WKFrameInfo cannot be constructed independently of WebKit's native frame.
    return (id)self;
}
@end

@interface MSIDActivationNavigationMock : MSIDWKNavigationActionMock
@property (nonatomic) WKFrameInfo *sourceFrameValue;
@end

@implementation MSIDActivationNavigationMock
- (WKFrameInfo *)sourceFrame
{
    return self.sourceFrameValue;
}
@end

@interface MSIDActivationOpenCapture : NSObject
@property (nonatomic) NSURL *URL;
@property (nonatomic) NSDictionary *options;
@property (nonatomic) NSUInteger openCount;
@property (nonatomic, copy) void (^completion)(BOOL);
@property (nonatomic) BOOL applicationUnavailable;
@property (nonatomic) id application;
@end

@implementation MSIDActivationOpenCapture
@end

static MSIDActivationOpenCapture *s_activationOpenCapture;

@interface MSIDActivationAppExtensionUtilMock : MSIDAppExtensionUtil
@end

@implementation MSIDActivationAppExtensionUtilMock
+ (UIApplication *)sharedApplication
{
    return s_activationOpenCapture.applicationUnavailable ? nil : s_activationOpenCapture.application;
}

+ (void)sharedApplicationOpenURL:(NSURL *)url
                         options:(NSDictionary<UIApplicationOpenExternalURLOptionsKey, id> *)options
               completionHandler:(void (^)(BOOL))completionHandler
{
    s_activationOpenCapture.URL = url;
    s_activationOpenCapture.options = options;
    s_activationOpenCapture.openCount += 1;
    s_activationOpenCapture.completion = completionHandler;
}
@end

@interface MSIDActivationControllerSpy : MSIDAADOAuthEmbeddedWebviewController
@property (nonatomic) NSError *receivedError;
@property (nonatomic) NSUInteger completionCount;
@property (nonatomic) NSUInteger loadCount;
@end

@implementation MSIDActivationControllerSpy
- (void)endWebAuthWithURL:(NSURL *)endURL error:(NSError *)error
{
    if (!self.complete)
    {
        self.receivedError = error;
        self.completionCount += 1;
    }
    [super endWebAuthWithURL:endURL error:error];
}

- (void)dismissWebview:(void (^)(void))completion
{
    if (completion)
    {
        completion();
    }
}

- (void)loadRequest:(__unused NSURLRequest *)request
{
    self.loadCount += 1;
}
@end

@interface MSIDActivationHeaderProviderSpy : NSObject <MSIDCustomHeaderProviding>
@property (nonatomic) NSUInteger callCount;
@end

@implementation MSIDActivationHeaderProviderSpy
- (void)getCustomHeaders:(__unused NSURLRequest *)request
                 forHost:(__unused NSString *)host
         completionBlock:(MSIDCustomHeaderBlock)completionBlock
{
    self.callCount += 1;
    completionBlock(@{@"Test-Header": @"test-value"}, nil);
}
@end

@interface MSIDMockAppDelegate : NSObject <UIApplicationDelegate>
@property (nonatomic) NSURL *receivedURL;
@property (nonatomic) BOOL handledResult;
@property (nonatomic) NSUInteger invocationCount;
@end

@implementation MSIDMockAppDelegate
- (BOOL)application:(__unused UIApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:(__unused void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler
{
    self.receivedURL = userActivity.webpageURL;
    self.invocationCount += 1;
    return self.handledResult;
}
@end

@interface MSIDActivationApplicationMock : NSObject
@property (nonatomic) id<UIApplicationDelegate> delegate;
@end

@implementation MSIDActivationApplicationMock
@end
#endif

@interface MSIDAADOAuthEmbeddedWebviewControllerTests : XCTestCase

@property (nonatomic) MSIDFlightManagerMockProvider *flightProvider;
@property (nonatomic) BOOL originalCompliantExtension;
@property (nonatomic) BOOL originalWebAuthExtension;

@end

@implementation MSIDAADOAuthEmbeddedWebviewControllerTests

- (void)setUp
{
    [super setUp];
    self.originalCompliantExtension = MSIDAppExtensionUtil.runningInCompliantExtension;
    self.originalWebAuthExtension = MSIDWebAuthNUtil.amIRunningInExtension;
    self.flightProvider = [MSIDFlightManagerMockProvider new];
    MSIDFlightManager.sharedInstance.flightProvider = self.flightProvider;
}

- (void)tearDown
{
    MSIDFlightManager.sharedInstance.flightProvider = nil;
    self.flightProvider = nil;
    MSIDAppExtensionUtil.runningInCompliantExtension = self.originalCompliantExtension;
    MSIDWebAuthNUtil.amIRunningInExtension = self.originalWebAuthExtension;
    [MSIDTestBundle reset];
    [MSIDDIContainer.sharedInstance reset];
#if TARGET_OS_IPHONE
    s_activationOpenCapture = nil;
#endif
    [super tearDown];
}


- (void)testInitWithStartURL_whenURLisNil_shouldFail
{
    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc] initWithStartURL:nil
                                                                                                            endURL:[NSURL URLWithString:@"endurl://host"]
                                                                                                           webview:nil
                                                                                                     customHeaders:nil
                                                                                                    platfromParams:nil
                                                                                                           context:nil];

    XCTAssertNil(webVC);
}


- (void)testInitWithStartURL_whenEndURLisNil_shouldFail
{
    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc]
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
    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];
    XCTAssertNotNil(webVC);

}

- (void)testDecidePolicyForNavigationAction_whenIsRegularUrl_shouldCancelActionAndReturnNo
{
    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:@"https://login.microsoftonline.com/auth"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    BOOL result = [webVC decidePolicyAADForNavigationAction:action decisionHandler:nil];

    XCTAssertFalse(result);
}

- (void)testDecidePolicyForNavigationAction_whenIsBrokerUrl_shouldCancelActionAndReturnYes
{
    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:@"msauth://com.contoso.app/result"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];

    BOOL result = [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy decision) {

        XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertTrue(result);
}

- (void)testDecidePolicyForNavigationAction_whenIsBrowserUrlAndNoExternalDecidePolicyForBrowserAction_shouldCancelActionAndReturnYes
{
    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:@"browser://www.web-cp.com/check"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];

    BOOL result = [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy decision) {

        XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertTrue(result);
}

#if TARGET_OS_IPHONE
- (void)testDecidePolicyForNavigationAction_whenIsOpenIdVcUrl_shouldCancelActionAndReturnYes
{
    MSIDOpenIdVcWebViewControllerSpy *webVC = [[MSIDOpenIdVcWebViewControllerSpy alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:@"openid-vc://credential-offer?credential_issuer=https%3A%2F%2Fexample.com"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];

    BOOL result = [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy decision) {

        XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertTrue(result);
    XCTAssertTrue(webVC.didOpenHandoffURL);
    XCTAssertEqualObjects(webVC.capturedHandoffURL.scheme, @"openid-vc");
}

- (void)testDecidePolicyForNavigationAction_whenIsOpenIdVcUrlMixedCase_shouldCancelActionAndReturnYes
{
    MSIDOpenIdVcWebViewControllerSpy *webVC = [[MSIDOpenIdVcWebViewControllerSpy alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:@"OPENID-VC://mock.com"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];

    BOOL result = [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy decision) {

        XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertTrue(result);
    XCTAssertTrue(webVC.didOpenHandoffURL);
}
#endif

- (void)testDecidePolicyForNavigationAction_whenExternalDecidePolicyForBrowserAction_shouldCancelActionAndReturnYesAndCallExternalMethod
{
    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:@"browser://www.web-cp.com/check"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectationExternalDecisionHandler = [self expectationWithDescription:@"external decision handler"];
    XCTestExpectation *expectationDecisionHandler = [self expectationWithDescription:@"decision handler"];

    webVC.externalDecidePolicyForBrowserAction = ^NSURLRequest *(MSIDOAuth2EmbeddedWebviewController *webView, NSURL *url) {

        XCTAssertNotNil(webView);
        XCTAssertEqualObjects([url absoluteString], @"browser://www.web-cp.com/check");
        [expectationExternalDecisionHandler fulfill];

        return [[NSURLRequest alloc] initWithURL:url];
    };


    BOOL result = [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy decision) {

        XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
        [expectationDecisionHandler fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertTrue(result);
}

- (void)testDecidePolicyForNavigationAction_whenExternalDecidePolicyForBrowserActionLegacyFlow_shouldCancelActionAndReturnYesAndCallExternalMethod
{
    [MSIDWebAuthNUtil setAmIRunningInExtension:NO];
    
    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:@"https://www.web-cp.com/check"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectationExternalDecisionHandler = [self expectationWithDescription:@"external decision handler"];
    XCTestExpectation *expectationDecisionHandler = [self expectationWithDescription:@"decision handler"];

    webVC.externalDecidePolicyForBrowserAction = ^NSURLRequest *(MSIDOAuth2EmbeddedWebviewController *webView, NSURL *url) {

        XCTAssertNotNil(webView);
        XCTAssertEqualObjects([url absoluteString], @"browser://www.web-cp.com/check");
        [expectationExternalDecisionHandler fulfill];

        return [[NSURLRequest alloc] initWithURL:url];
    };


    BOOL result = [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy decision) {

        XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
        [expectationDecisionHandler fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertTrue(result);
}

- (void)testDecidePolicyForNavigationAction_whenExternalDecidePolicyForBrowserActionLegacyFlowNonHttps_shouldCancelActionAndReturnNoAndCallExternalMethod
{
    [MSIDWebAuthNUtil setAmIRunningInExtension:NO];
    
    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:@"http://www.web-cp.com/check"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    BOOL result = [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy decision) {
        XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
    }];

    XCTAssertFalse(result);
}

#if TARGET_OS_IPHONE
- (void)configureActivationExtension
{
    MSIDAppExtensionUtil.runningInCompliantExtension = YES;
    MSIDWebAuthNUtil.amIRunningInExtension = YES;
    [MSIDTestBundle overrideBundleId:@"com.microsoft.azureauthenticator.ssoextension"];
    s_activationOpenCapture = [MSIDActivationOpenCapture new];
    s_activationOpenCapture.application = [MSIDActivationApplicationMock new];
    [MSIDDIContainer.sharedInstance registerClass:MSIDAppExtensionUtil.class
                                       lifetime:MSIDDIContainerLifetimeSingleton
                                        factory:^id { return MSIDActivationAppExtensionUtilMock.class; }];
}

- (MSIDActivationControllerSpy *)activationController
{
    return [[MSIDActivationControllerSpy alloc]
        initWithStartURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/authorize"]
                  endURL:[NSURL URLWithString:@"endurl://host"]
                 webview:nil customHeaders:nil platfromParams:nil context:nil];
}

- (MSIDActivationNavigationMock *)activationActionWithURL:(NSString *)URLString
                                           navigationType:(WKNavigationType)navigationType
{
    MSIDActivationFrameMock *frame = [MSIDActivationFrameMock new];
    frame.mainFrameValue = YES;
    MSIDActivationNavigationMock *action = [[MSIDActivationNavigationMock alloc]
        initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:URLString]]
         navigationType:navigationType targetFrame:frame.frameInfo];
    action.sourceFrameValue = frame.frameInfo;
    return action;
}

- (void)testActivationInCompliantExtension_whenClickedOrHeaderReloaded_shouldHandoffBeforeLoadingWebsite
{
    [self configureActivationExtension];
    for (NSNumber *navigationType in @[@(WKNavigationTypeLinkActivated), @(WKNavigationTypeOther)])
    {
        MSIDActivationControllerSpy *controller = [self activationController];
        MSIDActivationHeaderProviderSpy *headers = [MSIDActivationHeaderProviderSpy new];
        controller.customHeaderProvider = headers;
        MSIDActivationNavigationMock *action = [self activationActionWithURL:@"https://login.microsoftonline.com/authenticatorApp/activateAccount?test=synthetic"
                                                             navigationType:navigationType.integerValue];
        NSUInteger previousOpenCount = s_activationOpenCapture.openCount;
        __block NSUInteger decisionCount = 0;
        [controller decidePolicyForNavigationAction:action webview:nil decisionHandler:^(WKNavigationActionPolicy decision)
        {
            decisionCount += 1;
            XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
            XCTAssertEqual(s_activationOpenCapture.openCount, previousOpenCount);
        }];
        XCTAssertEqual(decisionCount, 1);
        XCTAssertEqual(headers.callCount, 0);
        XCTAssertEqual(controller.loadCount, 0);
        XCTAssertEqual(controller.completionCount, 0);
        XCTAssertEqual(s_activationOpenCapture.openCount, previousOpenCount + 1);
        XCTAssertEqualObjects(s_activationOpenCapture.URL, action.request.URL);
        XCTAssertEqualObjects(s_activationOpenCapture.options, @{UIApplicationOpenURLOptionUniversalLinksOnly: @YES});
        XCTAssertNotNil(s_activationOpenCapture.completion);
        if (s_activationOpenCapture.completion)
        {
            s_activationOpenCapture.completion(YES);
        }
        XCTAssertFalse(controller.complete);
        XCTAssertEqual(controller.completionCount, 0);
    }
}

- (void)testActivationInCompliantExtension_whenTrustedCloud_shouldPreserveOriginalUniversalLink
{
    [self configureActivationExtension];
    for (NSString *host in @[@"login.microsoftonline.com", @"login.microsoftonline.us", @"login.chinacloudapi.cn",
                            @"LOGIN.microsoftonline.com:443"])
    {
        NSString *URLString = [NSString stringWithFormat:@"https://%@/authenticatorApp/activateAccount?test=Synthetic%%2B%%2F%%3D", host];
        MSIDActivationControllerSpy *controller = [self activationController];
        MSIDActivationNavigationMock *action = [self activationActionWithURL:URLString navigationType:WKNavigationTypeLinkActivated];
        __block NSUInteger decisionCount = 0;
        XCTAssertTrue([controller decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy)
        {
            decisionCount += 1;
            XCTAssertEqual(policy, WKNavigationActionPolicyCancel);
        }]);
        XCTAssertEqual(decisionCount, 1);
        XCTAssertEqualObjects(s_activationOpenCapture.URL.absoluteString, URLString);
        XCTAssertNotNil(s_activationOpenCapture.completion);
        if (s_activationOpenCapture.completion)
        {
            s_activationOpenCapture.completion(YES);
        }
        XCTAssertFalse(controller.complete);
    }
}

- (void)testActivationInCompliantExtension_whenNewWindow_shouldUseUniversalLinkInsteadOfGenericOpen
{
    [self configureActivationExtension];
    MSIDActivationControllerSpy *controller = [self activationController];
    MSIDActivationNavigationMock *action = [[MSIDActivationNavigationMock alloc]
        initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"]]
         navigationType:WKNavigationTypeLinkActivated targetFrame:nil];
    MSIDActivationFrameMock *sourceFrame = [MSIDActivationFrameMock new];
    sourceFrame.mainFrameValue = YES;
    action.sourceFrameValue = sourceFrame.frameInfo;
    __block NSUInteger decisionCount = 0;
    [controller decidePolicyForNavigationAction:action webview:nil decisionHandler:^(WKNavigationActionPolicy policy)
    {
        decisionCount += 1;
        XCTAssertEqual(policy, WKNavigationActionPolicyCancel);
    }];
    XCTAssertEqual(decisionCount, 1);
    XCTAssertEqual(s_activationOpenCapture.openCount, 1);
    XCTAssertEqualObjects(s_activationOpenCapture.options, @{UIApplicationOpenURLOptionUniversalLinksOnly: @YES});
    XCTAssertEqual(controller.loadCount, 0);
    XCTAssertEqual(controller.completionCount, 0);
}

- (void)testActivationHandoff_whenURLIsNotTrustedHttpsActivation_shouldKeepOriginalPolicy
{
    [self configureActivationExtension];
    NSArray<NSString *> *URLs = @[
        @"http://login.microsoftonline.com/authenticatorApp/activateAccount",
        @"https://untrusted.invalid/authenticatorApp/activateAccount",
        @"https://login.microsoftonline.com.untrusted.invalid/authenticatorApp/activateAccount",
        @"https://login.microsoftonline.com/authenticatorApp/activateAccount/extra",
        @"https://login.microsoftonline.com/authenticatorApp/activateAccount/",
        @"https://login.microsoftonline.com/authenticatorApp/%61ctivateAccount",
        @"https://login.microsoftonline.com/other?path=/authenticatorApp/activateAccount",
        @"https://login.microsoftonline.com/other#/authenticatorApp/activateAccount",
        @"https://login.microsoftonline.com:444/authenticatorApp/activateAccount",
        @"https://synthetic@login.microsoftonline.com/authenticatorApp/activateAccount",
        @"https://@login.microsoftonline.com/authenticatorApp/activateAccount",
        @"https://:synthetic@login.microsoftonline.com/authenticatorApp/activateAccount",
        @"https://login.microsoftonline.com@untrusted.invalid/authenticatorApp/activateAccount",
        @"microsoft-authenticator://activate",
        @"itms-apps://itunes.apple.com/app/synthetic"
    ];
    for (NSString *URLString in URLs)
    {
        MSIDActivationControllerSpy *controller = [self activationController];
        MSIDActivationNavigationMock *action = [self activationActionWithURL:URLString navigationType:WKNavigationTypeOther];
        __block NSUInteger decisionCount = 0;
        XCTAssertFalse([controller decidePolicyAADForNavigationAction:action decisionHandler:^(__unused WKNavigationActionPolicy policy)
        {
            decisionCount += 1;
        }], @"URL case %@", URLString);
        XCTAssertEqual(decisionCount, 0);
        XCTAssertEqual(s_activationOpenCapture.openCount, 0);
        XCTAssertEqual(controller.completionCount, 0);
    }
}

- (void)testActivationHandoff_whenEitherExtensionFlagIsFalse_shouldKeepOriginalPolicy
{
    [self configureActivationExtension];
    for (NSArray<NSNumber *> *flags in @[@[@NO, @NO], @[@NO, @YES], @[@YES, @NO]])
    {
        MSIDWebAuthNUtil.amIRunningInExtension = flags[0].boolValue;
        MSIDAppExtensionUtil.runningInCompliantExtension = flags[1].boolValue;
        MSIDActivationControllerSpy *controller = [self activationController];
        MSIDActivationNavigationMock *action = [self activationActionWithURL:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"
                                                             navigationType:WKNavigationTypeLinkActivated];
        XCTAssertFalse([controller decidePolicyAADForNavigationAction:action decisionHandler:nil]);
        XCTAssertEqual(s_activationOpenCapture.openCount, 0);
    }
}

- (void)testActivationHandoff_whenSubframeOrFormSubmission_shouldKeepOriginalPolicy
{
    [self configureActivationExtension];
    for (NSNumber *subframeSource in @[@YES, @NO])
    {
        MSIDActivationNavigationMock *action = [self activationActionWithURL:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"
                                                             navigationType:WKNavigationTypeLinkActivated];
        MSIDActivationFrameMock *subframe = [MSIDActivationFrameMock new];
        if (subframeSource.boolValue)
        {
            action.sourceFrameValue = subframe.frameInfo;
        }
        else
        {
            WKFrameInfo *sourceFrame = action.sourceFrame;
            action = [[MSIDActivationNavigationMock alloc] initWithRequest:action.request
                                                           navigationType:WKNavigationTypeLinkActivated targetFrame:subframe.frameInfo];
            action.sourceFrameValue = sourceFrame;
        }
        XCTAssertFalse([[self activationController] decidePolicyAADForNavigationAction:action decisionHandler:nil]);
    }
    MSIDActivationNavigationMock *formAction = [self activationActionWithURL:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"
                                                             navigationType:WKNavigationTypeFormSubmitted];
    XCTAssertFalse([[self activationController] decidePolicyAADForNavigationAction:formAction decisionHandler:nil]);
    XCTAssertEqual(s_activationOpenCapture.openCount, 0);
}

#if !AD_BROKER
- (void)testActivationHandoff_whenMainAppInNonBrokerBuild_shouldKeepOriginalPolicy
{
    [self configureActivationExtension];
    [MSIDTestBundle overrideBundleId:@"com.microsoft.azureauthenticator"];
    MSIDActivationNavigationMock *action = [self activationActionWithURL:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"
                                                         navigationType:WKNavigationTypeLinkActivated];
    XCTAssertFalse([[self activationController] decidePolicyAADForNavigationAction:action decisionHandler:nil]);
    XCTAssertEqual(s_activationOpenCapture.openCount, 0);
}
#endif

- (void)testActivationHandoff_whenOpenFails_shouldEndOnceWithoutLoadingStoreAndAllowFreshSession
{
    [self configureActivationExtension];
    MSIDActivationControllerSpy *controller = [self activationController];
    MSIDActivationNavigationMock *action = [self activationActionWithURL:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"
                                                         navigationType:WKNavigationTypeLinkActivated];
    __block NSUInteger decisionCount = 0;
    [controller decidePolicyForNavigationAction:action webview:nil decisionHandler:^(WKNavigationActionPolicy policy)
    {
        decisionCount += 1;
        XCTAssertEqual(policy, WKNavigationActionPolicyCancel);
    }];
    XCTAssertNotNil(s_activationOpenCapture.completion);
    if (s_activationOpenCapture.completion)
    {
        s_activationOpenCapture.completion(NO);
        s_activationOpenCapture.completion(NO);
    }
    XCTAssertEqual(decisionCount, 1);
    XCTAssertTrue(controller.complete);
    XCTAssertFalse(controller.activationHandoffInProgress);
    XCTAssertEqual(controller.completionCount, 1);
    XCTAssertEqual(controller.receivedError.code, MSIDErrorInternal);
    XCTAssertEqual(controller.loadCount, 0);
    [[self activationController] decidePolicyAADForNavigationAction:action decisionHandler:nil];
    XCTAssertEqual(s_activationOpenCapture.openCount, 2);
}

- (void)testActivationHandoff_whenAppUnavailable_shouldFailExplicitlyWithoutOpening
{
    [self configureActivationExtension];
    s_activationOpenCapture.applicationUnavailable = YES;
    MSIDActivationControllerSpy *controller = [self activationController];
    MSIDActivationNavigationMock *action = [self activationActionWithURL:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"
                                                         navigationType:WKNavigationTypeLinkActivated];
    XCTAssertTrue([controller decidePolicyAADForNavigationAction:action decisionHandler:nil]);
    XCTAssertTrue(controller.complete);
    XCTAssertEqual(controller.completionCount, 1);
    XCTAssertEqual(controller.receivedError.code, MSIDErrorAttemptToOpenURLFromExtension);
    XCTAssertEqual(s_activationOpenCapture.openCount, 0);
}

- (void)testActivationHandoff_whenPendingDuplicateAndLaterIntentionalRetry_shouldOpenOncePerAttempt
{
    [self configureActivationExtension];
    MSIDActivationControllerSpy *controller = [self activationController];
    MSIDActivationNavigationMock *action = [self activationActionWithURL:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"
                                                         navigationType:WKNavigationTypeLinkActivated];
    __block NSUInteger decisionCount = 0;
    void (^decisionHandler)(WKNavigationActionPolicy) = ^(WKNavigationActionPolicy policy)
    {
        decisionCount += 1;
        XCTAssertEqual(policy, WKNavigationActionPolicyCancel);
    };
    [controller decidePolicyAADForNavigationAction:action decisionHandler:decisionHandler];
    [controller decidePolicyAADForNavigationAction:action decisionHandler:decisionHandler];
    XCTAssertEqual(s_activationOpenCapture.openCount, 1);
    XCTAssertEqual(decisionCount, 2);
    void (^firstResult)(BOOL) = s_activationOpenCapture.completion;
    XCTAssertNotNil(firstResult);
    firstResult(YES);
    XCTAssertFalse(controller.activationHandoffInProgress);
    [controller decidePolicyAADForNavigationAction:action decisionHandler:decisionHandler];
    XCTAssertEqual(s_activationOpenCapture.openCount, 2);
    XCTAssertTrue(controller.activationHandoffInProgress);
    firstResult(NO);
    [controller decidePolicyAADForNavigationAction:action decisionHandler:decisionHandler];
    XCTAssertEqual(s_activationOpenCapture.openCount, 2);
    XCTAssertFalse(controller.complete);
    XCTAssertEqual(controller.completionCount, 0);
}

- (void)testActivationHandoff_whenCancelledBeforeOpenResult_shouldIgnoreLateCallbackAndAllowFreshSession
{
    [self configureActivationExtension];
    MSIDActivationControllerSpy *controller = [self activationController];
    MSIDActivationNavigationMock *action = [self activationActionWithURL:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"
                                                         navigationType:WKNavigationTypeLinkActivated];
    [controller decidePolicyAADForNavigationAction:action decisionHandler:nil];
    void (^result)(BOOL) = s_activationOpenCapture.completion;
    NSError *cancelError = [NSError errorWithDomain:MSIDErrorDomain code:MSIDErrorUserCancel userInfo:nil];
    [controller endWebAuthWithURL:nil error:cancelError];
    XCTAssertFalse(controller.activationHandoffInProgress);
    XCTAssertNotNil(result);
    result(NO);
    result(YES);
    XCTAssertEqual(controller.completionCount, 1);
    XCTAssertEqualObjects(controller.receivedError, cancelError);
    XCTAssertTrue(controller.complete);
    [controller decidePolicyAADForNavigationAction:action decisionHandler:nil];
    XCTAssertEqual(s_activationOpenCapture.openCount, 1);
    [[self activationController] decidePolicyAADForNavigationAction:action decisionHandler:nil];
    XCTAssertEqual(s_activationOpenCapture.openCount, 2);
}

- (void)testActivationHandoff_whenAsyncResultArrivesAfterCompletion_shouldNotCompleteAgain
{
    [self configureActivationExtension];
    MSIDActivationControllerSpy *controller = [self activationController];
    MSIDActivationNavigationMock *action = [self activationActionWithURL:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"
                                                         navigationType:WKNavigationTypeLinkActivated];
    [controller decidePolicyAADForNavigationAction:action decisionHandler:nil];
    void (^result)(BOOL) = s_activationOpenCapture.completion;
    XCTAssertNotNil(result);
    [controller endWebAuthWithURL:nil error:nil];
    XCTestExpectation *expectation = [self expectationWithDescription:@"late open result drained"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        result(NO);
        dispatch_async(dispatch_get_main_queue(), ^{
            XCTAssertTrue(NSThread.isMainThread);
            XCTAssertTrue(controller.complete);
            XCTAssertFalse(controller.activationHandoffInProgress);
            XCTAssertEqual(controller.completionCount, 1);
            XCTAssertNil(controller.receivedError);
            [expectation fulfill];
        });
    });
    [self waitForExpectations:@[expectation] timeout:2.0];
}

- (void)testActivationHandoff_whenControllerReleasedBeforeResult_shouldNotKeepItAlive
{
    [self configureActivationExtension];
    __weak MSIDActivationControllerSpy *weakController;
    @autoreleasepool
    {
        MSIDActivationControllerSpy *controller = [self activationController];
        weakController = controller;
        MSIDActivationNavigationMock *action = [self activationActionWithURL:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"
                                                             navigationType:WKNavigationTypeLinkActivated];
        [controller decidePolicyAADForNavigationAction:action decisionHandler:nil];
    }
    XCTAssertNil(weakController);
    XCTAssertNotNil(s_activationOpenCapture.completion);
    s_activationOpenCapture.completion(NO);
}

- (void)testActivationHandoff_shouldStillRejectItmsAppsOtherNavigation
{
    [self configureActivationExtension];
    MSIDActivationControllerSpy *controller = [self activationController];
    MSIDActivationNavigationMock *action = [self activationActionWithURL:@"itms-apps://itunes.apple.com/app/synthetic"
                                                         navigationType:WKNavigationTypeOther];
    __block NSUInteger decisionCount = 0;
    [controller decidePolicyForNavigationAction:action webview:nil decisionHandler:^(WKNavigationActionPolicy policy)
    {
        decisionCount += 1;
        XCTAssertEqual(policy, WKNavigationActionPolicyCancel);
    }];
    XCTAssertEqual(decisionCount, 1);
    XCTAssertEqual(controller.receivedError.code, MSIDErrorServerNonHttpsRedirect);
    XCTAssertEqual(s_activationOpenCapture.openCount, 0);
}

#if AD_BROKER
- (void)testActivationInMainApp_whenDelegateDeclinesOrMissing_shouldPreserveExistingHandledPolicy
{
    [self configureActivationExtension];
    [MSIDTestBundle overrideBundleId:@"com.microsoft.azureauthenticator"];
    MSIDActivationApplicationMock *application = [MSIDActivationApplicationMock new];
    s_activationOpenCapture.application = application;
    for (NSNumber *delegatePresent in @[@YES, @NO])
    {
        MSIDMockAppDelegate *delegate = delegatePresent.boolValue ? [MSIDMockAppDelegate new] : nil;
        delegate.handledResult = NO;
        application.delegate = delegate;
        MSIDActivationControllerSpy *controller = [self activationController];
        MSIDActivationNavigationMock *action = [self activationActionWithURL:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"
                                                             navigationType:WKNavigationTypeLinkActivated];
        __block NSUInteger decisionCount = 0;
        XCTAssertTrue([controller decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy)
        {
            decisionCount += 1;
            XCTAssertEqual(policy, WKNavigationActionPolicyCancel);
        }]);
        XCTAssertEqual(decisionCount, 1);
        XCTAssertEqual(controller.completionCount, 0);
        XCTAssertEqual(s_activationOpenCapture.openCount, 0);
        if (delegatePresent.boolValue)
        {
            XCTAssertEqualObjects(delegate.receivedURL, action.request.URL);
            XCTAssertEqual(delegate.invocationCount, 1);
        }
    }
}

- (void)testDecidePolicyForNavigationAction_whenActivationURL_shouldCancelActionAndInvokeContinueUserActivity
{
    [self configureActivationExtension];
    [MSIDTestBundle overrideBundleId:@"com.microsoft.azureauthenticator"];

    MSIDMockAppDelegate *mockDelegate = [MSIDMockAppDelegate new];
    mockDelegate.handledResult = YES;
    MSIDActivationApplicationMock *application = [MSIDActivationApplicationMock new];
    application.delegate = mockDelegate;
    s_activationOpenCapture.application = application;

    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    NSURL *activationURL = [NSURL URLWithString:@"https://login.microsoftonline.com/authenticatorApp/activateAccount"];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:activationURL];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    __block NSUInteger decisionCount = 0;
    BOOL result = [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy decision) {
        XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
        decisionCount += 1;
    }];

    XCTAssertTrue(result);
    XCTAssertEqual(decisionCount, 1);
    XCTAssertEqual(mockDelegate.invocationCount, 1);
    XCTAssertEqualObjects(mockDelegate.receivedURL, activationURL);
    XCTAssertEqual(s_activationOpenCapture.openCount, 0);
}
#endif
#endif

#pragma mark - openid-vc handoff URL mutation

- (NSURL *)mutatedOpenIdVcURLForRequestURL:(NSString *)requestURLString
                                   endURL:(NSString *)endURLString
{
    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:endURLString]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    SEL selector = NSSelectorFromString(@"openIdVcURLWithCallerContext:");
    NSURL * (*impl)(id, SEL, NSURL *) = (NSURL * (*)(id, SEL, NSURL *))[webVC methodForSelector:selector];
    return impl(webVC, selector, [NSURL URLWithString:requestURLString]);
}

- (void)testOpenIdVcURLMutation_whenCallerRedirectUriPresent_shouldAppendXMsParams
{
    NSURL *mutated = [self mutatedOpenIdVcURLForRequestURL:@"openid-vc://?request_uri=https%3A%2F%2Fverifier%2Fvp%2Fabc&client_id=verifier-id"
                                                   endURL:@"msauth.com.microsoft.outlook://auth"];

    NSURLComponents *components = [NSURLComponents componentsWithURL:mutated resolvingAgainstBaseURL:NO];
    NSMutableDictionary<NSString *, NSString *> *queryMap = [NSMutableDictionary new];
    for (NSURLQueryItem *item in components.queryItems)
    {
        queryMap[item.name] = item.value;
    }

    XCTAssertEqualObjects(queryMap[@"request_uri"], @"https://verifier/vp/abc");
    XCTAssertEqualObjects(queryMap[@"client_id"], @"verifier-id");
    XCTAssertEqualObjects(queryMap[@"x_ms_caller_redirect_uri"], @"msauth.com.microsoft.outlook://auth");
    XCTAssertNotNil(queryMap[@"x_ms_caller_bundle_id"]);
}

- (void)testOpenIdVcURLMutation_whenCallerRedirectUriBlank_shouldReturnOriginalURL
{
    // `[NSURL URLWithString:@""]` returns a URL whose `absoluteString` is the empty
    // string; the controller accepts it (`if (!endURL)` is false), and the helper
    // then takes the blank-string fallback path.
    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@""]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];
    XCTAssertNotNil(webVC);

    SEL selector = NSSelectorFromString(@"openIdVcURLWithCallerContext:");
    NSURL * (*impl)(id, SEL, NSURL *) = (NSURL * (*)(id, SEL, NSURL *))[webVC methodForSelector:selector];
    NSURL *originalURL = [NSURL URLWithString:@"openid-vc://?request_uri=https%3A%2F%2Fverifier%2Fvp%2Fabc"];
    NSURL *mutated = impl(webVC, selector, originalURL);

    XCTAssertEqualObjects(mutated, originalURL);
}

- (void)testOpenIdVcURLMutation_whenXMsParamAlreadyPresent_shouldBeIdempotent
{
    NSURL *mutated = [self mutatedOpenIdVcURLForRequestURL:@"openid-vc://?request_uri=https%3A%2F%2Fverifier&x_ms_caller_redirect_uri=other%3A%2F%2Fpreexisting"
                                                   endURL:@"msauth.com.microsoft.outlook://auth"];

    NSURLComponents *components = [NSURLComponents componentsWithURL:mutated resolvingAgainstBaseURL:NO];
    NSInteger callerRedirectUriCount = 0;
    NSString *callerRedirectUriValue = nil;
    for (NSURLQueryItem *item in components.queryItems)
    {
        if ([item.name isEqualToString:@"x_ms_caller_redirect_uri"])
        {
            callerRedirectUriCount++;
            callerRedirectUriValue = item.value;
        }
    }

    XCTAssertEqual(callerRedirectUriCount, 1);
    XCTAssertEqualObjects(callerRedirectUriValue, @"other://preexisting");
}

- (void)testOpenIdVcURLMutation_whenOriginalURLHasNoQueryString_shouldStillAppendXMsParams
{
    NSURL *mutated = [self mutatedOpenIdVcURLForRequestURL:@"openid-vc://credential-offer"
                                                   endURL:@"msauth.com.microsoft.outlook://auth"];

    NSURLComponents *components = [NSURLComponents componentsWithURL:mutated resolvingAgainstBaseURL:NO];
    NSMutableDictionary<NSString *, NSString *> *queryMap = [NSMutableDictionary new];
    for (NSURLQueryItem *item in components.queryItems)
    {
        queryMap[item.name] = item.value;
    }

    XCTAssertEqualObjects(queryMap[@"x_ms_caller_redirect_uri"], @"msauth.com.microsoft.outlook://auth");
    XCTAssertNotNil(queryMap[@"x_ms_caller_bundle_id"]);
}

#pragma mark - Mobile onboarding stamping (msauth://enroll)

- (MSIDAADOAuthEmbeddedWebviewController *)onboardingControllerWithBuilder:(MSIDOnboardingBlobBuilder *)builder
                                                                  context:(MSIDInteractiveTokenRequestParameters *)parameters
{
    MSIDAADOAuthEmbeddedWebviewController *webVC = [[MSIDAADOAuthEmbeddedWebviewController alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"endurl://host"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:parameters];
    webVC.onboardingBlobBuilder = builder;
    return webVC;
}

- (void)testDecidePolicyForNavigationAction_whenOnboardingRedirectEnabled_shouldStampCARedirectWithoutPhase1AndEnableFlow
{
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_DISABLE_MOBILE_ONBOARDING: @NO };

    for (NSString *host in @[MSID_MDM_ENROLL_HOST, MSID_COMPLIANCE_HOST])
    {
        MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
        [builder addUxFlowUsed:@"PriorUxFlow"];
        MSIDInteractiveTokenRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
        MSIDAADOAuthEmbeddedWebviewController *webVC = [self onboardingControllerWithBuilder:builder context:params];

        NSString *encoded = [@"https://manage.microsoft.com/enroll" stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@", host, MSID_INTUNE_URL_KEY, encoded];
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
        MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

        XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];
        [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy __unused decision) {
            [expectation fulfill];
        }];
        [self waitForExpectationsWithTimeout:1.0 handler:nil];

        XCTAssertEqualObjects([builder msidUxFlowsUsed], (@[@"PriorUxFlow", @"NewCAMdmRedirect"]));
        XCTAssertTrue(params.isNewMobileOnboardingFlow);
    }
}

- (void)testOnboardingRedirects_whenClientEnabled_delegateExactlyOnce
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_MOBILE_ONBOARDING: @NO};
    for (NSString *host in @[MSID_MDM_ENROLL_HOST, MSID_COMPLIANCE_HOST])
    {
        MSIDInteractiveTokenRequestParameters *context = [MSIDTestParametersProvider testInteractiveParameters];
        context.isNewMobileOnboardingFlow = NO;
        MSIDAADOAuthEmbeddedWebviewController *controller = [self onboardingControllerWithBuilder:nil context:context];
        MSIDOnboardingNavigationDelegateSpy *delegate = [MSIDOnboardingNavigationDelegateSpy new];
        delegate.redirectExpectation = [self expectationWithDescription:host];
        controller.navigationDelegate = delegate;
        NSURL *redirectURL = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@?intuneRedirectUrl=https%%3A%%2F%%2Fportal.manage.microsoft.com%%2Fenroll", host]];
        MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc]
            initWithRequest:[NSURLRequest requestWithURL:redirectURL]];
        __block NSUInteger decisionCount = 0;

        XCTAssertTrue([controller decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy)
        {
            decisionCount += 1;
            XCTAssertEqual(policy, WKNavigationActionPolicyCancel);
        }]);
        [self waitForExpectations:@[delegate.redirectExpectation] timeout:1];
        XCTAssertTrue(context.isNewMobileOnboardingFlow);
        XCTAssertEqual(delegate.invocationCount, 1);
        XCTAssertEqual(decisionCount, 1);
    }
}

- (void)testOnboardingRedirects_whenClientDisabled_bypassDelegateAndPreserveLegacyQuery
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_MOBILE_ONBOARDING: @YES};
    NSString *targetURL = @"https://portal.manage.microsoft.com/enroll?in-app=false&In-App=legacy";
    for (NSString *host in @[MSID_MDM_ENROLL_HOST, MSID_COMPLIANCE_HOST])
    {
        MSIDInteractiveTokenRequestParameters *context = [MSIDTestParametersProvider testInteractiveParameters];
        context.isNewMobileOnboardingFlow = NO;
        MSIDAADOAuthEmbeddedWebviewController *controller = [self onboardingControllerWithBuilder:nil context:context];
        MSIDOnboardingNavigationDelegateSpy *delegate = [MSIDOnboardingNavigationDelegateSpy new];
        controller.navigationDelegate = delegate;
        __block NSURL *legacyURL = nil;
        controller.externalDecidePolicyForBrowserAction = ^NSURLRequest *(__unused MSIDOAuth2EmbeddedWebviewController *webview, NSURL *URL)
        {
            legacyURL = URL;
            return nil;
        };
        NSURLComponents *outer = [NSURLComponents new];
        outer.scheme = @"msauth";
        outer.host = host;
        outer.queryItems = @[[NSURLQueryItem queryItemWithName:MSID_INTUNE_URL_KEY value:targetURL]];
        MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc]
            initWithRequest:[NSURLRequest requestWithURL:outer.URL]];
        __block NSUInteger decisionCount = 0;

        XCTAssertTrue([controller decidePolicyAADForNavigationAction:action decisionHandler:^(__unused WKNavigationActionPolicy policy)
        {
            decisionCount += 1;
        }]);
        XCTAssertFalse(context.isNewMobileOnboardingFlow);
        XCTAssertEqual(delegate.invocationCount, 0);
        XCTAssertEqual(decisionCount, 1);
        XCTAssertEqualObjects(legacyURL.scheme, MSID_SCHEME_BROWSER);
        XCTAssertEqualObjects(legacyURL.query, [NSURL URLWithString:targetURL].query);
    }
}

- (void)testOnboardingRedirects_whenContextIsNil_bypassDelegate
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_MOBILE_ONBOARDING: @NO};
    for (NSString *host in @[MSID_MDM_ENROLL_HOST, MSID_COMPLIANCE_HOST])
    {
        MSIDAADOAuthEmbeddedWebviewController *controller = [self onboardingControllerWithBuilder:nil context:nil];
        MSIDOnboardingNavigationDelegateSpy *delegate = [MSIDOnboardingNavigationDelegateSpy new];
        controller.navigationDelegate = delegate;
        MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc]
            initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@", host]]]];
        __block NSUInteger decisionCount = 0;

        XCTAssertTrue([controller decidePolicyAADForNavigationAction:action decisionHandler:^(__unused WKNavigationActionPolicy policy)
        {
            decisionCount += 1;
        }]);
        XCTAssertEqual(delegate.invocationCount, 0);
        XCTAssertEqual(decisionCount, 1);
    }
}

- (void)testDecidePolicyForNavigationAction_whenOnboardingAlreadyEnabled_shouldPreserveExistingUxFlows
{
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_DISABLE_MOBILE_ONBOARDING: @NO };

    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    [builder addUxFlowUsed:MSIDOnboardingUxFlowNewCAMdmRedirect];
    [builder addUxFlowUsed:MSIDOnboardingUxFlowMobileOnboardingPhase1];
    MSIDInteractiveTokenRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    params.isNewMobileOnboardingFlow = YES;
    MSIDAADOAuthEmbeddedWebviewController *webVC = [self onboardingControllerWithBuilder:builder context:params];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc]
        initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"msauth://compliance"]]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];
    [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy __unused decision) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertEqualObjects([builder msidUxFlowsUsed], (@[@"NewCAMdmRedirect", @"MobileOnboardingPhase1"]));
    XCTAssertTrue(params.isNewMobileOnboardingFlow);
}

- (void)testDecidePolicyForNavigationAction_whenMsauthEnrollAndOnboardingDisabledWithValidIntuneUrl_shouldStampClientFlightDisabledLegacyFallback
{
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_DISABLE_MOBILE_ONBOARDING: @YES };

    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    MSIDInteractiveTokenRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    MSIDAADOAuthEmbeddedWebviewController *webVC = [self onboardingControllerWithBuilder:builder context:params];

    NSString *encoded = [@"https://manage.microsoft.com/enroll" stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@", MSID_MDM_ENROLL_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];
    [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy __unused decision) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertTrue([[builder msidStampedStepIds] containsObject:MSIDOnboardingBlobStepMobileOnboardingClientFlightDisabledLegacyFallback]);
    XCTAssertFalse(params.isNewMobileOnboardingFlow);
    XCTAssertEqual([builder msidUxFlowsUsed].count, 0U);
}

- (void)testDecidePolicyForNavigationAction_whenMsauthEnrollAndOnboardingDisabledWithMissingIntuneUrl_shouldNotStampFallback
{
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_DISABLE_MOBILE_ONBOARDING: @YES };

    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    MSIDInteractiveTokenRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    MSIDAADOAuthEmbeddedWebviewController *webVC = [self onboardingControllerWithBuilder:builder context:params];

    NSString *urlString = [NSString stringWithFormat:@"msauth://%@", MSID_MDM_ENROLL_HOST];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];
    [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy __unused decision) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertFalse([[builder msidStampedStepIds] containsObject:MSIDOnboardingBlobStepMobileOnboardingClientFlightDisabledLegacyFallback]);
    XCTAssertFalse([[builder msidUxFlowsUsed] containsObject:MSIDOnboardingUxFlowMobileOnboardingPhase1]);
    XCTAssertFalse([[builder msidUxFlowsUsed] containsObject:MSIDOnboardingUxFlowNewCAMdmRedirect]);
}

#pragma mark - openid-vc handler delegation

#if TARGET_OS_IPHONE
- (void)testDecidePolicy_whenOpenIdVcHandlerIsSet_shouldForwardToHandlerAndSkipOpenURLFallback
{
    MSIDOpenIdVcWebViewControllerSpy *webVC = [[MSIDOpenIdVcWebViewControllerSpy alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"msauth.com.microsoft.outlook://auth"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    MSIDOpenIdVcHandlerStub *handler = [MSIDOpenIdVcHandlerStub new];
    webVC.openIdVcHandler = handler;

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:
        [NSURL URLWithString:@"openid-vc://?request_uri=https%3A%2F%2Fverifier%2Fvp%2Fabc"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];

    BOOL result = [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy decision) {
        XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertTrue(result);
    XCTAssertEqual(handler.invocationCount, 1);
    // Handler receives the original URL (no x_ms_* mutation — that's only for the openURL fallback).
    XCTAssertEqualObjects(handler.receivedURL.absoluteString,
                          @"openid-vc://?request_uri=https%3A%2F%2Fverifier%2Fvp%2Fabc");
    XCTAssertEqualObjects(handler.receivedCallerRedirectUri, @"msauth.com.microsoft.outlook://auth");
    XCTAssertEqual(handler.receivedWebviewController, webVC);
    // Critically: the URL must NOT be opened via UIApplication when a handler is attached.
    XCTAssertFalse(webVC.didOpenHandoffURL);
}

- (void)testDecidePolicy_whenHandlerReportsError_shouldEndAuthSession
{
    MSIDOpenIdVcWebViewControllerSpy *webVC = [[MSIDOpenIdVcWebViewControllerSpy alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"msauth.com.microsoft.outlook://auth"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    MSIDOpenIdVcHandlerStub *handler = [MSIDOpenIdVcHandlerStub new];
    handler.errorToReportInCompletion = [NSError errorWithDomain:@"TestDomain" code:42 userInfo:nil];
    webVC.openIdVcHandler = handler;

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:
        [NSURL URLWithString:@"openid-vc://?request_uri=https%3A%2F%2Fverifier%2Fvp%2Fabc"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];

    [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy decision) {
        XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertEqual(handler.invocationCount, 1);
    XCTAssertFalse(webVC.didOpenHandoffURL);
    // Error path terminates the auth session via -endWebAuthWithURL:error:, which sets `complete`.
    XCTAssertTrue(webVC.complete);
}

- (void)testDecidePolicy_whenHandlerIsNil_shouldFallBackToOpenURL
{
    MSIDOpenIdVcWebViewControllerSpy *webVC = [[MSIDOpenIdVcWebViewControllerSpy alloc]
            initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                      endURL:[NSURL URLWithString:@"msauth.com.microsoft.outlook://auth"]
                     webview:nil
               customHeaders:nil
              platfromParams:nil
                     context:nil];

    XCTAssertNil(webVC.openIdVcHandler);

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:
        [NSURL URLWithString:@"openid-vc://?request_uri=https%3A%2F%2Fverifier%2Fvp%2Fabc"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"decision handler"];

    [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy decision) {
        XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    // Existing Phase 1 fallback path is exercised — openURL is invoked, mutated.
    XCTAssertTrue(webVC.didOpenHandoffURL);
    XCTAssertEqualObjects(webVC.capturedHandoffURL.scheme, @"openid-vc");
    XCTAssertFalse(webVC.complete);
}
#endif

@end

#endif
