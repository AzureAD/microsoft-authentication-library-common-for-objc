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

#import "MSIDInteractiveAuthorizationCodeRequest.h"
#import "MSIDLastRequestTelemetry.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "NSError+MSIDServerTelemetryError.h"
#import "MSIDWebviewResponse.h"
#import "MSIDWebOAuth2AuthCodeResponse.h"
#import "MSIDCBAWebAADAuthResponse.h"
#import "MSIDWebWPJResponse.h"
#import "MSIDWebUpgradeRegResponse.h"
#import "MSIDWebOpenBrowserResponse.h"
#import "MSIDOauth2Factory.h"
#import "MSIDWebviewFactory.h"
#import "MSIDAuthorizeWebRequestConfiguration.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDAuthorizationCodeResult.h"
#import "MSIDPkce.h"
#import "MSIDWebResponseOperationFactory.h"
#import "MSIDWebResponseBaseOperation.h"

#if TARGET_OS_IPHONE
#import "MSIDAppExtensionUtil.h"
#import "MSIDWebviewInteracting.h"
#endif

#import "MSIDFlightManager.h"

@interface MSIDInteractiveAuthorizationCodeRequest()
#if !EXCLUDE_FROM_MSALCPP
@property (nonatomic) MSIDLastRequestTelemetry *lastRequestTelemetry;
#endif
@property (nonatomic) MSIDClientInfo *authCodeClientInfo;
@property (nonatomic) MSIDAuthorizeWebRequestConfiguration *webViewConfiguration;

@end

@implementation MSIDInteractiveAuthorizationCodeRequest

- (nullable instancetype)initWithRequestParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                      oauthFactory:(MSIDOauth2Factory *)oauthFactory
{
    self = [super init];

    if (self)
    {
        _requestParameters = parameters;
        _oauthFactory = oauthFactory;
#if !EXCLUDE_FROM_MSALCPP
        _lastRequestTelemetry = [MSIDLastRequestTelemetry sharedInstance];
#endif
    }

    return self;
}

- (void)getAuthCodeWithCompletion:(MSIDInteractiveAuthorizationCodeCompletionBlock)completionBlock
{
    NSString *upn = self.requestParameters.accountIdentifier.displayableId ?: self.requestParameters.loginHint;

    [self.requestParameters.authority resolveAndValidate:self.requestParameters.validateAuthority
                                       userPrincipalName:upn
                                                 context:self.requestParameters
                                         completionBlock:^(__unused NSURL *openIdConfigurationEndpoint,
                                         __unused BOOL validated, NSError *error)
     {
         if (error)
         {
             completionBlock(nil, error, nil);
             return;
         }

         [self.requestParameters.authority loadOpenIdMetadataWithContext:self.requestParameters
                                                         completionBlock:^(__unused MSIDOpenIdProviderMetadata *metadata, NSError *loadError)
          {
              if (loadError)
              {
                  completionBlock(nil, loadError, nil);
                  return;
              }

              [self getAuthCodeWithCompletionImpl:completionBlock];
          }];
     }];
}

- (void)getAuthCodeWithCompletionImpl:(MSIDInteractiveAuthorizationCodeCompletionBlock)completionBlock
{
    self.webViewConfiguration = [self.oauthFactory.webviewFactory authorizeWebRequestConfigurationWithRequestParameters:self.requestParameters];
    
    __typeof__(self) __weak weakSelf = self;
    [self showWebComponentWithCompletion:^(MSIDWebviewResponse *response, NSError *error)
     {
        __typeof__(self) strongSelf = weakSelf;
        
        if ([response useV2WebResponseHandling])
        {
            [strongSelf handleWebReponseV2:response error:error completionBlock:completionBlock];
        }
        else
        {
            [strongSelf handleWebReponseV1:response error:error completionBlock:completionBlock];
        }
    }];
}

- (void)showWebComponentWithCompletion:(MSIDWebviewAuthCompletionHandler)completionHandler
{
    NSObject<MSIDWebviewInteracting> *webView = [self.oauthFactory.webviewFactory webViewWithConfiguration:self.webViewConfiguration
                                                                                         requestParameters:self.requestParameters
                                                                      externalDecidePolicyForBrowserAction:self.externalDecidePolicyForBrowserAction
                                                                                                   context:self.requestParameters];
    
    if (!webView)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected error. Didn't find any supported web browsers.", nil, nil, nil, nil, nil, YES);
        if (completionHandler) completionHandler(nil, error);
        return;
    }
    
    [MSIDWebviewAuthorization startSessionWithWebView:webView
                                        oauth2Factory:self.oauthFactory
                                        configuration:self.webViewConfiguration
                                              context:self.requestParameters
                                    completionHandler:completionHandler];

}

#pragma mark - v2 code

- (void)handleWebReponseV2:(MSIDWebviewResponse *)response error:(NSError *)error completionBlock:(MSIDInteractiveAuthorizationCodeCompletionBlock)completionBlock
{
    void (^returnErrorBlock)(NSError *) = ^(NSError *localError)
    {
        NSString *errorString = [localError msidServerTelemetryErrorString];
        if (errorString)
        {
#if !EXCLUDE_FROM_MSALCPP
            [self.lastRequestTelemetry updateWithApiId:[self.requestParameters.telemetryApiId integerValue]
                                           errorString:errorString
                                               context:self.requestParameters];
#endif
        }
        
        completionBlock(nil, localError, nil);
    };
    
    if (error)
    {
        returnErrorBlock(error);
        return;
    }

    if ([response isKindOfClass:MSIDWebOpenBrowserResponse.class])
    {
        error = nil;
        MSIDWebResponseBaseOperation *operation = [MSIDWebResponseOperationFactory createOperationForResponse:response
                                                                                                        error:&error];
        if (error)
        {
            returnErrorBlock(error);
            return;
        }
        
        BOOL isCurrentFlowFinished = [operation doActionWithCorrelationId:self.requestParameters.correlationId
                                                                    error:&error];
        if (isCurrentFlowFinished && error)
        {
            returnErrorBlock(error);
            return;
        }
        
        // This should never happen, create a new error here just in case it would hang if somehow falls into this part
        error = MSIDCreateError(MSIDErrorDomain,
                                MSIDErrorInternal,
                                @"Authorization session was not canceled successfully",
                                nil,
                                nil,
                                nil,
                                self.requestParameters.correlationId,
                                nil,
                                YES);
        returnErrorBlock(error);
        return;
    }
        
    NSError *localError = nil;
    MSIDWebResponseBaseOperation *operation = [MSIDWebResponseOperationFactory createOperationForResponse:response
                                                                                                    error:&localError];
    
    if (localError)
    {
        returnErrorBlock(localError);
        return;
    }

    __typeof__(self) __weak weakSelf = self;
    [operation invokeWithRequestParameters:self.requestParameters
                   webRequestConfiguration:self.webViewConfiguration
                              oauthFactory:self.oauthFactory
         decidePolicyForBrowserActionBlock:self.externalDecidePolicyForBrowserAction
            webviewResponseCompletionBlock:^(MSIDWebviewResponse *webviewResponse, NSError *responseError) {
        
        [weakSelf handleWebReponseV2:webviewResponse error:responseError completionBlock:completionBlock];
    } authorizationCodeCompletionBlock:^(MSIDAuthorizationCodeResult *codeResult, NSError *resultError, MSIDWebWPJResponse *wpjResponse) {
        if (resultError)
        {
            returnErrorBlock(resultError);
            return;
        }
        
        if (wpjResponse) 
        {
            completionBlock(nil, nil, wpjResponse);
            return;
        }
        
        completionBlock(codeResult, nil, nil);
    }];
}

#pragma mark - v1 code

- (void)handleWebReponseV1:(MSIDWebviewResponse *)response error:(NSError *)error completionBlock:(MSIDInteractiveAuthorizationCodeCompletionBlock)completionBlock
{
    void (^returnErrorBlock)(NSError *) = ^(NSError *localError)
    {
        NSString *errorString = [localError msidServerTelemetryErrorString];
        if (errorString)
        {
#if !EXCLUDE_FROM_MSALCPP
            [self.lastRequestTelemetry updateWithApiId:[self.requestParameters.telemetryApiId integerValue]
                                           errorString:errorString
                                               context:self.requestParameters];
#endif
        }
        
        completionBlock(nil, localError, nil);
    };
    
    if (error)
    {
        returnErrorBlock(error);
        return;
    }

    /*

     TODO: this code has been moved from MSAL almost as is to avoid any changes in the MSIDWebviewAuthorization logic.
     Some minor refactoring to MSIDWebviewAuthorization response logic and to the interactive requests tests will be done separately: https://github.com/AzureAD/microsoft-authentication-library-common-for-objc/issues/297
     */

    if ([response isKindOfClass:MSIDWebOAuth2AuthCodeResponse.class])
    {
        MSIDWebOAuth2AuthCodeResponse *oauthResponse = (MSIDWebOAuth2AuthCodeResponse *)response;

        if (oauthResponse.authorizationCode)
        {
            if ([response isKindOfClass:MSIDCBAWebAADAuthResponse.class])
            {
                MSIDCBAWebAADAuthResponse *cbaResponse = (MSIDCBAWebAADAuthResponse *)response;
                self.requestParameters.redirectUri = cbaResponse.redirectUri;
            }
            // handle instance aware flow (cloud host)
            
            if ([response isKindOfClass:MSIDWebAADAuthCodeResponse.class])
            {
                MSIDWebAADAuthCodeResponse *aadResponse = (MSIDWebAADAuthCodeResponse *)response;
                [self.requestParameters setCloudAuthorityWithCloudHostName:aadResponse.cloudHostName];
                self.authCodeClientInfo = aadResponse.clientInfo;
            }

            [self returnResultWithCodeV1:oauthResponse.authorizationCode completion:completionBlock];
            return;
        }

        returnErrorBlock(oauthResponse.oauthError);
        return;
    }
    else if ([response isKindOfClass:MSIDWebUpgradeRegResponse.class])
    {
        completionBlock(nil, nil, (MSIDWebUpgradeRegResponse *)response);
    }
    else if ([response isKindOfClass:MSIDWebWPJResponse.class])
    {
        completionBlock(nil, nil, (MSIDWebWPJResponse *)response);
    }
    else if ([response isKindOfClass:MSIDWebOpenBrowserResponse.class])
    {
        error = nil;
        MSIDWebResponseBaseOperation *operation = [MSIDWebResponseOperationFactory createOperationForResponse:response
                                                                                                        error:&error];
        if (error)
        {
            returnErrorBlock(error);
            return;
        }
        
        BOOL isCurrentFlowFinished = [operation doActionWithCorrelationId:self.requestParameters.correlationId
                                                                    error:&error];
        if (isCurrentFlowFinished && error)
        {
            returnErrorBlock(error);
            return;
        }
        
        // This should never happen, create a new error here just in case it would hang if somehow falls into this part
        error = MSIDCreateError(MSIDErrorDomain,
                                MSIDErrorInternal,
                                @"Authorization session was not canceled successfully",
                                nil,
                                nil,
                                nil,
                                self.requestParameters.correlationId,
                                nil,
                                YES);
        returnErrorBlock(error);
        return;
    }
}

- (void)returnResultWithCodeV1:(NSString *)authCode
                    completion:(MSIDInteractiveAuthorizationCodeCompletionBlock)completionBlock
{
    MSIDAuthorizationCodeResult *result = [MSIDAuthorizationCodeResult new];
    result.authCode = authCode;
    result.accountIdentifier = self.authCodeClientInfo.accountIdentifier;
    result.pkceVerifier = self.webViewConfiguration.pkce.codeVerifier;
    completionBlock(result, nil, nil);
}

@end
