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

#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDLegacyTokenCacheKey.h"
#import "MSIDTokenResponse.h"
#import "NSDate+MSIDExtensions.h"
#import "MSIDAuthority.h"
#import "MSIDOauth2Factory.h"
#import "MSIDLegacyTokenCacheQuery.h"
#import "MSIDLegacyAccessToken.h"
#import "MSIDLegacyRefreshToken.h"
#import "MSIDLegacyTokenCacheItem.h"
#import "MSIDBrokerResponse.h"
#import "MSIDTokenFilteringHelper.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDIdTokenClaims.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTelemetry+Cache.h"
#import "MSIDAuthorityFactory.h"

@interface MSIDLegacyTokenCacheAccessor()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDKeyedArchiverSerializer *_serializer;
    MSIDOauth2Factory *_factory;
    NSArray *_otherAccessors;
}

@end

@implementation MSIDLegacyTokenCacheAccessor

#pragma mark - Init

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
               otherCacheAccessors:(NSArray<id<MSIDCacheAccessor>> *)otherAccessors
                           factory:(MSIDOauth2Factory *)factory
{
    self = [super init];

    if (self)
    {
        _dataSource = dataSource;
        _serializer = [[MSIDKeyedArchiverSerializer alloc] init];
        _otherAccessors = otherAccessors;
        _factory = factory;
    }

    return self;
}

#pragma mark - Persistence

- (BOOL)saveTokensWithConfiguration:(MSIDConfiguration *)configuration
                           response:(MSIDTokenResponse *)response
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    if (response.isMultiResource)
    {
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Saving multi resource refresh token");
        BOOL result = [self saveAccessTokenWithConfiguration:configuration response:response context:context error:error];

        if (!result) return NO;

        return [self saveSSOStateWithConfiguration:configuration response:response context:context error:error];
    }
    else
    {
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Saving single resource refresh token");
        return [self saveLegacySingleResourceTokenWithConfiguration:configuration response:response context:context error:error];
    }
}

- (BOOL)saveTokensWithBrokerResponse:(MSIDBrokerResponse *)response
                    saveSSOStateOnly:(BOOL)saveSSOStateOnly
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Saving broker response, only save SSO state %d", saveSSOStateOnly);

    
    __auto_type authorityFactory = [MSIDAuthorityFactory new];
    __auto_type authority = [authorityFactory authorityFromUrl:[response.authority msidUrl] context:nil error:nil];
    
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:nil
                                                                           clientId:response.clientId
                                                                             target:response.resource];

    if (saveSSOStateOnly)
    {
        return [self saveSSOStateWithConfiguration:configuration
                                          response:response.tokenResponse
                                           context:context
                                             error:error];
    }

    return [self saveTokensWithConfiguration:configuration
                                    response:response.tokenResponse
                                     context:context
                                       error:error];
}

- (BOOL)saveSSOStateWithConfiguration:(MSIDConfiguration *)configuration
                             response:(MSIDTokenResponse *)response
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    if (!response)
    {
        [self fillInternalErrorWithMessage:@"No response provided" context:context error:error];
        return NO;
    }

    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Saving SSO state");

    BOOL result = [self saveRefreshTokenWithConfiguration:configuration
                                                 response:response
                                                  context:context
                                                    error:error];

    if (!result)
    {
        return NO;
    }

    for (id<MSIDCacheAccessor> accessor in _otherAccessors)
    {
        if (![accessor saveSSOStateWithConfiguration:configuration
                                            response:response
                                             context:context
                                               error:error])
        {
            MSID_LOG_WARN(context, @"Failed to save SSO state in other accessor: %@", accessor.class);
            MSID_LOG_WARN(context, @"Failed to save SSO state in other accessor: %@, error %@", accessor.class, *error);
        }
    }

    return YES;
}

- (MSIDRefreshToken *)getRefreshTokenWithAccount:(MSIDAccountIdentifier *)account
                                        familyId:(NSString *)familyId
                                   configuration:(MSIDConfiguration *)configuration
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Get refresh token with authority %@, clientId %@, familyID %@", configuration.authority, configuration.clientId, familyId);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Get refresh token with authority %@, clientId %@, familyID %@, account %@", configuration.authority, configuration.clientId, familyId, account.homeAccountId);

    MSIDRefreshToken *refreshToken = [self getRefreshTokenForAccountImpl:account
                                                                familyId:familyId
                                                           configuration:configuration
                                                                 context:context
                                                                   error:error];

    if (!refreshToken)
    {
        for (id<MSIDCacheAccessor> accessor in _otherAccessors)
        {
            MSIDRefreshToken *refreshToken = [accessor getRefreshTokenWithAccount:account
                                                                         familyId:familyId
                                                                    configuration:configuration
                                                                          context:context
                                                                            error:error];

            if (refreshToken)
            {
                MSID_LOG_VERBOSE(context, @"(Legacy accessor) Found refresh token in a different accessor %@", [accessor class]);
                return refreshToken;
            }
        }
    }

    return refreshToken;

}

- (BOOL)clearWithContext:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    return [_dataSource clearWithContext:context error:error];
}

- (NSArray<MSIDAccount *> *)allAccountsForEnvironment:(NSString *)environment
                                             clientId:(NSString *)clientId
                                             familyId:(NSString *)familyId
                                              context:(id<MSIDRequestContext>)context
                                                error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Get accounts with environment %@, clientId %@, familyId %@", environment, clientId, familyId);

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    __auto_type items = [_dataSource tokensWithKey:query serializer:_serializer context:context error:error];

    NSArray<NSString *> *environmentAliases = [_factory cacheAliasesForEnvironment:environment];

    BOOL (^filterBlock)(MSIDCredentialCacheItem *tokenCacheItem) = ^BOOL(MSIDCredentialCacheItem *tokenCacheItem) {
        if ([environmentAliases count] && ![tokenCacheItem.environment msidIsEquivalentWithAnyAlias:environmentAliases])
        {
            return NO;
        }

        if (clientId && ![tokenCacheItem.clientId isEqualToString:clientId])
        {
            return NO;
        }

        if (familyId && ![tokenCacheItem.familyId isEqualToString:familyId])
        {
            return NO;
        }

        return YES;
    };

    NSArray *refreshTokens = [MSIDTokenFilteringHelper filterTokenCacheItems:items
                                                                   tokenType:MSIDRefreshTokenType
                                                                 returnFirst:NO
                                                                    filterBy:filterBlock];

    if ([refreshTokens count] == 0)
    {
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Found no refresh tokens");
        [MSIDTelemetry stopFailedCacheEvent:event wipeData:[_dataSource wipeInfo:context error:error] context:context];
    }
    else
    {
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Found %lu refresh tokens", (unsigned long)[refreshTokens count]);
        [MSIDTelemetry stopCacheEvent:event withItem:nil success:YES context:context];
    }

    NSMutableSet *resultAccounts = [NSMutableSet set];

    for (MSIDLegacyRefreshToken *refreshToken in refreshTokens)
    {
        MSIDAccount *account = [MSIDAccount new];
        account.homeAccountId = refreshToken.homeAccountId;
        
        __auto_type authorityFactory = [MSIDAuthorityFactory new];
        __auto_type authority = [authorityFactory authorityFromUrl:refreshToken.authority.url rawTenant:refreshToken.realm context:nil error:nil];
        account.authority = authority;
        account.accountType = MSIDAccountTypeMSSTS;
        account.username = refreshToken.legacyUserId;
        [resultAccounts addObject:account];
    }

    return [resultAccounts allObjects];
}

#pragma mark - Public

- (MSIDLegacyAccessToken *)getAccessTokenForAccount:(MSIDAccountIdentifier *)account
                                      configuration:(MSIDConfiguration *)configuration
                                            context:(id<MSIDRequestContext>)context
                                              error:(NSError **)error
{
    
    NSArray *aliases = [configuration.authority cacheAliases] ?: @[];

    return (MSIDLegacyAccessToken *)[self getTokenByLegacyUserId:account.legacyAccountId
                                                            type:MSIDAccessTokenType
                                                       authority:configuration.authority
                                                   lookupAliases:aliases
                                                        clientId:configuration.clientId
                                                        resource:configuration.target
                                                         context:context
                                                           error:error];
}

- (MSIDLegacySingleResourceToken *)getSingleResourceTokenForAccount:(MSIDAccountIdentifier *)account
                                                      configuration:(MSIDConfiguration *)configuration
                                                            context:(id<MSIDRequestContext>)context
                                                              error:(NSError **)error
{
    NSArray *aliases = [configuration.authority cacheAliases] ?: @[];

    return (MSIDLegacySingleResourceToken *)[self getTokenByLegacyUserId:account.legacyAccountId
                                                                    type:MSIDLegacySingleResourceTokenType
                                                               authority:configuration.authority
                                                           lookupAliases:aliases
                                                                clientId:configuration.clientId
                                                                resource:configuration.target
                                                                 context:context
                                                                   error:error];
}

- (BOOL)validateAndRemoveRefreshToken:(MSIDBaseToken<MSIDRefreshableToken> *)token
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    if (!token || [NSString msidIsStringNilOrBlank:token.refreshToken])
    {
        [self fillInternalErrorWithMessage:@"Removing tokens can be done only as a result of a token request. Valid refresh token should be provided." context:context error:error];
        return NO;
    }

    MSID_LOG_VERBOSE(context, @"Removing refresh token with clientID %@, authority %@", token.clientId, token.authority);
    MSID_LOG_VERBOSE_PII(context, @"Removing refresh token with clientID %@, authority %@, userId %@, token %@", token.clientId, token.authority, token.homeAccountId, _PII_NULLIFY(token.refreshToken));

    MSIDCredentialCacheItem *cacheItem = [token tokenCacheItem];

    __auto_type storageAuthority = token.storageAuthority ? token.storageAuthority : token.authority;

    MSIDLegacyRefreshToken *tokenInCache = (MSIDLegacyRefreshToken *)[self getTokenByLegacyUserId:token.primaryUserId
                                                                                             type:cacheItem.credentialType
                                                                                        authority:token.authority
                                                                                    lookupAliases:@[storageAuthority.url]
                                                                                         clientId:cacheItem.clientId
                                                                                         resource:cacheItem.target
                                                                                          context:context
                                                                                            error:error];

    if (tokenInCache && [tokenInCache.refreshToken isEqualToString:token.refreshToken])
    {
        MSID_LOG_VERBOSE(context, @"Found refresh token in cache and it's the latest version, removing token");
        MSID_LOG_VERBOSE_PII(context, @"Found refresh token in cache and it's the latest version, removing token %@", token);

        return [self removeToken:token userId:token.primaryUserId context:context error:error];
    }

    return YES;
}

- (BOOL)removeAccessToken:(MSIDLegacyAccessToken *)token
                  context:(id<MSIDRequestContext>)context
                    error:(NSError **)error
{
    return [self removeToken:token userId:token.legacyUserId context:context error:error];
}

- (BOOL)clearCacheForAccount:(MSIDAccountIdentifier *)account
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error
{
    if (!account.legacyAccountId)
    {
        [self fillInternalErrorWithMessage:@"Can't clear cache without user id" context:context error:error];
        return NO;
    }

    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Clearing cache with account");
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Clearing cache with account %@", account.legacyAccountId);

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];

    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    query.legacyUserId = account.legacyAccountId;

    BOOL result = [_dataSource removeItemsWithKey:query context:context error:error];

    [_dataSource saveWipeInfoWithContext:context error:nil];

    [MSIDTelemetry stopCacheEvent:event withItem:nil success:result context:context];
    return result;
}

#pragma mark - Input validation

- (void)fillInternalErrorWithMessage:(NSString *)message
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSID_LOG_ERROR(context, @"%@", message);

    if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, message, nil, nil, nil, context.correlationId, nil);
}

#pragma mark - Internal

- (MSIDLegacyRefreshToken *)getRefreshTokenForAccountImpl:(MSIDAccountIdentifier *)account
                                                 familyId:(NSString *)familyId
                                            configuration:(MSIDConfiguration *)configuration
                                                  context:(id<MSIDRequestContext>)context
                                                    error:(NSError **)error
{
    NSString *clientId = familyId ? [MSIDCacheKey familyClientId:familyId] : configuration.clientId;
    NSArray<NSURL *> *aliases = [_factory refreshTokenLookupAuthorities:configuration.authority];

    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Finding refresh token with legacy user ID, clientId %@, authority %@", clientId, aliases);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Finding refresh token with legacy user ID %@, clientId %@, authority %@", account.legacyAccountId, clientId, aliases);

    MSIDLegacyRefreshToken *resultToken = (MSIDLegacyRefreshToken *)[self getTokenByLegacyUserId:account.legacyAccountId
                                                                                            type:MSIDRefreshTokenType
                                                                                       authority:configuration.authority
                                                                                   lookupAliases:aliases
                                                                                        clientId:clientId
                                                                                        resource:nil
                                                                                         context:context
                                                                                           error:error];

    // If no legacy user ID available, or no token found by legacy user ID, try to look by unique user ID
    if (!resultToken
        && ![NSString msidIsStringNilOrBlank:account.homeAccountId])
    {
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Finding refresh token with new user ID, clientId %@, authority %@", clientId, aliases);
        MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Finding refresh token with new user ID %@, clientId %@, authority %@", account.homeAccountId, clientId, aliases);

        *error = nil;

        resultToken = (MSIDLegacyRefreshToken *) [self getTokenByHomeAccountId:account.homeAccountId
                                                                     tokenType:MSIDRefreshTokenType
                                                                     authority:configuration.authority
                                                                 lookupAliases:aliases
                                                                      clientId:clientId
                                                                      resource:nil
                                                                       context:context
                                                                         error:error];
    }

    return resultToken;
}

- (BOOL)saveAccessTokenWithConfiguration:(MSIDConfiguration *)configuration
                                response:(MSIDTokenResponse *)response
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    MSIDLegacyAccessToken *accessToken = [_factory legacyAccessTokenFromResponse:response configuration:configuration];

    if (!accessToken)
    {
        [self fillInternalErrorWithMessage:@"Tried to save access token, but no access token returned" context:context error:error];
        return NO;
    }

    MSID_LOG_INFO(context, @"(Legacy accessor) Saving access token in legacy accessor");
    MSID_LOG_INFO_PII(context, @"(Legacy accessor) Saving access token in legacy accessor %@", accessToken);

    return [self saveToken:accessToken
                 cacheItem:accessToken.legacyTokenCacheItem
                    userId:accessToken.legacyUserId
                   context:context
                     error:error];
}

- (BOOL)saveRefreshTokenWithConfiguration:(MSIDConfiguration *)configuration
                                 response:(MSIDTokenResponse *)response
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    MSIDLegacyRefreshToken *refreshToken = [_factory legacyRefreshTokenFromResponse:response configuration:configuration];

    if (!refreshToken)
    {
        MSID_LOG_INFO(context, @"No refresh token returned in the token response, not updating cache");
        return YES;
    }

    MSID_LOG_INFO(context, @"(Legacy accessor) Saving multi resource refresh token in legacy accessor");
    MSID_LOG_INFO_PII(context, @"(Legacy accessor) Saving multi resource refresh token in legacy accessor %@", refreshToken);

    BOOL result = [self saveToken:refreshToken
                        cacheItem:refreshToken.legacyTokenCacheItem
                           userId:refreshToken.legacyUserId
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
    MSIDLegacyRefreshToken *familyRefreshToken = [refreshToken copy];
    familyRefreshToken.clientId = [MSIDCacheKey familyClientId:refreshToken.familyId];

    return [self saveToken:familyRefreshToken
                 cacheItem:familyRefreshToken.legacyTokenCacheItem
                    userId:familyRefreshToken.legacyUserId
                   context:context
                     error:error];
}

- (BOOL)saveLegacySingleResourceTokenWithConfiguration:(MSIDConfiguration *)configuration
                                              response:(MSIDTokenResponse *)response
                                               context:(id<MSIDRequestContext>)context
                                                 error:(NSError **)error
{
    MSIDLegacySingleResourceToken *legacyToken = [_factory legacyTokenFromResponse:response configuration:configuration];

    if (!legacyToken)
    {
        [self fillInternalErrorWithMessage:@"Tried to save single resource token, but no access token returned" context:context error:error];
        return NO;
    }

    MSID_LOG_INFO(context, @"(Legacy accessor) Saving single resource tokens in legacy accessor");
    MSID_LOG_INFO_PII(context, @"(Legacy accessor) Saving single resource tokens in legacy accessor %@", legacyToken);

    // Save token for legacy single resource token
    return [self saveToken:legacyToken
                 cacheItem:legacyToken.legacyTokenCacheItem
                    userId:legacyToken.legacyUserId
                   context:context
                     error:error];
}

- (BOOL)saveToken:(MSIDBaseToken *)token
        cacheItem:(MSIDLegacyTokenCacheItem *)tokenCacheItem
           userId:(NSString *)userId
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE context:context];

    NSURL *alias = [token.authority cacheUrlWithContext:context];;
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Saving token %@ with authority %@, clientID %@", [MSIDCredentialTypeHelpers credentialTypeAsString:tokenCacheItem.credentialType], alias, tokenCacheItem.clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Saving token %@ for account %@ with authority %@, clientID %@", tokenCacheItem, userId, alias, tokenCacheItem.clientId);

    // The authority used to retrieve the item over the network can differ from the preferred authority used to
    // cache the item. As it would be awkward to cache an item using an authority other then the one we store
    // it with we switch it out before saving it to cache.
    tokenCacheItem.authority = alias;

    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:alias
                                                                             clientId:tokenCacheItem.clientId
                                                                             resource:tokenCacheItem.target
                                                                         legacyUserId:userId];

    BOOL result = [_dataSource saveToken:tokenCacheItem
                                     key:key
                              serializer:_serializer
                                 context:context
                                   error:error];

    if (!result)
    {
        [MSIDTelemetry stopCacheEvent:event withItem:token success:NO context:context];
        MSID_LOG_VERBOSE(context, @"Failed to save token with alias: %@", alias);
        return NO;
    }

    [MSIDTelemetry stopCacheEvent:event withItem:token success:YES context:context];
    return YES;
}

- (NSArray<MSIDBaseToken *> *)allTokensWithContext:(id<MSIDRequestContext>)context
                                             error:(NSError **)error
{
    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    __auto_type items = [_dataSource tokensWithKey:query serializer:_serializer context:context error:error];
    
    NSMutableArray<MSIDBaseToken *> *tokens = [NSMutableArray new];
    
    for (MSIDLegacyTokenCacheItem *item in items)
    {
        MSIDBaseToken *token = [item tokenWithType:item.credentialType];
        if (token)
        {
            [tokens addObject:token];
        }
    }
    
    return tokens;
}

- (BOOL)removeToken:(MSIDBaseToken *)token
             userId:(NSString *)userId
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (!token)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Token not provided", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Removing token with clientId %@, authority %@", token.clientId, token.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Removing token %@ with account %@", token, userId);

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];
    
    MSIDCredentialCacheItem *cacheItem = token.tokenCacheItem;
 
    __auto_type authority = token.storageAuthority ? token.storageAuthority : token.authority;

    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority.url
                                                                             clientId:cacheItem.clientId
                                                                             resource:cacheItem.target
                                                                         legacyUserId:userId];
    
    BOOL result = [_dataSource removeItemsWithKey:key context:context error:error];

    if (result && token.credentialType == MSIDRefreshTokenType)
    {
        [_dataSource saveWipeInfoWithContext:context error:nil];
    }
    
    [MSIDTelemetry stopCacheEvent:event withItem:nil success:result context:context];
    return result;
}

#pragma mark - Private

- (MSIDBaseToken *)getTokenByLegacyUserId:(NSString *)legacyUserId
                                     type:(MSIDCredentialType)type
                                authority:(MSIDAuthority *)authority
                            lookupAliases:(NSArray<NSURL *> *)aliases
                                 clientId:(NSString *)clientId
                                 resource:(NSString *)resource
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    for (NSURL *alias in aliases)
    {
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Looking for token with alias %@, clientId %@, resource %@", alias, clientId, resource);
        MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Looking for token with alias %@, clientId %@, resource %@, legacy userId %@", alias, clientId, resource, legacyUserId);

        MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:alias
                                                                                 clientId:clientId
                                                                                 resource:resource
                                                                             legacyUserId:legacyUserId];
        
        if (!key)
        {
            return nil;
        }
        
        NSError *cacheError = nil;
        MSIDLegacyTokenCacheItem *cacheItem = (MSIDLegacyTokenCacheItem *) [_dataSource tokenWithKey:key serializer:_serializer context:context error:&cacheError];
        
        if (cacheError)
        {
            [MSIDTelemetry stopCacheEvent:event withItem:nil success:NO context:context];
            if (error) *error = cacheError;
            return nil;
        }

        if (cacheItem)
        {
            MSID_LOG_VERBOSE(context, @"(Legacy accessor) Found token");
            MSIDBaseToken *token = [cacheItem tokenWithType:type];
            token.storageAuthority = token.authority;
            token.authority = authority;
            [MSIDTelemetry stopCacheEvent:event withItem:token success:YES context:context];
            return token;
        }
    }

    if (type == MSIDRefreshTokenType)
    {
        [MSIDTelemetry stopFailedCacheEvent:event wipeData:[_dataSource wipeInfo:context error:error] context:context];
    }
    else
    {
        [MSIDTelemetry stopCacheEvent:event withItem:nil success:NO context:context];
    }
    return nil;
}

- (MSIDBaseToken *)getTokenByHomeAccountId:(NSString *)homeAccountId
                                 tokenType:(MSIDCredentialType)tokenType
                                 authority:(MSIDAuthority *)authority
                             lookupAliases:(NSArray<NSURL *> *)aliases
                                  clientId:(NSString *)clientId
                                  resource:(NSString *)resource
                                   context:(id<MSIDRequestContext>)context
                                     error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    for (NSURL *alias in aliases)
    {
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Looking for token with alias %@, clientId %@, resource %@", alias, clientId, resource);
        MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Looking for token with alias %@, clientId %@, resource %@, unique userId %@", alias, clientId, resource, homeAccountId);

        MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
        query.authority = alias;
        query.clientId = clientId;
        query.resource = resource;

        NSError *cacheError = nil;
        NSArray *tokens = [_dataSource tokensWithKey:query serializer:_serializer context:context error:&cacheError];
        
        if (cacheError)
        {
            [MSIDTelemetry stopCacheEvent:event withItem:nil success:NO context:context];
            if (error) *error = cacheError;
            return nil;
        }
        
        BOOL (^filterBlock)(MSIDCredentialCacheItem *cacheItem) = ^BOOL(MSIDCredentialCacheItem *cacheItem) {
            return [cacheItem.homeAccountId isEqualToString:homeAccountId];
        };
        
        NSArray *matchedTokens = [MSIDTokenFilteringHelper filterTokenCacheItems:tokens
                                                                       tokenType:tokenType
                                                                     returnFirst:YES
                                                                        filterBy:filterBlock];
        
        if ([matchedTokens count])
        {            
            MSID_LOG_VERBOSE(context, @"(Legacy accessor) Found token");
            MSIDBaseToken *token = matchedTokens[0];
            token.storageAuthority = token.authority;
            token.authority = authority;
            [MSIDTelemetry stopCacheEvent:event withItem:token success:YES context:context];
            return token;
        }
    }

    [MSIDTelemetry stopCacheEvent:event withItem:nil success:NO context:context];
    return nil;
}

@end
