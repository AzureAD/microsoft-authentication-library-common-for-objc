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

#import "MSIDRefreshToken.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDUserInformation.h"

@implementation MSIDRefreshToken

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDRefreshToken *item = [super copyWithZone:zone];
    item->_refreshToken = [_refreshToken copyWithZone:zone];
    item->_familyId = [_familyId copyWithZone:zone];
    item->_idToken = [_idToken copyWithZone:zone];
    
    return item;
}

#pragma mark - NSSecureCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super initWithCoder:coder]))
    {
        return nil;
    }
    
    _refreshToken = [coder decodeObjectOfClass:[NSString class] forKey:@"refreshToken"];
    _familyId = [coder decodeObjectOfClass:[NSString class] forKey:@"familyId"];
    
    // Decode id_token from a backward compatible way
    _idToken = [[coder decodeObjectOfClass:[MSIDUserInformation class] forKey:@"userInformation"] rawIdToken];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    
    [coder encodeObject:self.familyId forKey:@"familyId"];
    [coder encodeObject:self.refreshToken forKey:@"refreshToken"];
    
    // Encode id_token in backward compatible way with ADAL
    MSIDUserInformation *userInformation = [[MSIDUserInformation alloc] initWithRawIdToken:self.idToken];
    [coder encodeObject:userInformation forKey:@"userInformation"];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSIDRefreshToken.class])
    {
        return NO;
    }
    
    return [self isEqualToToken:(MSIDRefreshToken *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash ^= self.refreshToken.hash;
    hash ^= self.familyId.hash;
    hash ^= self.idToken.hash;
    
    return hash;
}

- (BOOL)isEqualToToken:(MSIDRefreshToken *)token
{
    if (!token)
    {
        return NO;
    }
    
    BOOL result = [super isEqualToToken:token];
    result &= (!self.refreshToken && !token.refreshToken) || [self.refreshToken isEqualToString:token.refreshToken];
    result &= (!self.familyId && !token.familyId) || [self.familyId isEqualToString:token.familyId];
    result &= (!self.idToken && !token.idToken) || [self.idToken isEqualToString:token.idToken];
    
    return result;
}

#pragma mark - JSON

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (!(self = [super initWithJSONDictionary:json error:error]))
    {
        return nil;
    }
    
    /* Mandatory fields */
    _refreshToken = json[MSID_TOKEN_CACHE_KEY];
    _familyId = json[MSID_FAMILY_ID_CACHE_KEY];
    
    /* Optional fields */
    _username = json[MSID_USERNAME_CACHE_KEY];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [[super jsonDictionary] mutableCopy];
    
    /* Mandatory fields */
    [dictionary setValue:_refreshToken forKey:MSID_TOKEN_CACHE_KEY];
    [dictionary setValue:_familyId forKey:MSID_FAMILY_ID_CACHE_KEY];
    
    /* Optional fields */
    [dictionary setValue:_username forKey:MSID_USERNAME_CACHE_KEY];
    
    return dictionary;
}

#pragma mark - Init

- (instancetype)initWithTokenResponse:(MSIDTokenResponse *)response
                              request:(MSIDRequestParameters *)requestParams
{
    if (!(self = [super initWithTokenResponse:response request:requestParams]))
    {
        return nil;
    }
    
    [self fillToken:response];
    
    return self;
}

#pragma mark - Fill item

- (void)fillToken:(MSIDTokenResponse *)response
{
    _refreshToken = response.refreshToken;
    
    if ([response isKindOfClass:[MSIDAADTokenResponse class]])
    {
        MSIDAADTokenResponse *aadTokenResponse = (MSIDAADTokenResponse *)response;
        _familyId = aadTokenResponse.familyId;
    }
    
    _idToken = response.idToken;
    _username = response.idTokenObj.preferredUsername;
}

#pragma mark - Token type

- (MSIDTokenType)tokenType
{
    return MSIDTokenTypeRefreshToken;
}

@end
