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

#import "MSIDBrokerOperationInteractiveTokenRequest.h"
#import "MSIDPromptType_Internal.h"
#import "MSIDBrokerOperationRequestFactory.h"
#import "MSIDAccountIdentifier+MSIDJsonSerializable.h"
#import "MSIDPromptType_Internal.h"

@implementation MSIDBrokerOperationInteractiveTokenRequest

+ (void)load
{
    [MSIDBrokerOperationRequestFactory registerOperationRequestClass:self operation:self.operation];
}

#pragma mark - MSIDBrokerOperationRequest

+ (NSString *)operation
{
    return @"acquire_token_interactive";
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
    {
        NSDictionary *requestParameters = json[MSID_BROKER_REQUEST_PARAMETERS_KEY];
        assert(requestParameters);
        if (!requestParameters) return nil;
        
        _accountIdentifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:requestParameters error:error];
        _loginHint = [json msidStringObjectForKey:MSID_BROKER_LOGIN_HINT_KEY];
        
        NSString *promptString = [json msidStringObjectForKey:MSID_BROKER_PROMPT_KEY];
        _promptType = MSIDPromptTypeFromString(promptString);
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    NSMutableDictionary *requestParametersJson = [json[MSID_BROKER_REQUEST_PARAMETERS_KEY] mutableCopy];
    assert(requestParametersJson);
    if (!requestParametersJson) return nil;
    
    NSDictionary *accountIdentifierJson = [self.accountIdentifier jsonDictionary];
    if (accountIdentifierJson) [requestParametersJson addEntriesFromDictionary:accountIdentifierJson];
    
    requestParametersJson[MSID_BROKER_LOGIN_HINT_KEY] = self.loginHint;
    
    NSString *promptString = MSIDPromptParamFromType(self.promptType);
    requestParametersJson[MSID_BROKER_PROMPT_KEY] = promptString;
    
    json[MSID_BROKER_REQUEST_PARAMETERS_KEY] = requestParametersJson;
    
    return json;
}

@end
