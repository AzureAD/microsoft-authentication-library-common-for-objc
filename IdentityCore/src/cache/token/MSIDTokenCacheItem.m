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

#import "MSIDTokenCacheItem.h"
#import "MSIDUserInformation.h"
#import "MSIDTokenType.h"
#import "NSDate+MSIDExtensions.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDIdTokenWrapper.h"
#import "MSIDBaseToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDIdToken.h"

@implementation MSIDTokenCacheItem

#pragma mark - MSIDCacheItem

- (BOOL)isEqualToItem:(MSIDTokenCacheItem *)item
{
    BOOL result = [super isEqualToItem:item];
    result &= (!self.clientId && !item.clientId) || [self.clientId isEqualToString:item.clientId];
    result &= self.tokenType == item.tokenType;
    result &= (!self.accessToken && !item.accessToken) || [self.accessToken isEqualToString:item.accessToken];
    result &= (!self.refreshToken && !item.refreshToken) || [self.refreshToken isEqualToString:item.refreshToken];
    result &= (!self.idToken && !item.idToken) || [self.idToken isEqualToString:item.idToken];
    result &= (!self.target && !item.target) || [self.target isEqualToString:item.target];
    result &= (!self.expiresOn && !item.expiresOn) || [self.expiresOn isEqualToDate:item.expiresOn];
    result &= (!self.cachedAt && !item.cachedAt) || [self.cachedAt isEqualToDate:item.cachedAt];
    result &= (!self.familyId && !item.familyId) || [self.familyId isEqualToString:item.familyId];
    result &= (!self.oauthTokenType && !item.oauthTokenType) || [self.oauthTokenType isEqualToString:item.oauthTokenType];
    
    return result;
}

#pragma mark - NSObject

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.clientId.hash;
    hash = hash * 31 + self.tokenType;
    hash = hash * 31 + self.accessToken.hash;
    hash = hash * 31 + self.refreshToken.hash;
    hash = hash * 31 + self.idToken.hash;
    hash = hash * 31 + self.target.hash;
    hash = hash * 31 + self.expiresOn.hash;
    hash = hash * 31 + self.cachedAt.hash;
    hash = hash * 31 + self.familyId.hash;
    hash = hash * 31 + self.oauthTokenType.hash;
    
    return hash;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDTokenCacheItem *item = [super copyWithZone:zone];
    item.clientId = [self.clientId copyWithZone:zone];
    item.tokenType = self.tokenType;
    item.accessToken = [self.accessToken copyWithZone:zone];
    item.refreshToken = [self.refreshToken copyWithZone:zone];
    item.idToken = [self.idToken copyWithZone:zone];
    item.target = [self.target copyWithZone:zone];
    item.expiresOn = [self.expiresOn copyWithZone:zone];
    item.cachedAt = [self.cachedAt copyWithZone:zone];
    item.familyId = [self.familyId copyWithZone:zone];
    item.oauthTokenType = [self.oauthTokenType copyWithZone:zone];
    
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
    _accessToken = [coder decodeObjectOfClass:[NSString class] forKey:@"accessToken"];
    
    _familyId = [coder decodeObjectOfClass:[NSString class] forKey:@"familyId"];
    
    _expiresOn = [coder decodeObjectOfClass:[NSDate class] forKey:@"expiresOn"];
    _target = [coder decodeObjectOfClass:[NSString class] forKey:@"resource"];
    _cachedAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"cachedAt"];
    
    _clientId = [coder decodeObjectOfClass:[NSString class] forKey:@"clientId"];
    
    _oauthTokenType = [coder decodeObjectOfClass:[NSString class] forKey:@"accessTokenType"];
    
    // Decode id_token from a backward compatible way
    _idToken = [[coder decodeObjectOfClass:[MSIDUserInformation class] forKey:@"userInformation"] rawIdToken];
    
    _tokenType = [MSIDTokenTypeHelpers tokenTypeWithRefreshToken:_refreshToken accessToken:_accessToken];
        
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    
    [coder encodeObject:self.familyId forKey:@"familyId"];
    [coder encodeObject:self.refreshToken forKey:@"refreshToken"];
    
    [coder encodeObject:self.clientId forKey:@"clientId"];
    
    [coder encodeObject:self.expiresOn forKey:@"expiresOn"];
    [coder encodeObject:self.accessToken forKey:@"accessToken"];
    [coder encodeObject:self.target forKey:@"resource"];
    [coder encodeObject:self.cachedAt forKey:@"cachedAt"];
    
    // Backward compatibility with ADAL.
    NSString *tokenType = [NSString msidIsStringNilOrBlank:self.oauthTokenType] ? MSID_OAUTH2_BEARER : self.oauthTokenType;
    [coder encodeObject:tokenType forKey:@"accessTokenType"];
    
    // Encode id_token in backward compatible way with ADAL
    MSIDUserInformation *userInformation = [[MSIDUserInformation alloc] initWithRawIdToken:self.idToken];
    [coder encodeObject:userInformation forKey:@"userInformation"];
    
    [coder encodeObject:[NSMutableDictionary dictionary] forKey:@"additionalClient"];
}

#pragma mark - JSON

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (!(self = [super initWithJSONDictionary:json error:error]))
    {
        return nil;
    }
    
    // Token type
    NSString *tokenType = json[MSID_CREDENTIAL_TYPE_CACHE_KEY];
    _tokenType = [MSIDTokenTypeHelpers tokenTypeFromString:tokenType];
    
    // Family ID
    _familyId = json[MSID_FAMILY_ID_CACHE_KEY];
    
    // Client ID
    _clientId = json[MSID_CLIENT_ID_CACHE_KEY];
    
    // Target
    _target = json[MSID_TARGET_CACHE_KEY];
    
    // Cached at
    _cachedAt = [NSDate msidDateFromTimeStamp:json[MSID_CACHED_AT_CACHE_KEY]];
    
    // Expires on
    _expiresOn = [NSDate msidDateFromTimeStamp:json[MSID_EXPIRES_ON_CACHE_KEY]];
    
    // ID token
    _idToken = json[MSID_ID_TOKEN_CACHE_KEY];
    
    // Access token type
    _oauthTokenType = json[MSID_OAUTH_TOKEN_TYPE_CACHE_KEY];
    
    switch (_tokenType) {
        case MSIDTokenTypeRefreshToken:
        {
            _refreshToken = json[MSID_TOKEN_CACHE_KEY];
            break;
        }
        case MSIDTokenTypeIDToken:
        {
            _idToken = json[MSID_TOKEN_CACHE_KEY];
            break;
        }
        case MSIDTokenTypeAccessToken:
        {
            _accessToken = json[MSID_TOKEN_CACHE_KEY];
            break;
        }
        case MSIDTokenTypeLegacySingleResourceToken:
        {
            _accessToken = json[MSID_TOKEN_CACHE_KEY];
            _refreshToken = json[MSID_RESOURCE_RT_CACHE_KEY];
            break;
        }
            
        default:
        {
            break;
        }
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [[super jsonDictionary] mutableCopy];
    
    /* Mandatory fields */
    
    // Credential type
    dictionary[MSID_CREDENTIAL_TYPE_CACHE_KEY] = [MSIDTokenTypeHelpers tokenTypeAsString:self.tokenType];
    
    // Family ID
    dictionary[MSID_FAMILY_ID_CACHE_KEY] = _familyId;
    
    // Client ID
    dictionary[MSID_CLIENT_ID_CACHE_KEY] = _clientId;
    
    // Target
    dictionary[MSID_TARGET_CACHE_KEY] = _target;
    
    // Cached at
    dictionary[MSID_CACHED_AT_CACHE_KEY] = _cachedAt.msidDateToTimestamp;
    
    // Expires on
    dictionary[MSID_EXPIRES_ON_CACHE_KEY] = _expiresOn.msidDateToTimestamp;
    
    // Oauth token type
    dictionary[MSID_OAUTH_TOKEN_TYPE_CACHE_KEY] = _oauthTokenType;
    
    switch (_tokenType) {
        case MSIDTokenTypeRefreshToken:
        {
            dictionary[MSID_TOKEN_CACHE_KEY] = _refreshToken;
            dictionary[MSID_ID_TOKEN_CACHE_KEY] = _idToken;
            break;
        }
        case MSIDTokenTypeIDToken:
        {
            dictionary[MSID_TOKEN_CACHE_KEY] = _idToken;
            dictionary[MSID_REALM_CACHE_KEY] = _authority.msidTenant;
            break;
        }
        case MSIDTokenTypeAccessToken:
        {
            dictionary[MSID_TOKEN_CACHE_KEY] = _accessToken;
            dictionary[MSID_REALM_CACHE_KEY] = _authority.msidTenant;
            dictionary[MSID_ID_TOKEN_CACHE_KEY] = _idToken;
            break;
        }
        case MSIDTokenTypeLegacySingleResourceToken:
        {
            dictionary[MSID_TOKEN_CACHE_KEY] = _accessToken;
            dictionary[MSID_RESOURCE_RT_CACHE_KEY] = _refreshToken;
            dictionary[MSID_REALM_CACHE_KEY] = _authority.msidTenant;
            dictionary[MSID_ID_TOKEN_CACHE_KEY] = _idToken;
            break;
        }
            
        default:
        {
            break;
        }
    }
    
    return dictionary;
}

#pragma mark - Helpers

- (MSIDBaseToken *)tokenWithType:(MSIDTokenType)tokenType
{
    switch (tokenType)
    {
        case MSIDTokenTypeAccessToken:
        {
            return [[MSIDAccessToken alloc] initWithTokenCacheItem:self];
        }
        case MSIDTokenTypeRefreshToken:
        {
            return [[MSIDRefreshToken alloc] initWithTokenCacheItem:self];
        }
        case MSIDTokenTypeLegacySingleResourceToken:
        {
            return [[MSIDLegacySingleResourceToken alloc] initWithTokenCacheItem:self];
        }
        case MSIDTokenTypeIDToken:
        {
            return [[MSIDIdToken alloc] initWithTokenCacheItem:self];
        }
        default:
            return [[MSIDBaseToken alloc] initWithTokenCacheItem:self];
    }
    
    return nil;
}

@end
