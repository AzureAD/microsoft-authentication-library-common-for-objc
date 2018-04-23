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

#import "MSIDAADV1Oauth2Factory.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAccessToken.h"
#import "MSIDBaseToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDAccount.h"

@implementation MSIDAADV1Oauth2Factory

#pragma mark - Helpers

- (BOOL)checkResponseClass:(MSIDTokenResponse *)response
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    if (![response isKindOfClass:[MSIDAADV1TokenResponse class]])
    {
        if (error)
        {
            NSString *errorMessage = [NSString stringWithFormat:@"Wrong token response type passed, which means wrong factory is being used (expected MSIDAADV1TokenResponse, passed %@", response.class];

            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorMessage, nil, nil, nil, context.correlationId, nil);
        }

        return NO;
    }

    return YES;
}

#pragma mark - Response

- (MSIDTokenResponse *)tokenResponseFromJSON:(NSDictionary *)json
                                     context:(id<MSIDRequestContext>)context
                                       error:(NSError **)error
{
    return [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:json error:error];
}

- (MSIDTokenResponse *)tokenResponseFromJSON:(NSDictionary *)json
                                refreshToken:(MSIDBaseToken<MSIDRefreshableToken> *)token
                                     context:(id<MSIDRequestContext>)context
                                       error:(NSError * __autoreleasing *)error
{
    return [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:json refreshToken:token error:error];
}

- (BOOL)verifyResponse:(MSIDAADV1TokenResponse *)response
               context:(id<MSIDRequestContext>)context
                 error:(NSError * __autoreleasing *)error
{
    return [self verifyResponse:response
               fromRefreshToken:NO
                        context:context
                          error:error];
}

- (BOOL)verifyResponse:(MSIDAADV1TokenResponse *)response
      fromRefreshToken:(BOOL)fromRefreshToken
               context:(id<MSIDRequestContext>)context
                 error:(NSError * __autoreleasing *)error
{
    if (![self checkResponseClass:response context:context error:error])
    {
        return NO;
    }

    BOOL result = [super verifyResponse:response context:context error:error];

    if (!result)
    {
        if (response.error)
        {
            MSIDErrorCode errorCode = fromRefreshToken ? MSIDErrorServerRefreshTokenRejected : MSIDErrorServerOauth;

            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     errorCode,
                                     response.errorDescription,
                                     response.error,
                                     nil,
                                     nil,
                                     context.correlationId,
                                     nil);
        }

        return result;
    }

    if (!response.clientInfo)
    {
        MSID_LOG_WARN(context, @"Client info was not returned in the server response");
        MSID_LOG_WARN_PII(context, @"Client info was not returned in the server response");
    }

    return YES;
}

#pragma mark - Tokens

- (MSIDAccessToken *)accessTokenFromResponse:(MSIDAADV1TokenResponse *)response
                                     request:(MSIDRequestParameters *)requestParams
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDAccessToken *accessToken = [super accessTokenFromResponse:response request:requestParams];
    accessToken.resource = response.target ? response.target : requestParams.target;

    return accessToken;
}

- (MSIDLegacySingleResourceToken *)legacyTokenFromResponse:(MSIDTokenResponse *)response
                                                   request:(MSIDRequestParameters *)requestParams
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDLegacySingleResourceToken *legacyToken = [super legacyTokenFromResponse:response request:requestParams];
    legacyToken.resource = response.target ? response.target : requestParams.target;
    return legacyToken;
}

#pragma mark - Webview controllers
- (id<MSIDWebviewInteracting>)embeddedWebviewControllerWithRequest:(MSIDRequestParameters *)requestParams
                                                           Webview:(WKWebView *)webview
{
    // Create MSIDEmbeddedWebviewRequest and create EmbeddedWebviewController
    return nil;
}

- (id<MSIDWebviewInteracting>)systemWebviewControllerWithRequest:(MSIDRequestParameters *)requestParams
{
    // Create MSIDSystemWebviewRequest and create SystemWebviewController
    return nil;
}

- (NSURL *)generateStartURL:(MSIDRequestParameters *)requestParams
{
    NSString* state = [self encodeProtocolState];
    NSString* queryParams = nil;
    // Start the web navigation process for the Implicit grant profile.
    NSMutableString* startUrl = [NSMutableString stringWithFormat:@"%@?%@=%@&%@=%@&%@=%@&%@=%@&%@=%@",
                                 [_context.authority stringByAppendingString:MSID_OAUTH2_AUTHORIZE_SUFFIX],
                                 MSID_OAUTH2_RESPONSE_TYPE, requestType,
                                 MSID_OAUTH2_CLIENT_ID, [[_requestParams clientId] msidUrlFormEncode],
                                 MSID_OAUTH2_RESOURCE, [[_requestParams resource] msidUrlFormEncode],
                                 MSID_OAUTH2_REDIRECT_URI, [[_requestParams redirectUri] msidUrlFormEncode],
                                 MSID_OAUTH2_STATE, state];
    
    [startUrl appendFormat:@"&%@", [[MSIDDeviceId deviceId] msidURLFormEncode]];
    
    if ([_requestParams identifier] && [[_requestParams identifier] isDisplayable] && ![NSString msidIsStringNilOrBlank:[_requestParams identifier].userId])
    {
        [startUrl appendFormat:@"&%@=%@", MSID_OAUTH2_LOGIN_HINT, [[_requestParams identifier].userId msidUrlFormEncode]];
    }
    NSString* promptParam = [ADAuthenticationContext getPromptParameter:_promptBehavior];
    if (promptParam)
    {
        //Force the server to ignore cookies, by specifying explicitly the prompt behavior:
        [startUrl appendString:[NSString stringWithFormat:@"&prompt=%@", promptParam]];
    }
    
    [startUrl appendString:@"&haschrome=1"]; //to hide back button in UI
    
    if (![NSString msidIsStringNilOrBlank:_queryParams])
    {//Append the additional query parameters if specified:
        queryParams = _queryParams.msidTrimmedString;
        
        //Add the '&' for the additional params if not there already:
        if ([queryParams hasPrefix:@"&"])
        {
            [startUrl appendString:queryParams];
        }
        else
        {
            [startUrl appendFormat:@"&%@", queryParams];
        }
    }
    
    if (![NSString msidIsStringNilOrBlank:_claims])
    {
        NSString *claimsParam = _claims.msidTrimmedString;
        [startUrl appendFormat:@"&claims=%@", claimsParam];
    }
    
    return startUrl;
}

@end
