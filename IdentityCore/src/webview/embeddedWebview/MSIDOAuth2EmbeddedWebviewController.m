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

#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryUIEvent.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDWebviewUIController.h"
#import "MSIDError.h"
#import "MSIDWebOAuth2Response.h"
#import "MSIDWebviewAuthorization.h"

#if TARGET_OS_IPHONE
#import "UIApplication+MSIDExtensions.h"
#else
#define DEFAULT_WINDOW_WIDTH 420
#define DEFAULT_WINDOW_HEIGHT 650
#endif

@implementation MSIDOAuth2EmbeddedWebviewController
{
    NSURL *_startUrl;
    NSURL *_endUrl;
    id<MSIDRequestContext> _context;
    void (^_completionHandler)(MSIDWebOAuth2Response *response, NSError *error);
    
    NSLock *_completionLock;
    
#if TARGET_OS_IPHONE
    UIActivityIndicatorView *_laodingIndicator;
#else
    NSProgressIndicator *_laodingIndicator;
#endif
}

- (id)initWithStartUrl:(NSURL *)startUrl
                endURL:(NSURL *)endUrl
               webview:(WKWebView *)webview
               context:(id<MSIDRequestContext>)context
            completion:(MSIDWebUICompletionHandler)completionHandler
{
    self = [super init];
    
    if (self)
    {
        _startUrl = startUrl;
        _endUrl = endUrl;
        _webView = webview;
        _context  = context;
        
        // Save the completion block
        _completionHandler = [completionHandler copy];
        
        _completionLock = [[NSLock alloc] init];
    }
    
    return self;
}

-(void)dealloc
{
    [_webView setNavigationDelegate:nil];
    _webView = nil;
}

- (void)start
{
    // If we're not on the main thread when trying to kick up the UI then
    // dispatch over to the main thread.
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self start];
        });
        return;
    }
    
    [self loadView];
    [self startRequest:[[NSMutableURLRequest alloc] initWithURL:_startUrl]];
}

- (void)cancel
{
    //TODO
}

- (void)loadView
{
    // Just need to hijack the delegate and return if webview is passed in.
    if (_webView)
    {
        _webView.navigationDelegate = self;
        return;
    }
    
    // Create Webview
    // Get UI container to hold the webview
#if TARGET_OS_IPHONE
    // Need parent controller to proceed
    if (![self obtainParentController])
    {
        return;
    }
    
    UIView *rootView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [rootView setAutoresizesSubviews:YES];
    [rootView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
#else
    NSWindow *window = [self obtainSignInWindow];
    NSView *rootView = window.contentView;
#endif
    
    // Prepare the WKWebView
    WKWebViewConfiguration *webConfiguration = [WKWebViewConfiguration new];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:rootView.frame configuration:webConfiguration];
    [webView setNavigationDelegate:self];
    [webView setAccessibilityIdentifier:@"MSID_SIGN_IN_WEBVIEW"];
    
    // Customize the UI
#if TARGET_OS_IPHONE
    [webView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self setupCancelButton];
    _laodingIndicator = [self prepareLoadingIndicator:rootView];
    self.view = rootView;
#else
    [webView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    _laodingIndicator = [self prepareLoadingIndicator];
    self.window = window;
#endif
    
    // Append webview and loading indicator
    _webView = webView;
    [rootView addSubview:_webView];
    [rootView addSubview:_laodingIndicator];
}

- (void)cancelWebAuth
{
    // Dispatch the completion block
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"The user has cancelled the authorization.", nil, nil, nil, nil, nil);
    [self endWebAuthenticationWithError:error orURL:nil];
}

- (BOOL)endWebAuthenticationWithError:(NSError *) error
                                orURL:(NSURL*)endURL
{
    [self dismidssWebview:^{[self dispatchCompletionBlock:error URL:endURL];}];
    
    return YES;
}

- (void)dismidssWebview:(void (^)(void))completion
{
#if TARGET_OS_IPHONE
    //if webview is created by us, dismiss and then complete and return;
    //otherwise just complete and return.
    if (_parentController)
    {
        [_parentController dismissViewControllerAnimated:YES completion:completion];
    }
    else
    {
        completion();
    }
    
    _parentController = nil;
#else
    [self close];
    completion();
#endif
}

- (void)dispatchCompletionBlock:(NSError *)error URL:(NSURL *)url
{
    // NOTE: It is possible that competition between a successful completion
    //       and the user cancelling the authentication dialog can
    //       occur causing this method to be called twice. The competition
    //       cannot be blocked at its root, and so this method must
    //       be resilient to this condition and should not generate
    //       two callbacks.
    [_completionLock lock];
    
    if ( _completionHandler )
    {
        void (^completionHandler)(MSIDWebOAuth2Response *response, NSError *error) = _completionHandler;
        _completionHandler = nil;
        
        MSIDWebOAuth2Response *response = nil;
        NSError *systemError = error;
        if (!systemError)
        {
            response = [MSIDWebviewAuthorization parseUrlResponse:url context:_context error:&systemError];
        }
        
        dispatch_async( dispatch_get_main_queue(), ^{
            completionHandler(response, error);
        });
    }
    
    [_completionLock unlock];
}

- (void)startRequest:(NSURLRequest *)request
{
    [self loadRequest:request];
    
#if TARGET_OS_IPHONE
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self];
    
    if (_fullScreen)
    {
        [navController setModalPresentationStyle:UIModalPresentationFullScreen];
    }
    else
    {
        [navController setModalPresentationStyle:UIModalPresentationFormSheet];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_parentController presentViewController:navController animated:YES completion:nil];
    });
#else
    [self showWindow:nil];
#endif
}

- (void)loadRequest:(NSURLRequest*)request
{
    [_webView loadRequest:request];
}

#pragma mark - WKNavigationDelegate Protocol

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *requestUrl = navigationAction.request.URL;
    
    // Stop at the end URL.
    if ([[requestUrl.absoluteString lowercaseString] hasPrefix:[_endUrl.absoluteString lowercaseString]] ||
        [[[requestUrl scheme] lowercaseString] isEqualToString:@"msauth"])
    {
        NSURL *url = navigationAction.request.URL;
        [self webAuthCompleteWithURL:url];
        
        // Tell the web view that this URL should not be loaded.
        decisionHandler(WKNavigationActionPolicyCancel);
    }
    else
    {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation
{
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [self webAuthFailWithError:error];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [self webAuthFailWithError:error];
}

// Authentication completed at the end URL
- (void)webAuthCompleteWithURL:(NSURL *)endURL
{
    [self endWebAuthenticationWithError:nil orURL:endURL];
}

// Authentication failed somewhere
- (void)webAuthFailWithError:(NSError *)error
{
    // Ignore WebKitError 102 for OAuth 2.0 flow.
    if ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102)
    {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{ [self endWebAuthenticationWithError:error orURL:nil]; });
}

#pragma mark - iOS specific

#if TARGET_OS_IPHONE
- (BOOL)obtainParentController
{
    if (_parentController)
    {
        return YES;
    }

    _parentController = [UIApplication msalCurrentViewController];
    
    return (_parentController != nil);
}

- (void)setupCancelButton
{
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                  target:self
                                                                                  action:@selector(onCancel:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
}

// Authentication was cancelled by the user
- (IBAction)onCancel:(id)sender
{
    (void)sender;
    [self cancelWebAuth];
}

- (UIActivityIndicatorView *)prepareLoadingIndicator:(UIView *)rootView
{
    UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [loadingIndicator setColor:[UIColor blackColor]];
    [loadingIndicator setCenter:rootView.center];
    return loadingIndicator;
}
#endif

#pragma mark - Mac specific

#if !TARGET_OS_IPHONE
- (NSWindow *)obtainSignInWindow
{
    NSWindow *mainWindow = [NSApp mainWindow];
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
    NSRect centerRect = [self getCenterRect:windowRect rect2:NSMakeRect(0, 0, DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT)];
    
    NSWindow *window = [[NSWindow alloc] initWithContentRect:centerRect
                                                   styleMask:NSTitledWindowMask | NSClosableWindowMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:YES];
    [window setDelegate:self];
    [window setAccessibilityIdentifier:@"MSID_SIGN_IN_WINDOW"];
    [window.contentView setAutoresizesSubviews:YES];
    
    return window;
}

- (NSRect)getCenterRect:(NSRect)rect1
                  rect2:(NSRect)rect2
{
    CGFloat x = rect1.origin.x + ((rect1.size.width - rect2.size.width) / 2);
    CGFloat y = rect1.origin.y + ((rect1.size.height - rect2.size.height) / 2);
    
    rect2.origin.x = x;
    rect2.origin.y = y;
    
    return rect2;
}

// Authentication was cancelled by the user by closing the window
- (void)windowWillClose:(NSNotification *)notification
{
    (void)notification;
    
    [self cancelWebAuth];
}

- (NSProgressIndicator *)prepareLoadingIndicator
{
    NSProgressIndicator *loadingIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(DEFAULT_WINDOW_WIDTH / 2 - 16, DEFAULT_WINDOW_HEIGHT / 2 - 16, 32, 32)];
    [loadingIndicator setStyle:NSProgressIndicatorSpinningStyle];
    // Keep the item centered in the window even if it's resized.
    [loadingIndicator setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin];
    
    // On OS X there's a noticable lag between the window showing and the page loading, so starting with the spinner
    // at least make it looks like something is happening.
    [loadingIndicator setHidden:NO];
    [loadingIndicator startAnimation:nil];

    return loadingIndicator;
}

#endif

@end

