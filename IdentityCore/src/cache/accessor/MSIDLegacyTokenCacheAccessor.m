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
#import "MSIDTokenCacheKey.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDAADV1RequestParameters.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDTokenCacheKey+Legacy.h"

@interface MSIDLegacyTokenCacheAccessor()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    
    MSIDKeyedArchiverSerializer *_serializer;
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

        _serializer = [[MSIDKeyedArchiverSerializer alloc] init];
        _adfsSerializer = [[MSIDKeyedArchiverSerializer alloc] initWithClassName:MSIDAdfsToken.class];
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
    if (!account.upn)
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

- (BOOL)saveAccessToken:(MSIDToken *)token
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
                serializer:token.tokenType == MSIDTokenTypeAdfsUserToken ? _adfsSerializer : _serializer
                   context:context
                     error:error];
}

- (MSIDToken *)getATForAccount:(MSIDAccount *)account
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
                      serializer:_serializer
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
                  refreshToken:(MSIDToken *)refreshToken
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
                serializer:_serializer
                   context:context
                     error:error];
}

- (MSIDToken *)getSharedRTForAccount:(MSIDAccount *)account
                       requestParams:(MSIDRequestParameters *)parameters
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    return [self getItemForAccount:account
                         authority:parameters.authority
                          clientId:parameters.clientId
                          resource:nil
                        serializer:_serializer
                           context:context
                             error:error];
}

- (NSArray<MSIDToken *> *)getAllSharedRTsWithClientId:(NSString *)clientId
                                              context:(id<MSIDRequestContext>)context
                                                error:(NSError **)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    NSArray *legacyTokens = [_dataSource itemsWithKey:[MSIDTokenCacheKey keyForAllItems]
                                           serializer:_serializer
                                              context:context
                                                error:error];
    
    if (!legacyTokens)
    {
        [self stopTelemetryEvent:event withToken:nil success:NO context:context];
        
        return nil;
    }
    
    NSMutableArray *resultRTs = [NSMutableArray array];
    
    for (MSIDToken *token in legacyTokens)
    {
        if (token.tokenType == MSIDTokenTypeRefreshToken
            && [token.clientId isEqualToString:clientId])
        {
            [resultRTs addObject:token];
        }
    }
    
    [self stopTelemetryEvent:event withToken:nil success:YES context:context];
    
    return resultRTs;
}

- (BOOL)removeSharedRTForAccount:(MSIDAccount *)account
                           token:(MSIDToken *)token
                         context:(id<MSIDRequestContext>)context
                           error:(NSError **)error
{
    if (!token || token.tokenType != MSIDTokenTypeRefreshToken)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Removing tokens can be done only as a result of a token request. Valid refresh token should be provided.", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:token.authority
                                                        clientId:token.clientId
                                                        resource:token.resource
                                                             upn:account.upn];
    
    MSIDToken *tokenInCache = [_dataSource itemWithKey:key
                                            serializer:_serializer
                                               context:context
                                                 error:nil];
    
    if (tokenInCache
        && tokenInCache.tokenType == MSIDTokenTypeRefreshToken
        && [tokenInCache.token isEqualToString:token.token])
    {
        return [_dataSource removeItemsWithKey:key
                                       context:context
                                         error:error];
    }
    
    return YES;
    
}

#pragma mark - Helper methods

- (MSIDToken *)getATForAccount:(MSIDAccount *)account
                 requestParams:(MSIDRequestParameters *)parameters
                    serializer:(id<MSIDTokenSerializer>)serializer
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    if (![self checkRequestParameters:parameters context:context error:error])
    {
        return nil;
    }
    
    MSIDAADV1RequestParameters *aadRequestParams = (MSIDAADV1RequestParameters *)parameters;
    
    return [self getItemForAccount:account
                         authority:aadRequestParams.authority
                          clientId:aadRequestParams.clientId
                          resource:aadRequestParams.resource
                        serializer:serializer
                           context:context
                             error:error];
}

- (BOOL)saveToken:(MSIDToken *)token
          account:(MSIDAccount *)account
         clientId:(NSString *)clientId
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
    
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:newAuthority
                                                        clientId:clientId
                                                        resource:token.resource
                                                             upn:account.upn];
    
    BOOL result = [_dataSource setItem:token key:key serializer:serializer context:context error:error];
    
    [self stopTelemetryEvent:event withToken:token success:result context:context];
    
    return result;
}

- (MSIDToken *)getItemForAccount:(MSIDAccount *)account
                       authority:(NSURL *)authority
                        clientId:(NSString *)clientId
                        resource:(NSString *)resource
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
        BOOL matchByUPN = account.upn != nil;
        
        MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:alias
                                                            clientId:clientId
                                                            resource:resource
                                                                 upn:account.upn];
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
        
        for (MSIDToken *token in tokens)
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

@end
