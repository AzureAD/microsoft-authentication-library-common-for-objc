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
#import "MSIDAADTokenResponse.h"
#import "MSIDClientInfo.h"
#import "MSIDTelemetryEventStrings.h"

//in seconds, ensures catching of clock differences between the server and the device
static uint64_t s_expirationBuffer = 300;

@implementation MSIDToken

MSID_JSON_RW(MSID_OAUTH2_ID_TOKEN, idToken, setIdToken)
MSID_JSON_RW(MSID_FAMILY_ID, familyId, setFamilyId)
MSID_JSON_RW(MSID_OAUTH2_RESOURCE, resource, setResource)
MSID_JSON_RW(MSID_OAUTH2_CLIENT_ID, clientId, setClientId)

- (void)setToken:(NSString *)token
{
    if (token)
    {
        _json[MSID_OAUTH2_ACCESS_TOKEN] = token;
    }
    else
    {
        [_json removeObjectForKey:MSID_OAUTH2_ACCESS_TOKEN];
    }
}

- (NSString *)token
{
    return _json[MSID_OAUTH2_ACCESS_TOKEN];
}

- (void)setAdditionalServerInfo:(NSDictionary *)additionalServerInfo
{
    if (additionalServerInfo)
    {
        _json[MSID_OAUTH2_ADDITIONAL_SERVER_INFO] = additionalServerInfo;
    }
    else
    {
        [_json removeObjectForKey:MSID_OAUTH2_ADDITIONAL_SERVER_INFO];
    }
}

- (NSDictionary *)additionalServerInfo
{
    return _json[MSID_OAUTH2_ADDITIONAL_SERVER_INFO];
}

- (void)setScopes:(NSOrderedSet<NSString *> *)scopes
{
    if (scopes)
    {
        _json[MSID_OAUTH2_SCOPE] = [self scopesToString:scopes];
    }
    else
    {
        [_json removeObjectForKey:MSID_OAUTH2_SCOPE];
    }
}

- (NSOrderedSet<NSString *> *)scopes
{
    if (_json[MSID_OAUTH2_SCOPE])
    {
        return [self scopesFromString:_json[MSID_OAUTH2_SCOPE]];
    }
    
    return nil;
}

- (void)setAuthority:(NSURL *)authority
{
    if (authority)
    {
        _json[MSID_OAUTH2_AUTHORITY] = authority.absoluteString;
    }
    else
    {
        [_json removeObjectForKey:MSID_OAUTH2_AUTHORITY];
    }
}

- (NSURL *)authority
{
    if (_json[MSID_OAUTH2_AUTHORITY] )
    {
        return [[NSURL alloc] initWithString:_json[MSID_OAUTH2_AUTHORITY]];
    }
    
    return nil;
}

- (void)setClientInfo:(MSIDClientInfo *)clientInfo
{
    if (clientInfo)
    {
        _json[MSID_OAUTH2_CLIENT_INFO] = clientInfo.rawClientInfo;
    }
    else
    {
        [_json removeObjectForKey:MSID_OAUTH2_CLIENT_INFO];
    }
}

- (MSIDClientInfo *)clientInfo
{
    if (_json[MSID_OAUTH2_CLIENT_INFO])
    {
        return [[MSIDClientInfo alloc] initWithRawClientInfo:_json[MSID_OAUTH2_CLIENT_INFO] error:nil];
    }
    
    return nil;
}

- (void)setExpiresOn:(NSDate *)expiresOn
{
    if (expiresOn)
    {
        _json[MSID_OAUTH2_EXPIRES_ON] = [NSString stringWithFormat:@"%qu", (uint64_t)[expiresOn timeIntervalSince1970]];
    }
    else
    {
        [_json removeObjectForKey:MSID_OAUTH2_EXPIRES_ON];
    }
}

- (NSDate *)expiresOn
{
    if (_json[MSID_OAUTH2_EXPIRES_ON])
    {
        return [NSDate dateWithTimeIntervalSince1970:[_json[MSID_OAUTH2_EXPIRES_ON] doubleValue]];
    }
    
    return nil;
}

- (BOOL)isExpired;
{
    NSDate *nowPlusBuffer = [NSDate dateWithTimeIntervalSinceNow:s_expirationBuffer];
    return [self.expiresOn compare:nowPlusBuffer] == NSOrderedAscending;
}

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
    result &= (!self.clientInfo && !token.clientInfo) || [self.clientInfo.rawClientInfo isEqualToString:token.clientInfo.rawClientInfo];
    result &= (!self.additionalServerInfo && !token.additionalServerInfo) || [self.additionalServerInfo isEqualToDictionary:token.additionalServerInfo];
    result &= self.tokenType == token.tokenType;
    result &= (!self.resource && !token.resource) || [self.resource isEqualToString:token.resource];
    result &= (!self.authority && !token.authority) || [self.authority.absoluteString isEqualToString:token.authority.absoluteString];
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
    
    self.familyId = [coder decodeObjectOfClass:[NSString class] forKey:@"familyId"];
    self.expiresOn = [coder decodeObjectOfClass:[NSDate class] forKey:@"expiresOn"];
    
    NSString *accessToken = [coder decodeObjectOfClass:[NSString class] forKey:@"accessToken"];
    NSString *refreshToken = [coder decodeObjectOfClass:[NSString class] forKey:@"refreshToken"];
    
    if (refreshToken)
    {
        self.token = refreshToken;
        _tokenType = MSIDTokenTypeRefreshToken;
    }
    else
    {
        self.token = accessToken;
        _tokenType = MSIDTokenTypeAccessToken;
    }
    
    self.additionalServerInfo = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"additionalServer"];
    
    NSString *rawClientInfo = [coder decodeObjectOfClass:[NSString class] forKey:@"clientInfo"];
    
    NSError *error = nil;
    self.clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:rawClientInfo error:&error];
    
    if (error)
    {
        MSID_LOG_WARN(nil, @"Couln't initialize client info when deserializing token");
    }
    
    self.idToken = [[coder decodeObjectOfClass:[MSIDUserInformation class] forKey:@"userInformation"] rawIdToken];
    self.resource = [coder decodeObjectOfClass:[NSString class] forKey:@"resource"];

    NSString *authorityString = [coder decodeObjectOfClass:[NSString class] forKey:@"authority"];
    self.authority = [NSURL URLWithString:authorityString];
    
    self.clientId = [coder decodeObjectOfClass:[NSString class] forKey:@"clientId"];
    self.scopes = [coder decodeObjectOfClass:[NSOrderedSet class] forKey:@"scopes"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.familyId forKey:@"familyId"];
    [coder encodeObject:self.expiresOn forKey:@"expiresOn"];
    
    if (self.tokenType == MSIDTokenTypeRefreshToken)
    {
        [coder encodeObject:self.token forKey:@"refreshToken"];
    }
    else
    {
        [coder encodeObject:self.token forKey:@"accessToken"];
    }
    // Backward compatibility with ADAL.
    [coder encodeObject:@"Bearer" forKey:@"accessTokenType"];
    
    [coder encodeObject:self.clientInfo.rawClientInfo forKey:@"clientInfo"];
    [coder encodeObject:self.additionalServerInfo forKey:@"additionalServer"];
    
    MSIDUserInformation *userInformation = [MSIDUserInformation new];
    userInformation.rawIdToken = self.idToken;
    [coder encodeObject:userInformation forKey:@"userInformation"];
    
    [coder encodeObject:self.resource forKey:@"resource"];
    [coder encodeObject:self.authority.absoluteString forKey:@"authority"];
    [coder encodeObject:self.clientId forKey:@"clientId"];
    [coder encodeObject:self.scopes forKey:@"scopes"];
}

#pragma mark - Init

- (instancetype)initWithTokenResponse:(MSIDTokenResponse *)response
                              request:(MSIDTokenRequest *)request
                            tokenType:(MSIDTokenType)tokenType
{
    if (!response
        || !request)
    {
        return nil;
    }
    
    if (!(self = [super init]))
    {
        return nil;
    }
    
    [self fillFromRequest:request];
    [self fillFromResponse:response tokenType:tokenType];
    [self fillExpiryFromResponse:response];
    [self fillAdditionalServerInfoFromResponse:response];
    
    return self;
}

#pragma mark - Private

- (NSMutableOrderedSet<NSString *> *)scopesFromString:(NSString *)scopesString
{
    NSMutableOrderedSet<NSString *> *scope = [NSMutableOrderedSet<NSString *> new];
    NSArray *parts = [scopesString componentsSeparatedByString:@" "];
    for (NSString *part in parts)
    {
        if (![NSString msidIsStringNilOrBlank:part])
        {
            [scope addObject:part.msidTrimmedString.lowercaseString];
        }
    }
    
    return scope;
}

- (NSString *)scopesToString:(NSOrderedSet<NSString *> *)scopes
{
    return [scopes.array componentsJoinedByString:@" "];
}


#pragma mark - Fill item

- (void)fillFromRequest:(MSIDTokenRequest *)tokenRequest
{
    self.authority = tokenRequest.authority;
    self.clientId = tokenRequest.clientId;
}

- (void)fillFromResponse:(MSIDTokenResponse *)tokenResponse
               tokenType:(MSIDTokenType)tokenType
{
    _tokenType = tokenType;
    self.idToken = tokenResponse.idToken;
    
    NSString *resource = nil;
    NSString *familyId = nil;
    
    if ([tokenResponse isKindOfClass:[MSIDAADTokenResponse class]])
    {
        MSIDAADTokenResponse *aadTokenResponse = (MSIDAADTokenResponse *)tokenResponse;
        resource = aadTokenResponse.resource;
        familyId = aadTokenResponse.familyId;
        self.clientInfo = aadTokenResponse.clientInfo;
    }
    
    switch (tokenType)
    {
        case MSIDTokenTypeAccessToken:
        {
            self.resource = resource;
            self.token = tokenResponse.accessToken;
            self.scopes = [tokenResponse.scope scopeSet];
            
            break;
        }
        case MSIDTokenTypeRefreshToken:
        {
            self.token = tokenResponse.refreshToken;
            self.familyId = familyId;
            break;
        }
        case MSIDTokenTypeAdfsUserToken:
        {
            self.resource = resource;
            self.token = tokenResponse.refreshToken;
            break;
        }
        default:
            break;
    }
}

- (void)fillExpiryFromResponse:(MSIDTokenResponse *)tokenResponse
{
    NSDate *expiryDate = tokenResponse.expiryDate;
    
    if (!expiryDate)
    {
        MSID_LOG_WARN(nil, @"The server did not return the expiration time for the access token.");
        expiryDate = [NSDate dateWithTimeIntervalSinceNow:3600.0]; //Assume 1hr expiration
    }
    else
    {
        self.expiresOn = expiryDate;
    }
}

- (void)fillAdditionalServerInfoFromResponse:(MSIDTokenResponse *)tokenResponse
{
    NSMutableDictionary *serverInfo = [NSMutableDictionary dictionary];
    
    if ([tokenResponse isKindOfClass:[MSIDAADTokenResponse class]])
    {
        MSIDAADTokenResponse *aadTokenResponse = (MSIDAADTokenResponse *)tokenResponse;
        [serverInfo setObject:aadTokenResponse.extendedExpiresIn forKey:@"ext_expires_on"];
        [serverInfo setObject:aadTokenResponse.speInfo forKey:MSID_TELEMETRY_KEY_SPE_INFO];
    }
    
    self.additionalServerInfo = serverInfo;
}

@end
