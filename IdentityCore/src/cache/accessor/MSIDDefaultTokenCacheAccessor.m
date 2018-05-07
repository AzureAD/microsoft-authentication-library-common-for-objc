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
#import "MSIDAADV2IdTokenClaims.h"
#import "MSIDRequestParameters.h"
#import "NSDate+MSIDExtensions.h"
#import "MSIDTokenFilteringHelper.h"
#import "MSIDOauth2Factory.h"
#import "MSIDAccountCredentialCache.h"
#import "NSOrderedSet+MSIDExtensions.h"

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

- (BOOL)saveAccessTokenWithFactory:(MSIDOauth2Factory *)factory
                     requestParams:(MSIDRequestParameters *)requestParams
                          response:(MSIDTokenResponse *)response
                           context:(id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    // TODO: telemetry?
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

    if (refreshToken)
    {
        return [self saveRefreshToken:refreshToken context:context error:error];
    }

    return YES;
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
        return [_accountCredentialCache saveAccount:account.accountCacheItem context:context error:error];
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
    BOOL result = [_accountCredentialCache removeCredentialsWithUniqueUserId:accessToken.uniqueUserId
                                                                 environment:accessToken.authority.msidHostWithPortIfNecessary
                                                                       realm:accessToken.authority.msidTenant
                                                                    clientId:accessToken.clientId
                                                                      target:[accessToken.scopes msidToString]
                                                              targetMatching:Intersect
                                                                        type:MSIDTokenTypeAccessToken
                                                                     context:context
                                                                       error:error];

    if (!result)
    {
        return NO;
    }

    return [self saveToken:accessToken
                   context:context
                     error:error];
}

// Retrieval
- (MSIDBaseToken *)getTokenWithType:(MSIDTokenType)tokenType
                    userIdentifiers:(id<MSIDUserIdentifiers>)userIdentifiers
                      requestParams:(MSIDRequestParameters *)parameters
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    // TODO: optimize telemetry here
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];

    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];

    MSIDBaseToken *token = nil;

    // First try to look by the unique user identifier
    if (![NSString msidIsStringNilOrBlank:userIdentifiers.uniqueUserId])
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Finding token with user ID, clientId %@, authority %@", parameters.clientId, parameters.authority);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Finding token with user ID %@, clientId %@, authority %@", userIdentifiers.uniqueUserId, parameters.clientId, parameters.authority);

        token = [self getTokenByUniqueUserId:userIdentifiers.uniqueUserId
                                   tokenType:tokenType
                               requestParams:parameters
                               scopeMatching:SubSet
                                     context:context
                                       error:error];
    }

    if (tokenType != MSIDTokenTypeRefreshToken)
    {
        // Unless it's a refresh token, return whatever we already found
        [self stopTelemetryLookupEvent:event tokenType:tokenType withToken:token success:token != nil context:context];
        return token;
    }

    // If a refresh token wasn't found and legacy user ID is available, try to look by legacy user id
    if (!token && ![NSString msidIsStringNilOrBlank:userIdentifiers.legacyUserId])
    {
        MSID_LOG_VERBOSE(context, @"(Default accessor) Finding refresh token with legacy user ID, clientId %@, authority %@", parameters.clientId, parameters.authority);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Finding refresh token with legacy user ID %@, clientId %@, authority %@", userIdentifiers.legacyUserId, parameters.clientId, parameters.authority);

        // TODO: match environment only here?
        token = [self getTokenByLegacyUserId:userIdentifiers.legacyUserId
                                   tokenType:MSIDTokenTypeRefreshToken
                                   authority:parameters.authority
                                    clientId:parameters.clientId
                                      scopes:nil
                                     context:context
                                       error:error];
    }

    [self stopTelemetryLookupEvent:event tokenType:tokenType withToken:token success:token != nil context:context];
    return token;
}

- (MSIDBaseToken *)getUpdatedToken:(MSIDBaseToken *)token
                           context:(id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;

    return [self getTokenByUniqueUserId:cacheItem.uniqueUserId
                         inputAuthority:cacheItem.authority
                               clientId:cacheItem.clientId
                                 target:cacheItem.target
                              tokenType:cacheItem.tokenType
                                context:context
                                  error:error
                           outAuthority:nil];
}

- (NSArray<MSIDBaseToken *> *)allTokensWithContext:(id<MSIDRequestContext>)context
                                             error:(NSError **)error
{
    NSArray<MSIDTokenCacheItem *> *cacheItems = [_accountCredentialCache getAllItemsWithContext:context error:error];

    NSMutableArray<MSIDBaseToken *> *tokens = [NSMutableArray new];

    for (MSIDTokenCacheItem *item in cacheItems)
    {
        MSIDBaseToken *token = [item tokenWithType:item.tokenType];
        if (token)
        {
            [tokens addObject:token];
        }
    }

    return tokens;
}

- (NSArray<MSIDBaseToken *> *)getAllTokensOfType:(MSIDTokenType)tokenType
                                    withClientId:(NSString *)clientId
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    NSArray<MSIDTokenCacheItem *> *cacheItems = [_accountCredentialCache getAllCredentialsWithType:tokenType context:context error:error];

    BOOL (^filterBlock)(MSIDTokenCacheItem *tokenCacheItem) = ^BOOL(MSIDTokenCacheItem *token) {

        return [token.clientId isEqualToString:clientId];

    };

    return [MSIDTokenFilteringHelper filterTokenCacheItems:cacheItems
                                                 tokenType:tokenType
                                               returnFirst:NO
                                                  filterBy:filterBlock];
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

    // TODO: should remove with storage authority
    return [_accountCredentialCache removeCredential:token.tokenCacheItem context:context error:error];
}

- (BOOL)removeAccount:(MSIDAccount *)account
              context:(id<MSIDRequestContext>)context
                error:(NSError **)error
{
    return [_accountCredentialCache removeAccount:account.accountCacheItem context:context error:error];
}

- (BOOL)removeAllTokensForUser:(id<MSIDUserIdentifiers>)userIdentifiers
                   environment:(NSString *)environment
                      clientId:(NSString *)clientId
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    return [_accountCredentialCache removeCredentialsWithUniqueUserId:userIdentifiers.uniqueUserId
                                                          environment:environment
                                                                realm:nil
                                                             clientId:clientId
                                                               target:nil
                                                       targetMatching:Any
                                                                 type:MSIDTokenTypeOther // TODO: type is other?
                                                              context:context
                                                                error:error];
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
                                tokenType:(MSIDTokenType)tokenType
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
                                             inputAuthority:parameters.authority
                                                   clientId:parameters.clientId
                                                     target:parameters.target
                                                  tokenType:tokenType
                                                    context:context
                                                      error:error
                                               outAuthority:&outAuthority];

        parameters.authority = outAuthority;
        return token;
    }

    NSArray<NSURL *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:parameters.authority];

    for (NSURL *alias in aliases)
    {
        MSIDBaseToken *token = [self getTokenByUniqueUserId:uniqueUserId
                                             inputAuthority:alias
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
                           inputAuthority:(NSURL *)authority
                                 clientId:(NSString *)clientId
                                   target:(NSString *)target
                                tokenType:(MSIDTokenType)tokenType
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
                             outAuthority:(NSURL **)outAuthority
{
    MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for token with alias %@, clientId %@, scopes %@", authority, clientId, target);
    MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Looking for token with alias %@, clientId %@, scopes %@, userId %@", authority, clientId, target, uniqueUserId);

    NSError *cacheError = nil;

    NSArray<MSIDTokenCacheItem *> *cacheItems = [_accountCredentialCache getCredentialsWithUniqueUserId:uniqueUserId
                                                                                            environment:authority.msidHostWithPortIfNecessary
                                                                                                  realm:authority.msidTenant
                                                                                               clientId:clientId
                                                                                                 target:target
                                                                                         targetMatching:SubSet
                                                                                                   type:tokenType
                                                                                                context:context
                                                                                                  error:&cacheError];

    if (cacheError)
    {
        if (error) *error = cacheError;
        return nil;
    }

    if ([cacheItems count])
    {
        if (!authority)
        {
            authority = cacheItems[0].authority;

            NSArray<NSURL *> *tokenAliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authority];

            for (MSIDTokenCacheItem *cacheItem in cacheItems)
            {
                if (![cacheItem.authority msidIsEquivalentWithAnyAlias:tokenAliases])
                {
                    if (error)
                    {
                        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorAmbiguousAuthority, @"Found multiple access tokens, which token to return is ambiguous! Please pass in authority if not provided.", nil, nil, nil, context.correlationId, nil);
                    }

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

        return resultToken;
    }

    return nil;
}

// TODO: can we optimize this logic? Can account credential cache match by legacy user ID?
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
        MSID_LOG_VERBOSE(context, @"(Default accessor) Looking for token with alias %@, clientId %@, scopes %@", alias, clientId, scopes);
        MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Looking for token with alias %@, clientId %@, scopes %@, legacy userId %@", alias, clientId, scopes, legacyUserId);

        NSError *cacheError = nil;

        NSArray<MSIDTokenCacheItem *> *cacheItems = [_accountCredentialCache getCredentialsWithUniqueUserId:nil
                                                                                                environment:alias.msidHostWithPortIfNecessary
                                                                                                      realm:alias.msidTenant
                                                                                                   clientId:clientId
                                                                                                     target:[scopes msidToString]
                                                                                             targetMatching:Any
                                                                                                       type:tokenType
                                                                                                    context:context
                                                                                                      error:&cacheError];
        
        if (cacheError)
        {
            if (error) *error = cacheError;
            return nil;
        }
        
        NSArray<MSIDBaseToken *> *matchedTokens = [MSIDTokenFilteringHelper filterRefreshTokenCacheItems:cacheItems
                                                                                            legacyUserId:legacyUserId
                                                                                             environment:alias.msidHostWithPortIfNecessary // TODO: environment not necessary
                                                                                                 context:context];
        
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

- (BOOL)saveToken:(MSIDBaseToken *)token
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    if (![self checkUserIdentifier:token.uniqueUserId context:context error:error])
    {
        return NO;
    }
    
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                           context:context];

    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    cacheItem.authority = [[MSIDAadAuthorityCache sharedInstance] cacheUrlForAuthority:cacheItem.authority context:context];

    BOOL result = [_accountCredentialCache saveCredential:cacheItem context:context error:error];
    
    [self stopTelemetryEvent:event withItem:token success:result context:context];
    
    return result;
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
