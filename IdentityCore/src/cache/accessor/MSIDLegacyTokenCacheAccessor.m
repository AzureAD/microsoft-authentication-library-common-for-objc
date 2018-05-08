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
#import "MSIDOauth2Factory.h"
#import "MSIDLegacyTokenCacheQuery.h"

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
    if (response.isMultiResource)
    {
        BOOL result = [self saveAccessTokenWithFactory:factory requestParams:requestParams response:response context:context error:error];

        if (!result) { return result; }

        return [self saveRefreshTokenWithFactory:factory requestParams:requestParams response:response context:context error:error];
    }
    else
    {
        return [self saveLegacySingleResourceTokenWithFactory:factory requestParams:requestParams response:response context:context error:error];
    }
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

    MSID_LOG_INFO(context, @"(Legacy accessor) Saving access token in legacy accessor");
    MSID_LOG_INFO_PII(context, @"(Legacy accessor) Saving access token in legacy accessor %@", accessToken);

    return [self saveToken:accessToken userId:accessToken.legacyUserId context:context error:error];
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
        MSID_LOG_INFO(context, @"No refresh token returned in the token response, not updating cache");
        return YES;
    }

    MSID_LOG_INFO(context, @"(Legacy accessor) Saving multi resource refresh token in legacy accessor");
    MSID_LOG_INFO_PII(context, @"(Legacy accessor) Saving multi resource refresh token in legacy accessor %@", refreshToken);

    return [self saveToken:refreshToken userId:refreshToken.legacyUserId context:context error:error];
}

- (BOOL)saveLegacySingleResourceTokenWithFactory:(MSIDOauth2Factory *)factory
                                   requestParams:(MSIDRequestParameters *)requestParams
                                        response:(MSIDTokenResponse *)response
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    MSIDLegacySingleResourceToken *legacyToken = [factory legacyTokenFromResponse:response request:requestParams];

    if (!legacyToken)
    {
        [self fillInternalErrorWithMessage:@"Tried to save single resource token, but no access token returned" context:context error:error];
        return NO;
    }

    MSID_LOG_INFO(context, @"(Legacy accessor) Saving single resource tokens in legacy accessor");
    MSID_LOG_INFO_PII(context, @"(Legacy accessor) Saving single resource tokens in legacy accessor %@", legacyToken);

    // Save token for legacy single resource token
    return [self saveToken:legacyToken userId:legacyToken.legacyUserId context:context error:error];
}

- (BOOL)saveRefreshToken:(MSIDRefreshToken *)refreshToken
                 context:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    return [self saveToken:refreshToken userId:refreshToken.legacyUserId context:context error:error];
}

- (BOOL)saveAccessToken:(MSIDAccessToken *)accessToken
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error
{
    return [self saveToken:accessToken userId:accessToken.legacyUserId context:context error:error];
}

- (BOOL)saveToken:(MSIDBaseToken *)token
           userId:(NSString *)userId
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE context:context];
    
    NSURL *newAuthority = [[MSIDAadAuthorityCache sharedInstance] cacheUrlForAuthority:token.authority context:context];
    
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Saving token %@ with authority %@, clientID %@", [MSIDTokenTypeHelpers tokenTypeAsString:token.tokenType], newAuthority, token.clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Saving token %@ for account %@ with authority %@, clientID %@", token, token.legacyUserId, newAuthority, token.clientId);
    
    // The authority used to retrieve the item over the network can differ from the preferred authority used to
    // cache the item. As it would be awkward to cache an item using an authority other then the one we store
    // it with we switch it out before saving it to cache.
    token.authority = newAuthority;
    
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;

    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:newAuthority
                                                                             clientId:cacheItem.clientId
                                                                             resource:cacheItem.target
                                                                         legacyUserId:userId];
    
    BOOL result = [_dataSource saveToken:cacheItem
                                     key:key
                              serializer:_serializer
                                 context:context
                                   error:error];
    
    [self stopTelemetryEvent:event withItem:token success:result context:context];
    
    return result;
}

- (MSIDBaseToken *)getTokenWithType:(MSIDTokenType)tokenType
                    userIdentifiers:(id<MSIDUserIdentifiers>)userIdentifiers
                      requestParams:(MSIDRequestParameters *)parameters
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];
    
    MSIDBaseToken *token = nil;
    
    // Do custom handling for refresh tokens, because they need fallback logic with different identifiers
    if (tokenType == MSIDTokenTypeRefreshToken)
    {
        token = [self getRefreshTokenWithUserIdentifiers:userIdentifiers
                                           requestParams:parameters
                                                 context:context
                                                   error:error];
    }
    else
    {
        token = [self getTokenByLegacyUserId:userIdentifiers.legacyUserId
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

- (MSIDBaseToken *)getUpdatedToken:(MSIDBaseToken *)token
                           context:(id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    return [self getTokenByLegacyUserId:cacheItem.legacyUserId
                              tokenType:cacheItem.tokenType
                              authority:cacheItem.authority
                               clientId:cacheItem.clientId
                               resource:cacheItem.target
                                context:context
                                  error:error];
}

- (NSArray *)getAllTokensOfType:(MSIDTokenType)tokenType
                   withClientId:(NSString *)clientId
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Get all tokens of type %@ with clientId %@", [MSIDTokenTypeHelpers tokenTypeAsString:tokenType], clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Get all tokens of type %@ with clientId %@", [MSIDTokenTypeHelpers tokenTypeAsString:tokenType], clientId);
    
    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP context:context];

    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    
    NSArray<MSIDTokenCacheItem *> *legacyCacheItems = [_dataSource tokensWithKey:query
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

- (NSArray<MSIDBaseToken *> *)allTokensWithContext:(id<MSIDRequestContext>)context
                                             error:(NSError **)error
{
    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    __auto_type items = [_dataSource tokensWithKey:query serializer:_serializer context:context error:error];
    
    NSMutableArray<MSIDBaseToken *> *tokens = [NSMutableArray new];
    
    for (MSIDTokenCacheItem *item in items)
    {
        MSIDBaseToken *token = [item tokenWithType:item.tokenType];
        if (token)
        {
            [tokens addObject:token];
        }
    }
    
    return tokens;
}

- (BOOL)removeToken:(MSIDBaseToken *)token
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
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Removing token %@ with account %@", token, token.legacyUserId);

    MSIDTelemetryCacheEvent *event = [self startCacheEventWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE context:context];
    
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
 
    NSURL *authority = token.storageAuthority ? token.storageAuthority : token.authority;

    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                             clientId:cacheItem.clientId
                                                                             resource:cacheItem.target
                                                                         legacyUserId:cacheItem.legacyUserId];
    
    BOOL result = [_dataSource removeItemsWithKey:key context:context error:error];

    if (result && token.tokenType == MSIDTokenTypeRefreshToken)
    {
        [_dataSource saveWipeInfoWithContext:context error:nil];
    }
    
    [self stopTelemetryEvent:event withItem:nil success:result context:context];
    return result;
}

- (BOOL)removeAccount:(MSIDAccount *)account
              context:(id<MSIDRequestContext>)context
                error:(NSError **)error
{
    // We don't suppport account in legacy cache.
    return YES;
}

- (BOOL)removeAllTokensForUser:(id<MSIDUserIdentifiers>)userIdentifiers
                   environment:(NSString *)environment
                      clientId:(NSString *)clientId
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    // TODO: authority migration?
    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    query.legacyUserId = userIdentifiers.legacyUserId;

    NSArray<MSIDTokenCacheItem *> *userTokens = [_dataSource tokensWithKey:query serializer:_serializer context:context error:error];

    for (MSIDTokenCacheItem *item in userTokens)
    {
        if ([item.clientId isEqualToString:clientId]
            && [item.authority.msidHostWithPortIfNecessary isEqualToString:environment])
        {
            MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:item.authority
                                                                                     clientId:item.clientId
                                                                                     resource:item.target
                                                                                 legacyUserId:item.legacyUserId];

            if (![_dataSource removeItemsWithKey:key
                                         context:context
                                           error:error])
            {
                return NO;
            }
        }
    }

    return YES;
}

- (BOOL)clearWithContext:(id<MSIDRequestContext>)context error:(NSError **)error
{
    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    return [_dataSource removeItemsWithKey:query context:nil error:error];
}

#pragma mark - Private

- (MSIDBaseToken *)getRefreshTokenWithUserIdentifiers:(id<MSIDUserIdentifiers>)userIdentifiers
                                        requestParams:(MSIDRequestParameters *)parameters
                                              context:(id<MSIDRequestContext>)context
                                                error:(NSError **)error
{
    if ([MSIDAuthority isConsumerInstanceURL:parameters.authority])
    {
        return nil;
    }
    
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Finding refresh token with legacy user ID, clientId %@, authority %@", parameters.clientId, parameters.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Finding refresh token with legacy user ID %@, clientId %@, authority %@", userIdentifiers.legacyUserId, parameters.clientId, parameters.authority);
    
    MSIDBaseToken *resultToken = [self getTokenByLegacyUserId:userIdentifiers.legacyUserId
                                                    tokenType:MSIDTokenTypeRefreshToken
                                                    authority:parameters.authority
                                                     clientId:parameters.clientId
                                                     resource:nil
                                                      context:context
                                                        error:error];
    
    // If no legacy user ID available, or no token found by legacy user ID, try to look by unique user ID
    if (!resultToken
        && ![NSString msidIsStringNilOrBlank:userIdentifiers.uniqueUserId])
    {
        NSURL *authority = [MSIDAuthority universalAuthorityURL:parameters.authority];
        
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Finding refresh token with new user ID, clientId %@, authority %@", parameters.clientId, authority);
        MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Finding refresh token with new user ID %@, clientId %@, authority %@", userIdentifiers.uniqueUserId, parameters.clientId, authority);
        
        return [self getTokenByUniqueUserId:userIdentifiers.uniqueUserId
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

        MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:alias
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

        MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
        query.authority = alias;
        query.clientId = clientId;
        query.resource = resource;

        NSError *cacheError = nil;
        NSArray *tokens = [_dataSource tokensWithKey:query serializer:_serializer context:context error:&cacheError];
        
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

- (MSIDTelemetryCacheEvent *)startCacheEventWithName:(NSString *)cacheEventName
                                             context:(id<MSIDRequestContext>)context
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:cacheEventName];

    return [[MSIDTelemetryCacheEvent alloc] initWithName:cacheEventName context:context];
}

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
