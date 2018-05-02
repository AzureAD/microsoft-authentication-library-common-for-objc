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
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDOauth2Factory.h"
#import "MSIDWebAADAuthResponse.h"
#import "MSIDError.h"
#import "MSIDWebWPJAuthResponse.h"

id<MSIDWebviewInteracting> s_webviewController;

@implementation MSIDWebviewAuthorization

+ (id<MSIDWebviewInteracting>)systemWebviewControllerWithRequestParameters:(MSIDRequestParameters *)parameters
                                                                   factory:(MSIDOauth2Factory *)factory;
{
    return nil;
}

+ (BOOL)handleURLResponse:(NSURL *)url
{
    return NO;
}

+ (void)startEmbeddedWebviewAuthWithRequestParameters:(MSIDRequestParameters *)parameters
                                              factory:(MSIDOauth2Factory *)factory
                                              context:(id<MSIDRequestContext>)context
                                    completionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    [self startEmbeddedWebviewWebviewAuthWithRequestParameters:parameters
                                                       webview:nil
                                                       factory:factory
                                                       context:context
                                             completionHandler:completionHandler];
}

+ (void)startEmbeddedWebviewWebviewAuthWithRequestParameters:(MSIDRequestParameters *)parameters
                                                     webview:(WKWebView *)webview
                                                     factory:(MSIDOauth2Factory *)factory
                                                     context:(id<MSIDRequestContext>)context
                                           completionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    //TODO: rewrite the following to fit JK's work
    
    NSURL *startURL = [factory startURLFromRequest:parameters];
    s_webviewController = [[MSIDOAuth2EmbeddedWebviewController alloc] initWithStartUrl:startURL
                                                                                 endURL:[NSURL URLWithString:[parameters redirectUri]]
                                                                                webview:webview
                                                                                context:context
                                                                             completion:completionHandler];
    [s_webviewController start];
}

+ (MSIDWebOAuth2Response *)parseUrlResponse:(NSURL *)url
                                     context:(id<MSIDRequestContext>)context
                                      error:(NSError **)error
{
    // Check for WPJ response
    if([url.absoluteString hasPrefix:@"msauth://"])
    {
        NSString* query = [url query];
        NSDictionary* queryParams = [NSDictionary msidURLFormDecode:query];
        NSString* appURLString = [queryParams objectForKey:@"app_link"];
        
        MSIDWebWPJAuthResponse *response = [MSIDWebWPJAuthResponse new];
        [response setAppInstallLink:appURLString];
        return response;
    }
    
    // Check for auth response
    // Try both the URL and the fragment parameters:
    NSDictionary *parameters = [url msidFragmentParameters];
    if ( parameters.count == 0 )
    {
        parameters = [url msidQueryParameters];
    }
    
    NSString *code = nil;
    NSString *cloudHostName = nil;
    NSError *oauthError = [self oauthErrorFromDictionary:parameters];
    if (!oauthError)
    {
        //Note that we do not enforce the state, just log it:
        [self verifyStateFromDictionary:parameters context:context];
        
        code = [parameters objectForKey:MSID_OAUTH2_CODE];
        if ([NSString msidIsStringNilOrBlank:code])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorAuthorizationCode, @"The authorization server did not return a valid authorization code.", nil, nil, nil, context.correlationId, nil);
                return nil;
            }
        }
        
        cloudHostName = [parameters objectForKey:MSID_AUTH_CLOUD_INSTANCE_HOST_NAME];
    }
    
    MSIDWebAADAuthResponse *response = [MSIDWebAADAuthResponse new];
    [response setCode:code];
    [response setOauthError:oauthError];
    [response setCloudHostName:cloudHostName];
    return response;
}

+ (NSError *)oauthErrorFromDictionary:(NSDictionary *)dictionary
{
    NSString *serverOAuth2Error = [dictionary objectForKey:MSID_OAUTH2_ERROR];
    
    if (![NSString msidIsStringNilOrBlank:serverOAuth2Error])
    {
        NSString *errorDetails = [dictionary objectForKey:MSID_OAUTH2_ERROR_DESCRIPTION];
        NSUUID *correlationId = [dictionary objectForKey:MSID_OAUTH2_CORRELATION_ID_RESPONSE] ?
        [[NSUUID alloc] initWithUUIDString:[dictionary objectForKey:MSID_OAUTH2_CORRELATION_ID_RESPONSE]]:
        nil;
        
        return MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorAuthorizationCode, errorDetails, serverOAuth2Error, nil, nil, correlationId, nil);
    }
    
    return nil;
}

// TODO: check if we have it in MSAL
+ (BOOL)verifyStateFromDictionary: (NSDictionary*) dictionary
                          context:(id<MSIDRequestContext>)context
{
    NSDictionary *state = [NSDictionary msidURLFormDecode:[[dictionary objectForKey:MSID_OAUTH2_STATE] msidBase64UrlDecode]];
    if (state.count != 0)
    {
        NSString *authorizationServer = [state objectForKey:@"a"];
        NSString *resource            = [state objectForKey:@"r"];
        
        if (![NSString msidIsStringNilOrBlank:authorizationServer] && ![NSString msidIsStringNilOrBlank:resource])
        {
            MSID_LOG_VERBOSE_PII(context, @"The authorization server returned the following state: %@", state);
            return YES;
        }
    }
    
    MSID_LOG_WARN(context, @"Missing or invalid state returned");
    MSID_LOG_WARN_PII(context, @"Missing or invalid state returned state: %@", state);
    return NO;
}

@end
