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

@implementation MSIDTokenCacheItem

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
    
    // Decode id_token from a backward compatible way
    _idToken = [[coder decodeObjectOfClass:[MSIDUserInformation class] forKey:@"userInformation"] rawIdToken];
    
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
    
    // Client ID
    _clientId = json[MSID_CLIENT_ID_CACHE_KEY];
    
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
    if (!_authority && _tenant)
    {
        if (_tenant)
        {
            _authority = [NSURL msidURLWithEnvironment:_environment tenant:_tenant];
        }
        else
        {
            _authority = [NSURL msidURLWithEnvironment:_environment];
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
    
    return dictionary;
}

@end
