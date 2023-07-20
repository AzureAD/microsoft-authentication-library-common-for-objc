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


#import "MSIDBrowserNativeMessageGetCookiesResponse.h"
#import "MSIDBrokerOperationGetSsoCookiesResponse.h"
#import "MSIDCredentialHeader.h"
#import "MSIDDeviceHeader.h"
#import "MSIDPrtHeader.h"
#import "MSIDCredentialInfo.h"

@interface MSIDBrowserNativeMessageGetCookiesResponse()

@property (nonatomic) MSIDBrokerOperationGetSsoCookiesResponse *cookiesResponse;

@end

@implementation MSIDBrowserNativeMessageGetCookiesResponse

- (instancetype)initWithCookiesResponse:(MSIDBrokerOperationGetSsoCookiesResponse *)cookiesResponse
{
    self = [super initWithDeviceInfo:cookiesResponse.deviceInfo];
    if (self)
    {
        if (!cookiesResponse)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create browser 'GetCookies' response: sso cookies response is nil. ");
            return nil;
        }
        
        _cookiesResponse = cookiesResponse;
    }
    
    return self;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    @throw MSIDException(MSIDGenericException, @"Not implemented.", nil);
    
    return nil;
}

- (NSDictionary *)jsonDictionary
{
    NSArray<MSIDCredentialHeader *> *prtHeaders = self.cookiesResponse.prtHeaders;
    NSArray<MSIDCredentialHeader *> *deviceHeaders = self.cookiesResponse.deviceHeaders;
    NSArray<MSIDCredentialHeader *> *credentials = [prtHeaders arrayByAddingObjectsFromArray:deviceHeaders];
    
    NSMutableArray *credentialsJson = [NSMutableArray new];
    
    for (MSIDCredentialHeader *credential in credentials) {
        
        NSString *name = credential.info.name;
        NSString *value = credential.info.value;
        
        if ([NSString msidIsStringNilOrBlank:name])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to serialize json for credential: 'name' is nil or empty. ");
            continue;
        }
        
        if ([NSString msidIsStringNilOrBlank:value])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to serialize json for credential: 'value' is nil or empty. ");
            continue;
        }

        NSDictionary *credentialJson = @{
            @"name": name,
            @"data": value
        };
        
        [credentialsJson addObject:credentialJson];
    }
    
    return @{@"response": credentialsJson};
}

@end
