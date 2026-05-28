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
#import "MSIDMainThreadUtil.h"
#import "MSIDAppExtensionUtil.h"
#import "MSIDFlightManager.h"
#import "MSIDWebviewNavigationDecision.h"
#import "MSIDOnboardingBlobBuilder.h"
#import "MSIDOnboardingBlobFieldKeys.h"
#import "MSIDWebAuthNUtil.h"

#if !MSID_EXCLUDE_WEBKIT

@interface MSIDOAuth2EmbeddedWebviewController()

@property (nonatomic) NSDictionary<NSString *, NSString *> *customHeaders;

@end

@implementation MSIDOAuth2EmbeddedWebviewController
{
    NSURL *_endURL;
    MSIDWebUICompletionHandler _completionHandler;

    NSLock *_completionLock;
    NSTimer *_spinnerTimer; // Used for managing the activity spinner
    
    id<MSIDRequestContext> _context;
    
    NSString *_telemetryRequestId;
#if !EXCLUDE_FROM_MSALCPP
    MSIDTelemetryUIEvent *_telemetryEvent;
#endif
}

// Backed by readonly properties declared in the public header.
@synthesize onboardingStrongAuthSetupStarted = _onboardingStrongAuthSetupStarted;
@synthesize onboardingMdmEnrollmentStarted = _onboardingMdmEnrollmentStarted;

#if AD_BROKER
NSString *const SSO_EXTENSION_USER_DEFAULTS_KEY = @"group.com.microsoft.azureauthenticator.sso";
NSString *const CAMERA_CONSENT_PROMPT_SUPPRESS_KEY = @"Microsoft.Broker.Feature.suppress_camera_consent";
NSString *const SDM_CAMERA_CONSENT_PROMPT_SUPPRESS_KEY = @"Microsoft.Broker.Feature.sdm_suppress_camera_consent";
#endif

- (id)initWithStartURL:(NSURL *)startURL
                endURL:(NSURL *)endURL
               webview:(WKWebView *)webview
         customHeaders:(NSDictionary<NSString *, NSString *> *)customHeaders
        platfromParams:(MSIDWebViewPlatformParams *)platformParams
               context:(id<MSIDRequestContext>)context
{
    if (!startURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,context, @"Attempted to start with nil URL");
        return nil;
    }
    
    if (!endURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,context, @"Attempted to start with nil endURL");
        return nil;
    }
    
    self = [super initWithContext:context
                   platformParams:platformParams];

    if (self)
    {
        self.webView = webview;
        _startURL = startURL;
        _endURL = endURL;
        _customHeaders = customHeaders;
        
        _completionLock = [[NSLock alloc] init];

        _context = context;
        
        _complete = NO;
        
        // isMobileOnboardingEnabled starts as NO; it is dynamically set to YES
        // when the server issues msauth://enroll (server-driven enablement).
    }
    
    return self;
}

-(void)dealloc
{
    if ([self.webView.navigationDelegate isEqual:self])
    {
        [self.webView setNavigationDelegate:nil];
    }
    if ([self.webView.UIDelegate isEqual:self])
    {
        [self.webView setUIDelegate:nil];
    }
    
    self.webView = nil;
}

- (void)startWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    if (!completionHandler)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,_context, @"CompletionHandler cannot be nil for interactive session.");
        return;
    }
    
    // Save the completion block
    _completionHandler = [completionHandler copy];
    
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        
        NSError *error = nil;
        [self loadView:&error];
        if (error)
        {
            [self endWebAuthWithURL:nil error:error];
            return;
        }
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.startURL];
        for (NSString *headerKey in self.customHeaders)
            [request addValue:self.customHeaders[headerKey] forHTTPHeaderField:headerKey];
        
        [self startRequest:request];
        
    }];
}

- (void)cancelProgrammatically
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Canceled web view controller.");
    
    // End web auth with error
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorSessionCanceledProgrammatically, @"Authorization session was cancelled programmatically.", nil, nil, nil, self.context.correlationId, nil, NO);
    
    CONDITIONAL_UI_EVENT_SET_IS_CANCELLED(_telemetryEvent, YES);
    [self endWebAuthWithURL:nil error:error];
}

- (void)dismiss
{
    [self cancelProgrammatically];
}

- (void)userCancel
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Canceled web view controller by the user.");
    
    // End web auth with error
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"User cancelled the authorization session.", nil, nil, nil, self.context.correlationId, nil, NO);
    
    CONDITIONAL_UI_EVENT_SET_IS_CANCELLED(_telemetryEvent, YES);
    [self endWebAuthWithURL:nil error:error];
}

- (BOOL)loadView:(NSError *__autoreleasing*)error
{
    // create and load the view if not provided
    BOOL result = [super loadView:error];
    
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;

#if !EXCLUDE_FROM_MSALCPP
#if DEBUG
    // Allows debugging using Safari Web Tools when physical device connected to Mac
    if (@available(iOS 16.4, macOS 13.3, *)) {
        [self.webView setInspectable:YES];
    }
#endif
#endif
    
    return result;
}

- (void)endWebAuthWithURL:(NSURL *)endURL
                    error:(NSError *)error
{
    if (self.complete)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"endWebAuthWithURL called for a second time, disregarding");
        return;
    }
    self.complete = YES;
    
    // Record the terminal onboarding step on the shared builder
    if (_onboardingBlobBuilder && [MSIDWebAuthNUtil amIRunningInExtension])
    {
        [self finalizeOnboardingTelemetry:endURL error:error];
        _onboardingBlobBuilder = nil;
    }

    BOOL enableSpinnerFix = [MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_SPINNER_FIX];
    
    if (enableSpinnerFix)
    {
        [self stopSpinner];
    }
    
    if (error)
    {
        // TODO: https://identitydivision.visualstudio.com/Engineering/_workitems/edit/3539094
        [MSIDNotifications notifyWebAuthDidFailWithError:error];
    }
    else
    {
        [MSIDNotifications notifyWebAuthDidCompleteWithURL:endURL];
    }
    
    CONDITIONAL_STOP_EVENT(CONDITIONAL_SHARED_INSTANCE, _telemetryRequestId, _telemetryEvent);
    
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Dismissed web view controller.");
        [self dismissWebview:^{[self dispatchCompletionBlock:endURL error:error];}];
    }];
    
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
    
    if (_completionHandler)
    {
        MSIDWebUICompletionHandler completionHandler = _completionHandler;
        _completionHandler = nil;
        [_completionLock unlock];
        
        completionHandler(url, error);
    }
    else
    {
        [_completionLock unlock];
    }
}

- (void)startRequest:(NSURLRequest *)request
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Presenting web view controller.");
    
    _telemetryRequestId = [_context telemetryRequestId];
    CONDITIONAL_START_EVENT(CONDITIONAL_SHARED_INSTANCE, _telemetryRequestId, MSID_TELEMETRY_EVENT_UI_EVENT);
#if !EXCLUDE_FROM_MSALCPP
    _telemetryEvent = [[MSIDTelemetryUIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_UI_EVENT
                                                         context:_context];
#endif
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
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, self.context, @"-decidePolicyForNavigationAction host: %@", MSID_PII_LOG_TRACKABLE(requestURL.host));
    
    if ([self shouldSendNavigationNotification:requestURL navigationAction:navigationAction])
    {
        [MSIDNotifications notifyWebAuthDidStartLoad:requestURL userInfo:webView ? @{@"webview" : webView} : nil];
    }

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
#if MSAL_JS_AUTOMATION
    [webView evaluateJavaScript:self.clientAutomationScript completionHandler:nil];
#endif
    
    [self notifyFinishedNavigation:url webView:webView];
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
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,self.context,
                     @"%@ - %@. Previous challenge failure count: %ld",
                     @"webView:didReceiveAuthenticationChallenge:completionHandler",
                     authMethod, (long)challenge.previousFailureCount);
    
    [MSIDChallengeHandler handleChallenge:challenge
                                  webview:webView
#if TARGET_OS_IPHONE
                         parentController:self.parentController
#endif
                                  context:self.context
                        completionHandler:completionHandler];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    if (navigationResponse && [navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]])
    {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)navigationResponse.response;

        [self processOnboardingTelemetryForResponse:response];

        if (self.navigationResponseBlock)
        {
            self.navigationResponseBlock(response);
        }
    }
    
    WKNavigationResponsePolicy responsePolicy = WKNavigationResponsePolicyAllow;

    if (self.isMobileOnboardingEnabled)
    {
        id<MSIDWebviewNavigationDelegate> strongNavigationDelegate = self.navigationDelegate;
        if ((strongNavigationDelegate)
            && [strongNavigationDelegate respondsToSelector:@selector(processResponseHeadersAndCheckForASWebAuthHandoff:responseURL:)]
            && [navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]])
        {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)navigationResponse.response;

            // Process the response headers and determine if a hand-off to ASWebAuthenticationSession is signaled.
            // The response URL is passed so the delegate can verify the issuing origin is allowed (HTTPS + allowlisted host)
            // before honoring an ASWebAuth header.
            BOOL didHandoff = [strongNavigationDelegate processResponseHeadersAndCheckForASWebAuthHandoff:response.allHeaderFields
                                                                                             responseURL:response.URL];

#if !MSID_EXCLUDE_SYSTEMWV
            // If a hand-off is signaled, and the navigation delegate implements the hand-off method, perform the hand-off to ASWebAuthenticationSession and cancel the current navigation.
            if (didHandoff
                && [strongNavigationDelegate respondsToSelector:@selector(performASWebAuthenticationHandoffWithCompletion:)])
            {
                NSURL *responseURL = response.URL;
                responsePolicy = WKNavigationResponsePolicyCancel;
                [strongNavigationDelegate performASWebAuthenticationHandoffWithCompletion:^(MSIDWebviewNavigationDecision *decision, NSError *error)
                {
                    [self performNavigationDecision:decision
                                         requestURL:responseURL
                                              error:error];
                }];
            }
#endif // !MSID_EXCLUDE_SYSTEMWV
        }
    }

    decisionHandler(responsePolicy);
}

- (void)completeWebAuthWithURL:(NSURL *)endURL
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"-completeWebAuthWithURL: %@", [endURL msidPIINullifiedURL]);
    
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
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, self.context, @"-webAuthFailWithError: %@", MSID_PII_LOG_MASKABLE(error));
    
    [self endWebAuthWithURL:nil error:error];
}

#pragma mark - URL scheme helpers

- (BOOL)shouldOpenURLInSystemBrowser:(NSURL *)url targetFrame:(WKFrameInfo *)targetFrame
{
    NSString *scheme = url.scheme.lowercaseString;

    if (!scheme.length)
    {
        return NO;
    }

    // Open https links targeting a new window (targetFrame == nil) or non-http(s) scheme URLs
    return ([scheme isEqualToString:@"https"] && !targetFrame) || ![scheme hasPrefix:@"http"];
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
    
    if ([requestURLString isEqualToString:@"about:blank"] || [requestURLString isEqualToString:@"about:srcdoc"])
    {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    
    // Handle anchor links that were clicked
    if ([navigationAction navigationType] == WKNavigationTypeLinkActivated)
    {
        //Open secure web links with target=new window in default browser or non-web links with URL schemes that can be opened by the application
        // If the target of the navigation is a new window, navigationAction.targetFrame is nil. (See discussions in : https://developer.apple.com/documentation/webkit/wknavigationaction/1401918-targetframe?language=objc)
        if ([self shouldOpenURLInSystemBrowser:requestURL targetFrame:navigationAction.targetFrame])
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"Opening URL outside embedded webview with scheme: %@ host: %@", requestURL.scheme, MSID_PII_LOG_TRACKABLE(requestURL.host));
            [MSIDAppExtensionUtil sharedApplicationOpenURL:requestURL];
            [self notifyFinishedNavigation:requestURL webView:webView];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
    }
    
    // redirecting to non-https url is not allowed
    if (![requestURL.scheme.lowercaseString isEqualToString:@"https"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Server is redirecting to a non-https url");
        
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerNonHttpsRedirect, @"The server has redirected to a non-https url.", nil, nil, nil, self.context.correlationId, nil, NO);
        [self endWebAuthWithURL:nil error:error];
        
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    if (self.customHeaderProvider)
    {
        [self.customHeaderProvider getCustomHeaders:navigationAction.request
                                            forHost:requestURL.host
                                    completionBlock:^(NSDictionary<NSString *, NSString *> *extraHeaders, NSError *error){
            [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
                if (extraHeaders && extraHeaders.count > 0)
                {
                    NSMutableURLRequest *newUrlRequest = [navigationAction.request mutableCopy];
                    
                    for (NSString *headerKey in extraHeaders)
                    {
                        if (![NSString msidIsStringNilOrBlank:extraHeaders[headerKey]])
                        {
                            [newUrlRequest setValue:extraHeaders[headerKey] forHTTPHeaderField:headerKey];
                        }
                    }
                    
                    decisionHandler(WKNavigationActionPolicyCancel);
                    [self loadRequest:newUrlRequest];
                    return;
                }
                
                if (error)
                {
                    MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Error received while getting custom headers in embedded webview: %@", MSID_PII_LOG_MASKABLE(error));
                }
                
                decisionHandler(WKNavigationActionPolicyAllow);
                return;
            }];
        }];
    }
    else
    {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation
{
    NSURL *url = webView.URL;
    if (url && [url.absoluteString containsString:[NSString stringWithFormat:@"%@=", MSID_SSO_NONCE_QUERY_PARAM_KEY]])
    {
        [self completeWebAuthWithURL:url];
    }
}

#pragma mark - WKUIDelegate Protocol

- (WKWebView *)webView:(WKWebView *)webView
createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
   forNavigationAction:(WKNavigationAction *)navigationAction
        windowFeatures:(WKWindowFeatures *)windowFeatures
{
    if ([[MSIDFlightManager sharedInstance] boolForKey:MSID_FLIGHT_DISABLE_OPEN_NEW_WINDOW_IN_BROWSER])
    {
        return nil;
    }

    NSURL *requestURL = navigationAction.request.URL;

    // Skip link-activated navigations — decidePolicyForNavigationAction: already handles
    // target="_blank" anchor clicks by opening them in the system browser.
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated)
    {
        return nil;
    }

    // For other new-window requests (e.g. window.open()), use the same scheme gating
    // as decidePolicyForNavigationAction:. targetFrame is nil for new-window requests.
    if ([self shouldOpenURLInSystemBrowser:requestURL targetFrame:nil])
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"Opening new window URL in system browser with scheme: %@ host: %@", requestURL.scheme, MSID_PII_LOG_TRACKABLE(requestURL.host));
        [MSIDAppExtensionUtil sharedApplicationOpenURL:requestURL];
        [self notifyFinishedNavigation:requestURL webView:webView];
    }

    // Return nil to prevent WKWebView from creating a new web view
    return nil;
}

#if AD_BROKER
- (void) webView:(WKWebView *)webView
requestMediaCapturePermissionForOrigin:(WKSecurityOrigin *)origin
initiatedByFrame:(WKFrameInfo *)frame
            type:(WKMediaCaptureType)type
 decisionHandler:(void (^)(WKPermissionDecision decision))decisionHandler API_AVAILABLE(ios(15.0), macos(12.0))
{
    // Prompt suppression is only allowed for the camera
    if (type == WKMediaCaptureTypeCamera)
    {
        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:SSO_EXTENSION_USER_DEFAULTS_KEY];
        id cameraConsentValue = [userDefaults objectForKey:CAMERA_CONSENT_PROMPT_SUPPRESS_KEY];
        id sdmCameraConsentValue = [userDefaults objectForKey:SDM_CAMERA_CONSENT_PROMPT_SUPPRESS_KEY];
        
        if (cameraConsentValue && ([cameraConsentValue isKindOfClass:NSNumber.class] || [cameraConsentValue isKindOfClass:NSString.class]))
        {
            if ([cameraConsentValue boolValue])
            {
                decisionHandler(WKPermissionDecisionGrant);
                return;
            }
        }
        else if (sdmCameraConsentValue && ([sdmCameraConsentValue isKindOfClass:NSNumber.class] || [sdmCameraConsentValue isKindOfClass:NSString.class]))
        {
            if ([sdmCameraConsentValue boolValue])
            {
                decisionHandler(WKPermissionDecisionGrant);
                return;
            }
        }
    }

    decisionHandler(WKPermissionDecisionPrompt);
}
#endif

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

- (void)notifyFinishedNavigation:(NSURL *)url webView:(WKWebView *)webView
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, self.context, @"-didFinishNavigation host: %@", MSID_PII_LOG_TRACKABLE(url.host));
    
    [MSIDNotifications notifyWebAuthDidFinishLoad:url userInfo:webView ? @{@"webview": webView} : nil];
    
    [self stopSpinner];
}

- (BOOL)shouldSendNavigationNotification:(NSURL *)requestURL navigationAction:(WKNavigationAction *)navigationAction
{
    NSString *requestURLString = [requestURL.absoluteString lowercaseString];
    if ([requestURLString isEqualToString:@"about:blank"] || [requestURLString isEqualToString:@"about:srcdoc"])
    {
        return NO;
    }
    
    if (!navigationAction.targetFrame.isMainFrame)
    {
        return NO;
    }
    
    return YES;
}

#pragma mark - Navigation Decision

- (void)performNavigationDecision:(MSIDWebviewNavigationDecision *)navigationDecision
                       requestURL:(NSURL *)requestURL
                            error:(NSError *)error
{
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        if (error)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context,
                              @"Navigation delegate returned error: %@", error);
            [self endWebAuthWithURL:nil error:error];
            return;
        }
        
        // Default to completing the web auth with the current URL if no decision is returned
        if (!navigationDecision)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context,
                              @"Navigation delegate returned nil action");
            [self completeWebAuthWithURL:requestURL];
            return;
        }
        
        // Check validity
        if (![navigationDecision isValid])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context,
                              @"Navigation validation failed, using fallback");
            [self completeWebAuthWithURL:requestURL];
            return;
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                          @"Applying navigation decision type: %ld", (long)navigationDecision.type);
        
        switch (navigationDecision.type)
        {
            case MSIDWebviewNavigationDecisionLoadRequest:
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context,
                                      @"Loading request: %@",
                                      MSID_PII_LOG_MASKABLE(navigationDecision.request.URL));
                [self loadRequest:navigationDecision.request];
                break;
            }
                
            case MSIDWebviewNavigationDecisionCompleteWithURL:
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context,
                                      @"Completing webauth with URL: %@",
                                      MSID_PII_LOG_MASKABLE(navigationDecision.URL));
                [self completeWebAuthWithURL:navigationDecision.URL];
                break;
            }
                
            case MSIDWebviewNavigationDecisionFailWithError:
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context,
                                  @"Failing webauth with error: %@", navigationDecision.error);
                [self endWebAuthWithURL:nil error:navigationDecision.error];
                break;
            }
                
            case MSIDWebviewNavigationDecisionContinueDefault:
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                                  @"Continuing with default behavior");
                [self completeWebAuthWithURL:requestURL];
                break;
            }
                
            default:
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context,
                                  @"Unknown decision type: %ld, using fallback", (long)navigationDecision.type);
                [self completeWebAuthWithURL:requestURL];
                break;
            }
        }
    }];
}

#pragma mark - Onboarding telemetry

- (void)finalizeOnboardingTelemetry:(NSURL *)endURL
                              error:(NSError *)error
{
    MSIDOnboardingBlobBuilder *onboardingBlobBuilder = self.onboardingBlobBuilder;
    if (onboardingBlobBuilder)
    {
        BOOL flowSucceeded = (endURL != nil && error == nil);
        if (flowSucceeded)
        {
            NSDate *now = [NSDate date];
            if (_onboardingStrongAuthSetupStarted)
            {
                [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepStrongAuthSetupCompleted timestamp:now];
            }
            if (_onboardingMdmEnrollmentStarted)
            {
                [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepMdmEnrollmentFinished timestamp:now];
            }
        }
        
        NSString *endUrlStep = [self onboardingStepForEndURL:endURL];
        if (endUrlStep)
        {
            [onboardingBlobBuilder addStep:endUrlStep timestamp:[NSDate date]];
        }
    }
}

// Maps a terminal endURL that points at a well-known go.microsoft.com fwlink
// (browser://go.microsoft.com/fwlink[/]?...LinkId=<id>...) to the onboarding
// step that should be recorded against the current blob. The LinkId-to-step
// map is the single extension point: new LinkIds (potentially mapping to a
// different step) just add entries here.
- (NSString *)onboardingStepForEndURL:(NSURL *)endURL
{
    if (!endURL)
    {
        return nil;
    }

    NSURLComponents *components = [NSURLComponents componentsWithURL:endURL resolvingAgainstBaseURL:NO];
    if (!components)
    {
        return nil;
    }

    if ([components.scheme caseInsensitiveCompare:@"browser"] != NSOrderedSame)
    {
        return nil;
    }

    if ([components.host caseInsensitiveCompare:@"go.microsoft.com"] != NSOrderedSame)
    {
        return nil;
    }

    NSString *path = components.path;
    if ([path caseInsensitiveCompare:@"/fwlink"] != NSOrderedSame
        && [path caseInsensitiveCompare:@"/fwlink/"] != NSOrderedSame)
    {
        return nil;
    }

    NSString *linkIdValue = nil;
    for (NSURLQueryItem *item in components.queryItems)
    {
        if ([item.name caseInsensitiveCompare:@"LinkId"] == NSOrderedSame)
        {
            linkIdValue = item.value;
            break;
        }
    }

    if (linkIdValue.length == 0)
    {
        return nil;
    }

    return [[self.class onboardingStepsByFwlinkLinkId] objectForKey:linkIdValue];
}

// LinkId value -> onboarding step constant. Extension point: future LinkIds
// (which may map to a different onboarding step) are added here.
+ (NSDictionary<NSString *, NSString *> *)onboardingStepsByFwlinkLinkId
{
    static NSDictionary<NSString *, NSString *> *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"396941"  : MSIDOnboardingBlobStepMdmEnrollmentStarted, // Public
            @"2132314" : MSIDOnboardingBlobStepMdmEnrollmentStarted, // China
            @"2114747" : MSIDOnboardingBlobStepMdmEnrollmentStarted, // GOV
            @"399153"  : MSIDOnboardingBlobStepMdmEnrollmentStarted, // PPE
        };
    });
    return map;
}

- (void)processOnboardingTelemetryForResponse:(NSHTTPURLResponse *)response
{
    MSIDOnboardingBlobBuilder *builder = self.onboardingBlobBuilder;
    if (!builder || !response)
    {
        return;
    }

    NSString *host = response.URL.host;
    if (host.length > 0)
    {
        [builder setLastLoadedDomain:host];
    }

    NSString *cliTelem = response.allHeaderFields[MSID_OAUTH2_CLIENT_TELEMETRY];
    if ([NSString msidIsStringNilOrBlank:cliTelem])
    {
        return;
    }

    // Format: <version>,<error_code>,<suberror_code>,<rt_age>,<spe_info>
    NSArray *components = [cliTelem componentsSeparatedByString:@","];
    if (components.count < 2)
    {
        return;
    }

    NSString *errorCode = [components[1] msidTrimmedString];
    if (errorCode.length == 0 || [errorCode isEqualToString:@"0"])
    {
        return;
    }

    // Check list of expected errors to ignore as part of normal sign-in flow.
    if ([[self.class nonBlockingOnboardingErrorCodes] containsObject:errorCode])
    {
        return;
    }

    [builder addBlockingError:errorCode];
    [self recordOnboardingRemediationStepForErrorCode:errorCode builder:builder];
}

// Error codes that are returned during normal sign-in flow and should not be
// treated as blocking onboarding errors (e.g. user not signed in, wrong password,
// device auth interrupt). This list will be extended over time.
//   50058  UserInformationNotProvided      - User not signed in / no valid SSO session found
//   50097  DeviceAuthenticationRequired    - Device auth interrupt triggered by CA policy
//   50126  InvalidUserNameOrPassword       - Wrong username or password
+ (NSSet<NSString *> *)nonBlockingOnboardingErrorCodes
{
    static NSSet<NSString *> *codes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        codes = [NSSet setWithObjects:@"50058", @"50097", @"50126", nil];
    });
    return codes;
}

- (void)recordOnboardingRemediationStepForErrorCode:(NSString *)errorCode
                                            builder:(MSIDOnboardingBlobBuilder *)builder
{
    NSDate *now = [NSDate date];

    // 50079: Strong auth enrollment needed (MFA setup, not MFA fulfillment like 50076/50078)
    if ([errorCode isEqualToString:@"50079"] && !_onboardingStrongAuthSetupStarted)
    {
        [builder addStep:MSIDOnboardingBlobStepStrongAuthSetupStarted timestamp:now];
        _onboardingStrongAuthSetupStarted = YES;
    }
    // 50129 (DeviceIsNotWorkplaceJoined): Device registration needed,
    // 501291 (DeviceIsNotWorkplaceJoinedForMamApp): Device registration needed for MAM app
    else if ([errorCode isEqualToString:@"50129"] || [errorCode isEqualToString:@"501291"])
    {
        [builder addStep:MSIDOnboardingBlobStepDeviceRegistrationRequired timestamp:now];
    }
    // 530001 (DeviceNotCompliantBrowserNotSupported): Browser not supported,
    // 530002: (DeviceNotCompliantDeviceCompliantRequired): The device is required to be compliant to access this resource
    else if ([errorCode isEqualToString:@"530001"] || [errorCode isEqualToString:@"530002"])
    {
        [builder addStep:MSIDOnboardingBlobStepDeviceNotCompliant timestamp:now];
    }
    // 53000 (DeviceNotCompliant): The user must enroll their device with an approved MDM provider like Intune,
    // 530003 (DeviceNotCompliantDeviceManagementRequired): MDM enrollment required
    else if ([errorCode isEqualToString:@"53000"] || [errorCode isEqualToString:@"530003"])
    {
        [builder addStep:MSIDOnboardingBlobStepMdmEnrollmentRequired timestamp:now];
    }
    // 50127: Client app is a MAM app and device is not registered
    else if ([errorCode isEqualToString:@"50127"])
    {
        [builder addStep:MSIDOnboardingBlobStepBrokerInstallPromptedForMAM timestamp:now];
    }
    // 501271: Broker app needs to be installed for device authentication to succeed.
    else if ([errorCode isEqualToString:@"501271"])
    {
        [builder addStep:MSIDOnboardingBlobStepBrokerInstallPrompted timestamp:now];
    }
    
    // All other error codes (50076, 50078, 53005, 53003, etc.): blocking error only, no step
}

@end

#endif
