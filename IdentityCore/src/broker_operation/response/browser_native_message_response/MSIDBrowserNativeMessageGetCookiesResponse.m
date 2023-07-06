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

- (instancetype)initCookiesResponse:(MSIDBrokerOperationGetSsoCookiesResponse *)cookiesResponse
{
    self = [super init];
    if (self)
    {
        if (!cookiesResponse) return nil; // TODO: log error.
        
        _cookiesResponse = cookiesResponse;
    }
    
    return self;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing *)error
{
//    __auto_type ssoCookiesResponse = [[MSIDBrokerOperationGetSsoCookiesResponse alloc] initWithJSONDictionary:json error:error];
//
//    if (!ssoCookiesResponse) return nil;
//
//    return [self initCookiesResponse:ssoCookiesResponse];
    
    // TODO: this ^ logic is wrong
    self = [self init];
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
        
        if ([NSString msidIsStringNilOrBlank:name] || [NSString msidIsStringNilOrBlank:value]) {
            // TODO: log
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
