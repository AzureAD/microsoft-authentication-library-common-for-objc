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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  


#import "MSIDAuthenticationSchemeSshCert.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDAuthScheme.h"

@interface MSIDAuthenticationSchemeSshCert()

@property (nonatomic) NSString *keyId;
@property (nonatomic) NSString *req_cnf;

@end

@implementation MSIDAuthenticationSchemeSshCert

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:MSIDAuthSchemeParamFromType(MSIDAuthSchemeSshCert)];
}

- (instancetype)initWithSchemeParameters:(NSDictionary *)schemeParameters
{
    self = [super initWithSchemeParameters:schemeParameters];
    
    if (self)
    {
        if (_authScheme != MSIDAuthSchemeSshCert)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Wrong token_type string");
            return nil;
        }
        
        _req_cnf = [_schemeParameters msidObjectForKey:MSID_OAUTH2_REQUEST_CONFIRMATION ofClass:[NSString class]];
        if ([NSString msidIsStringNilOrBlank:_req_cnf])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to read req_cnf from scheme parameters.");
            return nil;
        }
        
        _keyId = [_schemeParameters msidObjectForKey:@"key_id" ofClass:[NSString class]];
        if ([NSString msidIsStringNilOrBlank:_keyId])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to read _keyId from scheme parameters.");
            return nil;
        }
    }
    
    return self;
}

- (MSIDCredentialType)credentialType
{
    return MSIDCredentialTypeOther;
}

- (NSString *)tokenType
{
    return MSIDAuthSchemeParamFromType(self.authScheme);
}

- (MSIDAuthScheme)authSchemeFromParameters:(__unused NSDictionary *)schemeParameters
{
    return MSIDAuthSchemeSshCert;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    NSMutableDictionary *schemeParameters = [NSMutableDictionary new];
    NSString *requestConf = json[MSID_OAUTH2_REQUEST_CONFIRMATION];
    if ([NSString msidIsStringNilOrBlank:requestConf])
    {
        NSString *message = [NSString stringWithFormat:@"Failed to init %@ from json: req_cnf is nil", self.class];
        if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, message, nil, nil, nil, nil, nil, YES);
        return nil;
    }
    
    NSString *authScheme = json[MSID_OAUTH2_TOKEN_TYPE];
    if ([NSString msidIsStringNilOrBlank:authScheme])
    {
        NSString *message = [NSString stringWithFormat:@"Failed to init %@ from json: auth_scheme is nil", self.class];
        if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, message, nil, nil, nil, nil, nil, YES);
        return nil;
    }
    
    NSString *keyId = json[@"keyId"];
    if ([NSString msidIsStringNilOrBlank:authScheme])
    {
        NSString *message = [NSString stringWithFormat:@"Failed to init %@ from json: key_id is nil", self.class];
        if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, message, nil, nil, nil, nil, nil, YES);
        return nil;
    }
    
    [schemeParameters setObject:keyId forKey:@"keyId"];
    [schemeParameters setObject:requestConf forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    [schemeParameters setObject:authScheme forKey:MSID_OAUTH2_TOKEN_TYPE];
    
    return [self initWithSchemeParameters:schemeParameters];
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    if (self.authScheme != MSIDAuthSchemeSshCert)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create json for %@: invalid auth_scheme.", self.class);
        return nil;
    }
    
    json[MSID_OAUTH2_TOKEN_TYPE] = MSIDAuthSchemeParamFromType(self.authScheme);
    
    if ([NSString msidIsStringNilOrBlank:self.req_cnf])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create json for %@: req_cnf is nil.", self.class);
        return nil;
    }
    
    json[MSID_OAUTH2_REQUEST_CONFIRMATION] = self.req_cnf;
    
    if ([NSString msidIsStringNilOrBlank:self.keyId])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create json for %@: req_cnf is nil.", self.class);
        return nil;
    }
    
    json[@"key_id"] = self.keyId;
    
    return json;
}

@end
