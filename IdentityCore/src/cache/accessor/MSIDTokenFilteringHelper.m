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

#import "MSIDTokenFilteringHelper.h"
#import "MSIDAccessToken.h"
#import "MSIDTokenCacheItem.h"
#import "MSIDAccount.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDConfiguration.h"
#import "MSIDAADIdTokenClaimsFactory.h"


@implementation MSIDTokenFilteringHelper

#pragma mark - Generic

+ (NSArray *)filterTokenCacheItems:(NSArray<MSIDTokenCacheItem *> *)allCacheItems
                         tokenType:(MSIDTokenType)tokenType
                       returnFirst:(BOOL)returnFirst
                          filterBy:(MSIDTokenCacheItemFiltering)tokenFiltering
{
    NSMutableArray *matchedItems = [NSMutableArray new];
    
    for (MSIDTokenCacheItem *cacheItem in allCacheItems)
    {
        if (tokenFiltering && tokenFiltering(cacheItem))
        {
            MSIDBaseToken *token = [cacheItem tokenWithType:tokenType];
            
            if (token)
            {
                [matchedItems addObject:token];
            }
            
            if (returnFirst)
            {
                break;
            }
        }
    }
    
    return matchedItems;
}

#pragma mark - Access token

+ (NSArray<MSIDAccessToken *> *)filterAllAccessTokenCacheItems:(NSArray<MSIDTokenCacheItem *> *)allCacheItems
                                                    withScopes:(NSOrderedSet<NSString *> *)scopes
{
    return [self filterTokenCacheItems:allCacheItems
                             tokenType:MSIDTokenTypeAccessToken
                           returnFirst:YES
                              filterBy:^BOOL(MSIDTokenCacheItem *token) {
        
                                  return [scopes isSubsetOfOrderedSet:[token.target scopeSet]];
    }];
}

+ (NSArray<MSIDAccessToken *> *)filterAllAccessTokenCacheItems:(NSArray<MSIDTokenCacheItem *> *)allItems
                                                withConfiguration:(MSIDConfiguration *)configuration
                                                       account:(MSIDAccount *)account
                                                       context:(id<MSIDRequestContext>)context
                                                         error:(NSError **)error
{
    if (!allItems || [allItems count] == 0)
    {
        // This should be rare-to-never as having a MSIDAccount object requires having a RT in cache,
        // which should imply that at some point we got an AT for that user with this client ID
        // as well. Unless users start working cross client id of course.
        MSID_LOG_WARN(context, @"No access token found for user & client id.");
        MSID_LOG_WARN_PII(context, @"No access token found for user & client id.");
        return nil;
    }
    
    NSURL *authorityToCheck = allItems[0].authority;
    NSArray<NSURL *> *tokenAliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authorityToCheck];
    
    __block NSUInteger differentAuthorities = 1;
    
    BOOL (^filterBlock)(MSIDTokenCacheItem *tokenCacheItem) = ^BOOL(MSIDTokenCacheItem *token) {
        
        if ([token.uniqueUserId isEqualToString:account.uniqueUserId]
            && [token.clientId isEqualToString:configuration.clientId]
            && [configuration.scopes isSubsetOfOrderedSet:[token.target scopeSet]])
        {
            if ([token.authority msidIsEquivalentWithAnyAlias:tokenAliases])
            {
                return YES;
            }
            else differentAuthorities++;
        }
        
        return NO;
        
    };
    
    NSArray *matchedTokens = [self filterTokenCacheItems:allItems
                                               tokenType:MSIDTokenTypeAccessToken
                                             returnFirst:NO
                                                filterBy:filterBlock];
    
    if (differentAuthorities > 1)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorAmbiguousAuthority, @"Found multiple access tokens, which token to return is ambiguous! Please pass in authority if not provided.", nil, nil, nil, context.correlationId, nil);
        }
        
        return nil;
    }
    
    return matchedTokens;
}

#pragma mark - Refresh token

+ (NSArray<MSIDBaseToken *> *)filterRefreshTokenCacheItems:(NSArray<MSIDTokenCacheItem *> *)allItems
                                              legacyUserId:(NSString *)legacyUserId
                                               environment:(NSString *)environment
                                                   context:(id<MSIDRequestContext>)context
{
    BOOL (^filterBlock)(MSIDTokenCacheItem *tokenCacheItem) = ^BOOL(MSIDTokenCacheItem *token) {
        
        if (!token.idToken) return NO;

        MSIDIdTokenClaims *idTokenClaims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:token.idToken];
        
        if (![idTokenClaims matchesLegacyUserId:legacyUserId]
            && [token.authority.msidHostWithPortIfNecessary isEqualToString:environment])
        {
            MSID_LOG_VERBOSE(context, @"(Default accessor) Matching by legacy userId didn't succeed");
            MSID_LOG_VERBOSE_PII(context, @"(Default accessor) Matching by legacy userId didn't succeed (expected userId %@, found %@)", legacyUserId, idTokenClaims.userId);
            
            return NO;
        }
        
        return YES;
    };
    
    NSArray *matchedTokens = [MSIDTokenFilteringHelper filterTokenCacheItems:allItems
                                                                   tokenType:MSIDTokenTypeRefreshToken
                                                                 returnFirst:YES
                                                                    filterBy:filterBlock];
    
    return matchedTokens;
}

@end
