//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDWebCPScriptMessageHandler.h"
#import "MSIDOnboardingReadiness.h"
#import "MSIDOnboardingReadinessProvider.h"
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

@interface MSIDReadinessTestProvider : MSIDOnboardingReadinessProvider
@property (nonatomic) MSIDOnboardingReadiness *readinessResult;
@property (nonatomic) NSUInteger invocationCount;
@end

@implementation MSIDReadinessTestProvider
- (MSIDOnboardingReadiness *)readiness
{
    self.invocationCount++;
    return self.readinessResult;
}
@end

@interface MSIDWebCPScriptMessageHandlerTests : XCTestCase
@property (nonatomic) WKWebView *webView;
@property (nonatomic) MSIDReadinessTestProvider *provider;
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
    self.provider.readinessResult = [[MSIDOnboardingReadiness alloc] initWithBrokerAvailability:NO
                                                                     ssoExtensionAvailability:YES];
    self.handler = [MSIDWebCPScriptMessageHandler attachToWebView:self.webView
                                                 readinessProvider:self.provider];
    XCTAssertNotNil(self.handler);
}

- (void)tearDown
{
    [self.handler detachFromWebView:self.webView];
    MSIDFlightManager.sharedInstance.flightProvider = nil;
    [super tearDown];
}

- (NSDictionary *)requestWithVersion:(NSNumber *)version
{
    return @{@"correlationID": @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb",
             @"action_name": @"get_onboarding_readiness",
             @"action_component": @"native",
             @"params": @{@"contractVersion": version}};
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
    [self sendBody:[self requestWithVersion:@1]
               url:[NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"]
         mainFrame:YES webView:self.webView completion:^(NSDictionary *response, NSString *error) {
        replies++;
        XCTAssertNil(error);
        XCTAssertEqualObjects(response[@"correlationID"], @"a7c08f6d-b239-49fb-a494-85f70f1a2fcb");
        XCTAssertEqualObjects(response[@"status"], @"Success");
        XCTAssertEqualObjects(response[@"result"][@"brokerAvailability"], @NO);
        XCTAssertEqualObjects(response[@"result"][@"ssoExtensionAvailability"], @YES);
        XCTAssertEqualObjects(response[@"result"][@"contractVersion"], @1);
    }];
    XCTAssertEqual(replies, 1u);
    XCTAssertEqual(self.provider.invocationCount, 1u);
}

- (void)testHandleBody_whenVersionIsUnsupported_shouldNotProbe
{
    [self sendBody:[self requestWithVersion:@2]
               url:[NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"]
         mainFrame:YES webView:self.webView completion:^(NSDictionary *response, NSString *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(response[@"status"], @"NotSupported");
        XCTAssertEqualObjects(response[@"result"][@"supportedContractVersions"], (@[@1]));
    }];
    XCTAssertEqual(self.provider.invocationCount, 0u);
}

- (void)testHandleBody_whenAnotherActionIsRequested_shouldNotProbe
{
    NSMutableDictionary *body = [[self requestWithVersion:@1] mutableCopy];
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
    NSMutableDictionary *body = [[self requestWithVersion:@1] mutableCopy];
    body[@"before_action"] = @{};
    body[@"params"] = @{@"contractVersion": @1, @"operation": @"open"};
    [self sendBody:body
               url:[NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"]
         mainFrame:YES webView:self.webView completion:^(NSDictionary *response, NSString *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(response[@"status"], @"Success");
        XCTAssertEqualObjects(response[@"result"][@"brokerAvailability"], @NO);
        XCTAssertEqualObjects(response[@"result"][@"ssoExtensionAvailability"], @YES);
    }];
    XCTAssertEqual(self.provider.invocationCount, 1u);
}

- (void)testHandleBody_whenProviderFails_shouldReturnFailedInsteadOfFalseBooleans
{
    self.provider.readinessResult = nil;
    [self sendBody:[self requestWithVersion:@1]
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
    [self sendBody:[self requestWithVersion:@1]
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
        [self sendBody:[self requestWithVersion:@1] url:url mainFrame:YES webView:self.webView
            completion:^(id response, NSString *error) {
            XCTAssertNil(response);
            XCTAssertNotNil(error);
        }];
    }
    [self sendBody:[self requestWithVersion:@1]
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
        [self sendBody:[self requestWithVersion:@1] url:url mainFrame:YES webView:self.webView
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
    WKWebView *otherWebView = [[WKWebView alloc] initWithFrame:CGRectZero
                                                 configuration:self.webView.configuration];
    XCTAssertEqual([MSIDWebCPScriptMessageHandler attachToWebView:otherWebView
                                                readinessProvider:nil], self.handler);
    [self.handler detachFromWebView:self.webView];
    [self sendBody:[self requestWithVersion:@1]
               url:[NSURL URLWithString:@"https://portal.manage.microsoft.com/enrollment/webenrollment/waitForDeviceCheckin"]
         mainFrame:YES webView:otherWebView completion:^(NSDictionary *response, NSString *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(response[@"status"], @"Success");
    }];
    XCTAssertEqual(self.provider.invocationCount, 1u);
    [self.handler detachFromWebView:otherWebView];
    [self.handler detachFromWebView:otherWebView];
}

- (void)testOAuthController_whenReadinessDisabled_shouldAttachBridgeToSuppliedWebView
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
    XCTAssertNotNil(controller.webCPScriptMessageHandler);
    XCTAssertEqual(controller.webView, suppliedWebView);
}

@end
