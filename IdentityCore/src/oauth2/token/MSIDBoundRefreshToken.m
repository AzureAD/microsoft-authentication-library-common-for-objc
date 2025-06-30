//
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

#import "MSIDBoundRefreshToken.h"
#import "MSIDBoundRefreshTokenCacheItem.h"

@implementation MSIDBoundRefreshToken

- (instancetype)initWithRefreshToken:(MSIDRefreshToken *)refreshToken
                       boundDeviceId:(NSString *)boundDeviceId
{
    if (refreshToken && ![NSString msidIsStringNilOrBlank:boundDeviceId])
    {
        MSIDBoundRefreshToken *boundRefreshToken = [MSIDBoundRefreshToken new];
        boundRefreshToken.refreshToken = refreshToken.refreshToken;
        boundRefreshToken.boundDeviceId = boundDeviceId;
        boundRefreshToken.familyId = refreshToken.familyId;
        boundRefreshToken.storageEnvironment = refreshToken.storageEnvironment;
        boundRefreshToken.environment = refreshToken.environment;
        boundRefreshToken.realm = refreshToken.realm;
        boundRefreshToken.clientId = refreshToken.clientId;
        boundRefreshToken.additionalServerInfo = refreshToken.additionalServerInfo;
        boundRefreshToken.accountIdentifier = refreshToken.accountIdentifier;
        boundRefreshToken.speInfo = refreshToken.speInfo;
        self = boundRefreshToken;
        return self;
    }

    return nil;
}

- (instancetype)initWithTokenCacheItem:(MSIDCredentialCacheItem *)tokenCacheItem
{
    self = [super initWithTokenCacheItem:tokenCacheItem];
    
    if (self)
    {
        NSDictionary *jsonDictionary = tokenCacheItem.jsonDictionary;
        _boundDeviceId = [jsonDictionary msidObjectForKey:MSID_BOUND_DEVICE_ID_CACHE_KEY ofClass:[NSString class]];
        if ([NSString msidIsStringNilOrBlank:_boundDeviceId])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create bound refresh token: bound device ID is nil or blank.");
            return nil;
        }
    }
    
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDBoundRefreshToken *item = [super copyWithZone:zone];
    item.boundDeviceId = [self.boundDeviceId copyWithZone:zone];
    return item;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }

    if (![object isKindOfClass:MSIDBoundRefreshToken.class])
    {
        return NO;
    }

    return [self isEqualToItem:(MSIDBoundRefreshToken *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.boundDeviceId.hash;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDBoundRefreshToken *)token
{
    if (!token)
    {
        return NO;
    }

    BOOL result = [super isEqualToItem:token];
    result &= (!self.boundDeviceId && !token.boundDeviceId) || [self.boundDeviceId isEqualToString:token.boundDeviceId];
    return result;
}

#pragma mark - Cache

- (MSIDCredentialCacheItem *)tokenCacheItem
{
    MSIDCredentialCacheItem *cacheItem = [super tokenCacheItem];
    NSError *error;
    if (!self.boundDeviceId)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create bound refresh token cache item from base cache item: %@", error.description);
        return nil;
    }
    cacheItem.boundDeviceId = self.boundDeviceId;
    return cacheItem;
}

#pragma mark - Token type

- (MSIDCredentialType)credentialType
{
    return MSIDBoundRefreshTokenType;
}

#pragma mark - Description

- (NSString *)description
{
    NSString *baseDescription = [super description];
    return [baseDescription stringByAppendingFormat:@"(bound refresh token=%@, bound device ID=%@)", [_refreshToken msidSecretLoggingHash], _boundDeviceId];
}

@end
