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
#import "NSDate+MSIDExtensions.h"
#import "MSIDTokenFilteringHelper.h"

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
    if (!account.uniqueUserId)
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

- (void)fillInternalErrorWithMessage:(NSString *)message
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSID_LOG_ERROR(context, @"%@", message);
    
    if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, message, nil, nil, nil, context.correlationId, nil);
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
        [self fillInternalErrorWithMessage:@"Tried to save access token, but no access token returned" context:context error:error];
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
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Saving refresh toke with clientID %@, authority %@, userID %@", refreshToken.clientId, refreshToken.authority, account.uniqueUserId);
    
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
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
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    MSIDBaseToken *token = nil;
    
    switch (tokenType)
    {
        case MSIDTokenTypeAccessToken:
        {
            token = [self getATForAccount:account requestParams:parameters context:context error:error];
            break;
        }
        case MSIDTokenTypeRefreshToken:
        {
            token = [self getRTForAccount:account requestParams:parameters context:context error:error];
            break;
        }
        default:
        {
            token = [self getTokenByUniqueUserId:account.uniqueUserId
                                       tokenType:tokenType
                                       authority:parameters.authority
                                        clientId:parameters.clientId
                                          scopes:nil
                                         context:context
                                           error:error];
            break;
        }
    }
    
    [self stopTelemetryLookupEvent:event tokenType:tokenType withToken:token success:token != nil context:context];
    return token;
}

- (MSIDBaseToken *)getLatestToken:(MSIDBaseToken *)token
                          account:(MSIDAccount *)account
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    return [self getTokenByUniqueUserId:account.uniqueUserId
                              tokenType:cacheItem.tokenType
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
        [self fillInternalErrorWithMessage:@"Token not provided, cannot remove" context:context error:error];
        return NO;
    }
    
    MSID_LOG_VERBOSE(context, @"(Default accessor) Removing token with clientId %@, authority %@", token.clientId, token.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Removing token %@ with account %@", token, account);
    
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    NSURL *authority = token.storageAuthority ? token.storageAuthority : token.authority;
    
    MSIDTokenCacheKey *key = [self keyForTokenType:cacheItem.tokenType
                                            userId:account.uniqueUserId
                                          clientId:cacheItem.clientId
                                            scopes:[cacheItem.target scopeSet]
                                         authority:authority];
    
    BOOL result = [_dataSource removeItemsWithKey:key context:context error:error];
    
    if (result && token.tokenType == MSIDTokenTypeRefreshToken)
    {
        [_dataSource saveWipeInfoWithContext:context error:nil];
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
    
    BOOL (^filterBlock)(MSIDTokenCacheItem *tokenCacheItem) = ^BOOL(MSIDTokenCacheItem *token) {
        
        return [token.clientId isEqualToString:clientId];
        
    };
    
    return [MSIDTokenFilteringHelper filterTokenCacheItems:cacheItems
                                                 tokenType:tokenType
                                               returnFirst:NO
                                                  filterBy:filterBlock];
}

#pragma mark - Private

- (MSIDBaseToken *)getTokenByUniqueUserId:(NSString *)uniqueUserId
                                tokenType:(MSIDTokenType)tokenType
                                authority:(NSURL *)authority
                                 clientId:(NSString *)clientId
                                   scopes:(NSOrderedSet<NSString *> *)scopes
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    NSArray<NSURL *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authority];
    
    for (NSURL *alias in aliases)
    {
        MSIDTokenCacheKey *key = [self keyForTokenType:tokenType
                                                userId:uniqueUserId
                                              clientId:clientId
                                                scopes:scopes
                                             authority:alias];
        
        MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for token with alias %@, clientId %@, scopes %@", alias, clientId, scopes);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Looking for token with alias %@, clientId %@, scopes %@, userId %@", alias, clientId, scopes, uniqueUserId);
        
        if (!key)
        {
            return nil;
        }
        
        NSError *cacheError = nil;
        
        MSIDTokenCacheItem *cacheItem = [_dataSource tokenWithKey:key serializer:_serializer context:context error:&cacheError];
        
        if (cacheError)
        {
            if (error) *error = cacheError;
            return nil;
        }
        
        if (cacheItem)
        {
            MSIDBaseToken *resultToken = [cacheItem tokenWithType:tokenType];
            resultToken.storageAuthority = resultToken.authority;
            resultToken.authority = authority;
            return resultToken;
        }
    }
    
    return nil;
}

- (MSIDBaseToken *)getTokenByLegacyUserId:(NSString *)legacyUserId
                                tokenType:(MSIDTokenType)tokenType
                                authority:(NSURL *)authority
                                 clientId:(NSString *)clientId
                                   scopes:(NSOrderedSet<NSString *> *)scopes
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    NSArray<NSURL *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authority];
    
    for (NSURL *alias in aliases)
    {
        MSIDTokenCacheKey *key = [self keyForTokenType:tokenType
                                                userId:nil
                                              clientId:clientId
                                                scopes:scopes
                                             authority:alias];
        
        MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for token with alias %@, clientId %@, scopes %@", alias, clientId, scopes);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Looking for token with alias %@, clientId %@, scopes %@, legacy userId %@", alias, clientId, scopes, legacyUserId);
        
        if (!key)
        {
            return nil;
        }
        
        NSError *cacheError = nil;
        NSArray<MSIDTokenCacheItem *> *cacheItems = [_dataSource tokensWithKey:key serializer:_serializer context:context error:&cacheError];
        
        if (cacheError)
        {
            if (error) *error = cacheError;
            return nil;
        }
        
        NSArray<MSIDBaseToken *> *matchedTokens = [MSIDTokenFilteringHelper filterRefreshTokenCacheItems:cacheItems legacyUserId:legacyUserId context:context];
        
        if ([matchedTokens count] > 0)
        {
            MSIDBaseToken *resultToken = matchedTokens[0];
            resultToken.storageAuthority = resultToken.authority;
            resultToken.authority = authority;
            return resultToken;
        }
    }
    
    return nil;
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
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForAccountWithUniqueUserId:account.uniqueUserId
                                                                                  authority:parameters.authority
                                                                                   clientId:parameters.clientId
                                                                                   username:account.username
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
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Saving account with authority %@, clientId %@, user ID %@, legacy user ID %@", account.authority, parameters.clientId, account.uniqueUserId, account.legacyUserId);
    
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
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Looking for access token with authority %@, clientId %@, scopes %@, user Id %@, legacy user ID %@", parameters.authority, parameters.clientId, parameters.scopes, account.uniqueUserId, account.legacyUserId);
    
    NSArray<MSIDAccessToken *> *matchedTokens = nil;
    
    if (parameters.authority)
    {
        // This is an optimization for cases, when developer provides us an authority
        // We can then do exact match except for scopes
        // We query less items and loop through less items too
        
        MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForAllAccessTokensWithUniqueUserId:account.uniqueUserId
                                                                                                authority:parameters.authority
                                                                                                 clientId:parameters.clientId];
        
        NSArray<MSIDTokenCacheItem *> *allItems = [self getAllTokensWithKey:key
                                                                    context:context
                                                                      error:error];
        
        matchedTokens = [MSIDTokenFilteringHelper filterAllAccessTokenCacheItems:allItems withScopes:parameters.scopes];
    }
    else
    {
        // This is the case, when developer doesn't provide us any authority
        // This flow is pretty unpredictable and basically only works for apps working with single tenants
        // If we can eliminate this flow in future, we can get rid of this logic and logic underneath
        MSIDDefaultTokenCacheKey *key = nil;
        
        if (account.authority)
        {
            key = [MSIDDefaultTokenCacheKey queryForAllAccessTokensWithUniqueUserId:account.uniqueUserId
                                                                        environment:account.authority.msidHostWithPortIfNecessary];
        }
        else
        {
            key = [MSIDDefaultTokenCacheKey queryForAllAccessTokens];
        }
        
        NSArray<MSIDTokenCacheItem *> *allItems = [self getAllTokensWithKey:key
                                                                    context:context
                                                                      error:error];
        
        matchedTokens = [MSIDTokenFilteringHelper filterAllAccessTokenCacheItems:allItems
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
    if (![NSString msidIsStringNilOrBlank:account.uniqueUserId])
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Finding refresh token with user ID, clientId %@, authority %@", parameters.clientId, parameters.authority);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Finding refresh token with user ID %@, clientId %@, authority %@", account.uniqueUserId, parameters.clientId, parameters.authority);
        
        refreshToken = [self getTokenByUniqueUserId:account.uniqueUserId
                                          tokenType:MSIDTokenTypeRefreshToken
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
        
        refreshToken = [self getTokenByLegacyUserId:account.legacyUserId
                                          tokenType:MSIDTokenTypeRefreshToken
                                          authority:parameters.authority
                                           clientId:parameters.clientId
                                             scopes:nil
                                            context:context
                                              error:error];
    }
    
    return (MSIDRefreshToken *)refreshToken;
}

#pragma mark - Datasource helpers

- (BOOL)removeIDTokensForRefreshToken:(MSIDBaseToken *)refreshToken
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    // Remove all related ID tokens
    MSIDTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForIDTokensWithUniqueUserId:refreshToken.uniqueUserId
                                                                            environment:refreshToken.authority.msidHostWithPortIfNecessary];
    
    NSArray *tokens = [self getAllTokensWithKey:key context:context error:error];
    
    if (!tokens)
    {
        return NO;
    }
    
    return [self deleteTokenCacheItems:tokens
                               context:context
                                 error:error
                              filterBy:^BOOL(MSIDTokenCacheItem *tokenCacheItem) {
        
                                  return [tokenCacheItem.clientId isEqualToString:refreshToken.clientId];
    }];
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
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForAllAccessTokensWithUniqueUserId:account.uniqueUserId
                                                                                            authority:accessToken.authority
                                                                                             clientId:accessToken.clientId];
    
    NSArray<MSIDTokenCacheItem *> *allCacheItems = [self getAllTokensWithKey:key context:context error:error];
    
    if (!allCacheItems)
    {
        return NO;
    }
    
    BOOL result = [self deleteTokenCacheItems:allCacheItems
                                      context:context
                                        error:error
                                     filterBy:^BOOL(MSIDTokenCacheItem *tokenCacheItem) {
                                         
                                         return [[tokenCacheItem.target scopeSet] intersectsOrderedSet:accessToken.scopes];
                                     }];
    
    if (!result)
    {
        return NO;
    }
    
    return [self saveToken:accessToken
                    userId:account.uniqueUserId
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
                    userId:account.uniqueUserId
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
        [self stopTelemetryEvent:event withItem:token success:NO context:context];
        return NO;
    }
    
    BOOL result = [_dataSource saveToken:cacheItem
                                     key:key
                              serializer:_serializer
                                 context:context
                                   error:error];
    
    [self stopTelemetryEvent:event withItem:token success:result context:context];
    
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
    [self stopTelemetryLookupEvent:event tokenType:key.type.integerValue withToken:nil success:(tokens.count > 0) context:context];
    
    return tokens;
}

- (BOOL)deleteTokenCacheItems:(NSArray<MSIDTokenCacheItem *> *)allCacheItems
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
                     filterBy:(MSIDTokenCacheItemFiltering)tokenFiltering
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE
                                                                           context:context];
    
    for (MSIDTokenCacheItem *cacheItem in allCacheItems)
    {
        if (tokenFiltering && tokenFiltering(cacheItem))
        {
            MSIDTokenCacheKey *key = [self keyForTokenType:cacheItem.tokenType
                                                    userId:cacheItem.uniqueUserId
                                                  clientId:cacheItem.clientId
                                                    scopes:[cacheItem.target scopeSet]
                                                 authority:cacheItem.authority];
            
            MSID_LOG_VERBOSE(context, @"(Default accessor) Deleting tokens with authority %@, clientId %@, scopes %@", cacheItem.authority, cacheItem.clientId, cacheItem.target);
            MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Deleting tokens with authority %@, clientId %@, scopes %@", cacheItem.authority, cacheItem.clientId, cacheItem.target);
            
            if (![_dataSource removeItemsWithKey:key context:context error:error])
            {
                [self stopTelemetryEvent:event withItem:nil success:NO context:context];
                return NO;
            }
        }
    }
    
    [self stopTelemetryEvent:event withItem:nil success:YES context:context];
    return YES;
}

#pragma mark - Telemetry helpers

- (void)stopTelemetryEvent:(MSIDTelemetryCacheEvent *)event
                  withItem:(MSIDBaseToken *)token
                   success:(BOOL)success
                   context:(id<MSIDRequestContext>)context
{
    [event setStatus:success ? MSID_TELEMETRY_VALUE_SUCCEEDED : MSID_TELEMETRY_VALUE_FAILED];
    if (token)
    {
        [event setToken:token];
    }
    [[MSIDTelemetry sharedInstance] stopEvent:[context telemetryRequestId]
                                        event:event];
}

- (void)stopTelemetryLookupEvent:(MSIDTelemetryCacheEvent *)event
                       tokenType:(MSIDTokenType)tokenType
                       withToken:(MSIDBaseToken *)token
                         success:(BOOL)success
                         context:(id<MSIDRequestContext>)context
{
    if (!success && tokenType == MSIDTokenTypeRefreshToken)
    {
        [event setWipeData:[_dataSource wipeInfo:context error:nil]];
    }
    
    [self stopTelemetryEvent:event
                    withItem:token
                     success:success
                     context:context];
}

@end
