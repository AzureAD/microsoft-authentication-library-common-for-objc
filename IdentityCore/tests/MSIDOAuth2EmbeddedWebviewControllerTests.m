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
#import "MSIDWKNavigationActionMock.h"
#import "MSIDAppExtensionUtil.h"
#import "MSIDTestSwizzle.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDConstants.h"

#if !MSID_EXCLUDE_WEBKIT

@interface MSIDOAuth2EmbeddedWebviewControllerTests : XCTestCase

@end

@implementation MSIDOAuth2EmbeddedWebviewControllerTests

- (void)setUp {
    [super setUp];

    // No flight configuration needed — the feature is enabled by default
}

- (void)tearDown {
    MSIDFlightManager.sharedInstance.flightProvider = nil;
    [MSIDTestSwizzle reset];
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

#pragma mark - createWebViewWithConfiguration tests

- (void)testCreateWebView_whenWindowOpenWithHttpsURL_shouldOpenInSystemBrowserAndReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://support.microsoft.com/help"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request
                                                                             navigationType:WKNavigationTypeOther
                                                                                targetFrame:nil];

    __block NSURL *openedURL = nil;
    [MSIDTestSwizzle classMethod:@selector(sharedApplicationOpenURL:)
                           class:[MSIDAppExtensionUtil class]
                           block:(id)^(id obj, NSURL *url)
    {
        openedURL = url;
    }];

    WKWebView *result = [webVC webView:[[WKWebView alloc] init]
         createWebViewWithConfiguration:[[WKWebViewConfiguration alloc] init]
                    forNavigationAction:action
                         windowFeatures:[[WKWindowFeatures alloc] init]];

    XCTAssertNil(result);
    XCTAssertEqualObjects(openedURL.absoluteString, @"https://support.microsoft.com/help");
}

- (void)testCreateWebView_whenLinkActivatedNavigation_shouldNotOpenInBrowserAndReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://support.microsoft.com/help"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request
                                                                             navigationType:WKNavigationTypeLinkActivated
                                                                                targetFrame:nil];

    __block NSURL *openedURL = nil;
    [MSIDTestSwizzle classMethod:@selector(sharedApplicationOpenURL:)
                           class:[MSIDAppExtensionUtil class]
                           block:(id)^(id obj, NSURL *url)
    {
        openedURL = url;
    }];

    WKWebView *result = [webVC webView:[[WKWebView alloc] init]
         createWebViewWithConfiguration:[[WKWebViewConfiguration alloc] init]
                    forNavigationAction:action
                         windowFeatures:[[WKWindowFeatures alloc] init]];

    XCTAssertNil(result);
    XCTAssertNil(openedURL, @"Link-activated navigations should not open in browser from createWebView — decidePolicyForNavigationAction handles them");
}

- (void)testCreateWebView_whenWindowOpenWithHttpURL_shouldNotOpenInBrowserAndReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://insecure.example.com"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request
                                                                             navigationType:WKNavigationTypeOther
                                                                                targetFrame:nil];

    __block NSURL *openedURL = nil;
    [MSIDTestSwizzle classMethod:@selector(sharedApplicationOpenURL:)
                           class:[MSIDAppExtensionUtil class]
                           block:(id)^(id obj, NSURL *url)
    {
        openedURL = url;
    }];

    WKWebView *result = [webVC webView:[[WKWebView alloc] init]
         createWebViewWithConfiguration:[[WKWebViewConfiguration alloc] init]
                    forNavigationAction:action
                         windowFeatures:[[WKWindowFeatures alloc] init]];

    XCTAssertNil(result);
    XCTAssertNil(openedURL, @"Insecure http URLs should not be opened in the system browser");
}

- (void)testCreateWebView_whenWindowOpenWithCustomScheme_shouldOpenInSystemBrowserAndReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"msauth://com.contoso.app/callback"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request
                                                                             navigationType:WKNavigationTypeOther
                                                                                targetFrame:nil];

    __block NSURL *openedURL = nil;
    [MSIDTestSwizzle classMethod:@selector(sharedApplicationOpenURL:)
                           class:[MSIDAppExtensionUtil class]
                           block:(id)^(id obj, NSURL *url)
    {
        openedURL = url;
    }];

    WKWebView *result = [webVC webView:[[WKWebView alloc] init]
         createWebViewWithConfiguration:[[WKWebViewConfiguration alloc] init]
                    forNavigationAction:action
                         windowFeatures:[[WKWindowFeatures alloc] init]];

    XCTAssertNil(result);
    XCTAssertEqualObjects(openedURL.absoluteString, @"msauth://com.contoso.app/callback");
}

- (void)testCreateWebView_whenWindowOpenWithNilURL_shouldNotOpenInBrowserAndReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:nil
                                                                             navigationType:WKNavigationTypeOther
                                                                                targetFrame:nil];

    __block NSURL *openedURL = nil;
    [MSIDTestSwizzle classMethod:@selector(sharedApplicationOpenURL:)
                           class:[MSIDAppExtensionUtil class]
                           block:(id)^(id obj, NSURL *url)
    {
        openedURL = url;
    }];

    WKWebView *result = [webVC webView:[[WKWebView alloc] init]
         createWebViewWithConfiguration:[[WKWebViewConfiguration alloc] init]
                    forNavigationAction:action
                         windowFeatures:[[WKWindowFeatures alloc] init]];

    XCTAssertNil(result);
    XCTAssertNil(openedURL, @"Nil URL should not trigger system browser open");
}

- (void)testCreateWebView_whenWindowOpenWithSchemelessURL_shouldNotOpenInBrowserAndReturnNil
{
    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    // A relative/scheme-less URL has a nil scheme; it should not be opened in the system browser.
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"/relative/path"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request
                                                                             navigationType:WKNavigationTypeOther
                                                                                targetFrame:nil];

    __block NSURL *openedURL = nil;
    [MSIDTestSwizzle classMethod:@selector(sharedApplicationOpenURL:)
                           class:[MSIDAppExtensionUtil class]
                           block:(id)^(id obj, NSURL *url)
    {
        openedURL = url;
    }];

    WKWebView *result = [webVC webView:[[WKWebView alloc] init]
         createWebViewWithConfiguration:[[WKWebViewConfiguration alloc] init]
                    forNavigationAction:action
                         windowFeatures:[[WKWindowFeatures alloc] init]];

    XCTAssertNil(result);
    XCTAssertNil(openedURL, @"Schemeless/relative URLs should not be opened in the system browser");
}

- (void)testCreateWebView_whenFlightDisabled_shouldNotOpenInBrowserAndReturnNil
{
    // Enable the kill-switch flight to disable the feature
    MSIDFlightManagerMockProvider *flightProvider = [MSIDFlightManagerMockProvider new];
    flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_OPEN_NEW_WINDOW_IN_BROWSER: @YES};
    MSIDFlightManager.sharedInstance.flightProvider = flightProvider;

    MSIDOAuth2EmbeddedWebviewController *webVC = [self createTestWebviewController];
    XCTAssertNotNil(webVC);

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://support.microsoft.com/help"]];
    MSIDWKNavigationActionMock *action = [[MSIDWKNavigationActionMock alloc] initWithRequest:request
                                                                             navigationType:WKNavigationTypeOther
                                                                                targetFrame:nil];

    __block NSURL *openedURL = nil;
    [MSIDTestSwizzle classMethod:@selector(sharedApplicationOpenURL:)
                           class:[MSIDAppExtensionUtil class]
                           block:(id)^(id obj, NSURL *url)
    {
        openedURL = url;
    }];

    WKWebView *result = [webVC webView:[[WKWebView alloc] init]
         createWebViewWithConfiguration:[[WKWebViewConfiguration alloc] init]
                    forNavigationAction:action
                         windowFeatures:[[WKWindowFeatures alloc] init]];

    XCTAssertNil(result);
    XCTAssertNil(openedURL, @"When flight is disabled, URLs should not be opened in the system browser");
}

@end

#endif
