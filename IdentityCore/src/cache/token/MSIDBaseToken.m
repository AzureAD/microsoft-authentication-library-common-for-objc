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
    item->_idToken = [_idToken copyWithZone:zone];
    item->_additionalServerInfo = [_additionalServerInfo copyWithZone:zone];
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
    _authority = [NSURL URLWithString:authorityString];
    
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
    
    // Decode id_token from a backward compatible way
    _idToken = [[coder decodeObjectOfClass:[MSIDUserInformation class] forKey:@"userInformation"] rawIdToken];
    
    _additionalServerInfo = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"additionalServer"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.authority.absoluteString forKey:@"authority"];
    [coder encodeObject:self.clientId forKey:@"clientId"];
    
    // Encode client info as string
    [coder encodeObject:self.clientInfo.rawClientInfo forKey:@"clientInfo"];
    
    // Encode id_token in backward compatible way with ADAL
    MSIDUserInformation *userInformation = [MSIDUserInformation new];
    userInformation.rawIdToken = self.idToken;
    [coder encodeObject:userInformation forKey:@"userInformation"];
    
    [coder encodeObject:self.additionalServerInfo forKey:@"additionalServer"];
    
    // Backward compatibility with ADAL.
    [coder encodeObject:@"Bearer" forKey:@"accessTokenType"];
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
    NSUInteger hash = self.authority.hash;
    hash ^= self.clientId.hash;
    hash ^= self.clientInfo.rawClientInfo.hash;
    hash ^= self.idToken.hash;
    hash ^= self.additionalServerInfo.hash;
    hash ^= self.tokenType;
    
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
    result &= (!self.idToken && !token.idToken) || [self.idToken isEqualToString:token.idToken];
    result &= (!self.additionalServerInfo && !token.additionalServerInfo) || [self.additionalServerInfo isEqualToDictionary:token.additionalServerInfo];
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
    
    // Fill in authority URL
    NSString *authorityString = json[MSID_OAUTH2_AUTHORITY];
    NSString *environment = json[MSID_OAUTH2_ENVIRONMENT];
    
    if (!authorityString && environment)
    {
        NSString *authority = [NSString stringWithFormat:@"https://%@/common", environment];
        _authority = [[NSURL alloc] initWithString:authority];
    }
    else
    {
        _authority = authorityString ? [[NSURL alloc] initWithString:authorityString] : nil;
    }
    
    // Fill in client info
    NSError *err;
    _clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:json[MSID_OAUTH2_CLIENT_INFO] error:&err];
    
    if (err)
    {
        MSID_LOG_ERROR(nil, @"Client info is corrupted.");
        MSID_LOG_ERROR_PII(nil, @"Client info is corrupted, error: %@", err);
    }
    
    _clientId = json[MSID_OAUTH2_CLIENT_ID];
    _idToken = json[MSID_OAUTH2_ID_TOKEN];
    _additionalServerInfo = json[MSID_OAUTH2_ADDITIONAL_SERVER_INFO];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [NSMutableDictionary new];
    [dictionary setValue:_authority.absoluteString forKey:MSID_OAUTH2_AUTHORITY];
    [dictionary setValue:_authority.msidHostWithPortIfNecessary
                  forKey:MSID_OAUTH2_ENVIRONMENT];
    [dictionary setValue:_clientInfo.rawClientInfo forKey:MSID_OAUTH2_CLIENT_INFO];
    [dictionary setValue:_idToken forKey:MSID_OAUTH2_ID_TOKEN];
    [dictionary setValue:_additionalServerInfo
                  forKey:MSID_OAUTH2_ADDITIONAL_SERVER_INFO];
    [dictionary setValue:_clientId
                  forKey:MSID_OAUTH2_CLIENT_ID];
    
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
    
    _idToken = response.idToken;
    
    // Fill in client info and spe info
    if ([response isKindOfClass:[MSIDAADTokenResponse class]])
    {
        MSIDAADTokenResponse *aadTokenResponse = (MSIDAADTokenResponse *)response;
        _clientInfo = aadTokenResponse.clientInfo;
        
        NSMutableDictionary *serverInfo = [NSMutableDictionary dictionary];
        [serverInfo setValue:aadTokenResponse.speInfo
                      forKey:MSID_TELEMETRY_KEY_SPE_INFO];
        _additionalServerInfo = serverInfo;
    }
}

@end
