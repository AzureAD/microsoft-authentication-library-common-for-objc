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

#import "MSIDAccountMetadataCacheItem.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDAuthorityFactory.h"
#import "NSDictionary+MSIDExtensions.h"

static const NSString *AccountMetadataURLMapKey = @"URLMap";

@interface MSIDAccountMetadataCacheItem()
@property NSMutableDictionary *internalMap;

@end

@implementation MSIDAccountMetadataCacheItem

- (instancetype)initWithHomeAccountId:(NSString *)homeAccountId
                             clientId:(NSString *)clientId

{
    if (!homeAccountId || !clientId) return nil;
    
    self = [super init];
    if (self)
    {
        _homeAccountId = homeAccountId;
        _clientId = clientId;
        _internalMap = [NSMutableDictionary new];
    }
    return self;
}

#pragma mark - URL caching
- (BOOL)setCachedURL:(NSURL *)cachedURL forRequestURL:(NSURL *)requestURL error:(NSError **)error
{
    if ([NSString msidIsStringNilOrBlank:cachedURL.absoluteString]
        || [NSString msidIsStringNilOrBlank:requestURL.absoluteString])
    {
        if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Either a target or request URL produces a nil string", nil, nil, nil, nil, nil);
        
        return NO;
    }
    
    NSMutableDictionary *urlMap = _internalMap[AccountMetadataURLMapKey];
    if (!urlMap)
    {
        urlMap = [NSMutableDictionary new];
        _internalMap[AccountMetadataURLMapKey] = urlMap;
    }
    
    urlMap[requestURL.absoluteString] = cachedURL.absoluteString;
    return YES;
}

- (NSURL *)cachedURL:(NSURL *)requestURL
{
    NSDictionary *urlMap = _internalMap[AccountMetadataURLMapKey];
    return [NSURL URLWithString:urlMap[requestURL.absoluteString]];
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    if (!json)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,nil, @"Tried to decode an authority map item from nil json");
        return nil;
    }
    
    self->_clientId = [json msidStringObjectForKey:MSID_CLIENT_ID_CACHE_KEY];
    self->_homeAccountId = [json msidStringObjectForKey:MSID_HOME_ACCOUNT_ID_CACHE_KEY];
    self->_internalMap = [[json msidObjectForKey:MSID_ACCOUNT_CACHE_KEY ofClass:NSDictionary.class] mutableCopy];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    dictionary[MSID_CLIENT_ID_CACHE_KEY] = self.clientId;
    dictionary[MSID_HOME_ACCOUNT_ID_CACHE_KEY] = self.homeAccountId;
    dictionary[MSID_ACCOUNT_CACHE_KEY] = _internalMap;
    
    return dictionary;
}

#pragma mark - Equal

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
    
    return [self isEqualToItem:(MSIDAccountMetadataCacheItem *)object];
}

- (BOOL)isEqualToItem:(MSIDAccountMetadataCacheItem *)item
{
    BOOL result = YES;
    result &= (!self.clientId && !item.clientId) || [self.clientId isEqualToString:item.clientId];
    result &= (!self.homeAccountId && !item.homeAccountId) || [self.homeAccountId isEqualToString:item.homeAccountId];;
    result &= ([_internalMap isEqualToDictionary:item->_internalMap]);
    
    return result;
}

#pragma mark - NSObject

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.clientId.hash;
    hash = hash * 31 + self.homeAccountId.hash;
    hash = hash * 31 + _internalMap.hash;
    
    return hash;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDAccountMetadataCacheItem *item = [[self class] allocWithZone:zone];
    item->_homeAccountId = [self.homeAccountId copyWithZone:zone];
    item->_clientId = [self.clientId copyWithZone:zone];
    item->_internalMap = [self->_internalMap copyWithZone:zone];
    
    return item;
}


@end
