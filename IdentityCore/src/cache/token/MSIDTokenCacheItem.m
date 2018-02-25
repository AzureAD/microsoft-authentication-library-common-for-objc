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

@implementation MSIDTokenCacheItem

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDTokenCacheItem *item = [super copyWithZone:zone];
    item->_tokenType = _tokenType;
    item->_accessToken = _accessToken;
    item->_refreshToken = _refreshToken;
    item->_idToken = _idToken;
    item->_target = _target;
    item->_familyId = _familyId;
    item->_cachedAt = _cachedAt;
    item->_expiresOn = _expiresOn;
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
    
    // Decode id_token from a backward compatible way
    _idToken = [[coder decodeObjectOfClass:[MSIDUserInformation class] forKey:@"userInformation"] rawIdToken];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    
    [coder encodeObject:self.familyId forKey:@"familyId"];
    [coder encodeObject:self.refreshToken forKey:@"refreshToken"];
    
    [coder encodeObject:self.expiresOn forKey:@"expiresOn"];
    [coder encodeObject:self.accessToken forKey:@"accessToken"];
    [coder encodeObject:self.refreshToken forKey:@"refreshToken"];
    [coder encodeObject:self.target forKey:@"resource"];
    [coder encodeObject:self.cachedAt forKey:@"cachedAt"];
    
    // Backward compatibility with ADAL.
    [coder encodeObject:@"Bearer" forKey:@"accessTokenType"];
    [coder encodeObject:[NSMutableDictionary dictionary] forKey:@"additionalClient"];
    
    // Encode id_token in backward compatible way with ADAL
    MSIDUserInformation *userInformation = [[MSIDUserInformation alloc] initWithRawIdToken:self.idToken];
    [coder encodeObject:userInformation forKey:@"userInformation"];
}

#pragma mark - NSObject

// TODO: this is not necessary here?
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
    
    return [self isEqualToItem:(MSIDTokenCacheItem *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.tokenType;
    hash = hash * 31 + self.accessToken.hash;
    hash = hash * 31 + self.refreshToken.hash;
    hash = hash * 31 + self.idToken.hash;
    hash = hash * 31 + self.target.hash;
    hash = hash * 31 + self.familyId.hash;
    hash = hash * 31 + self.expiresOn.hash;
    hash = hash * 31 + self.cachedAt.hash;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDTokenCacheItem *)item
{
    if (!item)
    {
        return NO;
    }
    
    BOOL result = [super isEqualToItem:item];
    result &= self.tokenType == item.tokenType;
    result &= (!self.accessToken && !item.accessToken) || [self.accessToken isEqualToString:item.accessToken];
    result &= (!self.refreshToken && !item.refreshToken) || [self.refreshToken isEqualToString:item.refreshToken];
    result &= (!self.idToken && !item.idToken) || [self.idToken isEqualToString:item.idToken];
    result &= (!self.target && !item.target) || [self.target isEqualToString:item.target];
    result &= (!self.familyId && !item.familyId) || [self.familyId isEqualToString:item.familyId];
    result &= (!self.cachedAt && !item.cachedAt) || [self.cachedAt isEqualToDate:item.cachedAt];
    result &= (!self.expiresOn && !item.expiresOn) || [self.expiresOn isEqualToDate:item.expiresOn];
    
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
    
    // Token type
    NSString *tokenType = json[MSID_CREDENTIAL_TYPE_CACHE_KEY];
    _tokenType = [MSIDTokenTypeHelpers tokenTypeFromString:tokenType];
    
    // Family ID
    _familyId = json[MSID_FAMILY_ID_CACHE_KEY];
    
    // Tenant
    _tenant = json[MSID_REALM_CACHE_KEY];
    
    // Target
    _target = json[MSID_TARGET_CACHE_KEY];
    
    // Cached at
    _cachedAt = [NSDate msidDateFromTimeStamp:json[MSID_CACHED_AT_CACHE_KEY]];
    
    // Expires on
    _expiresOn = [NSDate msidDateFromTimeStamp:json[MSID_EXPIRES_ON_CACHE_KEY]];
    
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
        case MSIDTokenTypeLegacyADFSToken:
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
    
    /* Optional fields */
    
    // ID token
    _idToken = json[MSID_ID_TOKEN_CACHE_KEY];
    
    // Authority
    _authority = json[MSID_AUTHORITY_CACHE_KEY];
    
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
    
    // Tenant
    dictionary[MSID_REALM_CACHE_KEY] = _tenant;
    
    // Target
    dictionary[MSID_TARGET_CACHE_KEY] = _target;
    
    // Cached at
    dictionary[MSID_CACHED_AT_CACHE_KEY] = _cachedAt.msidDateToTimestamp;
    
    // Expires on
    dictionary[MSID_EXPIRES_ON_CACHE_KEY] = _expiresOn.msidDateToTimestamp;
    
    switch (_tokenType) {
        case MSIDTokenTypeRefreshToken:
        {
            dictionary[MSID_TOKEN_CACHE_KEY] = _refreshToken;
            break;
        }
        case MSIDTokenTypeIDToken:
        {
            dictionary[MSID_TOKEN_CACHE_KEY] = _idToken;
            break;
        }
        case MSIDTokenTypeAccessToken:
        {
            dictionary[MSID_TOKEN_CACHE_KEY] = _accessToken;
            break;
        }
        case MSIDTokenTypeLegacyADFSToken:
        {
            dictionary[MSID_TOKEN_CACHE_KEY] = _accessToken;
            dictionary[MSID_RESOURCE_RT_CACHE_KEY] = _refreshToken;
            break;
        }
            
        default:
        {
            break;
        }
    }
    
    /* Optional fields */
    
    // ID token
    dictionary[MSID_ID_TOKEN_CACHE_KEY] = _idToken;
    
    // Authority
    dictionary[MSID_AUTHORITY_CACHE_KEY] = _authority;
    
    return dictionary;
}

@end
