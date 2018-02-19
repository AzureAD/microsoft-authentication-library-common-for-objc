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
#import "MSIDTokenCacheKey.h"
#import "MSIDBaseToken.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDAADV2RequestParameters.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"

@interface MSIDDefaultTokenCacheAccessor()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDJsonSerializer *_atSerializer;
    MSIDJsonSerializer *_rtSerializer;
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
        _atSerializer = [[MSIDJsonSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken];
        _rtSerializer = [[MSIDJsonSerializer alloc] initForTokenType:MSIDTokenTypeRefreshToken];
    }
    
    return self;
}

- (BOOL)saveAccessToken:(MSIDAccessToken *)token
                account:(MSIDAccount *)account
          requestParams:(MSIDRequestParameters *)parameters
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error {
    if (![parameters isKindOfClass:MSIDAADV2RequestParameters.class])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"MSIDAADV2RequestParameters is expected here, received something else", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    if (!account.userIdentifier)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"user identifier is needed to save access token for MSDIDefaultTokenCacheFormat", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    token.authority = [[MSIDAadAuthorityCache sharedInstance] cacheUrlForAuthority:token.authority context:context];
    NSArray<NSURL *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:token.authority];
    
    // delete all cache entries with intersecting scopes
    // this should not happen but we have this as a safe guard against multiple matches
    NSArray<MSIDAccessToken *> *allTokens = [self getAllATsForContext:context error:error];

    if (!allTokens)
    {
        return NO;
    }
    
    for (MSIDAccessToken *tokenInCache in allTokens)
    {
        if ([tokenInCache.clientInfo.userIdentifier isEqualToString:account.userIdentifier]
            && [tokenInCache.clientId isEqualToString:token.clientId]
            && [tokenInCache.authority msidIsEquivalentWithAnyAlias:aliases]
            && [tokenInCache.scopes intersectsOrderedSet:token.scopes])
        {
            MSIDTokenCacheKey *keyToDelete = [MSIDTokenCacheKey keyForAccessTokenWithAuthority:tokenInCache.authority
                                                                                      clientId:tokenInCache.clientId
                                                                                        scopes:tokenInCache.scopes
                                                                                        userId:account.userIdentifier];
            
            if (![self removeTokenWithKey:keyToDelete context:context error:error])
            {
                return NO;
            }
        }
    }
    
    return [self saveToken:token
                    userId:account.userIdentifier
                  clientId:token.clientId
                    scopes:token.scopes
                 authority:token.authority
                serializer:_atSerializer
                   context:context
                     error:error];
}


- (MSIDAccessToken *)getATForAccount:(MSIDAccount *)account
                       requestParams:(MSIDRequestParameters *)parameters
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    if (![parameters isKindOfClass:MSIDAADV2RequestParameters.class])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"MSIDAADV2RequestParameters is expected here, received something else", nil, nil, nil, context.correlationId, nil);
        }
        return nil;
    }
    MSIDAADV2RequestParameters *v2params = (MSIDAADV2RequestParameters *)parameters;
    
    if (!account.userIdentifier)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"user identifier is needed to save access token for MSDIDefaultTokenCacheFormat", nil, nil, nil, context.correlationId, nil);
        }
        return nil;
    }
    
    NSArray<MSIDAccessToken *> *allTokens = [self getAllATsForContext:context
                                                                error:error];
    
    if (!allTokens || allTokens.count == 0)
    {
        // This should be rare-to-never as having a MSIDAccount object requires having a RT in cache,
        // which should imply that at some point we got an AT for that user with this client ID
        // as well. Unless users start working cross client id of course.
        MSID_LOG_WARN(context, @"No access token found for user & client id.");
        MSID_LOG_WARN_PII(context, @"No access token found for user & client id.");
        
        return nil;
    }
    
    NSURL *authorityToCheck = v2params.authority? v2params.authority : allTokens[0].authority;
    NSArray<NSURL *> *tokenAliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authorityToCheck];
    
    NSMutableArray<MSIDAccessToken *> *matchedTokens = [NSMutableArray<MSIDAccessToken *> new];
    
    for (MSIDAccessToken *token in allTokens)
    {
        if ([token.clientInfo.userIdentifier isEqualToString:account.userIdentifier]
            && [token.clientId isEqualToString:v2params.clientId]
            && [token.scopes isSubsetOfOrderedSet:v2params.scopes])
        {
            if ([token.authority msidIsEquivalentWithAnyAlias:tokenAliases])
            {
                [matchedTokens addObject:token];
            }
            else
            {
                if (!v2params.authority)
                {
                    if (error)
                    {
                        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorAmbiguousAuthority, @"Found multiple access tokens, which token to return is ambiguous! Please pass in authority if not provided.", nil, nil, nil, context.correlationId, nil);
                    }
                    return nil;
                }
            }
        }
    }
    
    if (matchedTokens.count == 0)
    {
        MSID_LOG_INFO(context, @"No matching access token found.");
        MSID_LOG_INFO_PII(context, @"No matching access token found.");
        return nil;
    }
    
    if ([matchedTokens[0] isExpired])
    {
        MSID_LOG_INFO(context, @"Access token found in cache is already expired.");
        MSID_LOG_INFO_PII(context, @"Access token found in cache is already expired.");
        return nil;
    }
    
    MSIDAccessToken *tokenToReturn = matchedTokens[0];
    tokenToReturn.authority = parameters.authority;
    
    return tokenToReturn;
}

- (MSIDAdfsToken *)getADFSTokenWithRequestParams:(MSIDRequestParameters *)parameters
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"ADFS tokens are not currently supported for MSAL", nil, nil, nil, context.correlationId, nil);
    }
    
    return nil;
}

- (NSArray<MSIDRefreshToken *> *)getAllSharedRTsWithClientId:(NSString *)clientId
                                                     context:(id<MSIDRequestContext>)context
                                                       error:(NSError **)error
{

    return [self getAllRTsForClientId:clientId context:context error:error];
}

- (MSIDRefreshToken *)getSharedRTForAccount:(MSIDAccount *)account
                              requestParams:(MSIDRequestParameters *)parameters
                                    context:(id<MSIDRequestContext>)context
                                      error:(NSError **)error {
    
    if (!account.userIdentifier)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"user identifier is needed to save access token for MSDIDefaultTokenCacheFormat", nil, nil, nil, context.correlationId, nil);
        }
        return nil;
    }
    
    return [self getRefreshTokenForUserId:account.userIdentifier
                                 clientId:parameters.clientId
                                authority:parameters.authority
                               serializer:_rtSerializer
                                  context:context
                                    error:error];
}


- (BOOL)removeSharedRTForAccount:(MSIDAccount *)account
                           token:(MSIDRefreshToken *)token
                         context:(id<MSIDRequestContext>)context
                           error:(NSError **)error
{
    if (!token || [NSString msidIsStringNilOrBlank:token.refreshToken])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Removing tokens can be done only as a result of a token request. Valid refresh token should be provided.", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    NSError *cacheError = nil;
    MSIDRefreshToken *tokenInCache  = [self getRefreshTokenForUserId:account.userIdentifier
                                                            clientId:token.clientId
                                                           authority:token.authority
                                                          serializer:_rtSerializer
                                                             context:context
                                                               error:error];
    
    if (cacheError)
    {
        if (error)
        {
            *error = cacheError;
        }
        return NO;
    }

    if (tokenInCache
        && ![NSString msidIsStringNilOrBlank:tokenInCache.refreshToken]
        && [tokenInCache.refreshToken isEqualToString:token.refreshToken])
    {
        MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForRefreshTokenWithUserId:account.userIdentifier
                                                                        clientId:token.clientId
                                                                     environment:token.authority.msidHostWithPortIfNecessary];
        
        return [self removeTokenWithKey:key context:context error:error];
    }
    
    return YES;
}

- (BOOL)saveSharedRTForAccount:(MSIDAccount *)account
                  refreshToken:(MSIDRefreshToken *)refreshToken
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error {
    return [self saveToken:refreshToken
                    userId:account.userIdentifier
                  clientId:refreshToken.clientId
                    scopes:nil
                 authority:refreshToken.authority
                serializer:_rtSerializer
                   context:context
                     error:error];
}

#pragma mark - Datasource helpers

- (MSIDTokenCacheKey *)keyForTokenType:(MSIDTokenType)tokenType
                                userId:(NSString *)userId
                              clientId:(NSString *)clientId
                                scopes:(NSOrderedSet<NSString *> *)scopes
                             authority:(NSURL *)authority
{
    if (tokenType == MSIDTokenTypeAccessToken)
    {
        return [MSIDTokenCacheKey keyForAccessTokenWithAuthority:authority
                                                        clientId:clientId
                                                          scopes:scopes
                                                          userId:userId];
    }
    else if (tokenType == MSIDTokenTypeRefreshToken)
    {
        return [MSIDTokenCacheKey keyForRefreshTokenWithUserId:userId
                                                      clientId:clientId
                                                   environment:authority.msidHostWithPortIfNecessary];
    }
    
    // ADFS token type is not supported
    return nil;
}


- (BOOL)saveToken:(MSIDBaseToken *)token
           userId:(NSString *)userId
         clientId:(NSString *)clientId
           scopes:(NSOrderedSet<NSString *> *)scopes
        authority:(NSURL *)authority
       serializer:(id<MSIDTokenSerializer>)serializer
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                           context:context];
    
    NSURL *newAuthority = [[MSIDAadAuthorityCache sharedInstance] cacheUrlForAuthority:token.authority context:context];
    
    // The authority used to retrieve the item over the network can differ from the preferred authority used to
    // cache the item. As it would be awkward to cache an item using an authority other then the one we store
    // it with we switch it out before saving it to cache.
    token.authority = newAuthority;
    
    MSIDTokenCacheKey *key = [self keyForTokenType:token.tokenType userId:userId clientId:clientId scopes:scopes authority:authority];
    if (!key)
    {
        [self stopTelemetryEvent:event
                       withToken:token
                         success:NO
                         context:context];
        
        return NO;
    }
    
    BOOL result = [_dataSource setItem:token key:key serializer:serializer context:context error:error];
    
    [self stopTelemetryEvent:event
                   withToken:token
                     success:result
                     context:context];
    
    return result;
}

- (MSIDRefreshToken *)getRefreshTokenForUserId:(NSString *)userId
                                      clientId:(NSString *)clientId
                                     authority:(NSURL *)authority
                                    serializer:(id<MSIDTokenSerializer>)serializer
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
                                                userId:userId clientId:clientId scopes:nil authority:alias];
        if (!key)
        {
            [self stopTelemetryEvent:event
                           withToken:nil
                             success:NO
                             context:context];
            
            return nil;
        }
        
        NSError *cacheError = nil;

        MSIDRefreshToken *token = (MSIDRefreshToken *)[_dataSource itemWithKey:key
                                                                    serializer:serializer
                                                                       context:context
                                                                         error:&cacheError];
        
        if (token)
        {
            token.authority = authority;
            [self stopTelemetryEvent:event withToken:token success:YES context:context];
            return token;
        }
       
        if (cacheError)
        {
            if (error)
            {
                *error = cacheError;
            }
            
            [self stopTelemetryEvent:event
                           withToken:nil
                             success:NO
                             context:context];
            
            return nil;
        }
    }
    
    [self stopTelemetryEvent:event
                   withToken:nil
                     success:NO
                     context:context];
    
    return nil;
}


- (NSArray<MSIDAccessToken *> *)getAllATsForContext:(id<MSIDRequestContext>)context
                                              error:(NSError *__autoreleasing *)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                           context:context];

    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForAllAccessTokens];
    NSArray *allAccessTokensForAlias = [_dataSource itemsWithKey:key serializer:_atSerializer context:context error:error];
    
    [self stopTelemetryEvent:event
                   withToken:nil
                     success:(allAccessTokensForAlias != nil)
                     context:context];
    
    return allAccessTokensForAlias;
}

- (NSArray<MSIDRefreshToken *> *)getAllRTsForClientId:(NSString *)clientId context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForRefreshTokenWithClientId:clientId];
    
    NSArray *tokens = [_dataSource itemsWithKey:key serializer:_rtSerializer context:context error:error];
    
    [self stopTelemetryEvent:event withToken:nil success:(tokens != nil) context:context];
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
    
    [self stopTelemetryEvent:event withToken:nil success:YES context:context];
    return result;
}

#pragma mark - Telemetry helpers

- (void)stopTelemetryEvent:(MSIDTelemetryCacheEvent *)event
                 withToken:(MSIDBaseToken *)token
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

@end
