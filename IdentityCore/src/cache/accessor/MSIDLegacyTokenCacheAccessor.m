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
    MSIDKeyedArchiverSerializer *_adfsSerializer;
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
        
        result = [self saveRTForAccount:account
                           refreshToken:refreshToken
                              authority:request.authority
                                context:context
                                  error:error];
        
        if (!result)
        {
            return NO;
        }
        
        // Save RTs in other formats if any
        for (id<MSIDSharedTokenCacheAccessor> cache in _cacheFormats)
        {
            result = [cache saveRTForAccount:account
                                refreshToken:refreshToken
                                   authority:request.authority
                                     context:context
                                       error:error];
            
            if (!result)
            {
                return NO;
            }
        }
        
        return NO;
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
    // TODO
    return NO;
}

#pragma mark - MSIDSharedTokenCacheAccessor

- (BOOL)saveRTForAccount:(MSIDAccount *)account
            refreshToken:(MSIDToken *)refreshToken
               authority:(NSURL *)authority
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

- (MSIDToken *)getClientRTForAccount:(MSIDAccount *)account
                           authority:(NSURL *)authority
                            clientId:(NSString *)clientId
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    return [self getItemForAccount:account
                          clientId:clientId
                          resource:nil
                           context:context
                             error:error];
}

- (MSIDToken *)getFRTForAccount:(MSIDAccount *)account
                       familyId:(NSString *)familyId
                      authority:(NSURL *)authority
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    return [self getClientRTForAccount:account
                             authority:authority
                              clientId:[MSIDTokenCacheKey familyClientId:familyId]
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
    NSURL *oldAuthority = token.authority;
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
    
    // Swap the authority back to the original one
    token.authority = oldAuthority;
    
    return result;
}

- (MSIDToken *)getItemForAccount:(MSIDAccount *)account
                        clientId:(NSString *)clientId
                        resource:(NSString *)resource
                         context:(id<MSIDRequestContext>)context
                           error:(NSError **)error
{
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
        
        // TODO: storage authority
        token.authority = _authority;
        
        if (token)
        {
            return token;
        }
        
        if (cacheError)
        {
            if (error)
            {
                *error = cacheError;
            }
            
            return nil;
        }
    }
    
    return nil;
}

#pragma mark - ADAL methods

- (MSIDToken *)getATRTItemForAccount:(MSIDAccount *)account
                            resource:(NSString *)resource
                            clientId:(NSString *)clientId
                             context:(id<MSIDRequestContext>)context
                               error:(NSError * __autoreleasing *)error
{
    return [self getItemForAccount:account
                          clientId:clientId
                          resource:resource
                           context:context
                             error:error];
}

- (MSIDToken *)getMRRTItemForAccount:(MSIDAccount *)account
                            clientId:(NSString *)clientId
                             context:(id<MSIDRequestContext>)context
                               error:(NSError * __autoreleasing *)error
{
    MSIDToken *token = [self getClientRTForAccount:account
                                         authority:_authority
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
    for (id<MSIDSharedTokenCacheAccessor> cache in _cacheFormats)
    {
        MSIDToken *token = [cache getClientRTForAccount:account
                                              authority:_authority
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


- (MSIDToken *)getFRTItemForAccount:(MSIDAccount *)account
                           familyId:(NSString *)familyId
                            context:(id<MSIDRequestContext>)context
                              error:(NSError * __autoreleasing *)error
{
    return [self getMRRTItemForAccount:account
                              clientId:[MSIDTokenCacheKey familyClientId:familyId]
                               context:context
                                 error:error];
}


- (MSIDToken *)getADFSUserTokenForResource:(NSString *)resource
                                  clientId:(NSString *)clientId
                                   context:(id<MSIDRequestContext>)context
                                     error:(NSError * __autoreleasing *)error
{
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForAdfsUserTokenWithAuthority:_authority
                                                                        clientId:clientId
                                                                        resource:resource];
    return [_dataSource itemWithKey:key
                         serializer:_adfsSerializer
                            context:context
                              error:error];
}

@end
