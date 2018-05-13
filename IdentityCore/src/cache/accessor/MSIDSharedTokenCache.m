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

#import "MSIDSharedTokenCache.h"
#import "MSIDCacheKey.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDBaseToken.h"
#import "MSIDIdToken.h"
#import "MSIDOauth2Factory.h"

@interface MSIDSharedTokenCache()
{
    // Primary cache accessor
    id<MSIDSharedCacheAccessor> _primaryAccessor;

    // Other shared accessors
    NSArray<id<MSIDSharedCacheAccessor>> *_otherAccessors;
}

@end

@implementation MSIDSharedTokenCache

#pragma mark - Init

- (instancetype)initWithPrimaryCacheAccessor:(id<MSIDSharedCacheAccessor>)primaryAccessor
                         otherCacheAccessors:(NSArray<id<MSIDSharedCacheAccessor>> *)otherAccessors
{
    self = [super init];
    
    if (self)
    {
        _primaryAccessor = primaryAccessor;
        _otherAccessors = otherAccessors;
    }
    
    return self;
}

#pragma mark - Save tokens

- (BOOL)saveTokensWithFactory:(MSIDOauth2Factory *)factory
                 requestParams:(MSIDRequestParameters *)requestParams
                      response:(MSIDTokenResponse *)response
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    return [self saveTokensWithFactory:factory
                         requestParams:requestParams
                              response:response
                      saveSSOStateOnly:NO
                               context:context
                                 error:error];
}

- (BOOL)saveTokensWithFactory:(MSIDOauth2Factory *)factory
               brokerResponse:(MSIDBrokerResponse *)response
             saveSSOStateOnly:(BOOL)saveSSOStateOnly
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    MSIDRequestParameters *params = [[MSIDRequestParameters alloc] initWithAuthority:[NSURL URLWithString:response.authority]
                                                                         redirectUri:nil
                                                                            clientId:response.clientId
                                                                              target:response.resource];

    return [self saveTokensWithFactory:factory
                         requestParams:params
                              response:response.tokenResponse
                      saveSSOStateOnly:saveSSOStateOnly
                               context:context
                                 error:error];
}

#pragma mark - Get tokens

- (MSIDAccessToken *)getATForAccount:(id<MSIDAccountIdentifiers>)account
                       requestParams:(MSIDRequestParameters *)parameters
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    return (MSIDAccessToken *) [_primaryAccessor getTokenWithType:MSIDCredentialTypeAccessToken
                                                          account:account
                                                    requestParams:parameters
                                                          context:context
                                                            error:error];
}

- (MSIDLegacySingleResourceToken *)getLegacyTokenForAccount:(id<MSIDAccountIdentifiers>)account
                                              requestParams:(MSIDRequestParameters *)parameters
                                                    context:(id<MSIDRequestContext>)context
                                                      error:(NSError **)error
{
    return (MSIDLegacySingleResourceToken *) [_primaryAccessor getTokenWithType:MSIDCredentialTypeLegacySingleResourceToken
                                                                        account:account
                                                                  requestParams:parameters
                                                                        context:context
                                                                          error:error];
}

- (MSIDRefreshToken *)getRTForAccount:(id<MSIDAccountIdentifiers>)account
                        requestParams:(MSIDRequestParameters *)parameters
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    MSIDRefreshToken *token = (MSIDRefreshToken *) [_primaryAccessor getTokenWithType:MSIDCredentialTypeRefreshToken
                                                                              account:account
                                                                        requestParams:parameters
                                                                              context:context
                                                                                error:error];

    if (!token)
    {
        for (id<MSIDSharedCacheAccessor> cache in _otherAccessors)
        {
            MSIDRefreshToken *token = (MSIDRefreshToken *) [cache getTokenWithType:MSIDCredentialTypeRefreshToken
                                                                           account:account
                                                                     requestParams:parameters
                                                                           context:context
                                                                             error:error];

            if (token)
            {
                return token;
            }
        }
    }

    return nil;
}


- (MSIDRefreshToken *)getFRTforAccount:(id<MSIDAccountIdentifiers>)account
                         requestParams:(MSIDRequestParameters *)parameters
                              familyId:(NSString *)familyId
                               context:(id<MSIDRequestContext>)context
                                 error:(NSError **)error
{
    parameters.clientId = [MSIDCacheKey familyClientId:familyId];
    
    return [self getRTForAccount:account
                   requestParams:parameters
                         context:context
                           error:error];
}

- (NSArray<MSIDRefreshToken *> *)getAllClientRTs:(NSString *)clientId
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    NSArray *primaryRTs = [_primaryAccessor getAllTokensOfType:MSIDCredentialTypeRefreshToken withClientId:clientId context:context error:error];

    if (!primaryRTs)
    {
        return nil;
    }

    NSMutableArray *resultRTs = [primaryRTs mutableCopy];
    
    // Get RTs from all caches
    for (id<MSIDSharedCacheAccessor> cache in _otherAccessors)
    {
        NSArray *otherRTs = [cache getAllTokensOfType:MSIDCredentialTypeRefreshToken
                                         withClientId:clientId
                                              context:context
                                                error:error];
        
        if (otherRTs)
        {
            [resultRTs addObjectsFromArray:otherRTs];
        }
    }
    
    return resultRTs;
}

#pragma mark - Account

- (BOOL)removeAccount:(MSIDAccount *)account
              context:(id<MSIDRequestContext>)context
                error:(NSError **)error
{
    return [_primaryAccessor removeAccount:account context:context error:error];
}

#pragma mark - Remove tokens

- (BOOL)removeRefreshToken:(MSIDBaseToken<MSIDRefreshableToken> *)token
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    if (!token || [NSString msidIsStringNilOrBlank:token.refreshToken])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Removing tokens can be done only as a result of a token request. Valid refresh token should be provided.", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    MSID_LOG_VERBOSE(context, @"Removing refresh token with clientID %@, authority %@", token.clientId, token.authority);
    MSID_LOG_VERBOSE_PII(context, @"Removing refresh token with clientID %@, authority %@, userId %@, token %@", token.clientId, token.authority, token.uniqueUserId, _PII_NULLIFY(token.refreshToken));
    
    NSError *cacheError = nil;

    MSIDBaseToken<MSIDRefreshableToken> *tokenInCache = (MSIDBaseToken<MSIDRefreshableToken> *)[_primaryAccessor getUpdatedToken:token
                                                                                                                         context:context
                                                                                                                           error:&cacheError];
    
    if (cacheError)
    {
        if (error)
        {
            *error = cacheError;
        }
        return NO;
    }
    
    if (tokenInCache && [tokenInCache.refreshToken isEqualToString:token.refreshToken])
    {
        MSID_LOG_VERBOSE(context, @"Found refresh token in cache and it's the latest version, removing token");
        MSID_LOG_VERBOSE_PII(context, @"Found refresh token in cache and it's the latest version, removing token %@", token);
        
        return [_primaryAccessor removeToken:tokenInCache
                                     context:context
                                       error:error];
    }
    
    return YES;
}

- (BOOL)removeToken:(MSIDBaseToken *)token
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    return [_primaryAccessor removeToken:token
                                 context:context
                                   error:error];
}

- (BOOL)removeAllTokensForAccount:(id<MSIDAccountIdentifiers>)account
                      environment:(NSString *)environment
                         clientId:(NSString *)clientId
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    return [_primaryAccessor removeAllTokensForAccount:account
                                           environment:environment
                                              clientId:clientId
                                               context:context
                                                 error:error];
}

- (BOOL)clearWithContext:(id<MSIDRequestContext>)context error:(NSError **)error
{
    for (id<MSIDSharedCacheAccessor> cache in _otherAccessors)
    {
        BOOL result = [cache clearWithContext:context error:error];
        if (!result) return NO;
    }
    
    return [_primaryAccessor clearWithContext:context error:error];
}

#pragma mark - Private

- (BOOL)saveSSOStateInOtherAccessorsWithFactory:(MSIDOauth2Factory *)factory
                                  requestParams:(MSIDRequestParameters *)requestParams
                                       response:(MSIDTokenResponse *)response
                                        context:(id<MSIDRequestContext>)context
                                          error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"Saving SSO state in all caches");

    for (id<MSIDSharedCacheAccessor> accessor in _otherAccessors)
    {
        if (![accessor saveSSOStateWithFactory:factory
                                 requestParams:requestParams
                                      response:response
                                       context:context
                                         error:error])
        {
            return NO;
        }
    }

    return YES;
}

- (BOOL)saveTokensWithFactory:(MSIDOauth2Factory *)factory
                requestParams:(MSIDRequestParameters *)requestParams
                     response:(MSIDTokenResponse *)response
             saveSSOStateOnly:(BOOL)saveSSOStateOnly
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    MSIDAccount *account = [factory accountFromResponse:response request:requestParams];

    MSID_LOG_VERBOSE(context, @"Saving tokens with authority %@, clientId %@, resource %@", requestParams.authority, requestParams.clientId, requestParams.resource);
    MSID_LOG_VERBOSE_PII(context, @"Saving tokens with authority %@, clientId %@, resource %@, user ID: %@, legacy user ID: %@", requestParams.authority, requestParams.clientId, requestParams.resource, account.uniqueUserId, account.legacyUserId);
    
    BOOL result = YES;
    
    if (!saveSSOStateOnly)
    {
        result = [_primaryAccessor saveTokensWithFactory:factory
                                           requestParams:requestParams
                                                response:response
                                                 context:context
                                                   error:error];
        
        if (!result) return NO;
    }
    else
    {
        result = [_primaryAccessor saveSSOStateWithFactory:factory
                                             requestParams:requestParams
                                                  response:response
                                                   context:context
                                                     error:error];
    }

    return [self saveSSOStateInOtherAccessorsWithFactory:factory
                                           requestParams:requestParams
                                                response:response
                                                 context:context
                                                   error:error];
}

@end
