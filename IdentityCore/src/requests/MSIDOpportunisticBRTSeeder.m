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

#import "MSIDOpportunisticBRTSeeder.h"
#import <WebKit/WebKit.h>
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAuthority.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDLogger+Internal.h"
#import "MSIDOauth2Factory.h"
#import "MSIDPkce.h"
#import "MSIDAADAuthorizationCodeGrantRequest.h"
#import "MSIDAADTokenResponseSerializer.h"
#import "MSIDTokenResponse.h"
#import "MSIDConfiguration.h"
#import "MSIDCacheAccessor.h"
#import "MSIDAuthenticationScheme.h"
#import "MSIDConstants.h"

#if TARGET_OS_IPHONE
#import "MSIDBackgroundTaskManager.h"
#endif

static NSString *const ADB_BROKER_CLIENT_ID         = @"29d9ed98-a469-4536-ade2-f981bc1d605e";
static NSString *const ADB_BROKER_REDIRECT_URI      = @"msauth://Microsoft.AAD.BrokerPlugin";
static NSString *const ADB_BROKER_UPDATE_PRT_SCOPE  = @"urn:aad:tb:update:prt/.default";

#pragma mark - Hidden webview driver

/**
 Owns a short-lived, off-screen WKWebView. Loads the authorize URL, watches for
 the broker msauth:// redirect, cancels that navigation, extracts the auth code,
 and reports back via the completion block.

 The driver retains itself (strong self-reference cleared in completion) so the
 caller does not need to keep a pointer.
 */
@interface MSIDBRTSeederWebviewDriver : NSObject <WKNavigationDelegate>

@property (nonatomic, strong) WKWebView *hiddenWebView;
@property (nonatomic, strong) id strongSelf;
@property (nonatomic, copy)   void (^completion)(NSString *code, NSString *errorCode, NSString *errorDescription);
@property (nonatomic, strong) id<MSIDRequestContext> context;
@property (nonatomic, assign) BOOL completed;

- (instancetype)initWithParentWebView:(WKWebView *)parentWebView
                              context:(id<MSIDRequestContext>)context;

- (void)loadAuthorizeURL:(NSURL *)authorizeURL
              completion:(void (^)(NSString *code, NSString *errorCode, NSString *errorDescription))completion;

@end

@implementation MSIDBRTSeederWebviewDriver

- (instancetype)initWithParentWebView:(WKWebView *)parentWebView
                              context:(id<MSIDRequestContext>)context
{
    if (!(self = [super init])) return nil;

    _context = context;

    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    // Share *only* the website data store so AAD session cookies are reused.
    // Do NOT share the processPool: doing so makes WebKit treat the hidden
    // webview as part of the parent's browsing context, which causes the
    // parent's in-flight navigation to be torn down the moment we load.
    if (parentWebView.configuration.websiteDataStore)
    {
        config.websiteDataStore = parentWebView.configuration.websiteDataStore;
    }

    _hiddenWebView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)
                                        configuration:config];
    _hiddenWebView.navigationDelegate = self;
    _hiddenWebView.hidden = YES;

    return self;
}

- (void)loadAuthorizeURL:(NSURL *)authorizeURL
              completion:(void (^)(NSString *code, NSString *errorCode, NSString *errorDescription))completion
{
    self.completion = completion;
    self.strongSelf = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSURLRequest *request = [NSURLRequest requestWithURL:authorizeURL];
        [self.hiddenWebView loadRequest:request];
    });
}

- (void)finishWithCode:(NSString *)code
             errorCode:(NSString *)errorCode
      errorDescription:(NSString *)errorDescription
{
    @synchronized (self)
    {
        if (self.completed) return;
        self.completed = YES;
    }

    void (^completion)(NSString *, NSString *, NSString *) = self.completion;
    self.completion = nil;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.hiddenWebView stopLoading];
        self.hiddenWebView.navigationDelegate = nil;
        self.hiddenWebView = nil;

        if (completion) completion(code, errorCode, errorDescription);
        self.strongSelf = nil;
    });
}

#pragma mark - WKNavigationDelegate

- (void)webView:(__unused WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *url = navigationAction.request.URL;
    NSString *scheme = url.scheme.lowercaseString;

    if ([scheme isEqualToString:@"msauth"])
    {
        decisionHandler(WKNavigationActionPolicyCancel);

        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        NSString *code = nil;
        NSString *errCode = nil;
        NSString *errDesc = nil;
        for (NSURLQueryItem *item in components.queryItems)
        {
            if      ([item.name isEqualToString:@"code"])              code    = item.value;
            else if ([item.name isEqualToString:@"error"])             errCode = item.value;
            else if ([item.name isEqualToString:@"error_description"]) errDesc = item.value;
        }

        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                          @"[BRT seeder POC] Hidden webview captured msauth:// redirect (codePresent=%d errorPresent=%d).",
                          code.length > 0, errCode.length > 0);

        [self finishWithCode:code errorCode:errCode errorDescription:errDesc];
        return;
    }

    if ([scheme isEqualToString:@"browser"])
    {
        // Sub-webview should never follow browser:// — just cancel and report.
        decisionHandler(WKNavigationActionPolicyCancel);
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                          @"[BRT seeder POC] Hidden webview saw browser:// — ESTS wants external action. Aborting seed.");
        [self finishWithCode:nil errorCode:@"browser_redirect" errorDescription:nil];
        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(__unused WKWebView *)webView
didFailProvisionalNavigation:(__unused WKNavigation *)navigation
      withError:(NSError *)error
{
    // msauth:// cancellation produces a WebKit "unsupported URL" error after we cancel.
    // Ignore once we've already captured the code.
    @synchronized (self)
    {
        if (self.completed) return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                      @"[BRT seeder POC] Hidden webview provisional nav failed: %@", error);
    [self finishWithCode:nil errorCode:@"nav_failed" errorDescription:error.localizedDescription];
}

- (void)webView:(__unused WKWebView *)webView
didFailNavigation:(__unused WKNavigation *)navigation
      withError:(NSError *)error
{
    @synchronized (self)
    {
        if (self.completed) return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                      @"[BRT seeder POC] Hidden webview nav failed: %@", error);
    [self finishWithCode:nil errorCode:@"nav_failed" errorDescription:error.localizedDescription];
}

@end

#pragma mark - Seeder

@implementation MSIDOpportunisticBRTSeeder

+ (NSMutableSet<NSString *> *)inflightCorrelationIds
{
    static NSMutableSet *set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSMutableSet new];
    });
    return set;
}

+ (BOOL)markInflightForCorrelationId:(NSString *)correlationId
{
    @synchronized([self inflightCorrelationIds])
    {
        if ([[self inflightCorrelationIds] containsObject:correlationId])
        {
            return NO;
        }
        [[self inflightCorrelationIds] addObject:correlationId];
        return YES;
    }
}

+ (void)clearInflightForCorrelationId:(NSString *)correlationId
{
    @synchronized([self inflightCorrelationIds])
    {
        [[self inflightCorrelationIds] removeObject:correlationId];
    }
}

+ (void)finishWithCorrelationId:(NSString *)correlationKey
{
    [self clearInflightForCorrelationId:correlationKey];
#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#endif
}

+ (void)seedWithParentParameters:(MSIDInteractiveTokenRequestParameters *)parentParameters
                         webView:(WKWebView *)webView
                      tokenCache:(id<MSIDCacheAccessor>)tokenCache
            accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                    oauthFactory:(MSIDOauth2Factory *)oauthFactory
          tokenResponseValidator:(MSIDTokenResponseValidator *)tokenResponseValidator
                         context:(id<MSIDRequestContext>)context
{
    if (!parentParameters || !webView || !tokenCache || !oauthFactory || !tokenResponseValidator)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                          @"[BRT seeder POC] Skipping seed: missing prerequisites (params=%d webview=%d cache=%d factory=%d validator=%d).",
                          parentParameters != nil, webView != nil, tokenCache != nil,
                          oauthFactory != nil, tokenResponseValidator != nil);
        return;
    }

    NSURL *authorizeEndpoint = parentParameters.authority.metadata.authorizationEndpoint;
    NSURL *tokenEndpoint     = parentParameters.tokenEndpoint;
    if (!authorizeEndpoint || !tokenEndpoint)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                          @"[BRT seeder POC] Skipping seed: authority metadata not resolved (authorize=%d token=%d).",
                          authorizeEndpoint != nil, tokenEndpoint != nil);
        return;
    }

    NSString *correlationKey = [parentParameters.correlationId UUIDString] ?: [[NSUUID UUID] UUIDString];
    if (![self markInflightForCorrelationId:correlationKey])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                          @"[BRT seeder POC] Skipping seed: already inflight for correlationId=%@.", correlationKey);
        return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                      @"[BRT seeder POC] Starting opportunistic seed (correlationId=%@).", correlationKey);

#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] startOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#endif

    // Capture parent values up front — the parent request may tear down soon.
    NSString *loginHint                = parentParameters.loginHint;
    NSUUID *correlationUUID            = parentParameters.correlationId ?: [NSUUID UUID];
    MSIDAuthenticationScheme *authScheme = parentParameters.authScheme;
    MSIDAuthority *authority           = parentParameters.authority;

    // Build authorize URL with broker clientId + redirect + scope + PKCE.
    MSIDPkce *pkce = [MSIDPkce new];
    NSString *state = [[NSUUID UUID] UUIDString];

    NSURLComponents *components = [NSURLComponents componentsWithURL:authorizeEndpoint resolvingAgainstBaseURL:NO];
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray new];
    [items addObject:[NSURLQueryItem queryItemWithName:@"client_id"             value:ADB_BROKER_CLIENT_ID]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"redirect_uri"          value:ADB_BROKER_REDIRECT_URI]];
    // Scope MUST include openid/profile/offline_access alongside the broker-PRT scope so ESTS
    // issues a code that exchanges to a refresh-token-bearing response. Without OIDC scopes
    // the token endpoint returns an empty 200 {} body.
    [items addObject:[NSURLQueryItem queryItemWithName:@"scope"                 value:[NSString stringWithFormat:@"%@ openid profile offline_access", ADB_BROKER_UPDATE_PRT_SCOPE]]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"response_type"         value:@"code"]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"response_mode"         value:@"query"]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"prompt"                value:@"none"]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"client_info"           value:@"1"]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"code_challenge"        value:pkce.codeChallenge]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"code_challenge_method" value:pkce.codeChallengeMethod]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"state"                 value:state]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"client-request-id"     value:[correlationUUID UUIDString]]];
    if (loginHint.length)
    {
        [items addObject:[NSURLQueryItem queryItemWithName:@"login_hint" value:loginHint]];
    }
    components.queryItems = items;

    NSURL *authorizeURL = components.URL;
    if (!authorizeURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                          @"[BRT seeder POC] Failed to build authorize URL.");
        [self finishWithCorrelationId:correlationKey];
        return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                      @"[BRT seeder POC] Driving hidden WKWebView to authorize endpoint (host=%@, prompt=none).",
                      authorizeEndpoint.host);

    MSIDBRTSeederWebviewDriver *driver =
        [[MSIDBRTSeederWebviewDriver alloc] initWithParentWebView:webView
                                                          context:context];

    [driver loadAuthorizeURL:authorizeURL
                  completion:^(NSString *authCode, NSString *errorCode, NSString *errorDescription)
    {
        if (errorCode || !authCode.length)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                              @"[BRT seeder POC] Authorize step did not yield a code (error=%@ desc=%@). Aborting seed.",
                              errorCode, errorDescription);
            [self finishWithCorrelationId:correlationKey];
            return;
        }

        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                          @"[BRT seeder POC] Authorize step succeeded — exchanging code for BRT.");

        [self exchangeCode:authCode
              codeVerifier:pkce.codeVerifier
             tokenEndpoint:tokenEndpoint
                 authority:authority
                authScheme:authScheme
             correlationId:correlationUUID
                tokenCache:tokenCache
      accountMetadataCache:accountMetadataCache
              oauthFactory:oauthFactory
    tokenResponseValidator:tokenResponseValidator
                   context:context
            correlationKey:correlationKey];
    }];
}

#pragma mark - Token exchange + persistence

+ (void)exchangeCode:(NSString *)authCode
        codeVerifier:(NSString *)codeVerifier
       tokenEndpoint:(NSURL *)tokenEndpoint
           authority:(MSIDAuthority *)authority
          authScheme:(MSIDAuthenticationScheme *)authScheme
       correlationId:(NSUUID *)correlationId
          tokenCache:(id<MSIDCacheAccessor>)tokenCache
accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
        oauthFactory:(MSIDOauth2Factory *)oauthFactory
tokenResponseValidator:(MSIDTokenResponseValidator *)tokenResponseValidator
             context:(id<MSIDRequestContext>)context
      correlationKey:(NSString *)correlationKey
{
    MSIDAADAuthorizationCodeGrantRequest *grant =
        [[MSIDAADAuthorizationCodeGrantRequest alloc] initWithEndpoint:tokenEndpoint
                                                            authScheme:authScheme
                                                              clientId:ADB_BROKER_CLIENT_ID
                                                          enrollmentId:nil
                                                                 scope:[NSString stringWithFormat:@"%@ openid profile offline_access", ADB_BROKER_UPDATE_PRT_SCOPE]
                                                           redirectUri:ADB_BROKER_REDIRECT_URI
                                                                  code:authCode
                                                                claims:nil
                                                          codeVerifier:codeVerifier
                                                       extraParameters:nil
                                                            ssoContext:nil
                                                               context:context];

    grant.responseSerializer = [[MSIDAADTokenResponseSerializer alloc] initWithOauth2Factory:oauthFactory];

    [grant sendWithBlock:^(id response, NSError *grantError)
    {
        if (grantError || ![response isKindOfClass:[MSIDTokenResponse class]])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                              @"[BRT seeder POC] Token exchange failed (correlationId=%@): %@", correlationKey, grantError);
            [self finishWithCorrelationId:correlationKey];
            return;
        }

        MSIDTokenResponse *tokenResponse = (MSIDTokenResponse *)response;

        // BRT/PRT-scope responses contain only a refresh_token (no access_token / id_token), so we
        // bypass MSIDTokenResponseHandler (which fails such responses with "without expected
        // accessToken") and persist the refresh token directly via saveSSOStateWithConfiguration.
        NSOrderedSet<NSString *> *scopes = [[NSOrderedSet alloc] initWithObject:ADB_BROKER_UPDATE_PRT_SCOPE];
        MSIDConfiguration *configuration =
            [[MSIDConfiguration alloc] initWithAuthority:authority
                                             redirectUri:ADB_BROKER_REDIRECT_URI
                                                clientId:ADB_BROKER_CLIENT_ID
                                                resource:nil
                                                  scopes:scopes];

        NSError *saveError = nil;
        BOOL saved = [tokenCache saveSSOStateWithConfiguration:configuration
                                                      response:tokenResponse
                                                       factory:oauthFactory
                                                       context:context
                                                         error:&saveError];

        if (!saved)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                              @"[BRT seeder POC] Failed to persist BRT into shared cache (correlationId=%@): %@",
                              correlationKey, saveError);
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                              @"[BRT seeder POC] BRT seeded successfully into shared cache (correlationId=%@). refreshTokenPresent=%d",
                              correlationKey, tokenResponse.refreshToken.length > 0);
        }
        [self finishWithCorrelationId:correlationKey];
    }];
}

@end
