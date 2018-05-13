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
#import "MSIDHelpers.h"

//A special attribute to write, instead of nil/empty one.
static NSString *const s_nilKey = @"CC3513A0-0E69-4B4D-97FC-DFB6C91EE132";
static NSString *const s_adalLibraryString = @"MSOpenTech.ADAL.1";
static NSString *const s_adalServiceFormat = @"%@|%@|%@|%@";

@interface MSIDLegacyTokenCacheKey()

@end

@implementation MSIDLegacyTokenCacheKey

#pragma mark - Helpers

//We should not put nil keys in the keychain. The method substitutes nil with a special GUID:
- (NSString *)getAttributeName:(NSString *)original
{
    return ([NSString msidIsStringNilOrBlank:original]) ? s_nilKey : [original msidBase64UrlEncode];
}

- (NSString *)serviceWithAuthority:(NSURL *)authority
                          resource:(NSString *)resource
                          clientId:(NSString *)clientId
{
    // Trim first for faster nil or empty checks. Also lowercase and trimming is
    // needed to ensure that the cache handles correctly same items with different
    // character case:
    NSString *authorityString = authority.absoluteString.msidTrimmedString.lowercaseString;
    resource = resource.msidTrimmedString.lowercaseString;
    clientId = clientId.msidTrimmedString.lowercaseString;

    return [NSString stringWithFormat:s_adalServiceFormat,
            s_adalLibraryString,
            authorityString.msidBase64UrlEncode,
            [self.class getAttributeName:resource],
            clientId.msidBase64UrlEncode];
}

- (instancetype)initWithAuthority:(NSURL *)authority
                         clientId:(NSString *)clientId
                         resource:(NSString *)resource
                     legacyUserId:(NSString *)legacyUserId
{
    self = [super init];

    if (self)
    {
        _authority = authority;
        _clientId = clientId;
        _resource = resource;
        _legacyUserId = legacyUserId;
    }

    return self;
}

- (NSString *)account
{
    return [self adalAccountWithUserId:self.legacyUserId];
}

- (NSString *)service
{
    return [self serviceWithAuthority:self.authority resource:self.resource clientId:self.clientId];
}

- (NSData *)generic
{
    return [s_adalLibraryString dataUsingEncoding:NSUTF8StringEncoding];
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

    self.authority = [NSURL URLWithString:[coder decodeObjectOfClass:[NSString class] forKey:@"authority"]];
    self.resource = [coder decodeObjectOfClass:[NSString class] forKey:@"resource"];
    self.clientId = [coder decodeObjectOfClass:[NSString class] forKey:@"clientId"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.authority.absoluteString forKey:@"authority"];
    [coder encodeObject:self.resource forKey:@"resource"];
    [coder encodeObject:self.clientId forKey:@"clientId"];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSIDCacheKey.class])
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
    key.authority = [self.authority copyWithZone:zone];
    key.legacyUserId = [self.legacyUserId copyWithZone:zone];
    key.resource = [self.resource copyWithZone:zone];
    key.clientId = [self.clientId copyWithZone:zone];
    return key;
}

#pragma mark - Private
/*
 In order to be backward compatable with legacy format
 in ADAL we must to encode userId as base64 string
 for iOS only. For ADAL Mac we don't encode upn.
 */
- (NSString *)adalAccountWithUserId:(NSString *)userId
{
    if ([userId length])
    {
        userId = [MSIDHelpers normalizeUserId:userId];
    }
    
#if TARGET_OS_IPHONE
    return [userId msidBase64UrlEncode];
#endif
    
    return userId;
}

@end
