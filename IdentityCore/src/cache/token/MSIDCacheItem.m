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

#import "MSIDCacheItem.h"

@interface MSIDCacheItem()

@property (readwrite) NSDictionary *json;

@end

@implementation MSIDCacheItem

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
    
    return [self isEqualToItem:(MSIDCacheItem *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.uniqueUserId.hash;
    hash = hash * 31 + self.legacyUserId.hash;
    hash = hash * 31 + self.environment.hash;
    hash = hash * 31 + self.clientInfo.rawClientInfo.hash;

    return hash;
}

- (BOOL)isEqualToItem:(MSIDCacheItem *)item
{
    if (!item)
    {
        return NO;
    }
    
    BOOL result = YES;
    result &= (!self.uniqueUserId && !item.uniqueUserId) || [self.uniqueUserId isEqualToString:item.uniqueUserId];
    result &= (!self.legacyUserId && !item.legacyUserId) || [self.legacyUserId isEqualToString:item.legacyUserId];
    result &= (!self.environment && !item.environment) || [self.environment isEqualToString:item.environment];
    result &= (!self.clientInfo && !item.clientInfo) || [self.clientInfo.rawClientInfo isEqualToString:item.clientInfo.rawClientInfo];
    
    return result;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDCacheItem *item = [[self.class allocWithZone:zone] init];
    item.uniqueUserId = [self.uniqueUserId copyWithZone:zone];
    item.clientInfo = [self.clientInfo copyWithZone:zone];
    item.environment = [self.environment copyWithZone:zone];
    item.legacyUserId = [self.legacyUserId copyWithZone:zone];
    
    return item;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super init]))
    {
        return nil;
    }

    NSString *rawClientInfo = [coder decodeObjectOfClass:[NSString class] forKey:@"clientInfo"];
    [self fillClientInfo:rawClientInfo];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.clientInfo.rawClientInfo forKey:@"clientInfo"];
}

#pragma mark - JSON

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _json = json;
    
    // Unique ID
    _uniqueUserId = json[MSID_UNIQUE_ID_CACHE_KEY];

    // Environment
    _environment = json[MSID_ENVIRONMENT_CACHE_KEY];

    // Authority account ID
    _legacyUserId = json[MSID_ACCOUNT_ID_CACHE_KEY];
    
    /* Optional fields */
    NSString *rawClientInfo = json[MSID_OAUTH2_CLIENT_INFO];
    [self fillClientInfo:rawClientInfo];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    if (_json)
    {
        [dictionary addEntriesFromDictionary:_json];
    }
    
    /* Mandatory fields */
    
    // Unique id
    dictionary[MSID_UNIQUE_ID_CACHE_KEY] = _clientInfo.userIdentifier ? _clientInfo.userIdentifier : _uniqueUserId;

    // Environment
    dictionary[MSID_ENVIRONMENT_CACHE_KEY] = _environment;

    // Authority account ID
    dictionary[MSID_ACCOUNT_ID_CACHE_KEY] = _legacyUserId;
    
    /* Optional fields */
    
    // Client info
    dictionary[MSID_CLIENT_INFO_CACHE_KEY] = _clientInfo.rawClientInfo;
    
    return dictionary;
}

#pragma mark - Helpers

- (void)fillClientInfo:(NSString *)rawClientInfo
{
    if (!rawClientInfo)
    {
        return;
    }
    
    NSError *error = nil;
    _clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:rawClientInfo error:&error];
    
    if (error)
    {
        MSID_LOG_ERROR(nil, @"Client info is corrupted.");
    }
    else
    {
        _uniqueUserId = _clientInfo.userIdentifier;
    }
}

@end
