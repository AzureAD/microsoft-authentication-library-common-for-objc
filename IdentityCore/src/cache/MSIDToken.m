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
    
    return result;
}

#pragma mark - NSObject

+ (void)load
{
    // Maintain backward compatibility with ADAL.
    [NSKeyedArchiver setClassName:@"ADTokenCacheStoreItem" forClass:self];
    [NSKeyedUnarchiver setClass:self forClassName:@"ADTokenCacheStoreItem"];
}

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
    
    return hash;
}

#pragma mark - NSCoding

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
    _clientInfo = [coder decodeObjectOfClass:[NSMutableDictionary class] forKey:@"additionalClient"];
    _idToken = [[coder decodeObjectOfClass:[MSIDUserInformation class] forKey:@"userInformation"] rawIdToken];
    
//    _resource = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"resource"];
//    _authority = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"authority"];
//    _clientId = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"clientId"];
//    _accessTokenType = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"accessTokenType"];
//    _sessionKey = [aDecoder decodeObjectOfClass:[NSData class] forKey:@"sessionKey"];
    
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
    
    [coder encodeObject:_clientInfo forKey:@"additionalClient"];
    [coder encodeObject:_additionalServerInfo forKey:@"additionalServer"];
    
    MSIDUserInformation *userInformation = [MSIDUserInformation new];
    userInformation.rawIdToken = self.idToken;
    [coder encodeObject:userInformation forKey:@"userInformation"];
    
//    [aCoder encodeObject:_resource forKey:@"resource"];
//    [aCoder encodeObject:_authority forKey:@"authority"];
//    [aCoder encodeObject:_clientId forKey:@"clientId"];
//    [aCoder encodeObject:_accessTokenType forKey:@"accessTokenType"];
//    [aCoder encodeObject:_sessionKey forKey:@"sessionKey"];
}

@end
