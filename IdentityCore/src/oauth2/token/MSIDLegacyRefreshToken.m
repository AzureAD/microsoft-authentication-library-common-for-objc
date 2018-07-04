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

#import "MSIDLegacyRefreshToken.h"
#import "MSIDLegacyTokenCacheItem.h"
#import "MSIDAADIdTokenClaimsFactory.h"
#import "MSIDAuthorityFactory.h"
#import "MSIDAuthority.h"

@implementation MSIDLegacyRefreshToken

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDLegacyRefreshToken *item = [super copyWithZone:zone];
    item->_idToken = [_idToken copyWithZone:zone];
    item->_legacyUserId = [_legacyUserId copyWithZone:zone];
    return item;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }

    if (![object isKindOfClass:MSIDLegacyRefreshToken.class])
    {
        return NO;
    }

    return [self isEqualToItem:(MSIDLegacyRefreshToken *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.idToken.hash;
    hash = hash * 31 + self.legacyUserId.hash;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDLegacyRefreshToken *)token
{
    if (!token)
    {
        return NO;
    }

    BOOL result = [super isEqualToItem:token];
    result &= (!self.legacyUserId && !token.legacyUserId) || [self.legacyUserId isEqualToString:token.legacyUserId];
    result &= (!self.idToken && !token.idToken) || [self.idToken isEqualToString:token.idToken];

    return result;
}

#pragma mark - Cache

- (MSIDCredentialCacheItem *)tokenCacheItem
{
    MSIDCredentialCacheItem *cacheItem = [super tokenCacheItem];
    cacheItem.credentialType = MSIDRefreshTokenType;
    return cacheItem;
}

- (instancetype)initWithLegacyTokenCacheItem:(MSIDLegacyTokenCacheItem *)tokenCacheItem
{
    self = [self initWithTokenCacheItem:tokenCacheItem];

    if (self)
    {
        __auto_type authorityFactory = [MSIDAuthorityFactory new];
        __auto_type authority = [authorityFactory authorityFromUrl:tokenCacheItem.authority context:nil error:nil];
        
        _idToken = tokenCacheItem.idToken;
        _authority = authority;
        _refreshToken = tokenCacheItem.refreshToken;

        NSError *error = nil;
        MSIDIdTokenClaims *idTokenClaims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:_idToken error:&error];

        if (error)
        {
            MSID_LOG_WARN(nil, @"Invalid ID token");
            MSID_LOG_WARN_PII(nil, @"Invalid ID token, error %@", error.localizedDescription);
        }

        _legacyUserId = idTokenClaims.userId;
        _realm = idTokenClaims.realm;
    }

    return self;
}

- (MSIDLegacyTokenCacheItem *)legacyTokenCacheItem
{
    MSIDLegacyTokenCacheItem *cacheItem = [MSIDLegacyTokenCacheItem new];
    cacheItem.credentialType = MSIDRefreshTokenType;
    cacheItem.idToken = self.idToken;
    cacheItem.authority = self.storageAuthority.url ? self.storageAuthority.url : self.authority.url;
    cacheItem.environment = self.authority.url.msidHostWithPortIfNecessary;
    cacheItem.realm = self.authority.url.msidTenant;
    cacheItem.clientId = self.clientId;
    cacheItem.clientInfo = self.clientInfo;
    cacheItem.additionalInfo = self.additionalServerInfo;
    cacheItem.homeAccountId = self.homeAccountId;
    cacheItem.refreshToken = self.refreshToken;
    cacheItem.familyId = self.familyId;
    cacheItem.secret = self.refreshToken;
    return cacheItem;
}

- (NSString *)primaryUserId
{
    return self.legacyUserId;
}

#pragma mark - Token type

- (MSIDCredentialType)credentialType
{
    return MSIDRefreshTokenType;
}

#pragma mark - Description

- (NSString *)description
{
    NSString *baseDescription = [super description];
    return [baseDescription stringByAppendingFormat:@"(id token=%@, legacy user ID=%@)", _PII_NULLIFY(_idToken), _legacyUserId];
}

@end
