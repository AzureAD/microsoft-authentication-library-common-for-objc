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

#import "MSIDDeviceInfo.h"
#import "MSIDConstants.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDRegistrationInformation.h"

static NSArray *deviceModeEnumString;

@implementation MSIDDeviceInfo

- (instancetype)initWithDeviceMode:(MSIDDeviceMode)deviceMode
                 isWorkPlaceJoined:(BOOL)isWorkPlaceJoined
                     brokerVersion:(NSString *)brokerVersion
{
    self = [super init];
    
    if (self)
    {
        _deviceMode = deviceMode;
        _wpjStatus = isWorkPlaceJoined ? MSIDWorkPlaceJoinStatusJoined : MSIDWorkPlaceJoinStatusNotJoined;
        _brokerVersion = brokerVersion;
    }
    
    return self;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(__unused NSError **)error
{
    self = [super init];
    
    if (self)
    {
        _deviceMode = [self deviceModeEnumFromString:[json msidStringObjectForKey:MSID_BROKER_DEVICE_MODE_KEY]];
        _wpjStatus = [self wpjStatusEnumFromString:[json msidStringObjectForKey:MSID_BROKER_WPJ_STATUS_KEY]];
        _brokerVersion = [json msidStringObjectForKey:MSID_BROKER_BROKER_VERSION_KEY];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    
    json[MSID_BROKER_DEVICE_MODE_KEY] = [self deviceModeStringFromEnum:self.deviceMode];
    json[MSID_BROKER_WPJ_STATUS_KEY] = [self wpjStatusStringFromEnum:self.wpjStatus];
    json[MSID_BROKER_BROKER_VERSION_KEY] = self.brokerVersion;
    
    return json;
}

- (NSString *)deviceModeStringFromEnum:(MSIDDeviceMode)deviceMode
{
    switch (deviceMode) {
        case MSIDDeviceModePersonal:
            return @"personal";
        case MSIDDeviceModeShared:
            return @"shared";
        default:
            return nil;
    }
}

- (MSIDDeviceMode)deviceModeEnumFromString:(NSString *)deviceModeString
{
    if ([deviceModeString isEqualToString:@"personal"])    return MSIDDeviceModePersonal;
    if ([deviceModeString isEqualToString:@"shared"])  return MSIDDeviceModeShared;

    return MSIDDeviceModePersonal;
}

- (NSString *)wpjStatusStringFromEnum:(MSIDWorkPlaceJoinStatus)wpjStatus
{
    switch (wpjStatus) {
        case MSIDWorkPlaceJoinStatusNotJoined:
            return @"NotJoined";
        case MSIDWorkPlaceJoinStatusJoined:
            return @"joined";
        default:
            return nil;
    }
}

- (MSIDWorkPlaceJoinStatus)wpjStatusEnumFromString:(NSString *)wpjStatusString
{
    if ([wpjStatusString isEqualToString:@"NotJoined"]) return MSIDWorkPlaceJoinStatusNotJoined;
    if ([wpjStatusString isEqualToString:@"joined"])    return MSIDWorkPlaceJoinStatusJoined;

    return MSIDWorkPlaceJoinStatusNotJoined;
}

@end
