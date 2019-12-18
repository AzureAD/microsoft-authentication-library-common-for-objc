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

#if MSID_ENABLE_SSO_EXTENSION
#import <XCTest/XCTest.h>
#import "MSIDBrokerOperationResponse.h"
#import "MSIDDeviceInfo.h"
#import "MSIDBrokerConstants.h"

@interface MSIDBrokerOperationTestResponse : MSIDBrokerOperationResponse

@end

@implementation MSIDBrokerOperationTestResponse

+ (NSString *)responseType
{
    return @"test_response";
}

@end

@interface MSIDBrokerOperationResponseTests : XCTestCase

@end

@implementation MSIDBrokerOperationResponseTests

- (void)testHttpVersion_whenItWasNotSet_shouldReturnDefaultVersion
{
    __auto_type response = [[MSIDBrokerOperationTestResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    
    XCTAssertEqualObjects(@"HTTP/1.1", response.httpVersion);
}

- (void)testHttpStatusCode_whenItWasNotSet_shouldReturnDefaultCode
{
    __auto_type response = [[MSIDBrokerOperationTestResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    
    XCTAssertEqual(@200, response.httpStatusCode);
}

- (void)testJsonDictionary_whenAllPropertiesSet_shouldReturnJson
{
    __auto_type response = [[MSIDBrokerOperationTestResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.operation = @"login";
    response.success = true;
    response.clientAppVersion = @"1.0";
    response.deviceInfo = [[MSIDDeviceInfo alloc] initWithDeviceMode:MSIDDeviceModeShared isWorkPlaceJoined:YES brokerVersion:@"1.2.3"];
    
    NSDictionary *json = [response jsonDictionary];
    
    XCTAssertEqual(7, json.allKeys.count);
    XCTAssertEqualObjects(json[@"client_app_version"], @"1.0");
    XCTAssertEqualObjects(json[@"operation"], @"login");
    XCTAssertEqualObjects(json[@"operation_response_type"], @"test_response");
    XCTAssertEqualObjects(json[@"success"], @"1");
    XCTAssertEqualObjects(json[MSID_BROKER_DEVICE_MODE_KEY], @"shared");
    XCTAssertEqualObjects(json[MSID_BROKER_WPJ_STATUS_KEY], @"joined");
    XCTAssertEqualObjects(json[MSID_BROKER_BROKER_VERSION_KEY], @"1.2.3");
}

- (void)testJsonDictionary_whenRequiredPropertiesSet_shouldReturnJson
{
    __auto_type response = [[MSIDBrokerOperationTestResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.operation = @"login";
    response.success = true;
    
    NSDictionary *json = [response jsonDictionary];
    
    XCTAssertEqual(5, json.allKeys.count);
    XCTAssertEqualObjects(json[@"operation"], @"login");
    XCTAssertEqualObjects(json[@"operation_response_type"], @"test_response");
    XCTAssertEqualObjects(json[@"success"], @"1");
}

- (void)testInitWithJSONDictionary_whenAllProperties_shouldInitResponse
{
    NSDictionary *json = @{
        @"client_app_version": @"1.0",
        @"operation_response_type": @"test_response",
        @"success": @"1",
        @"operation": @"login",
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationTestResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"1.0", response.clientAppVersion);
    XCTAssertEqualObjects(@"login", response.operation);
    XCTAssertTrue(response.success);
    XCTAssertEqual(response.deviceInfo.deviceMode, MSIDDeviceModeShared);
    XCTAssertEqual(response.deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(response.deviceInfo.brokerVersion, @"1.2.3");
}

- (void)testInitWithJSONDictionary_whenRequiredProperties_shouldInitResponse
{
    NSDictionary *json = @{
        @"success": @"1",
        @"operation": @"login",
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationTestResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertNil(response.clientAppVersion);
    XCTAssertEqualObjects(@"login", response.operation);
    XCTAssertTrue(response.success);
}

- (void)testInitWithJSONDictionary_whenNoSuccessKey_shouldReturnError
{
    NSDictionary *json = @{
        @"operation": @"login",
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationTestResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"success key is missing in dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitWithJSONDictionary_whenNoOperationKey_shouldReturnError
{
    NSDictionary *json = @{
        @"success": @"1",
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationTestResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"operation key is missing in dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
}

@end
#endif
