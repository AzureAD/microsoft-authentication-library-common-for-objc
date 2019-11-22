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

static NSArray *deviceModeEnumString;

@implementation MSIDDeviceInfo

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
    if (deviceMode < 0 || deviceMode >= self.deviceModeEnumString.count) return nil;
    
    return [self.deviceModeEnumString objectAtIndex:deviceMode];
}

- (MSIDDeviceMode)deviceModeEnumFromString:(NSString *)deviceModeString
{
    // Default to personal mode if no device mode is available
    if ([NSString msidIsStringNilOrBlank:deviceModeString]) return MSIDDeviceModePersonal;
    
    NSUInteger index = [self.deviceModeEnumString indexOfObject:deviceModeString];
    
    if (index < 0 || index >= self.deviceModeEnumString.count)
    {
        return (MSIDDeviceMode) 0;
    }
    return (MSIDDeviceMode) index;
}

- (NSArray *)deviceModeEnumString
{
    static NSArray *s_deviceModeEnumStrings = nil;
    static dispatch_once_t deviceModeStringOnce;
    
    dispatch_once(&deviceModeStringOnce, ^{
        s_deviceModeEnumStrings = [[NSArray alloc] initWithObjects:DeviceModeStringArray];
    });
    
    return s_deviceModeEnumStrings;
}

- (NSString *)wpjStatusStringFromEnum:(MSIDWorkPlaceJoinStatus)wpjStatus
{
    if (wpjStatus < 0 || wpjStatus >= self.wpjStatusEnumString.count) return nil;
    
    return [self.wpjStatusEnumString objectAtIndex:wpjStatus];
}

- (MSIDWorkPlaceJoinStatus)wpjStatusEnumFromString:(NSString *)wpjStatusString
{
    // Default to personal mode if no device mode is available
    if ([NSString msidIsStringNilOrBlank:wpjStatusString]) return MSIDWorkPlaceJoinStatusNotJoined;
    
    NSUInteger index = [self.wpjStatusEnumString indexOfObject:wpjStatusString];
    
    if (index < 0 || index >= self.wpjStatusEnumString.count)
    {
        return (MSIDWorkPlaceJoinStatus) 0;
    }
    return (MSIDWorkPlaceJoinStatus) index;
}

- (NSArray *)wpjStatusEnumString
{
    static NSArray *s_wpjEnumStrings = nil;
    static dispatch_once_t wpjStringOnce;
    
    dispatch_once(&wpjStringOnce, ^{
        s_wpjEnumStrings = [[NSArray alloc] initWithObjects:WPJStatusStringArray];
    });
    
    return s_wpjEnumStrings;
}

@end
