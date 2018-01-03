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

#import "MSIDTokenCacheKey.h"
#import "NSString+MSIDExtensions.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDTokenType.h"

//A special attribute to write, instead of nil/empty one.
static NSString *const s_nilKey = @"CC3513A0-0E69-4B4D-97FC-DFB6C91EE132";
static NSString *const s_adalLibraryString = @"MSOpenTech.ADAL.1";

static uint32_t const s_msalV1 = 'MSv1';

@interface MSIDTokenCacheKey ()

@property (copy) NSURL *authority;
@property (copy) NSString *resource;
@property (copy) NSString *clientId;

@end

@implementation MSIDTokenCacheKey

- (id)initWithAccount:(NSString *)account
              service:(NSString *)service
                 type:(NSNumber *)type
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    self.account = account;
    self.service = service;
    self.type = type;
    
    return self;
}

//We should not put nil keys in the keychain. The method substitutes nil with a special GUID:
+ (NSString *)getAttributeName:(NSString *)original
{
    return ([NSString msidIsStringNilOrBlank:original]) ? s_nilKey : [original msidBase64UrlEncode];
}

+ (NSString *)accountWithUserIdentifier:(NSString *)userId
                            environment:(NSString *)environment
{
    return userId? [NSString stringWithFormat:@"%u$%@@%@", s_msalV1, userId, environment]: nil;
}

+ (MSIDTokenCacheKey *)keyForAdfsUserTokenWithAuthority:(NSURL *)authority
                                               clientId:(NSString *)clientId
                                               resource:(NSString *)resource
{
    return [[MSIDTokenCacheKey alloc] initWithAccount:@""
                                              service:[self.class serviceWithAuthority:authority
                                                                              resource:resource
                                                                              clientId:clientId]
                                                 type:nil];
}


+ (MSIDTokenCacheKey *)keyWithAuthority:(NSURL *)authority
                               clientId:(NSString *)clientId
                               resource:(NSString *)resource
                                    upn:(NSString *)upn
{
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey alloc] initWithAccount:upn
                                                                service:[self.class serviceWithAuthority:authority
                                                                                                resource:resource
                                                                                                clientId:clientId]
                                                                   type:nil];
    
    key.authority = authority;
    key.clientId = clientId;
    key.resource = resource;
    
    return key;
}

+ (MSIDTokenCacheKey *)keyForAccessTokenWithAuthority:(NSURL *)authority
                                             clientId:(NSString *)clientId
                                               scopes:(NSOrderedSet<NSString *> *)scopes
                                               userId:(NSString *)userId
{
    NSString *service = [self.class serviceWithAuthority:authority scopes:scopes clientId:clientId];
    NSString *account = [self.class accountWithUserIdentifier:userId
                                                  environment:authority.msidHostWithPortIfNecessary];
    
    return [[MSIDTokenCacheKey alloc] initWithAccount:account service:service type:[NSNumber numberWithInteger:MSIDTokenTypeAccessToken]];
}

+ (MSIDTokenCacheKey *)keyForAllAccessTokensWithUserId:(NSString *)userId
                                           environment:(NSString *)environment
{
    NSString *account = [self.class accountWithUserIdentifier:userId environment:environment];
    return [[MSIDTokenCacheKey alloc] initWithAccount:account service:nil type:[NSNumber numberWithInteger:MSIDTokenTypeAccessToken]];
}

+ (MSIDTokenCacheKey *)keyForAllAccessTokens
{
    return [[MSIDTokenCacheKey alloc] initWithAccount:nil service:nil type:[NSNumber numberWithInteger:MSIDTokenTypeAccessToken]];
}

// rt with uid and utid
+ (MSIDTokenCacheKey *)keyForRefreshTokenWithUserId:(NSString *)userId
                                           clientId:(NSString *)clientId
                                        environment:(NSString *)environment
{
    NSString *service = clientId.msidBase64UrlEncode;
    NSString *account = [self.class accountWithUserIdentifier:userId environment:environment];
    
    return [[MSIDTokenCacheKey alloc] initWithAccount:account service:service type:[NSNumber numberWithInteger:MSIDTokenTypeRefreshToken]];
}

+ (MSIDTokenCacheKey *)keyForRefreshTokenWithClientId:(NSString *)clientId
{
    NSString *service = clientId.msidBase64UrlEncode;
    return [[MSIDTokenCacheKey alloc] initWithAccount:nil service:service type:[NSNumber numberWithInteger:MSIDTokenTypeRefreshToken]];
}

+ (MSIDTokenCacheKey *)keyForAllItems
{
    return [[MSIDTokenCacheKey alloc] initWithAccount:nil service:nil type:nil];
}

+ (NSString *)familyClientId:(NSString *)familyId
{
    if (!familyId)
    {
        familyId = @"1";
    }
    
    return [NSString stringWithFormat:@"foci-%@", familyId];
}

- (BOOL)isEqualToTokenCacheKey:(MSIDTokenCacheKey *)key
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
    
    return [self isEqualToTokenCacheKey:(MSIDTokenCacheKey *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = self.account.hash;
    hash ^= self.service.hash;
    hash ^= self.type.hash;
    
    return hash;
}

#pragma mark - Private

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

+ (NSString *)serviceWithAuthority:(NSURL *)authority
                            scopes:(NSOrderedSet<NSString *> *)scopes
                          clientId:(NSString *)clientId
{
    if (scopes.count == 0)
    {
        return nil;
    }
    
    return [NSString stringWithFormat:@"%@$%@$%@",
            authority? authority.absoluteString.msidBase64UrlEncode : @"",
            clientId? clientId.msidBase64UrlEncode : @"",
            scopes? scopes.msidToString.msidBase64UrlEncode : @""];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDTokenCacheKey *key = [[MSIDTokenCacheKey allocWithZone:zone] init];
    key.account = [self.account copyWithZone:zone];
    key.service = [self.service copyWithZone:zone];
    key.type = [self.type copyWithZone:zone];
    
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
        _service = [self.class serviceWithAuthority:self.authority resource:self.resource clientId:self.clientId];
    }
    
    // TODO: account?
    
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

@end
