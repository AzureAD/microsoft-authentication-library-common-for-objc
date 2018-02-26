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

#import "MSIDAdfsToken.h"
#import "MSIDTokenResponse.h"

@implementation MSIDAdfsToken

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDAdfsToken *item = [super copyWithZone:zone];
    item->_refreshToken = [_refreshToken copyWithZone:zone];
    
    return item;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSIDAdfsToken.class])
    {
        return NO;
    }
    
    return [self isEqualToItem:(MSIDAdfsToken *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.refreshToken.hash;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDAdfsToken *)token
{
    if (!token)
    {
        return NO;
    }
    
    BOOL result = [super isEqualToItem:token];
    result &= (!self.refreshToken && !token.refreshToken) || [self.refreshToken isEqualToString:token.refreshToken];
    
    return result;
}

#pragma mark - Cache

- (instancetype)initWithTokenCacheItem:(MSIDTokenCacheItem *)tokenCacheItem
{
    self = [super initWithTokenCacheItem:tokenCacheItem];
    
    if (self)
    {
        _refreshToken = tokenCacheItem.refreshToken;
    }
    
    return self;
}

- (MSIDTokenCacheItem *)tokenCacheItem
{
    MSIDTokenCacheItem *cacheItem = [super tokenCacheItem];
    cacheItem.refreshToken = self.refreshToken;
    return cacheItem;
}

#pragma mark - Response

- (instancetype)initWithTokenResponse:(MSIDTokenResponse *)response
                              request:(MSIDRequestParameters *)requestParams
{
    if (!(self = [super initWithTokenResponse:response request:requestParams]))
    {
        return nil;
    }
    
    _refreshToken = response.refreshToken;
    
    if (!_refreshToken)
    {
        MSID_LOG_ERROR(nil, @"Trying to initialize ADFS token when missing refresh token field");
    }
    
    return self;
}

#pragma mark - Token type

- (MSIDTokenType)tokenType
{
    return MSIDTokenTypeLegacyADFSToken;
}

@end
