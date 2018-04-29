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

#import "MSIDWebOAuth2Response.h"
#import "MSIDWebAADAuthResponse.h"
#import "MSIDWebWPJAuthResponse.h"

@implementation MSIDWebOAuth2Response

+ (MSIDWebOAuth2Response *)responseWithURL:(NSURL *)url
                              requestState:(NSString *)requestState
                             stateVerifier:(MSIDWebUIStateVerifier)stateVerifier
                                   context:(id<MSIDRequestContext>)context
                                     error:(NSError **)error;

{
    // This error case *really* shouldn't occur. If we're seeing it it's almost certainly a developer bug
    if ([NSString msidIsStringNilOrBlank:url.absoluteString])
    {
        if (error){
            *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorNoAuthorizationResponse, @"No authorization response received from server.", nil, nil, nil, context.correlationId, nil);
            return nil;
        }
    }
    
    // Check for WPJ response
    if ([url.absoluteString hasPrefix:@"msauth://"])
    {
        NSString *query = [url query];
        NSDictionary *queryParams = [NSDictionary msidURLFormDecode:query];
        NSString *appURLString = [queryParams objectForKey:@"app_link"];
        
        MSIDWebWPJAuthResponse *response = [MSIDWebWPJAuthResponse new];
        response.url = url;
        response.appInstallLink = appURLString;
        
        return response;
    }
    
    // Check for auth response
    // Try both the URL and the fragment parameters:
    NSDictionary *parameters = [url msidFragmentParameters];
    if (parameters.count == 0)
    {
        parameters = [url msidQueryParameters];
    }
    
    // Verify state
    BOOL stateVerified = stateVerifier(parameters, requestState);
    
    if (!stateVerified)
    {
        if (error){
            *error = MSIDCreateError(MSIDOAuthErrorDomain, MSALErrorInvalidState, @"State returned from the server does not match", nil, nil, nil, context.correlationId, nil);
            return nil;
        }
    }
    
    NSString *code = parameters[MSID_OAUTH2_CODE];
    NSString *cloudHostName = parameters[MSID_AUTH_CLOUD_INSTANCE_HOST_NAME];
    
    if (code)
    {
        MSIDWebAADAuthResponse *response = [MSIDWebAADAuthResponse new];
        response.url = url;
        response.authorizationCode = code;
        response.cloudHostName = cloudHostName;
        return response;
    }
    
    NSError *oauthError = [self.class oauthErrorFromDictionary:parameters];
    if (!oauthError)
    {
        oauthError = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorBadAuthorizationResponse, @"No code or error in server response.", nil, nil, nil, context.correlationId, nil);
    }
    
    MSIDWebOAuth2Response *response = [MSIDWebOAuth2Response new];
    response.url = url;
    response.oauthError = oauthError;
    
    return response;
    
}

+ (NSError *)oauthErrorFromDictionary:(NSDictionary *)dictionary
{
    NSUUID *correlationId = [dictionary objectForKey:MSID_OAUTH2_CORRELATION_ID_RESPONSE] ?
    [[NSUUID alloc] initWithUUIDString:[dictionary objectForKey:MSID_OAUTH2_CORRELATION_ID_RESPONSE]]:nil;
    
    NSString *serverOAuth2Error = [dictionary objectForKey:MSID_OAUTH2_ERROR];
    
    if (serverOAuth2Error)
    {
        NSString *errorDescription = dictionary[MSID_OAUTH2_ERROR_DESCRIPTION];
        NSString *subError = dictionary[MSID_OAUTH2_CORRELATION_ID_RESPONSE];
        
        MSIDErrorCode errorCode = MSIDErrorCodeForOAuthError(errorDescription, MSIDErrorAuthorizationFailed);
        
        return MSIDCreateError(MSIDOAuthErrorDomain, errorCode, errorDescription, serverOAuth2Error, subError, nil, correlationId, nil);
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
