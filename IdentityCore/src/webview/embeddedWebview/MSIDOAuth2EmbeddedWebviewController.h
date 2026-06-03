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

#if !MSID_EXCLUDE_WEBKIT

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "MSIDWebviewInteracting.h"
#import "MSIDWebviewUIController.h"
#import "MSIDAuthorizeWebRequestConfiguration.h"
#import "MSIDWebViewPlatformParams.h"
#import "MSIDCustomHeaderProviding.h"
#import "MSIDWebviewNavigationDelegate.h"

@class MSIDOnboardingBlobBuilder;

typedef void (^MSIDNavigationResponseBlock)(NSHTTPURLResponse *response);

@interface MSIDOAuth2EmbeddedWebviewController :
MSIDWebviewUIController <MSIDWebviewInteracting, WKNavigationDelegate, WKUIDelegate>

typedef NSURLRequest *(^MSIDExternalDecidePolicyForBrowserActionBlock)(MSIDOAuth2EmbeddedWebviewController *webView, NSURL *url);

- (id)init NS_UNAVAILABLE;
- (id)initWithStartURL:(NSURL *)startURL
                endURL:(NSURL *)endURL
               webview:(WKWebView *)webview
         customHeaders:(NSDictionary<NSString *, NSString *> *)customHeaders
        platfromParams:(MSIDWebViewPlatformParams *)platformParams
               context:(id<MSIDRequestContext>)context;

- (void)loadRequest:(NSURLRequest *)request;
- (void)completeWebAuthWithURL:(NSURL *)endURL;
- (void)endWebAuthWithURL:(NSURL *)endURL error:(NSError *)error;
- (void)decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                                webview:(WKWebView *)webView
                        decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler;

/**
 Applies the navigation decision returned by the delegate.
 
 @param navigationDecision The navigation decision to apply
 @param requestURL The URL of the original request that triggered the navigation decision
 @param error An error from the delegate, if any
 
 @note This method automatically ensures execution on the main thread. If called from a background thread,
       it will dispatch to the main queue automatically.
 */
- (void)performNavigationDecision:(MSIDWebviewNavigationDecision *)navigationDecision
                       requestURL:(NSURL *)requestURL
                            error:(NSError *)error;

- (void)finalizeOnboardingTelemetry:(NSURL *)endURL
                              error:(NSError *)error;

@property (atomic, readonly) NSURL *startURL;
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *customHeaders;
@property (nonatomic, copy) MSIDNavigationResponseBlock navigationResponseBlock;
@property (nonatomic, copy) MSIDExternalDecidePolicyForBrowserActionBlock externalDecidePolicyForBrowserAction;
@property (nonatomic, weak) id<MSIDWebviewNavigationDelegate> navigationDelegate;
@property (nonatomic) id<MSIDCustomHeaderProviding> customHeaderProvider;

// When set, the controller automatically extracts onboarding telemetry signals
// (last loaded domain, blocking errors from x-ms-clitelem header, and remediation
// steps for known error codes) from each navigation response and forwards them
// to the builder. Reused by both non-brokered and brokered flows.
@property (nonatomic, strong) MSIDOnboardingBlobBuilder *onboardingBlobBuilder;

// Readonly flags exposing whether each remediation step has been recorded against
// the current onboarding blob builder. Subclasses use these to decide whether to
// emit matching completion steps when the flow ends successfully.
@property (nonatomic, readonly) BOOL onboardingStrongAuthSetupStarted;
@property (nonatomic, readonly) BOOL onboardingMdmEnrollmentStarted;
@property (nonatomic, readonly) BOOL onboardingDeviceRegistrationStarted;
@property (nonatomic, readonly) BOOL onboardingRemediationStarted;

#if MSAL_JS_AUTOMATION
@property (nonatomic) NSString *clientAutomationScript;
#endif

@end

#endif
