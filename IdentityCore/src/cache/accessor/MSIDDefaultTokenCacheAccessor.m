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
#import "MSIDBaseToken.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDAADV2RequestParameters.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDAadAuthorityCache.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"
#import "MSIDDefaultTokenCacheKey.h"

@interface MSIDDefaultTokenCacheAccessor()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDJsonSerializer *_tokenSerializer;
    MSIDJsonSerializer *_accountSerializer;
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
        _tokenSerializer = [[MSIDJsonSerializer alloc] initWithType:MSIDTokenSerializerType];
        _accountSerializer = [[MSIDJsonSerializer alloc] initWithType:MSIDAccountSerializerType];
    }
    
    return self;
}

#pragma mark - Input validation

- (BOOL)checkRequestParameters:(MSIDRequestParameters *)parameters
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    if (![parameters isKindOfClass:MSIDAADV2RequestParameters.class])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"MSIDAADV2RequestParameters is expected here, received something else", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)checkUserIdentifier:(MSIDAccount *)account
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    if (!account.userIdentifier)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"User identifier is expected for MSDIDefaultTokenCacheFormat", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    return YES;
}

#pragma mark - Access tokens

- (BOOL)saveAccessToken:(MSIDAccessToken *)token
                account:(MSIDAccount *)account
          requestParams:(MSIDRequestParameters *)parameters
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error
{
    if (![self checkRequestParameters:parameters context:context error:error]
        || ![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    // delete all cache entries with intersecting scopes
    // this should not happen but we have this as a safe guard against multiple matches
    if (![self deleteAllAccessTokensWithIntersectingScopes:token.scopes
                                                   account:account
                                                 authority:token.authority
                                                  clientId:token.clientId
                                                   context:context
                                                     error:error])
    {
        return NO;
    }
    
    return [self saveToken:token
                    userId:account.userIdentifier
                  clientId:token.clientId
                    scopes:token.scopes
                 authority:token.authority
                serializer:_tokenSerializer
                   context:context
                     error:error];
}

// TODO: move to helpers
- (BOOL)deleteAllAccessTokensWithIntersectingScopes:(NSOrderedSet<NSString *> *)scopes
                                            account:(MSIDAccount *)account
                                          authority:(NSURL *)authority
                                           clientId:(NSString *)clientId
                                            context:(id<MSIDRequestContext>)context
                                              error:(NSError **)error
{
    NSArray<MSIDTokenCacheItem *> *allCacheItems = [self getAllATsForAccount:account
                                                                   authority:authority
                                                                    clientId:clientId
                                                                     context:context
                                                                       error:error];
    
    if (!allCacheItems)
    {
        return NO;
    }
    
    for (MSIDTokenCacheItem *cacheItem in allCacheItems)
    {
        NSOrderedSet *scopeSet = [cacheItem.target scopeSet];
        
        if ([scopeSet intersectsOrderedSet:scopes])
        {
            MSIDDefaultTokenCacheKey *keyToDelete = [MSIDDefaultTokenCacheKey keyForAccessTokenWithUniqueUserId:account.userIdentifier
                                                                                                      authority:authority
                                                                                                       clientId:clientId
                                                                                                         scopes:scopeSet];
            
            if (![self removeTokenWithKey:keyToDelete context:context error:error])
            {
                return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)saveIDToken:(MSIDIdToken *)token
            account:(MSIDAccount *)account
      requestParams:(MSIDRequestParameters *)parameters
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (![self checkRequestParameters:parameters context:context error:error]
        || ![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    return [self saveToken:token
                    userId:account.userIdentifier
                  clientId:token.clientId
                    scopes:nil
                 authority:token.authority
                serializer:_tokenSerializer
                   context:context
                     error:error];
}

- (BOOL)saveAccount:(MSIDAccount *)account
      requestParams:(MSIDRequestParameters *)parameters
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (![self checkRequestParameters:parameters context:context error:error]
        || ![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    // Get previous account, so we don't loose any fields
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForAccountWithUniqueUserId:account.userIdentifier
                                                                                  authority:parameters.authority
                                                                                   clientId:parameters.clientId
                                                                                accountType:account.accountType];
    
    MSIDAccount *previousAccount = (MSIDAccount *)[_dataSource itemWithKey:key
                                                                serializer:_accountSerializer
                                                                   context:context
                                                                     error:error];
    
    if (previousAccount)
    {
        // Make sure we copy over all the additional fields
        [account updateFieldsFromAccount:previousAccount];
    }
    
    // TODO: update account
    /*
    return [_dataSource setItem:account
                            key:key
                     serializer:_accountSerializer
                        context:context
                          error:error];
     */
    
    return NO;
}


- (MSIDAccessToken *)getATForAccount:(MSIDAccount *)account
                       requestParams:(MSIDRequestParameters *)parameters
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    if (![self checkRequestParameters:parameters context:context error:error]
        || ![self checkUserIdentifier:account context:context error:error])
    {
        return nil;
    }
    
    MSIDAADV2RequestParameters *v2params = (MSIDAADV2RequestParameters *)parameters;
    
    NSArray<MSIDAccessToken *> *matchedTokens = nil;
    
    if (v2params.authority)
    {
        // This is an optimization for cases, when developer provides us an authority
        // We can then do exact match except for scopes
        // We query less items and loop through less items too
        NSArray<MSIDTokenCacheItem *> *allItems = [self getAllATsForAccount:account
                                                                  authority:v2params.authority
                                                                   clientId:v2params.clientId
                                                                    context:context
                                                                      error:error];
        
        matchedTokens = [self filterAllAccessTokenCacheItems:allItems withScopes:v2params.scopes];
    }
    else
    {
        // This is the case, when developer doesn't provide us any authority
        // This flow is pretty unpredictable and basically only works for apps working with single tenants
        // If we can eliminate this flow in future, we can get rid of this logic and logic underneath
        NSArray<MSIDTokenCacheItem *> *allItems = [self getAllATsForContext:context error:error];
        matchedTokens = [self filterAllAccessTokenCacheItems:allItems
                                              withParameters:v2params
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

- (BOOL)saveSharedRTForAccount:(MSIDAccount *)account
                  refreshToken:(MSIDRefreshToken *)refreshToken
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    NSURL *newAuthority = [[MSIDAadAuthorityCache sharedInstance] cacheUrlForAuthority:refreshToken.authority context:context];
    
    return [self saveToken:refreshToken
                    userId:account.userIdentifier
                  clientId:refreshToken.clientId
                    scopes:nil
                 authority:newAuthority
                serializer:_tokenSerializer
                   context:context
                     error:error];
}

- (MSIDRefreshToken *)getSharedRTForAccount:(MSIDAccount *)account
                              requestParams:(MSIDRequestParameters *)parameters
                                    context:(id<MSIDRequestContext>)context
                                      error:(NSError **)error
{
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return nil;
    }
    
    return [self getRefreshTokenForUserId:account.userIdentifier
                                 clientId:parameters.clientId
                                authority:parameters.authority
                               serializer:_tokenSerializer
                                  context:context
                                    error:error];
}

- (MSIDBaseToken<MSIDRefreshableToken> *)getLatestRTForToken:(MSIDBaseToken<MSIDRefreshableToken> *)token
                                                     account:(MSIDAccount *)account
                                                     context:(id<MSIDRequestContext>)context
                                                       error:(NSError **)error
{
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return nil;
    }
    
    return [self getRefreshTokenForUserId:account.userIdentifier
                                 clientId:token.clientId
                                authority:token.authority
                               serializer:_tokenSerializer
                                  context:context
                                    error:error];
}

- (NSArray<MSIDRefreshToken *> *)getAllSharedRTsWithClientId:(NSString *)clientId
                                                     context:(id<MSIDRequestContext>)context
                                                       error:(NSError **)error
{
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForRefreshTokenWithClientId:clientId];
    NSArray<MSIDTokenCacheItem *> *cacheItems = [self getAllTokensWithKey:key context:context error:error];
    
    NSMutableArray *results = [NSMutableArray array];
    
    for (MSIDTokenCacheItem *cacheItem in cacheItems)
    {
        MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] initWithTokenCacheItem:cacheItem];
        
        if (refreshToken)
        {
            [results addObject:cacheItem];
        }
    }
    
    return results;
}


- (BOOL)removeSharedRTForAccount:(MSIDAccount *)account
                           token:(MSIDBaseToken<MSIDRefreshableToken> *)token
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
    
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForRefreshTokenWithUniqueUserId:account.userIdentifier
                                                                                     environment:token.authority.msidHostWithPortIfNecessary
                                                                                        clientId:token.clientId];
    
    return [self removeTokenWithKey:key
                            context:context
                              error:error];
}

#pragma mark - Filtering

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
                                                withParameters:(MSIDAADV2RequestParameters *)parameters
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
    NSURL *authorityToCheck = allItems[0].authority; // TODO: what if nil?
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
            return [MSIDDefaultTokenCacheKey keyForRefreshTokenWithUniqueUserId:userId
                                                                    environment:authority.msidHostWithPortIfNecessary
                                                                       clientId:clientId];
        }
        case MSIDTokenTypeIDToken:
        {
            return [MSIDDefaultTokenCacheKey keyForIDTokenWithUniqueUserId:userId
                                                                 authority:authority
                                                                  clientId:clientId];
        }
            
        default:
            // ADFS token type is not supported
            return nil;
    }
}


- (BOOL)saveToken:(MSIDBaseToken *)token
           userId:(NSString *)userId
         clientId:(NSString *)clientId
           scopes:(NSOrderedSet<NSString *> *)scopes
        authority:(NSURL *)authority
       serializer:(id<MSIDCacheItemSerializer>)serializer
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
    
    MSIDTokenCacheKey *key = [self keyForTokenType:token.tokenType
                                            userId:userId
                                          clientId:clientId
                                            scopes:scopes
                                         authority:authority];
    
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    if (!key)
    {
        [self stopTelemetryEvent:event
                        withItem:cacheItem
                         success:NO
                         context:context];
        
        return NO;
    }
    
    BOOL result = [_dataSource setItem:cacheItem
                                   key:key
                            serializer:serializer
                               context:context
                                 error:error];
    
    [self stopTelemetryEvent:event
                    withItem:cacheItem
                     success:result
                     context:context];
    
    return result;
}

- (MSIDRefreshToken *)getRefreshTokenForUserId:(NSString *)userId
                                      clientId:(NSString *)clientId
                                     authority:(NSURL *)authority
                                    serializer:(id<MSIDCacheItemSerializer>)serializer
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
        MSIDTokenCacheKey *key = [self keyForTokenType:MSIDTokenTypeRefreshToken
                                                userId:userId
                                              clientId:clientId
                                                scopes:nil
                                             authority:alias];
        if (!key)
        {
            [self stopTelemetryEvent:event
                           withItem:nil
                             success:NO
                             context:context];
            
            return nil;
        }
        
        NSError *cacheError = nil;
        
        MSIDTokenCacheItem *cacheItem = (MSIDTokenCacheItem *)[_dataSource itemWithKey:key
                                                                            serializer:serializer
                                                                               context:context
                                                                                 error:&cacheError];
        
        if (cacheItem)
        {
            MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] initWithTokenCacheItem:cacheItem];
            refreshToken.authority = authority;
            [self stopTelemetryEvent:event withItem:cacheItem success:YES context:context];
            return refreshToken;
        }
       
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
    }
    
    [self stopTelemetryEvent:event
                   withItem:nil
                     success:NO
                     context:context];
    
    return nil;
}

- (NSArray<MSIDTokenCacheItem *> *)getAllATsForAccount:(MSIDAccount *)account
                                             authority:(NSURL *)authority
                                              clientId:(NSString *)clientId
                                               context:(id<MSIDRequestContext>)context
                                                 error:(NSError **)error
{
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForAllAccessTokensWithUniqueUserId:account.userIdentifier
                                                                                          authority:authority
                                                                                           clientId:clientId];
    return [self getAllTokensWithKey:key context:context error:error];
}


- (NSArray<MSIDTokenCacheItem *> *)getAllATsForContext:(id<MSIDRequestContext>)context
                                                 error:(NSError *__autoreleasing *)error
{
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForAllAccessTokens];
    return [self getAllTokensWithKey:key context:context error:error];
}

- (NSArray<MSIDTokenCacheItem *> *)getAllTokensWithKey:(MSIDTokenCacheKey *)key
                                               context:(id<MSIDRequestContext>)context
                                                 error:(NSError *__autoreleasing *)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    NSArray *tokens = [_dataSource itemsWithKey:key serializer:_tokenSerializer context:context error:error];
    
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
