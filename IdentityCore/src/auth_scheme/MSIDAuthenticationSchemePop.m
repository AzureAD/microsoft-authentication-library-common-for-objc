//------------------------------------------------------------------------------
//
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDAuthenticationSchemePop.h"
#import "MSIDDevicePopManager.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDAccessTokenWithAuthScheme.h"
#import "MSIDAuthScheme.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDJsonSerializableTypes.h"

@interface MSIDAuthenticationSchemePop()

@property (nonatomic) NSString *kid;
@property (nonatomic) NSString *req_cnf;

@end


@implementation MSIDAuthenticationSchemePop

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:MSIDAuthSchemeParamFromType(MSIDAuthSchemePop)];
}

- (instancetype)initWithSchemeParameters:(NSDictionary *)schemeParameters
{
    self = [super initWithSchemeParameters:schemeParameters];
    
    if (self)
    {
        _req_cnf = [_schemeParameters msidObjectForKey:MSID_OAUTH2_REQUEST_CONFIRMATION ofClass:[NSString class]];
        
        if (!_req_cnf)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to read req_cnf from scheme parameters.");
            return nil;
        }
        
        NSString *kidJwk = [_req_cnf msidBase64UrlDecode];
        NSData *kidData = [kidJwk dataUsingEncoding:NSUTF8StringEncoding];
        
        NSError *kidReadingError = nil;
        NSDictionary *kidDict = [NSJSONSerialization JSONObjectWithData:kidData options:0 error:&kidReadingError];
        _kid = [kidDict objectForKey:MSID_KID_CACHE_KEY];
        if (!_kid)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError,nil, @"Failed to generate kid from req_cnf, error: %@", MSID_PII_LOG_MASKABLE(kidReadingError));
            return nil;
        }
    }
    
    return self;
}

- (MSIDAuthScheme)authSchemeFromParameters:(NSDictionary *)schemeParameters
{
    NSString *scheme = [schemeParameters msidObjectForKey:MSID_OAUTH2_TOKEN_TYPE ofClass:[NSString class]];
    if (!scheme)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to read auth_scheme from scheme parameters.");
    }
    
    return MSIDAuthSchemeTypeFromString(scheme);
}

- (MSIDAccessToken *)blankAccessToken
{
    MSIDAccessTokenWithAuthScheme *blankAccessToken = [MSIDAccessTokenWithAuthScheme new];
    blankAccessToken.accessTokenType = self.tokenType;
    blankAccessToken.kid = self.kid;
    return blankAccessToken;
}

- (MSIDCredentialType)credentialType
{
    return MSIDAccessTokenWithAuthSchemeType;
}

- (NSString *)tokenType
{
    return MSIDAuthSchemeParamFromType(self.authScheme);
}

- (BOOL)matchAccessTokenKeyThumbprint:(MSIDAccessToken *)accessToken
{
    return accessToken.kid && self.kid && [self.kid isEqualToString:accessToken.kid];
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    NSMutableDictionary *schemeParameters = [NSMutableDictionary new];
    NSString *requestConf = json[MSID_OAUTH2_REQUEST_CONFIRMATION];
    if (!requestConf)
    {
        NSString *message = [NSString stringWithFormat:@"Failed to init %@ from json: req_cnf is nil", self.class];
        if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, message, nil, nil, nil, nil, nil, YES);
        return nil;
    }
    
    NSString *authScheme = json[MSID_OAUTH2_TOKEN_TYPE];
    if (!authScheme)
    {
        NSString *message = [NSString stringWithFormat:@"Failed to init %@ from json: auth_scheme is nil", self.class];
        if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, message, nil, nil, nil, nil, nil, YES);
        return nil;
    }
    
    [schemeParameters setObject:requestConf forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    [schemeParameters setObject:authScheme forKey:MSID_OAUTH2_TOKEN_TYPE];
    
    return [self initWithSchemeParameters:schemeParameters];
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    if (self.authScheme != MSIDAuthSchemePop)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create json for %@: invalid auth_scheme.", self.class);
        return nil;
    }
    
    json[MSID_OAUTH2_TOKEN_TYPE] = MSIDAuthSchemeParamFromType(self.authScheme);
    
    if (!self.req_cnf)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create json for %@: req_cnf is nil.", self.class);
        return nil;
    }
    
    json[MSID_OAUTH2_REQUEST_CONFIRMATION] = self.req_cnf;
    
    return json;
}

- (id)copyWithZone:(NSZone *)zone
{
    MSIDAuthenticationSchemePop *authScheme = [super copyWithZone:zone];
    authScheme->_kid = [_kid copyWithZone:zone];
    authScheme->_req_cnf = [_req_cnf copyWithZone:zone];
    return authScheme;
}

@end
