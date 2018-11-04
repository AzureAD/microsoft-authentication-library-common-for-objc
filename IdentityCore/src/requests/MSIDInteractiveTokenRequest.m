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

@interface MSIDInteractiveTokenRequest()

@property (nonatomic) MSIDInteractiveRequestParameters *requestParameters;
@property (nonatomic) MSIDWebviewConfiguration *webViewConfiguration;

@end

@implementation MSIDInteractiveTokenRequest

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDInteractiveRequestParameters *)parameters
{
    self = [super init];

    if (self)
    {
        self.requestParameters = parameters;
        [self initWebViewConfiguration];
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
                    //MSIDWebAADAuthResponse *aadResponse = (MSIDWebAADAuthResponse *)response;
                    //[_parameters setCloudAuthorityWithCloudHostName:aadResponse.cloudHostName]; // TODO
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
                //NSError *error = CREATE_MSAL_LOG_ERROR(nil, MSALErrorAttemptToOpenURLFromExtension, @"unable to redirect to browser from extension");
                //[self stopTelemetryEvent:[self getTelemetryAPIEvent] error:error];
                NSError *error = nil; // TODO
                completionBlock(nil, error);
                return;
            }
#else
            [[NSWorkspace sharedWorkspace] openURL:browserURL];
#endif
            //NSError *error = CREATE_MSAL_LOG_ERROR(nil, MSALErrorSessionCanceled, @"Authorization session was cancelled programatically.");
            //[self stopTelemetryEvent:[self getTelemetryAPIEvent] error:error];
            NSError *error = nil; // TODO
            completionBlock(nil, error);
            return;
        }
    };

    if (self.requestParameters.useEmbeddedWebView)
    {
        [MSIDWebviewAuthorization startEmbeddedWebviewAuthWithConfiguration:self.webViewConfiguration
                                                              oauth2Factory:self.requestParameters.oauthFactory
                                                                    webview:self.requestParameters.customWebview
                                                                    context:self.requestParameters
                                                          completionHandler:webAuthCompletion];
    }
    else
    {
        [MSIDWebviewAuthorization startSystemWebviewAuthWithConfiguration:self.webViewConfiguration
                                                            oauth2Factory:self.requestParameters.oauthFactory
                                                 useAuthenticationSession:!self.requestParameters.useSafariViewController
                                                allowSafariViewController:self.requestParameters.useSafariViewController
                                                                  context:self.requestParameters
                                                        completionHandler:webAuthCompletion];
    }
}

#pragma mark - Helpers

- (void)acquireTokenWithCode:(NSString *)authCode completion:(MSIDRequestCompletionBlock)completionBlock
{
    MSIDAADAuthorizationCodeGrantRequest *tokenRequest = [[MSIDAADAuthorizationCodeGrantRequest alloc] initWithEndpoint:nil // TODO
                                                                                                               clientId:self.requestParameters.clientId
                                                                                                                  scope:nil // TODO
                                                                                                            redirectUri:self.requestParameters.redirectUri
                                                                                                                   code:authCode
                                                                                                           codeVerifier:<#(nullable NSString *)#> context:<#(nullable id<MSIDRequestContext>)#>]

    MSIDAADAuthorizationCodeGrantRequest *tokenRequest = [[MSIDAADAuthorizationCodeGrantRequest alloc] initWithEndpoint:nil // TODO
                                                                                                               clientId:self.requestParameters.clientId
                                                                                                                  scope:nil // TODO
                                                                                                            redirectUri:self.requestParameters.redirectUri
                                                                                                                   code:authCode
                                                                                                                 claims:nil // TODO
                                                                                                           codeVerifier:self.webViewConfiguration.pkce.codeVerifier
                                                                                                                context:self.requestParameters];

    MSIDTokenRequest *authRequest = [self tokenRequest];

    [authRequest sendWithBlock:^(id response, NSError *error) {
        if (error)
        {
            if (!completionBlock)
            {
                return;
            }

            completionBlock(nil, error);
            return;
        }

        if (response && ![response isKindOfClass:[NSDictionary class]])
        {
            NSError *localError = CREATE_MSAL_LOG_ERROR(_parameters, MSALErrorInternal, @"response is not of the expected type: NSDictionary.");
            completionBlock(nil, localError);
            return;
        }

        NSDictionary *jsonDictionary = (NSDictionary *)response;
        NSError *localError = nil;
        MSIDAADV2TokenResponse *tokenResponse = (MSIDAADV2TokenResponse *)[self.oauth2Factory tokenResponseFromJSON:jsonDictionary context:nil error:&localError];

        if (!tokenResponse)
        {
            completionBlock(nil, localError);
            return;
        }

        NSError *verificationError = nil;
        if (![self verifyTokenResponse:tokenResponse error:&verificationError])
        {
            completionBlock(nil, verificationError);
            return;
        }

        NSError *savingError = nil;
        BOOL isSaved = [self.tokenCache saveTokensWithConfiguration:_parameters.msidConfiguration
                                                           response:tokenResponse
                                                            context:_parameters
                                                              error:&savingError];

        if (!isSaved)
        {
            completionBlock(nil, savingError);
            return;
        }

        NSError *scopesError = nil;
        if (![self verifyScopesWithResponse:tokenResponse error:&scopesError])
        {
            completionBlock(nil, scopesError);
            return;
        }

        NSError *resultError = nil;

        MSALResult *result = [self resultFromTokenResponse:tokenResponse error:&resultError];
        completionBlock(result, resultError);
    }];


}

- (void)initWebViewConfiguration
{
    self.webViewConfiguration = [[MSIDWebviewConfiguration alloc] initWithAuthorizationEndpoint:self.requestParameters.authority.metadata.authorizationEndpoint
                                                                                    redirectUri:self.requestParameters.redirectUri
                                                                                       clientId:self.requestParameters.clientId
                                                                                       resource:nil // TODO
                                                                                         scopes:nil // TODO
                                                                                  correlationId:self.requestParameters.correlationId
                                                                                     enablePkce:YES]; // TODO

    /*
     MSIDWebviewConfiguration *config = [[MSIDWebviewConfiguration alloc] initWithAuthorizationEndpoint:self.requestParameters.authority.metadata.authorizationEndpoint
     redirectUri:self.requestParameters.redirectUri
     clientId:self.requestParameters.clientId
     resource:nil
     scopes:[self requestScopes:_extraScopesToConsent]
     correlationId:self.requestParameters.correlationId
     enablePkce:YES];
     config.promptBehavior = MSALParameterStringForBehavior(_uiBehavior);
     config.loginHint = _parameters.account ? _parameters.account.username : _parameters.loginHint;
     config.uid = _parameters.account.homeAccountId.objectId;
     config.utid = _parameters.account.homeAccountId.tenantId;
     config.extraQueryParameters = _parameters.extraQueryParameters;
     config.sliceParameters = _parameters.sliceParameters;
     NSString *claims = [MSIDClientCapabilitiesUtil msidClaimsParameterFromCapabilities:_parameters.clientCapabilities
     developerClaims:_parameters.decodedClaims];
     if (![NSString msidIsStringNilOrBlank:claims])
     {
     config.claims = claims;
     }

     */
}

@end
