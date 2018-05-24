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
#import <SafariServices/SafariServices.h>
#import "MSIDSystemWebviewController.h"
#import "MSIDError.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDTelemetry.h"

@implementation MSIDWebviewAuthorization

static MSIDWebviewSession *s_currentSession = nil;

+ (void)startEmbeddedWebviewAuthWithConfiguration:(MSIDWebviewConfiguration *)configuration
                                          factory:(MSIDOauth2Factory *)factory
                                          context:(id<MSIDRequestContext>)context
                                completionHandler:(MSIDWebviewAuthCompletionHandler)completionHandler
{
    id<MSIDWebviewInteracting> embeddedWebviewController = [factory embeddedWebviewControllerWithConfiguration:configuration
                                                                                                 customWebview:nil
                                                                                                       context:context];
    [self startWebviewAuth:embeddedWebviewController
                   factory:factory
                   context:context
         completionHandler:completionHandler];
}

+ (void)startEmbeddedWebviewWebviewAuthWithConfiguration:(MSIDWebviewConfiguration *)configuration
                                                 factory:(MSIDOauth2Factory *)factory
                                                 webview:(WKWebView *)webview
                                                 context:(id<MSIDRequestContext>)context
                                       completionHandler:(MSIDWebviewAuthCompletionHandler)completionHandler
{
    id<MSIDWebviewInteracting> embeddedWebviewController = [factory embeddedWebviewControllerWithConfiguration:configuration
                                                                                                 customWebview:webview
                                                                                                       context:context];
    [self startWebviewAuth:embeddedWebviewController
                   factory:factory
                   context:context
         completionHandler:completionHandler];
}

+ (void)startSystemWebviewWebviewAuthWithConfiguration:(MSIDWebviewConfiguration *)configuration
                                               factory:(MSIDOauth2Factory *)factory
                                               context:(id<MSIDRequestContext>)context
                                     completionHandler:(MSIDWebviewAuthCompletionHandler)completionHandler
{
    
    id<MSIDWebviewInteracting> systemWebviewController = [factory systemWebviewControllerWithConfiguration:configuration
                                                                                         callbackURLScheme:configuration.redirectUri
                                                                                                   context:context];

    
    [self startWebviewAuth:systemWebviewController
                   factory:factory
                   context:context
         completionHandler:completionHandler];
}


+ (void)startWebviewAuth:(id<MSIDWebviewInteracting>)webviewController
                 factory:(MSIDOauth2Factory *)factory
                 context:(id<MSIDRequestContext>)context
       completionHandler:(MSIDWebviewAuthCompletionHandler)completionHandler
{
    if (![self setCurrentWebSession:webviewController factory:factory])
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionAlreadyRunning, @"Only one interactive session is allowed at a time.", nil, nil, nil, context.correlationId, nil);
        
        completionHandler(nil, error);
        return;
    }
    
    void (^startCompletionBlock)(NSURL *, NSError *) = ^void(NSURL *callbackURL, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            [MSIDWebviewAuthorization clearCurrentWebAuthSessionAndFactory];
            return;
        }
        
        NSError *responseError = nil;
        
        MSIDWebOAuth2Response *response = [s_currentSession.factory responseWithURL:callbackURL
                                                                       requestState:s_currentSession.requestState
                                                                            context:nil
                                                                              error:&responseError];
        
        completionHandler(response, responseError);
        [MSIDWebviewAuthorization clearCurrentWebAuthSessionAndFactory];
    };
    
    if (![s_currentSession.webviewController startWithCompletionHandler:startCompletionBlock])
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionStartFailure, @"Interactive web session failed to start.", nil, nil, nil, context.correlationId, nil);
        
        completionHandler(nil, error);
    }
}


+ (BOOL)setCurrentWebSession:(id<MSIDWebviewInteracting>)newWebSession
                     factory:(MSIDOauth2Factory *)factory
{
    @synchronized([MSIDWebviewAuthorization class])
    {
        if (s_currentSession) {
            MSID_LOG_INFO(nil, @"Session is already running. Please wait or cancel the session before setting it new.");
            return NO;   
        }

        s_currentSession = [[MSIDWebviewSession alloc] initWithWebviewController:newWebSession
                                                                         factory:factory
                                                                    requestState:[factory requestState]];
     
        return YES;
    }
    return NO;
}


+ (void)clearCurrentWebAuthSessionAndFactory
{
    @synchronized ([MSIDWebviewAuthorization class])
    {
        if (!s_currentSession)
        {
            // There's no error param because this isn't on a critical path. Just log that you are
            // trying to clear a session when there isn't one.
            MSID_LOG_INFO(nil, @"Trying to clear out an empty session");
        }
        
        s_currentSession = nil;
    }
}

+ (MSIDWebviewSession *)currentSession
{
    return s_currentSession;
}

+ (void)cancelCurrentSession
{
    @synchronized([MSIDWebviewAuthorization class])
    {
        if (s_currentSession)
        {
            [s_currentSession.webviewController cancel];
            s_currentSession = nil;
        }
    }
}



//
//+ (MSIDWebOAuth2Response *)responseWithURL:(NSURL *)url
//                              requestState:(NSString *)requestState
//                             stateVerifier:(MSIDWebUIStateVerifier)stateVerifier
//                                   context:(id<MSIDRequestContext>)context
//                                     error:(NSError **)error
//{
//    // This error case *really* shouldn't occur. If we're seeing it it's almost certainly a developer bug
//    if ([NSString msidIsStringNilOrBlank:url.absoluteString])
//    {
//        if (error) {
//            *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorNoAuthorizationResponse, @"No authorization response received from server.", nil, nil, nil, context.correlationId, nil);
//        }
//        return nil;
//    }
//    
//    NSDictionary *parameters = [self.class queryParametersFromURL:url];
//    
//    // Check if this is a WPJ response
//    MSIDWebWPJAuthResponse *wpjResponse = [[MSIDWebWPJAuthResponse alloc] initWithScheme:url.scheme
//                                                                                    host:url.host
//                                                                              parameters:parameters
//                                                                                 context:context
//                                                                                   error:nil];
//    if (wpjResponse)
//    {
//        wpjResponse.url = url;
//        return wpjResponse;
//    }
//    MSID_LOG_INFO(context, @"This is not a WPJ response");
//    
//    // Check for AAD response,
//    NSError *aadError = nil;
//    MSIDWebAADAuthResponse *aadResponse = [[MSIDWebAADAuthResponse alloc] initWithParameters:parameters
//                                                                                requestState:requestState
//                                                                               stateVerifier:stateVerifier
//                                                                                     context:context
//                                                                                       error:&aadError];
//    if (aadResponse)
//    {
//        aadResponse.url = url;
//        return aadResponse;
//    }
//    
//    if (aadError)
//    {
//        if (error) *error = aadError;
//        return nil;
//    }
//    
//    MSID_LOG_INFO(context, @"This is not an AAD response");
//    
//    // It is then, a standard OAuth2 response
//    //
//    // For now, there is no logic to really land here. As there is no definitive condition for response
//    // not being a AAD response.
////    MSIDWebOAuth2Response *oauth2Response = [[MSIDWebOAuth2Response alloc] initWithParameters:parameters
////                                                                                      context:context
////                                                                                        error:error];
////    if (oauth2Response)
////    {
////        oauth2Response.url = url;
////        return oauth2Response;
////    }
//    
//    return nil;
//}


+ (BOOL)handleURLResponseForSystemWebviewController:(NSURL *)url;
{
#if TARGET_OS_IPHONE
    @synchronized([MSIDWebviewAuthorization class])
    {
        if (s_currentSession &&
            [(NSObject *)s_currentSession.webviewController isKindOfClass:MSIDSystemWebviewController.class])
        {
            return [((MSIDSystemWebviewController *)s_currentSession.webviewController) handleURLResponseForSafariViewController:url];
        }
    }
#endif
    return NO;
}


@end



