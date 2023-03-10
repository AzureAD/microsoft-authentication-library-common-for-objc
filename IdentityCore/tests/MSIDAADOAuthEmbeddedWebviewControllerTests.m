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
#import "MSIDWKNavigationActionMock.h"

#if !MSID_EXCLUDE_WEBKIT

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

@end

#endif
