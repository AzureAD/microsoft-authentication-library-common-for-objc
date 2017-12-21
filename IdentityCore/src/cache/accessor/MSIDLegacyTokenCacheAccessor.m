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

@interface MSIDLegacyTokenCacheAccessor()
{
    NSArray<id<MSIDSharedCacheFormat>> *_cacheFormats;
    id<MSIDTokenCacheDataSource> _dataSource;
    
    MSIDKeyedArchiverSerializer *_serializer;
    MSIDKeyedArchiverSerializer *_adfsSerializer;
}

@end

@implementation MSIDLegacyTokenCacheAccessor

#pragma mark - Init

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
                      cacheFormats:(NSArray<id<MSIDSharedCacheFormat>> *)cacheFormats
{
    self = [super init];
    
    if (self)
    {
        _dataSource = dataSource;
        _cacheFormats = cacheFormats;
        _serializer = [[MSIDKeyedArchiverSerializer alloc] init];
        _adfsSerializer = [[MSIDKeyedArchiverSerializer alloc] initWithClassName:MSIDAdfsToken.class];
    }
    
    return self;
}

#pragma mark - MSIDOauth2TokenCache

- (BOOL)saveTokensWithRequest:(MSIDTokenRequest *)request
                     response:(MSIDTokenResponse *)response
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithTokenResponse:response];
    
    if (response.isMultiResource)
    {
        // Save ADAL access token item
        MSIDToken *accessToken = [[MSIDToken alloc] initWithTokenResponse:response
                                                                  request:request
                                                                tokenType:MSIDTokenTypeAccessToken];
        
        BOOL result = [self saveToken:accessToken
                              account:account
                             clientId:request.clientId
                           serializer:_serializer
                              context:context
                                error:error];
        
        if (!result)
        {
            return NO;
        }
        
        // Create ADAL refresh token item
        MSIDToken *refreshToken = [[MSIDToken alloc] initWithTokenResponse:response
                                                                   request:request
                                                                 tokenType:MSIDTokenTypeRefreshToken];
        
        result = [self saveSharedRTForAccount:account
                                 refreshToken:refreshToken
                                      context:context
                                        error:error];
        
        if (!result)
        {
            return NO;
        }
        
        // Save RTs in other formats if any
        for (id<MSIDSharedCacheFormat> cache in _cacheFormats)
        {
            result = [cache saveSharedRTForAccount:account
                                      refreshToken:refreshToken
                                           context:context
                                             error:error];
            
            if (!result)
            {
                return NO;
            }
        }
        
        return YES;
    }
    else
    {
        MSIDAdfsToken *adfsToken = [[MSIDAdfsToken alloc] initWithTokenResponse:response
                                                                        request:request
                                                                      tokenType:MSIDTokenTypeAdfsUserToken];
        
        MSIDAccount *adfsAccount = [[MSIDAccount alloc] initWithUpn:@""
                                                               utid:nil
                                                                uid:nil];
        
        // Save token for ADFS
        return [self saveToken:adfsToken
                       account:adfsAccount
                      clientId:request.clientId
                    serializer:_adfsSerializer
                       context:context
                         error:error];
    }
}

- (BOOL)saveTokensWithBrokerResponse:(MSIDBrokerResponse *)response
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSIDTokenRequest *request = [[MSIDTokenRequest alloc] initWithAuthority:[NSURL URLWithString:response.authority]
                                                                redirectUri:nil
                                                                   clientId:response.clientId];
    
    return [self saveTokensWithRequest:request
                              response:response.tokenResponse
                               context:context
                                 error:error];
}

- (MSIDToken *)getRTForAccount:(MSIDAccount *)account
                     authority:(NSURL *)authority
                      clientId:(NSString *)clientId
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    MSIDToken *token = [self getSharedRTForAccount:account
                                         authority:authority
                                          clientId:clientId
                                           context:context
                                             error:error];
    
    // Found token from the current cache, return immediately
    if (token)
    {
        return token;
    }
    // No token was found from the current cache and we got an error, don't try other caches
    else if (error)
    {
        return nil;
    }
    
    // Try other caches
    for (id<MSIDSharedCacheFormat> cache in _cacheFormats)
    {
        MSIDToken *token = [cache getSharedRTForAccount:account
                                              authority:authority
                                               clientId:clientId
                                                context:context
                                                  error:error];
        
        if (token)
        {
            return token;
        }
        
        if (error)
        {
            return nil;
        }
    }
    
    return nil;
}


- (MSIDToken *)getFRTforAccount:(MSIDAccount *)account
                      authority:(NSURL *)authority
                       familyId:(NSString *)familyId
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    return [self getRTForAccount:account
                       authority:authority
                        clientId:[MSIDTokenCacheKey familyClientId:familyId]
                         context:context
                           error:error];
}

- (NSArray<MSIDToken *> *)getAllRTsForClientId:(NSString *)clientId
                                       context:(id<MSIDRequestContext>)context
                                         error:(NSError **)error
{
    // TODO: implement me
    return nil;
}

- (BOOL)removeRTForAccount:(MSIDAccount *)account
                    token:(MSIDToken *)token
                  context:(id<MSIDRequestContext>)context
                    error:(NSError **)error
{
    if (!token || token.tokenType != MSIDTokenTypeRefreshToken)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Removing tokens can be done only as a result of a token request. Valid refresh token should be provided.", nil, nil, nil, context.correlationId, nil);
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

#pragma mark - MSIDSharedCacheFormat

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
                           authority:(NSURL *)authority
                            clientId:(NSString *)clientId
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    return [self getItemForAccount:account
                         authority:authority
                          clientId:clientId
                          resource:nil
                           context:context
                             error:error];
}

- (NSArray<MSIDToken *> *)getAllSharedRTsForClientId:(NSString *)clientId
                                             context:(id<MSIDRequestContext>)context
                                               error:(NSError **)error
{
    // TODO: implement me
    return nil;
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
    
    NSURL *newAthority = token.authority; // TODO: replace with an actual authority
    
    // The authority used to retrieve the item over the network can differ from the preferred authority used to
    // cache the item. As it would be awkward to cache an item using an authority other then the one we store
    // it with we switch it out before saving it to cache.
    token.authority = newAthority;
    
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:newAthority
                                                        clientId:clientId
                                                        resource:token.resource
                                                             upn:account.upn];
    
    BOOL result = [_dataSource setItem:token key:key serializer:serializer context:context error:error];
    
    [self stopTelemetryEvent:event
                   withToken:token
                     context:context];
    
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
                             context:context];
            
            return nil;
        }
    }
    
    [self stopTelemetryEvent:event
                   withToken:nil
                     context:context];
    
    return nil;
}

#pragma mark - ADAL methods

- (MSIDToken *)getATRTItemForAccount:(MSIDAccount *)account
                           authority:(NSURL *)authority
                            resource:(NSString *)resource
                            clientId:(NSString *)clientId
                             context:(id<MSIDRequestContext>)context
                               error:(NSError * __autoreleasing *)error
{
    return [self getItemForAccount:account
                         authority:authority
                          clientId:clientId
                          resource:resource
                           context:context
                             error:error];
}


- (MSIDToken *)getADFSUserTokenForResource:(NSString *)resource
                                 authority:(NSURL *)authority
                                  clientId:(NSString *)clientId
                                   context:(id<MSIDRequestContext>)context
                                     error:(NSError * __autoreleasing *)error
{
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForAdfsUserTokenWithAuthority:authority
                                                                        clientId:clientId
                                                                        resource:resource];
    return [_dataSource itemWithKey:key
                         serializer:_adfsSerializer
                            context:context
                              error:error];
}

#pragma mark - Telemetry helpers

- (void)stopTelemetryEvent:(MSIDTelemetryCacheEvent *)event
                 withToken:(MSIDToken *)token
                   context:(id<MSIDRequestContext>)context
{
    if (token)
    {
        [event setTokenType:token.tokenType];
        [event setStatus:MSID_TELEMETRY_VALUE_SUCCEEDED];
        [event setSpeInfo:token.additionalServerInfo[MSID_TELEMETRY_KEY_SPE_INFO]];
        
        if (![NSString msidIsStringNilOrBlank:token.familyId])
        {
            [event setIsFRT:MSID_TELEMETRY_VALUE_YES];
        }
    }
    else
    {
        [event setStatus:MSID_TELEMETRY_VALUE_FAILED];
    }
    
    [[MSIDTelemetry sharedInstance] stopEvent:[context telemetryRequestId]
                                        event:event];
}

@end
