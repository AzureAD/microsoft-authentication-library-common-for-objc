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
#import "MSIDAadAuthorityCache.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDOauth2Factory.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDRequestParameters.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDDefaultCredentialCacheQuery.h"
#import "MSIDBrokerResponse.h"
#import "MSIDDefaultAccountCacheQuery.h"

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
                requestParams:(MSIDRequestParameters *)requestParams
                     response:(MSIDTokenResponse *)response
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    BOOL result = [self saveAccessTokenWithFactory:factory requestParams:requestParams response:response context:context error:error];

    if (!result) return result;
    
    return [self saveSSOStateWithFactory:factory requestParams:requestParams response:response context:context error:error];
}

- (BOOL)saveTokensWithFactory:(MSIDOauth2Factory *)factory
               brokerResponse:(MSIDBrokerResponse *)response
             saveSSOStateOnly:(BOOL)saveSSOStateOnly
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    // MSAL currently doesn't yet support broker
    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUnsupportedFunctionality, @"MSAL currently doesn't yet support broker", nil, nil, nil, nil, nil);
    }

    return NO;
}

- (BOOL)saveSSOStateWithFactory:(MSIDOauth2Factory *)factory
                  requestParams:(MSIDRequestParameters *)requestParams
                       response:(MSIDTokenResponse *)response
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    BOOL result = [self saveIDTokenWithFactory:factory requestParams:requestParams response:response context:context error:error];
    result &= [self saveRefreshTokenWithFactory:factory requestParams:requestParams response:response context:context error:error];
    result &= [self saveAccountWithFactory:factory requestParams:requestParams response:response context:context error:error];

    if (!result)
    {
        return NO;
    }

    for (id<MSIDCacheAccessor> accessor in _otherAccessors)
    {
        if (![accessor saveSSOStateWithFactory:factory
                                 requestParams:requestParams
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


- (MSIDRefreshToken *)getRefreshTokenWithAccount:(id<MSIDAccountIdentifiers>)account
                                        familyId:(NSString *)familyId
                                   requestParams:(MSIDRequestParameters *)parameters
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    NSString *clientId = familyId ? nil : parameters.clientId;

    MSIDBaseToken *refreshToken = [self getTokenWithType:MSIDCredentialTypeRefreshToken
                                                 account:account
                                               authority:parameters.authority
                                                clientId:clientId
                                                familyId:familyId
                                                  target:nil
                                                 context:context
                                                   error:error
                                            outAuthority:nil];

    if (!refreshToken)
    {
        for (id<MSIDCacheAccessor> accessor in _otherAccessors)
        {
            MSIDRefreshToken *refreshToken = [accessor getRefreshTokenWithAccount:account
                                                                         familyId:familyId
                                                                    requestParams:parameters
                                                                          context:context
                                                                            error:error];

            if (refreshToken)
            {
                return refreshToken;
            }
        }
    }

    return (MSIDRefreshToken *)refreshToken;

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

- (MSIDAccessToken *)getAccessTokenForAccount:(id<MSIDAccountIdentifiers>)account
                                requestParams:(MSIDRequestParameters *)parameters
                                      context:(id<MSIDRequestContext>)context
                                        error:(NSError **)error
{
    NSURL *outAuthority = nil;
    MSIDAccessToken *accessToken = (MSIDAccessToken *) [self getTokenWithType:MSIDCredentialTypeAccessToken
                                                                      account:account
                                                                    authority:parameters.authority
                                                                     clientId:parameters.clientId
                                                                     familyId:nil
                                                                       target:parameters.target
                                                                      context:context
                                                                        error:error
                                                                 outAuthority:&outAuthority];

    if (accessToken && !parameters.authority)
    {
        parameters.authority = outAuthority;
    }

    return accessToken;
}

- (MSIDIdToken *)getIDTokenForAccount:(id<MSIDAccountIdentifiers>)account
                        requestParams:(MSIDRequestParameters *)parameters
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    return (MSIDIdToken *) [self getTokenWithType:MSIDCredentialTypeIDToken
                                          account:account
                                        authority:parameters.authority
                                         clientId:parameters.clientId
                                         familyId:nil
                                           target:nil
                                          context:context
                                            error:error
                                     outAuthority:nil];
}

- (NSArray<MSIDAccount *> *)allAccountsForEnvironment:(NSString *)environment
                                             clientId:(NSString *)clientId
                                             familyId:(NSString *)familyId
                                              context:(id<MSIDRequestContext>)context
                                                error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    NSArray<NSString *> *environmentAliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForEnvironment:environment];
    __auto_type accountsPerUserId = [self getAccountsPerUserIdForAliases:environmentAliases context:context error:error];

    if (![accountsPerUserId count])
    {
        MSID_LOG_INFO(context, @"No accounts found, returning!");
        [self stopCacheEvent:event withItem:nil success:NO context:context];
        return nil;
    }

    MSIDDefaultCredentialCacheQuery *credentialsQuery = [MSIDDefaultCredentialCacheQuery new];
    credentialsQuery.credentialType = MSIDCredentialTypeRefreshToken;
    credentialsQuery.clientId = clientId;
    credentialsQuery.familyId = familyId;
    credentialsQuery.clientIdMatchingOptions = Any;
    credentialsQuery.environmentAliases = environmentAliases;

    NSArray<MSIDCredentialCacheItem *> *resultCredentials = [_accountCredentialCache getCredentialsWithQuery:credentialsQuery legacyUserId:nil context:context error:error];

    NSMutableArray *filteredAccounts = [NSMutableArray array];

    for (MSIDCredentialCacheItem *credentialCacheItem in resultCredentials)
    {
        MSIDAccountCacheItem *accountCacheItem = accountsPerUserId[credentialCacheItem.uniqueUserId];

        if (!accountCacheItem) { continue; }

        MSIDAccount *account = [[MSIDAccount alloc] initWithAccountCacheItem:accountCacheItem];

        if (!account) { continue; }

        [filteredAccounts addObject:account];
    }

    [self stopTelemetryLookupEvent:event
                         tokenType:MSIDCredentialTypeRefreshToken
                         withToken:nil
                           success:[resultCredentials count] > 0
                           context:context];

    for (id<MSIDCacheAccessor> accessor in _otherAccessors)
    {
        [filteredAccounts addObjectsFromArray:[accessor allAccountsForEnvironment:environment
                                                                         clientId:clientId
                                                                         familyId:familyId
                                                                          context:context
                                                                            error:error]];
    }

    return filteredAccounts;
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

- (BOOL)removeAllTokensForAccount:(id<MSIDAccountIdentifiers>)account
                      environment:(NSString *)environment
                         clientId:(NSString *)clientId
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.clientId = clientId;
    query.uniqueUserId = account.uniqueUserId;
    query.environment = environment;
    query.targetMatchingOptions = Any;
    query.matchAnyCredentialType = YES;

    BOOL result = [_accountCredentialCache removeCredetialsWithQuery:query context:context error:error];

    [self stopCacheEvent:event withItem:nil success:result context:context];
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
    MSID_LOG_VERBOSE_PII(context, @"Removing refresh token with clientID %@, authority %@, userId %@, token %@", token.clientId, token.authority, token.uniqueUserId, _PII_NULLIFY(token.refreshToken));

    MSIDRefreshToken *tokenInCache = (MSIDRefreshToken *)[self getTokenWithAliasesByUniqueUserId:token.uniqueUserId
                                                                                       tokenType:MSIDCredentialTypeRefreshToken
                                                                                       authority:token.authority
                                                                                        clientId:token.clientId
                                                                                        familyId:token.familyId
                                                                                          target:nil
                                                                                   scopeMatching:SubSet
                                                                                         context:context
                                                                                           error:error
                                                                                    outAuthority:nil];

    if (tokenInCache && [tokenInCache.refreshToken isEqualToString:token.refreshToken])
    {
        MSID_LOG_VERBOSE(context, @"Found refresh token in cache and it's the latest version, removing token");
        MSID_LOG_VERBOSE_PII(context, @"Found refresh token in cache and it's the latest version, removing token %@", token);

        return [self removeToken:tokenInCache context:context error:error];
    }

    return YES;
}

- (BOOL)removeAccessToken:(MSIDAccessToken *)token
                  context:(id<MSIDRequestContext>)context
                    error:(NSError **)error
{
    return [self removeToken:token context:context error:error];
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
                     requestParams:(MSIDRequestParameters *)requestParams
                          response:(MSIDTokenResponse *)response
                           context:(id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response request:requestParams];

    if (!accessToken)
    {
        [self fillInternalErrorWithMessage:@"Response does not contain an access token" context:context error:error];
        return NO;
    }

    if (![self checkUserIdentifier:accessToken.uniqueUserId context:context error:error])
    {
        return NO;
    }

    return [self saveAccessToken:accessToken context:context error:error];
}

- (BOOL)saveIDTokenWithFactory:(MSIDOauth2Factory *)factory
                 requestParams:(MSIDRequestParameters *)requestParams
                      response:(MSIDTokenResponse *)response
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    MSIDIdToken *idToken = [factory idTokenFromResponse:response request:requestParams];

    if (idToken)
    {
        return [self saveToken:idToken context:context error:error];
    }

    return YES;
}

- (BOOL)saveRefreshTokenWithFactory:(MSIDOauth2Factory *)factory
                      requestParams:(MSIDRequestParameters *)requestParams
                           response:(MSIDTokenResponse *)response
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    MSIDRefreshToken *refreshToken = [factory refreshTokenFromResponse:response request:requestParams];

    if (!refreshToken)
    {
        return NO;
    }

    if (![NSString msidIsStringNilOrBlank:refreshToken.familyId])
    {
        MSID_LOG_VERBOSE(context, @"Saving family refresh token %@", _PII_NULLIFY(refreshToken.refreshToken));
        MSID_LOG_VERBOSE_PII(context, @"Saving family refresh token %@", refreshToken.refreshToken);

        if (![self saveToken:refreshToken context:context error:error])
        {
            return NO;
        }
    }

    refreshToken.familyId = nil;

    return [self saveToken:refreshToken context:context error:error];
}

- (BOOL)saveAccountWithFactory:(MSIDOauth2Factory *)factory
                 requestParams:(MSIDRequestParameters *)requestParams
                      response:(MSIDTokenResponse *)response
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    MSIDAccount *account = [factory accountFromResponse:response request:requestParams];

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
    query.uniqueUserId = accessToken.uniqueUserId;
    query.environment = accessToken.authority.msidHostWithPortIfNecessary;
    query.realm = accessToken.authority.msidTenant;
    query.clientId = accessToken.clientId;
    query.target = [accessToken.scopes msidToString];
    query.targetMatchingOptions = Intersect;
    query.credentialType = MSIDCredentialTypeAccessToken;

    BOOL result = [_accountCredentialCache removeCredetialsWithQuery:query context:context error:error];

    if (!result)
    {
        return NO;
    }

    return [self saveToken:accessToken
                   context:context
                     error:error];
}

// Retrieval
- (MSIDBaseToken *)getTokenWithType:(MSIDCredentialType)tokenType
                            account:(id<MSIDAccountIdentifiers>)account
                          authority:(NSURL *)authority
                           clientId:(NSString *)clientId
                           familyId:(NSString *)familyId
                             target:(NSString *)target
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
                       outAuthority:(NSURL **)outAuthority

{
    MSIDBaseToken *token = nil;

    // First try to look by the unique user identifier
    if (![NSString msidIsStringNilOrBlank:account.uniqueUserId])
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Finding token with user ID, clientId %@, authority %@", clientId, authority);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Finding token with user ID %@, clientId %@, authority %@", account.uniqueUserId, clientId, authority);

        token = [self getTokenWithAliasesByUniqueUserId:account.uniqueUserId
                                              tokenType:tokenType
                                              authority:authority
                                               clientId:clientId
                                               familyId:familyId
                                                 target:target
                                          scopeMatching:SubSet
                                                context:context
                                                  error:error
                                           outAuthority:outAuthority];
    }

    // If a refresh token wasn't found and legacy user ID is available, try to look by legacy user id
    if (!token && tokenType == MSIDCredentialTypeRefreshToken && ![NSString msidIsStringNilOrBlank:account.legacyUserId])
    {
        // Unless it's a refresh token, return whatever we already found
        MSID_LOG_VERBOSE(context, @"(Default accessor) Finding refresh token with legacy user ID, clientId %@, authority %@", clientId, authority);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Finding refresh token with legacy user ID %@, clientId %@, authority %@", account.legacyUserId, clientId, authority);

        token = [self getRefreshTokenByLegacyUserId:account.legacyUserId
                                          authority:authority
                                           clientId:clientId
                                            context:context
                                              error:error];
    }

    return token;
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

    if (result && token.credentialType == MSIDCredentialTypeRefreshToken)
    {
        [_accountCredentialCache saveWipeInfoWithContext:context error:nil];
    }

    [self stopCacheEvent:event withItem:token success:result context:context];
    return result;
}

- (NSMutableDictionary<NSString *, MSIDAccountCacheItem *> *)getAccountsPerUserIdForAliases:(NSArray<NSString *> *)environmentAliases
                                                                                    context:(id<MSIDRequestContext>)context
                                                                                      error:(NSError **)error
{
    MSIDDefaultAccountCacheQuery *accountsQuery = [MSIDDefaultAccountCacheQuery new];
    accountsQuery.accountType = MSIDAccountTypeAADV2;
    accountsQuery.environmentAliases = environmentAliases;

    NSArray<MSIDAccountCacheItem *> *resultAccounts = [_accountCredentialCache getAccountsWithQuery:accountsQuery context:context error:error];

    NSMutableDictionary<NSString *, MSIDAccountCacheItem *> *accountsPerUserId = [NSMutableDictionary dictionary];

    for (MSIDAccountCacheItem *accountCacheItem in resultAccounts)
    {
        if (accountCacheItem.uniqueUserId)
        {
            accountsPerUserId[accountCacheItem.uniqueUserId] = accountCacheItem;
        }
    }

    return accountsPerUserId;
}

#pragma mark - Private

- (MSIDBaseToken *)getTokenWithAliasesByUniqueUserId:(NSString *)uniqueUserId
                                           tokenType:(MSIDCredentialType)tokenType
                                           authority:(NSURL *)authority
                                            clientId:(NSString *)clientId
                                            familyId:(NSString *)familyId
                                              target:(NSString *)target
                                       scopeMatching:(MSIDComparisonOptions)matching
                                             context:(id<MSIDRequestContext>)context
                                               error:(NSError **)error
                                        outAuthority:(NSURL **)outAuthority
{
    if (![self checkUserIdentifier:uniqueUserId context:context error:error])
    {
        return nil;
    }

    if (!authority)
    {
        // TODO: This code should never be hit, because we now never have a case without authority
        // Check and remove
        MSIDBaseToken *token = [self getTokenByUniqueUserId:uniqueUserId
                                           inputEnvironment:nil
                                                inputTenant:nil
                                                   clientId:clientId
                                                   familyId:familyId
                                                     target:target
                                                  tokenType:tokenType
                                                    context:context
                                                      error:error
                                               outAuthority:outAuthority];

        return token;
    }

    NSArray<NSString *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForEnvironment:authority.msidHostWithPortIfNecessary];

    for (NSString *alias in aliases)
    {
        MSIDBaseToken *token = [self getTokenByUniqueUserId:uniqueUserId
                                           inputEnvironment:alias
                                                inputTenant:authority.msidTenant
                                                   clientId:clientId
                                                   familyId:familyId
                                                     target:target
                                                  tokenType:tokenType
                                                    context:context
                                                      error:error
                                               outAuthority:nil];

        if (token)
        {
            return token;
        }
    }
    
    return nil;
}

- (MSIDBaseToken *)getTokenByUniqueUserId:(NSString *)uniqueUserId
                         inputEnvironment:(NSString *)environment
                              inputTenant:(NSString *)tenant
                                 clientId:(NSString *)clientId
                                 familyId:(NSString *)familyId
                                   target:(NSString *)target
                                tokenType:(MSIDCredentialType)tokenType
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
                             outAuthority:(NSURL **)outAuthority
{
    MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for token with alias %@, tenant %@, clientId %@, scopes %@", environment, tenant, clientId, target);
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Looking for token with alias %@, tenant %@, clientId %@, scopes %@, userId %@", environment, tenant, clientId, target, uniqueUserId);

    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    NSError *cacheError = nil;

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.uniqueUserId = uniqueUserId;
    query.environment = environment;
    query.realm = tenant;
    query.clientId = clientId;
    query.familyId = familyId;
    query.target = target;
    query.targetMatchingOptions = SubSet;
    query.credentialType = tokenType;
    query.matchAnyCredentialType = NO;

    NSArray<MSIDCredentialCacheItem *> *cacheItems = [_accountCredentialCache getCredentialsWithQuery:query legacyUserId:nil context:context error:error];

    if (cacheError)
    {
        if (error) *error = cacheError;
        return nil;
    }

    if (![cacheItems count])
    {
        [self stopTelemetryLookupEvent:event tokenType:tokenType withToken:nil success:NO context:context];
        return nil;
    }

    NSURL *authority = [NSURL msidURLWithEnvironment:environment tenant:tenant];

    // TODO: This code should never be hit, because we now never have a case without authority
    // Check and remove
    if (!environment || !tenant)
    {
        environment = cacheItems[0].environment;
        tenant = cacheItems[0].realm;

        authority = [NSURL msidURLWithEnvironment:environment tenant:tenant];

        NSArray<NSString *> *environmentAliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForEnvironment:environment];

        for (MSIDCredentialCacheItem *cacheItem in cacheItems)
        {
            if (![cacheItem.realm isEqualToString:tenant]
                || ![cacheItem.environment msidIsEquivalentWithAnyAlias:environmentAliases])
            {
                if (error)
                {
                    *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorAmbiguousAuthority, @"Found multiple access tokens, which token to return is ambiguous! Please pass in authority if not provided.", nil, nil, nil, context.correlationId, nil);
                }

                [self stopTelemetryLookupEvent:event tokenType:tokenType withToken:nil success:NO context:context];

                return nil;
            }
        }

        if (outAuthority)
        {
            *outAuthority = authority;
        }
    }

    MSIDBaseToken *resultToken = [cacheItems[0] tokenWithType:tokenType];
    resultToken.storageAuthority = resultToken.authority;
    resultToken.authority = authority;

    [self stopTelemetryLookupEvent:event tokenType:tokenType withToken:resultToken success:YES context:context];
    return resultToken;
}

- (MSIDBaseToken *)getRefreshTokenByLegacyUserId:(NSString *)legacyUserId
                                       authority:(NSURL *)authority
                                        clientId:(NSString *)clientId
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    NSArray<NSURL *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authority];

    for (NSURL *alias in aliases)
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for token with alias %@, clientId %@", alias, clientId);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Looking for token with alias %@, clientId %@, legacy userId %@", alias, clientId, legacyUserId);

        MSIDDefaultCredentialCacheQuery *idTokensQuery = [MSIDDefaultCredentialCacheQuery new];
        idTokensQuery.environment = alias.msidHostWithPortIfNecessary;
        idTokensQuery.clientId = clientId;
        idTokensQuery.credentialType = MSIDCredentialTypeIDToken;

        NSArray<MSIDCredentialCacheItem *> *matchedIdTokens = [_accountCredentialCache getCredentialsWithQuery:idTokensQuery
                                                                                             legacyUserId:legacyUserId
                                                                                                  context:context
                                                                                                    error:error];

        if ([matchedIdTokens count])
        {
            NSString *uniqueUserId = matchedIdTokens[0].uniqueUserId;

            MSIDDefaultCredentialCacheQuery *rtQuery = [MSIDDefaultCredentialCacheQuery new];
            rtQuery.uniqueUserId = uniqueUserId;
            rtQuery.environment = alias.msidHostWithPortIfNecessary;
            rtQuery.clientId = clientId;
            rtQuery.credentialType = MSIDCredentialTypeRefreshToken;

            NSArray<MSIDCredentialCacheItem *> *rtCacheItems = [_accountCredentialCache getCredentialsWithQuery:rtQuery
                                                                                              legacyUserId:nil
                                                                                                   context:context
                                                                                                     error:error];

            if ([rtCacheItems count])
            {
                MSIDCredentialCacheItem *resultItem = rtCacheItems[0];
                MSIDBaseToken *resultToken = [resultItem tokenWithType:MSIDCredentialTypeRefreshToken];
                resultToken.storageAuthority = resultToken.authority;
                resultToken.authority = authority;

                [self stopTelemetryLookupEvent:event tokenType:MSIDCredentialTypeRefreshToken withToken:resultToken success:YES context:context];

                return resultToken;
            }
        }
    }

    [self stopTelemetryLookupEvent:event tokenType:MSIDCredentialTypeRefreshToken withToken:nil success:NO context:context];

    return nil;
}

- (BOOL)saveToken:(MSIDBaseToken *)token
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    if (![self checkUserIdentifier:token.uniqueUserId context:context error:error])
    {
        return NO;
    }

    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE context:context];

    MSIDCredentialCacheItem *cacheItem = token.tokenCacheItem;
    cacheItem.environment = [[MSIDAadAuthorityCache sharedInstance] cacheEnvironmentForEnvironment:cacheItem.environment context:context];

    BOOL result = [_accountCredentialCache saveCredential:cacheItem context:context error:error];
    
    [self stopCacheEvent:event withItem:token success:result context:context];
    
    return result;
}

- (BOOL)saveAccount:(MSIDAccount *)account
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (![self checkUserIdentifier:account.uniqueUserId context:context error:error])
    {
        return NO;
    }

    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE context:context];

    MSIDAccountCacheItem *cacheItem = account.accountCacheItem;
    cacheItem.environment = [[MSIDAadAuthorityCache sharedInstance] cacheEnvironmentForEnvironment:cacheItem.environment context:context];

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
    if (!success && tokenType == MSIDCredentialTypeRefreshToken)
    {
        [event setWipeData:[_accountCredentialCache wipeInfoWithContext:context error:nil]];
    }
    
    [self stopCacheEvent:event
                withItem:token
                 success:success
                context:context];
}

@end
