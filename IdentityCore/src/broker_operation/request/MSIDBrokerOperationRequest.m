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

#import "MSIDBrokerOperationRequest.h"

@implementation MSIDBrokerOperationRequest

+ (NSString *)operation
{
    NSAssert(NO, @"Abstract method.");
    return @"";
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        if (![json msidAssertType:NSString.class ofField:@"broker_key" context:nil errorCode:MSIDErrorInvalidInternalParameter error:error]) return nil;
        _brokerKey = json[@"broker_key"];
        
        if (![json msidAssertType:NSString.class ofField:@"client_version" context:nil errorCode:MSIDErrorInvalidInternalParameter error:error]) return nil;
        _clientVersion = json[@"client_version"];
        
        if (![json msidAssertType:NSString.class ofField:@"msg_protocol_ver" context:nil errorCode:MSIDErrorInvalidInternalParameter error:error]) return nil;
        _protocolVersion = [json[@"msg_protocol_ver"] integerValue];
        if (!_protocolVersion)
        {
            // TODO: create error or change Int to String.
            return nil;
        }
        
        if (![json msidAssertType:NSString.class
                          ofField:@"client_app_version"
                          context:nil
                        errorCode:MSIDErrorInvalidInternalParameter
                            error:error])
        {
            // TODO: log error.
        }
        _clientAppVersion = json[@"client_app_version"];
        
        if (![json msidAssertType:NSString.class
                          ofField:@"client_app_name"
                          context:nil
                        errorCode:MSIDErrorInvalidInternalParameter
                            error:error])
        {
            // TODO: log error.
        }
        _clientAppName = json[@"client_app_name"];
        
        if (![json msidAssertType:NSString.class
                          ofField:@"correlation_id"
                          context:nil
                        errorCode:MSIDErrorInvalidInternalParameter
                            error:error])
        {
            return nil;
        }
        // TODO: verify for crash when string is nil.
        _correlationId = [[NSUUID alloc] initWithUUIDString:json[@"correlation_id"]];
        if (!_correlationId)
        {
            // TODO: log error.
        }
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    json[@"operation"] = self.class.operation;
    json[@"broker_key"] = self.brokerKey;
    json[@"client_version"] = self.clientVersion;
    json[@"msg_protocol_ver"] = [@(self.protocolVersion) stringValue];
    json[@"client_app_version"] = self.clientAppVersion;
    json[@"client_app_name"] = self.clientAppName;
    json[@"correlation_id"] = self.correlationId.UUIDString;
    
    return json;
}

@end
