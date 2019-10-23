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

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
#import <AuthenticationServices/ASAuthorizationOpenIDRequest.h>
#import "MSIDBrokerOperationInteractiveTokenRequest.h"
#import "MSIDPromptType_Internal.h"
#import "MSIDBrokerOperationRequestFactory.h"
#import "MSIDPromptType_Internal.h"
#import "MSIDAccountIdentifier+MSIDJsonSerializable.h"

@implementation MSIDBrokerOperationInteractiveTokenRequest

+ (void)load
{
    if (@available(iOS 13.0, *))
    {
        [MSIDBrokerOperationRequestFactory registerOperationRequestClass:self operation:self.operation];
    }
}

#pragma mark - MSIDBrokerOperationRequest

+ (NSString *)operation
{
    return ASAuthorizationOperationLogin;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
    {
        NSError *localError;
        // We have flat json dictionary, that is why we are passing the whole json to the MSIDAccountIdentifier.
        _accountIdentifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:json error:&localError];
        if (localError) MSID_LOG_WITH_CORR_PII(MSIDLogLevelWarning, nil, @"Failed to parse MSIDAccountIdentifier %@", MSID_PII_LOG_MASKABLE(localError));
        
        _loginHint = [json msidStringObjectForKey:MSID_BROKER_LOGIN_HINT_KEY];
        
        NSString *promptString = [json msidStringObjectForKey:MSID_BROKER_PROMPT_KEY];
        _promptType = MSIDPromptTypeFromString(promptString);
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    if (!json) return nil;
    
    NSDictionary *accountIdentifierJson = [self.accountIdentifier jsonDictionary];
    if (accountIdentifierJson) [json addEntriesFromDictionary:accountIdentifierJson];
    
    json[MSID_BROKER_LOGIN_HINT_KEY] = self.loginHint;
    
    NSString *promptString = MSIDPromptParamFromType(self.promptType);
    if (!promptString) return nil;
    json[MSID_BROKER_PROMPT_KEY] = promptString;
    
    return json;
}

@end
#endif
