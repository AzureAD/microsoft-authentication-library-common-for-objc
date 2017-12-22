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
    // Primary cache format
    id<MSIDSharedCacheFormat> _primaryFormat;
    
    // All shared formats starting with the primary
    NSArray<id<MSIDSharedCacheFormat>> *_allFormats;
}

@end

@implementation MSIDSharedTokenCache

#pragma mark - Init

- (instancetype)initWithPrimaryCacheFormat:(id<MSIDSharedCacheFormat>)primaryFormat
                         otherCacheFormats:(NSArray<id<MSIDSharedCacheFormat>> *)cacheFormats
{
    self = [super init];
    
    if (self)
    {
        _primaryFormat = primaryFormat;
        
        NSMutableArray *allFormatsArray = [@[primaryFormat] mutableCopy];
        [allFormatsArray addObjectsFromArray:cacheFormats];
        _allFormats = allFormatsArray;
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
        // Save ADAL access token item
        MSIDToken *accessToken = [[MSIDToken alloc] initWithTokenResponse:response
                                                                  request:requestParams
                                                                tokenType:MSIDTokenTypeAccessToken];
        
        BOOL result = [_primaryFormat saveAccessToken:accessToken
                                              account:account
                                        requestParams:requestParams
                                              context:context
                                                error:error];
        
        if (!result)
        {
            return NO;
        }
        
        // Create ADAL refresh token item
        MSIDToken *refreshToken = [[MSIDToken alloc] initWithTokenResponse:response
                                                                   request:requestParams
                                                                 tokenType:MSIDTokenTypeRefreshToken];
        
        // Save RTs in other formats if any
        for (id<MSIDSharedCacheFormat> cache in _allFormats)
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
                                                                        request:requestParams
                                                                      tokenType:MSIDTokenTypeAdfsUserToken];
        
        MSIDAccount *adfsAccount = [[MSIDAccount alloc] initWithUpn:@""
                                                               utid:nil
                                                                uid:nil];
        
        // Save token for ADFS
        return [_primaryFormat saveAccessToken:adfsToken
                                       account:adfsAccount
                                 requestParams:requestParams
                                       context:context
                                         error:error];
    }
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
    return [_primaryFormat getATForAccount:account
                             requestParams:parameters
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
    for (id<MSIDSharedCacheFormat> cache in _allFormats)
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

- (NSArray<MSIDToken *> *)getAllClientRTsWithParams:(MSIDRequestParameters *)parameters
                                            context:(id<MSIDRequestContext>)context
                                              error:(NSError **)error
{
    NSMutableArray *resultRTs = [NSMutableArray array];
    
    // Get RTs from all caches
    for (id<MSIDSharedCacheFormat> cache in _allFormats)
    {
        NSArray *otherRTs = [cache getAllSharedClientRTsWithParams:parameters
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
    return [_primaryFormat removeRTForAccount:account
                                        token:token
                                      context:context
                                        error:error];
}

@end
