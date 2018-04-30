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

#import "MSIDWebviewAuthorization.h"
#import "MSIDWebviewInteracting.h"
#import "MSIDOauth2Factory.h"
#import "MSIDAADV1Oauth2Factory.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDWebOAuth2Response.h"
#import "MSIDWebAADAuthResponse.h"
#import "MSIDWebWPJAuthResponse.h"
#import <SafariServices/SafariServices.h>
#import "MSIDSystemWebviewController.h"

@implementation MSIDWebviewAuthorization

static id<MSIDWebviewInteracting> s_currentWebSession = nil;

+ (void)startEmbeddedWebviewAuthWithRequestParameters:(MSIDRequestParameters *)parameters
                                              factory:(MSIDOauth2Factory *)factory
                                              context:(id<MSIDRequestContext>)context
                                    completionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    id<MSIDWebviewInteracting> embeddedWebviewController = [factory embeddedWebviewControllerWithRequest:parameters
                                                                                           customWebview:nil
                                                                                       completionHandler:completionHandler];
    [self startWebviewAuth:embeddedWebviewController
                   context:context
         completionHandler:completionHandler];
}

+ (void)startEmbeddedWebviewWebviewAuthWithRequestParameters:(MSIDRequestParameters *)parameters
                                                     webview:(WKWebView *)webview
                                                     factory:(MSIDOauth2Factory *)factory
                                                     context:(id<MSIDRequestContext>)context
                                           completionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    id<MSIDWebviewInteracting> embeddedWebviewController = [factory embeddedWebviewControllerWithRequest:parameters
                                                                                           customWebview:webview
                                                                                       completionHandler:completionHandler];
    [self startWebviewAuth:embeddedWebviewController
                   context:context
         completionHandler:completionHandler];
}

+ (void)startSystemWebviewWebviewAuthWithRequestParameters:(MSIDRequestParameters *)parameters
                                         callbackURLScheme:(NSString *)callbackURLScheme
                                                   factory:(MSIDOauth2Factory *)factory
                                                   context:(id<MSIDRequestContext>)context
                                         completionHandler:(MSIDWebUICompletionHandler)completionHandler
{

    id<MSIDWebviewInteracting> systemWebviewController = [factory systemWebviewControllerWithRequest:parameters
                                                                                   callbackURLScheme:callbackURLScheme
                                                                                   completionHandler:completionHandler];
    [self startWebviewAuth:systemWebviewController
                   context:context
         completionHandler:completionHandler];
}

+ (void)startWebviewAuth:(id<MSIDWebviewInteracting>)webviewController
                 context:(id<MSIDRequestContext>)context
       completionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    if (![self setCurrentWebSession:webviewController])
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionAlreadyRunning, @"Only one interactive session is allowed at a time.", nil, nil, nil, context.correlationId, nil);
        
        completionHandler(nil, error);
        return;
    }
    
    if (![s_currentWebSession start])
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionStartFailure, @"Interactive web session failed to start.", nil, nil, nil, context.correlationId, nil);
        
        completionHandler(nil, error);
    }
}


+ (BOOL)setCurrentWebSession:(id<MSIDWebviewInteracting>)newWebSession
{
    if (!s_currentWebSession)
    {
        @synchronized([MSIDWebviewAuthorization class])
        {
            s_currentWebSession = newWebSession;
        }
        return YES;
    }
    
    return NO;
}


// Helper methods
+ (NSDictionary *)queryParametersFromURL:(NSURL *)url
{
    // Check for auth response
    // Try both the URL and the fragment parameters:
    NSDictionary *parameters = [url msidFragmentParameters];
    if (parameters.count == 0)
    {
        parameters = [url msidQueryParameters];
    }
    return parameters;
}

+ (NSError *)oauthErrorFromURL:(NSURL *)url
{
    NSDictionary *dictionary = [self.class queryParametersFromURL:url];
    
    NSUUID *correlationId = [dictionary objectForKey:MSID_OAUTH2_CORRELATION_ID_RESPONSE] ?
    [[NSUUID alloc] initWithUUIDString:[dictionary objectForKey:MSID_OAUTH2_CORRELATION_ID_RESPONSE]]:nil;
    
    NSString *serverOAuth2Error = [dictionary objectForKey:MSID_OAUTH2_ERROR];
    
    if (serverOAuth2Error)
    {
        NSString *errorDescription = dictionary[MSID_OAUTH2_ERROR_DESCRIPTION];
        NSString *subError = dictionary[MSID_OAUTH2_SUB_ERROR];
        
        MSIDErrorCode errorCode = MSIDErrorCodeForOAuthError(errorDescription, MSIDErrorAuthorizationFailed);
        
        return MSIDCreateError(MSIDOAuthErrorDomain, errorCode, errorDescription, serverOAuth2Error, subError, nil, correlationId, nil);
    }
    
    return nil;
}

+ (MSIDWebOAuth2Response *)responseWithURL:(NSURL *)url
                              requestState:(NSString *)requestState
                             stateVerifier:(MSIDWebUIStateVerifier)stateVerifier
                                   context:(id<MSIDRequestContext>)context
                                     error:(NSError **)error
{
    // This error case *really* shouldn't occur. If we're seeing it it's almost certainly a developer bug
    if ([NSString msidIsStringNilOrBlank:url.absoluteString])
    {
        if (error){
            *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorNoAuthorizationResponse, @"No authorization response received from server.", nil, nil, nil, context.correlationId, nil);
            return nil;
        }
    }
    
    NSDictionary *parameters = [self.class queryParametersFromURL:url];
    
    // Check if this is a WPJ response
    MSIDWebWPJAuthResponse *wpjResponse = [[MSIDWebWPJAuthResponse alloc] initWithScheme:url.scheme
                                                                              parameters:parameters
                                                                                 context:context
                                                                                   error:error];
    if (wpjResponse)
    {
        wpjResponse.url = url;
        return wpjResponse;
    }
    
    // Check for AAD response
    MSIDWebAADAuthResponse *aadResponse = [[MSIDWebAADAuthResponse alloc] initWithParameters:parameters
                                                                                requestState:requestState
                                                                               stateVerifier:stateVerifier
                                                                                     context:context
                                                                                       error:error];
    if (aadResponse)
    {
        aadResponse.url = url;
        return aadResponse;
    }
    
    // It is then, a standard OAuth2 response
    MSIDWebOAuth2Response *oauth2Response = [[MSIDWebOAuth2Response alloc] initWithParameters:parameters
                                                                                      context:context
                                                                                        error:error];
    if (oauth2Response)
    {
        oauth2Response.url = url;
        return oauth2Response;
        
    }
    
    // Any other errors are caught here
    if (error)
    {
        *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorBadAuthorizationResponse, @"No code or error in server response.", nil, nil, nil, context.correlationId, nil);
        
    }
    return nil;
}


+ (void)cancelCurrentWebAuthSession
{
    if (s_currentWebSession)
    {
        [s_currentWebSession cancel];
        
        @synchronized([MSIDWebviewAuthorization class])
        {
            s_currentWebSession = nil;
        }
    }
}

+ (BOOL)handleURLResponseForSystemWebviewController:(NSURL *)url;
{
#if TARGET_OS_IPHONE
    if (s_currentWebSession &&
        [(NSObject *)s_currentWebSession isKindOfClass:MSIDSystemWebviewController.class])
    {
        return [((MSIDSystemWebviewController *)s_currentWebSession) handleURLResponseForSafariViewController:url];
    }
#endif
    return NO;
}


@end
