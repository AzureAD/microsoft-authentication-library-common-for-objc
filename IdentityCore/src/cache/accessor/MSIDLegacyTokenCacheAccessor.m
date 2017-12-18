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

@interface MSIDLegacyTokenCacheAccessor()
{
    NSURL * _authority;
    NSArray<id<MSIDSharedTokenCacheAccessor>> *_cacheFormats;
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDKeyedArchiverSerializer *_serializer;
}

@end

@implementation MSIDLegacyTokenCacheAccessor

#pragma mark - Init

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
                         authority:(NSURL *)authority
                      cacheFormats:(NSArray<id<MSIDSharedTokenCacheAccessor>> *)cacheFormats
{
    self = [super init];
    
    if (self)
    {
        _dataSource = dataSource;
        _authority = authority;
        _cacheFormats = cacheFormats;
        _serializer = [[MSIDKeyedArchiverSerializer alloc] init];
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
        MSIDToken *accessToken = [[MSIDToken alloc] initWithTokenResponse:response
                                                                  request:request
                                                                tokenType:MSIDTokenTypeAccessToken];
        
        MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:request.authority
                                                            clientId:request.clientId
                                                            resource:accessToken.resource
                                                                 upn:account.upn];
        
        BOOL result = [self saveToken:accessToken
                              withKey:key
                              context:context
                                error:error];
        
        if (!result)
        {
            return NO;
        }
        
        MSIDToken *refreshToken = [[MSIDToken alloc] initWithTokenResponse:response
                                                                   request:request
                                                                 tokenType:MSIDTokenTypeRefreshToken];
        
        result = [self saveRTForUser:account
                        refreshToken:refreshToken
                             context:context
                               error:error];
        
        if (!result)
        {
            return NO;
        }
        
        return NO;
    }
    else
    {
        MSIDAdfsToken *adfsToken = [[MSIDAdfsToken alloc] initWithTokenResponse:response
                                                                        request:request
                                                                      tokenType:MSIDTokenTypeAdfsUserToken];
        
        MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForAdfsUserTokenWithAuthority:request.authority
                                                                            clientId:request.clientId
                                                                            resource:adfsToken.resource];
        
        return [self saveToken:adfsToken
                       withKey:key
                       context:context
                         error:error];
    }
}

- (BOOL)saveTokensWithBrokerResponse:(MSIDBrokerResponse *)response
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    return NO;
}

#pragma mark - Helper methods

- (BOOL)saveToken:(MSIDToken *)token
          withKey:(MSIDTokenCacheKey *)key
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    NSURL *oldAuthority = token.authority;
    NSURL *newAthority = token.authority; // TODO: replace with an actual authority
    
    // The authority used to retrieve the item over the network can differ from the preferred authority used to
    // cache the item. As it would be awkward to cache an item using an authority other then the one we store
    // it with we switch it out before saving it to cache.
    token.authority = newAthority;
    BOOL result = [_dataSource setItem:token key:key serializer:_serializer context:context error:error];
    token.authority = oldAuthority;
    
    return result;
}

#pragma mark - MSIDSharedTokenCacheAccessor

- (BOOL)saveRTForUser:(MSIDAccount *)user
         refreshToken:(MSIDToken *)refreshToken
              context:(id<MSIDRequestContext>)context
                error:(NSError **)error
{
    return NO;
}

- (MSIDToken *)getClientRTForUser:(MSIDAccount *)user
                         clientId:(NSString *)clientId
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    return nil;
}

- (MSIDToken *)getFRTForUser:(MSIDAccount *)user
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error
{
    return nil;
}

@end
