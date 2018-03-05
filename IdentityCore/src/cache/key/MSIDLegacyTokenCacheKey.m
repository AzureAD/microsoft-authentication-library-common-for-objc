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

#import "MSIDLegacyTokenCacheKey.h"

//A special attribute to write, instead of nil/empty one.
static NSString *const s_nilKey = @"CC3513A0-0E69-4B4D-97FC-DFB6C91EE132";
static NSString *const s_adalLibraryString = @"MSOpenTech.ADAL.1";

@interface MSIDLegacyTokenCacheKey()

@property (nonatomic, readwrite) NSURL *authority;
@property (nonatomic, readwrite) NSString *resource;
@property (nonatomic, readwrite) NSString *clientId;

@end

@implementation MSIDLegacyTokenCacheKey

#pragma mark - Helpers

//We should not put nil keys in the keychain. The method substitutes nil with a special GUID:
+ (NSString *)getAttributeName:(NSString *)original
{
    return ([NSString msidIsStringNilOrBlank:original]) ? s_nilKey : [original msidBase64UrlEncode];
}

+ (NSString *)serviceWithAuthority:(NSURL *)authority
                          resource:(NSString *)resource
                          clientId:(NSString *)clientId
{
    
    return [NSString stringWithFormat:@"%@|%@|%@|%@",
            s_adalLibraryString,
            authority.absoluteString.msidBase64UrlEncode,
            [self.class getAttributeName:resource.msidBase64UrlEncode],
            clientId.msidBase64UrlEncode];
}

#pragma mark - Legacy keys

+ (MSIDLegacyTokenCacheKey *)keyForAdfsUserTokenWithAuthority:(NSURL *)authority
                                                     clientId:(NSString *)clientId
                                                     resource:(NSString *)resource
{
    NSString *service = [self.class serviceWithAuthority:authority
                                                resource:resource
                                                clientId:clientId];
    
    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:@""
                                                                            service:service
                                                                            generic:[s_adalLibraryString dataUsingEncoding:NSUTF8StringEncoding]
                                                                               type:nil];
    
    key.authority = authority;
    key.clientId = clientId;
    key.resource = resource;
    
    return key;
}


+ (MSIDLegacyTokenCacheKey *)keyWithAuthority:(NSURL *)authority
                                     clientId:(NSString *)clientId
                                     resource:(NSString *)resource
                                 legacyUserId:(NSString *)legacyUserId
{
    NSString *service = [self.class serviceWithAuthority:authority
                                                resource:resource
                                                clientId:clientId];
    
    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey alloc] initWithAccount:legacyUserId
                                                                            service:service
                                                                            generic:[s_adalLibraryString dataUsingEncoding:NSUTF8StringEncoding]
                                                                               type:nil];
    
    key.authority = authority;
    key.clientId = clientId;
    key.resource = resource;
    
    return key;
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
    
    _account = [coder decodeObjectOfClass:[NSString class] forKey:@"account"];
    _service = [coder decodeObjectOfClass:[NSString class] forKey:@"service"];
    _type = [coder decodeObjectOfClass:[NSNumber class] forKey:@"type"];
    
    NSString *authority = [coder decodeObjectOfClass:[NSString class] forKey:@"authority"];
    if (authority)
    {
        _authority = [[NSURL alloc] initWithString:authority];
    }
    
    _resource = [coder decodeObjectOfClass:[NSString class] forKey:@"resource"];
    _clientId = [coder decodeObjectOfClass:[NSString class] forKey:@"clientId"];
    
    if (!_service)
    {
        _service = [self.class serviceWithAuthority:_authority resource:_resource clientId:_clientId];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_account forKey:@"account"];
    [coder encodeObject:_service forKey:@"service"];
    [coder encodeObject:_type forKey:@"type"];
    [coder encodeObject:_resource forKey:@"resource"];
    [coder encodeObject:_authority.absoluteString forKey:@"authority"];
    [coder encodeObject:_clientId forKey:@"clientId"];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSIDTokenCacheKey.class])
    {
        return NO;
    }
    
    return [self isEqualToTokenCacheKey:(MSIDLegacyTokenCacheKey *)object];
}

- (BOOL)isEqualToTokenCacheKey:(MSIDLegacyTokenCacheKey *)key
{
    if (!key)
    {
        return NO;
    }
    
    BOOL result = YES;
    result &= (!self.account && !key.account) || [self.account isEqualToString:key.account];
    result &= (!self.service && !key.service) || [self.service isEqualToString:key.service];
    result &= (!self.type && !key.type) || [self.type isEqualToNumber:key.type];
    
    return result;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;
    hash = hash * 31 + self.account.hash;
    hash = hash * 31 + self.service.hash;
    hash = hash * 31 + self.type.hash;
    
    return hash;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDLegacyTokenCacheKey *key = [[MSIDLegacyTokenCacheKey allocWithZone:zone] init];
    key.account = [self.account copyWithZone:zone];
    key.service = [self.service copyWithZone:zone];
    key.type = [self.type copyWithZone:zone];
    key.authority = [_authority copyWithZone:zone];
    key.resource = [_resource copyWithZone:zone];
    key.clientId = [_clientId copyWithZone:zone];
    
    return key;
}

@end
