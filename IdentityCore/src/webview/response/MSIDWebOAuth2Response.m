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

- (instancetype)initWithURL:(NSURL *)url
          authorizationCode:(NSString *)authorizationCode
                 oauthError:(NSError *)oauthError
{
    self = [super init];
    if (self)
    {
        _url = url;
        _authorizationCode = authorizationCode;
        _oauthError = oauthError;
    }
    return self;
}

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
    MSIDWebWPJAuthResponse *wpjResponse = [[MSIDWebWPJAuthResponse alloc] initWithURL:url];
    if (wpjResponse)
    {
        return wpjResponse;
    }
    
    // Check for AAD response
    MSIDWebAADAuthResponse *aadResponse = [[MSIDWebAADAuthResponse alloc] initWithURL:url
                                                                         requestState:requestState
                                                                        stateVerifier:stateVerifier
                                                                              context:context
                                                                                error:error];
    
    if (aadResponse)
    {
        return aadResponse;
    }
    
    NSError *oauthError = [self.class oauthErrorFromURL:url];
    if (!oauthError)
    {
        oauthError = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorBadAuthorizationResponse, @"No code or error in server response.", nil, nil, nil, context.correlationId, nil);
    }
    
    
    return [[MSIDWebOAuth2Response alloc] initWithURL:url
                                    authorizationCode:nil
                                           oauthError:oauthError];
}

+ (NSDictionary *)queryParams:(NSURL *)url
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
    NSDictionary *dictionary = [self.class queryParams:url];
    
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

@end
