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
#import "MSIDBrokerOperationBrowserNativeMessageMATSReport.h"

@interface MSIDBrokerOperationBrowserNativeMessageMATSReportTests : XCTestCase

@end

@implementation MSIDBrokerOperationBrowserNativeMessageMATSReportTests

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testInitWithJSONDictionary_whenJsonValidAndAllFieldsProvided_shouldInit
{
    __auto_type json = @{
        @"is_cached": @(0),
        @"broker_version": @"3.9.0",
        @"device_join": MSIDMATSDeviceJoinStatusAADJ,
        @"prompt_behavior": @"login",
        @"api_error_code": @(0),
        @"ui_visible": @(YES),
        @"silent_code": @(0),
        @"silent_message": @"",
        @"silent_status": @(MSIDMATSSilentStatusUserInteractionRequired),
        @"http_status": @(200)
    };
    
    NSError *error;
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(report);
    XCTAssertFalse(report.isCached);
    XCTAssertEqualObjects(@"3.9.0", report.brokerVersion);
    XCTAssertEqualObjects(MSIDMATSDeviceJoinStatusAADJ, report.deviceJoin);
    XCTAssertEqual(MSIDPromptTypeLogin, report.promptBehavior);
    XCTAssertEqual(0, report.apiErrorCode);
    XCTAssertTrue(report.uiVisible);
    XCTAssertEqual(0, report.silentCode);
    XCTAssertEqualObjects(@"", report.silentMessage);
    XCTAssertEqual(3, report.silentStatus);
    XCTAssertEqual(200, report.httpStatus);
}

- (void)testInitWithJSONDictionary_whenJsonValidAndMinimalFieldsProvided_shouldInit
{
    __auto_type json = @{
        @"is_cached": @(0),
        @"api_error_code": @(-50005),
        @"ui_visible": @(YES),
        @"silent_code": @(0),
        @"silent_status": @(0),
        @"http_status": @(400),
    };
    
    NSError *error;
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(report);
    XCTAssertFalse(report.isCached);
    XCTAssertNil(report.brokerVersion);
    XCTAssertNil(report.deviceJoin);
    XCTAssertEqual(MSIDPromptTypePromptIfNecessary, report.promptBehavior);
    XCTAssertEqual(-50005, report.apiErrorCode);
    XCTAssertTrue(report.uiVisible);
    XCTAssertEqual(0, report.silentCode);
    XCTAssertNil(report.silentMessage);
    XCTAssertEqual(0, report.silentStatus);
    XCTAssertEqual(400, report.httpStatus);
}

- (void)testInitWithJSONDictionary_whenJsonEmpty_shouldInitWithDefaults
{
    __auto_type json = @{};
    
    NSError *error;
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(report);
    XCTAssertFalse(report.isCached);
    XCTAssertNil(report.brokerVersion);
    XCTAssertNil(report.deviceJoin);
    XCTAssertEqual(MSIDPromptTypePromptIfNecessary, report.promptBehavior);
    XCTAssertEqual(0, report.apiErrorCode);
    XCTAssertFalse(report.uiVisible);
    XCTAssertEqual(0, report.silentCode);
    XCTAssertNil(report.silentMessage);
    XCTAssertEqual(0, report.silentStatus);
    XCTAssertEqual(0, report.httpStatus);
}

- (void)testJsonDictionary_whenAllFieldsSet_shouldReturnCompleteJson
{
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] init];
    report.isCached = YES;
    report.brokerVersion = @"3.9.0";
    report.deviceJoin = MSIDMATSDeviceJoinStatusAADJ;
    report.promptBehavior = MSIDPromptTypeLogin;
    report.apiErrorCode = 0;
    report.uiVisible = NO;
    report.silentCode = 123;
    report.silentMessage = @"User interaction required.";
    report.silentStatus = 1;
    report.httpStatus = 200;
    
    __auto_type json = [report jsonDictionary];
    
    XCTAssertNotNil(json);
    XCTAssertEqualObjects(@(YES), json[@"is_cached"]);
    XCTAssertEqualObjects(@"3.9.0", json[@"broker_version"]);
    XCTAssertEqualObjects(@"aadj", json[@"device_join"]);
    XCTAssertEqualObjects(@"login", json[@"prompt_behavior"]);
    XCTAssertEqualObjects(@(0), json[@"api_error_code"]);
    XCTAssertEqualObjects(@(NO), json[@"ui_visible"]);
    XCTAssertEqualObjects(@(123), json[@"silent_code"]);
    XCTAssertEqualObjects(@"User interaction required.", json[@"silent_message"]);
    XCTAssertEqualObjects(@(1), json[@"silent_status"]);
    XCTAssertEqualObjects(@(200), json[@"http_status"]);
}

- (void)testJsonDictionary_whenMinimalFieldsSet_shouldReturnPartialJson
{
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] init];
    report.isCached = NO;
    report.apiErrorCode = 123;
    report.uiVisible = YES;
    report.silentCode = 0;
    report.silentStatus = 0;
    report.httpStatus = 400;
    
    __auto_type json = [report jsonDictionary];
    
    XCTAssertNotNil(json);
    XCTAssertEqualObjects(@(NO), json[@"is_cached"]);
    XCTAssertNil(json[@"broker_version"]);
    XCTAssertNil(json[@"device_join"]);
    XCTAssertNil(json[@"prompt_behavior"]);
    XCTAssertEqualObjects(@(123), json[@"api_error_code"]);
    XCTAssertEqualObjects(@(YES), json[@"ui_visible"]);
    XCTAssertEqualObjects(@(0), json[@"silent_code"]);
    XCTAssertNil(json[@"silent_message"]);
    XCTAssertEqualObjects(@(0), json[@"silent_status"]);
    XCTAssertEqualObjects(@(400), json[@"http_status"]);
}

- (void)testJsonDictionary_whenDefaultValues_shouldReturnJsonWithDefaults
{
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] init];
    
    __auto_type json = [report jsonDictionary];
    
    XCTAssertNotNil(json);
    XCTAssertEqualObjects(@(NO), json[@"is_cached"]);
    XCTAssertNil(json[@"broker_version"]);
    XCTAssertNil(json[@"device_join"]);
    XCTAssertNil(json[@"prompt_behavior"]);
    XCTAssertEqualObjects(@(0), json[@"api_error_code"]);
    XCTAssertEqualObjects(@(NO), json[@"ui_visible"]);
    XCTAssertEqualObjects(@(0), json[@"silent_code"]);
    XCTAssertNil(json[@"silent_message"]);
    XCTAssertEqualObjects(@(0), json[@"silent_status"]);
    XCTAssertEqualObjects(@(0), json[@"http_status"]);
}

- (void)testErrorScenario_shouldHaveCorrectValues
{
    __auto_type json = @{
        @"is_cached": @(0),
        @"broker_version": @"3.9.0",
        @"device_join": MSIDMATSDeviceJoinStatusNotJoined,
        @"prompt_behavior": @"login",
        @"api_error_code": @(-50005),
        @"ui_visible": @(NO),
        @"silent_code": @(-50002),
        @"silent_message": @"The web page and the redirect uri must be on the same origin.",
        @"silent_status": @(MSIDMATSSilentStatusProviderError),
        @"http_status": @(400),
        @"http_event_count": @(1)
    };
    
    NSError *error;
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(report);
    XCTAssertFalse(report.isCached);
    XCTAssertEqual(-50005, report.apiErrorCode);
    XCTAssertEqual(-50002, report.silentCode);
    XCTAssertEqualObjects(@"The web page and the redirect uri must be on the same origin.", report.silentMessage);
    XCTAssertEqual(MSIDMATSSilentStatusProviderError, report.silentStatus);
    XCTAssertEqual(400, report.httpStatus);
    XCTAssertEqualObjects(MSIDMATSDeviceJoinStatusNotJoined, report.deviceJoin);
}

- (void)testDeviceJoinStatusConstants_shouldUseCorrectValues
{
    // Test AAD joined device
    __auto_type aadReport = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] init];
    aadReport.deviceJoin = MSIDMATSDeviceJoinStatusAADJ;
    
    __auto_type aadJson = [aadReport jsonDictionary];
    XCTAssertEqualObjects(@"aadj", aadJson[@"device_join"]);
    
    // Test not joined device
    __auto_type notJoinedReport = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] init];
    notJoinedReport.deviceJoin = MSIDMATSDeviceJoinStatusNotJoined;
    
    __auto_type notJoinedJson = [notJoinedReport jsonDictionary];
    XCTAssertEqualObjects(@"not_joined", notJoinedJson[@"device_join"]);
}

- (void)testSilentStatusEnum_shouldUseCorrectValues
{
    // Test all silent status enum values
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] init];
    
    // Success
    report.silentStatus = MSIDMATSSilentStatusSuccess;
    __auto_type json = [report jsonDictionary];
    XCTAssertEqualObjects(@(0), json[@"silent_status"]);
    
    // User Cancel
    report.silentStatus = MSIDMATSSilentStatusUserCancel;
    json = [report jsonDictionary];
    XCTAssertEqualObjects(@(1), json[@"silent_status"]);
    
    // User Interaction Required
    report.silentStatus = MSIDMATSSilentStatusUserInteractionRequired;
    json = [report jsonDictionary];
    XCTAssertEqualObjects(@(3), json[@"silent_status"]);
    
    // Provider Error
    report.silentStatus = MSIDMATSSilentStatusProviderError;
    json = [report jsonDictionary];
    XCTAssertEqualObjects(@(5), json[@"silent_status"]);
}


@end
