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

#import "MSIDAADOAuthEmbeddedWebviewController.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDPKeyAuthHandler.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDWebAuthNUtil.h"
#import "MSIDFlightManager.h"
#import "MSIDConstants.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDWebviewNavigationAction.h"

#if !MSID_EXCLUDE_WEBKIT

@interface MSIDAADOAuthEmbeddedWebviewController()

@property (nonatomic) NSHTTPURLResponse *lastHTTPResponse;

@end

@implementation MSIDAADOAuthEmbeddedWebviewController

- (id)initWithStartURL:(NSURL *)startURL
                endURL:(NSURL *)endURL
               webview:(WKWebView *)webview
         customHeaders:(NSDictionary<NSString *, NSString *> *)customHeaders
          platfromParams:(MSIDWebViewPlatformParams *)platformParams
               context:(id<MSIDRequestContext>)context
{
    NSMutableDictionary *headers = [NSMutableDictionary new];
    if (customHeaders)
    {
        [headers addEntriesFromDictionary:customHeaders];
    }
    
    // Declare our client as PkeyAuth-capable
    [headers setValue:kMSIDPKeyAuthHeaderVersion forKey:kMSIDPKeyAuthHeader];
        
    self = [super initWithStartURL:startURL
                            endURL:endURL
                           webview:webview
                     customHeaders:headers
                    platfromParams:platformParams
                           context:context];
    
    if (self)
    {
        // Set up navigation response block to capture HTTP responses
        __weak typeof(self) weakSelf = self;
        self.navigationResponseBlock = ^(NSHTTPURLResponse *response) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf)
            {
                strongSelf.lastHTTPResponse = response;
                
                // store last response headers in session
                MSIDWebviewSession *currentSession = [MSIDWebviewAuthorization currentSession];
                if (currentSession)
                {
                    currentSession.lastResponseHeaders = response.allHeaderFields;
                }
            }
        };
    }
    
    return self;
}

#pragma mark - Navigation Action Execution

- (void)executeWebviewNavigationAction:(MSIDWebviewNavigationAction *)action
                            requestURL:(NSURL *)requestURL
                                 error:(NSError *)error
{
    if (error)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context,
                         @"Navigation delegate returned error: %@", error);
        // TODO: check for endWebAuthWithURl or completeWebAuth
        [self endWebAuthWithURL:nil error:error];
        return;
    }
    
    // Explicit error for nil action
    if (!action)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context,
                         @"Navigation delegate returned nil action");
        NSError *localError = MSIDCreateError(MSIDErrorDomain,
                                        MSIDErrorInternal,
                                        @"Navigation action is nil",
                                        nil, nil, nil,
                                        self.context.correlationId,
                                        nil, NO);
        
        // TODO: check for endWebAuthWithURl or completeWebAuth
        [self endWebAuthWithURL:nil error:localError];
        return;
    }
    
    // Check validity
    if (![action isValid])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context,
                         @"Action validation failed, using fallback");
        [self completeWebAuthWithURL:requestURL];
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                     @"Executing navigation action type: %ld", (long)action.type);
    
    switch (action.type)
    {
        case MSIDWebviewNavigationActionTypeLoadRequestInWebview:
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context,
                                 @"Loading request: %@",
                                 MSID_PII_LOG_MASKABLE(action.request.URL));
            [self loadRequest:action.request];
            break;
        }
            
        case MSIDWebviewNavigationActionTypeOpenInASWebAuthenticationSession:
        {
            // TODO: testing if this recursion could cause any issue
            id<MSIDWebviewNavigationDelegate> strongNavigationDelegate = self.navigationDelegate;
            if (strongNavigationDelegate)
            {
                if ([strongNavigationDelegate respondsToSelector:@selector(handleASWebAuthenticationTransitionWithUrl:embeddedWebview:additionalHeaders:MSIDSystemWebviewPurpose:completion:)])
                {
                    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                                      @"Detected redirect scheme: %@. Delegating to navigationDelegate.", requestURL.scheme);
                    
                    // Call delegate on main thread
                    __weak typeof(self) weakSelf = self;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        __strong typeof(self) strongSelf = weakSelf;
                        if (!strongSelf) return;
                        
                        [strongNavigationDelegate handleASWebAuthenticationTransitionWithUrl:action.url
                                                                             embeddedWebview:strongSelf
                                                                           additionalHeaders:action.additionalHeaders
                                                                    MSIDSystemWebviewPurpose:action.purpose
                                                                                  completion:^(MSIDWebviewNavigationAction * _Nonnull navigationAction, NSError * _Nonnull aswebAuthError) {
                            [strongSelf executeWebviewNavigationAction:navigationAction
                                                            requestURL:requestURL
                                                                 error:aswebAuthError];
                        }];
                    });
                }
            }
            
            break;
        }
            // TODO: Check for more actions
        case MSIDWebviewNavigationActionTypeOpenInExternalBrowser:
        {
            /*MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context,
                                 @"Opening in external browser: %@",
                                 MSID_PII_LOG_MASKABLE(action.url));
#if TARGET_OS_IPHONE && !TARGET_OS_MACCATALYST
            #if !defined(MSID_EXCLUDE_SHARED_APPLICATION)
            if ([[UIApplication class] respondsToSelector:@selector(sharedApplication)])
            {
                [[UIApplication sharedApplication] openURL:action.url
                                                   options:@{}
                                         completionHandler:nil];
            }
            #endif
#elif TARGET_OS_OSX
            [[NSWorkspace sharedWorkspace] openURL:action.url];
#endif*/
            break;
        }
            
        case MSIDWebviewNavigationActionTypeCompleteWebAuthWithURL:
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context,
                                 @"Completing webauth with URL: %@",
                                 MSID_PII_LOG_MASKABLE(action.url));
            [self completeWebAuthWithURL:action.url];
            break;
        }
            
        case MSIDWebviewNavigationActionTypeFailWithError:
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context,
                             @"Failing webauth with error: %@", action.error);
            [self endWebAuthWithURL:nil error:action.error];
            break;
        }
            
        case MSIDWebviewNavigationActionTypeContinueDefault:
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                             @"Continuing with default behavior");
            [self completeWebAuthWithURL:requestURL];
            break;
        }
            
        default:
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context,
                             @"Unknown action type: %ld, using fallback", (long)action.type);
            [self completeWebAuthWithURL:requestURL];
            break;
        }
    }
}

#pragma mark - Navigation Action Decision
- (BOOL)decidePolicyAADForNavigationAction:(WKNavigationAction *)navigationAction
                           decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    //AAD specific policy for handling navigation action
    NSURL *requestURL = navigationAction.request.URL;
    
    // Stop at broker or browser
    BOOL isBrokerUrl = [@"msauth" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
    BOOL isBrowserUrl = [@"browser" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
    
    if (![MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_DISABLE_JIT_TROUBLESHOOTING_LEGACY_AUTH])
    {
        // When not running in SSO extension, the CA block page will return with "https" scheme instead of "browser"
        if (requestURL && ![MSIDWebAuthNUtil amIRunningInExtension] &&
            self.externalDecidePolicyForBrowserAction &&
            [@"https" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame)
        {
            // Create new URL replacing 'https' scheme with 'browser' scheme
            NSURL *legacyFlowUrl = [NSURL URLWithString:[NSString stringWithFormat:@"browser%@", [requestURL.absoluteString substringFromIndex:5]]];
            NSURLRequest *challengeResponse = self.externalDecidePolicyForBrowserAction(self, legacyFlowUrl);

            if (challengeResponse)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Found AAD policy for navigation using https url and externalDecidePolicyForBrowserAction in legacy auth flow.");
                decisionHandler(WKNavigationActionPolicyCancel);
                [self loadRequest:challengeResponse];

                return YES;
            }
        }
    }
    
    // Priority 1: Try navigationDelegate callback for redirect handling (NEW flow)
    // Check if delegate is set for special redirect handling
    id<MSIDWebviewNavigationDelegate> strongNavigationDelegate = self.navigationDelegate;
    if ((isBrokerUrl || isBrowserUrl) && strongNavigationDelegate)
    {
        if ([strongNavigationDelegate respondsToSelector:@selector(handleSpecialRedirectUrl:webviewController:completion:)])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                             @"Delegating special redirect %@ to navigationDelegate",
                             requestURL.scheme);
            
            // Cancel navigation and delegate decision to handler
            decisionHandler(WKNavigationActionPolicyCancel);
            
            // Call delegate on main thread
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                if (!strongSelf) return;

                [strongNavigationDelegate handleSpecialRedirectUrl:requestURL
                                           webviewController:strongSelf
                                                  completion:^(MSIDWebviewNavigationAction *action, NSError *error)
                 {
                    [strongSelf executeWebviewNavigationAction:action
                                                    requestURL:requestURL
                                                         error:error];
                }];
            });
            
            return YES;
        }
    }
    
    // Priority 2: If URL is broker or browser scheme, check for external callback, otherwise complete web auth by default
    if (isBrokerUrl || isBrowserUrl)
    {
        // Let external code decide if browser url is allowed to continue
        if (isBrowserUrl && self.externalDecidePolicyForBrowserAction)
        {
            NSURLRequest *challengeResponse = self.externalDecidePolicyForBrowserAction(self, requestURL);

            if (challengeResponse)
            {
                decisionHandler(WKNavigationActionPolicyCancel);
                [self loadRequest:challengeResponse];

                return YES;
            }
        }
        
        [self completeWebAuthWithURL:requestURL];
        
        decisionHandler(WKNavigationActionPolicyCancel);
        return YES;
    }
    
    // check for pkeyauth challenge.
    NSString *requestURLString = [requestURL.absoluteString lowercaseString];
    
    if ([requestURLString hasPrefix:[kMSIDPKeyAuthUrn lowercaseString]])
    {
        decisionHandler(WKNavigationActionPolicyCancel);
        [MSIDPKeyAuthHandler handleChallenge:requestURL.absoluteString
                                     context:self.context
                               customHeaders:self.customHeaders
                          externalSSOContext:self.platformParams.externalSSOContext
                           completionHandler:^(NSURLRequest *challengeResponse, NSError *error) {
                               if (!challengeResponse)
                               {
                                   [self endWebAuthWithURL:nil error:error];
                                   return;
                               }
                               [self loadRequest:challengeResponse];
                           }];
        return YES;
    }
    
    return NO;
}

- (void)decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                                webview:(WKWebView *)webView
                        decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if ([self decidePolicyAADForNavigationAction:navigationAction decisionHandler:decisionHandler])
    {
         return;
    }

    [super decidePolicyForNavigationAction:navigationAction webview:webView decisionHandler:decisionHandler];
}

@end

#endif
