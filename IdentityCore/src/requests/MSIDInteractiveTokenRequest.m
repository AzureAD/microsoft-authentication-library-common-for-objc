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
        self.requestParameters.promptType != MSIDPromptTypeSelectAccount &&
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
        
        NSString *refreshToken = nil;
        refreshToken = [self getRefreshTokenForRequest];
        
        if (![NSString msidIsStringNilOrBlank:refreshToken])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Included refresh token to custom headers for webview");
            customHeaders[MSID_WEBAUTH_REFRESH_TOKEN_KEY] = refreshToken;
 
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Added ignore sso to custom headers for webview");
            customHeaders[MSID_WEBAUTH_IGNORE_SSO_KEY] = @"1";
            
            self.requestParameters.customWebviewHeaders = customHeaders;
        }
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
