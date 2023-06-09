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

@implementation MSIDBrokerOperationBrowserNativeMessageRequest

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.operation];
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
        if (![json msidAssertType:NSString.class ofKey:@"payload" required:YES error:error]) return nil;
        NSString *payload = json[@"payload"];
        if ([NSString msidIsStringNilOrBlank:payload])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"payload is nil or emtpy.", nil, nil, nil, nil, nil, YES);
            }
            
            return nil;
        }
        
        _payload = payload;
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    if (!json) return nil;
    if ([NSString msidIsStringNilOrBlank:self.payload]) return nil;
    
    json[@"payload"] = self.payload;
    
    return json;
}

@end
