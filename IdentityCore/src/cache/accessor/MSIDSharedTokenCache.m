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

#import "MSIDSharedTokenCache.h"
#import "MSIDTokenCacheKey.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDAccount.h"
#import "MSIDAdfsToken.h"

@interface MSIDSharedTokenCache()
{
    // Primary cache accessor
    id<MSIDSharedCacheAccessor> _primaryAccessor;
    
    // All shared accessors starting with the primary
    NSArray<id<MSIDSharedCacheAccessor>> *_allAccessors;
}

@end

@implementation MSIDSharedTokenCache

#pragma mark - Init

- (instancetype)initWithPrimaryCacheAccessor:(id<MSIDSharedCacheAccessor>)primaryAccessor
                         otherCacheAccessors:(NSArray<id<MSIDSharedCacheAccessor>> *)otherAccessors
{
    self = [super init];
    
    if (self)
    {
        _primaryAccessor = primaryAccessor;
        
        NSMutableArray *allFormatsArray = [@[primaryAccessor] mutableCopy];
        [allFormatsArray addObjectsFromArray:otherAccessors];
        _allAccessors = allFormatsArray;
    }
    
    return self;
}

#pragma mark - Save tokens

- (BOOL)saveTokensWithRequestParams:(MSIDRequestParameters *)requestParams
                           response:(MSIDTokenResponse *)response
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    MSIDAccount *account = [[MSIDAccount alloc] initWithTokenResponse:response];
    
    if (response.isMultiResource)
    {
        // Save access token item in the primary format
        MSIDToken *accessToken = [[MSIDToken alloc] initWithTokenResponse:response
                                                                  request:requestParams
                                                                tokenType:MSIDTokenTypeAccessToken];
        
        BOOL result = [_primaryAccessor saveAccessToken:accessToken
                                              account:account
                                        requestParams:requestParams
                                              context:context
                                                error:error];
        
        if (!result)
        {
            return NO;
        }
        
        // Create a refresh token item
        MSIDToken *refreshToken = [[MSIDToken alloc] initWithTokenResponse:response
                                                                   request:requestParams
                                                                 tokenType:MSIDTokenTypeRefreshToken];
        
        // Save RTs in all formats
        result = [self saveRefreshTokenInAllCaches:refreshToken
                                       withAccount:account
                                           context:context
                                             error:error];
        
        if (!result || [NSString msidIsStringNilOrBlank:refreshToken.familyId])
        {
            // If saving failed or it's not an FRT, we're done
            return result;
        }
        
        // If it's an FRT, save it separately and update the clientId of the token item
        MSIDToken *familyRefreshToken = [refreshToken copy];
        familyRefreshToken.clientId = [MSIDTokenCacheKey familyClientId:refreshToken.familyId];
        
        return [self saveRefreshTokenInAllCaches:familyRefreshToken
                                     withAccount:account
                                         context:context
                                           error:error];
    }
    else
    {
        MSIDAdfsToken *adfsToken = [[MSIDAdfsToken alloc] initWithTokenResponse:response
                                                                        request:requestParams
                                                                      tokenType:MSIDTokenTypeAdfsUserToken];
        
        MSIDAccount *adfsAccount = [[MSIDAccount alloc] initWithUpn:@""
                                                               utid:nil
                                                                uid:nil];
        
        // Save token for ADFS
        return [_primaryAccessor saveAccessToken:adfsToken
                                       account:adfsAccount
                                 requestParams:requestParams
                                       context:context
                                         error:error];
    }
}

- (BOOL)saveRefreshTokenInAllCaches:(MSIDToken *)refreshToken
                        withAccount:(MSIDAccount *)account
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    // Save RTs in all formats including primary
    for (id<MSIDSharedCacheAccessor> cache in _allAccessors)
    {
        BOOL result = [cache saveSharedRTForAccount:account
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

- (BOOL)saveTokensWithBrokerResponse:(MSIDBrokerResponse *)response
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSIDRequestParameters *params = [[MSIDRequestParameters alloc] initWithAuthority:[NSURL URLWithString:response.authority]
                                                                         redirectUri:nil
                                                                            clientId:response.clientId];
    
    return [self saveTokensWithRequestParams:params
                                    response:response.tokenResponse
                                     context:context
                                       error:error];
}

#pragma mark - Get tokens

- (MSIDToken *)getATForAccount:(MSIDAccount *)account
                 requestParams:(MSIDRequestParameters *)parameters
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    return [_primaryAccessor getATForAccount:account
                             requestParams:parameters
                                   context:context
                                     error:error];
}

- (MSIDAdfsToken *)getADFSTokenWithRequestParams:(MSIDRequestParameters *)parameters
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    return [_primaryAccessor getADFSTokenWithRequestParams:parameters
                                                   context:context
                                                     error:error];
}

- (MSIDToken *)getRTForAccount:(MSIDAccount *)account
                 requestParams:(MSIDRequestParameters *)parameters
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    NSError *cacheError = nil;
    
    // try all caches in order starting with the primary
    for (id<MSIDSharedCacheAccessor> cache in _allAccessors)
    {
        MSIDToken *token = [cache getSharedRTForAccount:account
                                          requestParams:parameters
                                                context:context
                                                  error:&cacheError];
        
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


- (MSIDToken *)getFRTforAccount:(MSIDAccount *)account
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

- (NSArray<MSIDToken *> *)getAllClientRTs:(NSString *)clientId
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    NSMutableArray *resultRTs = [NSMutableArray array];
    
    // Get RTs from all caches
    for (id<MSIDSharedCacheAccessor> cache in _allAccessors)
    {
        NSArray *otherRTs = [cache getAllSharedRTsWithClientId:clientId
                                                       context:context
                                                         error:error];
        
        if (otherRTs)
        {
            [resultRTs addObjectsFromArray:otherRTs];
        }
    }
    
    return resultRTs;
}

- (BOOL)removeRTForAccount:(MSIDAccount *)account
                     token:(MSIDToken *)token
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    
    
    return [_primaryAccessor removeSharedRTForAccount:account
                                                token:token
                                              context:context
                                                error:error];
}

@end
