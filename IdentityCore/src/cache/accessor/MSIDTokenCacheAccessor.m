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

#import "MSIDTokenCacheAccessor.h"
#import "MSIDJsonSerializer.h"
#import "MSIDAccount.h"
#import "MSIDTokenCacheKey.h"
#import "MSIDToken.h"

@interface MSIDTokenCacheAccessor()
{
    NSURL * _authority;
    
    NSArray<id<MSIDSharedTokenCacheAccessor>> *_cacheFormats;
    id<MSIDTokenCacheDataSource> _dataSource;
    
    MSIDJsonSerializer *_serializer;
}

@end

@implementation MSIDTokenCacheAccessor


#pragma mark - Init
- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
                         authority:(NSURL *)authority
                      cacheFormats:(NSArray<id<MSIDSharedTokenCacheAccessor>> *)cacheFormats
{
    if (!(self = [super init]))
    {
        return nil;
    }
    _dataSource = dataSource;
    _authority = authority;
    _cacheFormats = cacheFormats;
    
    return self;
}

#pragma mark - MSAL AT
- (BOOL)saveAT:(MSIDToken *)msalAT
     authority:(NSURL *)authority
      clientId:(NSString *)clientId
       account:(MSIDAccount *)account
        scopes:(NSOrderedSet<NSString *> *)scopes
       context:(id<MSIDRequestContext>)context
         error:(NSError *__autoreleasing *)error
{
    if (!account || !account.userIdentifier)
    {
        return NO;
    }
    
    // delete all cache entries with intersecting scopes
    // this should not happen but we have this as a safe guard against multiple matches
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForAllAccessTokensWithUserId:account.userIdentifier
                                                                    environment:authority.msidHostWithPortIfNecessary];
    
    NSArray<MSIDToken *> *allTokens = [_dataSource itemsWithKey:key serializer:_serializer context:context error:error];
    
    if (!allTokens)
    {
        
        return NO;
    }
    
    for (MSIDToken *token in allTokens)
    {
        if (token.tokenType == MSIDTokenTypeAccessToken
            && [token.authority msidIsEquivalentAuthority:msalAT.authority]
            && [token.scopes intersectsOrderedSet:msalAT.scopes])
        {
            MSIDTokenCacheKey *keyToDelete = [MSIDTokenCacheKey keyForAccessTokenWithAuthority:token.authority
                                                                                      clientId:token.clientId
                                                                                        scopes:token.scopes
                                                                                        userId:account.userIdentifier];
            
            if(![_dataSource removeItemsWithKey:keyToDelete context:context error:nil])
            {
                return NO;
            }
        }
    }
    
    MSIDTokenCacheKey *atKey = [MSIDTokenCacheKey keyForAccessTokenWithAuthority:authority
                                                                        clientId:clientId
                                                                          scopes:scopes
                                                                          userId:account.userIdentifier];
    
    return [_dataSource setItem:msalAT
                            key:atKey
                     serializer:_serializer
                        context:context
                          error:error];
}

- (MSIDToken *)getATwithAuthority:(NSURL *)authority
                         clientId:(NSString *)clientId
                           scopes:(NSOrderedSet<NSString *> *)scopes
                          account:(MSIDAccount *)account
                          context:(id<MSIDRequestContext>)context
                            error:(NSError *__autoreleasing *)error
{
    if (!account || !account.userIdentifier)
    {
        return nil;
    }
    
    // delete all cache entries with intersecting scopes
    // this should not happen but we have this as a safe guard against multiple matches
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForAllAccessTokensWithUserId:account.userIdentifier
                                                                    environment:authority.msidHostWithPortIfNecessary];
    
    NSArray<MSIDToken *> *allTokens = [_dataSource itemsWithKey:key serializer:_serializer context:context error:error];
    
    BOOL anyAccessToken = NO;
    for (MSIDToken *token in allTokens)
    {
        if (token.tokenType == MSIDTokenTypeAccessToken)
        {
            anyAccessToken = YES;
        }
    }
    
    if (!anyAccessToken)
    {
        // This should be rare-to-never as having a MSALUser object requires having a RT in cache,
        // which should imply that at some point we got an AT for that user with this client ID
        // as well. Unless users start working cross client id of course.
        MSID_LOG_WARN(context, @"No access token found for user & client id.");
        MSID_LOG_WARN_PII(context, @"No access token found for user & client id.");
        
        return nil;
    }
    
    NSURL *foundAuthority = allTokens[0].authority;
    
    NSMutableArray<MSIDToken *> *matchedTokens = [NSMutableArray<MSIDToken *> new];
    
    for (MSIDToken *token in allTokens)
    {
        if (authority && ![authority msidIsEquivalentAuthority:token.authority])
        {
            continue;
        }
        if (![foundAuthority msidIsEquivalentAuthority:token.authority])
        {
            // Todo: add macro and handle error
            return nil;
        }
        if (![scopes isSubsetOfOrderedSet:token.scopes])
        {
            continue;
        }
        
        [matchedTokens addObject:token];
    }
    
    if (matchedTokens.count == 0)
    {
        MSID_LOG_INFO(context, @"No matching access token found.");
        MSID_LOG_INFO_PII(context, @"No matching access token found.");
        return nil;
    }
    
    if ([matchedTokens[0] isExpired])
    {
        MSID_LOG_INFO(context, @"Access token found in cache is already expired.");
        MSID_LOG_INFO_PII(context, @"Access token found in cache is already expired.");
        return nil;
    }
    
    return matchedTokens[0];
}

#pragma mark - MSIDOauth2TokenCache
- (BOOL)saveTokensWithRequest:(MSIDTokenRequest *)request response:(MSIDTokenResponse *)response context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error
{
    if (response.error)
    {
        if (error)
        {
            MSIDErrorCode code = MSIDErrorCodeForOAuthError(response.error, MSIDErrorInteractionRequired);
            *error = MSIDCreateError(MSIDErrorDomain, code, response.errorDescription, response.error, nil, nil, nil, nil);
        }
        return NO;
    }
    
    
    return NO;
}

- (BOOL)saveTokensWithBrokerResponse:(MSIDBrokerResponse *)response context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error
{
    return NO;
}

#pragma mark - MSIDSharedTokenCacheAccessor
- (BOOL)saveRTForAccount:(MSIDAccount *)account
            refreshToken:(MSIDToken *)refreshToken
               authority:(NSURL *)authority
                 context:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    if (!account || !account.userIdentifier)
    {
        return NO;
    }
    
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForRefreshTokenWithUserId:account.userIdentifier
                                                                    clientId:refreshToken.clientId
                                                                 environment:refreshToken.authority.msidHostWithPortIfNecessary];
    return [_dataSource setItem:refreshToken
                            key:key
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
    if (!account || !account.userIdentifier)
    {
        return nil;
    }
    
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForRefreshTokenWithUserId:account.userIdentifier
                                                                    clientId:clientId
                                                                 environment:authority.msidHostWithPortIfNecessary];
    return [_dataSource itemWithKey:key serializer:_serializer context:context error:error];
}

- (MSIDToken *)getFRTForAccount:(MSIDAccount *)account
                       familyId:(NSString *)familyId
                      authority:(NSURL *)authority
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error;
{
    return nil;
}

@end
