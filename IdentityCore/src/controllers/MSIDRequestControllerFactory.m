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

#import "MSIDRequestControllerFactory.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDSilentController.h"
#if TARGET_OS_IPHONE
#import "MSIDAppExtensionUtil.h"
#import "MSIDBrokerInteractiveController.h"
#endif
#import "MSIDSSOExtensionSilentTokenRequestController.h"
#import "MSIDSSOExtensionSignoutController.h"
#import "MSIDSSOExtensionInteractiveTokenRequestController.h"
#import "MSIDRequestParameters+Broker.h"
#import "MSIDAuthority.h"
#import "MSIDSignoutController.h"
#if TARGET_OS_OSX
#import "MSIDXpcSilentTokenRequestController.h"
#import "MSIDXpcInteractiveTokenRequestController.h"
#endif

@implementation MSIDRequestControllerFactory

+ (nullable id<MSIDRequestControlling>)silentControllerForParameters:(MSIDRequestParameters *)parameters
                                                        forceRefresh:(BOOL)forceRefresh
                                                         skipLocalRt:(MSIDSilentControllerLocalRtUsageType)skipLocalRt
                                                tokenRequestProvider:(id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                               error:(NSError *__autoreleasing*)error
{
    if (parameters.xpcMode == MSIDXpcModeDisabled)
    {
        return [self SilentControllerWithoutXpcForParameters:parameters
                                                forceRefresh:forceRefresh
                                                 skipLocalRt:skipLocalRt
                                        tokenRequestProvider:tokenRequestProvider
                                                       error:error];
    }
    else
    {
        return [self silentControllerWithXpcForParameters:parameters
                                             forceRefresh:forceRefresh
                                              skipLocalRt:skipLocalRt
                                     tokenRequestProvider:tokenRequestProvider
                                                    error:error];
    }
}

+ (nullable id<MSIDRequestControlling>)SilentControllerWithoutXpcForParameters:(MSIDRequestParameters *)parameters
                                                                  forceRefresh:(BOOL)forceRefresh
                                                                   skipLocalRt:(MSIDSilentControllerLocalRtUsageType)skipLocalRt
                                                          tokenRequestProvider:(id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                                         error:(NSError *__autoreleasing*)error
{
    // Nested auth protocol - Reverse client id & redirect uri
    if ([parameters isNestedAuthProtocol])
    {
        [parameters reverseNestedAuthParametersIfNeeded];
    }

    MSIDSilentController *brokerController;
    
    if ([parameters shouldUseBroker])
    {
        if ([MSIDSSOExtensionSilentTokenRequestController canPerformRequest])
        {
            MSIDSilentController *localController = nil;
            if (parameters.allowUsingLocalCachedRtWhenSsoExtFailed)
            {
                localController = [[MSIDSilentController alloc] initWithRequestParameters:parameters
                                                                             forceRefresh:YES
                                                                     tokenRequestProvider:tokenRequestProvider
                                                                                    error:error];
                localController.isLocalFallbackMode = YES;
            }

            brokerController = [[MSIDSSOExtensionSilentTokenRequestController alloc] initWithRequestParameters:parameters
                                                                                                  forceRefresh:forceRefresh
                                                                                          tokenRequestProvider:tokenRequestProvider
                                                                                 fallbackInteractiveController:localController
                                                                                                         error:error];
        }
    }
    
    // TODO: Performance optimization: check account source.
    // if (parameters.accountIdentifier.source == BROKER) return brokerController;
    
    if (!brokerController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, parameters, @"No fallback brokerController is provided", nil);
    }
    
    __auto_type localController = [[MSIDSilentController alloc] initWithRequestParameters:parameters
                                                                             forceRefresh:forceRefresh
                                                                     tokenRequestProvider:tokenRequestProvider
                                                            fallbackInteractiveController:brokerController
                                                                                    error:error];
    if (!localController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, parameters, @"failed to initialize silentController, return early", nil);
        return nil;
    }
    
    switch (skipLocalRt) {
        case MSIDSilentControllerForceSkippingLocalRt:
            localController.skipLocalRt = YES;
            break;
        case MSIDSilentControllerForceUsingLocalRt:
            localController.skipLocalRt = NO;
            break;
        case MSIDSilentControllerUndefinedLocalRtUsage:
            if (brokerController) localController.skipLocalRt = YES;
            break;
        default:
            break;
    }
    
    return localController;
}

+ (nullable id<MSIDRequestControlling>)silentControllerWithXpcForParameters:(MSIDRequestParameters *)parameters
                                                               forceRefresh:(BOOL)forceRefresh
                                                                skipLocalRt:(MSIDSilentControllerLocalRtUsageType)skipLocalRt
                                                       tokenRequestProvider:(id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                                      error:(NSError *__autoreleasing*)error
{
    // Nested auth protocol - Reverse client id & redirect uri
    if ([parameters isNestedAuthProtocol])
    {
        [parameters reverseNestedAuthParametersIfNeeded];
    }
    
    MSIDSilentController *fallbackController = nil;
    
    if ([parameters shouldUseBroker])
    {
        if (parameters.allowUsingLocalCachedRtWhenSsoExtFailed)
        {
            fallbackController = [[MSIDSilentController alloc] initWithRequestParameters:parameters
                                                                         forceRefresh:YES
                                                                 tokenRequestProvider:tokenRequestProvider
                                                                                error:error];
            fallbackController.isLocalFallbackMode = YES;
        }
    
        MSIDSilentController *xpcController = nil;
#if TARGET_OS_OSX
        if (parameters.xpcMode != MSIDXpcModeDisabled && [MSIDXpcSilentTokenRequestController canPerformRequest])
        {
            xpcController = [[MSIDXpcSilentTokenRequestController alloc] initWithRequestParameters:parameters
                                                                                           forceRefresh:forceRefresh
                                                                                   tokenRequestProvider:tokenRequestProvider
                                                                          fallbackInteractiveController:fallbackController
                                                                                                  error:error];
            if (parameters.xpcMode == MSIDXpcModeSSOExtBackup || parameters.xpcMode == MSIDXpcModePrimary)
            {
                // If in Xpc full mode, the XPCController will work as a isolated controller when SsoExtension cannotPerformRequest
                fallbackController = xpcController;
                xpcController = nil;
            }
        }
#endif
        
        BOOL shouldSkipSsoExtension = parameters.xpcMode == MSIDXpcModePrimary;
        
        if (!shouldSkipSsoExtension && [MSIDSSOExtensionSilentTokenRequestController canPerformRequest])
        {
            fallbackController = [[MSIDSSOExtensionSilentTokenRequestController alloc] initWithRequestParameters:parameters
                                                                                                    forceRefresh:forceRefresh
                                                                                            tokenRequestProvider:tokenRequestProvider
                                                                                   fallbackInteractiveController:xpcController?:fallbackController
                                                                                                           error:error];
        }
    }
    
    if (!fallbackController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, parameters, @"No fallbackController is provided", nil);
    }
    
    MSIDSilentController *silentController = [[MSIDSilentController alloc] initWithRequestParameters:parameters
                                                                                       forceRefresh:forceRefresh
                                                                               tokenRequestProvider:tokenRequestProvider
                                                                      fallbackInteractiveController:fallbackController
                                                                                              error:error];
    if (!silentController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, parameters, @"failed to initialize silentController, return early", nil);
        return nil;
    }
    
    switch (skipLocalRt) {
        case MSIDSilentControllerForceSkippingLocalRt:
            silentController.skipLocalRt = YES;
            break;
        case MSIDSilentControllerForceUsingLocalRt:
            silentController.skipLocalRt = NO;
            break;
        case MSIDSilentControllerUndefinedLocalRtUsage:
            if (fallbackController) silentController.skipLocalRt = YES;
            break;
        default:
            break;
    }
    
    return silentController;
    
}

+ (nullable id<MSIDRequestControlling>)interactiveControllerForParameters:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                                     tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                                    error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    // Nested auth protocol - Reverse client id & redirect uri
    if ([parameters isNestedAuthProtocol])
    {
        [parameters reverseNestedAuthParametersIfNeeded];
    }

    id<MSIDRequestControlling> interactiveController = [self platformInteractiveController:parameters
                                                                      tokenRequestProvider:tokenRequestProvider
                                                                                     error:error];

    if (parameters.uiBehaviorType != MSIDUIBehaviorAutoType)
    {
        return interactiveController;
    }

    return [[MSIDSilentController alloc] initWithRequestParameters:parameters
                                                      forceRefresh:NO
                                              tokenRequestProvider:tokenRequestProvider
                                     fallbackInteractiveController:interactiveController
                                                             error:error];
}

+ (nullable id<MSIDRequestControlling>)platformInteractiveController:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                                tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                               error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    id<MSIDRequestControlling> localController = [self localInteractiveController:parameters
                                                             tokenRequestProvider:tokenRequestProvider
                                                                            error:error];
    
    if (!localController)
    {
        return nil;
    }
    
    if ([parameters shouldUseBroker])
    {
        id<MSIDRequestControlling> brokerController = [self brokerController:parameters
                                                        tokenRequestProvider:tokenRequestProvider
                                                          fallbackController:localController
                                                                       error:error];
        
        if (brokerController)
        {
            return brokerController;
        }
    }

    return localController;
}

#if TARGET_OS_IPHONE
+ (nullable id<MSIDRequestControlling>)brokerController:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                   tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                     fallbackController:(nullable id<MSIDRequestControlling>)fallbackController
                                                  error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    MSIDBrokerInteractiveController *brokerController = nil;
    
    NSError *brokerControllerError;
    if ([MSIDBrokerInteractiveController canPerformRequest:parameters])
    {
        brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                                    tokenRequestProvider:tokenRequestProvider
                                                                                      fallbackController:fallbackController
                                                                                                   error:&brokerControllerError];
        
        if (brokerControllerError)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Encountered an error creating broker controller %@", MSID_PII_LOG_MASKABLE(brokerControllerError));
        }
    }
    
    brokerController.sdkBrokerCapabilities = @[MSID_BROKER_SDK_SSO_EXTENSION_CAPABILITY];
    
    id<MSIDRequestControlling> ssoExtensionController = [self ssoExtensionInteractiveController:parameters
                                                                           tokenRequestProvider:tokenRequestProvider
                                                                             fallbackController:brokerController
                                                                                          error:&brokerControllerError];
    
    if (ssoExtensionController)
    {
        return ssoExtensionController;
    }
    
    if (brokerControllerError)
    {
        if (error) *error = brokerControllerError;
        return nil;
    }
    else if (brokerController)
    {
        return brokerController;
    }
    
    return nil;
}
#else

+ (nullable id<MSIDRequestControlling>)brokerController:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                   tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                     fallbackController:(nullable id<MSIDRequestControlling>)fallbackController
                                                  error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    id<MSIDRequestControlling> xpcController = nil;
    
    // By default the xpc flow is disable, and should fallback to previous flow in else condition
    if (parameters.xpcMode != MSIDXpcModeDisabled)
    {
        xpcController = [self xpcInteractiveController:parameters
                                  tokenRequestProvider:tokenRequestProvider
                                    fallbackController:fallbackController
                                                 error:error];
        if (parameters.xpcMode == MSIDXpcModeSSOExtCompanion || parameters.xpcMode == MSIDXpcModeSSOExtBackup)
        {
            id<MSIDRequestControlling> ssoExtensionController = [self ssoExtensionInteractiveController:parameters
                                                                                   tokenRequestProvider:tokenRequestProvider
                                                                                     fallbackController:xpcController?:fallbackController
                                                                                                  error:error];
            if (parameters.xpcMode == MSIDXpcModeSSOExtBackup && !ssoExtensionController)
            {
                return xpcController;
            }
            
            return ssoExtensionController;
        }
        else
        {
            // Development only: MSIDXpcModePrimary
            return xpcController;
        }
    }
    else
    {
        return [self ssoExtensionInteractiveController:parameters
                                  tokenRequestProvider:tokenRequestProvider
                                    fallbackController:fallbackController
                                                 error:error];
    }
}
#endif

+ (nullable id<MSIDRequestControlling>)ssoExtensionInteractiveController:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                                    tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                      fallbackController:(nullable id<MSIDRequestControlling>)fallbackController
                                                                   error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    if ([MSIDSSOExtensionInteractiveTokenRequestController canPerformRequest])
    {
        return [[MSIDSSOExtensionInteractiveTokenRequestController alloc] initWithInteractiveRequestParameters:parameters
                                                                                          tokenRequestProvider:tokenRequestProvider
                                                                                            fallbackController:fallbackController
                                                                                                         error:error];
    }
    
    return nil;
}

#if TARGET_OS_OSX
+ (nullable id<MSIDRequestControlling>)xpcInteractiveController:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                           tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                             fallbackController:(nullable id<MSIDRequestControlling>)fallbackController
                                                          error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    if ([MSIDXpcInteractiveTokenRequestController canPerformRequest])
    {
        return [[MSIDXpcInteractiveTokenRequestController alloc] initWithInteractiveRequestParameters:parameters
                                                                                 tokenRequestProvider:tokenRequestProvider
                                                                                   fallbackController:fallbackController
                                                                                                error:error];
    }
    
    return nil;
}
#endif

+ (nullable id<MSIDRequestControlling>)localInteractiveController:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                             tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                            error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
#if TARGET_OS_IPHONE
    if ([MSIDAppExtensionUtil isExecutingInAppExtension]
        && !(parameters.webviewType == MSIDWebviewTypeWKWebView && parameters.customWebview))
    {
        // If developer provides us an custom webview, we should be able to use it for authentication in app extension
        BOOL hasSupportedEmbeddedWebView = parameters.webviewType == MSIDWebviewTypeWKWebView && parameters.customWebview;
        BOOL hasSupportedSystemWebView = parameters.webviewType == MSIDWebviewTypeSafariViewController && parameters.parentViewController;
        
        if (!hasSupportedEmbeddedWebView && !hasSupportedSystemWebView)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUINotSupportedInExtension, @"Interaction is not supported in an app extension.", nil, nil, nil, parameters.correlationId, nil, YES);
            }
            
            return nil;
        }
    }
#endif
    
    return [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                   tokenRequestProvider:tokenRequestProvider
                                                                                  error:error];
}

+ (nullable MSIDSignoutController *)signoutControllerForParameters:(MSIDInteractiveRequestParameters *)parameters
                                                      oauthFactory:(MSIDOauth2Factory *)oauthFactory
                                          shouldSignoutFromBrowser:(BOOL)shouldSignoutFromBrowser
                                                 shouldWipeAccount:(BOOL)shouldWipeAccount
                                     shouldWipeCacheForAllAccounts:(BOOL)shouldWipeCacheForAllAccounts
                                                             error:(NSError *__autoreleasing*)error
{
    if ([parameters shouldUseBroker])
    {
        if ([MSIDSSOExtensionSignoutController canPerformRequest])
        {
            return [[MSIDSSOExtensionSignoutController alloc] initWithRequestParameters:parameters
                                                               shouldSignoutFromBrowser:shouldSignoutFromBrowser
                                                                      shouldWipeAccount:shouldWipeAccount
                                                          shouldWipeCacheForAllAccounts:shouldWipeCacheForAllAccounts
                                                                           oauthFactory:oauthFactory
                                                                                  error:error];
        }
    }
    
    return [[MSIDSignoutController alloc] initWithRequestParameters:parameters
                                           shouldSignoutFromBrowser:shouldSignoutFromBrowser
                                                       oauthFactory:oauthFactory
                                                              error:error];
}

@end
