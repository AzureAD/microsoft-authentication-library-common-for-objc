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

#import "MSIDBaseTokenCache.h"
#import "MSIDRefreshToken.h"
#import "MSIDTokenCacheKey.h"
#import "MSIDBrokerResponse.h"
#import "MSIDRequestParameters.h"

@interface MSIDBaseTokenCache()

@property (nonatomic) id<MSIDTokenCacheDataSource> dataSource;
@property (nonatomic) NSArray<id<MSIDSSOStateShareable>> *allAccessors;

@end

@implementation MSIDBaseTokenCache

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
                secondaryAccessors:(NSArray<id<MSIDSSOStateShareable>> *)secondaryAccessors;
{
    self = [super init];
    
    if (self)
    {
        _dataSource = dataSource;
        // TODO: possible memory leak.
        NSMutableArray *allAccessors = [@[self] mutableCopy];
        if (secondaryAccessors)
        {
            [allAccessors addObjectsFromArray:secondaryAccessors];
        }
        _allAccessors = allAccessors;
    }
    
    return self;
}

#pragma mark - Save methods

- (BOOL)saveTokensWithRequestParams:(MSIDRequestParameters *)requestParams
                           response:(MSIDTokenResponse *)response
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    assert(false);
    return NO;
}

- (BOOL)saveTokensWithBrokerResponse:(MSIDBrokerResponse *)response
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSIDRequestParameters *params = [[MSIDRequestParameters alloc] initWithAuthority:[NSURL URLWithString:response.authority]
                                                                         redirectUri:nil
                                                                            clientId:response.clientId
                                                                              target:response.resource];
    
    return [self saveTokensWithRequestParams:params
                                    response:response.tokenResponse
                                     context:context
                                       error:error];
}

- (BOOL)saveRefreshToken:(MSIDRefreshToken *)refreshToken
             withAccount:(MSIDAccount *)account
                 context:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    // Save RTs in all formats.
    BOOL result = [self saveRefreshTokenInAllCaches:refreshToken
                                   withAccount:account
                                       context:context
                                         error:error];
    
    if (!result || [NSString msidIsStringNilOrBlank:refreshToken.familyId])
    {
        // If saving failed or it's not an FRT, we're done.
        return result;
    }
    
    // If it's an FRT, save it separately and update the clientId of the token item.
    MSIDRefreshToken *familyRefreshToken = [refreshToken copy];
    familyRefreshToken.clientId = [MSIDTokenCacheKey familyClientId:refreshToken.familyId];
    
    return [self saveRefreshTokenInAllCaches:familyRefreshToken
                                 withAccount:account
                                     context:context
                                       error:error];
}

#pragma mark - Get methods

- (MSIDAccessToken *)getATForAccount:(MSIDAccount *)account
                       requestParams:(MSIDRequestParameters *)parameters
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    assert(false);
    return nil;
}

- (MSIDRefreshToken *)getRTForAccount:(MSIDAccount *)account
                        requestParams:(MSIDRequestParameters *)parameters
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    NSError *cacheError = nil;
    
    // try all caches in order starting with the primary
    for (id<MSIDSSOStateShareable> cache in self.allAccessors)
    {
        MSIDRefreshToken *token = [cache getSSOTokenWithAccount:account
                                                  requestParams:parameters
                                                        context:context
                                                          error:error];
        
        if (token)
        {
            return token;
        }
        else if (cacheError)
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

- (MSIDRefreshToken *)getFRTforAccount:(MSIDAccount *)account
                         requestParams:(MSIDRequestParameters *)parameters
                              familyId:(NSString *)familyId
                               context:(id<MSIDRequestContext>)context
                                 error:(NSError **)error
{
    parameters.clientId = [MSIDTokenCacheKey familyClientId:familyId];
    
    return [self getRTForAccount:account
                   requestParams:parameters
                         context:context
                           error:error];
}

- (NSArray<MSIDRefreshToken *> *)getAllClientRTs:(NSString *)clientId
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    NSMutableArray *resultRTs = [NSMutableArray array];
    
    // Get RTs from all caches
    for (id<MSIDSSOStateShareable> cache in self.allAccessors)
    {
        NSArray *otherRTs = [cache getAllSSOTokensWithClientId:clientId context:context error:error];
        
        if (otherRTs)
        {
            [resultRTs addObjectsFromArray:otherRTs];
        }
    }
    
    return resultRTs;
}

#pragma mark - Remove

- (BOOL)removeRTForAccount:(MSIDAccount *)account
                     token:(MSIDBaseToken<MSIDRefreshableToken> *)token
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
    
    MSIDTokenCacheItem *cacheItem = [self getLatestTokenCacheItem:token.tokenCacheItem
                                                          account:account
                                                          context:context
                                                            error:&cacheError];
    
    if (cacheError)
    {
        if (error)
        {
            *error = cacheError;
        }
        return NO;
    }
    
    if (cacheItem && [cacheItem.refreshToken isEqualToString:token.refreshToken])
    {
        return [self removeTokenCacheItem:cacheItem
                         account:account
                         context:context
                           error:error];
    }
    
    return YES;
}

#pragma mark - Protected

- (MSIDTokenCacheItem *)getLatestTokenCacheItem:(MSIDTokenCacheItem *)cacheItem
                                        account:(MSIDAccount *)account
                                        context:(id<MSIDRequestContext>)context
                                          error:(NSError **)error
{
    return nil;
}

- (BOOL)removeTokenCacheItem:(MSIDTokenCacheItem *)cacheItem
                     account:(MSIDAccount *)account
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error
{
    return nil;
}

#pragma mark - Private

- (BOOL)saveRefreshTokenInAllCaches:(MSIDRefreshToken *)refreshToken
                        withAccount:(MSIDAccount *)account
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    
    // Save RTs in all formats.
    for (id<MSIDSSOStateShareable> cache in self.allAccessors)
    {
        BOOL result = [cache saveSSOToken:refreshToken
                                  account:account
                                  context:context
                                    error:error];
        
        if (!result)
        {
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - MSIDSSOStateShareable

- (BOOL)saveSSOToken:(MSIDRefreshToken *)refreshToken
             account:(MSIDAccount *)account
             context:(id<MSIDRequestContext>)context
               error:(NSError **)error
{
    return NO;
}

- (MSIDRefreshToken *)getSSOTokenWithAccount:(MSIDAccount *)account
                               requestParams:(MSIDRequestParameters *)parameters
                                     context:(id<MSIDRequestContext>)context
                                       error:(NSError **)error
{
    return nil;
}

- (NSArray *)getAllSSOTokensWithClientId:(NSString *)clientId
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    return nil;
}

@end
