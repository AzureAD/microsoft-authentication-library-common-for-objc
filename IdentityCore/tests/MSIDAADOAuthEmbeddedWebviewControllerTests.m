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

#if !MSID_EXCLUDE_WEBKIT

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

#if AD_BROKER && TARGET_OS_IPHONE
@interface MSIDMockAppDelegate : NSObject <UIApplicationDelegate>
@property (nonatomic) XCTestExpectation *continueUserActivityExpectation;
@property (nonatomic) NSURL *receivedURL;
@end

@implementation MSIDMockAppDelegate
- (BOOL)application:(__unused UIApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:(__unused void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler
{
    self.receivedURL = userActivity.webpageURL;
    [self.continueUserActivityExpectation fulfill];
    return YES;
}
@end
#endif

@interface MSIDAADOAuthEmbeddedWebviewControllerTests : XCTestCase

@end

@implementation MSIDAADOAuthEmbeddedWebviewControllerTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
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

#if AD_BROKER && TARGET_OS_IPHONE
- (void)testDecidePolicyForNavigationAction_whenActivationURL_shouldCancelActionAndInvokeContinueUserActivity
{
    [MSIDTestBundle overrideBundleId:@"com.microsoft.azureauthenticator"];

    MSIDMockAppDelegate *mockDelegate = [MSIDMockAppDelegate new];
    mockDelegate.continueUserActivityExpectation = [self expectationWithDescription:@"continueUserActivity invoked"];

    id<UIApplicationDelegate> originalDelegate = [UIApplication sharedApplication].delegate;
    [UIApplication sharedApplication].delegate = mockDelegate;

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

    XCTestExpectation *decisionExpectation = [self expectationWithDescription:@"decision handler"];

    BOOL result = [webVC decidePolicyAADForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy decision) {
        XCTAssertEqual(decision, WKNavigationActionPolicyCancel);
        [decisionExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertTrue(result);
    XCTAssertEqualObjects(mockDelegate.receivedURL, activationURL);

    [UIApplication sharedApplication].delegate = originalDelegate;
    [MSIDTestBundle reset];
}
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
