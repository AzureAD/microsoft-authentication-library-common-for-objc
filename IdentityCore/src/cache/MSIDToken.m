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

#import "MSIDToken.h"
#import "MSIDUserInformation.h"

@implementation MSIDToken

- (BOOL)isEqualToToken:(MSIDToken *)token
{
    if (!token)
    {
        return NO;
    }
    
    BOOL result = YES;
    result &= (!self.token && !token.token) || [self.token isEqualToString:token.token];
    result &= (!self.idToken && !token.idToken) || [self.idToken isEqualToString:token.idToken];
    result &= (!self.expiresOn && !token.expiresOn) || [self.expiresOn isEqualToDate:token.expiresOn];
    result &= (!self.familyId && !token.familyId) || [self.familyId isEqualToString:token.familyId];
    result &= (!self.clientInfo && !token.clientInfo) || [self.clientInfo isEqualToDictionary:token.clientInfo];
    result &= (!self.additionalServerInfo && !token.additionalServerInfo) || [self.additionalServerInfo isEqualToDictionary:token.additionalServerInfo];
    result &= self.tokenType == token.tokenType;
    result &= (!self.resource && !token.resource) || [self.resource isEqualToString:token.resource];
    result &= (!self.authority && !token.authority) || [self.authority isEqualToString:token.authority];
    result &= (!self.clientId && !token.clientId) || [self.clientId isEqualToString:token.clientId];
    result &= (!self.scopes && !token.scopes) || [self.scopes isEqualToOrderedSet:token.scopes];
    
    return result;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSIDToken.class])
    {
        return NO;
    }
    
    return [self isEqualToToken:(MSIDToken *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = self.token.hash;
    hash ^= self.idToken.hash;
    hash ^= self.expiresOn.hash;
    hash ^= self.familyId.hash;
    hash ^= self.clientInfo.hash;
    hash ^= self.additionalServerInfo.hash;
    hash ^= self.tokenType;
    hash ^= self.resource.hash;
    hash ^= self.authority.hash;
    hash ^= self.clientId.hash;
    hash ^= self.scopes.hash;
    
    return hash;
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
    
    _familyId = [coder decodeObjectOfClass:[NSString class] forKey:@"familyId"];
    _expiresOn = [coder decodeObjectOfClass:[NSDate class] forKey:@"expiresOn"];
    
    NSString *accessToken = [coder decodeObjectOfClass:[NSString class] forKey:@"accessToken"];
    NSString *refreshToken = [coder decodeObjectOfClass:[NSString class] forKey:@"refreshToken"];
    
    if (refreshToken)
    {
        _token = refreshToken;
        _tokenType = MSIDTokenTypeRefreshToken;
    }
    else
    {
        _token = accessToken;
        _tokenType = MSIDTokenTypeAccessToken;
    }
    
    _additionalServerInfo = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"additionalServer"];
    _clientInfo = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"clientInfo"];
    _idToken = [[coder decodeObjectOfClass:[MSIDUserInformation class] forKey:@"userInformation"] rawIdToken];
    _resource = [coder decodeObjectOfClass:[NSString class] forKey:@"resource"];
    _authority = [coder decodeObjectOfClass:[NSString class] forKey:@"authority"];
    _clientId = [coder decodeObjectOfClass:[NSString class] forKey:@"clientId"];
    _scopes = [coder decodeObjectOfClass:[NSOrderedSet class] forKey:@"scopes"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_familyId forKey:@"familyId"];
    [coder encodeObject:_expiresOn forKey:@"expiresOn"];
    
    if (self.tokenType == MSIDTokenTypeRefreshToken)
    {
        [coder encodeObject:_token forKey:@"refreshToken"];
    }
    else
    {
        [coder encodeObject:_token forKey:@"accessToken"];
    }
    
    [coder encodeObject:_clientInfo forKey:@"clientInfo"];
    [coder encodeObject:_additionalServerInfo forKey:@"additionalServer"];
    
    MSIDUserInformation *userInformation = [MSIDUserInformation new];
    userInformation.rawIdToken = self.idToken;
    [coder encodeObject:userInformation forKey:@"userInformation"];
    
    [coder encodeObject:_resource forKey:@"resource"];
    [coder encodeObject:_authority forKey:@"authority"];
    [coder encodeObject:_clientId forKey:@"clientId"];
    [coder encodeObject:_scopes forKey:@"scopes"];
}

@end
