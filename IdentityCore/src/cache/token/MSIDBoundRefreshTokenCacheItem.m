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

#import "MSIDBoundRefreshTokenCacheItem.h"
#import "NSString+MSIDExtensions.h"
#import "NSData+MSIDExtensions.h"

@implementation MSIDBoundRefreshTokenCacheItem

- (NSString *)boundRefreshToken
{
    return self.secret;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[self jsonDictionary] forKey:@"cacheItem"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if (!(self = [super init]))
    {
        return nil;
    }
    NSDictionary *json = [decoder decodeObjectOfClass:[NSDictionary class] forKey:@"cacheItem"];
    if (json)
    {
        self = [self initWithJSONDictionary:json error:nil];
    }
    return self;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing*)error
{
    if (!(self = [super initWithJSONDictionary:json error:error]))
    {
        return nil;
    }
    
    if (!self.secret)
    {
        if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Couldn't read bound refresh token.", nil, nil, nil, nil, nil, YES);
        return nil;
    }
    
    _boundDeviceId = [json msidObjectForKey:MSID_BOUND_DEVICE_ID_CACHE_KEY ofClass:[NSString class]];
    if (!_boundDeviceId)
    {
        if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Bound device ID is nil. Cannot initialize bound refresh token cache item without bound device id", nil, nil, nil, nil, nil, YES);
        return nil;
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [[super jsonDictionary] mutableCopy];
    
    if (!dictionary)
    {
        dictionary = [NSMutableDictionary new];
    }

    dictionary[MSID_BOUND_DEVICE_ID_CACHE_KEY] = self.boundDeviceId;
    return dictionary;
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
    
    return [self isEqualToItem:(MSIDBoundRefreshTokenCacheItem *)object];
}

- (BOOL)isEqualToItem:(MSIDBoundRefreshTokenCacheItem *)item
{
    BOOL result = [super isEqualToItem:item];
    result &= (!self.boundDeviceId && !item.boundDeviceId) || [self.boundDeviceId isEqualToString:item.boundDeviceId];
    return result;
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.boundDeviceId.hash;
    return hash;
}

- (NSString *)description
{
    NSString *baseDescription = [super description];
    return [NSString stringWithFormat:@"%@, boundDeviceId: %@", baseDescription, self.boundDeviceId ? self.boundDeviceId : @"<nil>"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDBoundRefreshTokenCacheItem *item = (MSIDBoundRefreshTokenCacheItem *)[super copyWithZone:zone];
    item.boundDeviceId = [self.boundDeviceId copyWithZone:zone];
    return item;
}
@end
