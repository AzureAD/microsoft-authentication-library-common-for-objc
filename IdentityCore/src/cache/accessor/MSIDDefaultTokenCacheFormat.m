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

#import "MSIDDefaultTokenCacheFormat.h"
#import "MSIDJsonSerializer.h"
#import "MSIDAccount.h"
#import "MSIDTokenCacheKey.h"
#import "MSIDToken.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDAADV2RequestParameters.h"

@interface MSIDDefaultTokenCacheFormat()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDJsonSerializer *_serializer;
}
@end

@implementation MSIDDefaultTokenCacheFormat

#pragma mark - Init
- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
{
    self = [super init];
    
    if (self)
    {
        _dataSource = dataSource;
        _serializer = [[MSIDJsonSerializer alloc] init];
    }
    
    return self;
}



- (BOOL)saveAccessToken:(MSIDToken *)token
                account:(MSIDAccount *)account
          requestParams:(MSIDRequestParameters *)parameters
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error {
    if (![parameters isKindOfClass:MSIDAADV2RequestParameters.class])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidParameter, @"MSIDAADV2RequestParameters is expected here, received something else", nil, nil, nil, context.correlationId, nil);
        }
        return nil;
    }
    
    MSIDAADV2RequestParameters *v2Params = (MSIDAADV2RequestParameters *)parameters;
    
    // delete all cache entries with intersecting scopes
    // this should not happen but we have this as a safe guard against multiple matches
    NSArray<MSIDToken *> *allTokens = [self getATsForAccount:account authority:v2Params.authority context:context error:error];
    
    if (!allTokens)
    {
        return NO;
    }
    
    for (MSIDToken *token in allTokens)
    {
        if ([token.authority msidIsEquivalentAuthority:token.authority]
            && [token.scopes intersectsOrderedSet:token.scopes])
        {
            MSIDTokenCacheKey *keyToDelete = [MSIDTokenCacheKey keyForAccessTokenWithAuthority:token.authority
                                                                                      clientId:token.clientId
                                                                                        scopes:token.scopes
                                                                                        userId:account.userIdentifier];
            
            if (![self removeTokenWithKey:keyToDelete context:context error:error])
            {
                return NO;
            }
        }
    }
    
    return [self saveToken:token
                   account:account
                  clientId:token.clientId
                    scopes:nil
                 authority:token.authority
                serializer:_serializer
                   context:context
                     error:error];
}


- (MSIDToken *)getATForAccount:(MSIDAccount *)account
                 requestParams:(MSIDRequestParameters *)parameters
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    if (![parameters isKindOfClass:MSIDAADV2RequestParameters.class])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidParameter, @"MSIDAADV2RequestParameters is expected here, received something else", nil, nil, nil, context.correlationId, nil);
        }
        return nil;
    }
    
    MSIDAADV2RequestParameters *v2Params = (MSIDAADV2RequestParameters *)parameters;
    NSArray<MSIDToken *> *allTokens = [self getATsForAccount:account authority:parameters.authority context:context error:error];
    
    if (!allTokens || allTokens.count == 0)
    {
        // This should be rare-to-never as having a MSIDAccount object requires having a RT in cache,
        // which should imply that at some point we got an AT for that user with this client ID
        // as well. Unless users start working cross client id of course.
        MSID_LOG_WARN(context, @"No access token found for user & client id.");
        MSID_LOG_WARN_PII(context, @"No access token found for user & client id.");
        
        return nil;
    }
    
    NSURL *foundAuthority = allTokens[0].authority;
    
    NSMutableArray<MSIDToken *> *matchedTokens = [NSMutableArray<MSIDToken *> new];
    
    for (MSIDToken *token in allTokens)
    {
        if (v2Params.authority && ![v2Params.authority msidIsEquivalentAuthority:token.authority])
        {
            continue;
        }
        if (![foundAuthority msidIsEquivalentAuthority:token.authority])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorAmbiguousAuthority, @"Found multiple access tokens, which token to return is ambiguous! Please pass in authority if not provided.", nil, nil, nil, context.correlationId, nil);
            }
            return nil;
        }
        if (![v2Params.scopes isSubsetOfOrderedSet:token.scopes])
        {
            continue;
        }
        
        [matchedTokens addObject:token];
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
    
    return matchedTokens[0];
}

- (NSArray<MSIDToken *> *)getAllSharedRTsWithParams:(MSIDRequestParameters *)parameters
                                            context:(id<MSIDRequestContext>)context
                                              error:(NSError **)error {

    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForRefreshTokenWithClientId:parameters.clientId];
    
    NSArray *tokens = [_dataSource itemsWithKey:key serializer:_serializer context:context error:error];
    if (!tokens)
    {
        return nil;
    }

    return tokens;
}

- (MSIDToken *)getSharedRTForAccount:(MSIDAccount *)account
                       requestParams:(MSIDRequestParameters *)parameters
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error {
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForRefreshTokenWithUserId:account.userIdentifier
                                                                    clientId:parameters.clientId
                                                                 environment:parameters.authority.msidHostWithPortIfNecessary];
    
    return [_dataSource itemWithKey:key serializer:_serializer context:context error:error];
}

- (BOOL)removeSharedRTForAccount:(MSIDAccount *)account token:(MSIDToken *)token context:(id<MSIDRequestContext>)context error:(NSError **)error {
    if (!token || token.tokenType != MSIDTokenTypeRefreshToken)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Removing tokens can be done only as a result of a token request. Valid refresh token should be provided.", nil, nil, nil, context.correlationId, nil);
        return NO;
    }
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForRefreshTokenWithUserId:account.userIdentifier
                                                                    clientId:token.clientId
                                                                 environment:token.authority.msidHostWithPortIfNecessary];
    
    MSIDToken *tokenInCache = [_dataSource itemWithKey:key
                                            serializer:_serializer
                                               context:context
                                                 error:nil];
    
    if (tokenInCache
        && tokenInCache.tokenType == MSIDTokenTypeRefreshToken
        && [tokenInCache.token isEqualToString:token.token])
    {
        return [self removeTokenWithKey:key context:context error:error];
    }
    
    return YES;
}

- (BOOL)saveSharedRTForAccount:(MSIDAccount *)account
                  refreshToken:(MSIDToken *)refreshToken
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error {
    return [self saveToken:refreshToken
                   account:account
                  clientId:refreshToken.clientId
                    scopes:nil
                 authority:refreshToken.authority
                serializer:_serializer
                   context:context
                     error:error];
}

#pragma mark - Datasource helpers

- (BOOL)saveToken:(MSIDToken *)token
          account:(MSIDAccount *)account
         clientId:(NSString *)clientId
           scopes:(NSOrderedSet<NSString *> *)scopes
        authority:(NSURL *)authority
       serializer:(id<MSIDTokenSerializer>)serializer
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    MSIDTokenCacheKey *key = nil;
    
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                           context:context];
    
    token.authority = authority;
    
    switch (token.tokenType) {
        case MSIDTokenTypeAccessToken:
            key = [MSIDTokenCacheKey keyForAccessTokenWithAuthority:authority
                                                           clientId:clientId
                                                             scopes:scopes
                                                             userId:account.userIdentifier];
            break;
            
        case MSIDTokenTypeRefreshToken:
            key = [MSIDTokenCacheKey keyForRefreshTokenWithUserId:account.userIdentifier
                                                         clientId:clientId
                                                      environment:authority.msidHostWithPortIfNecessary];
            break;
            
        default:
            break;
    }
    
    if (!key)
    {
        [self stopTelemetryEvent:event
                       withToken:token
                         success:NO
                         context:context];
        
        return NO;
    }
    
    [self stopTelemetryEvent:event
                   withToken:token
                     success:YES
                     context:context];
    
    return [_dataSource setItem:token key:key serializer:serializer context:context error:error];
}



- (NSArray<MSIDToken *> *)getATsForAccount:(MSIDAccount *)account
                                 authority:(NSURL *)authority
                                   context:(id<MSIDRequestContext>)context
                                     error:(NSError *__autoreleasing *)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                           context:context];
    
    
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForAllAccessTokensWithUserId:account.userIdentifier
                                                                    environment:authority.msidHostWithPortIfNecessary];
    
    NSArray<MSIDToken *> *result = [_dataSource itemsWithKey:key serializer:_serializer context:context error:error];
    
    [self stopTelemetryEvent:event
                   withToken:nil
                     success:NO
                     context:context];
    
    return result;
}


- (BOOL)removeTokenWithKey:(MSIDTokenCacheKey *)key
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error

{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE
                                                                           context:context];
    
    BOOL result = [_dataSource removeItemsWithKey:key context:context error:error];
    
    [self stopTelemetryEvent:event withToken:nil success:YES context:context];
    return result;
}

#pragma mark - Telemetry helpers

- (void)stopTelemetryEvent:(MSIDTelemetryCacheEvent *)event
                 withToken:(MSIDToken *)token
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


#pragma mark - Other helpers
+ (NSOrderedSet<NSString *> *)scopeFromString:(NSString *)scopeString
{
    NSMutableOrderedSet<NSString *> *scope = [NSMutableOrderedSet<NSString *> new];
    NSArray *parts = [scopeString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
    for (NSString *part in parts)
    {
        if (![NSString msidIsStringNilOrBlank:part])
        {
            [scope addObject:part.msidTrimmedString.lowercaseString];
        }
    }
    return scope;
}

@end
