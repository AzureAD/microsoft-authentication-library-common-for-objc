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

#if !MSID_EXCLUDE_WEBKIT

#import <XCTest/XCTest.h>
#import "MSIDWebviewNavigationDecisionResolver.h"
#import "MSIDWebviewNavigationDecision.h"
#import "MSIDWebviewConstants.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDSSOExtensionInteractiveTokenRequestController.h"
#import "MSIDIntuneDeviceIdCache.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDTestSwizzle.h"
#import "MSIDVersion.h"
#import "MSIDUXCallbackProvider.h"
#import "MSIDUXCallbackProtocol.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDConstants.h"
#import "MSIDMockUXCallbackProvider.h"
#import "MSIDOnboardingBlobBuilder.h"
#import "MSIDOnboardingBlobBuilder+MSIDTestUtil.h"
#import "MSIDOnboardingBlobFieldKeys.h"

@interface MSIDWebviewNavigationDecisionResolverTests : XCTestCase

@property (nonatomic) MSIDWebviewNavigationDecisionResolver *resolver;
@property (nonatomic) MSIDTestCacheDataSource *dataSource;
@property (nonatomic) MSIDIntuneDeviceIdCache *deviceIdCache;
@property (nonatomic) MSIDFlightManagerMockProvider *flightProvider;

@end

@implementation MSIDWebviewNavigationDecisionResolverTests

- (void)setUp
{
    [super setUp];
    self.resolver = [MSIDWebviewNavigationDecisionResolver sharedInstance];

    // Inject a fresh in-memory device-id cache (backed by a mock data source) for each test.
    // Mirrors the approach used in MSIDIntuneDeviceIdCacheTests so the keychain is never touched.
    self.dataSource = [MSIDTestCacheDataSource new];
    self.deviceIdCache = [[MSIDIntuneDeviceIdCache alloc] initWithDataSource:self.dataSource];
    [MSIDIntuneDeviceIdCache setSharedCache:self.deviceIdCache];

    self.flightProvider = [MSIDFlightManagerMockProvider new];
    MSIDFlightManager.sharedInstance.flightProvider = self.flightProvider;
}

- (void)tearDown
{
    [MSIDTestSwizzle reset];
    [self.dataSource reset];
    MSIDUXCallbackProvider.uxCallbackProvider = nil;
    MSIDFlightManager.sharedInstance.flightProvider = nil;
    [super tearDown];
}

#pragma mark - Helpers

// Builds a controller wired with the supplied external browser-action block.
- (MSIDOAuth2EmbeddedWebviewController *)createWebviewControllerWithExternalBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)block
{
    MSIDOAuth2EmbeddedWebviewController *controller =
        [[MSIDOAuth2EmbeddedWebviewController alloc] initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                               endURL:[NSURL URLWithString:@"endurl://host"]
                                                              webview:nil
                                                        customHeaders:nil
                                                       platfromParams:nil
                                                              context:nil];
    controller.externalDecidePolicyForBrowserAction = block;
    return controller;
}

#pragma mark - Nil / empty URL

- (void)testResolveDecision_nilURL_returnsFailWithError
{
    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:nil
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertNotNil(decision.error);
}

- (void)testResolveDecision_URLMissingScheme_returnsFailWithError
{
    // A URL without a scheme (e.g. "//host/path") must surface a failWithError decision
    // rather than nil so the caller always receives an actionable navigation outcome.
    NSURL *url = [NSURL URLWithString:@"//host/path"];
    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertNotNil(decision.error);
}

#pragma mark - Scheme routing

- (void)testResolveDecision_browserScheme_returnsContinueDefault
{
    NSURL *url = [NSURL URLWithString:@"browser://some.host/path"];
    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionContinueDefault);
}

- (void)testResolveDecision_unknownScheme_returnsContinueDefault
{
    NSURL *url = [NSURL URLWithString:@"foobar://some.host"];
    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionContinueDefault);
}

#pragma mark - msauth:// host routing

- (void)testResolveDecision_msauthEmptyHost_returnsFailWithError
{
    // msauth:/// has no host
    NSURL *url = [NSURL URLWithString:@"msauth:///path"];
    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertNotNil(decision.error);
}

- (void)testResolveDecision_msauthUnknownHost_returnsContinueDefault
{
    NSURL *url = [NSURL URLWithString:@"msauth://unknownhost"];
    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionContinueDefault);
}

#pragma mark - Enroll host

- (void)testEnrollURL_missingIntuneURL_returnsFailWithError
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@", MSID_MDM_ENROLL_HOST]];
    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertNotNil(decision.error);
}

- (void)testEnrollURL_validIntuneURL_returnsLoadRequest
{
    NSString *targetURL = @"https://manage.microsoft.com/enroll";
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_MDM_ENROLL_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    XCTAssertNotNil(decision.request);
    XCTAssertTrue([decision.request.URL.host isEqualToString:@"manage.microsoft.com"]);
}

- (void)testEnrollURL_attachesCachedDeviceId_whenPresent
{
    NSError *cacheError = nil;
    XCTAssertTrue([self.deviceIdCache setIntuneDeviceId:@"device-abc" context:nil error:&cacheError]);
    XCTAssertNil(cacheError);

    NSString *targetURL = @"https://manage.microsoft.com/enroll";
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_MDM_ENROLL_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);

    NSURLComponents *components = [NSURLComponents componentsWithURL:decision.request.URL resolvingAgainstBaseURL:NO];
    NSString *deviceId = nil;
    for (NSURLQueryItem *item in components.queryItems)
    {
        if ([item.name isEqualToString:MSID_INTUNE_DEVICE_ID_KEY])
        {
            deviceId = item.value;
            break;
        }
    }
    XCTAssertEqualObjects(deviceId, @"device-abc");
}

- (void)testEnrollURL_attachesPlatformAndVersionHeadersFromMSIDVersion
{
    // This test asserts the SDK-controlled x-client-SKU / x-client-Ver headers, which the
    // resolver always derives from MSIDVersion (independent of any caller-supplied headers).
    // The test target's MSIDVersion returns "TEST.iOS" / "1.0.0" (see tests/MSIDVersion.m).
    NSString *targetURL = @"https://manage.microsoft.com/enroll";
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_MDM_ENROLL_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    XCTAssertEqualObjects([decision.request valueForHTTPHeaderField:MSID_PLATFORM_KEY], [MSIDVersion platformName]);
    XCTAssertEqualObjects([decision.request valueForHTTPHeaderField:MSID_VERSION_KEY], [MSIDVersion sdkVersion]);
}

- (void)testEnrollURL_whenAdditionalHeadersProvided_attachesBrokerVersionHeader
{
    NSString *targetURL = @"https://manage.microsoft.com/enroll";
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_MDM_ENROLL_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:@{MSID_BROKER_VER_KEY: @"6.1.2"}];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    XCTAssertEqualObjects([decision.request valueForHTTPHeaderField:MSID_BROKER_VER_KEY], @"6.1.2");
}

- (void)testEnrollURL_whenAdditionalHeadersNil_doesNotAttachBrokerVersionHeader
{
    NSString *targetURL = @"https://manage.microsoft.com/enroll";
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_MDM_ENROLL_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURL *url = [NSURL URLWithString:urlString];

    // Passing nil additional headers omits the broker version header.
    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    XCTAssertNil([decision.request valueForHTTPHeaderField:MSID_BROKER_VER_KEY]);
}

- (void)testEnrollURL_whenAdditionalHeadersContainAppHeaders_attachesThemVerbatim
{
    // The resolver is a dumb merger: it stamps whatever the caller supplies without
    // doing any of its own gating.
    NSString *targetURL = @"https://manage.microsoft.com/enroll";
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_MDM_ENROLL_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURL *url = [NSURL URLWithString:urlString];

    NSDictionary *headers = @{MSID_BROKER_VER_KEY: @"6.1.2",
                              MSID_APP_NAME_KEY: @"Contoso",
                              MSID_APP_VER_KEY: @"1.2.3"};
    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:headers];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    XCTAssertEqualObjects([decision.request valueForHTTPHeaderField:MSID_BROKER_VER_KEY], @"6.1.2");
    XCTAssertEqualObjects([decision.request valueForHTTPHeaderField:MSID_APP_NAME_KEY], @"Contoso");
    XCTAssertEqualObjects([decision.request valueForHTTPHeaderField:MSID_APP_VER_KEY], @"1.2.3");
}

#pragma mark - Profile download complete host

- (void)testProfileDownloadComplete_missingDeviceId_returnsLoadRequest
{
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=https%%3A%%2F%%2Fmanage.microsoft.com%%2Fprofile",
                           MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST, MSID_INTUNE_PROFILE_INSTALL_URL_KEY];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    XCTAssertNotNil(decision.request);
}

- (void)testProfileDownloadComplete_missingProfileInstallURL_returnsFailWithError
{
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=device123",
                           MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST, MSID_INTUNE_DEVICE_ID_KEY];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertNotNil(decision.error);
}

- (void)testProfileDownloadComplete_validParams_returnsLoadRequest
{
    NSString *profileURL = @"https://manage.microsoft.com/profile.mobileconfig";
    NSString *encodedURL = [profileURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=device123&%@=%@",
                           MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST,
                           MSID_INTUNE_DEVICE_ID_KEY,
                           MSID_INTUNE_PROFILE_INSTALL_URL_KEY,
                           encodedURL];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    XCTAssertNotNil(decision.request);
    XCTAssertEqualObjects(decision.request.URL.absoluteString, profileURL);
}

- (void)testProfileDownloadComplete_cachesDeviceId
{
    NSString *profileURL = @"https://manage.microsoft.com/profile.mobileconfig";
    NSString *encodedURL = [profileURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=myDeviceXYZ&%@=%@",
                           MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST,
                           MSID_INTUNE_DEVICE_ID_KEY,
                           MSID_INTUNE_PROFILE_INSTALL_URL_KEY,
                           encodedURL];
    NSURL *url = [NSURL URLWithString:urlString];

    [self.resolver resolveDecisionForURL:url
                       embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    NSError *readError = nil;
    NSString *cached = [self.deviceIdCache intuneDeviceIdWithContext:nil error:&readError];
    XCTAssertNil(readError);
    XCTAssertEqualObjects(cached, @"myDeviceXYZ");
}

- (void)testProfileDownloadComplete_malformedProfileURL_returnsFailWithError
{
    // A value with no scheme/host. NSURL may parse it as a relative URL on newer SDKs,
    // but the resolver explicitly rejects URLs missing a scheme or host.
    NSString *badURL = @"not a url at all";
    NSURLComponents *comps = [NSURLComponents new];
    comps.scheme = @"msauth";
    comps.host = MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST;
    NSURLQueryItem *di = [NSURLQueryItem queryItemWithName:MSID_INTUNE_DEVICE_ID_KEY value:@"device123"];
    NSURLQueryItem *pu = [NSURLQueryItem queryItemWithName:MSID_INTUNE_PROFILE_INSTALL_URL_KEY value:badURL];
    comps.queryItems = @[di, pu];
    NSURL *url = comps.URL;
    XCTAssertNotNil(url, @"Test input msauth URL should itself be valid");

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertNotNil(decision.error);
}

#pragma mark - Compliance host

- (void)testComplianceURL_missingIntuneURL_returnsFailWithError
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@", MSID_COMPLIANCE_HOST]];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertNotNil(decision.error);
}

- (void)testComplianceURL_validParams_noExternalBlock_returnsLoadRequest
{
    NSString *targetURL = @"https://compliance.microsoft.com/check";
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_COMPLIANCE_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    XCTAssertNotNil(decision.request);
    XCTAssertEqualObjects(decision.request.URL.host, @"compliance.microsoft.com");
}

- (void)testComplianceURL_withExternalBlock_blockReturnsNil_returnsLoadRequest
{
    NSString *targetURL = @"https://compliance.microsoft.com/check";
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_COMPLIANCE_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURL *url = [NSURL URLWithString:urlString];

    // Block that returns nil simulates "no override". The resolver invokes the block
    // only when the controller exposes a non-nil externalDecidePolicyForBrowserAction.
    __block BOOL invoked = NO;
    MSIDExternalDecidePolicyForBrowserActionBlock block = ^NSURLRequest * _Nullable(MSIDOAuth2EmbeddedWebviewController * __unused wv, NSURL * __unused u)
    {
        invoked = YES;
        return nil;
    };

    MSIDOAuth2EmbeddedWebviewController *webviewController = [self createWebviewControllerWithExternalBlock:block];
    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                         embeddedWebviewController:webviewController
                                                                         additionalHeaders:nil];
    XCTAssertTrue(invoked, @"External block must be invoked when a webview controller is provided.");
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    XCTAssertEqualObjects(decision.request.URL.host, @"compliance.microsoft.com");
}

- (void)testComplianceURL_withExternalBlock_blockReturnsRequest_usesUpdatedRequest
{
    NSString *targetURL = @"https://compliance.microsoft.com/check";
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_COMPLIANCE_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURL *url = [NSURL URLWithString:urlString];

    NSURL *overrideURL = [NSURL URLWithString:@"https://override.example.com/path"];
    NSURLRequest *overrideRequest = [NSURLRequest requestWithURL:overrideURL];

    __block NSURL *receivedURL = nil;
    MSIDExternalDecidePolicyForBrowserActionBlock block = ^NSURLRequest * _Nullable(MSIDOAuth2EmbeddedWebviewController * __unused wv, NSURL *u)
    {
        receivedURL = u;
        return overrideRequest;
    };

    // The compliance external block is only invoked when the controller's
    // externalDecidePolicyForBrowserAction is non-nil.
    MSIDOAuth2EmbeddedWebviewController *webviewController = [self createWebviewControllerWithExternalBlock:block];
    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                         embeddedWebviewController:webviewController
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    XCTAssertEqualObjects(decision.request.URL.absoluteString, @"https://override.example.com/path");

    // The URL passed to the block should use the browser:// scheme
    XCTAssertEqualObjects(receivedURL.scheme, @"browser");
}

#pragma mark - Enrollment completion host

- (void)testEnrollmentCompletion_ssoExtensionAvailable_returnsCompleteWithURL
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return YES;
    }];

    NSString *urlString = [NSString stringWithFormat:@"msauth://%@", MSID_MDM_ENROLLMENT_COMPLETION_HOST];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionCompleteWithURL);
    XCTAssertEqualObjects(decision.URL, url);
}

- (void)testEnrollmentCompletion_ssoExtensionUnavailable_noErrorURL_returnsFailWithError
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return NO;
    }];

    NSString *urlString = [NSString stringWithFormat:@"msauth://%@", MSID_MDM_ENROLLMENT_COMPLETION_HOST];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertNotNil(decision.error);
}

- (void)testEnrollmentCompletion_ssoExtensionUnavailable_withErrorURL_returnsLoadRequest
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return NO;
    }];

    NSString *errorURL = @"https://enroll.microsoft.com/error";
    NSString *encoded = [errorURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_MDM_ENROLLMENT_COMPLETION_HOST,
                           MSID_MDM_ENROLLMENT_COMPLETION_ERROR_URL_KEY,
                           encoded];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    XCTAssertEqualObjects(decision.request.URL.absoluteString, errorURL);
}

#pragma mark - Whitespace-only parameter values

- (void)testEnrollURL_whitespaceOnlyIntuneURL_returnsFailWithError
{
    // A trimmed whitespace value must be treated as missing.
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_MDM_ENROLL_HOST, MSID_INTUNE_URL_KEY, @"%20%20%20"];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertNotNil(decision.error);
}

- (void)testComplianceURL_whitespaceOnlyIntuneURL_returnsFailWithError
{
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_COMPLIANCE_HOST, MSID_INTUNE_URL_KEY, @"%20%20"];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertNotNil(decision.error);
}

- (void)testProfileDownloadComplete_whitespaceOnlyDeviceId_doesNotCache
{
    NSString *profileURL = @"https://manage.microsoft.com/profile.mobileconfig";
    NSString *encodedURL = [profileURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@&%@=%@",
                           MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST,
                           MSID_INTUNE_DEVICE_ID_KEY, @"%20%20",
                           MSID_INTUNE_PROFILE_INSTALL_URL_KEY, encodedURL];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);

    NSError *readError = nil;
    NSString *cached = [self.deviceIdCache intuneDeviceIdWithContext:nil error:&readError];
    XCTAssertNil(cached, @"Whitespace-only device id must not be persisted.");
}

- (void)testProfileDownloadComplete_whitespaceOnlyProfileInstallURL_returnsFailWithError
{
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=device123&%@=%@",
                           MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST,
                           MSID_INTUNE_DEVICE_ID_KEY,
                           MSID_INTUNE_PROFILE_INSTALL_URL_KEY, @"%20%20"];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertNotNil(decision.error);
}

- (void)testEnrollmentCompletion_ssoExtensionUnavailable_whitespaceErrorURL_returnsFailWithError
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return NO;
    }];

    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_MDM_ENROLLMENT_COMPLETION_HOST,
                           MSID_MDM_ENROLLMENT_COMPLETION_ERROR_URL_KEY, @"%20%20"];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                                 embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertNotNil(decision.error);
}

#pragma mark - Compliance legacy 'browser' scheme rewrite

- (void)testComplianceURL_legacySchemeRewrite_preservesHostPathAndQuery
{
    NSString *targetURL = @"https://compliance.microsoft.com/check?foo=bar";

    // Use NSURLComponents so '?' and '=' in the inner URL are percent-encoded.
    NSURLComponents *outer = [NSURLComponents new];
    outer.scheme = @"msauth";
    outer.host = MSID_COMPLIANCE_HOST;
    outer.queryItems = @[[NSURLQueryItem queryItemWithName:MSID_INTUNE_URL_KEY value:targetURL]];
    NSURL *url = outer.URL;
    XCTAssertNotNil(url);

    __block NSURL *receivedURL = nil;
    MSIDExternalDecidePolicyForBrowserActionBlock block = ^NSURLRequest * _Nullable(MSIDOAuth2EmbeddedWebviewController * __unused wv, NSURL *u)
    {
        receivedURL = u;
        return nil;
    };

    MSIDOAuth2EmbeddedWebviewController *webviewController = [self createWebviewControllerWithExternalBlock:block];
    [self.resolver resolveDecisionForURL:url
               embeddedWebviewController:webviewController
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(receivedURL);
    XCTAssertEqualObjects(receivedURL.scheme, @"browser");
    XCTAssertEqualObjects(receivedURL.host, @"compliance.microsoft.com");
    XCTAssertEqualObjects(receivedURL.path, @"/check");
    XCTAssertTrue([receivedURL.query containsString:@"foo=bar"],
                  @"Query string should survive the scheme rewrite. Got: %@", receivedURL.query);
}

- (void)testComplianceURL_externalBlockNotInvoked_whenWebviewControllerIsNil
{
    NSString *targetURL = @"https://compliance.microsoft.com/check";
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_COMPLIANCE_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURL *url = [NSURL URLWithString:urlString];

    // Even with the block defined locally, passing a nil controller means the resolver
    // has no externalDecidePolicyForBrowserAction to invoke.
    __block BOOL invoked = NO;
    MSIDExternalDecidePolicyForBrowserActionBlock block __unused = ^NSURLRequest * _Nullable(MSIDOAuth2EmbeddedWebviewController * __unused wv, NSURL * __unused u)
    {
        invoked = YES;
        return nil;
    };

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url
                                                         embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertFalse(invoked, @"External block must not be invoked when no webview controller is provided.");
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
}

#pragma mark - UX Callback Tests

- (void)testProfileDownloadComplete_whenProviderSet_shouldNotScheduleNotification
{
    MSIDMockUXCallbackProvider *mockProvider = [MSIDMockUXCallbackProvider new];
    MSIDUXCallbackProvider.uxCallbackProvider = mockProvider;

    NSString *profileURL = @"https://manage.microsoft.com/profile.mobileconfig";
    NSString *encodedURL = [profileURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=device123&%@=%@",
                           MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST,
                           MSID_INTUNE_DEVICE_ID_KEY,
                           MSID_INTUNE_PROFILE_INSTALL_URL_KEY,
                           encodedURL];
    NSURL *url = [NSURL URLWithString:urlString];

    [self.resolver resolveDecisionForURL:url embeddedWebviewController:nil
                                                                         additionalHeaders:nil];

    XCTAssertFalse(mockProvider.scheduleCalled, @"Scheduling moved to the profile-download hand-off; the resolver must not schedule here.");
    XCTAssertTrue(mockProvider.scheduleCalled, @"UX callback should be invoked on profile download complete.");
    XCTAssertEqualWithAccuracy(mockProvider.receivedDelay, MSIDMDMProfileInstalledNotificationDefaultDelay, 0.01);
}

- (void)testProfileDownloadComplete_whenFlightConfiguresDelay_shouldPassFlightDelay
{
    MSIDMockUXCallbackProvider *mockProvider = [MSIDMockUXCallbackProvider new];
    MSIDUXCallbackProvider.uxCallbackProvider = mockProvider;

    self.flightProvider.stringForKeyContainer = @{ MSID_FLIGHT_MDM_PROFILE_INSTALLED_NOTIFICATION_DELAY: @"300" };

    NSString *profileURL = @"https://manage.microsoft.com/profile.mobileconfig";
    NSString *encodedURL = [profileURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=device123&%@=%@",
                           MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST,
                           MSID_INTUNE_DEVICE_ID_KEY,
                           MSID_INTUNE_PROFILE_INSTALL_URL_KEY,
                           encodedURL];
    NSURL *url = [NSURL URLWithString:urlString];

    [self.resolver resolveDecisionForURL:url embeddedWebviewController:nil
                                                                         additionalHeaders:nil];

    XCTAssertTrue(mockProvider.scheduleCalled);
    XCTAssertEqualWithAccuracy(mockProvider.receivedDelay, 300.0, 0.01);
}

- (void)testProfileDownloadComplete_whenFlightDelayIsNegative_shouldFallbackToDefault
{
    MSIDMockUXCallbackProvider *mockProvider = [MSIDMockUXCallbackProvider new];
    MSIDUXCallbackProvider.uxCallbackProvider = mockProvider;

    self.flightProvider.stringForKeyContainer = @{ MSID_FLIGHT_MDM_PROFILE_INSTALLED_NOTIFICATION_DELAY: @"-5" };

    NSString *profileURL = @"https://manage.microsoft.com/profile.mobileconfig";
    NSString *encodedURL = [profileURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=device123&%@=%@",
                           MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST,
                           MSID_INTUNE_DEVICE_ID_KEY,
                           MSID_INTUNE_PROFILE_INSTALL_URL_KEY,
                           encodedURL];
    NSURL *url = [NSURL URLWithString:urlString];

    [self.resolver resolveDecisionForURL:url embeddedWebviewController:nil
                                                                         additionalHeaders:nil];

    XCTAssertTrue(mockProvider.scheduleCalled);
    XCTAssertEqualWithAccuracy(mockProvider.receivedDelay, MSIDMDMProfileInstalledNotificationDefaultDelay, 0.01);
}

- (void)testProfileDownloadComplete_whenProviderIsNil_shouldNotCrash
{
    MSIDUXCallbackProvider.uxCallbackProvider = nil;

    NSString *profileURL = @"https://manage.microsoft.com/profile.mobileconfig";
    NSString *encodedURL = [profileURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=device123&%@=%@",
                           MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST,
                           MSID_INTUNE_DEVICE_ID_KEY,
                           MSID_INTUNE_PROFILE_INSTALL_URL_KEY,
                           encodedURL];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
}

#pragma mark - Cancel Notification on Enrollment Completion

- (void)testEnrollmentCompletion_whenProviderSet_shouldCancelNotification
{
    MSIDMockUXCallbackProvider *mockProvider = [MSIDMockUXCallbackProvider new];
    MSIDUXCallbackProvider.uxCallbackProvider = mockProvider;

    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return YES;
    }];

    NSString *urlString = [NSString stringWithFormat:@"msauth://%@", MSID_MDM_ENROLLMENT_COMPLETION_HOST];
    NSURL *url = [NSURL URLWithString:urlString];

    [self.resolver resolveDecisionForURL:url embeddedWebviewController:nil
                                                                         additionalHeaders:nil];

    XCTAssertTrue(mockProvider.cancelCalled, @"Cancel should be invoked on enrollment completion.");
}

- (void)testEnrollmentCompletion_whenProviderIsNil_shouldNotCrash
{
    MSIDUXCallbackProvider.uxCallbackProvider = nil;

    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return YES;
    }];

    NSString *urlString = [NSString stringWithFormat:@"msauth://%@", MSID_MDM_ENROLLMENT_COMPLETION_HOST];
    NSURL *url = [NSURL URLWithString:urlString];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url embeddedWebviewController:nil
                                                                         additionalHeaders:nil];
    XCTAssertNotNil(decision);
    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionCompleteWithURL);
}

#pragma mark - Onboarding telemetry step stamping

- (MSIDOAuth2EmbeddedWebviewController *)controllerWithOnboardingBuilder:(MSIDOnboardingBlobBuilder *)builder
{
    MSIDOAuth2EmbeddedWebviewController *controller = [self createWebviewControllerWithExternalBlock:nil];
    controller.onboardingBlobBuilder = builder;
    return controller;
}

- (NSString *)enrollishURLForHost:(NSString *)host targetURL:(NSString *)targetURL
{
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    return [NSString stringWithFormat:@"msauth://%@?%@=%@", host, MSID_INTUNE_URL_KEY, encoded];
}

- (void)testResolveEnroll_whenIntuneUrlMissing_shouldStampMdmEnrollmentUrlMissing
{
    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    MSIDOAuth2EmbeddedWebviewController *controller = [self controllerWithOnboardingBuilder:builder];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@", MSID_MDM_ENROLL_HOST]];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url embeddedWebviewController:controller
                                                                         additionalHeaders:nil];

    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertTrue([[builder msidStampedStepIds] containsObject:MSIDOnboardingBlobStepMdmEnrollmentUrlMissing]);
}

- (void)testResolveEnroll_whenValidIntuneUrl_shouldStampMdmEnrollmentStarted
{
    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    MSIDOAuth2EmbeddedWebviewController *controller = [self controllerWithOnboardingBuilder:builder];
    NSURL *url = [NSURL URLWithString:[self enrollishURLForHost:MSID_MDM_ENROLL_HOST targetURL:@"https://manage.microsoft.com/enroll"]];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url embeddedWebviewController:controller
                                                                         additionalHeaders:nil];

    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    NSArray<NSString *> *steps = [builder msidStampedStepIds];
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepMdmEnrollmentStarted]);
    XCTAssertFalse([steps containsObject:MSIDOnboardingBlobStepMdmEnrollmentRequestMalformed]);
}

- (void)testResolveProfileDownload_whenContinueUrlMissing_shouldStampProfileInstallUrlMissing
{
    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    MSIDOAuth2EmbeddedWebviewController *controller = [self controllerWithOnboardingBuilder:builder];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@?%@=device123",
                                       MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST, MSID_INTUNE_DEVICE_ID_KEY]];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url embeddedWebviewController:controller
                                                                         additionalHeaders:nil];

    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertTrue([[builder msidStampedStepIds] containsObject:MSIDOnboardingBlobStepProfileInstallUrlMissing]);
}

- (void)testResolveProfileDownload_whenContinueUrlMalformed_shouldStampProfileInstallUrlMalformed
{
    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    MSIDOAuth2EmbeddedWebviewController *controller = [self controllerWithOnboardingBuilder:builder];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@?%@=notaurl",
                                       MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST, MSID_INTUNE_PROFILE_INSTALL_URL_KEY]];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url embeddedWebviewController:controller
                                                                         additionalHeaders:nil];

    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertTrue([[builder msidStampedStepIds] containsObject:MSIDOnboardingBlobStepProfileInstallUrlMalformed]);
}

- (void)testResolveProfileDownload_whenValidUrlAndProviderSet_shouldStampNotificationScheduledAndCompleted
{
    MSIDMockUXCallbackProvider *mockProvider = [MSIDMockUXCallbackProvider new];
    MSIDUXCallbackProvider.uxCallbackProvider = mockProvider;

    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    MSIDOAuth2EmbeddedWebviewController *controller = [self controllerWithOnboardingBuilder:builder];
    NSString *encoded = [@"https://manage.microsoft.com/profile.mobileconfig" stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@?%@=%@",
                                       MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST, MSID_INTUNE_PROFILE_INSTALL_URL_KEY, encoded]];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url embeddedWebviewController:controller
                                                                         additionalHeaders:nil];

    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    NSArray<NSString *> *steps = [builder msidStampedStepIds];
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepProfileInstallNotificationScheduled]);
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepProfileDownloadCompleted]);
}

- (void)testResolveProfileDownload_whenValidUrlAndProviderNil_shouldStampCompletedOnly
{
    MSIDUXCallbackProvider.uxCallbackProvider = nil;

    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    MSIDOAuth2EmbeddedWebviewController *controller = [self controllerWithOnboardingBuilder:builder];
    NSString *encoded = [@"https://manage.microsoft.com/profile.mobileconfig" stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@?%@=%@",
                                       MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST, MSID_INTUNE_PROFILE_INSTALL_URL_KEY, encoded]];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url embeddedWebviewController:controller
                                                                         additionalHeaders:nil];

    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    NSArray<NSString *> *steps = [builder msidStampedStepIds];
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepProfileDownloadCompleted]);
    XCTAssertFalse([steps containsObject:MSIDOnboardingBlobStepProfileInstallNotificationScheduled]);
}

- (void)testResolveCompliance_whenValidIntuneUrl_shouldStampComplianceRemediationMSAuthRedirect
{
    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    MSIDOAuth2EmbeddedWebviewController *controller = [self controllerWithOnboardingBuilder:builder];
    NSURL *url = [NSURL URLWithString:[self enrollishURLForHost:MSID_COMPLIANCE_HOST targetURL:@"https://manage.microsoft.com/compliance"]];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url embeddedWebviewController:controller
                                                                         additionalHeaders:nil];

    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    NSArray<NSString *> *steps = [builder msidStampedStepIds];
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepComplianceRemediationMSAuthRedirect]);
    XCTAssertFalse([steps containsObject:MSIDOnboardingBlobStepComplianceRemediationRequestMalformed]);
}

- (void)testResolveCompliance_whenIntuneUrlMissing_shouldStampComplianceRemediationUrlMissing
{
    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    MSIDOAuth2EmbeddedWebviewController *controller = [self controllerWithOnboardingBuilder:builder];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@", MSID_COMPLIANCE_HOST]];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url embeddedWebviewController:controller
                                                                         additionalHeaders:nil];

    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    NSArray<NSString *> *steps = [builder msidStampedStepIds];
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepComplianceRemediationMSAuthRedirect]);
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepComplianceRemediationUrlMissing]);
}

- (void)testResolveEnrollmentCompletion_whenSSOUnavailableNoErrorURL_shouldStampSSOExtensionUnavailable
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void) { return NO; }];

    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    MSIDOAuth2EmbeddedWebviewController *controller = [self controllerWithOnboardingBuilder:builder];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@", MSID_MDM_ENROLLMENT_COMPLETION_HOST]];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url embeddedWebviewController:controller
                                                                         additionalHeaders:nil];

    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
    XCTAssertTrue([[builder msidStampedStepIds] containsObject:MSIDOnboardingBlobStepSSOExtensionUnavailable]);
}

- (void)testResolveEnrollmentCompletion_whenSSOUnavailableWithErrorURL_shouldStampMdmEnrollmentCompletionRetryStarted
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void) { return NO; }];

    MSIDOnboardingBlobBuilder *builder = [MSIDOnboardingBlobBuilder msidTestBuilder];
    MSIDOAuth2EmbeddedWebviewController *controller = [self controllerWithOnboardingBuilder:builder];
    NSString *encoded = [@"https://enroll.microsoft.com/error" stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@?%@=%@",
                                       MSID_MDM_ENROLLMENT_COMPLETION_HOST, MSID_MDM_ENROLLMENT_COMPLETION_ERROR_URL_KEY, encoded]];

    MSIDWebviewNavigationDecision *decision = [self.resolver resolveDecisionForURL:url embeddedWebviewController:controller
                                                                         additionalHeaders:nil];

    XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
    NSArray<NSString *> *steps = [builder msidStampedStepIds];
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepSSOExtensionUnavailable]);
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepMdmEnrollmentCompletionRetryStarted]);
}

@end

#endif // !MSID_EXCLUDE_WEBKIT
