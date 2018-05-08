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

#import "MSIDBaseToken.h"
#import "MSIDUserInformation.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDClientInfo.h"
#import "MSIDRequestParameters.h"

@implementation MSIDBaseToken

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDBaseToken *item = [[self.class allocWithZone:zone] init];
    item->_authority = _authority;
    item->_clientId = _clientId;
    item->_uniqueUserId = _uniqueUserId;
    item->_clientInfo = _clientInfo;
    item->_additionalServerInfo = _additionalServerInfo;
    item->_legacyUserId = _legacyUserId;
    
    return item;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:self.class])
    {
        return NO;
    }
    
    return [self isEqualToItem:(MSIDBaseToken *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.authority.hash;
    hash = hash * 31 + self.clientId.hash;
    hash = hash * 31 + self.uniqueUserId.hash;
    hash = hash * 31 + self.clientInfo.rawClientInfo.hash;
    hash = hash * 31 + self.additionalServerInfo.hash;
    hash = hash * 31 + self.tokenType;
    hash = hash * 31 + self.legacyUserId.hash;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDBaseToken *)item
{
    if (!item)
    {
        return NO;
    }
    
    BOOL result = YES;
    result &= (!self.authority && !item.authority) || [self.authority.absoluteString isEqualToString:item.authority.absoluteString];
    result &= (!self.clientId && !item.clientId) || [self.clientId isEqualToString:item.clientId];
    result &= (!self.uniqueUserId && !item.uniqueUserId) || [self.uniqueUserId isEqualToString:item.uniqueUserId];
    result &= (!self.legacyUserId || item.legacyUserId) || [self.legacyUserId isEqualToString:item.legacyUserId];
    result &= (!self.clientInfo && !item.clientInfo) || [self.clientInfo.rawClientInfo isEqualToString:item.clientInfo.rawClientInfo];
    result &= (!self.additionalServerInfo && !item.additionalServerInfo) || [self.additionalServerInfo isEqualToDictionary:item.additionalServerInfo];
    result &= (self.tokenType == item.tokenType);
    
    return result;
}

#pragma mark - Token type

- (MSIDTokenType)tokenType
{
    return MSIDTokenTypeOther;
}

- (BOOL)supportsTokenType:(MSIDTokenType)tokenType
{
    return tokenType == self.tokenType;
}

#pragma mark - Cache

- (instancetype)initWithTokenCacheItem:(MSIDTokenCacheItem *)tokenCacheItem
{
    self = [super init];
    
    if (self)
    {
        if (!tokenCacheItem)
        {
            return nil;
        }
        
        if (![self supportsTokenType:tokenCacheItem.tokenType])
        {
            MSID_LOG_ERROR(nil, @"Trying to initialize with a wrong token type");
            return nil;
        }
        
        _authority = tokenCacheItem.authority;
        
        if (!_authority)
        {
            MSID_LOG_ERROR(nil, @"Trying to initialize token when missing authority field");
            return nil;
        }
        
        _clientId = tokenCacheItem.clientId;
        
        if (!_clientId)
        {
            MSID_LOG_ERROR(nil, @"Trying to initialize token when missing clientId field");
            return nil;
        }
        
        _clientInfo = tokenCacheItem.clientInfo;
        _additionalServerInfo = tokenCacheItem.additionalInfo;
        _uniqueUserId = tokenCacheItem.uniqueUserId;
        _legacyUserId = tokenCacheItem.legacyUserId;
    }
    
    return self;
}

- (MSIDTokenCacheItem *)tokenCacheItem
{
    MSIDTokenCacheItem *cacheItem = [[MSIDTokenCacheItem alloc] init];
    cacheItem.tokenType = self.tokenType;
    cacheItem.authority = self.authority;
    cacheItem.clientId = self.clientId;
    cacheItem.clientInfo = self.clientInfo;
    cacheItem.additionalInfo = self.additionalServerInfo;
    cacheItem.uniqueUserId = self.uniqueUserId;
    cacheItem.legacyUserId = self.legacyUserId;
    return cacheItem;
}

#pragma mark - Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"(authority=%@ clientId=%@ tokenType=%@ uniqueUserId=%@ legacyuserId=%@ clientInfo=%@)",
            _authority, _clientId, [MSIDTokenTypeHelpers tokenTypeAsString:self.tokenType], _uniqueUserId, _legacyUserId, _clientInfo];
}

@end
