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


#import <Foundation/Foundation.h>
#import "MSIDBrokerOperationExtensionDataResponse.h"
#import "MSIDJsonSerializableTypes.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDBrokerNativeAppOperationResponse.h"

@implementation MSIDBrokerOperationExtensionDataResponse

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.responseType];
}

+ (NSString *)responseType
{
    return MSID_JSON_TYPE_OPERATION_REQUEST_EXTENSION_DATA;
}

- (instancetype)initWithExtensionData:(NSDictionary *)extensionData error:(NSError **)error
{
    self = [super initWithJSONDictionary:@{MSID_BROKER_OPERATION_JSON_KEY : MSID_JSON_TYPE_OPERATION_REQUEST_EXTENSION_DATA,
                                           MSID_BROKER_OPERATION_RESULT_JSON_KEY : @1}
                                   error:error];
    if (!self)
    {
        return nil;
    }
    if (!extensionData)
    {
        if(error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"No extension data obtained from extension.", nil, nil, nil, nil, nil, YES);
        }
        return nil;
    }
    
    if (![NSJSONSerialization isValidJSONObject:extensionData])
    {
        if(error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Obtained extension data but it is not a valid json object.", nil, nil, nil, nil, nil, YES);
        }
        return nil;
    }
    
    self.extensionData = extensionData;
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    if (!json) return nil;
    json[MSID_JSON_TYPE_OPERATION_REQUEST_EXTENSION_DATA] = [self.extensionData msidJSONSerializeWithContext:nil];
    return json;
}

- (MSIDDeviceInfo *)deviceInfo
{
    return nil;
}

@end
