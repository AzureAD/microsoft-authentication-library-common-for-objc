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

#import "MSIDWebviewUIController.h"

#if !MSID_EXCLUDE_WEBKIT

#define DEFAULT_WINDOW_WIDTH 420
#define DEFAULT_WINDOW_HEIGHT 650

static WKWebViewConfiguration *s_webConfig;

@interface MSIDWebviewUIController ( ) <NSWindowDelegate>
{
    NSProgressIndicator *_loadingIndicator;
}

@end

@implementation MSIDWebviewUIController

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_webConfig = [WKWebViewConfiguration new];
    });
}

- (id)initWithContext:(id<MSIDRequestContext>)context
{
    self = [super init];
    if (self)
    {
        _context = context;
    }
    
    return self;
}

- (BOOL)loadView:(__unused NSError **)error
{
    if (_webView)
    {
        return YES;
    }
    
    // Get UI container to hold the webview
    NSWindow *window = [self obtainSignInWindow];
    NSView *rootView = window.contentView;
    
    // Prepare the WKWebView
    WKWebView *webView = [[WKWebView alloc] initWithFrame:rootView.frame configuration:s_webConfig];
    [webView setAccessibilityIdentifier:@"MSID_SIGN_IN_WEBVIEW"];
    
    // Customize the UI
    [webView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    _loadingIndicator = [self prepareLoadingIndicator];
    self.window = window;
    
    // Append webview and loading indicator
    _webView = webView;
    [rootView addSubview:_webView];
    [rootView addSubview:_loadingIndicator];
    
    return YES;
}

- (void)presentView
{
    [self showWindow:nil];
}

- (void)dismissWebview:(void (^)(void))completion
{
    [self close];
    completion();
}

- (void)showLoadingIndicator
{
    [_loadingIndicator setHidden:NO];
    [_loadingIndicator startAnimation:nil];
    [self.window.contentView setNeedsDisplay:YES];
}

- (void)dismissLoadingIndicator
{
    [_loadingIndicator setHidden:YES];
    [_loadingIndicator stopAnimation:nil];
}

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
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
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
- (void)windowWillClose:(__unused NSNotification *)notification
{
    // If window is closed by us because web auth is completed, we simply return;
    // otherwise cancel the webauth because it is closed by users.
    if (_complete)
    {
        return;
    }
    [self userCancel];
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

// This is reserved for subclass to handle programatic cancellation.
- (void)cancel
{
    // Overridden in subclass with cancel logic
}

- (void)userCancel
{
    // Overridden in subclass with userCancel logic
}


@end

#endif
