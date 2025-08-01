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

#import "MSIDAADWebviewFactory.h"
#import "MSIDAuthorizeWebRequestConfiguration.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDWebWPJResponse.h"
#import "MSIDWebUpgradeRegResponse.h"
#import "MSIDWebAADAuthCodeResponse.h"
#import "MSIDDeviceId.h"
#import "MSIDAADOAuthEmbeddedWebviewController.h"
#import "MSIDWebviewSession.h"
#import "MSIDWebOpenBrowserResponse.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDAuthority.h"
#import "MSIDCBAWebAADAuthResponse.h"
#import "MSIDClaimsRequest+ClientCapabilities.h"
#import "MSIDSignoutWebRequestConfiguration.h"
#import "NSURL+MSIDAADUtils.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDSwitchBrowserResponse.h"
#import "MSIDSwitchBrowserResumeResponse.h"
#import "MSIDFlightManager.h"

#if !EXCLUDE_FROM_MSALCPP
#import "MSIDJITTroubleshootingResponse.h"
#endif

@implementation MSIDAADWebviewFactory

- (NSMutableDictionary<NSString *, NSString *> *)authorizationParametersFromRequestParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                                                                         pkce:(MSIDPkce *)pkce
                                                                                 requestState:(NSString *)state
{
    NSMutableDictionary<NSString *, NSString *> *result = [super authorizationParametersFromRequestParameters:parameters
                                                                                                         pkce:pkce
                                                                                                 requestState:state];
    
    if (parameters.instanceAware) result[@"instance_aware"] = @"true";
    
    MSIDClaimsRequest *claimsRequest = [MSIDClaimsRequest claimsRequestFromCapabilities:parameters.clientCapabilities
                                                                          claimsRequest:parameters.claimsRequest];
    NSString *claims = [[claimsRequest jsonDictionary] msidJSONSerializeWithContext:parameters];
    
    result[MSID_OAUTH2_CLAIMS] = claims;

    return result;
}

- (NSDictionary<NSString *, NSString *> *)metadataFromRequestParameters:(MSIDInteractiveRequestParameters *)parameters
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    [result addEntriesFromDictionary:[super metadataFromRequestParameters:parameters]];
    
    if (parameters.correlationId)
    {
        [result addEntriesFromDictionary:
         @{
            MSID_OAUTH2_CORRELATION_ID_REQUEST : @"true",
            MSID_OAUTH2_CORRELATION_ID_REQUEST_VALUE : [parameters.correlationId UUIDString]
        }];
    }
    
    result[@"haschrome"] = @"1";
    [result addEntriesFromDictionary:MSIDDeviceId.deviceId];
    
#if TARGET_OS_IPHONE
    if ([MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_SUPPORT_DUNA_CBA])
    {
        // Let server know that we support new cba flow
        result[MSID_BROWSER_RESPONSE_SWITCH_BROWSER] = @"1";
    }
#endif
    
    return result;
}

#if !MSID_EXCLUDE_WEBKIT

- (NSObject<MSIDWebviewInteracting> *)embeddedWebviewFromConfiguration:(MSIDBaseWebRequestConfiguration *)configuration
                                                         customWebview:(WKWebView *)webview
                                  externalDecidePolicyForBrowserAction:(MSIDExternalDecidePolicyForBrowserActionBlock)externalDecidePolicyForBrowserAction
                                                               context:(id<MSIDRequestContext>)context
{
    if (![NSThread isMainThread])
    {
        __block NSObject<MSIDWebviewInteracting> *session;
        dispatch_sync(dispatch_get_main_queue(), ^{
            session = [self embeddedWebviewFromConfiguration:configuration
                                               customWebview:webview
                        externalDecidePolicyForBrowserAction:externalDecidePolicyForBrowserAction
                                                     context:context];
        });
        
        return session;
    }
    
    MSIDWebViewPlatformParams *platformParams = nil;
    
    if (configuration.ssoContext)
    {
        platformParams = [[MSIDWebViewPlatformParams alloc] initWithExternalSSOContext:configuration.ssoContext];
    }
    
    MSIDAADOAuthEmbeddedWebviewController *embeddedWebviewController
      = [[MSIDAADOAuthEmbeddedWebviewController alloc] initWithStartURL:configuration.startURL
                                                                 endURL:[NSURL URLWithString:configuration.endRedirectUrl]
                                                                webview:webview
                                                          customHeaders:configuration.customHeaders
                                                         platfromParams:platformParams
                                                                context:context];
                                                                
#if MSAL_JS_AUTOMATION
    embeddedWebviewController.clientAutomationScript = configuration.clientAutomationScript;
#endif
    
#if TARGET_OS_IPHONE
    embeddedWebviewController.parentController = configuration.parentController;
    embeddedWebviewController.presentationType = configuration.presentationType;
#endif
    
    embeddedWebviewController.externalDecidePolicyForBrowserAction = externalDecidePolicyForBrowserAction;
    embeddedWebviewController.customHeaderProvider = configuration.customHeaderProvider;

    return embeddedWebviewController;
}

#endif

- (MSIDWebviewResponse *)oAuthResponseWithURL:(NSURL *)url
                                 requestState:(NSString *)requestState
                           ignoreInvalidState:(BOOL)ignoreInvalidState
                               endRedirectUri:(NSString *)endRedirectUri
                                      context:(id<MSIDRequestContext>)context
                                        error:(NSError *__autoreleasing*)error
{
    // Try to create CBA response
#if AD_BROKER
    MSIDCBAWebAADAuthResponse *cbaResponse = [[MSIDCBAWebAADAuthResponse alloc] initWithURL:url context:context error:nil];
    if (cbaResponse) return cbaResponse;
    
    if ([url.absoluteString containsString:[NSString stringWithFormat:@"%@=", MSID_SSO_NONCE_QUERY_PARAM_KEY]])
    {
        NSString *ssoNonce = [[url msidQueryParameters] valueForKey:MSID_SSO_NONCE_QUERY_PARAM_KEY];
        if (![NSString msidIsStringNilOrBlank:ssoNonce] && error)
        {
            NSDictionary *userInfo = @{MSID_SSO_NONCE_QUERY_PARAM_KEY : ssoNonce};
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorAuthorizationFailed, @"Nonce in JWT headers is likely expired, received SSO nonce redirect response.", nil, nil, nil, context.correlationId, userInfo, NO);
            return nil;
        }
    }
    
#if !EXCLUDE_FROM_MSALCPP
    // Try to create JIT troubleshooting response
    MSIDJITTroubleshootingResponse *jitResponse = [[MSIDJITTroubleshootingResponse alloc] initWithURL:url context:context error:nil];
    if (jitResponse)
    {
        // Get error from response's status
        NSError *jitError = [jitResponse getErrorFromResponseWithContext:context];
        if (jitError && error)
        {
            *error = jitError;
        }
        
        return nil;
    }
#endif
    
#endif

    // Try to create a upgrade registration response
    MSIDWebUpgradeRegResponse *upgradeRegResponse = [[MSIDWebUpgradeRegResponse alloc] initWithURL:url context:context error:nil];
    if (upgradeRegResponse) return upgradeRegResponse;

    // Try to create a WPJ response
    MSIDWebWPJResponse *wpjResponse = [[MSIDWebWPJResponse alloc] initWithURL:url context:context error:nil];
    if (wpjResponse) return wpjResponse;
    
    // Try to create a browser response
    MSIDWebOpenBrowserResponse *browserResponse = [[MSIDWebOpenBrowserResponse alloc] initWithURL:url
                                                                                          context:context
                                                                                            error:nil];
    if (browserResponse) return browserResponse;
    
    if ([MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_SUPPORT_DUNA_CBA])
    {
        MSIDSwitchBrowserResponse *switchBrowserResponse = [[MSIDSwitchBrowserResponse alloc] initWithURL:url
                                                                                              redirectUri:endRedirectUri
                                                                                             requestState:requestState
                                                                                                  context:context
                                                                                                    error:nil];
        if (switchBrowserResponse) return switchBrowserResponse;
        
        MSIDSwitchBrowserResumeResponse *switchBrowserResumeResponse = [[MSIDSwitchBrowserResumeResponse alloc] initWithURL:url
                                                                                                                redirectUri:endRedirectUri
                                                                                                               requestState:requestState
                                                                                                                    context:context
                                                                                                                      error:nil];
        if (switchBrowserResumeResponse) return switchBrowserResumeResponse;
    }
    
    // Try to create AAD Auth response or Error response (all other reponses don't handle errors).
    MSIDWebAADAuthCodeResponse *response = [[MSIDWebAADAuthCodeResponse alloc] initWithURL:url
                                                                              requestState:requestState
                                                                        ignoreInvalidState:ignoreInvalidState
                                                                                   context:context
                                                                                     error:error];
    
    return response;
}

@end
