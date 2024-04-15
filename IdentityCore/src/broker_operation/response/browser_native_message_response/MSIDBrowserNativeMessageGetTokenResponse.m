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


#import "MSIDBrowserNativeMessageGetTokenResponse.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDTokenResponse.h"
#import "MSIDOAuth2Constants.h"

@interface MSIDBrowserNativeMessageGetTokenResponse()

@property (nonatomic) MSIDBrokerOperationTokenResponse *operationTokenResponse;

@end

@implementation MSIDBrowserNativeMessageGetTokenResponse

- (instancetype)initWithTokenResponse:(MSIDBrokerOperationTokenResponse *)operationTokenResponse
{
    self = [super initWithDeviceInfo:operationTokenResponse.deviceInfo];
    if (self)
    {
        if (!operationTokenResponse)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create browser 'GetToken' response: operation token response is nil.");
            return nil;
        }
        
        _operationTokenResponse = operationTokenResponse;
    }
    
    return self;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    @throw MSIDException(MSIDGenericException, @"Not implemented.", nil);
}

- (NSDictionary *)jsonDictionary
{
    __auto_type tokenResponse = self.operationTokenResponse.tokenResponse;
    NSMutableDictionary *response = [[tokenResponse jsonDictionary] mutableCopy];
    if (!response)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create token json response.");
        return nil;
    }
    
    __auto_type accountJson = [NSMutableDictionary new];
    accountJson[@"userName"] = tokenResponse.idTokenObj.username;
    accountJson[@"id"] = tokenResponse.accountIdentifier;
    
    response[@"account"] = accountJson;
    response[@"state"] = self.state;
    
    __auto_type propertiesJson = [NSMutableDictionary new];
    // TODO: once ests follow the latest protocol, this should be removed. Account ID should be read from accountJson.
    propertiesJson[@"UPN"] = tokenResponse.idTokenObj.username;
    response[@"properties"] = propertiesJson;
    
    return response;
}

@end

