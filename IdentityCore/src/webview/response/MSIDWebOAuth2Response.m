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

@implementation MSIDWebOAuth2Response

- (instancetype)initWithParameters:(NSDictionary *)parameters
                           context:(id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    NSString *authCode = parameters[MSID_OAUTH2_CODE];
    NSError *oauthError = [self.class oauthErrorFromParameters:parameters];
    
    if (!authCode && !oauthError)
    {
        return nil;
    }
    
    self = [super init];
    if (self)
    {
        // populate auth code
        _authorizationCode = authCode;
        
        // populate oauth error
        _oauthError = oauthError;
    }
    return self;
}

+ (NSError *)oauthErrorFromParameters:(NSDictionary *)parameters
{
    NSUUID *correlationId = [parameters objectForKey:MSID_OAUTH2_CORRELATION_ID_RESPONSE] ?
    [[NSUUID alloc] initWithUUIDString:[parameters objectForKey:MSID_OAUTH2_CORRELATION_ID_RESPONSE]]:nil;
    
    NSString *serverOAuth2Error = [parameters objectForKey:MSID_OAUTH2_ERROR];
    //login_required  ; has error_description
    //access_denied ; has error_subcode
    
    if (serverOAuth2Error)
    {
        NSString *errorDescription = parameters[MSID_OAUTH2_ERROR_DESCRIPTION];
        if (!errorDescription)
        {
            errorDescription = parameters[MSID_OAUTH2_ERROR_SUBCODE];
        }
        
        NSString *subError = parameters[MSID_OAUTH2_SUB_ERROR];
        MSIDErrorCode errorCode = MSIDErrorCodeForOAuthError(errorDescription, MSIDErrorAuthorizationFailed);
        
        return MSIDCreateError(MSIDOAuthErrorDomain, errorCode, errorDescription, serverOAuth2Error, subError, nil, correlationId, nil);
    }
    
    return nil;
}

@end
