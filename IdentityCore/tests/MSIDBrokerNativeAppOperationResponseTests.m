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


#import <XCTest/XCTest.h>
#import "MSIDBrokerNativeAppOperationResponse.h"
#import "MSIDBrokerConstants.h"
#import "MSIDDeviceInfo.h"
#import "MSIDLastRequestTelemetry.h"
#import "NSDate+MSIDTestUtil.h"

@interface MSIDLastRequestTelemetry(Test)

- (instancetype)initInternal;

@end

@interface MSIDLastRequestTelemetryMock : MSIDLastRequestTelemetry

@property (nonatomic) NSString *telemetryType;
@property (nonatomic) NSTimeInterval totalPerfNumber;
@property (nonatomic) NSTimeInterval ipcRequestPerfNumber;
@property (nonatomic) NSTimeInterval ipcResponsePerfNumber;

@end

@implementation MSIDLastRequestTelemetryMock

- (void)trackSSOExtensionPerformanceWithType:(NSString *)type
                             totalPerfNumber:(NSTimeInterval)totalPerfNumber
                        ipcRequestPerfNumber:(NSTimeInterval)ipcRequestPerfNumber
                       ipcResponsePerfNumber:(NSTimeInterval)ipcResponsePerfNumber
{
    self.telemetryType = type;
    self.totalPerfNumber = totalPerfNumber;
    self.ipcResponsePerfNumber = ipcResponsePerfNumber;
    self.ipcRequestPerfNumber = ipcRequestPerfNumber;
}

@end

@interface MSIDBrokerNativeAppOperationResponseTests : XCTestCase

@end

@implementation MSIDBrokerNativeAppOperationResponseTests

- (void)tearDown
{
    [NSDate reset];
    [super tearDown];
}

- (void)testJsonDictionary_whenAllPropertiesSet_shouldReturnJson
{
    __auto_type response = [[MSIDBrokerNativeAppOperationResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.operation = @"login";
    response.success = true;
    response.clientAppVersion = @"1.0";
    response.responseGenerationTimeStamp = [NSDate dateWithTimeIntervalSince1970:100];
    response.requestReceivedTimeStamp = [NSDate dateWithTimeIntervalSince1970:50];
    
    NSDictionary *json = [response jsonDictionary];
#if TARGET_OS_OSX
    XCTAssertEqual(11, json.allKeys.count);
#else
    XCTAssertEqual(10, json.allKeys.count);
#endif
    XCTAssertEqualObjects(json[@"client_app_version"], @"1.0");
    XCTAssertEqualObjects(json[@"operation"], @"login");
    XCTAssertEqualObjects(json[@"operation_response_type"], @"operation_generic_response");
    XCTAssertEqualObjects(json[@"success"], @"1");
    XCTAssertEqualObjects(json[MSID_BROKER_DEVICE_MODE_KEY], @"personal");
    XCTAssertEqualObjects(json[MSID_BROKER_SSO_EXTENSION_MODE_KEY], @"full");
    XCTAssertEqualObjects(json[MSID_BROKER_WPJ_STATUS_KEY], @"notJoined");
    XCTAssertEqualObjects(json[@"response_gen_timestamp"], @"100.0000000000");
    XCTAssertEqualObjects(json[@"request_received_timestamp"], @"50.0000000000");
    XCTAssertEqualObjects(json[MSID_BROKER_PREFERRED_AUTH_CONFIGURATION_KEY], @"preferredAuthNotConfigured");
}

- (void)testInitWithJSONDictionary_whenAllProperties_shouldInitResponse
{
    NSDictionary *json = @{
        @"client_app_version": @"1.0",
        @"operation_response_type": @"operation_generic_response",
        @"success": @"1",
        @"operation": @"login",
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"response_gen_timestamp": @"100.0000000000",
        @"request_received_timestamp": @"50.0000000000"
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerNativeAppOperationResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"1.0", response.clientAppVersion);
    XCTAssertEqualObjects(@"login", response.operation);
    XCTAssertTrue(response.success);
    XCTAssertEqual(response.deviceInfo.deviceMode, MSIDDeviceModeShared);
    XCTAssertEqual(response.deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(response.deviceInfo.brokerVersion, @"1.2.3");
    XCTAssertEqualObjects(response.responseGenerationTimeStamp, [NSDate dateWithTimeIntervalSince1970:100]);
    XCTAssertEqualObjects(response.requestReceivedTimeStamp, [NSDate dateWithTimeIntervalSince1970:50]);
}

- (void)testInitWithJSONDictionary_whenDatesMissing_shouldInitResponseWithoutDates
{
    NSDictionary *json = @{
        @"client_app_version": @"1.0",
        @"operation_response_type": @"operation_generic_response",
        @"success": @"1",
        @"operation": @"login",
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3"
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerNativeAppOperationResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"1.0", response.clientAppVersion);
    XCTAssertEqualObjects(@"login", response.operation);
    XCTAssertTrue(response.success);
    XCTAssertEqual(response.deviceInfo.deviceMode, MSIDDeviceModeShared);
    XCTAssertEqual(response.deviceInfo.wpjStatus, MSIDWorkPlaceJoinStatusJoined);
    XCTAssertEqualObjects(response.deviceInfo.brokerVersion, @"1.2.3");
    XCTAssertNil(response.responseGenerationTimeStamp);
    XCTAssertNil(response.requestReceivedTimeStamp);
}

- (void)testTrackPerfTelemetry_whenDatesAreAllSet_shouldCallTrackWithRightIntervals
{
    MSIDBrokerNativeAppOperationResponse *response = [[MSIDBrokerNativeAppOperationResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.responseGenerationTimeStamp = [NSDate dateWithTimeIntervalSince1970:100];
    response.requestReceivedTimeStamp = [NSDate dateWithTimeIntervalSince1970:50];
    
    MSIDLastRequestTelemetryMock *telemetryMock = [[MSIDLastRequestTelemetryMock alloc] initInternal];
    
    NSDate *requestStartDate = [NSDate dateWithTimeIntervalSince1970:20];
    NSDate *responseReceivedDate = [NSDate dateWithTimeIntervalSince1970:150];
    [NSDate mockCurrentDate:responseReceivedDate];
    
    [response trackPerfTelemetryWithLastRequest:telemetryMock
                               requestStartDate:requestStartDate
                                  telemetryType:@"type"];
    
    XCTAssertEqualObjects(telemetryMock.telemetryType, @"type");
    XCTAssertEqualWithAccuracy(telemetryMock.totalPerfNumber, 130, 1.0);
    XCTAssertEqualWithAccuracy(telemetryMock.ipcRequestPerfNumber, 30, 1.0);
    XCTAssertEqualWithAccuracy(telemetryMock.ipcResponsePerfNumber, 50, 1.0);
}

- (void)testTrackPerfTelemetry_whenRequestReceivedDateIsNil_shouldCallTrackWithRightIntervals
{
    MSIDBrokerNativeAppOperationResponse *response = [[MSIDBrokerNativeAppOperationResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.responseGenerationTimeStamp = [NSDate dateWithTimeIntervalSince1970:100];
    
    MSIDLastRequestTelemetryMock *telemetryMock = [[MSIDLastRequestTelemetryMock alloc] initInternal];
    
    NSDate *requestStartDate = [NSDate dateWithTimeIntervalSince1970:20];
    NSDate *responseReceivedDate = [NSDate dateWithTimeIntervalSince1970:150];
    [NSDate mockCurrentDate:responseReceivedDate];
    
    [response trackPerfTelemetryWithLastRequest:telemetryMock
                               requestStartDate:requestStartDate
                                  telemetryType:@"type"];
    
    XCTAssertEqualObjects(telemetryMock.telemetryType, @"type");
    XCTAssertEqualWithAccuracy(telemetryMock.totalPerfNumber, 130, 1.0);
    XCTAssertEqualWithAccuracy(telemetryMock.ipcRequestPerfNumber, 0, 1.0);
    XCTAssertEqualWithAccuracy(telemetryMock.ipcResponsePerfNumber, 50, 1.0);
}

- (void)testTrackPerfTelemetry_whenResponseGenerationDateIsNil_shouldCallTrackWithRightIntervals
{
    MSIDBrokerNativeAppOperationResponse *response = [[MSIDBrokerNativeAppOperationResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.requestReceivedTimeStamp = [NSDate dateWithTimeIntervalSince1970:50];
    
    MSIDLastRequestTelemetryMock *telemetryMock = [[MSIDLastRequestTelemetryMock alloc] initInternal];
    
    NSDate *requestStartDate = [NSDate dateWithTimeIntervalSince1970:20];
    NSDate *responseReceivedDate = [NSDate dateWithTimeIntervalSince1970:150];
    [NSDate mockCurrentDate:responseReceivedDate];
    
    [response trackPerfTelemetryWithLastRequest:telemetryMock
                               requestStartDate:requestStartDate
                                  telemetryType:@"type"];
    
    XCTAssertEqualObjects(telemetryMock.telemetryType, @"type");
    XCTAssertEqualWithAccuracy(telemetryMock.totalPerfNumber, 130, 1.0);
    XCTAssertEqualWithAccuracy(telemetryMock.ipcRequestPerfNumber, 30, 1.0);
    XCTAssertEqualWithAccuracy(telemetryMock.ipcResponsePerfNumber, 0, 1.0);
}

@end
