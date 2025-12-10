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

#if !MSID_EXCLUDE_WEBKIT

#import <AuthenticationServices/AuthenticationServices.h>

@interface MSIDAADOAuthEmbeddedWebviewController () <ASWebAuthenticationPresentationContextProviding>
@property (nonatomic, strong) ASWebAuthenticationSession *authSession;
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
        
    return [super initWithStartURL:startURL endURL:endURL
                           webview:webview
                     customHeaders:headers
                    platfromParams:platformParams
                           context:context];
}

- (BOOL)decidePolicyAADForNavigationAction:(WKNavigationAction *)navigationAction
                           decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    //AAD specific policy for handling navigation action
    NSURL *requestURL = navigationAction.request.URL;
    
    // Stop at broker or browser
    BOOL isBrokerUrl = [@"msauth" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
    BOOL isBrowserUrl = [@"browser" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;

    // Lowercased URL string for comparisons (declare early to avoid use-before-declare)
    NSString *requestURLString = requestURL.absoluteString.lowercaseString ?: @"";
    

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
    
    if (isBrowserUrl)
    {
        NSURL *modifiedURL = [[NSURL alloc] initWithString:[requestURLString stringByReplacingOccurrencesOfString:@"browser" withString:@"https"]];
        NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:modifiedURL];
        decisionHandler(WKNavigationActionPolicyCancel);
        [self loadRequest:urlRequest];
        return YES;

    }
    
    if ([requestURL.scheme isEqualToString:@"https"] &&
            [requestURL.host isEqualToString:@"portal.manage-beta.microsoft.com"] &&
            [requestURL.path isEqualToString:@"/enrollment/webenrollment/installprofile"])
    {

        
        // Extract IntuneId from query parameters
           NSURLComponents *components = [NSURLComponents componentsWithURL:requestURL resolvingAgainstBaseURL:NO];
           NSString *intuneIdValue = nil;
           for (NSURLQueryItem *item in components.queryItems) {
               if ([item.name isEqualToString:@"IntuneId"]) {
                   intuneIdValue = item.value;
                   break;
               }
           }

        // Start ASWebAuthenticationSession
        self.authSession = [[ASWebAuthenticationSession alloc] initWithURL:requestURL
                                                         callbackURLScheme:nil
                                                         completionHandler:^(NSURL * _Nullable callbackURL, NSError * _Nullable error) {
            if (callbackURL) {
                NSLog(@"Success: %@", callbackURL);
                // Handle success if needed
            } else if (error) {
                NSLog(@"Failed: %@", error.localizedDescription);
            }
        }];
        self.authSession.presentationContextProvider = self;
        self.authSession.prefersEphemeralWebBrowserSession = YES; // Optional: Use ephemeral session if needed
        
        // Add custom header if IntuneId exists
        if (intuneIdValue) {
            NSMutableDictionary *headers = [NSMutableDictionary dictionary];
            headers[@"IntuneId"] = intuneIdValue;
            [self.authSession setValue:headers forKey:@"additionalHeader"];
        }

        [self.authSession start];
        
        // Block navigation in webview
        decisionHandler(WKNavigationActionPolicyCancel);
        return YES;
    }
    
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

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(__unused ASWebAuthenticationSession *)session
{
    return [self presentationAnchor];
}

- (ASPresentationAnchor)presentationAnchor
{
    if (![NSThread isMainThread])
    {
        __block ASPresentationAnchor anchor;
        dispatch_sync(dispatch_get_main_queue(), ^{
            anchor = [self presentationAnchor];
        });
        
        return anchor;
    }
    
    __typeof__(self.parentController) parentController = self.parentController;
    
#if TARGET_OS_OSX
    return parentController ? parentController.view.window : [NSApplication sharedApplication].keyWindow;
#else
    return parentController.view.window;
#endif
}


@end

#endif
