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

#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDPkce.h"
#import "NSMutableDictionary+MSIDExtensions.h"
#import "MSIDSystemWebviewController.h"
#import "MSIDDeviceId.h"
#import "MSIDWebviewConfiguration.h"

#import "MSIDOauth2Factory+Internal.h"

#import "MSIDWebWPJAuthResponse.h"
#import "MSIDWebAADAuthResponse.h"


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
- (NSMutableDictionary<NSString *, NSString *> *)authorizationParametersFromConfiguration:(MSIDWebviewConfiguration *)configuration
                                                                             requestState:(NSString *)state
{
    NSMutableDictionary<NSString *, NSString *> *parameters = [super authorizationParametersFromConfiguration:configuration
                                                                                                 requestState:state];
    
    NSOrderedSet<NSString *> *allScopes = configuration.scopes;
    parameters[MSID_OAUTH2_SCOPE] = [NSString stringWithFormat:@"%@ %@", MSID_OAUTH2_SCOPE_OPENID_VALUE,  [allScopes msidToString]];
    parameters[MSID_OAUTH2_PROMPT] = configuration.promptBehavior;
    parameters[@"haschrome"] = @"1";
    
    return parameters;
}


#pragma mark - Webview response parsing
- (MSIDWebOAuth2Response *)responseWithURL:(NSURL *)url
                              requestState:(NSString *)requestState
                               verifyState:(BOOL)verifyState
                                   context:(id<MSIDRequestContext>)context
                                     error:(NSError **)error
{
    // Check for auth response
    // Try both the URL and the fragment parameters:
    NSDictionary *parameters = [url msidFragmentParameters];
    if (parameters.count == 0)
    {
        parameters = [url msidQueryParameters];
    }
    
    // check state, if verifyState is enabled, stop if verification fails.
    // otherwise, log and continue.
    if (![self verifyRequestState:requestState parameters:parameters])
    {
        if (verifyState)
        {
            if (error) {
                *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorInvalidState, @"State returned from the server does not match", nil, nil, nil, context.correlationId, nil);
            }
            return nil;
        }
        MSID_LOG_WARN(context, @"State returned from the server does not match");
    }
    
    MSIDWebWPJAuthResponse *wpjResponse = [[MSIDWebWPJAuthResponse alloc] initWithScheme:url.scheme
                                                                                    host:url.host
                                                                              parameters:parameters
                                                                                 context:context
                                                                                   error:nil];
    
    if (wpjResponse) return wpjResponse;

    NSError *responseCreationError = nil;
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithParameters:parameters
                                                                                  context:context
                                                                                    error:&responseCreationError];
    if (responseCreationError) {
        if (error)  *error = responseCreationError;
        return nil;
    }
    
    return response;
}



@end
