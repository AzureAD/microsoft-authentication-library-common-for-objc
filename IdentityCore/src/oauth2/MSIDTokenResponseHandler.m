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

#import "MSIDTokenResponseHandler.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDRequestContext.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDError.h"
#import "MSIDClientInfo.h"
#import "MSIDAADV2RequestParameters.h"
#import "NSOrderedSet+MSIDExtensions.h"

@implementation MSIDTokenResponseHandler

+ (BOOL)processResponse:(MSIDAADTokenResponse *)response
           refreshToken:(NSString *)refreshToken
          requestParams:(MSIDRequestParameters *)parameters
                context:(id<MSIDRequestContext>)context
                  error:(NSError * __autoreleasing *)error
{
    if (!response)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorInternal, @"processTokenResponse called without a response dictionary", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    [self.class checkCorrelationId:response requestCorrelationId:context.correlationId];
    
    if (response.error)
    {
        if (error)
        {
            MSIDErrorCode errorCode = refreshToken ? MSIDErrorServerRefreshTokenRejected : MSIDErrorServerOauth;
            if ([response isKindOfClass:MSIDAADV2TokenResponse.class])
            {
                errorCode = [self.class getErrorCodeForAADV2:response.error];
            }
            
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     errorCode,
                                     response.errorDescription,
                                     response.error,
                                     nil,
                                     nil,
                                     context.correlationId,
                                     nil);
        }
        return NO;
    }
    
    if ([NSString msidIsStringNilOrBlank:response.accessToken])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Authentication response received without expected accessToken", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    if (!response.clientInfo)
    {
        MSID_LOG_ERROR(context, @"Client info was not returned in the server response");
        MSID_LOG_ERROR_PII(context, @"Client info was not returned in the server response");
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorInternal, @"Client info was not returned in the server response", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    // Checking for V1 response is done
    if (![response isKindOfClass:MSIDAADV2TokenResponse.class] || ![parameters isKindOfClass:MSIDAADV2RequestParameters.class])
    {
        return YES;
    }
    
    // The rest of the checking is only for V2
    MSIDAADV2RequestParameters *aadV2Parameters = (MSIDAADV2RequestParameters *)parameters;
    if ([NSString msidIsStringNilOrBlank:response.scope])
    {
        MSID_LOG_INFO(context, @"No scope in server response, using passed in scope instead.");
        MSID_LOG_INFO_PII(context, @"No scope in server response, using passed in scope instead.");
        [response setScope:aadV2Parameters.scopes.msidToString];
    }
    
    // For silent flow, with grant type being MSID_OAUTH2_REFRESH_TOKEN, this value may be missing from the response.
    // In this case, we simply return the refresh token in the request.
    if (refreshToken)
    {
        if (!response.refreshToken)
        {
            response.refreshToken = refreshToken;
            MSID_LOG_WARN(context, @"Refresh token was missing from the token refresh response, so the refresh token in the request is returned instead");
            MSID_LOG_WARN_PII(context, @"Refresh token was missing from the token refresh response, so the refresh token in the request is returned instead");
        }
    }
    
    // TODO: ADAL and MSAL are checking if user matches in different places. Discuss if we should move that logic to this function
    
    return YES;
}

+ (void)checkCorrelationId:(MSIDAADTokenResponse *)response
      requestCorrelationId:(NSUUID *)requestCorrelationId
{
    MSID_LOG_VERBOSE_CORR(requestCorrelationId, @"Token extraction. Attempt to extract the data from the server response.");
    
    NSString *responseId = [response correlationId];
    if (![NSString msidIsStringNilOrBlank:responseId])
    {
        NSUUID *responseUUID = [[NSUUID alloc] initWithUUIDString:responseId];
        if (!responseUUID)
        {
            MSID_LOG_INFO_CORR(requestCorrelationId, @"Bad correlation id - The received correlation id is not a valid UUID. Sent: %@; Received: %@", requestCorrelationId, responseId);
        }
        else if (![requestCorrelationId isEqual:responseUUID])
        {
            MSID_LOG_INFO_CORR(requestCorrelationId, @"Correlation id mismatch - Mismatch between the sent correlation id and the received one. Sent: %@; Received: %@", requestCorrelationId, responseId);
        }
    }
    else
    {
        MSID_LOG_INFO_CORR(requestCorrelationId, @"Missing correlation id - No correlation id received for request with correlation id: %@", [requestCorrelationId UUIDString]);
    }
}

+ (MSIDErrorCode)getErrorCodeForAADV2:(NSString *)oauthError
{
    if ([oauthError isEqualToString:@"invalid_request"])
    {
        return MSIDErrorInvalidRequest;
    }
    if ([oauthError isEqualToString:@"invalid_client"])
    {
        return MSIDErrorInvalidClient;
    }
    if ([oauthError isEqualToString:@"invalid_scope"])
    {
        return MSIDErrorInvalidParameter;
    }
    
    return MSIDErrorInteractionRequired;
}

@end

