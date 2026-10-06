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
#import "MSIDWebCPScriptMessageHandler.h"
#import "MSIDAuthenticationAvailabilityStatus.h"
#import "MSIDAuthenticationAvailabilityProvider.h"
#import "MSIDWebCPOnboardingReadinessContract.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDConstants.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"

@interface MSIDWebCPScriptMessageHandler (Testing)
- (void)handleBody:(id)body
         sourceURL:(NSURL *)sourceURL
     fromMainFrame:(BOOL)fromMainFrame
          webView:(WKWebView *)webView
contentController:(WKUserContentController *)contentController
      messageName:(NSString *)messageName
     replyHandler:(void (^)(id _Nullable, NSString * _Nullable))replyHandler;
@end

@interface MSIDOAuth2EmbeddedWebviewController (ReadinessTesting)
@property (nonatomic, readonly) MSIDWebCPScriptMessageHandler *webCPScriptMessageHandler;
@end

@interface MSIDReadinessTestProvider : MSIDAuthenticationAvailabilityProvider
@property (nonatomic) MSIDAuthenticationAvailabilityStatus *availabilityResult;
@property (nonatomic) NSUInteger invocationCount;
@end

@implementation MSIDReadinessTestProvider
- (MSIDAuthenticationAvailabilityStatus *)availabilityStatus
{
    self.invocationCount++;
    return self.availabilityResult;
}
@end

@interface MSIDTrackingReadinessContract : MSIDWebCPOnboardingReadinessContract
@property (nonatomic) NSUInteger validationCount;
@end

@implementation MSIDTrackingReadinessContract
- (MSIDWebCPOnboardingReadinessRequestValidation)validateRequest:(id)request
{
    self.validationCount++;
    return [super validateRequest:request];
}
@end

@interface MSIDWebCPScriptMessageHandlerTests : XCTestCase
@property (nonatomic) WKWebView *webView;
@property (nonatomic) MSIDReadinessTestProvider *provider;
@property (nonatomic) MSIDTrackingReadinessContract *contract;
@property (nonatomic) MSIDWebCPScriptMessageHandler *handler;
@property (nonatomic) MSIDFlightManagerMockProvider *flightProvider;
@end

@implementation MSIDWebCPScriptMessageHandlerTests

- (void)setUp
{
    [super setUp];
    self.flightProvider = [MSIDFlightManagerMockProvider new];
    MSIDFlightManager.sharedInstance.flightProvider = self.flightProvider;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:[WKWebViewConfiguration new]];
    self.provider = [MSIDReadinessTestProvider new];
    self.contract = [MSIDTrackingReadinessContract new];
    self.provider.availabilityResult = [[MSIDAuthenticationAvailabilityStatus alloc] initWithBrokerAppAvailable:NO
                                                                                    ssoExtensionAvailable:YES];
    self.handler = [MSIDWebCPScriptMessageHandler attachToWebView:self.webView
                                                 readinessProvider:self.provider
                                                 readinessContract:self.contract];
    XCTAssertNotNil(self.handler);
}

- (void)tearDown
{
    [self.handler detachFromWebView:self.webView];
    MSIDFlightManager.sharedInstance.flightProvider = nil;
    [super tearDown];
}

- (NSDictionary *)request
{
    return @{@"correlationID": @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb",
             @"action_name": @"get_onboarding_readiness",
             @"action_component": @"native",
             @"params": @{}};
}

- (void)sendBody:(id)body
             url:(NSURL *)url
       mainFrame:(BOOL)mainFrame
         webView:(WKWebView *)webView
      completion:(void (^)(id _Nullable, NSString * _Nullable))completion
{
    [self.handler handleBody:body
                  sourceURL:url
              fromMainFrame:mainFrame
                   webView:webView
          contentController:self.webView.configuration.userContentController
                messageName:MSIDWebCPScriptMessageHandlerName
               replyHandler:completion];
}

- (void)testHandleBody_whenRequestIsValid_shouldReturnIndependentBooleans
{
    __block NSUInteger replies = 0;
    [self sendBody:[self request]
               url:[NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"]
         mainFrame:YES webView:self.webView completion:^(NSDictionary *response, NSString *error) {
        replies++;
        XCTAssertNil(error);
        XCTAssertEqualObjects(response[@"correlationID"], @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb");
        XCTAssertEqualObjects(response[@"status"], @"Success");
        XCTAssertEqualObjects(response[@"result"][@"brokerAppAvailable"], @NO);
        XCTAssertEqualObjects(response[@"result"][@"ssoExtensionAvailable"], @YES);
        XCTAssertEqualObjects(response[@"result"],
                              (@{@"brokerAppAvailable": @NO, @"ssoExtensionAvailable": @YES}));
    }];
    XCTAssertEqual(replies, 1u);
    XCTAssertEqual(self.provider.invocationCount, 1u);
    XCTAssertEqual(self.contract.validationCount, 1u);
}

- (void)testHandleBody_whenAdditionalVersionFieldIsPresent_shouldIgnoreIt
{
    NSMutableDictionary *body = [[self request] mutableCopy];
    body[@"params"] = @{@"contractVersion": @2};
    [self sendBody:body
               url:[NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"]
         mainFrame:YES webView:self.webView completion:^(NSDictionary *response, NSString *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(response[@"status"], @"Success");
        XCTAssertEqualObjects(response[@"result"][@"brokerAppAvailable"], @NO);
    }];
    XCTAssertEqual(self.provider.invocationCount, 1u);
}

- (void)testHandleBody_whenAnotherActionIsRequested_shouldNotProbe
{
    NSMutableDictionary *body = [[self request] mutableCopy];
    body[@"action_name"] = @"fooBarCheck";
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_WEBCP_ONBOARDING_READINESS: @YES};
    [self sendBody:body
               url:[NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"]
         mainFrame:YES webView:self.webView completion:^(NSDictionary *response, NSString *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(response[@"status"], @"NotSupported");
    }];
    XCTAssertEqual(self.provider.invocationCount, 0u);
}

- (void)testHandleBody_whenRequestHasAdditionalFields_shouldOnlyProbeReadiness
{
    NSMutableDictionary *body = [[self request] mutableCopy];
    body[@"before_action"] = @{};
    body[@"params"] = @{@"contractVersion": @1, @"operation": @"open"};
    [self sendBody:body
               url:[NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"]
         mainFrame:YES webView:self.webView completion:^(NSDictionary *response, NSString *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(response[@"status"], @"Success");
        XCTAssertEqualObjects(response[@"result"][@"brokerAppAvailable"], @NO);
        XCTAssertEqualObjects(response[@"result"][@"ssoExtensionAvailable"], @YES);
    }];
    XCTAssertEqual(self.provider.invocationCount, 1u);
}

- (void)testHandleBody_whenProviderFails_shouldReturnFailedInsteadOfFalseBooleans
{
    self.provider.availabilityResult = nil;
    [self sendBody:[self request]
               url:[NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"]
         mainFrame:YES webView:self.webView completion:^(NSDictionary *response, NSString *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(response[@"status"], @"Failed");
        XCTAssertEqualObjects(response[@"result"], @{});
    }];
    XCTAssertEqual(self.provider.invocationCount, 1u);
}

- (void)testHandleBody_whenDisabledByFlight_shouldNotProbe
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_WEBCP_ONBOARDING_READINESS: @YES};
    [self sendBody:[self request]
               url:[NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"]
         mainFrame:YES webView:self.webView completion:^(NSDictionary *response, NSString *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(response[@"status"], @"NotSupported");
    }];
    XCTAssertEqual(self.provider.invocationCount, 0u);
}

- (void)testHandleBody_whenSourceIsNotAuthorized_shouldRejectWithoutProbing
{
    NSArray<NSURL *> *urls = @[
        [NSURL URLWithString:@"http://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"],
        [NSURL URLWithString:@"https://portal.manage.microsoft.com.evil.example/enrollment/webenrollment/waitForDeviceCheckin"],
        [NSURL URLWithString:@"https://portal.manage.microsoft.com:444/enrollment/webenrollment/waitForDeviceCheckin"],
        [NSURL URLWithString:@"https://portal.manage.microsoft.com/unrelated"]
    ];
    for (NSURL *url in urls)
    {
        [self sendBody:[self request] url:url mainFrame:YES webView:self.webView
            completion:^(id response, NSString *error) {
            XCTAssertNil(response);
            XCTAssertNotNil(error);
        }];
    }
    [self sendBody:[self request]
               url:[NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"]
         mainFrame:NO webView:self.webView completion:^(id response, NSString *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
    }];
    XCTAssertEqual(self.provider.invocationCount, 0u);
}

- (void)testHandleBody_whenRepeated_shouldProbeAndReplyEachTime
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"];
    __block NSUInteger replies = 0;
    for (NSUInteger index = 0; index < 2; index++)
    {
        [self sendBody:[self request] url:url mainFrame:YES webView:self.webView
            completion:^(NSDictionary *response, NSString *error) {
            XCTAssertNil(error);
            XCTAssertEqualObjects(response[@"status"], @"Success");
            replies++;
        }];
    }
    XCTAssertEqual(replies, 2u);
    XCTAssertEqual(self.provider.invocationCount, 2u);
}

- (void)testRegistration_whenViewsShareContentController_shouldPreserveRemainingView
{
    WKUserContentController *contentController = self.webView.configuration.userContentController;
    XCTAssertEqual(contentController.userScripts.count, 1u);
    WKUserScript *script = contentController.userScripts.firstObject;
    XCTAssertTrue([script.source containsString:@"window.msidWebCP ="]);
    XCTAssertTrue([script.source containsString:@"messageHandlers.msidWebCP.postMessage(message)"]);
    XCTAssertEqual(script.injectionTime, WKUserScriptInjectionTimeAtDocumentStart);
    XCTAssertTrue(script.forMainFrameOnly);

    WKWebView *otherWebView = [[WKWebView alloc] initWithFrame:CGRectZero
                                                 configuration:self.webView.configuration];
    XCTAssertEqual([MSIDWebCPScriptMessageHandler attachToWebView:otherWebView
                                                readinessProvider:nil
                                                readinessContract:self.contract], self.handler);
    XCTAssertEqual(contentController.userScripts.count, 1u);
    [self.handler detachFromWebView:self.webView];
    [self sendBody:[self request]
               url:[NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"]
         mainFrame:YES webView:otherWebView completion:^(NSDictionary *response, NSString *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(response[@"status"], @"Success");
    }];
    XCTAssertEqual(self.provider.invocationCount, 1u);
    [self.handler detachFromWebView:otherWebView];
    [self.handler detachFromWebView:otherWebView];
    MSIDWebCPScriptMessageHandler *reattached = [MSIDWebCPScriptMessageHandler
        attachToWebView:otherWebView readinessProvider:nil readinessContract:self.contract];
    XCTAssertNotNil(reattached);
    XCTAssertEqual(contentController.userScripts.count, 1u);
    [reattached detachFromWebView:otherWebView];
}

- (void)testOAuthController_whenReadinessDisabled_shouldNotAttachBridge
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_WEBCP_ONBOARDING_READINESS: @YES};
    WKWebView *suppliedWebView = [[WKWebView alloc] initWithFrame:CGRectZero
                                                    configuration:[WKWebViewConfiguration new]];
    MSIDOAuth2EmbeddedWebviewController *controller =
        [[MSIDOAuth2EmbeddedWebviewController alloc]
         initWithStartURL:[NSURL URLWithString:@"https://login.microsoftonline.com/"]
                   endURL:[NSURL URLWithString:@"msauth://callback"]
                  webview:suppliedWebView
            customHeaders:nil
           platfromParams:nil
                  context:nil];
    NSError *error = nil;
    XCTAssertTrue([controller loadView:&error]);
    XCTAssertNil(error);
    XCTAssertNil(controller.webCPScriptMessageHandler);
    XCTAssertEqual(suppliedWebView.configuration.userContentController.userScripts.count, 0u);
    XCTAssertEqual(controller.webView, suppliedWebView);
}

- (void)testOAuthController_whenCanceled_shouldDetachOnlySuppliedWebView
{
    WKWebView *suppliedWebView = [[WKWebView alloc] initWithFrame:CGRectZero
                                                    configuration:self.webView.configuration];
    MSIDOAuth2EmbeddedWebviewController *controller =
        [[MSIDOAuth2EmbeddedWebviewController alloc]
         initWithStartURL:[NSURL URLWithString:@"https://login.microsoftonline.com/"]
                   endURL:[NSURL URLWithString:@"msauth://callback"]
                  webview:suppliedWebView
            customHeaders:nil
           platfromParams:nil
                  context:nil];
    NSError *error = nil;
    XCTAssertTrue([controller loadView:&error]);
    XCTAssertNil(error);
    XCTAssertEqual(controller.webCPScriptMessageHandler, self.handler);

    [controller cancelProgrammatically];
    XCTAssertNil(controller.webCPScriptMessageHandler);

    NSURL *enrollmentURL = [NSURL URLWithString:
        @"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"];
    [self sendBody:[self request] url:enrollmentURL mainFrame:YES webView:suppliedWebView
        completion:^(id response, NSString *replyError) {
        XCTAssertNil(response);
        XCTAssertNotNil(replyError);
    }];
    [self sendBody:[self request] url:enrollmentURL mainFrame:YES webView:self.webView
        completion:^(NSDictionary *response, NSString *replyError) {
        XCTAssertNil(replyError);
        XCTAssertEqualObjects(response[@"status"], @"Success");
    }];
    XCTAssertEqual(self.provider.invocationCount, 1u);
}

- (void)testOAuthController_whenDeallocated_shouldDetachOnlySuppliedWebView
{
    WKWebView *suppliedWebView = [[WKWebView alloc] initWithFrame:CGRectZero
                                                    configuration:self.webView.configuration];
    __weak MSIDOAuth2EmbeddedWebviewController *weakController;
    @autoreleasepool
    {
        MSIDOAuth2EmbeddedWebviewController *controller =
            [[MSIDOAuth2EmbeddedWebviewController alloc]
             initWithStartURL:[NSURL URLWithString:@"https://login.microsoftonline.com/"]
                       endURL:[NSURL URLWithString:@"msauth://callback"]
                      webview:suppliedWebView
                customHeaders:nil
               platfromParams:nil
                      context:nil];
        NSError *error = nil;
        XCTAssertTrue([controller loadView:&error]);
        XCTAssertNil(error);
        XCTAssertEqual(controller.webCPScriptMessageHandler, self.handler);
        weakController = controller;
    }
    XCTAssertNil(weakController);

    NSURL *enrollmentURL = [NSURL URLWithString:
        @"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"];
    [self sendBody:[self request] url:enrollmentURL mainFrame:YES webView:suppliedWebView
        completion:^(id response, NSString *replyError) {
        XCTAssertNil(response);
        XCTAssertNotNil(replyError);
    }];
    [self sendBody:[self request] url:enrollmentURL mainFrame:YES webView:self.webView
        completion:^(NSDictionary *response, NSString *replyError) {
        XCTAssertNil(replyError);
        XCTAssertEqualObjects(response[@"status"], @"Success");
    }];
    XCTAssertEqual(self.provider.invocationCount, 1u);
}

@end
