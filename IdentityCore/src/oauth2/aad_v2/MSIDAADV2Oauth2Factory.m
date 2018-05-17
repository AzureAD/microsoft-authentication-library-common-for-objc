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
                 error:(NSError * __autoreleasing *)error
{
    if (![self checkResponseClass:response context:context error:error])
    {
        return NO;
    }

    BOOL result = [super verifyResponse:response context:context error:error];

    if (!result)
    {
        return NO;
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

    return YES;
}

#pragma mark - Tokens

- (MSIDBaseToken *)baseTokenFromResponse:(MSIDAADV2TokenResponse *)response
                                 configuration:(MSIDConfiguration *)configuration
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDBaseToken *baseToken = [super baseTokenFromResponse:response configuration:configuration];
    return [self fillAADV2BaseToken:baseToken fromResponse:response configuration:configuration];
}

- (MSIDAccessToken *)accessTokenFromResponse:(MSIDAADV2TokenResponse *)response
                                     configuration:(MSIDConfiguration *)configuration
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDAccessToken *accessToken = [super accessTokenFromResponse:response configuration:configuration];

    NSOrderedSet *responseScopes = response.scope.scopeSet;

    if (!response.scope)
    {
        responseScopes = configuration.scopes;
    }
    else
    {
        NSOrderedSet<NSString *> *reqScopes = configuration.scopes;

        if (reqScopes.count == 1 && [reqScopes.firstObject.lowercaseString hasSuffix:@".default"])
        {
            NSMutableOrderedSet<NSString *> *targetScopeSet = [responseScopes mutableCopy];
            [targetScopeSet unionOrderedSet:reqScopes];
            responseScopes = targetScopeSet;
        }
    }

    accessToken.scopes = responseScopes;

    return (MSIDAccessToken *) [self fillAADV2BaseToken:accessToken fromResponse:response configuration:configuration];
}

- (MSIDIdToken *)idTokenFromResponse:(MSIDAADTokenResponse *)response
                             configuration:(MSIDConfiguration *)configuration
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDIdToken *idToken = [super idTokenFromResponse:response configuration:configuration];
    return (MSIDIdToken *) [self fillAADV2BaseToken:idToken fromResponse:response configuration:configuration];
}

- (MSIDRefreshToken *)refreshTokenFromResponse:(MSIDAADTokenResponse *)response
                                       configuration:(MSIDConfiguration *)configuration
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDRefreshToken *token = [super refreshTokenFromResponse:response configuration:configuration];
    return (MSIDRefreshToken *) [self fillAADV2BaseToken:token fromResponse:response configuration:configuration];
}

- (MSIDLegacySingleResourceToken *)legacyTokenFromResponse:(MSIDAADTokenResponse *)response
                                                   configuration:(MSIDConfiguration *)configuration
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDLegacySingleResourceToken *token = [super legacyTokenFromResponse:response configuration:configuration];
    return (MSIDLegacySingleResourceToken *) [self fillAADV2BaseToken:token fromResponse:response configuration:configuration];
}

- (MSIDAccount *)accountFromResponse:(MSIDAADV2TokenResponse *)response
                             configuration:(MSIDConfiguration *)configuration
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDAccount *account = [super accountFromResponse:response configuration:configuration];
    MSIDAADV2IdTokenClaims *idToken = (MSIDAADV2IdTokenClaims *) response.idTokenObj;

    account.authority = [MSIDAuthority cacheUrlForAuthority:account.authority tenantId:idToken.tenantId];
    return account;
}

#pragma mark - Fill token

- (MSIDBaseToken *)fillAADV2BaseToken:(MSIDBaseToken *)baseToken
                         fromResponse:(MSIDAADTokenResponse *)response
                              configuration:(MSIDConfiguration *)configuration
{
    MSIDAADV2IdTokenClaims *idToken = (MSIDAADV2IdTokenClaims *) response.idTokenObj;
    baseToken.authority = [MSIDAuthority cacheUrlForAuthority:baseToken.authority tenantId:idToken.tenantId];

    return baseToken;
}

#pragma mark - Webview controllers
- (id<MSIDWebviewInteracting>)embeddedWebviewControllerWithRequest:(MSIDConfiguration *)requestParams
                                                           Webview:(WKWebView *)webview
{
    // Create MSIDEmbeddedWebviewRequest and create EmbeddedWebviewController
    return nil;
}

- (id<MSIDWebviewInteracting>)systemWebviewControllerWithRequest:(MSIDConfiguration *)requestParams
{
    // Create MSIDSystemWebviewRequest and create SystemWebviewController
    return nil;
}

@end
