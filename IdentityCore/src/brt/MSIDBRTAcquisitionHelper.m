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

#if !MSID_EXCLUDE_WEBKIT

#import "MSIDBRTAcquisitionHelper.h"
#import "MSIDAuthority.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDInteractiveTokenRequest.h"
#import "MSIDInteractiveTokenRequest+Internal.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDRequestContext.h"
#import "MSIDAuthenticationScheme.h"

static NSString *const kMSIDBRTBrokerClientId = @"29d9ed98-a469-4536-ade2-f981bc1d605e";
static NSString *const kMSIDBRTBrokerRedirectUri = @"msauth://Microsoft.AAD.BrokerPlugin";
static NSString *const kMSIDBRTUpdatePRTScope = @"urn:aad:tb:update:prt/.default";

@implementation MSIDBRTAcquisitionHelper

+ (void)acquireBRTWithWebView:(WKWebView *)webview
                    authority:(MSIDAuthority *)authority
                        cache:(id<MSIDCacheAccessor>)cache
                      context:(id<MSIDRequestContext>)context
                   completion:(nullable void (^)(BOOL didSucceed, NSError * _Nullable error))completion
{
    if (!webview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                          @"BRT acquisition: missing required parameter (webview=nil).");
        if (completion) completion(NO, nil);
        return;
    }
    if (!authority)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                          @"BRT acquisition: missing required parameter (authority=nil).");
        if (completion) completion(NO, nil);
        return;
    }
    if (!cache)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                          @"BRT acquisition: missing required parameter (cache=nil).");
        if (completion) completion(NO, nil);
        return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"BRT acquisition: starting synchronous flow.");

    // Clone WebView — inherits cookies via shared WKWebsiteDataStore
    WKWebView *brtWebView = [[WKWebView alloc] initWithFrame:CGRectZero
                                               configuration:webview.configuration];

    NSError *error = nil;

    // Local non-null aliases for the analyzer.
    MSIDAuthority * _Nonnull nonnullAuthority = authority;
    MSIDAuthenticationScheme * _Nonnull nonnullAuthScheme = [MSIDAuthenticationScheme new];

    // Build params with Broker's identity
    MSIDInteractiveTokenRequestParameters *params =
        [[MSIDInteractiveTokenRequestParameters alloc]
            initWithAuthority:nonnullAuthority
                   authScheme:nonnullAuthScheme
                  redirectUri:kMSIDBRTBrokerRedirectUri
                     clientId:kMSIDBRTBrokerClientId
                       scopes:[NSOrderedSet orderedSetWithObject:kMSIDBRTUpdatePRTScope]
                   oidcScopes:[NSOrderedSet orderedSetWithObjects:
                               @"openid", @"profile", @"offline_access", nil]
         extraScopesToConsent:nil
                correlationId:[NSUUID UUID]
               telemetryApiId:@"brt_seeding"
                brokerOptions:nil
                  requestType:MSIDRequestLocalType
          intuneAppIdentifier:nil
                        error:&error];

    if (!params)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                          @"BRT acquisition: failed to create params: %@", error.localizedDescription);
        if (completion) completion(NO, error);
        return;
    }

    // prompt=none: ESTS uses session cookies from cloned webview, no UI
    params.webviewType = MSIDWebviewTypeWKWebView;
    params.customWebview = brtWebView;
    params.promptType = MSIDPromptTypeNever; // prompt=none: silent via session cookies
    params.extraAuthorizeURLQueryParameters = @{
        @"x-ms-brt-bootstrap" : @"1"
    };
    params.shouldValidateResultAccount = NO;
    params.allowConcurrentWebviewSession = YES;
    params.saveSSOStateOnly = YES;

    // Create request directly (avoids controller recursion)
    MSIDAADV2Oauth2Factory *oauthFactory = [MSIDAADV2Oauth2Factory new];
    MSIDDefaultTokenResponseValidator *validator = [MSIDDefaultTokenResponseValidator new];

    MSIDInteractiveTokenRequest *request =
        [[MSIDInteractiveTokenRequest alloc]
            initWithRequestParameters:params
                         oauthFactory:oauthFactory
               tokenResponseValidator:validator
                           tokenCache:cache
                 accountMetadataCache:nil
                   extendedTokenCache:nil];

    if (!request)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                          @"BRT acquisition: failed to create token request.");
        if (completion) completion(NO, nil);
        return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"BRT acquisition: executing request synchronously.");

    // Retain webview for lifetime of request
    __block WKWebView *retainedWebView = brtWebView;

    [request executeRequestWithCompletion:^(MSIDTokenResult * __unused result, NSError *requestError, MSIDWebviewResponse * __unused wpjResponse)
    {
        retainedWebView = nil;

        if (requestError)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                              @"BRT acquisition failed: code=%ld domain=%@",
                              (long)requestError.code, requestError.domain);
            if (completion) completion(NO, requestError);
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"BRT stored successfully in shared keychain.");
            if (completion) completion(YES, nil);
        }
    }];
}

@end

#endif
