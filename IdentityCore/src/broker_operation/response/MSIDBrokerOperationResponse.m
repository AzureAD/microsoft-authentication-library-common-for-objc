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
#import "MSIDDeviceInfo.h"
#import "NSBundle+MSIDExtensions.h"
#import "MSIDJsonSerializableTypes.h"
#import "MSIDJsonSerializableFactory.h"

NSString *const MSID_BROKER_OPERATION_JSON_KEY = @"operation";
NSString *const MSID_BROKER_OPERATION_RESULT_JSON_KEY = @"success";
NSString *const MSID_BROKER_OPERATION_RESPONSE_TYPE_JSON_KEY = @"operation_response_type";
NSString *const MSID_BROKER_APP_VERSION_JSON_KEY = @"client_app_version";

@implementation MSIDBrokerOperationResponse

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.responseType];
}

- (instancetype)initWithDeviceInfo:(MSIDDeviceInfo *)deviceInfo
{
    self = [super init];
    
    if (self)
    {
        _deviceInfo = deviceInfo;
    }
    
    return self;
}

+ (NSString *)responseType
{
    return MSID_JSON_TYPE_BROKER_OPERATION_GENERIC_RESPONSE;
}

- (NSNumber *)httpStatusCode
{
    if (_httpStatusCode == nil) _httpStatusCode = @200;
    
    return _httpStatusCode;
}

- (NSString *)httpVersion
{
    if (!_httpVersion) _httpVersion = @"HTTP/1.1";
    
    return _httpVersion;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        if (![json msidAssertType:NSString.class ofKey:MSID_BROKER_OPERATION_JSON_KEY required:YES error:error]) return nil;
        _operation = json[MSID_BROKER_OPERATION_JSON_KEY];
        
        if (![json msidAssertTypeIsOneOf:@[NSString.class, NSNumber.class] ofKey:MSID_BROKER_OPERATION_RESULT_JSON_KEY required:YES error:error]) return nil;
        _success = [json[MSID_BROKER_OPERATION_RESULT_JSON_KEY] boolValue];
        _clientAppVersion = [json msidStringObjectForKey:MSID_BROKER_APP_VERSION_JSON_KEY];
        _deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:error];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    if (!self.operation)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, nil, @"Failed to create json for %@ class, operation is nil.", self.class);
        return nil;
    }
    
    json[MSID_BROKER_OPERATION_JSON_KEY] = self.operation;
    json[MSID_BROKER_OPERATION_RESULT_JSON_KEY] = [@(self.success) stringValue];
    json[MSID_BROKER_OPERATION_RESPONSE_TYPE_JSON_KEY] = self.class.responseType;
    json[MSID_BROKER_APP_VERSION_JSON_KEY] = self.clientAppVersion;
    
    NSDictionary *deviceInfoJson = [self.deviceInfo jsonDictionary];
    if (deviceInfoJson) [json addEntriesFromDictionary:deviceInfoJson];
    
    return json;
}

@end
