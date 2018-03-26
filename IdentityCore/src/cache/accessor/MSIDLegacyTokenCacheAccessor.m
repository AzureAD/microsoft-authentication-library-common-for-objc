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
#import "MSIDAccount.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDLegacyTokenCacheKey.h"
#import "MSIDRequestParameters.h"
#import "MSIDTokenResponse.h"
#import "NSDate+MSIDExtensions.h"
#import "MSIDTokenFilteringHelper.h"
#import "MSIDAuthority.h"

@interface MSIDLegacyTokenCacheAccessor()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDKeyedArchiverSerializer *_serializer;
}

@end

@implementation MSIDLegacyTokenCacheAccessor

#pragma mark - Init

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
{
    self = [super init];
    
    if (self)
    {
        _dataSource = dataSource;
        _serializer = [[MSIDKeyedArchiverSerializer alloc] init];
    }
    
    return self;
}

#pragma mark - Input validation

- (BOOL)checkUserIdentifier:(MSIDAccount *)account
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    if (!account.legacyUserId)
    {
        MSID_LOG_ERROR(context, @"(Legacy accessor) Legacy user ID is expected for legacy accessor, but not provided");
        MSID_LOG_ERROR_PII(context, @"(Legacy accessor) Legacy user ID is expected for legacy accessor, but not provided with account %@", account);
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Legacy user ID is needed for legacy token cache accessor", nil, nil, nil, context.correlationId, nil);
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
    if (response.isMultiResource)
    {
        // Save access token item in the primary format
        MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenResponse:response
                                                                              request:requestParams];
        
        MSID_LOG_INFO(context, @"(Legacy accessor) Saving multi resource tokens in legacy accessor");
        MSID_LOG_INFO_PII(context, @"(Legacy accessor) Saving multi resource tokens in legacy accessor %@", accessToken);

        if (!accessToken)
        {
            MSID_LOG_ERROR(context, @"Couldn't initialize access token entry. Not updating cache");
            
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Tried to save access token, but no access token returned", nil, nil, nil, context.correlationId, nil);
            }
            
            return NO;
        }
        
        BOOL result = [self saveToken:accessToken
                              account:account
                              context:context
                                error:error];
        
        if (!result) return NO;
    }
    else
    {
        MSIDLegacySingleResourceToken *legacyToken = [[MSIDLegacySingleResourceToken alloc] initWithTokenResponse:response
                                                                                                          request:requestParams];
        
        if (!legacyToken)
        {
            MSID_LOG_ERROR(context, @"Couldn't initialize ADFS token entry. Not updating cache");
            
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Tried to save ADFS token, but no ADFS token returned", nil, nil, nil, context.correlationId, nil);
            }
            
            return NO;
        }
        
        MSID_LOG_INFO(context, @"(Legacy accessor) Saving single resource tokens in legacy accessor");
        MSID_LOG_INFO_PII(context, @"(Legacy accessor) Saving single resource tokens in legacy accessor %@", legacyToken);
        
        account.legacyUserId = @"";
        
        // Save token for legacy single resource token
        return [self saveToken:legacyToken
                       account:account
                       context:context
                         error:error];
    }
    
    return YES;
}

- (BOOL)saveRefreshToken:(MSIDRefreshToken *)refreshToken
                 account:(MSIDAccount *)account
                 context:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Saving refresh token in legacy accessor with clientID %@, authority %@", refreshToken.clientId, refreshToken.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Saving refresh token in legacy accessor with clientID %@, authority %@, legacy userID %@", refreshToken.clientId, refreshToken.authority, account.legacyUserId);
    
    return [self saveToken:refreshToken
                   account:account
                   context:context
                     error:error];
}

- (BOOL)saveToken:(MSIDBaseToken *)token
          account:(MSIDAccount *)account
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                           context:context];
    
    NSURL *newAuthority = [[MSIDAadAuthorityCache sharedInstance] cacheUrlForAuthority:token.authority context:context];
    
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Saving token %@ with authority %@", [MSIDTokenTypeHelpers tokenTypeAsString:token.tokenType], newAuthority);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Saving token %@ for account %@ with authority %@", token, account, newAuthority);
    
    // The authority used to retrieve the item over the network can differ from the preferred authority used to
    // cache the item. As it would be awkward to cache an item using an authority other then the one we store
    // it with we switch it out before saving it to cache.
    token.authority = newAuthority;
    
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey keyWithAuthority:newAuthority
                                                                    clientId:cacheItem.clientId
                                                                    resource:cacheItem.target
                                                                legacyUserId:account.legacyUserId];
    
    BOOL result = [_dataSource saveToken:cacheItem
                                     key:key
                              serializer:_serializer
                                 context:context
                                   error:error];
    
    [self stopTelemetryEvent:event withItem:token success:result context:context];
    
    return result;
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
    
    // Do custom handling for refresh tokens, because they need fallback logic with different identifiers
    if (tokenType == MSIDTokenTypeRefreshToken)
    {
        token = [self getRefreshTokenWithAccount:account
                                   requestParams:parameters
                                         context:context
                                           error:error];
    }
    else
    {
        token = [self getTokenByLegacyUserId:account.legacyUserId
                                   tokenType:tokenType
                                   authority:parameters.authority
                                    clientId:parameters.clientId
                                    resource:parameters.resource
                                     context:context
                                       error:error];
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
    
    return [self getTokenByLegacyUserId:account.legacyUserId
                              tokenType:cacheItem.tokenType
                              authority:cacheItem.authority
                               clientId:cacheItem.clientId
                               resource:cacheItem.target
                                context:context
                                  error:error];
}

- (BOOL)removeToken:(MSIDBaseToken *)token
            account:(MSIDAccount *)account
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (!token)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Token not provided", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Removing token with clientId %@, authority %@", token.clientId, token.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Removing token %@ with account %@", token, account);
    
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
 
    NSURL *authority = token.storageAuthority ? token.storageAuthority : token.authority;
    
    MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey keyWithAuthority:authority
                                                                    clientId:cacheItem.clientId
                                                                    resource:cacheItem.target
                                                                legacyUserId:account.legacyUserId];
    
    BOOL result = [_dataSource removeItemsWithKey:key
                                          context:context
                                            error:error];

    if (result && token.tokenType == MSIDTokenTypeRefreshToken)
    {
        [_dataSource saveWipeInfoWithContext:context error:nil];
    }
    return result;
}

- (NSArray *)getAllTokensOfType:(MSIDTokenType)tokenType
                   withClientId:(NSString *)clientId
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Get all tokens of type %@ with clientId %@", [MSIDTokenTypeHelpers tokenTypeAsString:tokenType], clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Get all tokens of type %@ with clientId %@", [MSIDTokenTypeHelpers tokenTypeAsString:tokenType], clientId);
    
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    NSArray<MSIDTokenCacheItem *> *legacyCacheItems = [_dataSource tokensWithKey:[MSIDLegacyTokenCacheKey keyForAllItems]
                                                                      serializer:_serializer
                                                                         context:context
                                                                           error:error];
    
    if (!legacyCacheItems)
    {
        [self stopTelemetryEvent:event withItem:nil success:NO context:context];
        return nil;
    }
    
    NSArray *results = [MSIDTokenFilteringHelper filterTokenCacheItems:legacyCacheItems
                                                             tokenType:tokenType
                                                           returnFirst:NO
                                                              filterBy:^BOOL(MSIDTokenCacheItem *cacheItem) {
                                                                  
                                                                  return (cacheItem.tokenType == tokenType
                                                                          && [cacheItem.clientId isEqualToString:clientId]);
                                                              }];
    
    [self stopTelemetryLookupEvent:event tokenType:tokenType withToken:nil success:(results.count > 0) context:context];
    
    return results;
}

- (NSArray<MSIDAccount *> *)getAllAccountsWithClientId:(NSString *)clientId
                                               context:(id<MSIDRequestContext>)context
                                                 error:(NSError **)error
{
    // TODO: A
    return nil;
}

#pragma mark - Private

- (MSIDBaseToken *)getRefreshTokenWithAccount:(MSIDAccount *)account
                                requestParams:(MSIDRequestParameters *)parameters
                                      context:(id<MSIDRequestContext>)context
                                        error:(NSError **)error
{
    if ([MSIDAuthority isConsumerInstanceURL:parameters.authority])
    {
        return nil;
    }
    
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Finding refresh token with legacy user ID, clientId %@, authority %@", parameters.clientId, parameters.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Finding refresh token with legacy user ID %@, clientId %@, authority %@", account.legacyUserId, parameters.clientId, parameters.authority);
    
    MSIDBaseToken *resultToken = [self getTokenByLegacyUserId:account.legacyUserId
                                                    tokenType:MSIDTokenTypeRefreshToken
                                                    authority:parameters.authority
                                                     clientId:parameters.clientId
                                                     resource:nil
                                                      context:context
                                                        error:error];
    
    // If no legacy user ID available, or no token found by legacy user ID, try to look by unique user ID
    if (!resultToken
        && ![NSString msidIsStringNilOrBlank:account.uniqueUserId])
    {
        NSURL *authority = [MSIDAuthority universalAuthorityURL:parameters.authority];
        
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Finding refresh token with new user ID, clientId %@, authority %@", parameters.clientId, authority);
        MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Finding refresh token with new user ID %@, clientId %@, authority %@", account.uniqueUserId, parameters.clientId, authority);
        
        return [self getTokenByUniqueUserId:account.uniqueUserId
                                  tokenType:MSIDTokenTypeRefreshToken
                                  authority:authority
                                   clientId:parameters.clientId
                                   resource:nil
                                    context:context
                                      error:error];
    }
    
    return resultToken;
}

- (MSIDBaseToken *)getTokenByLegacyUserId:(NSString *)legacyUserId
                                tokenType:(MSIDTokenType)tokenType
                                authority:(NSURL *)authority
                                 clientId:(NSString *)clientId
                                 resource:(NSString *)resource
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    NSArray<NSURL *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authority];
    
    for (NSURL *alias in aliases)
    {
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Looking for token with alias %@, clientId %@, resource %@", alias, clientId, resource);
        MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Looking for token with alias %@, clientId %@, resource %@, legacy userId %@", alias, clientId, resource, legacyUserId);
        
        MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey queryWithAuthority:alias
                                                                          clientId:clientId
                                                                          resource:resource
                                                                      legacyUserId:legacyUserId];
        
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
            MSIDBaseToken *token = [cacheItem tokenWithType:tokenType];
            token.storageAuthority = token.authority;
            token.authority = authority;
            return token;
        }
    }
    
    return nil;
}

- (MSIDBaseToken *)getTokenByUniqueUserId:(NSString *)uniqueUserId
                                tokenType:(MSIDTokenType)tokenType
                                authority:(NSURL *)authority
                                 clientId:(NSString *)clientId
                                 resource:(NSString *)resource
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    NSArray<NSURL *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authority];
    
    for (NSURL *alias in aliases)
    {
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Looking for token with alias %@, clientId %@, resource %@", alias, clientId, resource);
        MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Looking for token with alias %@, clientId %@, resource %@, unique userId %@", alias, clientId, resource, uniqueUserId);
        
        MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey queryWithAuthority:alias
                                                                          clientId:clientId
                                                                          resource:resource
                                                                      legacyUserId:nil];
        
        if (!key)
        {
            return nil;
        }
        
        NSError *cacheError = nil;
        NSArray *tokens = [_dataSource tokensWithKey:key serializer:_serializer context:context error:&cacheError];
        
        if (cacheError)
        {
            if (error) *error = cacheError;
            return nil;
        }
        
        BOOL (^filterBlock)(MSIDTokenCacheItem *cacheItem) = ^BOOL(MSIDTokenCacheItem *cacheItem) {
            return [cacheItem.uniqueUserId isEqualToString:uniqueUserId];
        };
        
        NSArray *matchedTokens = [MSIDTokenFilteringHelper filterTokenCacheItems:tokens
                                                                       tokenType:tokenType
                                                                     returnFirst:YES
                                                                        filterBy:filterBlock];
        
        if ([matchedTokens count])
        {
            MSIDBaseToken *token = matchedTokens[0];
            token.storageAuthority = token.authority;
            token.authority = authority;
            return token;
        }
    }
    
    return nil;
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
