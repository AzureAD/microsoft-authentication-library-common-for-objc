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

#if !MSID_EXCLUDE_WEBKIT

// Expose private method for testing
@interface MSIDOAuth2EmbeddedWebviewController (Testing)
- (BOOL)shouldOpenURLInSystemBrowser:(NSURL *)url targetFrame:(WKFrameInfo *)targetFrame;
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

- (void)testCreateWebView_whenKillSwitchEnabled_flightManagerReturnsYes
{
    MSIDFlightManagerMockProvider *flightProvider = [MSIDFlightManagerMockProvider new];
    flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_OPEN_NEW_WINDOW_IN_BROWSER: @YES};
    MSIDFlightManager.sharedInstance.flightProvider = flightProvider;

    XCTAssertTrue([[MSIDFlightManager sharedInstance] boolForKey:MSID_FLIGHT_DISABLE_OPEN_NEW_WINDOW_IN_BROWSER],
                  @"Kill switch should return YES when enabled");
}

- (void)testCreateWebView_whenKillSwitchNotSet_flightManagerReturnsNo
{
    MSIDFlightManagerMockProvider *flightProvider = [MSIDFlightManagerMockProvider new];
    flightProvider.boolForKeyContainer = @{};
    MSIDFlightManager.sharedInstance.flightProvider = flightProvider;

    XCTAssertFalse([[MSIDFlightManager sharedInstance] boolForKey:MSID_FLIGHT_DISABLE_OPEN_NEW_WINDOW_IN_BROWSER],
                   @"Kill switch should return NO when not set (feature enabled by default)");
}

@end

#endif
