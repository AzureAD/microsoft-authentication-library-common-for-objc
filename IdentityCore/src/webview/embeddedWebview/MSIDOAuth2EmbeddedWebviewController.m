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
#import "MSIDError.h"
#import "MSIDChallengeHandler.h"
#import "MSIDAuthority.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDNotifications.h"

#if !MSID_EXCLUDE_WEBKIT

@implementation MSIDOAuth2EmbeddedWebviewController
{
    NSURL *_endURL;
    MSIDWebUICompletionHandler _completionHandler;
    NSDictionary<NSString *, NSString *> *_customHeaders;
    
    NSLock *_completionLock;
    NSTimer *_spinnerTimer; // Used for managing the activity spinner
}



- (id)initWithStartURL:(NSURL *)startURL
                endURL:(NSURL *)endURL
               webview:(WKWebView *)webview
         customHeaders:(NSDictionary<NSString *, NSString *> *)customHeaders
               context:(id<MSIDRequestContext>)context
{
    if (!startURL)
    {
        MSID_LOG_WARN(context, @"Attemped to start with nil URL");
        return nil;
    }
    
    if (!endURL)
    {
        MSID_LOG_WARN(context, @"Attemped to start with nil endURL");
        return nil;
    }
    
    self = [super initWithContext:context];
    
    if (self)
    {
        self.webView = webview;
        _startURL = startURL;
        _endURL = endURL;
        _customHeaders = customHeaders;
        
        _completionLock = [[NSLock alloc] init];
        self.complete = NO;
    }
    
    return self;
}

-(void)dealloc
{
    [self.webView setNavigationDelegate:nil];
    self.webView = nil;
}

- (void)startWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    if (!completionHandler)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"CompletionHandler cannot be nil for interactive session.", nil, nil, nil, self.context.correlationId, nil);
        [MSIDNotifications notifyWebAuthDidFailWithError:error];
        [self endWebAuthWithURL:nil error:error];
        return;
    }
    
    // Save the completion block
    _completionHandler = [completionHandler copy];
    
    dispatch_async(dispatch_get_main_queue(), ^{

        NSError *error = nil;
        [self loadView:&error];
        if (error)
        {
            [self endWebAuthWithURL:nil error:error];
            return;
        }
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:_startURL];
        for (NSString *headerKey in _customHeaders)
            [request addValue:_customHeaders[headerKey] forHTTPHeaderField:headerKey];
        
        [self startRequest:request];
    });
}

- (void)cancel
{
    MSID_LOG_INFO(self.context, @"Cancel Web Auth...");
    
    // End web auth with error
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorSessionCanceledProgrammatically, @"Authorization session was cancelled programatically.", nil, nil, nil, self.context.correlationId, nil);
    [self endWebAuthWithURL:nil error:error];
}

- (void)userCancel
{
    MSID_LOG_INFO(self.context, @"Cancel Web Auth...");
    
    // End web auth with error
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"User cancelled the authorization session.", nil, nil, nil, self.context.correlationId, nil);
    [self endWebAuthWithURL:nil error:error];
}

- (BOOL)loadView:(NSError **)error
{
    // create and load the view if not provided
    BOOL result = [super loadView:error];
    
    self.webView.navigationDelegate = self;
    
    return result;
}

- (BOOL)endWebAuthWithURL:(NSURL *)endURL
                    error:(NSError *)error
{
    self.complete = YES;
    
    if (error)
    {
        [MSIDNotifications notifyWebAuthDidFailWithError:error];
    }
    else
    {
        [MSIDNotifications notifyWebAuthDidCompleteWithURL:endURL];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissWebview:^{[self dispatchCompletionBlock:endURL error:error];}];
    });
    
    return YES;
}

- (void)dispatchCompletionBlock:(NSURL *)url error:(NSError *)error
{
    // NOTE: It is possible that competition between a successful completion
    //       and the user cancelling the authentication dialog can
    //       occur causing this method to be called twice. The competition
    //       cannot be blocked at its root, and so this method must
    //       be resilient to this condition and should not generate
    //       two callbacks.
    [_completionLock lock];
    
    [MSIDChallengeHandler resetHandlers];
    
    if ( _completionHandler )
    {
        MSIDWebUICompletionHandler completionHandler = _completionHandler;
        _completionHandler = nil;
        
        dispatch_async( dispatch_get_main_queue(), ^{
            completionHandler(url, error);
        });
    }
    
    [_completionLock unlock];
}

- (void)startRequest:(NSURLRequest *)request
{
    [self loadRequest:request];
    [self presentView];
}

- (void)loadRequest:(NSURLRequest *)request
{
    [self.webView loadRequest:request];
}

#pragma mark - WKNavigationDelegate Protocol

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *requestURL = navigationAction.request.URL;
    
    MSID_LOG_VERBOSE(self.context, @"-decidePolicyForNavigationAction host: %@", [MSIDAuthority isKnownHost:requestURL] ? requestURL.host : @"unknown host");
    MSID_LOG_VERBOSE_PII(self.context, @"-decidePolicyForNavigationAction host: %@", requestURL.host);
    
    [MSIDNotifications notifyWebAuthDidStartLoad:requestURL];
    
    [self decidePolicyForNavigationAction:navigationAction webview:webView decisionHandler:decisionHandler];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation
{
    if (!self.loading)
    {
        self.loading = YES;
        if (_spinnerTimer)
        {
            [_spinnerTimer invalidate];
        }
        _spinnerTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                         target:self
                                                       selector:@selector(onStartLoadingIndicator:)
                                                       userInfo:nil
                                                        repeats:NO];
        [_spinnerTimer setTolerance:0.3];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{
    NSURL *url = webView.URL;
    MSID_LOG_VERBOSE(self.context, @"-didFinishNavigation host: %@", [MSIDAuthority isKnownHost:url] ? url.host : @"unknown host");
    MSID_LOG_VERBOSE_PII(self.context, @"-didFinishNavigation host: %@", url.host);
    
    [MSIDNotifications notifyWebAuthDidFinishLoad:url];
    
    [self stopSpinner];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [self webAuthFailWithError:error];
}

- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(ChallengeCompletionHandler)completionHandler
{
    NSString *authMethod = [challenge.protectionSpace.authenticationMethod lowercaseString];
    
    MSID_LOG_VERBOSE(self.context,
                     @"%@ - %@. Previous challenge failure count: %ld",
                     @"webView:didReceiveAuthenticationChallenge:completionHandler",
                     authMethod, (long)challenge.previousFailureCount);
    
    [MSIDChallengeHandler handleChallenge:challenge
                                  webview:webView
                                  context:self.context
                        completionHandler:completionHandler];
}

- (void)completeWebAuthWithURL:(NSURL *)endURL
{
    MSID_LOG_INFO(self.context, @"-completeWebAuthWithURL: %@", [MSIDAuthority isKnownHost:endURL] ? endURL.host : @"unknown host");
    MSID_LOG_INFO_PII(self.context, @"-completeWebAuthWithURL: %@", endURL);
    
    [self endWebAuthWithURL:endURL error:nil];
}

// Authentication failed somewhere
- (void)webAuthFailWithError:(NSError *)error
{
    if (self.complete)
    {
        return;
    }
    
    if ([error.domain isEqualToString:NSURLErrorDomain] && NSURLErrorCancelled == error.code)
    {
        //This is a common error that webview generates and could be ignored.
        //See this thread for details: https://discussions.apple.com/thread/1727260
        return;
    }
    
    [self stopSpinner];
    
    // WebKitErrorDomain includes WebKitErrorFrameLoadInterruptedByPolicyChange and
    // other web page errors like JavaUnavailable etc. Ignore them here.
    if([error.domain isEqualToString:@"WebKitErrorDomain"])
    {
        return;
    }
    
    MSID_LOG_ERROR(self.context, @"-webAuthFailWithError error code %ld", (long)error.code);
    MSID_LOG_ERROR_PII(self.context, @"-webAuthFailWithError: %@", error);
    
    [self endWebAuthWithURL:nil error:error];
}

- (void)decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                                webview:(WKWebView *)webView
                        decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *requestURL = navigationAction.request.URL;
    NSString *requestURLString = [requestURL.absoluteString lowercaseString];
    
    // Stop at the end URL.
    if ([requestURLString hasPrefix:[_endURL.absoluteString lowercaseString]])
    {
        NSURL *url = navigationAction.request.URL;
        [self completeWebAuthWithURL:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    if ([requestURLString isEqualToString:@"about:blank"])
    {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    
    // redirecting to non-https url is not allowed
    if (![requestURL.scheme.lowercaseString isEqualToString:@"https"])
    {
        MSID_LOG_INFO(self.context, @"Server is redirecting to a non-https url");
        
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerNonHttpsRedirect, @"The server has redirected to a non-https url.", nil, nil, nil, self.context.correlationId, nil);
        [self endWebAuthWithURL:nil error:error];
        
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - Loading Indicator

- (void)onStartLoadingIndicator:(__unused id)sender
{
    if (self.loading)
    {
        [self showLoadingIndicator];
    }
    _spinnerTimer = nil;
}

- (void)stopSpinner
{
    if (!self.loading)
    {
        return;
    }
    
    self.loading = NO;
    if (_spinnerTimer)
    {
        [_spinnerTimer invalidate];
        _spinnerTimer = nil;
    }
    
    [self dismissLoadingIndicator];
}

@end

#endif
