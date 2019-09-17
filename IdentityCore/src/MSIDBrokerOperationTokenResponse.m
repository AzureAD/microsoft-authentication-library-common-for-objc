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

#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDTokenResult+MSIDJsonSerializable.h"
#import "MSIDTokenResponse.h"
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDConfiguration+MSIDJsonSerializable.h"

@implementation MSIDBrokerOperationTokenResponse

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        if (![json msidAssertType:NSDictionary.class
                          ofField:@"response_data"
                          context:nil
                        errorCode:MSIDErrorInvalidInternalParameter
                            error:error])
        {
            return nil;
        }
        
        NSDictionary *responseJson = json[@"response_data"];
        MSIDTokenResponse *tokenResponse = [[MSIDTokenResponse alloc] initWithJSONDictionary:responseJson error:error];
        if (!tokenResponse) return nil;

        __auto_type configuration = [[MSIDConfiguration alloc] initWithJSONDictionary:responseJson error:error];
        if (!configuration) return nil;
        
        __auto_type responseValidator = [MSIDDefaultTokenResponseValidator new];
        __auto_type oauthFactory = [MSIDAADV2Oauth2Factory new];
        // TODO: fix.
        NSUUID *correlationID = [NSUUID new];
        
        _result = [responseValidator validateTokenResponse:tokenResponse
                                              oauthFactory:oauthFactory
                                             configuration:configuration
                                            requestAccount:nil
                                             correlationID:correlationID
                                                     error:error];
        if (!_result) return nil;
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    
    NSMutableDictionary *responseJson = [[self.result.tokenResponse jsonDictionary] mutableDeepCopy];
    
    NSDictionary *configurationJson = [self.configuration jsonDictionary];
    if (!configurationJson) return nil;
    
    [responseJson addEntriesFromDictionary:configurationJson];
    
    json[@"response_data"] = responseJson;
    
    return json;
}

@end
