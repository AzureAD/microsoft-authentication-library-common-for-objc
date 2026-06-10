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


#import "MSIDBrowserNativeMessageGetSupportedContractsResponse.h"
#import "MSIDJsonSerializableTypes.h"
#import "MSIDJsonSerializableFactory.h"

NSString *const MSID_BROWSER_NATIVE_MESSAGE_SUPPORTED_CONTRACTS_KEY = @"contracts";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_SUPPORTED_CONTRACTS_DIVIDER = @",";

@implementation MSIDBrowserNativeMessageGetSupportedContractsResponse

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.responseType];
}

+ (NSString *)responseType
{
    return MSID_JSON_TYPE_BROKER_OPERATION_BROWSER_NATIVE_GET_SUPPORTED_CONTRACTS_RESPONSE;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing*)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
    {
        if (![json msidAssertType:NSString.class ofKey:MSID_BROWSER_NATIVE_MESSAGE_SUPPORTED_CONTRACTS_KEY required:YES error:error]) return nil;
        NSString *contracts = json[MSID_BROWSER_NATIVE_MESSAGE_SUPPORTED_CONTRACTS_KEY];
        if ([NSString msidIsStringNilOrBlank:contracts])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"contracts is nil or emtpy.", nil, nil, nil, nil, nil, YES);
            }
            
            return nil;
        }
        
        _supportedContracts = [contracts componentsSeparatedByString:MSID_BROWSER_NATIVE_MESSAGE_SUPPORTED_CONTRACTS_DIVIDER];
        if (!_supportedContracts)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to perase supported contracts.", nil, nil, nil, nil, nil, YES);
            }
            
            return nil;
        }
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    if (!json) return nil;
    
    NSString *contracts = [self.supportedContracts componentsJoinedByString:MSID_BROWSER_NATIVE_MESSAGE_SUPPORTED_CONTRACTS_DIVIDER];
    
    if (!contracts)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create GetSupportedContracts json response.");
        return nil;
    }
    
    json[MSID_BROWSER_NATIVE_MESSAGE_SUPPORTED_CONTRACTS_KEY] = contracts;
    
    return json;
}
@end
