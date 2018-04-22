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

#import <WebKit/WebKit.h>
#import "MSIDWebviewUIController.h"
#import "MSIDWebviewDelegate.h"

#define DEFAULT_WINDOW_WIDTH 420
#define DEFAULT_WINDOW_HEIGHT 650

static NSRect _CenterRect(NSRect rect1, NSRect rect2)
{
    CGFloat x = rect1.origin.x + ((rect1.size.width - rect2.size.width) / 2);
    CGFloat y = rect1.origin.y + ((rect1.size.height - rect2.size.height) / 2);
    
    rect2.origin.x = x;
    rect2.origin.y = y;
    
    return rect2;
}

@interface MSIDWebviewUIController ( ) <WKNavigationDelegate, NSWindowDelegate>
{
    NSProgressIndicator* _progressIndicator;
}

@end

@implementation MSIDWebviewUIController

- (void)loadView
{
    [self loadView:nil];
}

- (BOOL)loadView:(NSError *)error
{
    (void)error;
    
    if (_webView)
    {
        _webView.navigationDelegate = self;
        return YES;
    }
    
    NSWindow* mainWindow = [NSApp mainWindow];
    NSRect windowRect;
    if (mainWindow)
    {
        windowRect = mainWindow.frame;
    }
    else
    {
        // If we didn't get a main window then center it in the screen
        windowRect = [[NSScreen mainScreen] frame];
    }
    
    // Calculate the center of the current main window so we can position our window in the center of it
    NSRect centerRect = _CenterRect(windowRect, NSMakeRect(0, 0, DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT));
    
    NSWindow* window = [[NSWindow alloc] initWithContentRect:centerRect
                                                   styleMask:NSTitledWindowMask | NSClosableWindowMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:YES];
    [window setDelegate:self];
    [window setAccessibilityIdentifier:@"MSID_SIGN_IN_WINDOW"];
    
    NSView* contentView = window.contentView;
    [contentView setAutoresizesSubviews:YES];
    
    WKWebViewConfiguration *webConfiguration = [WKWebViewConfiguration new];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:contentView.frame configuration:webConfiguration];
    [webView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [webView setNavigationDelegate:self];
    
//    WebView* webView = [[WebView alloc] initWithFrame:contentView.frame];
//    [webView setFrameLoadDelegate:self];
//    [webView setResourceLoadDelegate:self];
//    [webView setPolicyDelegate:self];
//    [webView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [webView setAccessibilityIdentifier:@"MISD_SIGN_IN_WEBVIEW"];
    
    [contentView addSubview:webView];
    
    NSProgressIndicator* progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(DEFAULT_WINDOW_WIDTH / 2 - 16, DEFAULT_WINDOW_HEIGHT / 2 - 16, 32, 32)];
    [progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
    // Keep the item centered in the window even if it's resized.
    [progressIndicator setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin];
    
    // On OS X there's a noticable lag between the window showing and the page loading, so starting with the spinner
    // at least make it looks like something is happening.
    [progressIndicator setHidden:NO];
    [progressIndicator startAnimation:nil];
    
    [contentView addSubview:progressIndicator];
    _progressIndicator = progressIndicator;
    
    _webView = webView;
    self.window = window;
    
    return YES;
}

- (void)dealloc
{
    [_webView setNavigationDelegate:nil];
    _webView = nil;
}

#pragma mark - UIViewController Methods

#pragma mark - Event Handlers

// Authentication was cancelled by the user by closing the window
- (void)windowWillClose:(NSNotification *)notification
{
    (void)notification;
    
    [_delegate webAuthDidCancel];
}

// Fired 2 seconds after a page loads starts to show waiting indicator

- (void)stop:(void (^)(void))completion
{
    //[_webView.mainFrame stopLoading];
    _delegate = nil;
    [self close];
    completion();
}

- (void)startRequest:(NSURLRequest *)request
{
    [self showWindow:nil];
    [self loadRequest:request];
}

- (void)loadRequest:(NSURLRequest *)request
{
    [_webView loadRequest:request];
}

- (void)startSpinner
{
    [_progressIndicator setHidden:NO];
    [_progressIndicator startAnimation:nil];
    [self.window.contentView setNeedsDisplay:YES];
}

- (void)stopSpinner
{
    [_progressIndicator setHidden:YES];
    [_progressIndicator stopAnimation:nil];
}

- (NSWindow *)webviewWindow
{
    return _webView.window;
}

#pragma mark - WKNavigationDelegate Protocol

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if ([_delegate webAuthShouldStartLoadRequest:navigationAction.request])
    {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
    else
    {
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation
{
    [_delegate webAuthDidStartLoad:webView.URL];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{
    [_delegate webAuthDidFinishLoad:webView.URL];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [_delegate webAuthDidFailWithError:error];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [_delegate webAuthDidFailWithError:error];
}

@end

