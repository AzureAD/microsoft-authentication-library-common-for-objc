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
#import "MSIDAppExtensionUtil.h"
#import "MSIDMainThreadUtil.h"
#import "MSIDBrokerConstants.h"
#import "MSIDWebviewConstants.h"
#import "NSURL+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDInteractiveRequestParameters.h"

#if !MSID_EXCLUDE_WEBKIT

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

- (BOOL)isAuthenticatorAppActivationURL:(NSURL *)url
{
    
    NSString *host = url.host.lowercaseString;
    NSString *path = url.path.lowercaseString;
    
    static NSSet<NSString *> *aadHosts = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        aadHosts = [NSSet setWithArray:@[
            MSIDTrustedAuthorityWorldWide,
            MSIDTrustedAuthorityUS,
            MSIDTrustedAuthorityChina
        ]];
    });
    
    BOOL isAADHost = host && [aadHosts containsObject:host];
    BOOL isActivationPath = [path isEqualToString:@"/authenticatorapp/activateaccount"];
    
    return isAADHost && isActivationPath;
}

#pragma mark - Navigation Action Decision

- (BOOL)decidePolicyAADForNavigationAction:(WKNavigationAction *)navigationAction
                           decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    //AAD specific policy for handling navigation action
    NSURL *requestURL = navigationAction.request.URL;
    
    // Stop at broker or browser
    BOOL isBrokerUrl  = [@"msauth"  caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
    BOOL isBrowserUrl = [@"browser" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
    BOOL isOpenIdVcUrl = [MSID_SCHEME_OPENID_VC caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
    
    
    
msauth://enroll?IntuneUrl=
msauth://compliance?IntuneUrl=
    
    // TODO: testing
    NSString *host = requestURL.host;
    NSString *path = requestURL.path;
    if (isBrowserUrl)
    {
        NSDictionary *queryParams = [requestURL msidQueryParameters];
        NSString *linkId = queryParams[@"LinkId"] ?: queryParams[@"linkid"];
        linkId = linkId ? linkId : queryParams[@"linkid"] ?: queryParams[@"linkId"];
        NSString *compliance = queryParams[@"portalAction"] ?: queryParams[@"PortalAction"];
        BOOL isEnrollmentPath = [path isEqualToString:@"/fwlink"] || [path isEqualToString:@"/fwlink/"];
        if ([host isEqualToString:@"go.microsoft.com"] &&
            isEnrollmentPath
            && ([linkId isEqualToString:@"396941"] || [linkId isEqual:@"399153"]))
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
            
            NSString *msauthURLString = [NSString stringWithFormat:@"msauth://enroll?%@=%@", MSID_INTUNE_URL_KEY, cpurlValue];
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"Converting browser enrollment URL to msauth URL. Original: %@, Converted: %@", MSID_PII_LOG_MASKABLE(requestURL.absoluteString), MSID_PII_LOG_MASKABLE(msauthURLString));
            requestURL = [NSURL URLWithString:msauthURLString];
            // Re-evaluate URL scheme flags after conversion
            isBrokerUrl = [@"msauth" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
            isBrowserUrl = [@"browser" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
            isOpenIdVcUrl = [MSID_SCHEME_OPENID_VC caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
        }
        
        if (([host isEqualToString:@"portal.manage.microsoft.com"] ||[host isEqualToString:@"portal.manage-selfhost.microsoft.com"])
            && ([compliance isEqualToString:@"Compliance"]))
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
            
            NSString *msauthURLString = [NSString stringWithFormat:@"msauth://compliance?%@=%@", MSID_INTUNE_URL_KEY, cpurlValue];
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"Converting browser enrollment URL to msauth URL. Original: %@, Converted: %@", MSID_PII_LOG_MASKABLE(requestURL.absoluteString), MSID_PII_LOG_MASKABLE(msauthURLString));
            requestURL = [NSURL URLWithString:msauthURLString];
            // Re-evaluate URL scheme flags after conversion
            isBrokerUrl = [@"msauth" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
            isBrowserUrl = [@"browser" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
            isOpenIdVcUrl = [MSID_SCHEME_OPENID_VC caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
        }
        
    }
    
    id contextObject = self.context;
    MSIDInteractiveRequestParameters *interactiveRequestParameters =
        [contextObject isKindOfClass:[MSIDInteractiveRequestParameters class]]
            ? (MSIDInteractiveRequestParameters *)contextObject : nil;
    
    // Server-side trigger: msauth://enroll means the server opted this
    // session into the new mobile onboarding flow.
    BOOL isServerNewOnboardingRedirect =
           isBrokerUrl
    && ([MSID_MDM_ENROLL_HOST caseInsensitiveCompare:requestURL.host] == NSOrderedSame || [MSID_COMPLIANCE_HOST caseInsensitiveCompare:requestURL.host] == NSOrderedSame);

    if (isServerNewOnboardingRedirect && !interactiveRequestParameters.isNewMobileOnboardingFlow)
    {
        BOOL clientOnboardingDisabled =
            [[MSIDFlightManager sharedInstance] boolForKey:MSID_FLIGHT_DISABLE_MOBILE_ONBOARDING];

        if (!clientOnboardingDisabled)
        {
            // Server ON + client ON -> new flow for the rest of the session.
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                @"Server issued msauth://enroll - enabling mobile onboarding for this session.");
            interactiveRequestParameters.isNewMobileOnboardingFlow = YES;
        }
        else
        {
            // Server ON + client OFF -> legacy fallback.
            // Pull intuneRedirectUrl (https://...) out of the query params,
            // rewrite it to browser:// and let the unified broker/browser
            // handling below open it in the system browser.
            NSString *intuneURLString =
                [[requestURL msidQueryParameters][MSID_INTUNE_URL_KEY]
                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            NSURL *legacyBrowserURL =
                [self urlBySwappingScheme:[NSURL URLWithString:intuneURLString]
                                     from:@"https"
                                       to:MSID_SCHEME_BROWSER];

            if (legacyBrowserURL)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                    @"Mobile onboarding disabled on client; falling back to legacy "
                    @"flow by opening intuneRedirectUrl via browser:// scheme.");
                requestURL   = legacyBrowserURL;
                isBrokerUrl  = NO;
                isBrowserUrl = YES;
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context,
                    @"Mobile onboarding disabled on client but msauth://enroll URL is "
                    @"missing a valid https intuneRedirectUrl; continuing with default handling.");
            }
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
    // Hand off broker and browser URLs to the delegate when mobile onboarding is enabled.
    if (isBrokerUrl || isBrowserUrl)
    {
        id<MSIDWebviewNavigationDelegate> strongNavigationDelegate = self.navigationDelegate;

        if (interactiveRequestParameters.isNewMobileOnboardingFlow
            && [strongNavigationDelegate respondsToSelector:
                @selector(handleSpecialRedirectURL:embeddedWebviewController:completion:)])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                              @"Delegating special redirect %@ to navigationDelegate",
                              requestURL.scheme);

            decisionHandler(WKNavigationActionPolicyCancel);

            [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
                [strongNavigationDelegate handleSpecialRedirectURL:requestURL
                                         embeddedWebviewController:self
                                                        completion:^(MSIDWebviewNavigationDecision *action, NSError *error)
                {
                    [self performNavigationDecision:action
                                         requestURL:requestURL
                                              error:error];
                }];
            }];
            return YES;
        }

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

    if (isOpenIdVcUrl)
    {
        [self handleOpenIdVcNavigationAction:requestURL decisionHandler:decisionHandler];
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
    
#if AD_BROKER && TARGET_OS_IPHONE
    // Based on https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content,
    // Universal links won't open Authenticator if it is already in Authenticator.
    // Directly invoke the app delegate's continueUserActivity to handle it in-app.
    // Only apply when running in the main Authenticator app.
    if ([MSID_BROKER_APP_BUNDLE_ID isEqualToString:[[NSBundle mainBundle] bundleIdentifier]]
        && [self isAuthenticatorAppActivationURL:requestURL])
    {
        decisionHandler(WKNavigationActionPolicyCancel);
        NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
        userActivity.webpageURL = requestURL;
        UIApplication *app = [MSIDAppExtensionUtil sharedApplication];
        id<UIApplicationDelegate> appDelegate = app.delegate;
        if ([appDelegate respondsToSelector:@selector(application:continueUserActivity:restorationHandler:)])
        {
            [appDelegate application:app
                continueUserActivity:userActivity
                  restorationHandler:^(NSArray<id<UIUserActivityRestoring>> * _Nullable __unused _) {}];
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, @"Received MFA activation link in webview but failed to call delegate.");
        }
        return YES;
    }
#endif
    
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

#pragma mark - Private helpers

- (NSURL *)urlBySwappingScheme:(NSURL *)url
                          from:(NSString *)fromScheme
                            to:(NSString *)toScheme
{
    if (!url || fromScheme.length == 0 || toScheme.length == 0)
    {
        return nil;
    }

    if ([fromScheme caseInsensitiveCompare:url.scheme] != NSOrderedSame)
    {
        return nil;
    }

    NSString *absolute = url.absoluteString;
    if (absolute.length <= fromScheme.length)
    {
        return nil;
    }

    NSString *rewritten = [toScheme stringByAppendingString:
        [absolute substringFromIndex:fromScheme.length]];
    return [NSURL URLWithString:rewritten];
}

#pragma mark - openid-vc handoff

// Handles a webview navigation to an `openid-vc://` URL.
//
// Priority order:
//   1. If a delegate handler is attached (`openIdVcHandler`), forward the
//      navigation to it. The handler owns the entire VID interaction — it
//      may present in-process UI on top of the webview, hand off to a wallet,
//      or anything else. The webview is left presented and the auth session
//      is not terminated unless the handler reports an error.
//   2. Otherwise, fall back to the default behavior of mutating the URL with
//      `x_ms_*` extension parameters and dispatching to a system-registered
//      wallet via `UIApplication.openURL`. From an SSO extension this is not
//      possible, so we terminate the auth session with
//      `MSIDErrorAttemptToOpenURLFromExtension` in that case.
//
// In all cases the in-webview navigation is cancelled — the embedded webview
// never consumes the `openid-vc://` URL itself.
- (void)handleOpenIdVcNavigationAction:(NSURL *)requestURL
                       decisionHandler:(nullable void (^)(WKNavigationActionPolicy))decisionHandler
{
    id<MSIDOpenIdVcHandling> handler = self.openIdVcHandler;
    if (handler != nil)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                          @"Detected openid-vc:// navigation; delegating to registered handler.");

        // Weak/strong dance: the handler is weak, so no retain cycle through the
        // property — but the completion block still extends the controller's
        // lifetime for as long as the handler holds it, which could be a long
        // time once an SSO extension hosts VID in-process.
        __weak typeof(self) weakSelf = self;
        [handler handleOpenIdVcURL:requestURL
                 webviewController:self
                 callerRedirectUri:self.endURL.absoluteString
                     correlationId:self.context.correlationId
                        completion:^(NSError * _Nullable error)
        {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error)
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, strongSelf.context,
                                      @"openid-vc handler reported error; ending auth session: %@",
                                      MSID_PII_LOG_MASKABLE(error));
                [strongSelf endWebAuthWithURL:nil error:error];
            }
        }];

        if (decisionHandler) decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

#if TARGET_OS_IPHONE
    if ([MSIDAppExtensionUtil isExecutingInAppExtension])
    {
        NSError *extensionError = MSIDCreateError(MSIDErrorDomain,
                                                  MSIDErrorAttemptToOpenURLFromExtension,
                                                  @"unable to open openid-vc URL from extension",
                                                  nil, nil, nil, self.context.correlationId, nil, YES);
        [self endWebAuthWithURL:nil error:extensionError];
        if (decisionHandler) decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    NSURL *handoffURL = [self openIdVcURLWithCallerContext:requestURL];

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context,
                          @"Detected openid-vc:// navigation; opening wallet at %@ "
                          @"while keeping auth webview presented.",
                          [handoffURL msidPIINullifiedURL]);

    [self openOpenIdVcHandoffURL:handoffURL];

    // Cancel the in-webview navigation but DO NOT call completeWebAuthWithURL: or
    // endWebAuthWithURL:. The webview stays presented so the user returns to it
    // after the wallet completes. The verifier's page is responsible for driving
    // the webview to its terminal state once the VID exchange succeeds.
    if (decisionHandler) decisionHandler(WKNavigationActionPolicyCancel);
#else
    // macOS / unsupported platforms: VID flows are not supported here.
    // openid-vc:// is iOS-only by product scope, so this branch is not expected
    // to be reached. Cancel the navigation and leave the auth session alone —
    // there's no wallet to hand off to and no error contract to surface.
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context,
                      @"openid-vc:// scheme is not supported on this platform.");
    if (decisionHandler) decisionHandler(WKNavigationActionPolicyCancel);
#endif
}

// Wraps the actual `UIApplication.openURL:` call so tests can subclass the
// controller and override this method to capture the URL without hitting
// UIKit (`[UIApplication sharedApplication]` is nil in logic-test targets).
- (void)openOpenIdVcHandoffURL:(NSURL *)url
{
#if TARGET_OS_IPHONE
    [MSIDAppExtensionUtil sharedApplicationOpenURL:url];
#endif
}

// Appends Microsoft-namespaced query parameters (x_ms_caller_redirect_uri,
// x_ms_caller_bundle_id, x_ms_correlation_id) so the wallet can bounce the user
// back to the calling app when the VID flow completes. Falls back to the original
// URL if the calling-app redirect URI is unavailable or URL parsing fails — non-
// Microsoft wallets that handle openid-vc:// will simply ignore unknown parameters.
- (NSURL *)openIdVcURLWithCallerContext:(NSURL *)originalURL
{
    NSString *callerRedirectUri = self.endURL.absoluteString;
    if ([NSString msidIsStringNilOrBlank:callerRedirectUri])
    {
        return originalURL;
    }

    NSURLComponents *components = [NSURLComponents componentsWithURL:originalURL
                                              resolvingAgainstBaseURL:NO];
    if (!components)
    {
        return originalURL;
    }

    NSMutableArray<NSURLQueryItem *> *items = [components.queryItems mutableCopy] ?: [NSMutableArray new];

    [self appendQueryItem:items
                     name:MSID_OPENID_VC_CALLER_REDIRECT_URI_KEY
                    value:callerRedirectUri];
    [self appendQueryItem:items
                     name:MSID_OPENID_VC_CALLER_BUNDLE_ID_KEY
                    value:NSBundle.mainBundle.bundleIdentifier];
    [self appendQueryItem:items
                     name:MSID_OPENID_VC_CORRELATION_ID_KEY
                    value:self.context.correlationId.UUIDString];

    components.queryItems = items;
    return components.URL ?: originalURL;
}

- (void)appendQueryItem:(NSMutableArray<NSURLQueryItem *> *)items
                   name:(NSString *)name
                  value:(NSString *)value
{
    if ([NSString msidIsStringNilOrBlank:value]) return;

    for (NSURLQueryItem *item in items)
    {
        if ([item.name isEqualToString:name]) return;  // idempotent
    }

    [items addObject:[NSURLQueryItem queryItemWithName:name value:value]];
}

@end

#endif
