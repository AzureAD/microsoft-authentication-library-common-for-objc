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

#import "MSIDBaseToken.h"
#import "MSIDUserInformation.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDTelemetryEventStrings.h"

@implementation MSIDBaseToken

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDBaseToken *item = [[self.class allocWithZone:zone] init];
    item->_authority = [_authority copyWithZone:zone];
    item->_clientId = [_clientId copyWithZone:zone];
    item->_clientInfo = [_clientInfo copyWithZone:zone];
    item->_additionalInfo = [_additionalInfo copyWithZone:zone];
    item->_uniqueUserId = [_uniqueUserId copyWithZone:zone];
    item->_tokenType = _tokenType;
    
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
    
    return [self isEqualToToken:(MSIDBaseToken *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;
    hash = hash * 31 + self.authority.hash;
    hash = hash * 31 + self.clientId.hash;
    hash = hash * 31 + self.clientInfo.rawClientInfo.hash;
    hash = hash * 31 + self.additionalInfo.hash;
    hash = hash * 31 + self.tokenType;
    return hash;
}

- (BOOL)isEqualToToken:(MSIDBaseToken *)token
{
    if (!token)
    {
        return NO;
    }
    
    BOOL result = YES;
    result &= (!self.authority && !token.authority) || [self.authority.absoluteString isEqualToString:token.authority.absoluteString];
    result &= (!self.clientId && !token.clientId) || [self.clientId isEqualToString:token.clientId];
    result &= (!self.clientInfo && !token.clientInfo) || [self.clientInfo.rawClientInfo isEqualToString:token.clientInfo.rawClientInfo];
    result &= (!self.additionalInfo && !token.additionalInfo) || [self.additionalInfo isEqualToDictionary:token.additionalInfo];
    result &= self.tokenType == token.tokenType;
    
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
    
    /* Mandatory fields */
    NSString *credentialType = json[MSID_CREDENTIAL_TYPE_CACHE_KEY];
    
    if (credentialType
        && ![[MSIDTokenTypeHelpers tokenTypeAsString:self.tokenType] isEqualToString:credentialType])
    {
        return nil;
    }
    
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
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [NSMutableDictionary new];
    
    /* Mandatory fields */
    
    // Unique id
    [dictionary setValue:self.clientInfo.userIdentifier
                  forKey:MSID_UNIQUE_ID_CACHE_KEY];
    
    // Environment
    [dictionary setValue:_authority.msidHostWithPortIfNecessary
                  forKey:MSID_ENVIRONMENT_CACHE_KEY];
    
    // Credential type
    NSString *credentialType = [MSIDTokenTypeHelpers tokenTypeAsString:self.tokenType];
    [dictionary setValue:credentialType
                  forKey:MSID_CREDENTIAL_TYPE_CACHE_KEY];
    
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
