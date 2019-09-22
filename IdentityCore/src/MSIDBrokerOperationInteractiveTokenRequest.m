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

@implementation MSIDBrokerOperationInteractiveTokenRequest

#pragma mark - MSIDBrokerOperationRequest

- (NSString *)operation
{
    return @"acquire_token_interactive";
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
    {
        if (![json msidAssertType:NSDictionary.class ofField:@"request_parameters" context:nil errorCode:MSIDErrorInvalidInternalParameter error:error]) return nil;
        NSDictionary *requestParameters = json[@"request_parameters"];
        
        // TODO: fix json parsing.
        _loginHint = requestParameters[MSID_OAUTH2_LOGIN_HINT];
        _promptType = MSIDPromptTypeFromString(requestParameters[MSID_OAUTH2_PROMPT]);
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    
    NSMutableDictionary *requestParametersJson = [json[@"request_parameters"] mutableCopy];
    // TODO: assert requestParametersJson
    
    requestParametersJson[MSID_OAUTH2_LOGIN_HINT] = self.loginHint;
    requestParametersJson[MSID_OAUTH2_PROMPT] = MSIDPromptParamFromType(self.promptType);
    
    json[@"request_parameters"] = requestParametersJson;
    
    return json;
}

@end
