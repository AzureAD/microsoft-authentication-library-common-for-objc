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
#import "MSIDAADAuthority.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDConstants.h"
#import "MSIDPromptType_Internal.h"

NSString *const MSID_BROWSER_NATIVE_MESSAGE_CORRELATION_KEY = @"correlationId";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_CLIENT_ID_KEY = @"clientId";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_AUTHORITY_KEY = @"authority";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_SCOPE_KEY = @"scope";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_REDIRECT_URI_KEY = @"redirectUri";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_PROMPT_KEY = @"prompt";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_NONCE_KEY = @"nonce";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_IS_STS_KEY = @"isSts";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_STATE_KEY = @"state";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_LOGIN_HINT_KEY = @"loginHint";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_INSTANCE_AWARE_KEY = @"instance_aware";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_EXTRA_PARAMETERS_KEY = @"extraParameters";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_REQUEST_KEY = @"request";

@implementation MSIDBrowserNativeMessageGetTokenRequest

+ (void)load
{
//    [MSIDJsonSerializableFactory registerClass:self forClassType:self.operation];
}

+ (NSString *)operation
{
    return @"GetToken";
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    if (!self) return nil;
    
    if (![json msidAssertType:NSDictionary.class ofKey:MSID_BROWSER_NATIVE_MESSAGE_REQUEST_KEY required:YES error:error]) return nil;
    NSDictionary *requestJson = json[MSID_BROWSER_NATIVE_MESSAGE_REQUEST_KEY];
    
    _loginHint = [requestJson msidStringObjectForKey:MSID_BROWSER_NATIVE_MESSAGE_LOGIN_HINT_KEY];
    NSString *homeAccountId = [requestJson msidStringObjectForKey:MSID_BROWSER_NATIVE_MESSAGE_ACCOUNT_ID_KEY];
    if (homeAccountId != nil && ![MSIDAccountIdentifier isAccountIdValid:homeAccountId error:error]) return nil;
    
    if (homeAccountId || _loginHint)
    {
        _accountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:_loginHint homeAccountId:homeAccountId];
    }
    
    if (![requestJson msidAssertType:NSString.class ofKey:MSID_BROWSER_NATIVE_MESSAGE_CLIENT_ID_KEY required:YES error:error]) return nil;
    _clientId = requestJson[MSID_BROWSER_NATIVE_MESSAGE_CLIENT_ID_KEY];

    NSString *authorityString = [requestJson msidStringObjectForKey:MSID_BROWSER_NATIVE_MESSAGE_AUTHORITY_KEY];
    
    if (authorityString)
    {
        NSError *localError;
        _authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:authorityString] rawTenant:nil context:nil error:&localError];
        
        if (!_authority)
        {
            if (localError)
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Non AAD authorities are not supported in broker - %@", MSID_PII_LOG_MASKABLE(localError));
            }
            
            if (error) *error = localError;
            
            return nil;
        }
    }
    
    if (![requestJson msidAssertType:NSString.class ofKey:MSID_BROWSER_NATIVE_MESSAGE_SCOPE_KEY required:YES error:error]) return nil;
    _scopes = requestJson[MSID_BROWSER_NATIVE_MESSAGE_SCOPE_KEY];
    
    if (![requestJson msidAssertType:NSString.class ofKey:MSID_BROWSER_NATIVE_MESSAGE_REDIRECT_URI_KEY required:YES error:error]) return nil;
    _redirectUri = requestJson[MSID_BROWSER_NATIVE_MESSAGE_REDIRECT_URI_KEY];
    
    NSString *promptString = [requestJson msidStringObjectForKey:MSID_BROWSER_NATIVE_MESSAGE_PROMPT_KEY];
    _prompt = MSIDPromptTypeFromString(promptString);
    
    _nonce = [requestJson msidStringObjectForKey:MSID_BROWSER_NATIVE_MESSAGE_NONCE_KEY];
    _isSts = [requestJson msidBoolObjectForKey:MSID_BROWSER_NATIVE_MESSAGE_IS_STS_KEY];
    _state = [requestJson msidStringObjectForKey:MSID_BROWSER_NATIVE_MESSAGE_STATE_KEY];
    _instanceAware = [requestJson msidBoolObjectForKey:MSID_BROWSER_NATIVE_MESSAGE_INSTANCE_AWARE_KEY];
    
    if (![requestJson msidAssertType:NSDictionary.class ofKey:MSID_BROWSER_NATIVE_MESSAGE_EXTRA_PARAMETERS_KEY required:NO error:error]) return nil;
    _extraParameters = requestJson[MSID_BROWSER_NATIVE_MESSAGE_EXTRA_PARAMETERS_KEY];

    if (![requestJson msidAssertType:NSString.class ofKey:MSID_BROWSER_NATIVE_MESSAGE_CORRELATION_KEY required:NO error:error]) return nil;
    NSString *uuidString = requestJson[MSID_BROWSER_NATIVE_MESSAGE_CORRELATION_KEY];
    _correlationId = uuidString ? [[NSUUID alloc] initWithUUIDString:uuidString] : [NSUUID UUID];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    @throw MSIDException(MSIDGenericException, @"Not implemented.", nil);
}

@end
