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

#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAccessToken.h"
#import "MSIDBaseToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSIDAuthority.h"
#import "MSIDAccount.h"
#import "MSIDIdToken.h"
#import "MSIDOauth2Factory+Internal.h"
#import "MSIDAADV2WebviewFactory.h"
#import "MSIDAadAuthorityCache.h"
#import "NSString+MSIDExtensions.h"

@implementation MSIDAADV2Oauth2Factory

#pragma mark - Helpers

- (BOOL)checkResponseClass:(MSIDTokenResponse *)response
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    if (![response isKindOfClass:[MSIDAADV2TokenResponse class]])
    {
        if (error)
        {
            NSString *errorMessage = [NSString stringWithFormat:@"Wrong token response type passed, which means wrong factory is being used (expected MSIDAADV2TokenResponse, passed %@", response.class];

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
    return [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:json error:error];
}

- (MSIDTokenResponse *)tokenResponseFromJSON:(NSDictionary *)json
                                refreshToken:(MSIDBaseToken<MSIDRefreshableToken> *)token
                                     context:(id<MSIDRequestContext>)context
                                       error:(NSError * __autoreleasing *)error
{
    return [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:json refreshToken:token error:error];
}

- (BOOL)verifyResponse:(MSIDAADV2TokenResponse *)response
               context:(id<MSIDRequestContext>)context
         configuration:(MSIDConfiguration *)configuration
                 error:(NSError **)error
{
    if (![self checkResponseClass:response context:context error:error])
    {
        return NO;
    }

    BOOL result = [super verifyResponse:response context:context configuration:configuration error:error];

    if (!result)
    {
        if (response.error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     response.oauthErrorCode,
                                     response.errorDescription,
                                     response.error,
                                     response.suberror,
                                     nil,
                                     context.correlationId,
                                     nil);
        }

        return result;
    }

    if (!response.clientInfo)
    {
        MSID_LOG_ERROR(context, @"Client info was not returned in the server response");
        MSID_LOG_ERROR_PII(context, @"Client info was not returned in the server response");
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Client info was not returned in the server response", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }

    /*

     If server returns less scopes than developer requested,
     we'd like to throw an error and specify which scopes were granted and which ones not
     */

    NSOrderedSet *grantedScopes = [response.scope scopeSet];

    if (![configuration.scopes isSubsetOfOrderedSet:grantedScopes])
    {
        if (error)
        {
            NSMutableDictionary *additionalUserInfo = [NSMutableDictionary new];
            additionalUserInfo[MSIDGrantedScopesKey] = [grantedScopes array];

            NSMutableOrderedSet *requestedScopeSet = [configuration.scopes mutableCopy];
            [requestedScopeSet minusOrderedSet:grantedScopes];

            additionalUserInfo[MSIDDeclinedScopesKey] = [requestedScopeSet array];

            *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorServerInsufficientScopes, @"Server returned less scopes than requested", nil, nil, nil, context.correlationId, additionalUserInfo);
        }

        return NO;
    }

    return YES;
}

#pragma mark - Tokens

- (BOOL)fillAccessToken:(MSIDAccessToken *)accessToken
           fromResponse:(MSIDAADV2TokenResponse *)response
          configuration:(MSIDConfiguration *)configuration
{
    BOOL result = [super fillAccessToken:accessToken fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }

    NSOrderedSet *responseScopes = response.scope.scopeSet;

    if (!response.scope)
    {
        responseScopes = configuration.scopes;
    }

    accessToken.scopes = responseScopes;
    accessToken.authority = [MSIDAuthority cacheUrlForAuthority:accessToken.authority tenantId:response.idTokenObj.realm];

    return YES;
}

- (BOOL)fillIDToken:(MSIDIdToken *)token
       fromResponse:(MSIDTokenResponse *)response
      configuration:(MSIDConfiguration *)configuration
{
    BOOL result = [super fillIDToken:token fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }

    token.authority = [MSIDAuthority cacheUrlForAuthority:token.authority tenantId:response.idTokenObj.realm];

    return YES;
}

- (BOOL)fillAccount:(MSIDAccount *)account
       fromResponse:(MSIDAADV2TokenResponse *)response
      configuration:(MSIDConfiguration *)configuration
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return NO;
    }

    BOOL result = [super fillAccount:account fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }

    account.authority = [MSIDAuthority cacheUrlForAuthority:account.authority tenantId:response.idTokenObj.realm];
    return YES;
}

#pragma mark - Webview
- (MSIDWebviewFactory *)webviewFactory
{
    if (!_webviewFactory)
    {
        _webviewFactory = [[MSIDAADV2WebviewFactory alloc] init];
    }
    return _webviewFactory;
}

@end
