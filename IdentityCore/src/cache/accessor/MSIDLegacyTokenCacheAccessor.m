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

#pragma mark - MSIDSharedCacheAccessor

- (BOOL)saveSharedRTForAccount:(MSIDAccount *)account
                  refreshToken:(MSIDToken *)refreshToken
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    // Save refresh token entry
    BOOL result = [self saveToken:refreshToken
                          account:account
                         clientId:refreshToken.clientId
                       serializer:_serializer
                          context:context
                            error:error];
    
    if (!result)
    {
        return NO;
    }
    
    if ([NSString msidIsStringNilOrBlank:refreshToken.familyId])
    {
        return YES;
    }
    
    // Save an additional entry if it's a family refresh token
    return [self saveToken:refreshToken
                   account:account
                  clientId:[MSIDTokenCacheKey familyClientId:refreshToken.familyId]
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
                           context:context
                             error:error];
}

- (NSArray<MSIDToken *> *)getAllSharedRTsWithParams:(MSIDRequestParameters *)parameters
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
            && token.clientId == parameters.clientId)
        {
            [resultRTs addObject:token];
        }
    }
    
    [self stopTelemetryEvent:event withToken:nil success:YES context:context];
    
    return resultRTs;
}

- (BOOL)saveAccessToken:(MSIDToken *)token
                account:(MSIDAccount *)account
          requestParams:(MSIDRequestParameters *)parameters
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
    
    return [self saveToken:token
                   account:account
                  clientId:parameters.clientId
                serializer:_serializer
                   context:context
                     error:error];
}

- (BOOL)removeSharedRTForAccount:(MSIDAccount *)account
                           token:(MSIDToken *)token
                         context:(id<MSIDRequestContext>)context
                           error:(NSError **)error
{
    if (!token || token.tokenType != MSIDTokenTypeRefreshToken)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Removing tokens can be done only as a result of a token request. Valid refresh token should be provided.", nil, nil, nil, context.correlationId, nil);
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

- (MSIDToken *)getATForAccount:(MSIDAccount *)account
                 requestParams:(MSIDRequestParameters *)parameters
                       context:(id<MSIDRequestContext>)context
                         error:(NSError * __autoreleasing *)error
{
    if (![parameters isKindOfClass:MSIDAADV1RequestParameters.class])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"MSIDAADV1RequestParameters is expected here, received something else", nil, nil, nil, context.correlationId, nil);
        }
        return nil;
    }
    
    MSIDAADV1RequestParameters *aadRequestParams = (MSIDAADV1RequestParameters *)parameters;
    
    return [self getItemForAccount:account
                         authority:aadRequestParams.authority
                          clientId:aadRequestParams.clientId
                          resource:aadRequestParams.resource
                           context:context
                             error:error];
}

#pragma mark - Helper methods

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
    
    NSURL *newAuthority = token.authority; // TODO: replace with an actual authority
    
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
                         context:(id<MSIDRequestContext>)context
                           error:(NSError **)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    //NSArray<NSURL *> *aliases = [[ADAuthorityValidation sharedInstance] cacheAliasesForAuthority:[NSURL URLWithString:_authority]];
    NSArray<NSURL *> *aliases = [NSArray array]; // TODO: replace with a real data
    
    for (NSURL *alias in aliases)
    {
        MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:alias
                                                            clientId:clientId
                                                            resource:resource
                                                                 upn:account.upn];
        if (!key)
        {
            return nil;
        }
        
        NSError *cacheError = nil;
        
        MSIDToken *token = [_dataSource itemWithKey:key
                                         serializer:_serializer
                                            context:context
                                              error:&cacheError];
        
        token.authority = authority;
        
        if (token)
        {
            [self stopTelemetryEvent:event
                           withToken:token
                             success:YES
                             context:context];

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
