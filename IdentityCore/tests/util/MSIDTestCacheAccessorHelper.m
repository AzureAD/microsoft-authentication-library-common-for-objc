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

#import "MSIDTestCacheAccessorHelper.h"
#import "MSIDCacheAccessor.h"
#import "MSIDCredentialType.h"
#import "MSIDLegacyAccessToken.h"
#import "MSIDLegacyRefreshToken.h"
#import "MSIDIdToken.h"
#import "MSIDLegacySingleResourceToken.h"

@implementation MSIDTestCacheAccessorHelper

+ (NSArray *)getAllLegacyAccessTokens:(id<MSIDCacheAccessor>)cacheAccessor
{
    return [self getAllTokens:cacheAccessor type:MSIDAccessTokenType class:MSIDLegacyAccessToken.class];
}

+ (NSArray *)getAllLegacyRefreshTokens:(id<MSIDCacheAccessor>)cacheAccessor
{
    return [self getAllTokens:cacheAccessor type:MSIDRefreshTokenType class:MSIDLegacyRefreshToken.class];
}

+ (NSArray *)getAllLegacyTokens:(id<MSIDCacheAccessor>)cacheAccessor
{
    return [self getAllTokens:cacheAccessor type:MSIDLegacySingleResourceTokenType class:MSIDLegacySingleResourceToken.class];
}

+ (NSArray *)getAllDefaultAccessTokens:(id<MSIDCacheAccessor>)cacheAccessor
{
    return [self getAllTokens:cacheAccessor type:MSIDAccessTokenType class:MSIDAccessToken.class];
}

+ (NSArray *)getAllDefaultRefreshTokens:(id<MSIDCacheAccessor>)cacheAccessor
{
    return [self getAllTokens:cacheAccessor type:MSIDRefreshTokenType class:MSIDRefreshToken.class];
}

+ (NSArray *)getAllIdTokens:(id<MSIDCacheAccessor>)cacheAccessor
{
    return [self getAllTokens:cacheAccessor type:MSIDIDTokenType class:MSIDIdToken.class];
}

+ (NSArray *)getAllTokens:(id<MSIDCacheAccessor>)cacheAccessor type:(MSIDCredentialType)type class:(Class)typeClass
{
    NSError *error = nil;
    
    NSArray *allTokens = [cacheAccessor allTokensWithContext:nil error:&error];
    if (error) return nil;
    
    NSMutableArray *results = [NSMutableArray array];
    
    for (MSIDBaseToken *token in allTokens)
    {
        if ([token supportsCredentialType:type]
            && [token isKindOfClass:typeClass])
        {
            [results addObject:token];
        }
    }
    
    return results;
}

@end
