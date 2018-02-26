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

#import "MSIDLegacyTokenCache.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDAccount.h"
#import "MSIDAdfsToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDLegacyTokenCacheKey.h"
#import "MSIDRequestParameters.h"
#import "MSIDTokenResponse.h"
#import "MSIDTokenCacheDataSource.h"

@interface MSIDLegacyTokenCache()

@property (nonatomic) MSIDKeyedArchiverSerializer *serializer;

@end

@implementation MSIDLegacyTokenCache

- (MSIDAdfsToken *)getADFSTokenWithRequestParams:(MSIDRequestParameters *)parameters
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    MSIDTokenCacheItem *cacheItem = [self getTokenCacheItemWithAccount:nil
                                                       useLegacyUserId:YES
                                                             authority:parameters.authority
                                                              clientId:parameters.clientId
                                                              resource:parameters.resource
                                                               context:context
                                                                 error:error];
    
    
    return [[MSIDAdfsToken alloc] initWithTokenCacheItem:cacheItem];
}

#pragma mark - MSIDBaseTokenCache

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
                secondaryAccessors:(NSArray<id<MSIDSSOStateShareable>> *)secondaryAccessors;
{
    self = [super initWithDataSource:dataSource secondaryAccessors:secondaryAccessors];
    
    if (self)
    {
        _serializer = [MSIDKeyedArchiverSerializer new];
    }
    
    return self;
}

- (BOOL)saveTokensWithRequestParams:(MSIDRequestParameters *)requestParams
                           response:(MSIDTokenResponse *)response
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithTokenResponse:response request:requestParams];
    
    if (response.isMultiResource)
    {
        // Save Access Token.
        MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenResponse:response request:requestParams];
        BOOL result = [self saveToken:accessToken account:account context:context error:error];
        
        if (!result)
        {
            return NO;
        }
        
        // Save Refresh Token.
        MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] initWithTokenResponse:response request:requestParams];
        return [self saveRefreshToken:refreshToken withAccount:account context:context error:error];
    }
    
    // Save ADFS token.
    MSIDAdfsToken *adfsToken = [[MSIDAdfsToken alloc] initWithTokenResponse:response request:requestParams];
    account.legacyUserId = @"";
    return [self saveToken:adfsToken account:account context:context error:error];
}

- (MSIDAccessToken *)getATForAccount:(MSIDAccount *)account
                       requestParams:(MSIDRequestParameters *)parameters
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSIDTokenCacheItem *cacheItem = [self getTokenCacheItemWithAccount:account
                                                       useLegacyUserId:YES
                                                             authority:parameters.authority
                                                              clientId:parameters.clientId
                                                              resource:parameters.resource
                                                               context:context
                                                                 error:error];
    
    return [[MSIDAccessToken alloc] initWithTokenCacheItem:cacheItem];
}

#pragma mark - MSIDSSOStateShareable

- (BOOL)saveSSOToken:(MSIDRefreshToken *)refreshToken
             account:(MSIDAccount *)account
             context:(id<MSIDRequestContext>)context
               error:(NSError **)error
{
    return [self saveToken:refreshToken account:account context:context error:error];
}

- (MSIDRefreshToken *)getSSOTokenWithAccount:(MSIDAccount *)account
                            requestParams:(MSIDRequestParameters *)parameters
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    MSIDRefreshToken *resultToken = nil;
    
    if (![NSString msidIsStringNilOrBlank:account.legacyUserId])
    {
        MSIDTokenCacheItem *cacheItem = [self getTokenCacheItemWithAccount:account
                                                           useLegacyUserId:YES
                                                                 authority:parameters.authority clientId:parameters.clientId
                                                                  resource:nil
                                                                   context:context
                                                                     error:error];
        
        resultToken =  [[MSIDRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    }
    
    // If no legacy user ID available, or no token found by legacy user ID, try to look by unique user ID
    if (!resultToken && ![NSString msidIsStringNilOrBlank:account.userIdentifier])
    {
        MSIDTokenCacheItem *cacheItem = [self getTokenCacheItemWithAccount:account
                                                           useLegacyUserId:NO
                                                                 authority:parameters.authority clientId:parameters.clientId
                                                                  resource:nil
                                                                   context:context
                                                                     error:error];
        
        resultToken =  [[MSIDRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    }
    
    return resultToken;
}

- (NSArray *)getAllSSOTokensWithClientId:(NSString *)clientId
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    NSArray<MSIDTokenCacheItem *> *legacyCacheItems = [self.dataSource tokensWithKey:[MSIDLegacyTokenCacheKey keyForAllItems]
                                                                          serializer:_serializer
                                                                             context:context
                                                                               error:error];
    
    if (!legacyCacheItems)
    {
        [self stopTelemetryEvent:event withItem:nil success:NO context:context];
        return nil;
    }
    
    NSMutableArray *resultTokens = [NSMutableArray array];
    
    for (MSIDTokenCacheItem *cacheItem in legacyCacheItems)
    {
        if (cacheItem.tokenType == MSIDTokenTypeRefreshToken
            && [cacheItem.clientId isEqualToString:clientId])
        {
            MSIDBaseToken *token = [[MSIDRefreshToken alloc] initWithTokenCacheItem:cacheItem];
            if (token)
            {
                [resultTokens addObject:token];
            }
        }
    }
    
    [self stopTelemetryEvent:event withItem:nil success:YES context:context];
    
    return resultTokens;
}

#pragma mark - Input validation

- (BOOL)checkUserIdentifier:(MSIDAccount *)account
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    if (!account.legacyUserId)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Legacy user ID is needed for legacy token cache accessor", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    return YES;
}

- (MSIDTokenCacheItem *)getLatestTokenCacheItem:(MSIDTokenCacheItem *)cacheItem
                          account:(MSIDAccount *)account
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    return [self getTokenCacheItemWithAccount:account
                              useLegacyUserId:YES
                                    authority:cacheItem.authority
                                     clientId:cacheItem.clientId
                                     resource:cacheItem.target
                                      context:context error:error];
}

- (BOOL)removeTokenCacheItem:(MSIDTokenCacheItem *)cacheItem
            account:(MSIDAccount *)account
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    if (!cacheItem)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Token not provided", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey keyWithAuthority:cacheItem.authority
                                                                    clientId:cacheItem.clientId
                                                                    resource:cacheItem.target
                                                                         legacyUserId:account.legacyUserId];
    
    return [self.dataSource removeItemsWithKey:key
                                   context:context
                                     error:error];
}

#pragma mark - Private

- (MSIDTokenCacheItem *)getTokenCacheItemWithAccount:(MSIDAccount *)account
                                     useLegacyUserId:(BOOL)useLegacy
                                           authority:(NSURL *)authority
                                            clientId:(NSString *)clientId
                                            resource:(NSString *)resource
                                             context:(id<MSIDRequestContext>)context
                                               error:(NSError **)error
{
    if (useLegacy && ![self checkUserIdentifier:account context:context error:error])
    {
        return nil;
    }
    
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    NSArray<NSURL *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authority];
    
    for (NSURL *alias in aliases)
    {
        NSString *legacyUserId = useLegacy ? account.legacyUserId : nil;
        
        MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey keyWithAuthority:alias
                                                                        clientId:clientId
                                                                        resource:resource
                                                                    legacyUserId:legacyUserId];
        if (!key)
        {
            return nil;
        }
        
        NSError *cacheError = nil;
        
        NSArray *tokens = [self.dataSource tokensWithKey:key
                                              serializer:_serializer
                                                 context:context
                                                   error:&cacheError];
        
        if (cacheError)
        {
            if (error)
            {
                *error = cacheError;
            }
            
            [self stopTelemetryEvent:event
                            withItem:nil
                             success:NO
                             context:context];
            
            return nil;
        }
        
        for (MSIDTokenCacheItem *cacheItem in tokens)
        {
            /*
             This is an additional fallback for cases, when legacy user ID is not known, but uid and utid are available
             In that case, token is matched by uid and utid instead.
             */
            if (!useLegacy && ![cacheItem.uniqueUserId isEqualToString:account.userIdentifier])
            {
                continue;
            }
            
            [self stopTelemetryEvent:event
                            withItem:cacheItem
                             success:YES
                             context:context];
            
            cacheItem.authority = authority;
            return cacheItem;
        }
    }
    
    [self stopTelemetryEvent:event
                    withItem:nil
                     success:NO
                     context:context];
    
    return nil;
}

- (BOOL)saveToken:(MSIDBaseToken *)token
          account:(MSIDAccount *)account
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    if (![self checkUserIdentifier:account context:context error:error])
    {
        return NO;
    }
    
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                           context:context];
    
    NSURL *newAuthority = [[MSIDAadAuthorityCache sharedInstance] cacheUrlForAuthority:token.authority context:context];
    
    // The authority used to retrieve the item over the network can differ from the preferred authority used to
    // cache the item. As it would be awkward to cache an item using an authority other then the one we store
    // it with we switch it out before saving it to cache.
    token.authority = newAuthority;
    
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey keyWithAuthority:newAuthority
                                                                    clientId:cacheItem.clientId
                                                                    resource:cacheItem.target
                                                                legacyUserId:account.legacyUserId];
    
    BOOL result = [self.dataSource saveToken:cacheItem
                                         key:key
                                  serializer:_serializer
                                     context:context
                                       error:error];
    
    [self stopTelemetryEvent:event
                    withItem:cacheItem
                     success:result
                     context:context];
    
    return result;
}

#pragma mark - Telemetry helpers

- (void)stopTelemetryEvent:(MSIDTelemetryCacheEvent *)event
                  withItem:(MSIDTokenCacheItem *)tokenCacheItem
                   success:(BOOL)success
                   context:(id<MSIDRequestContext>)context
{
    [event setStatus:success ? MSID_TELEMETRY_VALUE_SUCCEEDED : MSID_TELEMETRY_VALUE_FAILED];
    
    if (tokenCacheItem)
    {
        [event setCacheItem:tokenCacheItem];
    }

    [[MSIDTelemetry sharedInstance] stopEvent:[context telemetryRequestId]
                                        event:event];
}

@end
