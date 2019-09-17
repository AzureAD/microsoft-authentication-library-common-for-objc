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

#import "MSIDBrokerOperationResponse.h"

@implementation MSIDBrokerOperationResponse

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        if (![json msidAssertType:NSString.class
                          ofField:@"operation"
                          context:nil
                        errorCode:MSIDErrorInvalidInternalParameter
                            error:error])
        {
            return nil;
        }
        _operation = json[@"operation"];
        
        if (![json msidAssertType:NSString.class
                          ofField:@"application_token"
                          context:nil
                        errorCode:MSIDErrorInvalidInternalParameter
                            error:error])
        {
            return nil;
        }
        _applicationToken = json[@"application_token"];
        
        if (![json msidAssertType:NSNumber.class
                          ofField:@"success"
                          context:nil
                        errorCode:MSIDErrorInvalidInternalParameter
                            error:error])
        {
            return nil;
        }
        _success = [json[@"success"] boolValue];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    json[@"operation"] = self.operation;
    json[@"application_token"] = self.applicationToken;
    json[@"success"] = @(self.success);
    
    return json;
}

@end
