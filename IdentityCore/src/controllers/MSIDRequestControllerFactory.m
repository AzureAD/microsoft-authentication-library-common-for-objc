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
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDAutoRequestController.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDBrokerController.h"
#import "MSIDSilentController.h"
#import "MSIDAppExtensionUtil.h"
#import "MSIDAuthority.h"

@implementation MSIDRequestControllerFactory

+ (nullable id<MSIDRequestControlling>)silentControllerForParameters:(nonnull MSIDRequestParameters *)parameters
                                                        forceRefresh:(BOOL)forceRefresh
                                                tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                               error:(NSError *_Nullable *_Nullable)error
{
    return [[MSIDSilentController alloc] initWithRequestParameters:parameters
                                                      forceRefresh:forceRefresh
                                              tokenRequestProvider:tokenRequestProvider
                                                             error:error];
}

+ (nullable id<MSIDRequestControlling>)interactiveControllerForParameters:(nonnull MSIDInteractiveRequestParameters *)parameters
                                                     tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                                    error:(NSError *_Nullable *_Nullable)error
{
    if ([self canUseBrokerOnDeviceWithParameters:parameters])
    {
        return [[MSIDBrokerController alloc] initWithInteractiveRequestParameters:parameters
                                                             tokenRequestProvider:tokenRequestProvider
                                                                            error:error];
    }

    // Else check for prompt auto and return interactive otherwise
    if (parameters.uiBehaviorType == MSIDUIBehaviorPromptAutoType)
    {
        return [[MSIDAutoRequestController alloc] initWithInteractiveRequestParameters:parameters
                                                                  tokenRequestProvider:tokenRequestProvider
                                                                                 error:error];
    }

    if ([MSIDAppExtensionUtil isExecutingInAppExtension]
        && !(parameters.useEmbeddedWebView && parameters.customWebview))
    {
        // If developer provides us an custom webview, we should be able to use it for authentication in app extension
        BOOL hasSupportedEmbeddedWebView = parameters.useEmbeddedWebView && parameters.customWebview;
        BOOL hasSupportedSystemWebView = parameters.useSafariViewController && parameters.parentViewController;

        if (!hasSupportedEmbeddedWebView && !hasSupportedSystemWebView)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUINotSupportedInExtension, @"Interaction is not supported in an app extension.", nil, nil, nil, parameters.correlationId, nil);
            }

            return nil;
        }
    }

    return [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:parameters
                                                                   tokenRequestProvider:tokenRequestProvider
                                                                                  error:error];
}

+ (BOOL)canUseBrokerOnDeviceWithParameters:(MSIDInteractiveRequestParameters *)parameters
{
#if TARGET_OS_IPHONE

    if (parameters.requestType != MSIDInteractiveRequestBrokeredType)
    {
        return NO;
    }

    if ([MSIDAppExtensionUtil isExecutingInAppExtension])
    {
        return NO;
    }

    if (!parameters.authority.supportsBrokeredAuthentication)
    {
        return NO;
    }

    // TODO: why this is important?
    if (!parameters.validateAuthority)
    {
        return NO;
    }

    return [self isBrokerInstalled:parameters];
#else
    return NO;
#endif
}

+ (BOOL)isBrokerInstalled:(MSIDInteractiveRequestParameters *)parameters
{
#if AD_BROKER
    return YES;
#else

    if (![NSThread isMainThread])
    {
        __block BOOL result = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            result = [self isBrokerInstalled:parameters];
        });

        return result;
    }

    if (![MSIDAppExtensionUtil isExecutingInAppExtension])
    {
        // Verify broker app url can be opened
        return [[MSIDAppExtensionUtil sharedApplication] canOpenURL:[[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@://broker", parameters.supportedBrokerProtocolScheme]]];
    }
    else
    {
        // Cannot perform app switching from application extension hosts
        return NO;
    }
#endif
}

@end
