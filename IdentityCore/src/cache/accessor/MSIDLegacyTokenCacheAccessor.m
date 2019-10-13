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
#import "NSURL+MSIDExtensions.h"

@interface MSIDLegacyTokenCacheAccessor()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDKeyedArchiverSerializer *_serializer;
    MSIDOauth2Factory *_factory;
    NSArray *_otherAccessors;
}

@property (nonatomic) MSIDAuthorityFactory *authorityFactory;

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
        _authorityFactory = [MSIDAuthorityFactory new];
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
                       appIdentifier:(NSString *)appIdentifier
                        enrollmentId:(NSString *)enrollmentId
                    saveSSOStateOnly:(BOOL)saveSSOStateOnly
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Saving broker response, only save SSO state %d", saveSSOStateOnly);

    __auto_type authority = [self.authorityFactory authorityFromUrl:[NSURL URLWithString:response.authority]
                                                            context:context error:error];
    
    if (!authority) return NO;
    
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
    
    configuration.applicationIdentifier = appIdentifier;
    configuration.enrollmentId = enrollmentId;

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
        NSError *otherAccessorError = nil;

        if (![accessor saveSSOStateWithConfiguration:configuration
                                            response:response
                                             context:context
                                               error:&otherAccessorError])
        {
            MSID_LOG_WARN(context, @"Failed to save SSO state in other accessor: %@", accessor.class);
            MSID_LOG_WARN(context, @"Failed to save SSO state in other accessor: %@, error %@", accessor.class, otherAccessorError);
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

    MSIDRefreshToken *refreshToken = [self getLegacyRefreshTokenForAccountImpl:account
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

- (NSArray<MSIDAccount *> *)allAccountsForAuthority:(MSIDAuthority *)authority
                                           clientId:(NSString *)clientId
                                           familyId:(NSString *)familyId
                                            context:(id<MSIDRequestContext>)context
                                              error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Get accounts with environment %@, clientId %@, familyId %@", authority.environment, clientId, familyId);

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    __auto_type items = [_dataSource tokensWithKey:query serializer:_serializer context:context error:error];

    NSArray<NSString *> *environmentAliases = [authority defaultCacheEnvironmentAliases];

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
        __auto_type account = [MSIDAccount new];
        account.accountIdentifier = refreshToken.accountIdentifier;
        account.username = refreshToken.accountIdentifier.legacyAccountId;
        NSURL *rtAuthority = [refreshToken.authority.url msidURLForPreferredHost:authority.environment context:context error:error];
        account.authority = [self.authorityFactory authorityFromUrl:rtAuthority rawTenant:refreshToken.realm context:context error:nil];
        account.accountType = MSIDAccountTypeMSSTS;
        [resultAccounts addObject:account];
    }

    return [resultAccounts allObjects];
}

- (MSIDAccount *)accountForIdentifier:(MSIDAccountIdentifier *)accountIdentifier
                             familyId:(NSString *)familyId
                        configuration:(MSIDConfiguration *)configuration
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Looking for account with client ID %@, family ID %@, authority %@", configuration.clientId, familyId, configuration.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Looking for account with client ID %@, family ID %@, authority %@, legacy user ID %@, home account ID %@", configuration.clientId, familyId, configuration.authority, accountIdentifier.legacyAccountId, accountIdentifier.homeAccountId);

    MSIDLegacyRefreshToken *refreshToken = [self getLegacyRefreshTokenForAccountImpl:accountIdentifier
                                                                            familyId:familyId
                                                                       configuration:configuration
                                                                             context:context
                                                                               error:error];

    if (refreshToken)
    {
        MSIDAccount *account = [MSIDAccount new];
        account.accountIdentifier = refreshToken.accountIdentifier;
        // TODO: Should we create account if authority is nil?
        __auto_type authority = [_authorityFactory authorityFromUrl:refreshToken.authority.url rawTenant:refreshToken.realm context:context error:nil];
        account.authority = authority;
        account.accountType = MSIDAccountTypeMSSTS;
        return account;
    }

    for (id<MSIDCacheAccessor> accessor in _otherAccessors)
    {
        MSIDAccount *account = [accessor accountForIdentifier:accountIdentifier
                                                     familyId:familyId
                                                configuration:configuration
                                                      context:context
                                                        error:error];

        if (account)
        {
            MSID_LOG_VERBOSE(context, @"(Legacy accessor) Found account in a different accessor %@", [accessor class]);
            return account;
        }
    }

    return nil;
}

#pragma mark - Public

- (MSIDLegacyAccessToken *)getAccessTokenForAccount:(MSIDAccountIdentifier *)account
                                      configuration:(MSIDConfiguration *)configuration
                                            context:(id<MSIDRequestContext>)context
                                              error:(NSError **)error
{
    NSArray *aliases = [configuration.authority legacyAccessTokenLookupAuthorities] ?: @[];

    return (MSIDLegacyAccessToken *)[self getTokenByLegacyUserId:account.legacyAccountId
                                                            type:MSIDAccessTokenType
                                                       authority:configuration.authority
                                                   lookupAliases:aliases
                                                        clientId:configuration.clientId
                                                        resource:configuration.target
                                                   appIdentifier:configuration.applicationIdentifier
                                                         context:context
                                                           error:error];
}

- (MSIDLegacySingleResourceToken *)getSingleResourceTokenForAccount:(MSIDAccountIdentifier *)account
                                                      configuration:(MSIDConfiguration *)configuration
                                                            context:(id<MSIDRequestContext>)context
                                                              error:(NSError **)error
{
    NSArray *aliases = [configuration.authority legacyAccessTokenLookupAuthorities] ?: @[];

    return (MSIDLegacySingleResourceToken *)[self getTokenByLegacyUserId:account.legacyAccountId
                                                                    type:MSIDLegacySingleResourceTokenType
                                                               authority:configuration.authority
                                                           lookupAliases:aliases
                                                                clientId:configuration.clientId
                                                                resource:configuration.target
                                                           appIdentifier:configuration.applicationIdentifier
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
    MSID_LOG_VERBOSE_PII(context, @"Removing refresh token with clientID %@, authority %@, userId %@, token %@", token.clientId, token.authority, token.accountIdentifier.homeAccountId, _PII_NULLIFY(token.refreshToken));

    MSIDCredentialCacheItem *cacheItem = [token tokenCacheItem];

    __auto_type storageAuthority = token.storageAuthority ? token.storageAuthority : token.authority;
    __auto_type lookupAliases = storageAuthority.url ? @[storageAuthority.url] : @[];

    MSIDLegacyRefreshToken *tokenInCache = (MSIDLegacyRefreshToken *)[self getTokenByLegacyUserId:token.accountIdentifier.legacyAccountId
                                                                                             type:cacheItem.credentialType
                                                                                        authority:token.authority
                                                                                    lookupAliases:lookupAliases
                                                                                         clientId:cacheItem.clientId
                                                                                         resource:cacheItem.target
                                                                                    appIdentifier:nil
                                                                                          context:context
                                                                                            error:error];

    if (tokenInCache && [tokenInCache.refreshToken isEqualToString:token.refreshToken])
    {
        MSID_LOG_VERBOSE(context, @"Found refresh token in cache and it's the latest version, removing token");
        MSID_LOG_VERBOSE_PII(context, @"Found refresh token in cache and it's the latest version, removing token %@", token);

        return [self removeTokenCacheItem:tokenInCache.legacyTokenCacheItem
                                   userId:tokenInCache.accountIdentifier.legacyAccountId
                                  context:context
                                    error:error];
    }
    
    // Clear RT from other accessors
    for (id<MSIDCacheAccessor> accessor in _otherAccessors)
    {
        if (![accessor validateAndRemoveRefreshToken:token context:context error:error])
        {
            MSID_LOG_WARN(context, @"Failed to remove RT from other accessor: %@", accessor.class);
            MSID_LOG_WARN(context, @"Failed to remove RT from other accessor:  %@, error %@", accessor.class, *error);
            return NO;
        }
    }

    return YES;
}

- (BOOL)removeAccessToken:(MSIDLegacyAccessToken *)token
                  context:(id<MSIDRequestContext>)context
                    error:(NSError **)error
{
    return [self removeTokenCacheItem:token.legacyTokenCacheItem
                               userId:token.accountIdentifier.legacyAccountId
                              context:context
                                error:error];
}

- (BOOL)clearCacheForAccount:(MSIDAccountIdentifier *)account
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error
{
    return [self clearCacheForAccount:account clientId:nil context:context error:error];
}

- (BOOL)clearCacheForAccount:(MSIDAccountIdentifier *)account
                    clientId:(NSString *)clientId
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Clearing cache with account and client id %@", clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Clearing cache with account %@ and client id %@", account.legacyAccountId, clientId);

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];

    BOOL result = YES;

    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    query.legacyUserId = account.legacyAccountId;

    // If only user id is provided, optimize operation by deleting from data source directly
    if ([NSString msidIsStringNilOrBlank:clientId]
        && ![NSString msidIsStringNilOrBlank:account.legacyAccountId])
    {
        result = [_dataSource removeItemsWithKey:query context:context error:error];
        [_dataSource saveWipeInfoWithContext:context error:nil];
    }
    else
    {
        // If we need to filter by client id, then we need to query all items by user id and go through them
        NSArray *results = [_dataSource tokensWithKey:query serializer:_serializer context:context error:error];

        if (results)
        {
            for (MSIDLegacyTokenCacheItem *cacheItem in results)
            {
                if (clientId && [cacheItem.clientId isEqualToString:clientId])
                {
                    result &= [self removeTokenCacheItem:cacheItem userId:cacheItem.idTokenClaims.userId context:context error:error];
                }
            }
        }
    }

    [MSIDTelemetry stopCacheEvent:event withItem:nil success:result context:context];

    // Clear cache from other accessors
    for (id<MSIDCacheAccessor> accessor in _otherAccessors)
    {
        if (![accessor clearCacheForAccount:account
                                   clientId:clientId
                                    context:context
                                      error:error])
        {
            MSID_LOG_WARN(context, @"Failed to clear cache from other accessor: %@", accessor.class);
            MSID_LOG_WARN(context, @"Failed to clear cache from other accessor:  %@, error %@", accessor.class, *error);
        }
    }

    return result;
}

#pragma mark - Input validation

- (BOOL)fillInternalErrorWithMessage:(NSString *)message
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSID_LOG_ERROR(context, @"%@", message);

    if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, message, nil, nil, nil, context.correlationId, nil);
    return YES;
}

#pragma mark - Internal

- (MSIDLegacyRefreshToken *)getLegacyRefreshTokenForAccountImpl:(MSIDAccountIdentifier *)account
                                                       familyId:(NSString *)familyId
                                                  configuration:(MSIDConfiguration *)configuration
                                                        context:(id<MSIDRequestContext>)context
                                                          error:(NSError **)error
{
    
    
    NSString *clientId = familyId ? [MSIDCacheKey familyClientId:familyId] : configuration.clientId;
    NSArray<NSURL *> *aliases = [configuration.authority legacyRefreshTokenLookupAliases] ?: @[];

    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Finding refresh token with legacy user ID, clientId %@, authority %@", clientId, aliases);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Finding refresh token with legacy user ID %@, clientId %@, authority %@", account.legacyAccountId, clientId, aliases);

    return (MSIDLegacyRefreshToken *)[self getTokenByLegacyUserId:account.legacyAccountId
                                                             type:MSIDRefreshTokenType
                                                        authority:configuration.authority
                                                    lookupAliases:aliases
                                                         clientId:clientId
                                                         resource:nil
                                                    appIdentifier:nil
                                                          context:context
                                                            error:error];
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
                    userId:accessToken.accountIdentifier.legacyAccountId
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
                           userId:refreshToken.accountIdentifier.legacyAccountId
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
                    userId:familyRefreshToken.accountIdentifier.legacyAccountId
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
                    userId:legacyToken.accountIdentifier.legacyAccountId
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
    
    key.applicationIdentifier = tokenCacheItem.applicationIdentifier;

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

- (BOOL)removeTokenCacheItem:(MSIDLegacyTokenCacheItem *)cacheItem
                      userId:(NSString *)userId
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error
{
    if (!cacheItem)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Token not provided", nil, nil, nil, context.correlationId, nil);
        }

        return NO;
    }

    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Removing token with clientId %@, authority %@", cacheItem.clientId, cacheItem.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Removing token %@ with account %@", cacheItem, userId);

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];

    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:cacheItem.authority
                                                                             clientId:cacheItem.clientId
                                                                             resource:cacheItem.target
                                                                         legacyUserId:userId];
    
    key.applicationIdentifier = cacheItem.applicationIdentifier;

    BOOL result = [_dataSource removeItemsWithKey:key context:context error:error];

    if (result && cacheItem.credentialType == MSIDRefreshTokenType)
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
                            appIdentifier:(NSString *)appIdentifier
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
        
        key.applicationIdentifier = appIdentifier;
        
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

@end
