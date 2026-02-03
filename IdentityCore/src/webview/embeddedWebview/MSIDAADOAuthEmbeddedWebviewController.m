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
#import "MSIDWebviewTransitionCoordinator.h"
#import "MSIDWebProfileInstallTriggerResponse.h"

#if !MSID_EXCLUDE_WEBKIT

@interface MSIDAADOAuthEmbeddedWebviewController()

@property (nonatomic) MSIDWebviewTransitionCoordinator *transitionCoordinator;
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
        
    self = [super initWithStartURL:startURL endURL:endURL
                           webview:webview
                     customHeaders:headers
                    platfromParams:platformParams
                           context:context];
    
    if (self)
    {
        _transitionCoordinator = [[MSIDWebviewTransitionCoordinator alloc] init];
        
        // Set up navigation response block to capture HTTP responses
        __weak typeof(self) weakSelf = self;
        self.navigationResponseBlock = ^(NSHTTPURLResponse *response) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf)
            {
                strongSelf.lastHTTPResponse = response;
            }
        };
    }
    
    return self;
}

- (BOOL)decidePolicyAADForNavigationAction:(WKNavigationAction *)navigationAction
                           decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    //AAD specific policy for handling navigation action
    NSURL *requestURL = navigationAction.request.URL;
    
    // Check for profile install trigger (msauth://installProfile)
    NSError *triggerError = nil;
    MSIDWebProfileInstallTriggerResponse *triggerResponse = [[MSIDWebProfileInstallTriggerResponse alloc] initWithURL:requestURL
                                                                                                          httpResponse:self.lastHTTPResponse
                                                                                                               context:self.context
                                                                                                                 error:&triggerError];
    
    if (triggerResponse)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Profile install trigger detected (msauth://installProfile)");
        
        // Cancel this navigation
        decisionHandler(WKNavigationActionPolicyCancel);
        
        // Handle profile installation flow
        [self handleProfileInstallTrigger:triggerResponse];
        
        return YES;
    }
    
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

#pragma mark - Profile Installation Flow

- (void)handleProfileInstallTrigger:(MSIDWebProfileInstallTriggerResponse *)triggerResponse
{
    if (!triggerResponse.profileInstallURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"Profile install trigger detected but no installation URL provided in headers");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Profile installation URL not found in response headers", nil, nil, nil, self.context.correlationId, nil, YES);
        [self endWebAuthWithURL:nil error:error];
        return;
    }
    
    NSURL *profileURL = [NSURL URLWithString:triggerResponse.profileInstallURL];
    if (!profileURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"Invalid profile installation URL");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Invalid profile installation URL", nil, nil, nil, self.context.correlationId, nil, YES);
        [self endWebAuthWithURL:nil error:error];
        return;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"Starting profile installation with URL: %@", MSID_PII_LOG_MASKABLE(profileURL));
    
    // Suspend this embedded webview (hide but keep alive)
    [self.transitionCoordinator suspendEmbeddedWebview:self];
    
    // Launch ASWebAuthenticationSession for profile installation
    __weak typeof(self) weakSelf = self;
    [self.transitionCoordinator launchProfileInstallationSession:profileURL
                                                parentController:self.parentController
                                                  callbackScheme:@"msauth"
                                               completionHandler:^(NSURL *callbackURL, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf)
        {
            return;
        }
        
        [strongSelf handleProfileInstallationCompletion:callbackURL error:error];
    }];
}

- (void)handleProfileInstallationCompletion:(NSURL *)callbackURL error:(NSError *)error
{
    if (error)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"Profile installation session failed: %@", error);
        
        // Clean up
        [self.transitionCoordinator cleanup];
        
        // End the auth flow with error
        [self endWebAuthWithURL:nil error:error];
        return;
    }
    
    // Check if callback is msauth://profileInstalled
    if (callbackURL && 
        [callbackURL.scheme caseInsensitiveCompare:@"msauth"] == NSOrderedSame &&
        [callbackURL.host caseInsensitiveCompare:@"profileInstalled"] == NSOrderedSame)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Profile installation completed successfully");
        
        // Dismiss the ASWebAuthenticationSession
        [self.transitionCoordinator dismissProfileInstallationSession];
        
        // Resume the suspended embedded webview
        [self.transitionCoordinator resumeSuspendedEmbeddedWebview];
        
        // The webview will continue its flow naturally
        // It's still alive and will process the next response from the server
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, @"Unexpected callback URL from profile installation: %@", callbackURL);
        
        // Clean up
        [self.transitionCoordinator cleanup];
        
        // Create error for unexpected callback
        NSError *callbackError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected callback from profile installation", nil, nil, nil, self.context.correlationId, nil, YES);
        [self endWebAuthWithURL:nil error:callbackError];
    }
}

@end

#endif
