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

@interface MSIDDefaultTokenCacheAccessor()
{
    MSIDAccountCredentialCache *_accountCredentialCache;
}

@end

@implementation MSIDDefaultTokenCacheAccessor

#pragma mark - Init

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
{
    self = [super init];
    
    if (self)
    {
        _accountCredentialCache = [[MSIDAccountCredentialCache alloc] initWithDataSource:dataSource];
    }
    
    return self;
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

#pragma mark - MSIDSharedCacheAccessor

- (BOOL)saveTokensWithFactory:(MSIDOauth2Factory *)factory
                requestParams:(MSIDRequestParameters *)requestParams
                     response:(MSIDTokenResponse *)response
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    BOOL result = [self saveAccessTokenWithFactory:factory requestParams:requestParams response:response context:context error:error];

    if (!result) return result;

    result &= [self saveIDTokenWithFactory:factory requestParams:requestParams response:response context:context error:error];
    result &= [self saveRefreshTokenWithFactory:factory requestParams:requestParams response:response context:context error:error];
    result &= [self saveAccountWithFactory:factory requestParams:requestParams response:response context:context error:error];

    return result;
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
    return result;
}

- (BOOL)saveAccessTokenWithFactory:(MSIDOauth2Factory *)factory
                     requestParams:(MSIDRequestParameters *)requestParams
                          response:(MSIDTokenResponse *)response
                           context:(id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response request:requestParams];

    if (!accessToken)
    {
        [self fillInternalErrorWithMessage:@"Tried to save access token, but no access token returned" context:context error:error];
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

    BOOL result = [self saveRefreshToken:refreshToken context:context error:error];

    if (!result || [NSString msidIsStringNilOrBlank:refreshToken.familyId])
    {
        // If saving failed or it's not an FRT, we're done
        return result;
    }

    MSID_LOG_VERBOSE(context, @"Saving family refresh token %@", _PII_NULLIFY(refreshToken.refreshToken));
    MSID_LOG_VERBOSE_PII(context, @"Saving family refresh token %@", refreshToken.refreshToken);

    // If it's an FRT, save it separately and update the clientId of the token item
    MSIDRefreshToken *familyRefreshToken = [refreshToken copy];
    familyRefreshToken.clientId = [MSIDCacheKey familyClientId:refreshToken.familyId];

    return [self saveRefreshToken:familyRefreshToken context:context error:error];
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

- (BOOL)saveRefreshToken:(MSIDRefreshToken *)refreshToken
                 context:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    if (![self checkUserIdentifier:refreshToken.uniqueUserId context:context error:error])
    {
        return NO;
    }

    return [self saveToken:refreshToken context:context error:error];
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
                      requestParams:(MSIDRequestParameters *)parameters
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    MSIDBaseToken *token = nil;

    // First try to look by the unique user identifier
    if (![NSString msidIsStringNilOrBlank:account.uniqueUserId])
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Finding token with user ID, clientId %@, authority %@", parameters.clientId, parameters.authority);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Finding token with user ID %@, clientId %@, authority %@", account.uniqueUserId, parameters.clientId, parameters.authority);

        token = [self getTokenByUniqueUserId:account.uniqueUserId
                                   tokenType:tokenType
                               requestParams:parameters
                               scopeMatching:SubSet
                                     context:context
                                       error:error];
    }

    if (tokenType != MSIDCredentialTypeRefreshToken)
    {
        // Unless it's a refresh token, return whatever we already found
        return token;
    }

    // If a refresh token wasn't found and legacy user ID is available, try to look by legacy user id
    if (!token && ![NSString msidIsStringNilOrBlank:account.legacyUserId])
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Finding refresh token with legacy user ID, clientId %@, authority %@", parameters.clientId, parameters.authority);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Finding refresh token with legacy user ID %@, clientId %@, authority %@", account.legacyUserId, parameters.clientId, parameters.authority);

        token = [self getRefreshTokenByLegacyUserId:account.legacyUserId
                                          authority:parameters.authority
                                           clientId:parameters.clientId
                                            context:context
                                              error:error];
    }

    return token;
}

- (MSIDBaseToken *)getUpdatedToken:(MSIDBaseToken *)token
                           context:(id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    MSIDCredentialCacheItem *cacheItem = token.tokenCacheItem;

    return [self getTokenByUniqueUserId:cacheItem.uniqueUserId
                       inputEnvironment:cacheItem.environment
                            inputTenant:cacheItem.realm
                               clientId:cacheItem.clientId
                                 target:cacheItem.target
                              tokenType:cacheItem.credentialType
                                context:context
                                  error:error
                           outAuthority:nil];
}

- (NSArray<MSIDBaseToken *> *)allTokensWithContext:(id<MSIDRequestContext>)context
                                             error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    NSArray<MSIDCredentialCacheItem *> *cacheItems = [_accountCredentialCache getAllItemsWithContext:context error:error];
    NSArray<MSIDBaseToken *> *tokens = [self tokensFromCacheItems:cacheItems];

    [self stopCacheEvent:event withItem:nil success:[cacheItems count] > 0 context:context];

    return tokens;
}

- (NSArray<MSIDBaseToken *> *)getAllTokensOfType:(MSIDCredentialType)tokenType
                                    withClientId:(NSString *)clientId
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.clientId = clientId;
    query.credentialType = tokenType;

    NSArray<MSIDCredentialCacheItem *> *cacheItems = [_accountCredentialCache getCredentialsWithQuery:query legacyUserId:nil context:context error:error];
    NSArray<MSIDBaseToken *> *tokens = [self tokensFromCacheItems:cacheItems];

    [self stopCacheEvent:event withItem:nil success:[tokens count] > 0 context:context];
    return tokens;
}

// Removal
- (BOOL)removeToken:(MSIDBaseToken *)token
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (!token)
    {
        [self fillInternalErrorWithMessage:@"Token not provided, cannot remove" context:context error:error];
        return NO;
    }

    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];

    // TODO: should remove with storage authority
    BOOL result = [_accountCredentialCache removeCredential:token.tokenCacheItem context:context error:error];
    [self stopCacheEvent:event withItem:token success:result context:context];
    return result;
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
    // TODO: should remove with storage authority
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

/*
 It is supposed to be used in test apps only.
 */
- (BOOL)clearWithContext:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    return [_accountCredentialCache clearWithContext:context error:error];
}

#pragma mark - Private

- (MSIDBaseToken *)getTokenByUniqueUserId:(NSString *)uniqueUserId
                                tokenType:(MSIDCredentialType)tokenType
                            requestParams:(MSIDRequestParameters *)parameters
                            scopeMatching:(MSIDComparisonOptions)matching
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    if (![self checkUserIdentifier:uniqueUserId context:context error:error])
    {
        return nil;
    }

    if (!parameters.authority)
    {
        NSURL *outAuthority = nil;

        MSIDBaseToken *token = [self getTokenByUniqueUserId:uniqueUserId
                                           inputEnvironment:nil
                                                inputTenant:nil
                                                   clientId:parameters.clientId
                                                     target:parameters.target
                                                  tokenType:tokenType
                                                    context:context
                                                      error:error
                                               outAuthority:&outAuthority];

        parameters.authority = outAuthority;
        return token;
    }

    NSArray<NSString *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForEnvironment:parameters.authority.msidHostWithPortIfNecessary];

    for (NSString *alias in aliases)
    {
        MSIDBaseToken *token = [self getTokenByUniqueUserId:uniqueUserId
                                           inputEnvironment:alias
                                                inputTenant:parameters.authority.msidTenant
                                                   clientId:parameters.clientId
                                                     target:parameters.target
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

    if ([cacheItems count])
    {
        NSURL *authority = [NSURL msidURLWithEnvironment:environment tenant:tenant];

        // This code should never be hit, because we now never have a case without authority
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

    [self stopTelemetryLookupEvent:event tokenType:tokenType withToken:nil success:NO context:context];

    return nil;
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
    NSURL *cacheAuthority = [[MSIDAadAuthorityCache sharedInstance] cacheUrlForAuthority:[NSURL msidURLWithEnvironment:cacheItem.environment] context:context];
    cacheItem.environment = cacheAuthority.msidHostWithPortIfNecessary; // TODO: this is a hack

    BOOL result = [_accountCredentialCache saveAccount:cacheItem context:context error:error];

    [self stopCacheEvent:event withItem:nil success:result context:context];

    return result;
}

- (NSArray<MSIDBaseToken *> *)tokensFromCacheItems:(NSArray<MSIDCredentialCacheItem *> *)cacheItems
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
