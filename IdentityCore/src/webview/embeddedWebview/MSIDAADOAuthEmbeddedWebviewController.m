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
#import "MSIDMainThreadUtil.h"

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

#pragma mark - Navigation Action Decision
- (BOOL)decidePolicyAADForNavigationAction:(WKNavigationAction *)navigationAction
                           decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    //AAD specific policy for handling navigation action
    NSURL *requestURL = navigationAction.request.URL;
    
    // Stop at broker or browser
    BOOL isBrokerUrl = [@"msauth" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
    BOOL isBrowserUrl = [@"browser" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
    
    // TODO: testing
    NSString *host = requestURL.host;
    NSString *path = requestURL.path;
    if (isBrowserUrl)
    {
        NSDictionary *queryParams = [requestURL msidQueryParameters];
        NSString *linkId = queryParams[@"LinkId"];
        // Check for enrollment URL (path could be /fwlink or /fwlink/)
        BOOL isEnrollmentPath = [path isEqualToString:@"/fwlink"] || [path isEqualToString:@"/fwlink/"];
        if ([host isEqualToString:@"go.microsoft.com"] &&
            isEnrollmentPath &&
            ([linkId isEqualToString:@"396941"] || [linkId isEqual:@"399153"]))
        {
            // Construct proper https URL with all query parameters
            NSString *cpurlValue;
            if (requestURL.query && requestURL.query.length > 0)
            {
                cpurlValue = [NSString stringWithFormat:@"https://%@%@?%@", host, path, requestURL.query];
            }
            else
            {
                cpurlValue = [NSString stringWithFormat:@"https://%@%@", host, path];
            }
            // Properly encode the cpurl value for use as a query parameter
            //            NSString *encodedCpurl = [cpurlValue stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            //            NSRange range = [encodedCpurl rangeOfString:@"?"];
            //            if (range.location != NSNotFound) {
            //                encodedCpurl = [cpurlValue stringByReplacingCharactersInRange:range withString:@"&"];
            //            }
            
            NSString *msauthURLString = [NSString stringWithFormat:@"msauth://enroll?cpurl=%@", cpurlValue];
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"Converting browser enrollment URL to msauth URL. Original: %@, Converted: %@", MSID_PII_LOG_MASKABLE(requestURL.absoluteString), MSID_PII_LOG_MASKABLE(msauthURLString));
            requestURL = [NSURL URLWithString:msauthURLString];
            // Re-evaluate URL scheme flags after conversion
            isBrokerUrl = [@"msauth" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
            isBrowserUrl = [@"browser" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
        }
        
    }
    
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
            [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
                [strongNavigationDelegate handleSpecialRedirectUrl:requestURL
                                           webviewController:self
                                                  completion:^(MSIDWebviewNavigationAction *action, NSError *error)
                 {
                    [self executeWebviewNavigationAction:action
                                                    requestURL:requestURL
                                                         error:error];
                }];
            }];
            
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
