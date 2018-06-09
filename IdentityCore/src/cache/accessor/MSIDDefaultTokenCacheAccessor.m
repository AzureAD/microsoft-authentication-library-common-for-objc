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

@interface MSIDDefaultTokenCacheAccessor()
{
    MSIDAccountCredentialCache *_accountCredentialCache;
    NSArray<id<MSIDCacheAccessor>> *_otherAccessors;
}

@end

@implementation MSIDDefaultTokenCacheAccessor

#pragma mark - MSIDCacheAccessor

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
               otherCacheAccessors:(NSArray<id<MSIDCacheAccessor>> *)otherAccessors
{
    self = [super init];

    if (self)
    {
        _accountCredentialCache = [[MSIDAccountCredentialCache alloc] initWithDataSource:dataSource];
        _otherAccessors = otherAccessors;
    }

    return self;
}

- (BOOL)saveTokensWithFactory:(MSIDOauth2Factory *)factory
                configuration:(MSIDConfiguration *)configuration
                     response:(MSIDTokenResponse *)response
                      context:(id<MSIDRequestContext>)context
                        error:(NSError *__autoreleasing *)error
{
    BOOL result = [self saveAccessTokenWithFactory:factory configuration:configuration response:response context:context error:error];

    if (!result) return result;

    return [self saveSSOStateWithFactory:factory configuration:configuration response:response context:context error:error];
}

- (BOOL)saveTokensWithFactory:(MSIDOauth2Factory *)factory
               brokerResponse:(MSIDBrokerResponse *)response
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

- (BOOL)saveSSOStateWithFactory:(MSIDOauth2Factory *)factory
                  configuration:(MSIDConfiguration *)configuration
                       response:(MSIDTokenResponse *)response
                        context:(id<MSIDRequestContext>)context
                          error:(NSError *__autoreleasing *)error
{
    if (!response)
    {
        [self fillInternalErrorWithMessage:@"No token response provided" context:context error:error];
        return NO;
    }

    BOOL result = [self saveIDTokenWithFactory:factory configuration:configuration response:response context:context error:error];
    result &= [self saveRefreshTokenWithFactory:factory configuration:configuration response:response context:context error:error];
    result &= [self saveAccountWithFactory:factory configuration:configuration response:response context:context error:error];

    if (!result)
    {
        return NO;
    }

    for (id<MSIDCacheAccessor> accessor in _otherAccessors)
    {
        if (![accessor saveSSOStateWithFactory:factory
                                 configuration:configuration
                                      response:response
                                       context:context
                                         error:error])
        {
            MSID_LOG_WARN(context, @"Failed to save SSO state in other accessor: %@", accessor.class);
            MSID_LOG_WARN_PII(context, @"Failed to save SSO state in other accessor: %@, error %@", accessor.class, *error);
        }
    }

    return YES;
}

- (MSIDRefreshToken *)getRefreshTokenWithAccount:(MSIDAccountIdentifier *)account
                                        familyId:(NSString *)familyId
                                         factory:(MSIDOauth2Factory *)factory
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
        query.environment = configuration.authority.msidHostWithPortIfNecessary;
        query.clientId = configuration.clientId;
        query.familyId = familyId;
        query.credentialType = MSIDRefreshTokenType;

        MSIDRefreshToken *refreshToken = (MSIDRefreshToken *) [self getTokenWithFactory:factory
                                                                              authority:configuration.authority
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
                                                                                          factory:factory
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
                                                                      factory:factory
                                                                configuration:configuration
                                                                      context:context
                                                                        error:error];

        if (refreshToken)
        {
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
    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    NSArray<MSIDCredentialCacheItem *> *cacheItems = [_accountCredentialCache getAllItemsWithContext:context error:error];
    NSArray<MSIDBaseToken *> *tokens = [self validTokensFromCacheItems:cacheItems];

    [self stopCacheEvent:event withItem:nil success:[cacheItems count] > 0 context:context];

    return tokens;
}

#pragma mark - Public

- (MSIDAccessToken *)getAccessTokenForAccount:(MSIDAccountIdentifier *)account
                                      factory:(MSIDOauth2Factory *)factory
                                configuration:(MSIDConfiguration *)configuration
                                      context:(id<MSIDRequestContext>)context
                                        error:(NSError **)error
{

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = account.homeAccountId;
    query.environment = configuration.authority.msidHostWithPortIfNecessary;
    query.realm = configuration.authority.msidTenant;
    query.clientId = configuration.clientId;
    query.target = configuration.target;
    query.targetMatchingOptions = SubSet;
    query.credentialType = MSIDAccessTokenType;

    return (MSIDAccessToken *) [self getTokenWithFactory:factory
                                               authority:configuration.authority
                                              cacheQuery:query
                                                 context:context
                                                   error:error];
}

- (MSIDIdToken *)getIDTokenForAccount:(MSIDAccountIdentifier *)account
                              factory:(MSIDOauth2Factory *)factory
                        configuration:(MSIDConfiguration *)configuration
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = account.homeAccountId;
    query.environment = configuration.authority.msidHostWithPortIfNecessary;
    query.realm = configuration.authority.msidTenant;
    query.clientId = configuration.clientId;
    query.credentialType = MSIDIDTokenType;

    return (MSIDIdToken *) [self getTokenWithFactory:factory
                                           authority:configuration.authority
                                          cacheQuery:query
                                             context:context
                                               error:error];
}

- (NSArray<MSIDAccount *> *)allAccountsForEnvironment:(NSString *)environment
                                             clientId:(NSString *)clientId
                                             familyId:(NSString *)familyId
                                              factory:(MSIDOauth2Factory *)factory
                                              context:(id<MSIDRequestContext>)context
                                                error:(NSError **)error
{
    NSMutableSet *filteredAccountsSet = [NSMutableSet set];

    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    NSArray<NSString *> *environmentAliases = [factory cacheAliasesForEnvironment:environment];
    __auto_type accountsPerUserId = [self getAccountsPerUserIdForAliases:environmentAliases context:context error:error];

    if (!accountsPerUserId)
    {
        MSID_LOG_INFO(context, @"No accounts found, returning!");
        [self stopCacheEvent:event withItem:nil success:NO context:context];
        return nil;
    }

    MSIDDefaultCredentialCacheQuery *credentialsQuery = [MSIDDefaultCredentialCacheQuery new];
    credentialsQuery.credentialType = MSIDRefreshTokenType;
    credentialsQuery.clientId = clientId;
    credentialsQuery.familyId = familyId;
    credentialsQuery.clientIdMatchingOptions = SuperSet;
    credentialsQuery.environmentAliases = environmentAliases;

    NSArray<MSIDCredentialCacheItem *> *resultCredentials = [_accountCredentialCache getCredentialsWithQuery:credentialsQuery legacyUserId:nil context:context error:error];

    for (MSIDCredentialCacheItem *credentialCacheItem in resultCredentials)
    {
        NSArray *accounts = accountsPerUserId[credentialCacheItem.homeAccountId];
        if (!accounts) continue;

        [filteredAccountsSet addObjectsFromArray:accounts];
    }

    [self stopTelemetryLookupEvent:event
                         tokenType:MSIDRefreshTokenType
                         withToken:nil
                           success:[resultCredentials count] > 0
                           context:context];

    for (id<MSIDCacheAccessor> accessor in _otherAccessors)
    {
        [filteredAccountsSet addObjectsFromArray:[accessor allAccountsForEnvironment:environment
                                                                            clientId:clientId
                                                                            familyId:familyId
                                                                             factory:factory
                                                                             context:context
                                                                               error:error]];
    }

    return [filteredAccountsSet allObjects];
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

    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];
    BOOL result = [_accountCredentialCache removeAccount:account.accountCacheItem context:context error:error];
    [self stopCacheEvent:event withItem:nil success:result context:context];
    return result;
}

- (BOOL)clearCacheForAccount:(MSIDAccountIdentifier *)account
                 environment:(NSString *)environment
                    clientId:(NSString *)clientId
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error
{
    if (!account
        || !environment
        || !clientId)
    {
        [self fillInternalErrorWithMessage:@"Missing parameter, please provide account, clientId and environment" context:context error:error];
        return NO;
    }

    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.clientId = clientId;
    query.homeAccountId = account.homeAccountId;
    query.environment = environment;
    query.matchAnyCredentialType = YES;

    BOOL result = [_accountCredentialCache removeCredetialsWithQuery:query context:context error:error];

    if (!result)
    {
        [self stopCacheEvent:event withItem:nil success:NO context:context];
        return NO;
    }

    MSIDDefaultAccountCacheQuery *accountsQuery = [MSIDDefaultAccountCacheQuery new];
    accountsQuery.homeAccountId = account.homeAccountId;
    accountsQuery.environment = environment;

    result = [_accountCredentialCache removeAccountsWithQuery:accountsQuery context:context error:error];

    [self stopCacheEvent:event withItem:nil success:result context:context];
    return result;
}

- (BOOL)validateAndRemoveRefreshToken:(MSIDRefreshToken *)token
                              factory:(MSIDOauth2Factory *)factory
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

    NSURL *authority = token.storageAuthority ? token.storageAuthority : token.authority;

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = token.homeAccountId;
    query.environment = authority.msidHostWithPortIfNecessary;
    query.clientId = token.clientId;
    query.familyId = token.familyId;
    query.credentialType = MSIDRefreshTokenType;

    MSIDRefreshToken *tokenInCache = (MSIDRefreshToken *) [self getTokenWithFactory:factory
                                                                          authority:token.authority
                                                                         cacheQuery:query
                                                                            context:context
                                                                              error:error];

    if (tokenInCache && [tokenInCache.refreshToken isEqualToString:token.refreshToken])
    {
        MSID_LOG_VERBOSE(context, @"Found refresh token in cache and it's the latest version, removing token");
        MSID_LOG_VERBOSE_PII(context, @"Found refresh token in cache and it's the latest version, removing token %@", token);

        return [self removeToken:tokenInCache context:context error:error];
    }

    return YES;
}

#pragma mark - Input validation

- (BOOL)checkUserIdentifier:(NSString *)userIdentifier
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    if (!userIdentifier)
    {
        MSID_LOG_ERROR(context, @"(Default accessor) User identifier is expected for default accessor, but not provided");
        MSID_LOG_ERROR_PII(context, @"(Default accessor) User identifier is expected for default accessor, but not provided");
        
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

#pragma mark - Internal

- (BOOL)saveAccessTokenWithFactory:(MSIDOauth2Factory *)factory
                     configuration:(MSIDConfiguration *)configuration
                          response:(MSIDTokenResponse *)response
                           context:(id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    if (!accessToken)
    {
        [self fillInternalErrorWithMessage:@"Response does not contain an access token" context:context error:error];
        return NO;
    }

    if (![self checkUserIdentifier:accessToken.homeAccountId context:context error:error])
    {
        return NO;
    }

    return [self saveAccessToken:accessToken factory:factory context:context error:error];
}

- (BOOL)saveIDTokenWithFactory:(MSIDOauth2Factory *)factory
                 configuration:(MSIDConfiguration *)configuration
                      response:(MSIDTokenResponse *)response
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    MSIDIdToken *idToken = [factory idTokenFromResponse:response configuration:configuration];

    if (idToken)
    {
        return [self saveToken:idToken factory:factory context:context error:error];
    }

    return YES;
}

- (BOOL)saveRefreshTokenWithFactory:(MSIDOauth2Factory *)factory
                      configuration:(MSIDConfiguration *)configuration
                           response:(MSIDTokenResponse *)response
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    MSIDRefreshToken *refreshToken = [factory refreshTokenFromResponse:response configuration:configuration];

    if (!refreshToken)
    {
        return YES;
    }

    if (![NSString msidIsStringNilOrBlank:refreshToken.familyId])
    {
        MSID_LOG_VERBOSE(context, @"Saving family refresh token %@", _PII_NULLIFY(refreshToken.refreshToken));
        MSID_LOG_VERBOSE_PII(context, @"Saving family refresh token %@", refreshToken.refreshToken);

        if (![self saveToken:refreshToken factory:factory context:context error:error])
        {
            return NO;
        }
    }

    refreshToken.familyId = nil;

    return [self saveToken:refreshToken factory:factory context:context error:error];
}

- (BOOL)saveAccountWithFactory:(MSIDOauth2Factory *)factory
                 configuration:(MSIDConfiguration *)configuration
                      response:(MSIDTokenResponse *)response
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];

    if (account)
    {
        return [self saveAccount:account factory:factory context:context error:error];
    }

    return YES;
}

- (BOOL)saveAccessToken:(MSIDAccessToken *)accessToken
                factory:(MSIDOauth2Factory *)factory
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error
{
    // Delete access tokens with intersecting scopes
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = accessToken.homeAccountId;
    query.environment = accessToken.authority.msidHostWithPortIfNecessary;
    query.realm = accessToken.authority.msidTenant;
    query.clientId = accessToken.clientId;
    query.target = [accessToken.scopes msidToString];
    query.targetMatchingOptions = Intersect;
    query.credentialType = MSIDAccessTokenType;

    BOOL result = [_accountCredentialCache removeCredetialsWithQuery:query context:context error:error];

    if (!result)
    {
        return NO;
    }

    return [self saveToken:accessToken
                   factory:factory
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

    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];
    BOOL result = [_accountCredentialCache removeCredential:token.tokenCacheItem context:context error:error];

    if (result && token.credentialType == MSIDRefreshTokenType)
    {
        [_accountCredentialCache saveWipeInfoWithContext:context error:nil];
    }

    [self stopCacheEvent:event withItem:token success:result context:context];
    return result;
}

- (NSMutableDictionary<NSString *, NSMutableArray *> *)getAccountsPerUserIdForAliases:(NSArray<NSString *> *)environmentAliases
                                                                              context:(id<MSIDRequestContext>)context
                                                                                error:(NSError **)error
{
    MSIDDefaultAccountCacheQuery *accountsQuery = [MSIDDefaultAccountCacheQuery new];
    accountsQuery.accountType = MSIDAccountTypeMSSTS;
    accountsQuery.environmentAliases = environmentAliases;

    NSArray<MSIDAccountCacheItem *> *resultAccounts = [_accountCredentialCache getAccountsWithQuery:accountsQuery context:context error:error];

    NSMutableDictionary<NSString *, NSMutableArray *> *accountsPerUserId = [NSMutableDictionary dictionary];

    for (MSIDAccountCacheItem *accountCacheItem in resultAccounts)
    {
        MSIDAccount *account = [[MSIDAccount alloc] initWithAccountCacheItem:accountCacheItem];

        if (account.homeAccountId)
        {
            NSMutableArray *accounts = accountsPerUserId[account.homeAccountId];

            if (!accounts)
            {
                accounts = [NSMutableArray array];
                accountsPerUserId[account.homeAccountId] = accounts;
            }

            [accounts addObject:account];
        }
    }

    return accountsPerUserId;
}

#pragma mark - Private

- (MSIDBaseToken *)getTokenWithFactory:(MSIDOauth2Factory *)factory
                             authority:(NSURL *)authority
                            cacheQuery:(MSIDDefaultCredentialCacheQuery *)cacheQuery
                               context:(id<MSIDRequestContext>)context
                                 error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    NSArray<NSString *> *aliases = [factory cacheAliasesForEnvironment:authority.msidHostWithPortIfNecessary];

    for (NSString *alias in aliases)
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for token with alias %@, tenant %@, clientId %@, scopes %@", alias, cacheQuery.realm, cacheQuery.clientId, cacheQuery.target);

        NSError *cacheError = nil;

        NSArray<MSIDCredentialCacheItem *> *cacheItems = [_accountCredentialCache getCredentialsWithQuery:cacheQuery legacyUserId:nil context:context error:error];

        if (cacheError)
        {
            if (error) *error = cacheError;
            [self stopTelemetryLookupEvent:event tokenType:cacheQuery.credentialType withToken:nil success:NO context:context];
            return nil;
        }

        if ([cacheItems count])
        {
            MSIDBaseToken *resultToken = [cacheItems[0] tokenWithType:cacheQuery.credentialType];

            if (resultToken)
            {
                resultToken.storageAuthority = resultToken.authority;
                resultToken.authority = authority;

                [self stopTelemetryLookupEvent:event tokenType:cacheQuery.credentialType withToken:resultToken success:YES context:context];
                return resultToken;
            }
        }
    }

    [self stopTelemetryLookupEvent:event tokenType:cacheQuery.credentialType withToken:nil success:YES context:context];
    return nil;
}

- (MSIDBaseToken *)getRefreshTokenByLegacyUserId:(NSString *)legacyUserId
                                       authority:(NSURL *)authority
                                        clientId:(NSString *)clientId
                                        familyId:(NSString *)familyId
                                         factory:(MSIDOauth2Factory *)factory
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    NSArray<NSURL *> *aliases = [factory cacheAliasesForAuthority:authority];

    for (NSURL *alias in aliases)
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for token with alias %@, clientId %@", alias, clientId);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Looking for token with alias %@, clientId %@, legacy userId %@", alias, clientId, legacyUserId);

        MSIDDefaultCredentialCacheQuery *idTokensQuery = [MSIDDefaultCredentialCacheQuery new];
        idTokensQuery.environment = alias.msidHostWithPortIfNecessary;
        idTokensQuery.clientId = clientId;
        idTokensQuery.credentialType = MSIDIDTokenType;

        NSArray<MSIDCredentialCacheItem *> *matchedIdTokens = [_accountCredentialCache getCredentialsWithQuery:idTokensQuery
                                                                                                  legacyUserId:legacyUserId
                                                                                                       context:context
                                                                                                         error:error];

        if ([matchedIdTokens count])
        {
            NSString *homeAccountId = matchedIdTokens[0].homeAccountId;

            MSIDDefaultCredentialCacheQuery *rtQuery = [MSIDDefaultCredentialCacheQuery new];
            rtQuery.homeAccountId = homeAccountId;
            rtQuery.environment = alias.msidHostWithPortIfNecessary;
            rtQuery.clientId = clientId;
            rtQuery.familyId = familyId;
            rtQuery.credentialType = MSIDRefreshTokenType;

            NSArray<MSIDCredentialCacheItem *> *rtCacheItems = [_accountCredentialCache getCredentialsWithQuery:rtQuery
                                                                                              legacyUserId:nil
                                                                                                   context:context
                                                                                                     error:error];

            if ([rtCacheItems count])
            {
                MSIDCredentialCacheItem *resultItem = rtCacheItems[0];
                MSIDBaseToken *resultToken = [resultItem tokenWithType:MSIDRefreshTokenType];
                resultToken.storageAuthority = resultToken.authority;
                resultToken.authority = authority;

                [self stopTelemetryLookupEvent:event tokenType:MSIDRefreshTokenType withToken:resultToken success:YES context:context];

                return resultToken;
            }
        }
    }

    [self stopTelemetryLookupEvent:event tokenType:MSIDRefreshTokenType withToken:nil success:NO context:context];

    return nil;
}

- (BOOL)saveToken:(MSIDBaseToken *)token
          factory:(MSIDOauth2Factory *)factory
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    if (![self checkUserIdentifier:token.homeAccountId context:context error:error])
    {
        return NO;
    }

    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE context:context];

    MSIDCredentialCacheItem *cacheItem = token.tokenCacheItem;
    cacheItem.environment = [factory cacheEnvironmentFromEnvironment:cacheItem.environment context:context];

    BOOL result = [_accountCredentialCache saveCredential:cacheItem context:context error:error];
    
    [self stopCacheEvent:event withItem:token success:result context:context];
    
    return result;
}

- (BOOL)saveAccount:(MSIDAccount *)account
            factory:(MSIDOauth2Factory *)factory
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (![self checkUserIdentifier:account.homeAccountId context:context error:error])
    {
        return NO;
    }

    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE context:context];
    MSIDAccountCacheItem *cacheItem = account.accountCacheItem;
    cacheItem.environment = [factory cacheEnvironmentFromEnvironment:account.authority.msidHostWithPortIfNecessary context:context];

    BOOL result = [_accountCredentialCache saveAccount:cacheItem context:context error:error];

    [self stopCacheEvent:event withItem:nil success:result context:context];

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

#pragma mark - Telemetry helpers

- (MSIDTelemetryCacheEvent *)startCacheEventWithName:(NSString *)cacheEventName
                                             context:(id<MSIDRequestContext>)context
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:cacheEventName];

    return [[MSIDTelemetryCacheEvent alloc] initWithName:cacheEventName context:context];
}

- (void)stopCacheEvent:(MSIDTelemetryCacheEvent *)event
              withItem:(MSIDBaseToken *)token
               success:(BOOL)success
               context:(id<MSIDRequestContext>)context
{
    [event setStatus:success ? MSID_TELEMETRY_VALUE_SUCCEEDED : MSID_TELEMETRY_VALUE_FAILED];
    if (token) {[event setToken:token];}
    [[MSIDTelemetry sharedInstance] stopEvent:[context telemetryRequestId]
                                        event:event];
}

- (void)stopTelemetryLookupEvent:(MSIDTelemetryCacheEvent *)event
                       tokenType:(MSIDCredentialType)tokenType
                       withToken:(MSIDBaseToken *)token
                         success:(BOOL)success
                         context:(id<MSIDRequestContext>)context
{
    if (!success && tokenType == MSIDRefreshTokenType)
    {
        [event setWipeData:[_accountCredentialCache wipeInfoWithContext:context error:nil]];
    }
    
    [self stopCacheEvent:event
                withItem:token
                 success:success
                context:context];
}

@end
