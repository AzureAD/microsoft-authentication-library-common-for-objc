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
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDNotifications.h"

#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryUIEvent.h"
#import "MSIDTelemetryEventStrings.h"

#if !MSID_EXCLUDE_WEBKIT

@implementation MSIDOAuth2EmbeddedWebviewController
{
    NSURL *_endURL;
    MSIDWebUICompletionHandler _completionHandler;
    NSDictionary<NSString *, NSString *> *_customHeaders;
    
    NSLock *_completionLock;
    NSTimer *_spinnerTimer; // Used for managing the activity spinner
    
    id<MSIDRequestContext> _context;
    
    NSString *_telemetryRequestId;
    MSIDTelemetryUIEvent *_telemetryEvent;
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

        _context = context;
        
        self.complete = NO;
    }
    
    return self;
}

-(void)dealloc
{
    if ([self.webView.navigationDelegate isEqual:self])
    {
        [self.webView setNavigationDelegate:nil];
    }
    
    self.webView = nil;
}

- (void)startWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    if (!completionHandler)
    {
        MSID_LOG_WARN(_context, @"CompletionHandler cannot be nil for interactive session.");
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
    MSID_LOG_INFO(self.context, @"Canceled web view contoller.");
    
    // End web auth with error
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorSessionCanceledProgrammatically, @"Authorization session was cancelled programatically.", nil, nil, nil, self.context.correlationId, nil);
    
    [_telemetryEvent setIsCancelled:YES];
    [self endWebAuthWithURL:nil error:error];
}

- (void)userCancel
{
    MSID_LOG_INFO(self.context, @"Canceled web view contoller.");
    
    // End web auth with error
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"User cancelled the authorization session.", nil, nil, nil, self.context.correlationId, nil);
    
    [_telemetryEvent setIsCancelled:YES];
    [self endWebAuthWithURL:nil error:error];
}

- (BOOL)loadView:(NSError **)error
{
    // create and load the view if not provided
    BOOL result = [super loadView:error];
    
    self.webView.navigationDelegate = self;
    
    return result;
}

- (void)endWebAuthWithURL:(NSURL *)endURL
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
    
    [[MSIDTelemetry sharedInstance] stopEvent:_telemetryRequestId event:_telemetryEvent];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        MSID_LOG_INFO(self.context, @"Dismissed web view contoller.");
        [self dismissWebview:^{[self dispatchCompletionBlock:endURL error:error];}];
    });
    
    return;
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
        
        completionHandler(url, error);
    }
    
    [_completionLock unlock];
}

- (void)startRequest:(NSURLRequest *)request
{
    MSID_LOG_INFO(self.context, @"Presenting web view contoller.");
    
    _telemetryRequestId = [_context telemetryRequestId];
    [[MSIDTelemetry sharedInstance] startEvent:_telemetryRequestId eventName:MSID_TELEMETRY_EVENT_UI_EVENT];
    _telemetryEvent = [[MSIDTelemetryUIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_UI_EVENT
                                                         context:_context];

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
    __auto_type isKnown = [MSIDAADNetworkConfiguration.defaultConfiguration isAADPublicCloud:requestURL.host];
    
    MSID_LOG_NO_PII(MSIDLogLevelVerbose, nil, self.context, @"-decidePolicyForNavigationAction host: %@", isKnown ? requestURL.host : @"unknown host");
    MSID_LOG_PII(MSIDLogLevelVerbose, nil, self.context, @"-decidePolicyForNavigationAction host: %@", requestURL.host);
    
    [MSIDNotifications notifyWebAuthDidStartLoad:requestURL];
    
    [self decidePolicyForNavigationAction:navigationAction webview:webView decisionHandler:decisionHandler];
}

- (void)webView:(__unused WKWebView *)webView didStartProvisionalNavigation:(null_unspecified __unused WKNavigation *)navigation
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

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified __unused WKNavigation *)navigation
{
    NSURL *url = webView.URL;
    __auto_type isKnown = [MSIDAADNetworkConfiguration.defaultConfiguration isAADPublicCloud:url.host];
    
    MSID_LOG_NO_PII(MSIDLogLevelVerbose, nil, self.context, @"-didFinishNavigation host: %@", isKnown ? url.host : @"unknown host");
    MSID_LOG_PII(MSIDLogLevelVerbose, nil, self.context, @"-didFinishNavigation host: %@", url.host);
    
    [MSIDNotifications notifyWebAuthDidFinishLoad:url];
    
    [self stopSpinner];
}

- (void)webView:(__unused WKWebView *)webView didFailNavigation:(null_unspecified __unused WKNavigation *)navigation withError:(NSError *)error
{
    [self webAuthFailWithError:error];
}

- (void)webView:(__unused WKWebView *)webView didFailProvisionalNavigation:(__unused WKNavigation *)navigation withError:(NSError *)error
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
    __auto_type isKnown = [MSIDAADNetworkConfiguration.defaultConfiguration isAADPublicCloud:endURL.host];
    
    MSID_LOG_NO_PII(MSIDLogLevelInfo, nil, self.context, @"-completeWebAuthWithURL: %@", isKnown ? endURL.host : @"unknown host");
    MSID_LOG_PII(MSIDLogLevelInfo, nil, self.context, @"-completeWebAuthWithURL: %@", [endURL msidPIINullifiedURL]);
    
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
    
    MSID_LOG_NO_PII(MSIDLogLevelError, nil, self.context, @"-webAuthFailWithError error code %ld", (long)error.code);
    MSID_LOG_PII(MSIDLogLevelError, nil, self.context, @"-webAuthFailWithError: %@", error);
    
    [self endWebAuthWithURL:nil error:error];
}

- (void)decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                                webview:(__unused WKWebView *)webView
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
