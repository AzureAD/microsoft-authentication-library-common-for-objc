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
#import "MSIDOnboardingBlobBuilder.h"

#if !MSID_EXCLUDE_WEBKIT

// Expose private methods for testing
@interface MSIDOAuth2EmbeddedWebviewController (Testing)
- (BOOL)shouldOpenURLInSystemBrowser:(NSURL *)url targetFrame:(WKFrameInfo *)targetFrame;
- (NSString *)onboardingStepForEndURL:(NSURL *)endURL;
- (void)finalizeOnboardingTelemetry:(NSURL *)endURL error:(NSError *)error;
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

#pragma mark - finalizeOnboardingTelemetry:error:

- (MSIDOnboardingBlobBuilder *)builderForFinalizeTest
{
    NSDictionary *seed = @{@"schema_version": @"1.0.0", @"session_correlation_id": @"abc-123", @"onboarding_mode": @"non-brokered"};
    NSString *seedJson = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:seed options:0 error:nil]
                                               encoding:NSUTF8StringEncoding];
    return [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"clientA" target:@"resource1"];
}

- (NSArray<NSString *> *)stampedStepIdsFromBuilder:(MSIDOnboardingBlobBuilder *)builder
{
    NSData *data = [[builder finalizeBlob] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSMutableArray<NSString *> *stepIds = [NSMutableArray new];
    for (NSDictionary *step in parsed[@"steps_list"])
    {
        [stepIds addObject:step[@"step_id"]];
    }
    return stepIds;
}

- (void)testFinalizeOnboardingTelemetry_whenBuilderStrongAuthFlagSetAndSuccess_shouldStampStrongAuthSetupCompleted
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    MSIDOnboardingBlobBuilder *builder = [self builderForFinalizeTest];
    webVC.onboardingBlobBuilder = builder;

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]
                                                             statusCode:200
                                                            HTTPVersion:@"HTTP/1.1"
                                                           headerFields:@{@"x-ms-clitelem": @"2,50079,0,,"}];
    [webVC processOnboardingTelemetryForResponse:response];
    XCTAssertTrue(builder.strongAuthSetupStarted);

    [webVC finalizeOnboardingTelemetry:[NSURL URLWithString:@"https://contoso.com/done"] error:nil];

    XCTAssertTrue([[self stampedStepIdsFromBuilder:builder] containsObject:MSIDOnboardingBlobStepStrongAuthSetupCompleted]);
}

- (void)testFinalizeOnboardingTelemetry_whenFlagSetButError_shouldNotStampCompleted
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    MSIDOnboardingBlobBuilder *builder = [self builderForFinalizeTest];
    [builder processResponseHeaders:@{@"x-ms-clitelem": @"2,50079,0,,"} responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];
    webVC.onboardingBlobBuilder = builder;

    NSError *error = [NSError errorWithDomain:@"TestDomain" code:-1 userInfo:nil];
    [webVC finalizeOnboardingTelemetry:[NSURL URLWithString:@"https://contoso.com/done"] error:error];

    XCTAssertFalse([[self stampedStepIdsFromBuilder:builder] containsObject:MSIDOnboardingBlobStepStrongAuthSetupCompleted]);
}

- (void)testFinalizeOnboardingTelemetry_whenNoStartedFlagAndSuccess_shouldNotStampCompleted
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    MSIDOnboardingBlobBuilder *builder = [self builderForFinalizeTest];
    XCTAssertFalse(builder.strongAuthSetupStarted);
    webVC.onboardingBlobBuilder = builder;

    [webVC finalizeOnboardingTelemetry:[NSURL URLWithString:@"https://contoso.com/done"] error:nil];

    NSArray<NSString *> *steps = [self stampedStepIdsFromBuilder:builder];
    XCTAssertFalse([steps containsObject:MSIDOnboardingBlobStepStrongAuthSetupCompleted]);
    XCTAssertFalse([steps containsObject:MSIDOnboardingBlobStepMdmEnrollmentFinished]);
}

@end

#endif
