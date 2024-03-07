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
        MSID_BROKER_SSO_EXTENSION_MODE_KEY : @"silent_only",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        MSID_ADDITIONAL_EXTENSION_DATA_KEY: @"{\"token\":\"\",\"dict\":{\"key\":\"value\"},\"feature_flag1\":1}",
        MSID_EXTRA_DEVICE_INFO_KEY:@"{\"mdm_id\":\"mdmId\",\"object_id\":\"objectId\",\"isCallerAppManaged\":\"1\"}"
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModeShared);
    XCTAssertEqual(deviceInfo.ssoExtensionMode, MSIDSSOExtensionModeSilentOnly);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
    XCTAssertEqual(deviceInfo.preferredAuthConfig, MSIDPreferredAuthMethodNotConfigured);
    
    NSDictionary *expectedAdditionalData = @{@"feature_flag1":@1,@"token":@"",@"dict":@{@"key":@"value"}};
    XCTAssertEqualObjects(deviceInfo.additionalExtensionData, expectedAdditionalData);
    NSDictionary *expectedExtraDeviceInfo = @{@"mdm_id":@"mdmId",@"object_id":@"objectId", @"isCallerAppManaged":@"1"};
    XCTAssertEqualObjects(deviceInfo.extraDeviceInfo, expectedExtraDeviceInfo);
}

- (void)testInitWithJSONDictionary_whenJsonValid_andAdditionalDataCorrupt_shouldInitWithJsonWithoutAdditionalInfo {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_SSO_EXTENSION_MODE_KEY : @"silent_only",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        MSID_ADDITIONAL_EXTENSION_DATA_KEY: @"{\"token\":\"\",\"dict\":{\"key\":\"value\"},\"feature_flag1\":1",
        MSID_EXTRA_DEVICE_INFO_KEY:@"{\"mdm_id\":\"mdmId\",\"object_id\":\"objectId\"}"
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModeShared);
    XCTAssertEqual(deviceInfo.ssoExtensionMode, MSIDSSOExtensionModeSilentOnly);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
    XCTAssertEqual(deviceInfo.preferredAuthConfig, MSIDPreferredAuthMethodNotConfigured);
    XCTAssertNil(deviceInfo.additionalExtensionData);
    NSDictionary *expectedExtraDeviceInfo = @{@"mdm_id":@"mdmId",@"object_id":@"objectId"};
    XCTAssertEqualObjects(deviceInfo.extraDeviceInfo, expectedExtraDeviceInfo);
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
    XCTAssertEqual(deviceInfo.ssoExtensionMode, MSIDSSOExtensionModeFull);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
    XCTAssertEqual(deviceInfo.preferredAuthConfig, MSIDPreferredAuthMethodNotConfigured);
}

- (void)testInitWithJSONDictionary_whenDeviceInfoCorruptedValue_shouldInitWithDefaultValue {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"P_ersonal",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_SSO_EXTENSION_MODE_KEY : @"silent-only",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModePersonal);
    XCTAssertEqual(deviceInfo.ssoExtensionMode, MSIDSSOExtensionModeFull);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
    XCTAssertEqual(deviceInfo.preferredAuthConfig, MSIDPreferredAuthMethodNotConfigured);
}

- (void)testInitWithJSONDictionary_whenDeviceInfoWrongValueType_shouldInitWithDefaultValue {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @5,
        MSID_BROKER_DEVICE_MODE_KEY : @2,
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModePersonal);
    XCTAssertEqual(deviceInfo.ssoExtensionMode, MSIDSSOExtensionModeFull);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
    XCTAssertEqual(deviceInfo.preferredAuthConfig, MSIDPreferredAuthMethodNotConfigured);
}

- (void)testInitWithJSONDictionary_whenDeviceInfoEmptyString_shouldInitWithDefaultValue {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"",
        MSID_BROKER_DEVICE_MODE_KEY : @"",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModePersonal);
    XCTAssertEqual(deviceInfo.ssoExtensionMode, MSIDSSOExtensionModeFull);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
    XCTAssertEqual(deviceInfo.preferredAuthConfig, MSIDPreferredAuthMethodNotConfigured);
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
    XCTAssertEqual(deviceInfo.ssoExtensionMode, MSIDSSOExtensionModeFull);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusNotJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
    XCTAssertEqual(deviceInfo.preferredAuthConfig, MSIDPreferredAuthMethodNotConfigured);
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
    XCTAssertEqual(deviceInfo.preferredAuthConfig, MSIDPreferredAuthMethodNotConfigured);
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
    XCTAssertEqual(deviceInfo.preferredAuthConfig, MSIDPreferredAuthMethodNotConfigured);
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
    XCTAssertEqual(deviceInfo.preferredAuthConfig, MSIDPreferredAuthMethodNotConfigured);
}

- (void)testJsonDictionary_whenDeserialize_shouldGenerateCorrectJson {
    MSIDDeviceInfo *deviceInfo = [MSIDDeviceInfo new];
    deviceInfo.deviceMode = MSIDDeviceModeShared;
    deviceInfo.wpjStatus = MSIDWorkPlaceJoinStatusJoined;
    deviceInfo.brokerVersion = @"1.2.3";
    
    NSDictionary *additionalData = @{@"feature_flag1":@1,@"token":@"",@"dict":@{@"key":@"value"}};
    deviceInfo.additionalExtensionData = additionalData;
#if TARGET_OS_IPHONE
    deviceInfo.extraDeviceInfo = @{MSID_BROKER_MDM_ID_KEY:@"mdmId",MSID_ENROLLED_USER_OBJECT_ID_KEY:@"objectId", MSID_IS_CALLER_MANAGED_KEY:@"1"};
#endif
#if TARGET_OS_OSX
    NSDictionary *expectedJson = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_SSO_EXTENSION_MODE_KEY : @"full",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        MSID_PLATFORM_SSO_STATUS_KEY : @"platformSSONotEnabled",
        MSID_ADDITIONAL_EXTENSION_DATA_KEY: @"{\"dict\":{\"key\":\"value\"},\"feature_flag1\":1,\"token\":\"\"}",
        MSID_BROKER_PREFERRED_AUTH_CONFIGURATION_KEY : @"preferredAuthNotConfigured"
    };
#else
    NSDictionary *expectedJson = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_SSO_EXTENSION_MODE_KEY : @"full",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        MSID_ADDITIONAL_EXTENSION_DATA_KEY: @"{\"dict\":{\"key\":\"value\"},\"feature_flag1\":1,\"token\":\"\"}",
        MSID_EXTRA_DEVICE_INFO_KEY:@"{\"isCallerAppManaged\":\"1\",\"mdm_id\":\"mdmId\",\"object_id\":\"objectId\"}",
        MSID_BROKER_PREFERRED_AUTH_CONFIGURATION_KEY : @"preferredAuthNotConfigured"
    };
#endif
    XCTAssertEqualObjects(expectedJson, [deviceInfo jsonDictionary]);
}

- (void)testJsonDictionaryFromOldSDK_whenDeserialize_shouldGenerateCorrectJson {
    MSIDDeviceInfo *deviceInfo = [MSIDDeviceInfo new];
    deviceInfo.deviceMode = MSIDDeviceModeShared;
    deviceInfo.wpjStatus = MSIDWorkPlaceJoinStatusJoined;
    deviceInfo.brokerVersion = @"1.2.3";
    
    NSDictionary *additionalData = @{@"feature_flag1":@1,@"token":@"",@"dict":@{@"key":@"value"}};
    deviceInfo.additionalExtensionData = additionalData;
#if TARGET_OS_IPHONE
    deviceInfo.extraDeviceInfo = @{MSID_BROKER_MDM_ID_KEY:@"mdmId",MSID_ENROLLED_USER_OBJECT_ID_KEY:@"objectId"};
#endif
#if TARGET_OS_OSX
    NSDictionary *expectedJson = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_SSO_EXTENSION_MODE_KEY : @"full",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        MSID_PLATFORM_SSO_STATUS_KEY : @"platformSSONotEnabled",
        MSID_ADDITIONAL_EXTENSION_DATA_KEY: @"{\"dict\":{\"key\":\"value\"},\"feature_flag1\":1,\"token\":\"\"}",
        MSID_BROKER_PREFERRED_AUTH_CONFIGURATION_KEY : @"preferredAuthNotConfigured"
    };
#else
    NSDictionary *expectedJson = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_SSO_EXTENSION_MODE_KEY : @"full",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        MSID_ADDITIONAL_EXTENSION_DATA_KEY: @"{\"dict\":{\"key\":\"value\"},\"feature_flag1\":1,\"token\":\"\"}",
        MSID_EXTRA_DEVICE_INFO_KEY:@"{\"mdm_id\":\"mdmId\",\"object_id\":\"objectId\"}",
        MSID_BROKER_PREFERRED_AUTH_CONFIGURATION_KEY : @"preferredAuthNotConfigured"
    };
#endif
    XCTAssertEqualObjects(expectedJson, [deviceInfo jsonDictionary]);
}

#if TARGET_OS_OSX && __MAC_OS_X_VERSION_MAX_ALLOWED >= 130000
- (void)testInitWithJSONDictionary_whenJsonValid_PlatformSSOEnabled_shouldInitWithJsonWithPlatformSSOStatus {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"personal",
        MSID_BROKER_SSO_EXTENSION_MODE_KEY : @"silent_only",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        MSID_PLATFORM_SSO_STATUS_KEY : @"platformSSOEnabledNotRegistered",
        MSID_ADDITIONAL_EXTENSION_DATA_KEY: @"{\"token\":\"\",\"dict\":{\"key\":\"value\"},\"feature_flag1\":1}",
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModePersonal);
    XCTAssertEqual(deviceInfo.ssoExtensionMode, MSIDSSOExtensionModeSilentOnly);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
    XCTAssertEqual(deviceInfo.platformSSOStatus, MSIDPlatformSSOEnabledNotRegistered);
    NSDictionary *expectedAdditionalData = @{@"feature_flag1":@1,@"token":@"",@"dict":@{@"key":@"value"}};
    XCTAssertEqualObjects(deviceInfo.additionalExtensionData, expectedAdditionalData);
}

- (void)testJsonDictionaryWithPlatformSSOStatus_whenDeserialize_shouldGenerateCorrectJson
{
    MSIDDeviceInfo *deviceInfo = [MSIDDeviceInfo new];
    deviceInfo.deviceMode = MSIDDeviceModePersonal;
    deviceInfo.wpjStatus = MSIDWorkPlaceJoinStatusJoined;
    deviceInfo.brokerVersion = @"1.2.3";
    deviceInfo.platformSSOStatus = MSIDPlatformSSOEnabledAndRegistered;
    
    NSDictionary *additionalData = @{@"feature_flag1":@1,@"token":@"",@"dict":@{@"key":@"value"}};
    deviceInfo.additionalExtensionData = additionalData;
    
    NSDictionary *expectedJson = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"personal",
        MSID_BROKER_SSO_EXTENSION_MODE_KEY : @"full",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        MSID_PLATFORM_SSO_STATUS_KEY :
            @"platformSSOEnabledAndRegistered",
        MSID_BROKER_PREFERRED_AUTH_CONFIGURATION_KEY : @"preferredAuthNotConfigured",
        MSID_ADDITIONAL_EXTENSION_DATA_KEY: @"{\"dict\":{\"key\":\"value\"},\"feature_flag1\":1,\"token\":\"\"}"
    };
    
    XCTAssertEqualObjects(expectedJson, [deviceInfo jsonDictionary]);
}
#endif

- (void)testInitWithJSONDictionary_whenPreferredAuthConfigIncluded_shouldInitWithJson {
    NSDictionary *json = @{
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_SSO_EXTENSION_MODE_KEY : @"silent_only",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        MSID_BROKER_PREFERRED_AUTH_CONFIGURATION_KEY : @"preferredAuthQRPIN"
    };
    
    NSError *error;
    MSIDDeviceInfo *deviceInfo = [[MSIDDeviceInfo alloc] initWithJSONDictionary:json error:&error];
    
    
    XCTAssertNil(error);
    XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModeShared);
    XCTAssertEqual(deviceInfo.ssoExtensionMode, MSIDSSOExtensionModeSilentOnly);
    XCTAssertEqual(deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(deviceInfo.brokerVersion, @"1.2.3");
    XCTAssertEqual(deviceInfo.preferredAuthConfig, MSIDPreferredAuthMethodQRPIN);
}

@end
