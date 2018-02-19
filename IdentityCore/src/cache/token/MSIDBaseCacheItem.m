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

#import "MSIDBaseCacheItem.h"
#import "MSIDAADTokenResponse.h"

@implementation MSIDBaseCacheItem

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDBaseCacheItem *item = [[self.class allocWithZone:zone] init];
    item->_authority = [_authority copyWithZone:zone];
    item->_clientId = [_clientId copyWithZone:zone];
    item->_clientInfo = [_clientInfo copyWithZone:zone];
    item->_additionalInfo = [_additionalInfo copyWithZone:zone];
    item->_uniqueUserId = [_uniqueUserId copyWithZone:zone];
    item->_username = [_username copyWithZone:zone];
    
    return item;
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
    
    NSString *authorityString = [coder decodeObjectOfClass:[NSString class] forKey:@"authority"];
    
    if (authorityString)
    {
        _authority = [NSURL URLWithString:authorityString];
    }
    
    _clientId = [coder decodeObjectOfClass:[NSString class] forKey:@"clientId"];
    
    // Decode client info from string
    NSString *rawClientInfo = [coder decodeObjectOfClass:[NSString class] forKey:@"clientInfo"];
    
    NSError *error = nil;
    _clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:rawClientInfo error:&error];
    
    if (error)
    {
        MSID_LOG_ERROR(nil, @"Client info is corrupted.");
        MSID_LOG_ERROR_PII(nil, @"Client info is corrupted, error: %@", error);
    }
    
    _additionalInfo = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"additionalServer"];
    _username = [coder decodeObjectOfClass:[NSString class] forKey:@"username"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.authority.absoluteString forKey:@"authority"];
    [coder encodeObject:self.clientId forKey:@"clientId"];
    
    // Encode client info as string
    [coder encodeObject:self.clientInfo.rawClientInfo forKey:@"clientInfo"];
    [coder encodeObject:self.additionalInfo forKey:@"additionalServer"];
    
    // Backward compatibility with ADAL.
    [coder encodeObject:@"Bearer" forKey:@"accessTokenType"];
    [coder encodeObject:[NSMutableDictionary dictionary] forKey:@"additionalClient"];
    [coder encodeObject:self.username forKey:@"username"];
}

#pragma mark - NSObject

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
    
    return [self isEqualToItem:(MSIDBaseCacheItem *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;
    hash = hash * 31 + self.authority.hash;
    hash = hash * 31 + self.clientId.hash;
    hash = hash * 31 + self.clientInfo.rawClientInfo.hash;
    hash = hash * 31 + self.additionalInfo.hash;
    hash = hash * 31 + self.username.hash;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDBaseCacheItem *)item
{
    if (!item)
    {
        return NO;
    }
    
    BOOL result = YES;
    result &= (!self.authority && !item.authority) || [self.authority.absoluteString isEqualToString:item.authority.absoluteString];
    result &= (!self.clientId && !item.clientId) || [self.clientId isEqualToString:item.clientId];
    result &= (!self.clientInfo && !item.clientInfo) || [self.clientInfo.rawClientInfo isEqualToString:item.clientInfo.rawClientInfo];
    result &= (!self.additionalInfo && !item.additionalInfo) || [self.additionalInfo isEqualToDictionary:item.additionalInfo];
    result &= (!self.username && !item.username) || [self.username isEqualToString:item.username];
    
    return result;
}

#pragma mark - JSON

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (!(self = [super initWithJSONDictionary:json error:error]))
    {
        return nil;
    }
    
    // We don't use _json variable.
    _json = nil;
    
    // Unique ID
    _uniqueUserId = json[MSID_UNIQUE_ID_CACHE_KEY];
    
    // Environment
    NSString *environment = json[MSID_ENVIRONMENT_CACHE_KEY];
    
    if (environment)
    {
        NSString *authority = [NSString stringWithFormat:@"https://%@/common", environment];
        _authority = [[NSURL alloc] initWithString:authority];
    }
    
    // Client ID
    _clientId = json[MSID_CLIENT_ID_CACHE_KEY];
    
    /* Optional fields */
    
    // Client info
    NSError *err;
    _clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:json[MSID_OAUTH2_CLIENT_INFO] error:&err];
    
    if (err)
    {
        MSID_LOG_ERROR(nil, @"Client info is corrupted.");
        MSID_LOG_ERROR_PII(nil, @"Client info is corrupted, error: %@", err);
    }
    
    // SPE info
    _additionalInfo = [NSMutableDictionary dictionary];
    if (json[MSID_SPE_INFO_CACHE_KEY])
    {
        [_additionalInfo setValue:json[MSID_SPE_INFO_CACHE_KEY] forKey:MSID_SPE_INFO_CACHE_KEY];
    }
    
    // Username
    _username = json[MSID_USERNAME_CACHE_KEY];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [NSMutableDictionary new];
    
    /* Mandatory fields */
    
    // Unique id
    NSString *uniqueUserId = self.uniqueUserId ? self.uniqueUserId : self.clientInfo.userIdentifier;
    [dictionary setValue:uniqueUserId
                  forKey:MSID_UNIQUE_ID_CACHE_KEY];
    
    // Environment
    [dictionary setValue:_authority.msidHostWithPortIfNecessary
                  forKey:MSID_ENVIRONMENT_CACHE_KEY];
    
    // Client ID
    [dictionary setValue:_clientId
                  forKey:MSID_CLIENT_ID_CACHE_KEY];
    
    /* Optional fields */
    
    // Client info
    [dictionary setValue:_clientInfo.rawClientInfo
                  forKey:MSID_CLIENT_INFO_CACHE_KEY];
    
    // SPE info
    [dictionary setValue:_additionalInfo[MSID_SPE_INFO_CACHE_KEY]
                  forKey:MSID_SPE_INFO_CACHE_KEY];
    
    // Username
    [dictionary setValue:_username
                  forKey:MSID_USERNAME_CACHE_KEY];
    
    return dictionary;
}

#pragma mark - Init

- (instancetype)initWithTokenResponse:(MSIDTokenResponse *)response
                              request:(MSIDRequestParameters *)requestParams
{
    if (!response
        || !requestParams)
    {
        return nil;
    }
    
    if (!(self = [super init]))
    {
        return nil;
    }
    
    [self fillTokenFromResponse:response
                        request:requestParams];
    
    return self;
}

#pragma mark - Fill item

- (void)fillTokenFromResponse:(MSIDTokenResponse *)response
                      request:(MSIDRequestParameters *)requestParams
{
    // Fill from request
    _authority = requestParams.authority;
    _clientId = requestParams.clientId;
    _additionalInfo = [NSMutableDictionary dictionary];
    _username = response.idTokenObj.preferredUsername ? response.idTokenObj.preferredUsername : response.idTokenObj.userId;
    
    // Fill in client info and spe info
    if ([response isKindOfClass:[MSIDAADTokenResponse class]])
    {
        MSIDAADTokenResponse *aadTokenResponse = (MSIDAADTokenResponse *)response;
        _clientInfo = aadTokenResponse.clientInfo;
        _uniqueUserId = _clientInfo.userIdentifier;
        [_additionalInfo setValue:aadTokenResponse.speInfo
                           forKey:MSID_SPE_INFO_CACHE_KEY];
    }
    else
    {
        _uniqueUserId = response.idTokenObj.userId;
    }
}

@end
