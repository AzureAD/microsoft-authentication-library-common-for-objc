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
#import "MSIDTokenCacheKey.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDAccount.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDBaseToken.h"
#import "MSIDIdToken.h"

@interface MSIDSharedTokenCache()
{
    // Primary cache accessor
    id<MSIDSharedCacheAccessor> _primaryAccessor;
    
    // All shared accessors starting with the primary
    NSArray<id<MSIDSharedCacheAccessor>> *_allAccessors;
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
        
        NSMutableArray *allFormatsArray = [@[primaryAccessor] mutableCopy];
        [allFormatsArray addObjectsFromArray:otherAccessors];
        _allAccessors = allFormatsArray;
    }
    
    return self;
}

#pragma mark - Save tokens

- (BOOL)saveTokensWithRequestParams:(MSIDRequestParameters *)requestParams
                           response:(MSIDTokenResponse *)response
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    return [self saveTokensWithRequestParams:requestParams
                                    response:response
                        saveRefreshTokenOnly:NO
                                     context:context
                                       error:error];
}

- (BOOL)saveTokensWithBrokerResponse:(MSIDBrokerResponse *)response
                saveRefreshTokenOnly:(BOOL)saveRefreshTokenOnly
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSIDRequestParameters *params = [[MSIDRequestParameters alloc] initWithAuthority:[NSURL URLWithString:response.authority]
                                                                         redirectUri:nil
                                                                            clientId:response.clientId
                                                                              target:response.resource];
    return [self saveTokensWithRequestParams:params
                                    response:response.tokenResponse
                        saveRefreshTokenOnly:saveRefreshTokenOnly
                                     context:context
                                       error:error];
}

#pragma mark - Get tokens

- (MSIDAccessToken *)getATForAccount:(MSIDAccount *)account
                       requestParams:(MSIDRequestParameters *)parameters
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    return (MSIDAccessToken *)[_primaryAccessor getTokenWithType:MSIDTokenTypeAccessToken
                                                         account:account
                                                   requestParams:parameters
                                                         context:context
                                                           error:error];
}

- (MSIDLegacySingleResourceToken *)getLegacyTokenForAccount:(MSIDAccount *)account
                                              requestParams:(MSIDRequestParameters *)parameters
                                                    context:(id<MSIDRequestContext>)context
                                                      error:(NSError **)error
{
    return (MSIDLegacySingleResourceToken *)[_primaryAccessor getTokenWithType:MSIDTokenTypeLegacySingleResourceToken
                                                                       account:account
                                                                 requestParams:parameters
                                                                       context:context
                                                                         error:error];
}

- (MSIDLegacySingleResourceToken *)getLegacyTokenWithRequestParams:(MSIDRequestParameters *)parameters
                                                           context:(id<MSIDRequestContext>)context
                                                             error:(NSError **)error
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:@"" uniqueUserId:nil];
    
    return (MSIDLegacySingleResourceToken *)[_primaryAccessor getTokenWithType:MSIDTokenTypeLegacySingleResourceToken
                                                                       account:account
                                                                 requestParams:parameters
                                                                       context:context
                                                                         error:error];
}

- (MSIDRefreshToken *)getRTForAccount:(MSIDAccount *)account
                        requestParams:(MSIDRequestParameters *)parameters
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    NSError *cacheError = nil;
    
    // try all caches in order starting with the primary
    for (id<MSIDSharedCacheAccessor> cache in _allAccessors)
    {
        MSIDRefreshToken *token = (MSIDRefreshToken *)[cache getTokenWithType:MSIDTokenTypeRefreshToken
                                                                      account:account
                                                                requestParams:parameters
                                                                      context:context
                                                                        error:error];
        
        if (token)
        {
            return token;
        }
        else if (cacheError)
        {
            if (error)
            {
                *error = cacheError;
            }
            
            return nil;
        }
    }
    
    return nil;
}


- (MSIDRefreshToken *)getFRTforAccount:(MSIDAccount *)account
                         requestParams:(MSIDRequestParameters *)parameters
                              familyId:(NSString *)familyId
                               context:(id<MSIDRequestContext>)context
                                 error:(NSError **)error
{
    parameters.clientId = [MSIDTokenCacheKey familyClientId:familyId];
    
    return [self getRTForAccount:account
                   requestParams:parameters
                         context:context
                           error:error];
}

- (NSArray<MSIDRefreshToken *> *)getAllClientRTs:(NSString *)clientId
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    NSMutableArray *resultRTs = [NSMutableArray array];
    
    // Get RTs from all caches
    for (id<MSIDSharedCacheAccessor> cache in _allAccessors)
    {
        NSArray *otherRTs = [cache getAllTokensOfType:MSIDTokenTypeRefreshToken
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

- (NSArray<MSIDAccount *> *)getAllAccountsWithContext:(id<MSIDRequestContext>)context
                                                error:(NSError **)error
{
    NSMutableSet *result = [NSMutableSet new];
    for (id<MSIDSharedCacheAccessor> cache in _allAccessors)
    {
        NSArray<MSIDAccount *> *accounts = [cache getAllAccountsWithContext:context error:error];
        [result addObjectsFromArray:accounts];
    }
    
    return [result allObjects];
}

- (NSArray<MSIDBaseToken *> *)allTokensForAccount:(MSIDAccount *)account
                                          context:(id<MSIDRequestContext>)context
                                            error:(NSError **)error
{
    return [_primaryAccessor allTokensForAccount:account context:context error:error];
}

- (BOOL)removeAccount:(MSIDAccount *)account
              context:(id<MSIDRequestContext>)context
                error:(NSError **)error
{
    return [_primaryAccessor removeAccount:account context:context error:error];
}

#pragma mark - Remove tokens

- (BOOL)removeRTForAccount:(MSIDAccount *)account
                     token:(MSIDBaseToken<MSIDRefreshableToken> *)token
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
    MSID_LOG_VERBOSE_PII(context, @"Removing refresh token with clientID %@, authority %@, userId %@, legacy userId %@, token %@", token.clientId, token.authority, account.uniqueUserId, account.legacyUserId, _PII_NULLIFY(token.refreshToken));
    
    NSError *cacheError = nil;
    
    MSIDBaseToken<MSIDRefreshableToken> *tokenInCache = (MSIDBaseToken<MSIDRefreshableToken> *)[_primaryAccessor getLatestToken:token
                                                                                                                        account:account
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
                                     account:account
                                     context:context
                                       error:error];
    }
    
    return YES;
}

- (BOOL)removeTokenForAccount:(MSIDAccount *)account
                        token:(MSIDBaseToken *)token
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    return [_primaryAccessor removeToken:token
                                 account:account
                                 context:context
                                   error:error];
}

#pragma mark - Private

- (BOOL)saveRefreshToken:(MSIDRefreshToken *)refreshToken
              forAccount:(MSIDAccount *)account
                 context:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"Saving refresh token in all caches");
    MSID_LOG_VERBOSE_PII(context, @"Saving refresh token in all caches %@", _PII_NULLIFY(refreshToken.refreshToken));
    
    // Save RTs in all formats
    BOOL result = [self saveRefreshTokenInAllCaches:refreshToken
                                        withAccount:account
                                            context:context
                                              error:error];
    
    if (!result || [NSString msidIsStringNilOrBlank:refreshToken.familyId])
    {
        // If saving failed or it's not an FRT, we're done
        return result;
    }
    
    MSID_LOG_VERBOSE(context, @"Saving family refresh token in all caches");
    MSID_LOG_VERBOSE_PII(context, @"Saving family refresh token in all caches %@", _PII_NULLIFY(refreshToken.refreshToken));
    
    // If it's an FRT, save it separately and update the clientId of the token item
    MSIDRefreshToken *familyRefreshToken = [refreshToken copy];
    familyRefreshToken.clientId = [MSIDTokenCacheKey familyClientId:refreshToken.familyId];
    
    return [self saveRefreshTokenInAllCaches:familyRefreshToken
                                 withAccount:account
                                     context:context
                                       error:error];
}

- (BOOL)saveRefreshTokenInAllCaches:(MSIDRefreshToken *)refreshToken
                        withAccount:(MSIDAccount *)account
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    // Save RTs in all formats including primary
    for (id<MSIDSharedCacheAccessor> cache in _allAccessors)
    {
        NSError *cacheError = nil;
        
        BOOL result = [cache saveRefreshToken:refreshToken
                                      account:account
                                      context:context
                                        error:&cacheError];
        
        if (!result && [cache isEqual:_primaryAccessor])
        {
            if (error) *error = cacheError;
            
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)saveTokensWithRequestParams:(MSIDRequestParameters *)requestParams
                           response:(MSIDTokenResponse *)response
               saveRefreshTokenOnly:(BOOL)saveRefreshTokenOnly
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithTokenResponse:response
                                                              request:requestParams];
    
    MSID_LOG_VERBOSE(context, @"Saving tokens with authority %@, clientId %@, resource %@", requestParams.authority, requestParams.clientId, requestParams.resource);
    MSID_LOG_VERBOSE_PII(context, @"Saving tokens with authority %@, clientId %@, resource %@, user ID: %@, legacy user ID: %@", requestParams.authority, requestParams.clientId, requestParams.resource, account.uniqueUserId, account.legacyUserId);
    
    
    
    BOOL result = YES;
    
    if (!saveRefreshTokenOnly)
    {
        result = [_primaryAccessor saveTokensWithRequestParams:requestParams
                                                       account:account
                                                      response:response
                                                       context:context
                                                         error:error];
        
        if (!result) return NO;
    }
    
    // Create a refresh token item
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] initWithTokenResponse:response
                                                                             request:requestParams];
    
    if (!refreshToken)
    {
        MSID_LOG_INFO(context, @"No refresh token returned in the token response, not updating cache");
        return YES;
    }
    
    return [self saveRefreshToken:refreshToken forAccount:account context:context error:error];
}

@end
