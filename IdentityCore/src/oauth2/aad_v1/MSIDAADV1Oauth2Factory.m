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
#import "MSIDDeviceId.h"

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

- (NSURL *)startURLFrom:(MSIDRequestParameters *)requestParams
{
    NSString* state = [self encodeProtocolState:requestParams];
    
    // if value is nil, it won't appear in the dictionary
    NSMutableDictionary *queryParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        MSID_OAUTH2_CODE, MSID_OAUTH2_RESPONSE_TYPE,
                                        [requestParams clientId], MSID_OAUTH2_CLIENT_ID,
                                        [requestParams resource], MSID_OAUTH2_RESOURCE,
                                        [requestParams redirectUri], MSID_OAUTH2_REDIRECT_URI,
                                        state, MSID_OAUTH2_STATE,
                                        requestParams.promptBehavior, @"prompt",
                                        @"1", @"hashchrome", //to hide back button in UI
                                        [NSString msidIsStringNilOrBlank:requestParams.loginHint] ? nil : requestParams.loginHint, MSID_OAUTH2_LOGIN_HINT, 
                                        nil];
    
    [queryParams addEntriesFromDictionary:[MSIDDeviceId deviceId]];
    
    NSMutableString* startUrl = [NSMutableString stringWithFormat:@"%@?%@",
                                 [requestParams.authority.absoluteString stringByAppendingString:MSID_OAUTH2_AUTHORIZE_SUFFIX], [queryParams msidURLFormEncode]];
    
    // we expect extraQueryParameters to be URL form encoded
    if (![NSString msidIsStringNilOrBlank:requestParams.extraQueryParameters])
    {
        //Add the '&' for the additional params if not there already:
        if ([requestParams.extraQueryParameters hasPrefix:@"&"])
        {
            [startUrl appendString:requestParams.extraQueryParameters.msidTrimmedString];
        }
        else
        {
            [startUrl appendFormat:@"&%@", requestParams.extraQueryParameters.msidTrimmedString];
        }
    }
    
    // we expect claims to be URL form encoded
    if (![NSString msidIsStringNilOrBlank:requestParams.claims])
    {
        [startUrl appendFormat:@"&claims=%@", requestParams.claims];
    }
    
    return [NSURL URLWithString:startUrl];
}

// Encodes the state parameter for a protocol message
- (NSString *)encodeProtocolState:(MSIDRequestParameters *)requestParams
{
    return [[[NSMutableDictionary dictionaryWithObjectsAndKeys:[requestParams authority], @"a", [requestParams resource], @"r", nil]
             msidURLFormEncode] msidBase64UrlEncode];
}

@end
