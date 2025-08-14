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

#import "MSIDBrokerOperationBrowserNativeMessageMATSReport.h"
#import "NSDictionary+MSIDExtensions.h"

NSString *const MSID_MATS_IS_CACHED_KEY = @"is_cached";
NSString *const MSID_MATS_BROKER_VERSION_KEY = @"broker_version";
NSString *const MSID_MATS_DEVICE_JOIN_KEY = @"device_join";
NSString *const MSID_MATS_PROMPT_BEHAVIOR_KEY = @"prompt_behavior";
NSString *const MSID_MATS_API_ERROR_CODE_KEY = @"api_error_code";
NSString *const MSID_MATS_UI_VISIBLE_KEY = @"ui_visible";
NSString *const MSID_MATS_SILENT_CODE_KEY = @"silent_code";
NSString *const MSID_MATS_SILENT_MESSAGE_KEY = @"silent_message";
NSString *const MSID_MATS_SILENT_STATUS_KEY = @"silent_status";
NSString *const MSID_MATS_HTTP_STATUS_KEY = @"http_status";
NSString *const MSID_MATS_HTTP_EVENT_COUNT_KEY = @"http_event_count";

// Device Join Status Constants
MSIDMATSDeviceJoinStatus const MSIDMATSDeviceJoinStatusAADJ = @"aadj";
MSIDMATSDeviceJoinStatus const MSIDMATSDeviceJoinStatusNotJoined = @"not_joined";

@implementation MSIDBrokerOperationBrowserNativeMessageMATSReport

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        // Initialize with default values.
        _isCached = NO;
        _apiErrorCode = 0;
        _uiVisible = NO;
        _silentCode = 0;
        _silentStatus = MSIDMATSSilentStatusSuccess;
        _httpStatus = 0;
        _httpEventCount = 0;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"MSIDBrokerOperationBrowserNativeMessageMATSReport: isCached: %@, brokerVersion: %@, deviceJoin: %@, promptBehavior: %@, apiErrorCode: %ld, uiVisible: %@, silentCode: %ld, silentMessage: %@, silentStatus: %ld, httpStatus: %ld, httpEventCount: %ld",
            @(self.isCached),
            self.brokerVersion,
            self.deviceJoin,
            self.promptBehavior,
            (long)self.apiErrorCode,
            @(self.uiVisible),
            (long)self.silentCode,
            self.silentMessage,
            (long)self.silentStatus,
            (long)self.httpStatus,
            (long)self.httpEventCount];
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing *)error
{
    self = [super init];
    if (!self) return nil;
    
    _isCached = [json msidBoolObjectForKey:MSID_MATS_IS_CACHED_KEY];
    _brokerVersion = [json msidStringObjectForKey:MSID_MATS_BROKER_VERSION_KEY];
    _deviceJoin = [json msidStringObjectForKey:MSID_MATS_DEVICE_JOIN_KEY];
    _promptBehavior = [json msidStringObjectForKey:MSID_MATS_PROMPT_BEHAVIOR_KEY];
    _apiErrorCode = [json msidIntegerObjectForKey:MSID_MATS_API_ERROR_CODE_KEY];
    _uiVisible = [json msidBoolObjectForKey:MSID_MATS_UI_VISIBLE_KEY];
    _silentCode = [json msidIntegerObjectForKey:MSID_MATS_SILENT_CODE_KEY];
    _silentMessage = [json msidStringObjectForKey:MSID_MATS_SILENT_MESSAGE_KEY];
    _silentStatus = [json msidIntegerObjectForKey:MSID_MATS_SILENT_STATUS_KEY];
    _httpStatus = [json msidIntegerObjectForKey:MSID_MATS_HTTP_STATUS_KEY];
    _httpEventCount = [json msidIntegerObjectForKey:MSID_MATS_HTTP_EVENT_COUNT_KEY];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    
    json[MSID_MATS_IS_CACHED_KEY] = @(self.isCached);
    if (self.brokerVersion) json[MSID_MATS_BROKER_VERSION_KEY] = self.brokerVersion;
    if (self.deviceJoin) json[MSID_MATS_DEVICE_JOIN_KEY] = self.deviceJoin;
    if (self.promptBehavior) json[MSID_MATS_PROMPT_BEHAVIOR_KEY] = self.promptBehavior;
    json[MSID_MATS_API_ERROR_CODE_KEY] = @(self.apiErrorCode);
    json[MSID_MATS_UI_VISIBLE_KEY] = @(self.uiVisible);
    json[MSID_MATS_SILENT_CODE_KEY] = @(self.silentCode);
    json[MSID_MATS_SILENT_STATUS_KEY] = @(self.silentStatus);
    json[MSID_MATS_HTTP_STATUS_KEY] = @(self.httpStatus);
    json[MSID_MATS_HTTP_EVENT_COUNT_KEY] = @(self.httpEventCount);
    
    return json;
}

- (NSString *)jsonString
{
    NSDictionary *matsDict = [self jsonDictionary];
    if (matsDict)
    {
        NSString *matsString = [matsDict msidJSONSerializeWithContext:nil];
        if (!matsString)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to serialize MATS report to JSON string.");
        }
        
        return matsString;
    }
    
    return nil;
}

@end
