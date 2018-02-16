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

#import "MSIDAccessToken.h"
#import "MSIDAADTokenResponse.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDAADV1RequestParameters.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDUserInformation.h"
#import "NSDate+MSIDExtensions.h"

//in seconds, ensures catching of clock differences between the server and the device
static uint64_t s_expirationBuffer = 300;

@interface MSIDAccessToken()
{
    NSString *_target;
}

@end

@implementation MSIDAccessToken

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDAccessToken *item = [super copyWithZone:zone];
    item->_expiresOn = [_expiresOn copyWithZone:zone];
    item->_cachedAt = [_cachedAt copyWithZone:zone];
    item->_accessToken = [_accessToken copyWithZone:zone];
    item->_target = [_target copyWithZone:zone];
    
    return item;
}

#pragma mark - NSSecureCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super initWithCoder:coder]))
    {
        return nil;
    }
    
    _expiresOn = [coder decodeObjectOfClass:[NSDate class] forKey:@"expiresOn"];
    _accessToken = [coder decodeObjectOfClass:[NSString class] forKey:@"accessToken"];
    _target = [coder decodeObjectOfClass:[NSString class] forKey:@"resource"];
    _cachedAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"cachedAt"];
    // Decode id_token from a backward compatible way
    _idToken = [[coder decodeObjectOfClass:[MSIDUserInformation class] forKey:@"userInformation"] rawIdToken];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    
    [coder encodeObject:self.expiresOn forKey:@"expiresOn"];
    [coder encodeObject:self.accessToken forKey:@"accessToken"];
    [coder encodeObject:self.resource forKey:@"resource"];
    [coder encodeObject:self.scopes forKey:@"scopes"];
    [coder encodeObject:self.cachedAt forKey:@"cachedAt"];
    
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
    
    if (![object isKindOfClass:MSIDAccessToken.class])
    {
        return NO;
    }
    
    return [self isEqualToToken:(MSIDAccessToken *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash ^= self.expiresOn.hash;
    hash ^= self.accessToken.hash;
    hash ^= self.resource.hash;
    hash ^= self.scopes.hash;
    hash ^= self.cachedAt.hash;
    
    return hash;
}

- (BOOL)isEqualToToken:(MSIDAccessToken *)token
{
    if (!token)
    {
        return NO;
    }
    
    BOOL result = [super isEqualToToken:token];
    result &= (!self.expiresOn && !token.expiresOn) || [self.expiresOn isEqualToDate:token.expiresOn];
    result &= (!self.accessToken && !token.accessToken) || [self.accessToken isEqualToString:token.accessToken];
    result &= (!self.resource && !token.resource) || [self.resource isEqualToString:token.resource];
    result &= (!self.scopes && !token.scopes) || [self.scopes isEqualToOrderedSet:token.scopes];
    result &= (!self.cachedAt && !token.cachedAt) || [self.cachedAt isEqualToDate:token.cachedAt];
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
    
    // Realm
    if (json[MSID_AUTHORITY_CACHE_KEY])
    {
        _authority = [NSURL URLWithString:json[MSID_AUTHORITY_CACHE_KEY]];
    }
    else if (json[MSID_REALM_CACHE_KEY])
    {
        NSString *authorityString = [NSString stringWithFormat:@"%@/%@", json[MSID_ENVIRONMENT_CACHE_KEY], json[MSID_REALM_CACHE_KEY]];
        _authority = [NSURL URLWithString:authorityString];
    }
    
    // Target
    _target = json[MSID_TARGET_CACHE_KEY];
    
    // Cached at
    _cachedAt = [NSDate msidDateFromTimeStamp:json[MSID_CACHED_AT_CACHE_KEY]];
    
    // Expires on
    _expiresOn = [NSDate msidDateFromTimeStamp:json[MSID_EXPIRES_ON_CACHE_KEY]];
    
    // Token
    _accessToken = json[MSID_TOKEN_CACHE_KEY];
    
    /* Optional fields */
    // Extended expires on
    [_additionalInfo setValue:json[MSID_EXTENDED_EXPIRES_ON_CACHE_KEY] forKey:MSID_EXTENDED_EXPIRES_ON_CACHE_KEY];
    
    // ID token
    _idToken = json[MSID_ID_TOKEN_CACHE_KEY];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [[super jsonDictionary] mutableCopy];
    
    /* Mandatory fields */
    // Realm
    [dictionary setValue:_authority.msidTenant
                  forKey:MSID_REALM_CACHE_KEY];
    // Target
    [dictionary setValue:_target forKey:MSID_TARGET_CACHE_KEY];
    
    // Cached at
    [dictionary setValue:_cachedAt.msidDateToTimestamp forKey:MSID_CACHED_AT_CACHE_KEY];
    
    // Expires On
    [dictionary setValue:_expiresOn.msidDateToTimestamp forKey:MSID_EXPIRES_ON_CACHE_KEY];
    
    // Token
    [dictionary setValue:_accessToken forKey:MSID_TOKEN_CACHE_KEY];
    
    /* Optional fields */
    
    // Authority
    [dictionary setValue:_authority.absoluteString forKey:MSID_AUTHORITY_CACHE_KEY];
    
    // Extended expires on
    [dictionary setValue:[self extendedExpireTime]
                  forKey:MSID_EXTENDED_EXPIRES_ON_CACHE_KEY];
    
    // ID token
    [dictionary setValue:_idToken forKey:MSID_ID_TOKEN_CACHE_KEY];
    
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
    
    [self fillToken:response
            request:requestParams];
    
    return self;
}

#pragma mark - Fill item

- (void)fillToken:(MSIDTokenResponse *)response
          request:(MSIDRequestParameters *)requestParams
{
    NSString *resource = nil;
    
    if ([requestParams isKindOfClass:[MSIDAADV1RequestParameters class]])
    {
        MSIDAADV1RequestParameters *v1RequestParams = (MSIDAADV1RequestParameters *)requestParams;
        resource = v1RequestParams.resource;
    }
    
    if ([response isKindOfClass:[MSIDAADV1TokenResponse class]])
    {
        MSIDAADV1TokenResponse *aadV1TokenResponse = (MSIDAADV1TokenResponse *)response;
        resource = aadV1TokenResponse.resource ? aadV1TokenResponse.resource : resource;
    }
    
    if (resource)
    {
        _target = resource;
    }
    else
    {
        _target = response.scope;
    }
    
    _accessToken = response.accessToken;
    _idToken = response.idToken;
    
    [self fillExpiryFromResponse:response];
    [self fillExtendedExpiryFromResponse:response];
}

- (void)fillExpiryFromResponse:(MSIDTokenResponse *)response
{
    NSDate *expiresOn = response.expiryDate;
    
    if (!expiresOn)
    {
        MSID_LOG_WARN(nil, @"The server did not return the expiration time for the access token.");
        expiresOn = [NSDate dateWithTimeIntervalSinceNow:3600.0]; //Assume 1hr expiration
    }
    
    _expiresOn = [NSDate dateWithTimeIntervalSince1970:(uint64_t)[expiresOn timeIntervalSince1970]];
}

- (void)fillExtendedExpiryFromResponse:(MSIDTokenResponse *)response
{
    if ([response isKindOfClass:[MSIDAADTokenResponse class]])
    {
        MSIDAADTokenResponse *aadTokenResponse = (MSIDAADTokenResponse *)response;
        NSMutableDictionary *serverInfo = [_additionalInfo mutableCopy];
        [serverInfo setValue:aadTokenResponse.extendedExpiresOnDate
                      forKey:MSID_EXTENDED_EXPIRES_ON_LEGACY_CACHE_KEY];
        _additionalInfo = serverInfo;
    }
}

#pragma mark - Token type

- (MSIDTokenType)tokenType
{
    return MSIDTokenTypeAccessToken;
}

#pragma mark - Expiry

- (BOOL)isExpired;
{
    NSDate *nowPlusBuffer = [NSDate dateWithTimeIntervalSinceNow:s_expirationBuffer];
    return [self.expiresOn compare:nowPlusBuffer] == NSOrderedAscending;
}

- (NSDate *)extendedExpireTime
{
    return _additionalInfo[MSID_EXTENDED_EXPIRES_ON_LEGACY_CACHE_KEY];
}

#pragma mark - Resource/scopes

- (NSString *)resource
{
    return _target;
}

- (NSOrderedSet<NSString *> *)scopes
{
    return [_target scopeSet];
}

@end
