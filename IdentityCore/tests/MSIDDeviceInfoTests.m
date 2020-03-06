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

#import <XCTest/XCTest.h>
#import "MSIDDeviceInfo.h"
#import "MSIDBrokerConstants.h"

@interface MSIDDeviceInfoTests : XCTestCase

@end

@implementation MSIDDeviceInfoTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testInitWithJSONDictionary_whenJsonValid_shouldInitWithJson {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModeShared);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
}

- (void)testInitWithJSONDictionary_whenDeviceInfoMissing_shouldInitWithDefaultValue {
    NSDictionary *json = @{
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModePersonal);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
}

- (void)testInitWithJSONDictionary_whenDeviceInfoCorruptedValue_shouldInitWithDefaultValue {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"P_ersonal",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModePersonal);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
}

- (void)testInitWithJSONDictionary_whenDeviceInfoWrongValueType_shouldInitWithDefaultValue {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @5,
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModePersonal);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
}

- (void)testInitWithJSONDictionary_whenDeviceInfoEmptyString_shouldInitWithDefaultValue {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModePersonal);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
}

- (void)testInitWithJSONDictionary_whenWPJStatusMissing_shouldInitWithDefaultValue {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"personal",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModePersonal);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusNotJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
}

- (void)testInitWithJSONDictionary_whenWPJStatusCorruptedValue_shouldInitWithDefaultValue {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"personal",
        MSID_BROKER_WPJ_STATUS_KEY : @"';'-",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };

    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModePersonal);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusNotJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
}

- (void)testInitWithJSONDictionary_whenWPJStatusWrongValueType_shouldInitWithDefaultValue {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @6,
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };

    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModeShared);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusNotJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
}

- (void)testInitWithJSONDictionary_whenWPJStatusEmptyString_shouldInitWithDefaultValue {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };

    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModeShared);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusNotJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
}

- (void)testJsonDictionary_whenDeserialize_shouldGenerateCorrectJson {
    MSIDDeviceInfo *deviceInfo = [MSIDDeviceInfo new];
    deviceInfo.deviceMode = MSIDDeviceModeShared;
    deviceInfo.wpjStatus = MSIDWorkPlaceJoinStatusJoined;
    deviceInfo.brokerVersion = @"1.2.3";
    
    NSDictionary *expectedJson = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_SSO_EXTENSION_MODE_KEY : @"full",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };
    
    XCTAssertEqualObjects(expectedJson, [deviceInfo jsonDictionary]);
}

@end
