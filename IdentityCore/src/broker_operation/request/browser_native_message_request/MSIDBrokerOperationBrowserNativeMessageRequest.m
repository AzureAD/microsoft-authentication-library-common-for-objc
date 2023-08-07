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


#import "MSIDBrokerOperationBrowserNativeMessageRequest.h"
#import "MSIDJsonSerializableTypes.h"
#import "MSIDJsonSerializableFactory.h"
#import "NSDictionary+MSIDExtensions.h"

NSString *const BROWSER_NATIVE_MESSAGE_REQUEST_PAYLOAD_KEY = @"payload";
NSString *const BROWSER_NATIVE_MESSAGE_REQUEST_METHOD_KEY = @"method";

@implementation MSIDBrokerOperationBrowserNativeMessageRequest

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.operation];
}

- (NSString *)method
{
    return self.payloadJson[BROWSER_NATIVE_MESSAGE_REQUEST_METHOD_KEY];
}

#pragma mark - MSIDBrokerOperationRequest

+ (NSString *)operation
{
    return MSID_JSON_TYPE_OPERATION_REQUEST_BROWSER_NATIVE_MESSAGE;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
    {
        if (![json msidAssertType:NSString.class ofKey:BROWSER_NATIVE_MESSAGE_REQUEST_PAYLOAD_KEY required:YES error:error]) return nil;
        NSString *payload = json[BROWSER_NATIVE_MESSAGE_REQUEST_PAYLOAD_KEY];
        
        _payloadJson = [NSDictionary msidDictionaryFromJSONString:payload];
        if (!_payloadJson)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize payload.", nil, nil, nil, nil, nil, YES);
            }
            
            return nil;
        }
        
        if (!_payloadJson[BROWSER_NATIVE_MESSAGE_REQUEST_METHOD_KEY])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Payload is invalid: no 'method' found.", nil, nil, nil, nil, nil, YES);
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
    if (!self.payloadJson) return nil;
    
    json[BROWSER_NATIVE_MESSAGE_REQUEST_PAYLOAD_KEY] = [self.payloadJson msidJSONSerializeWithContext:nil];
    
    return json;
}

@end
