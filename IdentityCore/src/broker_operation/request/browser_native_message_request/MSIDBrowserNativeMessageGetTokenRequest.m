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


#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAuthenticationScheme.h"
#import "MSIDAADAuthority.h"

NSString *const BROWSER_NATIVE_MESSAGE_CORRELATION_KEY = @"correlationId";
NSString *const BROWSER_NATIVE_MESSAGE_ACCOUNT_ID_KEY = @"accountId";
NSString *const BROWSER_NATIVE_MESSAGE_CLIENT_ID_KEY = @"clientId";
NSString *const BROWSER_NATIVE_MESSAGE_AUTHORITY_KEY = @"authority";
NSString *const BROWSER_NATIVE_MESSAGE_SCOPE_KEY = @"scopes";// TODO: should be "scope"
NSString *const BROWSER_NATIVE_MESSAGE_REDIRECT_URI_KEY = @"redirectUri";
NSString *const BROWSER_NATIVE_MESSAGE_PROMPT_KEY = @"prompt";
NSString *const BROWSER_NATIVE_MESSAGE_NONCE_KEY = @"nonce";
NSString *const BROWSER_NATIVE_MESSAGE_IS_STS_KEY = @"isSts";
NSString *const BROWSER_NATIVE_MESSAGE_STATE_KEY = @"state";
NSString *const BROWSER_NATIVE_MESSAGE_LOGIN_HINT_KEY = @"loginHint";
NSString *const BROWSER_NATIVE_MESSAGE_INSTANCE_AWARE_KEY = @"instance_aware";
NSString *const BROWSER_NATIVE_MESSAGE_EXTRA_PARAMETERS_KEY = @"extraParameters";
NSString *const BROWSER_NATIVE_MESSAGE_REQUEST_KEY = @"request";

@implementation MSIDBrowserNativeMessageGetTokenRequest

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.operation];
}

+ (NSString *)operation
{
    return @"GetToken";
}

- (MSIDInteractiveTokenRequestParameters *)interactiveTokenRequestParameters
{
    NSError *error = nil;
    
    NSError *localError = nil;
    MSIDAADAuthority *aadAuthority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:self.authority]
                                                                 rawTenant:nil
                                                                   context:nil
                                                                     error:&localError];
    
//    if (!aadAuthority)
//    {
//        if (error)
//        {
//            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Non AAD authorities are not supported in broker - %@", MSID_PII_LOG_MASKABLE(localError));
//            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Non AAD authorities are not supported in broker", nil, nil, nil, nil, nil, YES);
//        }
//        
//        return nil;
//    }
    
    
    
    __auto_type params =
    [[MSIDInteractiveTokenRequestParameters alloc] initWithAuthority:aadAuthority // TODO: fix
                                                          authScheme:[MSIDAuthenticationScheme new] // TODO: fix
                                                         redirectUri:@"msauth.com.microsoft.MSALTestApp://auth"//self.redirectUri
                                                            clientId:self.clientId
                                                              scopes:nil
                                                          oidcScopes:nil
                                                extraScopesToConsent:nil
                                                       correlationId:self.correlationId
                                                      telemetryApiId:nil
                                                       brokerOptions:nil
                                                         requestType:MSIDRequestLocalType
                                                 intuneAppIdentifier:nil
                                                               error:&error];
    
    if (error)
    {
        // TODO: error
        return nil;
    }
    
    return params;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    if (!self) return nil;
    
    
    if (![json msidAssertType:NSDictionary.class ofKey:BROWSER_NATIVE_MESSAGE_REQUEST_KEY required:YES error:error]) return nil;
    NSDictionary *requestJson = json[BROWSER_NATIVE_MESSAGE_REQUEST_KEY];
    
    _accountId = [requestJson msidStringObjectForKey:BROWSER_NATIVE_MESSAGE_ACCOUNT_ID_KEY];
    
    if (![requestJson msidAssertType:NSString.class ofKey:BROWSER_NATIVE_MESSAGE_CLIENT_ID_KEY required:YES error:error]) return nil;
    _clientId = requestJson[BROWSER_NATIVE_MESSAGE_CLIENT_ID_KEY];

    _authority = [requestJson msidStringObjectForKey:BROWSER_NATIVE_MESSAGE_AUTHORITY_KEY];
    
    if (![requestJson msidAssertType:NSString.class ofKey:BROWSER_NATIVE_MESSAGE_SCOPE_KEY required:YES error:error]) return nil;
    _scope = requestJson[BROWSER_NATIVE_MESSAGE_SCOPE_KEY];
    
    if (![requestJson msidAssertType:NSString.class ofKey:BROWSER_NATIVE_MESSAGE_REDIRECT_URI_KEY required:YES error:error]) return nil;
    _redirectUri = requestJson[BROWSER_NATIVE_MESSAGE_REDIRECT_URI_KEY];
    
    _prompt = [requestJson msidStringObjectForKey:BROWSER_NATIVE_MESSAGE_PROMPT_KEY];
    _nonce = [requestJson msidStringObjectForKey:BROWSER_NATIVE_MESSAGE_NONCE_KEY];
    _isSts = [requestJson msidBoolObjectForKey:BROWSER_NATIVE_MESSAGE_IS_STS_KEY];
    _state = [requestJson msidStringObjectForKey:BROWSER_NATIVE_MESSAGE_STATE_KEY];
    _loginHint = [requestJson msidStringObjectForKey:BROWSER_NATIVE_MESSAGE_LOGIN_HINT_KEY];
    _instanceAware = [requestJson msidBoolObjectForKey:BROWSER_NATIVE_MESSAGE_INSTANCE_AWARE_KEY];
    
    if (![requestJson msidAssertType:NSDictionary.class ofKey:BROWSER_NATIVE_MESSAGE_EXTRA_PARAMETERS_KEY required:NO error:error]) return nil;
    _extraParameters = requestJson[BROWSER_NATIVE_MESSAGE_EXTRA_PARAMETERS_KEY];

    if (![requestJson msidAssertType:NSString.class ofKey:BROWSER_NATIVE_MESSAGE_CORRELATION_KEY required:YES error:error]) return nil;
    NSString *uuidString = requestJson[BROWSER_NATIVE_MESSAGE_CORRELATION_KEY];
    _correlationId = [[NSUUID alloc] initWithUUIDString:uuidString];
    if (!_correlationId) return nil; // TODO: should it be required?
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    // TODO: throw ?
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    if (!json) return nil;
    
    if (![NSString msidIsStringNilOrBlank:self.accountId])
    {
        json[BROWSER_NATIVE_MESSAGE_ACCOUNT_ID_KEY] = self.accountId;
    }
    
    if ([NSString msidIsStringNilOrBlank:self.clientId]) return nil;
    json[BROWSER_NATIVE_MESSAGE_CLIENT_ID_KEY] = self.clientId;
    
    if (![NSString msidIsStringNilOrBlank:self.authority])
    {
        json[BROWSER_NATIVE_MESSAGE_AUTHORITY_KEY] = self.authority;
    }
    
    if ([NSString msidIsStringNilOrBlank:self.scope]) return nil;
    json[BROWSER_NATIVE_MESSAGE_SCOPE_KEY] = self.scope;
    
    if ([NSString msidIsStringNilOrBlank:self.redirectUri]) return nil;
    json[BROWSER_NATIVE_MESSAGE_REDIRECT_URI_KEY] = self.redirectUri;
    
    if (![NSString msidIsStringNilOrBlank:self.prompt])
    {
        json[BROWSER_NATIVE_MESSAGE_PROMPT_KEY] = self.prompt;
    }
    
    json[BROWSER_NATIVE_MESSAGE_IS_STS_KEY] = [@(self.isSts) stringValue];
    json[BROWSER_NATIVE_MESSAGE_NONCE_KEY] = self.nonce;
    json[BROWSER_NATIVE_MESSAGE_STATE_KEY] = self.state;
    json[BROWSER_NATIVE_MESSAGE_LOGIN_HINT_KEY] = self.loginHint;
    json[BROWSER_NATIVE_MESSAGE_INSTANCE_AWARE_KEY] = [@(self.instanceAware) stringValue];
    json[BROWSER_NATIVE_MESSAGE_EXTRA_PARAMETERS_KEY] = [self.extraParameters msidNormalizedJSONDictionary];
    json[BROWSER_NATIVE_MESSAGE_CORRELATION_KEY] = self.correlationId.UUIDString;
    
    return json;
}

@end
