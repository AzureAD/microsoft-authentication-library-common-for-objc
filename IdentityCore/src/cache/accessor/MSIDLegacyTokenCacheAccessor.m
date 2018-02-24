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
#import "MSIDAdfsToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDAADV1RequestParameters.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDLegacyTokenCacheKey.h"

@interface MSIDLegacyTokenCacheAccessor()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    
    MSIDKeyedArchiverSerializer *_atSerializer;
    MSIDKeyedArchiverSerializer *_rtSerializer;
    MSIDKeyedArchiverSerializer *_adfsSerializer;
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

        _atSerializer = [[MSIDKeyedArchiverSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken];
        _rtSerializer = [[MSIDKeyedArchiverSerializer alloc] initForTokenType:MSIDTokenTypeRefreshToken];
        _adfsSerializer = [[MSIDKeyedArchiverSerializer alloc] initForTokenType:MSIDTokenTypeLegacyADFSToken];
    }
    
    return self;
}

#pragma mark - Input validation

- (BOOL)checkRequestParameters:(MSIDRequestParameters *)parameters
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    if (![parameters isKindOfClass:MSIDAADV1RequestParameters.class])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"MSIDAADV1RequestParameters is expected here, received something else", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)checkUserIdentifier:(MSIDAccount *)account
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    if (!account.legacyUserId)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"UPN is needed for legacy token cache accessor", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    return YES;
}

#pragma mark - Access tokens

- (BOOL)saveAccessToken:(MSIDAccessToken *)token
                account:(MSIDAccount *)account
          requestParams:(MSIDRequestParameters *)parameters
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error
{
    if (![self checkRequestParameters:parameters context:context error:error]
        || ![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    return [self saveToken:token
                   account:account
                  clientId:parameters.clientId
                serializer:_atSerializer
                   context:context
                     error:error];
}

- (MSIDAccessToken *)getATForAccount:(MSIDAccount *)account
                       requestParams:(MSIDRequestParameters *)parameters
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return nil;
    }
    
    return [self getATForAccount:account
                   requestParams:parameters
                      serializer:_atSerializer
                         context:context
                           error:error];
}

#pragma mark - ADFS tokens

- (BOOL)saveADFSToken:(MSIDAdfsToken *)token
              account:(MSIDAccount *)account
        requestParams:(MSIDRequestParameters *)parameters
              context:(id<MSIDRequestContext>)context
                error:(NSError **)error
{
    if (![self checkRequestParameters:parameters context:context error:error]
        || ![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    return [self saveToken:token
                   account:account
                  clientId:parameters.clientId
                serializer:_adfsSerializer
                   context:context
                     error:error];
}

- (MSIDAdfsToken *)getADFSTokenWithRequestParams:(MSIDRequestParameters *)parameters
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithUpn:@"" utid:nil uid:nil];
    return (MSIDAdfsToken *)[self getATForAccount:account
                                    requestParams:parameters
                                       serializer:_adfsSerializer
                                          context:context
                                            error:error];
}

#pragma mark - Refresh tokens

- (BOOL)saveSharedRTForAccount:(MSIDAccount *)account
                  refreshToken:(MSIDRefreshToken *)refreshToken
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    // Save refresh token entry
    return [self saveToken:refreshToken
                   account:account
                  clientId:refreshToken.clientId
                serializer:_rtSerializer
                   context:context
                     error:error];
}

- (MSIDRefreshToken *)getSharedRTForAccount:(MSIDAccount *)account
                              requestParams:(MSIDRequestParameters *)parameters
                                    context:(id<MSIDRequestContext>)context
                                      error:(NSError **)error
{
    return (MSIDRefreshToken *)[self getItemForAccount:account
                                             authority:parameters.authority
                                              clientId:parameters.clientId
                                              resource:nil
                                            serializer:_rtSerializer
                                               context:context
                                                 error:error];
}

- (MSIDBaseToken<MSIDRefreshableToken> *)getLatestRTForToken:(MSIDBaseToken<MSIDRefreshableToken> *)token
                                                     account:(MSIDAccount *)account
                                                     context:(id<MSIDRequestContext>)context
                                                       error:(NSError **)error
{
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return nil;
    }
    
    return (MSIDRefreshToken *)[self getItemForAccount:account
                                             authority:token.authority
                                              clientId:token.clientId
                                              resource:token.resource
                                            serializer:_rtSerializer
                                               context:context
                                                 error:error];
}

- (NSArray<MSIDRefreshToken *> *)getAllSharedRTsWithClientId:(NSString *)clientId
                                                     context:(id<MSIDRequestContext>)context
                                                       error:(NSError **)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    NSArray *legacyTokens = [_dataSource itemsWithKey:[MSIDLegacyTokenCacheKey keyForAllItems]
                                           serializer:_rtSerializer
                                              context:context
                                                error:error];
    
    if (!legacyTokens)
    {
        [self stopTelemetryEvent:event withToken:nil success:NO context:context];
        
        return nil;
    }
    
    NSMutableArray *resultRTs = [NSMutableArray array];
    
    for (MSIDRefreshToken *token in legacyTokens)
    {
        if (![NSString msidIsStringNilOrBlank:token.refreshToken]
            && [token.clientId isEqualToString:clientId])
        {
            [resultRTs addObject:token];
        }
    }
    
    [self stopTelemetryEvent:event withToken:nil success:YES context:context];
    
    return resultRTs;
}

- (BOOL)removeSharedRTForAccount:(MSIDAccount *)account
                           token:(MSIDBaseToken<MSIDRefreshableToken> *)token
                         context:(id<MSIDRequestContext>)context
                           error:(NSError **)error
{
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    if (!token)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Token not provided", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey keyWithAuthority:token.authority
                                                                    clientId:token.clientId
                                                                    resource:token.resource
                                                                         upn:account.legacyUserId];
    
    return [_dataSource removeItemsWithKey:key
                                   context:context
                                     error:error];
}

#pragma mark - Helper methods

- (MSIDAccessToken *)getATForAccount:(MSIDAccount *)account
                       requestParams:(MSIDRequestParameters *)parameters
                          serializer:(id<MSIDCacheItemSerializer>)serializer
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    if (![self checkRequestParameters:parameters context:context error:error])
    {
        return nil;
    }
    
    MSIDAADV1RequestParameters *aadRequestParams = (MSIDAADV1RequestParameters *)parameters;
    
    return (MSIDAccessToken *)[self getItemForAccount:account
                                            authority:aadRequestParams.authority
                                             clientId:aadRequestParams.clientId
                                             resource:aadRequestParams.resource
                                           serializer:serializer
                                              context:context
                                                error:error];
}

- (BOOL)saveToken:(MSIDBaseToken *)token
          account:(MSIDAccount *)account
         clientId:(NSString *)clientId
       serializer:(id<MSIDCacheItemSerializer>)serializer
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
    
    NSString *resource = nil;
    
    if ([token isKindOfClass:[MSIDAccessToken class]])
    {
        resource = ((MSIDAccessToken *)token).resource;
    }
    
    MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey keyWithAuthority:newAuthority
                                                                    clientId:clientId
                                                                    resource:resource
                                                                         upn:account.legacyUserId];
    
    BOOL result = [_dataSource setItem:token key:key serializer:serializer context:context error:error];
    
    [self stopTelemetryEvent:event withToken:token success:result context:context];
    
    return result;
}

- (MSIDBaseToken *)getItemForAccount:(MSIDAccount *)account
                           authority:(NSURL *)authority
                            clientId:(NSString *)clientId
                            resource:(NSString *)resource
                          serializer:(id<MSIDCacheItemSerializer>)serializer
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
        BOOL matchByUPN = account.legacyUserId != nil;
        
        MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey keyWithAuthority:alias
                                                                        clientId:clientId
                                                                        resource:resource
                                                                             upn:account.legacyUserId];
        if (!key)
        {
            return nil;
        }
        
        NSError *cacheError = nil;
        
        NSArray *tokens = [_dataSource itemsWithKey:key
                                         serializer:serializer
                                            context:context
                                              error:&cacheError];
        
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
        
        for (MSIDBaseToken *token in tokens)
        {
            token.authority = authority;
            
            /*
             This is an additional fallback for cases, when UPN is not known, but uid and utid are available
             In that case, token is matched by uid and utid instead.
             */
            if (!matchByUPN
                && ![token.clientInfo.userIdentifier isEqualToString:account.userIdentifier])
            {
                continue;
            }
            
            [self stopTelemetryEvent:event
                           withToken:token
                             success:YES
                             context:context];
            
            return token;
        }
    }
    
    [self stopTelemetryEvent:event
                   withToken:nil
                     success:NO
                     context:context];
    
    return nil;
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
