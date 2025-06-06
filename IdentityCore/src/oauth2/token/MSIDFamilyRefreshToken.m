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

#import "MSIDFamilyRefreshToken.h"

@implementation MSIDFamilyRefreshToken

- (instancetype)initWithRefreshToken:(MSIDRefreshToken *)refreshToken
{
    if (refreshToken && [refreshToken isKindOfClass:[MSIDRefreshToken class]])
    {
        MSIDFamilyRefreshToken *frt = [[MSIDFamilyRefreshToken alloc] init];
        
        // MSIDRefreshToken properties
        frt.refreshToken = refreshToken.refreshToken;
        frt.familyId = refreshToken.familyId;
        
        // MSIDBaseToken properties
        frt.storageEnvironment = refreshToken.storageEnvironment;
        frt.environment = refreshToken.environment;
        frt.realm = refreshToken.realm;
        frt.clientId = refreshToken.clientId;
        frt.additionalServerInfo = refreshToken.additionalServerInfo;
        frt.accountIdentifier = refreshToken.accountIdentifier;
        frt.speInfo = refreshToken.speInfo;
        
        self = frt;
    }
    
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDFamilyRefreshToken *item = [super copyWithZone:zone];
    return item;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSIDFamilyRefreshToken.class])
    {
        return NO;
    }
    
    return [self isEqualToItem:(MSIDFamilyRefreshToken *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.refreshToken.hash;
    hash = hash * 31 + self.familyId.hash;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDFamilyRefreshToken *)token
{
    if (!token)
    {
        return NO;
    }
    
    BOOL result = [super isEqualToItem:token];
    result &= (!self.refreshToken && !token.refreshToken) || [self.refreshToken isEqualToString:token.refreshToken];
    result &= (!self.familyId && !token.familyId) || [self.familyId isEqualToString:token.familyId];
    return result;
}

#pragma mark - Cache

- (MSIDCredentialCacheItem *)tokenCacheItem
{
    MSIDCredentialCacheItem *cacheItem = [super tokenCacheItem];
    cacheItem.secret = self.refreshToken;
    cacheItem.familyId = self.familyId;
    cacheItem.realm = nil;
    return cacheItem;
}

#pragma mark - Token type

- (MSIDCredentialType)credentialType
{
    return MSIDFamilyRefreshTokenType;
}

#pragma mark - Description

- (NSString *)description
{
    NSString *baseDescription = [super description];
    return [baseDescription stringByAppendingFormat:@"(family refresh token=%@, family ID=%@)", [_refreshToken msidSecretLoggingHash], _familyId];
}

@end
