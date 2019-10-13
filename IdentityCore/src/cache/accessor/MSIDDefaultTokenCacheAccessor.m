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
#import "MSIDAccount.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDConfiguration.h"
#import "MSIDOauth2Factory.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDDefaultCredentialCacheQuery.h"
#import "MSIDBrokerResponse.h"
#import "MSIDDefaultAccountCacheQuery.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTelemetry+Cache.h"
#import "MSIDAuthority.h"
#import "MSIDAuthorityFactory.h"

@interface MSIDDefaultTokenCacheAccessor()
{
    MSIDAccountCredentialCache *_accountCredentialCache;
    NSArray<id<MSIDCacheAccessor>> *_otherAccessors;
    MSIDOauth2Factory *_factory;
}

@end

@implementation MSIDDefaultTokenCacheAccessor

#pragma mark - MSIDCacheAccessor

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
               otherCacheAccessors:(NSArray<id<MSIDCacheAccessor>> *)otherAccessors
                           factory:(MSIDOauth2Factory *)factory
{
    self = [super init];

    if (self)
    {
        _accountCredentialCache = [[MSIDAccountCredentialCache alloc] initWithDataSource:dataSource];
        _otherAccessors = otherAccessors;
        _factory = factory;
    }

    return self;
}

- (BOOL)saveTokensWithConfiguration:(MSIDConfiguration *)configuration
                           response:(MSIDTokenResponse *)response
                            context:(id<MSIDRequestContext>)context
                              error:(NSError *__autoreleasing *)error
{
    MSID_LOG_VERBOSE(context, @"(Default accessor) Saving multi resource refresh token");

    // Save access token
    BOOL result = [self saveAccessTokenWithConfiguration:configuration response:response context:context error:error];

    if (!result) return result;

    // Save ID token
    result = [self saveIDTokenWithConfiguration:configuration response:response context:context error:error];

    if (!result) return result;

    // Save SSO state (refresh token and account)
    return [self saveSSOStateWithConfiguration:configuration response:response context:context error:error];
}

- (BOOL)saveTokensWithBrokerResponse:(MSIDBrokerResponse *)response
                       appIdentifier:(NSString *)appIdentifier
                        enrollmentId:(NSString *)enrollmentId
                    saveSSOStateOnly:(BOOL)saveSSOStateOnly
                             context:(id<MSIDRequestContext>)context
                               error:(NSError *__autoreleasing *)error
{
    // MSAL currently doesn't yet support broker
    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUnsupportedFunctionality, @"MSAL currently doesn't yet support broker", nil, nil, nil, nil, nil);
    }

    return NO;
}

- (BOOL)saveSSOStateWithConfiguration:(MSIDConfiguration *)configuration
                             response:(MSIDTokenResponse *)response
                              context:(id<MSIDRequestContext>)context
                                error:(NSError *__autoreleasing *)error
{
    if (!response)
    {
        [self fillInternalErrorWithMessage:@"No token response provided" context:context error:error];
        return NO;
    }

    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Saving SSO state");

    BOOL result = [self saveRefreshTokenWithConfiguration:configuration response:response context:context error:error];

    if (!result) return NO;

    return [self saveAccountWithConfiguration:configuration response:response context:context error:error];
}

- (MSIDRefreshToken *)getRefreshTokenWithAccount:(MSIDAccountIdentifier *)account
                                        familyId:(NSString *)familyId
                                   configuration:(MSIDConfiguration *)configuration
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError *__autoreleasing *)error
{
    if (![NSString msidIsStringNilOrBlank:account.homeAccountId])
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Finding token with user ID, clientId %@, familyID %@, authority %@", configuration.clientId, familyId, configuration.authority);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Finding token with user ID %@, clientId %@, familyID %@, authority %@", account.homeAccountId, configuration.clientId, familyId, configuration.authority);

        MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
        query.homeAccountId = account.homeAccountId;
        query.environmentAliases = [configuration.authority defaultCacheEnvironmentAliases];
        query.clientId = familyId ? nil : configuration.clientId;
        query.familyId = familyId;
        query.credentialType = MSIDRefreshTokenType;

        MSIDRefreshToken *refreshToken = (MSIDRefreshToken *) [self getTokenWithAuthority:configuration.authority
                                                                               cacheQuery:query
                                                                                  context:context
                                                                                    error:error];

        if (refreshToken)
        {
            MSID_LOG_VERBOSE(context, @"(Default accessor) Found refresh token by home account id");
            return refreshToken;
        }
    }

    if (![NSString msidIsStringNilOrBlank:account.legacyAccountId])
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Finding refresh token with legacy user ID, clientId %@, authority %@", configuration.clientId, configuration.authority);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Finding refresh token with legacy user ID %@, clientId %@, authority %@", account.legacyAccountId, configuration.clientId, configuration.authority);

        MSIDRefreshToken *refreshToken = (MSIDRefreshToken *) [self getRefreshTokenByLegacyUserId:account.legacyAccountId
                                                                                        authority:configuration.authority
                                                                                         clientId:configuration.clientId
                                                                                         familyId:familyId
                                                                                          context:context
                                                                                            error:error];

        if (refreshToken)
        {
            MSID_LOG_VERBOSE(context, @"(Default accessor) Found refresh token by legacy account id");
            return refreshToken;
        }
    }

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

    return nil;
}

- (BOOL)clearWithContext:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    return [_accountCredentialCache clearWithContext:context error:error];
}

- (NSArray<MSIDBaseToken *> *)allTokensWithContext:(id<MSIDRequestContext>)context
                                             error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    NSArray<MSIDCredentialCacheItem *> *cacheItems = [_accountCredentialCache getAllItemsWithContext:context error:error];
    NSArray<MSIDBaseToken *> *tokens = [self validTokensFromCacheItems:cacheItems];

    [MSIDTelemetry stopCacheEvent:event withItem:nil success:[cacheItems count] > 0 context:context];
    return tokens;
}

#pragma mark - Public

- (MSIDAccessToken *)getAccessTokenForAccount:(MSIDAccountIdentifier *)account
                                configuration:(MSIDConfiguration *)configuration
                                      context:(id<MSIDRequestContext>)context
                                        error:(NSError **)error
{

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = account.homeAccountId;
    query.environmentAliases = [configuration.authority defaultCacheEnvironmentAliases];
    query.realm = configuration.authority.url.msidTenant;
    query.clientId = configuration.clientId;
    query.target = configuration.target;
    query.targetMatchingOptions = MSIDSubSet;
    query.credentialType = MSIDAccessTokenType;

    return (MSIDAccessToken *) [self getTokenWithAuthority:configuration.authority
                                                cacheQuery:query
                                                   context:context
                                                     error:error];
}

- (MSIDIdToken *)getIDTokenForAccount:(MSIDAccountIdentifier *)account
                        configuration:(MSIDConfiguration *)configuration
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = account.homeAccountId;
    query.environmentAliases = [configuration.authority defaultCacheEnvironmentAliases];
    query.realm = configuration.authority.url.msidTenant;
    query.clientId = configuration.clientId;
    query.credentialType = MSIDIDTokenType;

    return (MSIDIdToken *) [self getTokenWithAuthority:configuration.authority
                                            cacheQuery:query
                                               context:context
                                                 error:error];
}

- (NSArray<MSIDAccount *> *)allAccountsForAuthority:(MSIDAuthority *)authority
                                           clientId:(NSString *)clientId
                                           familyId:(NSString *)familyId
                                            context:(id<MSIDRequestContext>)context
                                              error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Default accessor) Get accounts with environment %@, clientId %@, familyId %@", authority.environment, clientId, familyId);

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    NSArray<NSString *> *environmentAliases = [authority defaultCacheEnvironmentAliases];

    NSMutableSet *filteredAccountsSet = [self getAccountsForEnvironment:authority.environment
                                                     environmentAliases:environmentAliases
                                                                context:context
                                                                  error:error];

    if (!filteredAccountsSet)
    {
        MSID_LOG_ERROR(context, @"(Default accessor) Failed accounts lookup");
        [MSIDTelemetry stopCacheEvent:event withItem:nil success:NO context:context];
        return @[];
    }

    if ([filteredAccountsSet count])
    {
        [MSIDTelemetry stopCacheEvent:event withItem:nil success:YES context:context];
    }
    else
    {
        MSID_LOG_INFO(context, @"(Default accessor) No accounts found in default accessor");
        [MSIDTelemetry stopFailedCacheEvent:event wipeData:[_accountCredentialCache wipeInfoWithContext:context error:error] context:context];
    }

    for (id<MSIDCacheAccessor> accessor in _otherAccessors)
    {
        NSArray *accounts = [accessor allAccountsForAuthority:authority
                                                     clientId:clientId
                                                     familyId:familyId
                                                      context:context
                                                        error:error];

        [filteredAccountsSet addObjectsFromArray:accounts];
    }

    return [filteredAccountsSet allObjects];
}

- (MSIDAccount *)accountForIdentifier:(MSIDAccountIdentifier *)accountIdentifier
                             familyId:(NSString *)familyId
                        configuration:(MSIDConfiguration *)configuration
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for account with client ID %@, family ID %@, authority %@", configuration.clientId, familyId, configuration.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Looking for account with client ID %@, family ID %@, authority %@, legacy user ID %@, home account ID %@", configuration.clientId, familyId, configuration.authority, accountIdentifier.legacyAccountId, accountIdentifier.homeAccountId);

    MSIDDefaultAccountCacheQuery *cacheQuery = [MSIDDefaultAccountCacheQuery new];
    cacheQuery.homeAccountId = accountIdentifier.homeAccountId;
    cacheQuery.environmentAliases = [configuration.authority defaultCacheEnvironmentAliases];
    cacheQuery.accountType = MSIDAccountTypeMSSTS;

    NSArray<MSIDAccountCacheItem *> *accountCacheItems = [_accountCredentialCache getAccountsWithQuery:cacheQuery context:context error:error];

    if (!accountCacheItems)
    {
        MSID_LOG_WARN(context, @"(Default accessor) Failed to retrieve account with client ID %@, family ID %@, authority %@", configuration.clientId, familyId, configuration.authority);
        return nil;
    }

    for (MSIDAccountCacheItem *cacheItem in accountCacheItems)
    {
        MSIDAccount *account = [[MSIDAccount alloc] initWithAccountCacheItem:cacheItem];
        if (account) return account;
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
            MSID_LOG_VERBOSE(context, @"(Default accessor) Found account in a different accessor %@", [accessor class]);
            return account;
        }
    }

    return nil;
}

- (BOOL)removeAccount:(MSIDAccount *)account
              context:(id<MSIDRequestContext>)context
                error:(NSError **)error
{
    if (!account)
    {
        [self fillInternalErrorWithMessage:@"Account not provided, cannot remove" context:context error:error];
        return NO;
    }

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];
    BOOL result = [_accountCredentialCache removeAccount:account.accountCacheItem context:context error:error];
    [MSIDTelemetry stopCacheEvent:event withItem:nil success:result context:context];
    return result;
}

- (BOOL)clearCacheForAccount:(MSIDAccountIdentifier *)account
                   authority:(MSIDAuthority *)authority
                    clientId:(NSString *)clientId
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error
{
    if (!account)
    {
        [self fillInternalErrorWithMessage:@"Missing parameter, please provide account" context:context error:error];
        return NO;
    }

    MSID_LOG_VERBOSE(context, @"Clearing cache for environment: %@, client ID %@", authority.environment, clientId);
    MSID_LOG_VERBOSE(context, @"Clearing cache for environment: %@, client ID %@, account %@", authority.environment, clientId, account.homeAccountId);

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];

    NSArray *aliases = [authority defaultCacheEnvironmentAliases];

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.clientId = clientId;
    query.homeAccountId = account.homeAccountId;
    query.environmentAliases = aliases;
    query.matchAnyCredentialType = YES;

    BOOL result = [_accountCredentialCache removeCredetialsWithQuery:query context:context error:error];

    if (!result)
    {
        [MSIDTelemetry stopCacheEvent:event withItem:nil success:NO context:context];
        return NO;
    }

    MSIDDefaultAccountCacheQuery *accountsQuery = [MSIDDefaultAccountCacheQuery new];
    accountsQuery.homeAccountId = account.homeAccountId;
    accountsQuery.environmentAliases = aliases;

    result = [_accountCredentialCache removeAccountsWithQuery:accountsQuery context:context error:error];
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

- (BOOL)validateAndRemoveRefreshToken:(MSIDRefreshToken *)token
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

    NSURL *authority = token.storageAuthority.url ? token.storageAuthority.url : token.authority.url;

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = token.accountIdentifier.homeAccountId;
    query.environment = authority.msidHostWithPortIfNecessary;
    query.clientId = token.clientId;
    query.familyId = token.familyId;
    query.credentialType = MSIDRefreshTokenType;

    MSIDRefreshToken *tokenInCache = (MSIDRefreshToken *) [self getTokenWithAuthority:token.authority
                                                                           cacheQuery:query
                                                                              context:context
                                                                                error:error];

    if (tokenInCache && [tokenInCache.refreshToken isEqualToString:token.refreshToken])
    {
        MSID_LOG_VERBOSE(context, @"Found refresh token in cache and it's the latest version, removing token");
        MSID_LOG_VERBOSE_PII(context, @"Found refresh token in cache and it's the latest version, removing token %@", token);

        return [self removeToken:tokenInCache context:context error:error];
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

- (BOOL)clearCacheForAccount:(MSIDAccountIdentifier *)account
                    clientId:(NSString *)clientId
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];
    
    BOOL result = YES;

    // If home account id is available, remove tokens by home account id
    if (account.homeAccountId)
    {
        result = [self clearCacheForAccount:account
                                  authority:nil
                                   clientId:clientId
                                    context:context
                                      error:error];
    }
    // If legacy account id is available, lookup home account id by legacy account id and remove tokens
    else if (account.legacyAccountId)
    {
        MSIDDefaultAccountCacheQuery *accountsQuery = [MSIDDefaultAccountCacheQuery new];
        accountsQuery.accountType = MSIDAccountTypeMSSTS;

        NSArray<MSIDAccountCacheItem *> *resultAccounts = [_accountCredentialCache getAccountsWithQuery:accountsQuery context:context error:error];

        for (MSIDAccountCacheItem *cacheItem in resultAccounts)
        {
            if ([cacheItem.username isEqualToString:account.legacyAccountId]
                && cacheItem.homeAccountId)
            {
                account.homeAccountId = cacheItem.homeAccountId;

                result &= [self clearCacheForAccount:account
                                           authority:nil
                                            clientId:clientId
                                             context:context
                                               error:error];

                break;
            }
        }
    }

    if (!result)
    {
        [MSIDTelemetry stopCacheEvent:event withItem:nil success:result context:context];
        return NO;
    }

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

    [MSIDTelemetry stopCacheEvent:event withItem:nil success:result context:context];
    return YES;
}

#pragma mark - Input validation

- (BOOL)checkAccountIdentifier:(NSString *)accountIdentifier
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    if (!accountIdentifier)
    {
        MSID_LOG_ERROR(context, @"(Default accessor) User identifier is expected for default accessor, but not provided");
        MSID_LOG_ERROR_PII(context, @"(Default accessor) User identifier is expected for default accessor, but not provided");
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Account identifier is expected for MSDIDefaultTokenCacheFormat", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)fillInternalErrorWithMessage:(NSString *)message
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSID_LOG_ERROR(context, @"%@", message);
    
    if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, message, nil, nil, nil, context.correlationId, nil);
    return YES;
}

#pragma mark - Internal

- (BOOL)saveAccessTokenWithConfiguration:(MSIDConfiguration *)configuration
                                response:(MSIDTokenResponse *)response
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    MSIDAccessToken *accessToken = [_factory accessTokenFromResponse:response configuration:configuration];
    if (!accessToken)
    {
        [self fillInternalErrorWithMessage:@"Response does not contain an access token" context:context error:error];
        return NO;
    }

    if (![self checkAccountIdentifier:accessToken.accountIdentifier.homeAccountId context:context error:error])
    {
        return NO;
    }

    return [self saveAccessToken:accessToken context:context error:error];
}

- (BOOL)saveIDTokenWithConfiguration:(MSIDConfiguration *)configuration
                            response:(MSIDTokenResponse *)response
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSIDIdToken *idToken = [_factory idTokenFromResponse:response configuration:configuration];

    if (idToken)
    {
        return [self saveToken:idToken context:context error:error];
    }

    return YES;
}

- (BOOL)saveRefreshTokenWithConfiguration:(MSIDConfiguration *)configuration
                                 response:(MSIDTokenResponse *)response
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    MSIDRefreshToken *refreshToken = [_factory refreshTokenFromResponse:response configuration:configuration];

    if (!refreshToken)
    {
        return YES;
    }

    if (![NSString msidIsStringNilOrBlank:refreshToken.familyId])
    {
        MSID_LOG_VERBOSE(context, @"Saving family refresh token %@", _PII_NULLIFY(refreshToken.refreshToken));
        MSID_LOG_VERBOSE_PII(context, @"Saving family refresh token %@", _PII_NULLIFY(refreshToken.refreshToken));

        if (![self saveToken:refreshToken context:context error:error])
        {
            return NO;
        }
    }

    refreshToken.familyId = nil;

    return [self saveToken:refreshToken context:context error:error];
}

- (BOOL)saveAccountWithConfiguration:(MSIDConfiguration *)configuration
                            response:(MSIDTokenResponse *)response
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSIDAccount *account = [_factory accountFromResponse:response configuration:configuration];

    if (account)
    {
        return [self saveAccount:account context:context error:error];
    }

    return YES;
}

- (BOOL)saveAccessToken:(MSIDAccessToken *)accessToken
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error
{
    // Delete access tokens with intersecting scopes
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = accessToken.accountIdentifier.homeAccountId;
    query.environment = accessToken.authority.environment;
    query.realm = accessToken.authority.url.msidTenant;
    query.clientId = accessToken.clientId;
    query.target = [accessToken.scopes msidToString];
    query.targetMatchingOptions = MSIDIntersect;
    query.credentialType = MSIDAccessTokenType;

    BOOL result = [_accountCredentialCache removeCredetialsWithQuery:query context:context error:error];

    if (!result)
    {
        return NO;
    }

    return [self saveToken:accessToken
                   context:context
                     error:error];
}

// Removal
- (BOOL)removeToken:(MSIDBaseToken *)token
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (!token)
    {
        [self fillInternalErrorWithMessage:@"Cannot remove token" context:context error:error];
        return NO;
    }

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];
    BOOL result = [_accountCredentialCache removeCredential:token.tokenCacheItem context:context error:error];

    if (result && token.credentialType == MSIDRefreshTokenType)
    {
        [_accountCredentialCache saveWipeInfoWithContext:context error:nil];
    }

    [MSIDTelemetry stopCacheEvent:event withItem:token success:result context:context];
    return result;
}

- (NSMutableSet *)getAccountsForEnvironment:(NSString *)inputEnvironment
                         environmentAliases:(NSArray<NSString *> *)environmentAliases
                                    context:(id<MSIDRequestContext>)context
                                      error:(NSError **)error
{
    MSIDDefaultAccountCacheQuery *accountsQuery = [MSIDDefaultAccountCacheQuery new];
    accountsQuery.accountType = MSIDAccountTypeMSSTS;
    accountsQuery.environmentAliases = environmentAliases;

    NSArray<MSIDAccountCacheItem *> *resultAccounts = [_accountCredentialCache getAccountsWithQuery:accountsQuery context:context error:error];

    if (!resultAccounts)
    {
        return nil;
    }

    NSMutableSet *resultAccountSet = [NSMutableSet set];

    for (MSIDAccountCacheItem *accountCacheItem in resultAccounts)
    {
        if (inputEnvironment) accountCacheItem.environment = inputEnvironment;

        [resultAccountSet addObject:[[MSIDAccount alloc] initWithAccountCacheItem:accountCacheItem]];
    }

    return resultAccountSet;
}

#pragma mark - Private

- (MSIDBaseToken *)getTokenWithAuthority:(MSIDAuthority *)authority
                              cacheQuery:(MSIDDefaultCredentialCacheQuery *)cacheQuery
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for token with aliases %@, tenant %@, clientId %@, scopes %@", cacheQuery.environmentAliases, cacheQuery.realm, cacheQuery.clientId, cacheQuery.target);

    NSError *cacheError = nil;

    NSArray<MSIDCredentialCacheItem *> *cacheItems = [_accountCredentialCache getCredentialsWithQuery:cacheQuery context:context error:error];

    if (cacheError)
    {
        if (error) *error = cacheError;
        [MSIDTelemetry stopCacheEvent:event withItem:nil success:NO context:context];
        return nil;
    }

    if ([cacheItems count])
    {
        MSIDBaseToken *resultToken = [cacheItems[0] tokenWithType:cacheQuery.credentialType];

        if (resultToken)
        {
            MSID_LOG_VERBOSE(context, @"(Default accessor) Found %lu tokens", (unsigned long)[cacheItems count]);
            resultToken.storageAuthority = resultToken.authority;
            resultToken.authority = authority;
            [MSIDTelemetry stopCacheEvent:event withItem:resultToken success:YES context:context];
            return resultToken;
        }
    }

    if (cacheQuery.credentialType == MSIDRefreshTokenType)
    {
        [MSIDTelemetry stopFailedCacheEvent:event wipeData:[_accountCredentialCache wipeInfoWithContext:context error:error] context:context];
    }
    else
    {
        [MSIDTelemetry stopCacheEvent:event withItem:nil success:NO context:context];
    }
    return nil;
}

- (MSIDBaseToken *)getRefreshTokenByLegacyUserId:(NSString *)legacyUserId
                                       authority:(MSIDAuthority *)authority
                                        clientId:(NSString *)clientId
                                        familyId:(NSString *)familyId
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for token with authority %@, clientId %@", authority, clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Looking for token with authority %@, clientId %@, legacy userId %@", authority, clientId, legacyUserId);

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    NSArray<NSString *> *aliases = [authority defaultCacheEnvironmentAliases];

    MSIDDefaultAccountCacheQuery *accountsQuery = [MSIDDefaultAccountCacheQuery new];
    accountsQuery.username = legacyUserId;
    accountsQuery.environmentAliases = aliases;
    accountsQuery.accountType = MSIDAccountTypeMSSTS;

    NSArray<MSIDAccountCacheItem *> *accountCacheItems = [_accountCredentialCache getAccountsWithQuery:accountsQuery
                                                                                               context:context
                                                                                                 error:error];

    if ([accountCacheItems count])
    {
        MSIDAccountCacheItem *accountCacheItem = accountCacheItems[0];
        NSString *homeAccountId = accountCacheItem.homeAccountId;

        MSID_LOG_VERBOSE(context, @"(Default accessor] Found Match with environment %@, realm %@", accountCacheItem.environment, accountCacheItem.realm);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor] Found Match with environment %@, realm %@, home account ID %@", accountCacheItem.environment, accountCacheItem.realm, accountCacheItem.homeAccountId);

        MSIDDefaultCredentialCacheQuery *rtQuery = [MSIDDefaultCredentialCacheQuery new];
        rtQuery.homeAccountId = homeAccountId;
        rtQuery.environmentAliases = aliases;
        rtQuery.clientId = familyId ? nil : clientId;
        rtQuery.familyId = familyId;
        rtQuery.credentialType = MSIDRefreshTokenType;

        NSArray<MSIDCredentialCacheItem *> *rtCacheItems = [_accountCredentialCache getCredentialsWithQuery:rtQuery
                                                                                                    context:context
                                                                                                      error:error];

        if ([rtCacheItems count])
        {
            MSID_LOG_VERBOSE(context, @"(Default accessor) Found %lu refresh tokens", (unsigned long)[rtCacheItems count]);
            MSIDCredentialCacheItem *resultItem = rtCacheItems[0];
            MSIDBaseToken *resultToken = [resultItem tokenWithType:MSIDRefreshTokenType];
            resultToken.storageAuthority = resultToken.authority;
            resultToken.authority = authority;
            [MSIDTelemetry stopCacheEvent:event withItem:resultToken success:YES context:context];
            return resultToken;
        }
    }

    [MSIDTelemetry stopCacheEvent:event withItem:nil success:NO context:context];
    return nil;
}

- (BOOL)saveToken:(MSIDBaseToken *)token
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    if (![self checkAccountIdentifier:token.accountIdentifier.homeAccountId context:context error:error])
    {
        return NO;
    }

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE context:context];

    MSIDCredentialCacheItem *cacheItem = token.tokenCacheItem;
    cacheItem.environment = [[token.authority cacheUrlWithContext:context] msidHostWithPortIfNecessary];
    BOOL result = [_accountCredentialCache saveCredential:cacheItem context:context error:error];
    [MSIDTelemetry stopCacheEvent:event withItem:token success:result context:context];
    return result;
}

- (BOOL)saveAccount:(MSIDAccount *)account
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (![self checkAccountIdentifier:account.accountIdentifier.homeAccountId context:context error:error])
    {
        return NO;
    }

    MSIDTelemetryCacheEvent *event = [MSIDTelemetry startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE context:context];

    MSIDAccountCacheItem *cacheItem = account.accountCacheItem;
    cacheItem.environment = [[account.authority cacheUrlWithContext:context] msidHostWithPortIfNecessary];
    BOOL result = [_accountCredentialCache saveAccount:cacheItem context:context error:error];
    [MSIDTelemetry stopCacheEvent:event withItem:nil success:result context:context];
    return result;
}

- (NSArray<MSIDBaseToken *> *)validTokensFromCacheItems:(NSArray<MSIDCredentialCacheItem *> *)cacheItems
{
    NSMutableArray<MSIDBaseToken *> *tokens = [NSMutableArray new];

    for (MSIDCredentialCacheItem *item in cacheItems)
    {
        MSIDBaseToken *token = [item tokenWithType:item.credentialType];
        if (token) { [tokens addObject:token];}
    }

    return tokens;
}

@end
