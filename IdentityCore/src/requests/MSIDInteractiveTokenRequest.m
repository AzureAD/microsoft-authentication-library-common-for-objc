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

#import "MSIDInteractiveTokenRequest.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDAuthority.h"
#import "MSIDWebviewConfiguration.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDWebviewResponse.h"
#import "MSIDWebOAuth2Response.h"
#import "MSIDWebAADAuthResponse.h"
#import "MSIDWebMSAuthResponse.h"
#import "MSIDWebOpenBrowserResponse.h"
#import "MSIDAppExtensionUtil.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDAADAuthorizationCodeGrantRequest.h"
#import "MSIDPkce.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDTokenRequestFactory.h"
#import "MSIDTokenResult.h"

@interface MSIDInteractiveTokenRequest()

@property (nonatomic) MSIDInteractiveRequestParameters *requestParameters;
@property (nonatomic) MSIDOauth2Factory *oauthFactory;
@property (nonatomic) MSIDTokenRequestFactory *tokenRequestFactory;
@property (nonatomic) MSIDTokenResponseValidator *tokenResponseValidator;
@property (nonatomic) id<MSIDCacheAccessor> tokenCache;
@property (nonatomic) MSIDWebviewConfiguration *webViewConfiguration;

@end

@implementation MSIDInteractiveTokenRequest

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDInteractiveRequestParameters *)parameters
                                      oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
                               tokenRequestFactory:(nonnull MSIDTokenRequestFactory *)tokenRequestFactory
                            tokenResponseValidator:(nonnull MSIDTokenResponseValidator *)tokenResponseValidator
                                        tokenCache:(nonnull id<MSIDCacheAccessor>)tokenCache
{
    self = [super init];

    if (self)
    {
        self.requestParameters = parameters;
        self.oauthFactory = oauthFactory;
        self.tokenRequestFactory = tokenRequestFactory; // TODO: move token request factory methods into oauth2 factory?
        self.tokenResponseValidator = tokenResponseValidator;
        self.tokenCache = tokenCache;
        self.webViewConfiguration = [self.tokenRequestFactory webViewConfigurationWithRequestParameters:parameters];
    }

    return self;
}

- (void)acquireToken:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    [self.requestParameters.authority loadOpenIdMetadataWithContext:self.requestParameters
                                                    completionBlock:^(MSIDOpenIdProviderMetadata *metadata, NSError *error)
     {
         if (error)
         {
             completionBlock(nil, error);
             return;
         }

         [self acquireTokenImpl:completionBlock];
     }];
}

- (void)acquireTokenImpl:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    void (^webAuthCompletion)(MSIDWebviewResponse *, NSError *) = ^void(MSIDWebviewResponse *response, NSError *error)
    {
        if (error)
        {
            completionBlock(nil, error);
            return;
        }

        if ([response isKindOfClass:MSIDWebOAuth2Response.class])
        {
            MSIDWebOAuth2Response *oauthResponse = (MSIDWebOAuth2Response *)response;

            if (oauthResponse.authorizationCode)
            {
                // handle instance aware flow (cloud host)
                if ([response isKindOfClass:MSIDWebAADAuthResponse.class])
                {
                    MSIDWebAADAuthResponse *aadResponse = (MSIDWebAADAuthResponse *)response;
                    [self.requestParameters setCloudAuthorityWithCloudHostName:aadResponse.cloudHostName];
                }

                [self acquireTokenWithCode:oauthResponse.authorizationCode completion:completionBlock];
                return;
            }

            completionBlock(nil, oauthResponse.oauthError);
            return;
        }
        else if ([response isKindOfClass:MSIDWebMSAuthResponse.class])
        {
            // Todo: Install broker prompt
        }

        else if ([response isKindOfClass:MSIDWebOpenBrowserResponse.class])
        {
            NSURL *browserURL = ((MSIDWebOpenBrowserResponse *)response).browserURL;

#if TARGET_OS_IPHONE
            if (![MSIDAppExtensionUtil isExecutingInAppExtension])
            {
                MSID_LOG_INFO(nil, @"Opening a browser");
                MSID_LOG_INFO_PII(nil, @"Opening a browser - %@", browserURL);
                [MSIDAppExtensionUtil sharedApplicationOpenURL:browserURL];
            }
            else
            {
                NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorAttemptToOpenURLFromExtension, @"unable to redirect to browser from extension", nil, nil, nil, self.requestParameters.correlationId, nil);
                completionBlock(nil, error);
                return;
            }
#else
            [[NSWorkspace sharedWorkspace] openURL:browserURL];
#endif
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorSessionCanceledProgrammatically, @"Authorization session was cancelled programatically.", nil, nil, nil, self.requestParameters.correlationId, nil);
            completionBlock(nil, error);
            return;
        }
    };

    if (self.requestParameters.useEmbeddedWebView)
    {
        [MSIDWebviewAuthorization startEmbeddedWebviewAuthWithConfiguration:self.webViewConfiguration
                                                              oauth2Factory:self.oauthFactory
                                                                    webview:self.requestParameters.customWebview
                                                                    context:self.requestParameters
                                                          completionHandler:webAuthCompletion];
    }
    else
    {
        [MSIDWebviewAuthorization startSystemWebviewAuthWithConfiguration:self.webViewConfiguration
                                                            oauth2Factory:self.oauthFactory
                                                 useAuthenticationSession:!self.requestParameters.useSafariViewController
                                                allowSafariViewController:self.requestParameters.useSafariViewController
                                                                  context:self.requestParameters
                                                        completionHandler:webAuthCompletion];
    }
}

#pragma mark - Helpers

- (void)acquireTokenWithCode:(NSString *)authCode
                  completion:(MSIDRequestCompletionBlock)completionBlock
{
    MSIDAuthorizationCodeGrantRequest *tokenRequest = [self.tokenRequestFactory authorizationGrantRequestWithRequestParameters:self.requestParameters
                                                                                                                  codeVerifier:self.webViewConfiguration.pkce.codeVerifier
                                                                                                                      authCode:authCode];

    [tokenRequest sendWithBlock:^(id response, NSError *error) {

        if (error)
        {
            completionBlock(nil, error);
            return;
        }

        NSError *validationError = nil;

        MSIDTokenResult *tokenResult = [self.tokenResponseValidator validateTokenResponse:response
                                                                             oauthFactory:self.oauthFactory
                                                                               tokenCache:self.tokenCache
                                                                        requestParameters:self.requestParameters
                                                                                    error:&validationError];

        if (!tokenResult)
        {
            completionBlock(nil, validationError);
            return;
        }

        completionBlock(tokenResult, nil);
    }];
}

@end
