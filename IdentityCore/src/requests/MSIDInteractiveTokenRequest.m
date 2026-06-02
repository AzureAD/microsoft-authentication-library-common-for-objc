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

#import "MSIDInteractiveTokenRequest+Internal.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAuthority.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDTokenResult.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTokenResponseHandler.h"
#import "MSIDAccount.h"
#import "NSError+MSIDServerTelemetryError.h"
#import "MSIDAuthorizationCodeResult.h"
#import "MSIDAuthorizationCodeGrantRequest.h"
#import "MSIDOauth2Factory.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDRefreshToken.h"
#import "MSIDConfiguration.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDExternalRedirectContext.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDKeychainUtil.h"

#if TARGET_OS_IPHONE
#import "MSIDAppExtensionUtil.h"
#import "MSIDBackgroundTaskManager.h"
#endif

#if TARGET_OS_OSX && !EXCLUDE_FROM_MSALCPP
#import "MSIDExternalAADCacheSeeder.h"
#endif

@interface MSIDInteractiveTokenRequest()

@property (nonatomic) MSIDTokenResponseHandler *tokenResponseHandler;

@end

@implementation MSIDInteractiveTokenRequest

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                      oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
                            tokenResponseValidator:(nonnull MSIDTokenResponseValidator *)tokenResponseValidator
                                        tokenCache:(nonnull id<MSIDCacheAccessor>)tokenCache
                              accountMetadataCache:(nullable MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                                extendedTokenCache:(nullable id<MSIDExtendedTokenCacheDataSource>)extendedTokenCache
{
    self = [super initWithRequestParameters:parameters oauthFactory:oauthFactory];

    if (self)
    {
        _tokenResponseValidator = tokenResponseValidator;
        _tokenCache = tokenCache;
        _accountMetadataCache = accountMetadataCache;
        _tokenResponseHandler = [MSIDTokenResponseHandler new];
        _extendedTokenCache = extendedTokenCache;
    }

    return self;
}

- (void)executeRequestWithCompletion:(nonnull MSIDInteractiveRequestCompletionBlock) __unused completionBlock
{
#if !EXCLUDE_FROM_MSALCPP
#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] startOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#endif
    
    [self updateCustomHeadersForFRTSupportIfNeeded];

    [self installExternalRedirectHook];

    [super getAuthCodeWithCompletion:^(MSIDAuthorizationCodeResult * _Nullable result, NSError * _Nullable error, MSIDWebWPJResponse * _Nullable installBrokerResponse)
    {
        if (!result)
        {
            completionBlock(nil, error, installBrokerResponse);
            return;
        }
        
        [self.requestParameters updateAppRequestMetadata:result.accountIdentifier];
        
        [self acquireTokenWithCodeResult:result completion:completionBlock];
    }];
#endif
}

#pragma mark - External redirect hook

// Microsoft's Apple Developer Team ID — used to sign Microsoft 1P apps
// (Authenticator, Teams, Outlook, OneDrive, Edge, Office, etc.). The
// external-redirect notifier is gated to this Team ID because the host
// block (e.g. OneAuth's BRT seeder) is intended only for Microsoft 1P
// callers; third-party MSAL consumers MUST NOT receive the parent
// webview / shared cache handle.
static NSString * const kMSIDMicrosoft1PTeamId = @"UBF8T346G9";

// Returns YES iff the currently-running process is signed by Microsoft.
// Result is cached (Team ID does not change during process lifetime).
static BOOL MSIDIsMicrosoft1PHostProcess(void)
{
    static BOOL isMicrosoft1P = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *teamId = [MSIDKeychainUtil sharedInstance].teamId;
        isMicrosoft1P = teamId.length > 0 && [teamId isEqualToString:kMSIDMicrosoft1PTeamId];
    });
    return isMicrosoft1P;
}

// Wraps the existing externalDecidePolicyForBrowserAction chain. When the
// embedded webview is about to leave for an external redirect (e.g.
// browser:// or msauth://), build a passive MSIDExternalRedirectContext
// snapshot and hand it to the host's externalRedirectURLAction block (if
// configured). IdentityCore does not act on the redirect itself — the host
// (typically OneAuth) decides whether to mount any secondary flow. Fires
// at most once per interactive request, and only when the host process is
// signed by Microsoft (1P apps only).
- (void)installExternalRedirectHook
{
    if (!self.requestParameters.externalRedirectURLAction) return;

    if (!MSIDIsMicrosoft1PHostProcess())
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                          @"[ExternalRedirectHook] Host process is not Microsoft 1P; skipping hook installation.");
        return;
    }

    MSIDExternalDecidePolicyForBrowserActionBlock previous = self.externalDecidePolicyForBrowserAction;
    __weak typeof(self) weakSelf = self;
    __block BOOL hostNotified = NO;

    self.externalDecidePolicyForBrowserAction = ^NSURLRequest *(MSIDOAuth2EmbeddedWebviewController *webViewCtrl, NSURL *url)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        MSIDExternalRedirectURLActionBlock hostBlock = strongSelf.requestParameters.externalRedirectURLAction;

        if (strongSelf && hostBlock && !hostNotified)
        {
            hostNotified = YES;
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, strongSelf.requestParameters,
                              @"[ExternalRedirectHook] Redirect intercepted (scheme=%@, host=%@). Notifying host.",
                              url.scheme, url.host);

            MSIDExternalRedirectContext *context =
                [[MSIDExternalRedirectContext alloc] initWithRedirectURL:url
                                                        correlationId:strongSelf.requestParameters.correlationId
                                                            loginHint:strongSelf.requestParameters.loginHint
                                                      parentAuthority:strongSelf.requestParameters.authority
                                        parentExtraURLQueryParameters:strongSelf.requestParameters.extraURLQueryParameters
                                                        parentWebView:webViewCtrl.webView
                                                           tokenCache:strongSelf.tokenCache
                                                 accountMetadataCache:strongSelf.accountMetadataCache
                                                         oauthFactory:strongSelf.oauthFactory];
            hostBlock(context);
        }
        return previous ? previous(webViewCtrl, url) : nil;
    };
}

#pragma mark - Helpers

- (void)acquireTokenWithCodeResult:(MSIDAuthorizationCodeResult *) __unused authCodeResult
                        completion:(MSIDInteractiveRequestCompletionBlock) __unused completionBlock
{
#if !EXCLUDE_FROM_MSALCPP
    MSIDAuthorizationCodeGrantRequest *tokenRequest = [self.oauthFactory authorizationGrantRequestWithRequestParameters:self.requestParameters
                                                                                                           codeVerifier:authCodeResult.pkceVerifier
                                                                                                               authCode:authCodeResult.authCode
                                                                                                          homeAccountId:authCodeResult.accountIdentifier];

    [tokenRequest sendWithBlock:^(MSIDTokenResponse *tokenResponse, NSError *error)
    {
#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#elif TARGET_OS_OSX
    self.tokenResponseHandler.externalCacheSeeder = self.externalCacheSeeder;
#endif
        [self.tokenResponseHandler handleTokenResponse:tokenResponse
                                     requestParameters:self.requestParameters
                                         homeAccountId:authCodeResult.accountIdentifier
                                tokenResponseValidator:self.tokenResponseValidator
                                          oauthFactory:self.oauthFactory
                                            tokenCache:self.tokenCache
                                  accountMetadataCache:self.accountMetadataCache
                                       validateAccount:self.requestParameters.shouldValidateResultAccount
                                      saveSSOStateOnly:NO
                                      brokerAppVersion:nil
                     brokerResponseGenerationTimeStamp:nil
                        brokerRequestReceivedTimeStamp:nil
                                                 error:error
                                       completionBlock:^(MSIDTokenResult *result, NSError *localError)
         {
            completionBlock(result, localError, nil);
        }];
    }];
#endif
}

- (void)updateCustomHeadersForFRTSupportIfNeeded
{
#if !EXCLUDE_FROM_MSALCPP && !AD_BROKER
    
    BOOL enableFRT = NO;
    
    if (self.tokenCache && [self.tokenCache isKindOfClass:MSIDDefaultTokenCacheAccessor.class])
    {
        MSIDAccountCredentialCache *credentialCache = ((MSIDDefaultTokenCacheAccessor *)self.tokenCache).accountCredentialCache;
        if (credentialCache)
        {
            NSError *error = nil;
            MSIDIsFRTEnabledStatus frtEnabledStatus = [credentialCache checkFRTEnabled:self.requestParameters error:&error];
            enableFRT = (frtEnabledStatus == MSIDIsFRTEnabledStatusEnabled);
            
            if (error)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Error when checking if FRT is enabled: error code: %@", error);
            }
        }
    }
    
    if (enableFRT &&
        self.requestParameters.promptType != MSIDPromptTypeLogin &&
        self.requestParameters.promptType != MSIDPromptTypeCreate)
    {
        NSMutableDictionary *customHeaders = nil;
        if (self.requestParameters.customWebviewHeaders)
        {
            customHeaders = [self.requestParameters.customWebviewHeaders mutableCopy];
        }
        else
        {
            customHeaders = [NSMutableDictionary new];
        }
        
        // Always include `x-ms-sso-Ignore-SSO` header with or without a refresh token
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Added ignore sso to custom headers for webview");
        customHeaders[MSID_WEBAUTH_IGNORE_SSO_KEY] = @"1";
        
        NSString *refreshToken = nil;
        refreshToken = [self getRefreshTokenForRequest];
        
        if (![NSString msidIsStringNilOrBlank:refreshToken])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Included refresh token to custom headers for webview");
            customHeaders[MSID_WEBAUTH_REFRESH_TOKEN_KEY] = refreshToken;
        }
        
        self.requestParameters.customWebviewHeaders = customHeaders;
    }
#endif
}

- (NSString *)getRefreshTokenForRequest
{
#if !EXCLUDE_FROM_MSALCPP
    NSError *refreshTokenError = nil;
    MSIDRefreshToken *refreshTokenItem = [self.tokenCache getRefreshTokenWithAccount:self.requestParameters.accountIdentifier
                                                                            familyId:nil
                                                                       configuration:self.requestParameters.msidConfiguration
                                                                             context:self.requestParameters
                                                                               error:&refreshTokenError];

     // FRT is more likely to be valid as it gets refreshed if any app in the family uses it, so try to use the FRT instead (unless it already fot a family refresh token)
    if (!refreshTokenItem || (refreshTokenItem.credentialType != MSIDFamilyRefreshTokenType && ![NSString msidIsStringNilOrBlank:[refreshTokenItem familyId]]))
    {
        NSError *msidFRTError = nil;
        NSString *familyId = [NSString msidIsStringNilOrBlank:[refreshTokenItem familyId]] ? @"1" : [refreshTokenItem familyId];
        MSIDRefreshToken *frtItem = [self.tokenCache getRefreshTokenWithAccount:self.requestParameters.accountIdentifier
                                                                       familyId:familyId
                                                                  configuration:self.requestParameters.msidConfiguration
                                                                        context:self.requestParameters
                                                                          error:&msidFRTError];
        if (frtItem && !msidFRTError)
        {
            refreshTokenItem = frtItem;
            refreshTokenError = nil;
        }
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Retrieve refresh token from cache for web view: %@, error code: %ld", _PII_NULLIFY(refreshTokenItem), refreshTokenError.code);
    
    return [refreshTokenItem refreshToken];
#else
    return nil;
#endif
}

- (void)dealloc
{
#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#endif
}

@end
