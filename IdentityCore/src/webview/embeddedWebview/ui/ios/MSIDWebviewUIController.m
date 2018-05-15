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
#import "UIApplication+MSIDExtensions.h"

@interface MSIDWebviewUIController ( )
{
    UIActivityIndicatorView *_laodingIndicator;
    __weak UIViewController *_parentController;
    UIModalPresentationStyle _presentationType;
}

@end

@implementation MSIDWebviewUIController

- (id)initWithContext:(id<MSIDRequestContext>)context
{
    self = [super init];
    if (self)
    {
        _context = context;
    }
    
    return self;
}

- (BOOL)createAndLoadView:(NSError **)error;
{
    // Get UI container to hold the webview
    // Need parent controller to proceed
    if (![self obtainParentController])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorNoMainViewController, @"The Application does not have a current ViewController", nil, nil, nil, _context.correlationId, nil);
        }
        return NO;
    }
    UIView *rootView = [self view];
    [rootView setFrame:[[UIScreen mainScreen] bounds]];
    [rootView setAutoresizesSubviews:YES];
    [rootView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    
    // Prepare the WKWebView
    WKWebViewConfiguration *webConfiguration = [WKWebViewConfiguration new];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:rootView.frame configuration:webConfiguration];
    [webView setAccessibilityIdentifier:@"MSID_SIGN_IN_WEBVIEW"];
    
    // Customize the UI
    [webView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self setupCancelButton];
    _laodingIndicator = [self prepareLoadingIndicator:rootView];
    self.view = rootView;
    
    // Append webview and loading indicator
    _webView = webView;
    [rootView addSubview:_webView];
    [rootView addSubview:_laodingIndicator];
    
    return YES;
}

- (void)presentView
{
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self];
    [navController setModalPresentationStyle:_presentationType];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_parentController presentViewController:navController animated:YES completion:nil];
    });
}

- (void)dismissWebview:(void (^)(void))completion
{
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
}

- (void)showLoadingIndicator
{
    [_laodingIndicator setHidden:NO];
    [_laodingIndicator startAnimating];
}

- (void)dismissLoadingIndicator
{
    [_laodingIndicator setHidden:YES];
    [_laodingIndicator stopAnimating];
}

- (BOOL)obtainParentController
{
    if (_parentController)
    {
        return YES;
    }
    
    _parentController = [UIApplication msidCurrentViewController];
    
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
    [self cancel];
}

- (UIActivityIndicatorView *)prepareLoadingIndicator:(UIView *)rootView
{
    UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [loadingIndicator setColor:[UIColor blackColor]];
    [loadingIndicator setCenter:rootView.center];
    return loadingIndicator;
}

- (void)cancel
{
    // Overridden in subclass with cancel logic
}

@end
