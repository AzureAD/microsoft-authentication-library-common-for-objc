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

#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDJsonSerializer.h"
#import "MSIDAccount.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDAadAuthorityCache.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"
#import "MSIDDefaultTokenCacheKey.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDAADV2IdTokenWrapper.h"
#import "MSIDRequestParameters.h"

@interface MSIDDefaultTokenCacheAccessor()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDJsonSerializer *_serializer;
}
@end

@implementation MSIDDefaultTokenCacheAccessor

#pragma mark - Init

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
{
    self = [super init];
    
    if (self)
    {
        _dataSource = dataSource;
        _serializer = [[MSIDJsonSerializer alloc] init];
    }
    
    return self;
}

#pragma mark - Input validation

- (BOOL)checkUserIdentifier:(MSIDAccount *)account
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    if (!account.userIdentifier)
    {
        MSID_LOG_ERROR(context, @"(Default accessor) User identifier is expected for default accessor, but not provided");
        MSID_LOG_ERROR_PII(context, @"(Default accessor) User identifier is expected for default accessor, but not provided for account %@", account);
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"User identifier is expected for MSDIDefaultTokenCacheFormat", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    return YES;
}

#pragma mark - MSIDSharedCacheAccessor

- (BOOL)saveTokensWithRequestParams:(MSIDRequestParameters *)requestParams
                            account:(MSIDAccount *)account
                           response:(MSIDTokenResponse *)response
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    // Save access token item in the primary format
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenResponse:response
                                                                          request:requestParams];
    
    if (!accessToken)
    {
        MSID_LOG_ERROR(context, @"Couldn't initialize access token entry. Not updating cache");
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Tried to save access token, but no access token returned", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    MSID_LOG_INFO(context, @"(Default accessor) Saving access token");
    MSID_LOG_INFO_PII(context, @"(Default accessor) Saving access token %@", accessToken);
    
    if (![self saveAccessToken:accessToken
                       account:account
                       context:context
                         error:error])
    {
        MSID_LOG_ERROR(context, @"Saving access token failed");
        MSID_LOG_ERROR_PII(context, @"Saving access token %@ failed with error %@", accessToken, *error);
        return NO;
    }
    
    // Save ID token
    MSIDIdToken *idToken = [[MSIDIdToken alloc] initWithTokenResponse:response
                                                              request:requestParams];
    if (idToken)
    {
        MSID_LOG_INFO(context, @"(Default accessor) Saving ID token");
        MSID_LOG_INFO_PII(context, @"(Default accessor) Saving ID token %@", idToken);
        
        if (![self saveTokenWithPreferredCache:idToken
                                       account:account
                                       context:context
                                         error:error])
        {
            return NO;
        }
    }
    
    MSID_LOG_INFO(context, @"(Default accessor) Saving account");
    MSID_LOG_INFO_PII(context, @"(Default accessor) Saving account %@", account);
    
    // Save account
    return [self saveAccount:account
               requestParams:requestParams
                     context:context
                       error:error];
}

- (BOOL)saveRefreshToken:(MSIDRefreshToken *)refreshToken
                 account:(MSIDAccount *)account
                 context:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Default accessor) Saving refresh token with clientID %@, authority %@", refreshToken.clientId, refreshToken.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Saving refresh toke with clientID %@, authority %@, userID %@", refreshToken.clientId, refreshToken.authority, account.userIdentifier);
    
    return [self saveTokenWithPreferredCache:refreshToken
                                     account:account
                                     context:context
                                       error:error];
}

- (MSIDBaseToken *)getTokenWithType:(MSIDTokenType)tokenType
                            account:(MSIDAccount *)account
                      requestParams:(MSIDRequestParameters *)parameters
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    switch (tokenType)
    {
        case MSIDTokenTypeAccessToken:
        {
            return [self getATForAccount:account
                           requestParams:parameters
                                 context:context
                                   error:error];
        }
        case MSIDTokenTypeRefreshToken:
        {
            return [self getRTForAccount:account
                           requestParams:parameters
                                 context:context
                                   error:error];
        }
        default:
        {
            return [self getTokenWithType:tokenType
                                  account:account
                          useLegacyUserId:NO
                                authority:parameters.authority
                                 clientId:parameters.clientId
                                   scopes:nil
                                  context:context
                                    error:error];
        }
    }
}

- (MSIDBaseToken *)getLatestToken:(MSIDBaseToken *)token
                          account:(MSIDAccount *)account
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    return [self getTokenWithType:cacheItem.tokenType
                          account:account
                  useLegacyUserId:NO
                        authority:cacheItem.authority
                         clientId:cacheItem.clientId
                           scopes:[cacheItem.target scopeSet]
                          context:context
                            error:error];
}

- (BOOL)removeToken:(MSIDBaseToken *)token
            account:(MSIDAccount *)account
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    if (!token)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Token not provided", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    MSID_LOG_VERBOSE(context, @"(Default accessor) Removing token with clientId %@, authority %@", token.clientId, token.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Removing token %@ with account %@", token, account);
    
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    MSIDTokenCacheKey *key = [self keyForTokenType:cacheItem.tokenType
                                            userId:account.userIdentifier
                                          clientId:cacheItem.clientId
                                            scopes:[cacheItem.target scopeSet]
                                         authority:cacheItem.authority];
    
    BOOL result = [_dataSource removeItemsWithKey:key
                                          context:context
                                            error:error];
    
    if (result && token.tokenType == MSIDTokenTypeRefreshToken)
    {
        return [self removeIDTokensForRefreshToken:token context:context error:error];
    }
    
    return result;
}

- (NSArray *)getAllTokensOfType:(MSIDTokenType)tokenType
                   withClientId:(NSString *)clientId
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Default accessor) Get all tokens of type %@ with clientId %@", [MSIDTokenTypeHelpers tokenTypeAsString:tokenType], clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Get all tokens of type %@ with clientId %@", [MSIDTokenTypeHelpers tokenTypeAsString:tokenType], clientId);
    
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForAllTokensWithType:tokenType];
    NSArray<MSIDTokenCacheItem *> *cacheItems = [self getAllTokensWithKey:key context:context error:error];
    
    NSMutableArray *results = [NSMutableArray array];
    
    for (MSIDTokenCacheItem *cacheItem in cacheItems)
    {
        if (![cacheItem.clientId isEqualToString:clientId])
        {
            continue;
        }
        
        MSIDBaseToken *token = [cacheItem tokenWithType:tokenType];
        
        if (token)
        {
            [results addObject:token];
        }
    }
    
    return results;
}

#pragma mark - Private

- (MSIDBaseToken *)getTokenWithType:(MSIDTokenType)tokenType
                            account:(MSIDAccount *)account
                    useLegacyUserId:(BOOL)useLegacyUserId
                          authority:(NSURL *)authority
                           clientId:(NSString *)clientId
                             scopes:(NSOrderedSet<NSString *> *)scopes
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    NSArray<NSURL *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authority];
    
    for (NSURL *alias in aliases)
    {
        NSString *userId = useLegacyUserId ? nil : account.userIdentifier;
        
        MSIDTokenCacheKey *key = [self keyForTokenType:tokenType
                                                userId:userId
                                              clientId:clientId
                                                scopes:scopes
                                             authority:alias];
        
        MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for token with alias %@, clientId %@, scopes %@", alias, clientId, scopes);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Looking for token with alias %@, clientId %@, scopes %@, userId %@", alias, clientId, scopes, userId);
        
        if (!key)
        {
            [self stopTelemetryEvent:event
                            withItem:nil
                             success:NO
                             context:context];
            
            return nil;
        }
        
        NSError *cacheError = nil;
        
        NSArray *tokens = [_dataSource tokensWithKey:key
                                          serializer:_serializer
                                             context:context
                                               error:&cacheError];
        
        if (cacheError)
        {
            if (error)
            {
                *error = cacheError;
            }
            
            [self stopTelemetryEvent:event
                            withItem:nil
                             success:NO
                             context:context];
            
            return nil;
        }
        
        for (MSIDTokenCacheItem *cacheItem in tokens)
        {
            /*
             This is an additional fallback for cases, when user identifier is not known, but legacy user ID is available
             In that case, token is matched by legacy user ID instead.
             */
            if (useLegacyUserId)
            {
                if (!cacheItem.idToken)
                {
                    continue; // Can't match by legacy ID without having an id token
                }
                
                MSIDAADV2IdTokenWrapper *idTokenWrapper = [[MSIDAADV2IdTokenWrapper alloc] initWithRawIdToken:cacheItem.idToken];
                
                if (![idTokenWrapper matchesLegacyUserId:account.legacyUserId])
                {
                    MSID_LOG_VERBOSE(context, @"(Default accessor) Matching by legacy userId didn't succeed");
                    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Matching by legacy userId didn't succeed (expected userId %@, found %@)", account.legacyUserId, idTokenWrapper.userId);
                    
                    // Id token was there, but legacy user ID match wasn't found, continue to the next token
                    continue;
                }
            }
            
            [self stopTelemetryEvent:event
                            withItem:cacheItem
                             success:YES
                             context:context];
            
            MSIDBaseToken *token = [cacheItem tokenWithType:tokenType];
            token.authority = authority;
            return token;
        }
    }
    
    [self stopTelemetryEvent:event
                    withItem:nil
                     success:NO
                     context:context];
    
    return nil;
}

#pragma mark - Access token helpers

- (BOOL)deleteAllAccessTokensWithIntersectingScopes:(MSIDAccessToken *)accessToken
                                            account:(MSIDAccount *)account
                                            context:(id<MSIDRequestContext>)context
                                              error:(NSError **)error
{
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForAllAccessTokensWithUniqueUserId:account.userIdentifier
                                                                                            authority:accessToken.authority
                                                                                             clientId:accessToken.clientId];
    
    NSArray<MSIDTokenCacheItem *> *allCacheItems = [self getAllTokensWithKey:key context:context error:error];
    
    if (!allCacheItems)
    {
        return NO;
    }
    
    for (MSIDTokenCacheItem *cacheItem in allCacheItems)
    {
        NSOrderedSet *scopeSet = [cacheItem.target scopeSet];
        
        if ([scopeSet intersectsOrderedSet:accessToken.scopes])
        {
            MSIDDefaultTokenCacheKey *keyToDelete = [MSIDDefaultTokenCacheKey keyForAccessTokenWithUniqueUserId:account.userIdentifier
                                                                                                      authority:accessToken.authority
                                                                                                       clientId:accessToken.clientId
                                                                                                         scopes:scopeSet];
            
            MSID_LOG_VERBOSE(context, @"(Default accessor) Deleting access tokens with intersecting scopes, authority %@, clientId %@, scopes %@", accessToken.authority, accessToken.clientId, accessToken.scopes);
            MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Deleting access tokens with intersecting scopes, authority %@, clientId %@, scopes %@", accessToken.authority, accessToken.clientId, accessToken.scopes);
            
            if (![self removeTokenWithKey:keyToDelete context:context error:error])
            {
                return NO;
            }
        }
    }
    
    return YES;
}

#pragma mark - Account

- (BOOL)saveAccount:(MSIDAccount *)account
      requestParams:(MSIDRequestParameters *)parameters
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    // Get previous account, so we don't loose any fields
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForAccountWithUniqueUserId:account.userIdentifier
                                                                                  authority:parameters.authority
                                                                                   clientId:parameters.clientId
                                                                                accountType:account.accountType];
    
    MSIDAccountCacheItem *previousAccount = [_dataSource accountWithKey:key
                                                             serializer:_serializer
                                                                context:context
                                                                  error:error];
    
    MSIDAccountCacheItem *currentAccount = account.accountCacheItem;
    
    if (previousAccount)
    {
        // Make sure we copy over all the additional fields
        [currentAccount updateFieldsFromAccount:previousAccount];
    }
    
    MSID_LOG_VERBOSE(context, @"(Default accessor) Saving account with authority %@, clientId %@", account.authority, parameters.clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Saving account with authority %@, clientId %@, user ID %@, legacy user ID %@", account.authority, parameters.clientId, account.userIdentifier, account.legacyUserId);
    
    return [_dataSource saveAccount:currentAccount
                                key:key
                         serializer:_serializer
                            context:context
                              error:error];
}


- (MSIDAccessToken *)getATForAccount:(MSIDAccount *)account
                       requestParams:(MSIDRequestParameters *)parameters
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return nil;
    }
    
    MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for access token with authority %@, clientId %@, scopes %@", parameters.authority, parameters.clientId, parameters.scopes);
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Looking for access token with authority %@, clientId %@, scopes %@, user Id %@, legacy user ID %@", parameters.authority, parameters.clientId, parameters.scopes, account.userIdentifier, account.legacyUserId);
    
    NSArray<MSIDAccessToken *> *matchedTokens = nil;
    
    if (parameters.authority)
    {
        // This is an optimization for cases, when developer provides us an authority
        // We can then do exact match except for scopes
        // We query less items and loop through less items too
        
        MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForAllAccessTokensWithUniqueUserId:account.userIdentifier
                                                                                                authority:parameters.authority
                                                                                                 clientId:parameters.clientId];
        
        NSArray<MSIDTokenCacheItem *> *allItems = [self getAllTokensWithKey:key
                                                                    context:context
                                                                      error:error];
        
        matchedTokens = [self filterAllAccessTokenCacheItems:allItems withScopes:parameters.scopes];
    }
    else
    {
        // This is the case, when developer doesn't provide us any authority
        // This flow is pretty unpredictable and basically only works for apps working with single tenants
        // If we can eliminate this flow in future, we can get rid of this logic and logic underneath
        NSArray<MSIDTokenCacheItem *> *allItems = [self getAllTokensWithKey:[MSIDDefaultTokenCacheKey queryForAllAccessTokens]
                                                                    context:context
                                                                      error:error];
        
        matchedTokens = [self filterAllAccessTokenCacheItems:allItems
                                              withParameters:parameters
                                                     account:account
                                                     context:context
                                                       error:error];
    }
    
    if (matchedTokens.count == 0)
    {
        MSID_LOG_INFO(context, @"No matching access token found.");
        MSID_LOG_INFO_PII(context, @"No matching access token found.");
        return nil;
    }
    
    MSIDAccessToken *tokenToReturn = matchedTokens[0];
    tokenToReturn.authority = parameters.authority;
    
    return tokenToReturn;
}


- (MSIDRefreshToken *)getRTForAccount:(MSIDAccount *)account
                        requestParams:(MSIDRequestParameters *)parameters
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    MSIDBaseToken *refreshToken = nil;
    
    // First try to look by the unique user identifier
    if (![NSString msidIsStringNilOrBlank:account.userIdentifier])
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Finding refresh token with user ID, clientId %@, authority %@", parameters.clientId, parameters.authority);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Finding refresh token with user ID %@, clientId %@, authority %@", account.userIdentifier, parameters.clientId, parameters.authority);
        
        refreshToken = [self getTokenWithType:MSIDTokenTypeRefreshToken
                                      account:account
                              useLegacyUserId:NO
                                    authority:parameters.authority
                                     clientId:parameters.clientId
                                       scopes:nil
                                      context:context
                                        error:error];
    }
    
    // If token wasn't found and legacy user ID is available, try to look by legacy user id
    if (!refreshToken && ![NSString msidIsStringNilOrBlank:account.legacyUserId])
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Finding refresh token with legacy user ID, clientId %@, authority %@", parameters.clientId, parameters.authority);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Finding refresh token with legacy user ID %@, clientId %@, authority %@", account.legacyUserId, parameters.clientId, parameters.authority);
        
        refreshToken = [self getTokenWithType:MSIDTokenTypeRefreshToken
                                      account:account
                              useLegacyUserId:YES
                                    authority:parameters.authority
                                     clientId:parameters.clientId
                                       scopes:nil
                                      context:context
                                        error:error];
    }
    
    return (MSIDRefreshToken *)refreshToken;
}

#pragma mark - Access token filtering

- (NSArray<MSIDAccessToken *> *)filterAllAccessTokenCacheItems:(NSArray<MSIDTokenCacheItem *> *)allCacheItems
                                                    withScopes:(NSOrderedSet<NSString *> *)scopes
{
    NSMutableArray<MSIDAccessToken *> *matchedItems = [NSMutableArray<MSIDAccessToken *> new];
    
    for (MSIDTokenCacheItem *cacheItem in allCacheItems)
    {
        MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenCacheItem:cacheItem];
        
        if ([accessToken.scopes isSubsetOfOrderedSet:scopes])
        {
            [matchedItems addObject:accessToken];
        }
    }
    
    return matchedItems;
}

- (NSArray<MSIDAccessToken *> *)filterAllAccessTokenCacheItems:(NSArray<MSIDTokenCacheItem *> *)allItems
                                                withParameters:(MSIDRequestParameters *)parameters
                                                       account:(MSIDAccount *)account
                                                       context:(id<MSIDRequestContext>)context
                                                         error:(NSError **)error
{
    if (!allItems || [allItems count] == 0)
    {
        // This should be rare-to-never as having a MSIDAccount object requires having a RT in cache,
        // which should imply that at some point we got an AT for that user with this client ID
        // as well. Unless users start working cross client id of course.
        MSID_LOG_WARN(context, @"No access token found for user & client id.");
        MSID_LOG_WARN_PII(context, @"No access token found for user & client id.");
        return nil;
    }
    
    NSMutableArray<MSIDAccessToken *> *matchedTokens = [NSMutableArray<MSIDAccessToken *> new];
    NSURL *authorityToCheck = allItems[0].authority;
    NSArray<NSURL *> *tokenAliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authorityToCheck];
    
    for (MSIDTokenCacheItem *cacheItem in allItems)
    {
        MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenCacheItem:cacheItem];
        
        if ([accessToken.uniqueUserId isEqualToString:account.userIdentifier]
            && [accessToken.clientId isEqualToString:parameters.clientId]
            && [accessToken.scopes isSubsetOfOrderedSet:parameters.scopes])
        {
            if ([accessToken.authority msidIsEquivalentWithAnyAlias:tokenAliases])
            {
                [matchedTokens addObject:accessToken];
            }
            else
            {
                if (error)
                {
                    *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorAmbiguousAuthority, @"Found multiple access tokens, which token to return is ambiguous! Please pass in authority if not provided.", nil, nil, nil, context.correlationId, nil);
                }
                
                return nil;
            }
        }
    }
    
    return matchedTokens;
}

#pragma mark - Datasource helpers

- (BOOL)removeIDTokensForRefreshToken:(MSIDBaseToken *)refreshToken
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    // Remove all related ID tokens
    MSIDTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForIDTokensWithUniqueUserId:refreshToken.uniqueUserId
                                                                            environment:refreshToken.authority.msidHostWithPortIfNecessary];
    
    NSArray *tokens = [_dataSource tokensWithKey:key serializer:_serializer context:context error:error];
    
    if (!tokens)
    {
        return NO;
    }
    
    for (MSIDTokenCacheItem *cacheItem in tokens)
    {
        if ([cacheItem.clientId isEqualToString:cacheItem.clientId])
        {
            MSIDDefaultTokenCacheKey *idTokenKey = [MSIDDefaultTokenCacheKey keyForIDTokenWithUniqueUserId:cacheItem.uniqueUserId
                                                                                                 authority:cacheItem.authority
                                                                                                  clientId:cacheItem.clientId];
            
            BOOL result = [_dataSource removeItemsWithKey:idTokenKey context:context error:error];
            
            if (!result)
            {
                return NO;
            }
        }
    }
    
    return YES;
}

- (MSIDDefaultTokenCacheKey *)keyForTokenType:(MSIDTokenType)tokenType
                                       userId:(NSString *)userId
                                     clientId:(NSString *)clientId
                                       scopes:(NSOrderedSet<NSString *> *)scopes
                                    authority:(NSURL *)authority
{
    switch (tokenType)
    {
        case MSIDTokenTypeAccessToken:
        {
            return [MSIDDefaultTokenCacheKey keyForAccessTokenWithUniqueUserId:userId
                                                                     authority:authority
                                                                      clientId:clientId
                                                                        scopes:scopes];
        }
        case MSIDTokenTypeRefreshToken:
        {
            if (userId)
            {
                return [MSIDDefaultTokenCacheKey keyForRefreshTokenWithUniqueUserId:userId
                                                                        environment:authority.msidHostWithPortIfNecessary
                                                                           clientId:clientId];
            }
            else
            {
                return [MSIDDefaultTokenCacheKey queryForAllRefreshTokensWithClientId:clientId];
            }
        }
        case MSIDTokenTypeIDToken:
        {
            return [MSIDDefaultTokenCacheKey keyForIDTokenWithUniqueUserId:userId
                                                                 authority:authority
                                                                  clientId:clientId];
        }
            
        default:
            return nil;
    }
}

- (BOOL)saveAccessToken:(MSIDAccessToken *)accessToken
                account:(MSIDAccount *)account
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error
{
    // Access tokens have a special handling because of scopes
    if (![self deleteAllAccessTokensWithIntersectingScopes:accessToken
                                                   account:account
                                                   context:context
                                                     error:error])
    {
        return NO;
    }
    
    return [self saveToken:accessToken
                    userId:account.userIdentifier
                 authority:accessToken.authority
                   context:context
                     error:error];
}

- (BOOL)saveTokenWithPreferredCache:(MSIDBaseToken *)token
                            account:(MSIDAccount *)account
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    // All other tokens have the same handling
    NSURL *authority = [[MSIDAadAuthorityCache sharedInstance] cacheUrlForAuthority:token.authority context:context];
    
    return [self saveToken:token
                    userId:account.userIdentifier
                 authority:authority
                   context:context
                     error:error];
}

- (BOOL)saveToken:(MSIDBaseToken *)token
           userId:(NSString *)userId
        authority:(NSURL *)authority
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                           context:context];
    
    // The authority used to retrieve the item over the network can differ from the preferred authority used to
    // cache the item. As it would be awkward to cache an item using an authority other then the one we store
    // it with we switch it out before saving it to cache.
    token.authority = authority;
    
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    MSID_LOG_VERBOSE(context, @"(Default accessor) Saving token %@ with authority %@", [MSIDTokenTypeHelpers tokenTypeAsString:token.tokenType], authority);
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Saving token %@ for userID %@ with authority %@", token, userId, authority);
    
    MSIDTokenCacheKey *key = [self keyForTokenType:cacheItem.tokenType
                                            userId:userId
                                          clientId:cacheItem.clientId
                                            scopes:[cacheItem.target scopeSet]
                                         authority:authority];
    
    if (!key)
    {
        [self stopTelemetryEvent:event
                        withItem:cacheItem
                         success:NO
                         context:context];
        
        return NO;
    }
    
    BOOL result = [_dataSource saveToken:cacheItem
                                     key:key
                              serializer:_serializer
                                 context:context
                                   error:error];
    
    [self stopTelemetryEvent:event
                    withItem:cacheItem
                     success:result
                     context:context];
    
    return result;
}

- (NSArray<MSIDTokenCacheItem *> *)getAllTokensWithKey:(MSIDTokenCacheKey *)key
                                               context:(id<MSIDRequestContext>)context
                                                 error:(NSError *__autoreleasing *)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    NSArray *tokens = [_dataSource tokensWithKey:key serializer:_serializer context:context error:error];
    
    [self stopTelemetryEvent:event withItem:nil success:(tokens != nil) context:context];
    return tokens;
}

- (BOOL)removeTokenWithKey:(MSIDTokenCacheKey *)key
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error

{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE
                                                                           context:context];
    
    BOOL result = [_dataSource removeItemsWithKey:key context:context error:error];
    
    [self stopTelemetryEvent:event withItem:nil success:YES context:context];
    return result;
}

#pragma mark - Telemetry helpers

- (void)stopTelemetryEvent:(MSIDTelemetryCacheEvent *)event
                  withItem:(MSIDTokenCacheItem *)item
                   success:(BOOL)success
                   context:(id<MSIDRequestContext>)context
{
    [event setStatus:success ? MSID_TELEMETRY_VALUE_SUCCEEDED : MSID_TELEMETRY_VALUE_FAILED];
    if (item)
    {
        [event setCacheItem:item];
    }
    [[MSIDTelemetry sharedInstance] stopEvent:[context telemetryRequestId]
                                        event:event];
}

@end
