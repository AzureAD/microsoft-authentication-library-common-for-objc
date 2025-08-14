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
        @"broker_version": @"1.4.0",
        @"account_join_on_start": @"supplied",
        @"account_join_on_end": @"Connected",
        @"device_join": @"AzureADJoined",
        @"prompt_behavior": @"login",
        @"api_error_code": @(0),
        @"ui_visible": @(YES),
        @"silent_code": @(0),
        @"silent_bi_sub_code": @(0),
        @"silent_message": @"",
        @"silent_status": @(3),
        @"http_status": @(200),
        @"http_event_count": @(1)
    };
    
    NSError *error;
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(report);
    XCTAssertFalse(report.isCached);
    XCTAssertEqualObjects(@"1.4.0", report.brokerVersion);
    XCTAssertEqualObjects(@"supplied", report.accountJoinOnStart);
    XCTAssertEqualObjects(@"Connected", report.accountJoinOnEnd);
    XCTAssertEqualObjects(@"AzureADJoined", report.deviceJoin);
    XCTAssertEqualObjects(@"login", report.promptBehavior);
    XCTAssertEqual(0, report.apiErrorCode);
    XCTAssertTrue(report.uiVisible);
    XCTAssertEqual(0, report.silentCode);
    XCTAssertEqual(0, report.silentBiSubCode);
    XCTAssertEqualObjects(@"", report.silentMessage);
    XCTAssertEqual(3, report.silentStatus);
    XCTAssertEqual(200, report.httpStatus);
    XCTAssertEqual(1, report.httpEventCount);
}

- (void)testInitWithJSONDictionary_whenJsonValidAndMinimalFieldsProvided_shouldInit
{
    __auto_type json = @{
        @"is_cached": @(0),
        @"api_error_code": @(3400017),
        @"ui_visible": @(YES),
        @"silent_code": @(0),
        @"silent_bi_sub_code": @(0),
        @"silent_status": @(0),
        @"http_status": @(400),
        @"http_event_count": @(2)
    };
    
    NSError *error;
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(report);
    XCTAssertFalse(report.isCached);
    XCTAssertNil(report.brokerVersion);
    XCTAssertNil(report.accountJoinOnStart);
    XCTAssertNil(report.accountJoinOnEnd);
    XCTAssertNil(report.deviceJoin);
    XCTAssertNil(report.promptBehavior);
    XCTAssertEqual(3400017, report.apiErrorCode);
    XCTAssertTrue(report.uiVisible);
    XCTAssertEqual(0, report.silentCode);
    XCTAssertEqual(0, report.silentBiSubCode);
    XCTAssertNil(report.silentMessage);
    XCTAssertEqual(0, report.silentStatus);
    XCTAssertEqual(400, report.httpStatus);
    XCTAssertEqual(2, report.httpEventCount);
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
    XCTAssertNil(report.accountJoinOnStart);
    XCTAssertNil(report.accountJoinOnEnd);
    XCTAssertNil(report.deviceJoin);
    XCTAssertNil(report.promptBehavior);
    XCTAssertEqual(0, report.apiErrorCode);
    XCTAssertFalse(report.uiVisible);
    XCTAssertEqual(0, report.silentCode);
    XCTAssertEqual(0, report.silentBiSubCode);
    XCTAssertNil(report.silentMessage);
    XCTAssertEqual(0, report.silentStatus);
    XCTAssertEqual(0, report.httpStatus);
    XCTAssertEqual(0, report.httpEventCount);
}

- (void)testJsonDictionary_whenAllFieldsSet_shouldReturnCompleteJson
{
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] init];
    report.isCached = YES;
    report.brokerVersion = @"3.2.7";
    report.accountJoinOnStart = @"None";
    report.accountJoinOnEnd = @"Azure AD Registered";
    report.deviceJoin = @"Azure AD Registered";
    report.promptBehavior = @"auto";
    report.apiErrorCode = 0;
    report.uiVisible = NO;
    report.silentCode = 65001;
    report.silentBiSubCode = 1001;
    report.silentMessage = @"User interaction required for consent";
    report.silentStatus = 1;
    report.httpStatus = 200;
    report.httpEventCount = 1;
    
    __auto_type json = [report jsonDictionary];
    
    XCTAssertNotNil(json);
    XCTAssertEqualObjects(@(YES), json[@"is_cached"]);
    XCTAssertEqualObjects(@"3.2.7", json[@"broker_version"]);
    XCTAssertEqualObjects(@"None", json[@"account_join_on_start"]);
    XCTAssertEqualObjects(@"Azure AD Registered", json[@"account_join_on_end"]);
    XCTAssertEqualObjects(@"Azure AD Registered", json[@"device_join"]);
    XCTAssertEqualObjects(@"auto", json[@"prompt_behavior"]);
    XCTAssertEqualObjects(@(0), json[@"api_error_code"]);
    XCTAssertEqualObjects(@(NO), json[@"ui_visible"]);
    XCTAssertEqualObjects(@(65001), json[@"silent_code"]);
    XCTAssertEqualObjects(@(1001), json[@"silent_bi_sub_code"]);
    XCTAssertEqualObjects(@"User interaction required for consent", json[@"silent_message"]);
    XCTAssertEqualObjects(@(1), json[@"silent_status"]);
    XCTAssertEqualObjects(@(200), json[@"http_status"]);
    XCTAssertEqualObjects(@(1), json[@"http_event_count"]);
}

- (void)testJsonDictionary_whenMinimalFieldsSet_shouldReturnPartialJson
{
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] init];
    report.isCached = NO;
    report.apiErrorCode = 3400017;
    report.uiVisible = YES;
    report.silentCode = 0;
    report.silentBiSubCode = 0;
    report.silentStatus = 0;
    report.httpStatus = 400;
    report.httpEventCount = 2;
    
    __auto_type json = [report jsonDictionary];
    
    XCTAssertNotNil(json);
    XCTAssertEqualObjects(@(NO), json[@"is_cached"]);
    XCTAssertNil(json[@"broker_version"]);
    XCTAssertNil(json[@"account_join_on_start"]);
    XCTAssertNil(json[@"account_join_on_end"]);
    XCTAssertNil(json[@"device_join"]);
    XCTAssertNil(json[@"prompt_behavior"]);
    XCTAssertEqualObjects(@(3400017), json[@"api_error_code"]);
    XCTAssertEqualObjects(@(YES), json[@"ui_visible"]);
    XCTAssertEqualObjects(@(0), json[@"silent_code"]);
    XCTAssertEqualObjects(@(0), json[@"silent_bi_sub_code"]);
    XCTAssertNil(json[@"silent_message"]);
    XCTAssertEqualObjects(@(0), json[@"silent_status"]);
    XCTAssertEqualObjects(@(400), json[@"http_status"]);
    XCTAssertEqualObjects(@(2), json[@"http_event_count"]);
}

- (void)testJsonDictionary_whenDefaultValues_shouldReturnJsonWithDefaults
{
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] init];
    
    __auto_type json = [report jsonDictionary];
    
    XCTAssertNotNil(json);
    XCTAssertEqualObjects(@(NO), json[@"is_cached"]);
    XCTAssertNil(json[@"broker_version"]);
    XCTAssertNil(json[@"account_join_on_start"]);
    XCTAssertNil(json[@"account_join_on_end"]);
    XCTAssertNil(json[@"device_join"]);
    XCTAssertNil(json[@"prompt_behavior"]);
    XCTAssertEqualObjects(@(0), json[@"api_error_code"]);
    XCTAssertEqualObjects(@(NO), json[@"ui_visible"]);
    XCTAssertEqualObjects(@(0), json[@"silent_code"]);
    XCTAssertEqualObjects(@(0), json[@"silent_bi_sub_code"]);
    XCTAssertNil(json[@"silent_message"]);
    XCTAssertEqualObjects(@(0), json[@"silent_status"]);
    XCTAssertEqualObjects(@(0), json[@"http_status"]);
    XCTAssertEqualObjects(@(0), json[@"http_event_count"]);
}

- (void)testRoundTrip_whenAllFieldsSet_shouldPreserveValues
{
    __auto_type originalReport = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] init];
    originalReport.isCached = YES;
    originalReport.brokerVersion = @"3.2.7";
    originalReport.accountJoinOnStart = @"None";
    originalReport.accountJoinOnEnd = @"Azure AD Registered";
    originalReport.deviceJoin = @"Azure AD Registered";
    originalReport.promptBehavior = @"auto";
    originalReport.apiErrorCode = 0;
    originalReport.uiVisible = NO;
    originalReport.silentCode = 65001;
    originalReport.silentBiSubCode = 1001;
    originalReport.silentMessage = @"User interaction required for consent";
    originalReport.silentStatus = 1;
    originalReport.httpStatus = 200;
    originalReport.httpEventCount = 1;
    
    __auto_type json = [originalReport jsonDictionary];
    
    NSError *error;
    __auto_type recreatedReport = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(recreatedReport);
    XCTAssertEqual(originalReport.isCached, recreatedReport.isCached);
    XCTAssertEqualObjects(originalReport.brokerVersion, recreatedReport.brokerVersion);
    XCTAssertEqualObjects(originalReport.accountJoinOnStart, recreatedReport.accountJoinOnStart);
    XCTAssertEqualObjects(originalReport.accountJoinOnEnd, recreatedReport.accountJoinOnEnd);
    XCTAssertEqualObjects(originalReport.deviceJoin, recreatedReport.deviceJoin);
    XCTAssertEqualObjects(originalReport.promptBehavior, recreatedReport.promptBehavior);
    XCTAssertEqual(originalReport.apiErrorCode, recreatedReport.apiErrorCode);
    XCTAssertEqual(originalReport.uiVisible, recreatedReport.uiVisible);
    XCTAssertEqual(originalReport.silentCode, recreatedReport.silentCode);
    XCTAssertEqual(originalReport.silentBiSubCode, recreatedReport.silentBiSubCode);
    XCTAssertEqualObjects(originalReport.silentMessage, recreatedReport.silentMessage);
    XCTAssertEqual(originalReport.silentStatus, recreatedReport.silentStatus);
    XCTAssertEqual(originalReport.httpStatus, recreatedReport.httpStatus);
    XCTAssertEqual(originalReport.httpEventCount, recreatedReport.httpEventCount);
}

- (void)testCacheHitScenario_shouldHaveCorrectValues
{
    __auto_type json = @{
        @"is_cached": @(1),
        @"broker_version": @"3.2.7",
        @"device_join": @"Azure AD Registered",
        @"prompt_behavior": @"auto",
        @"api_error_code": @(0),
        @"ui_visible": @(NO),
        @"silent_code": @(0),
        @"silent_bi_sub_code": @(0),
        @"silent_status": @(0),
        @"http_status": @(0),
        @"http_event_count": @(0)
    };
    
    NSError *error;
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(report);
    XCTAssertTrue(report.isCached);
    XCTAssertFalse(report.uiVisible);
    XCTAssertEqual(0, report.silentCode);
    XCTAssertEqual(0, report.httpStatus);
    XCTAssertEqual(0, report.httpEventCount);
}

- (void)testInteractiveFlowScenario_shouldHaveCorrectValues
{
    __auto_type json = @{
        @"is_cached": @(0),
        @"broker_version": @"3.2.7",
        @"account_join_on_start": @"None",
        @"account_join_on_end": @"Azure AD Registered",
        @"device_join": @"Azure AD Registered",
        @"prompt_behavior": @"force_login",
        @"api_error_code": @(0),
        @"ui_visible": @(YES),
        @"silent_code": @(65001),
        @"silent_bi_sub_code": @(1001),
        @"silent_message": @"User interaction required for consent",
        @"silent_status": @(1),
        @"http_status": @(200),
        @"http_event_count": @(2)
    };
    
    NSError *error;
    __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(report);
    XCTAssertFalse(report.isCached);
    XCTAssertTrue(report.uiVisible);
    XCTAssertEqual(65001, report.silentCode);
    XCTAssertEqual(1, report.silentStatus);
    XCTAssertEqual(200, report.httpStatus);
    XCTAssertEqual(2, report.httpEventCount);
    XCTAssertEqualObjects(@"User interaction required for consent", report.silentMessage);
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
        @"silent_bi_sub_code": @(0),
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

- (void)testPromptBehaviorValues_shouldAcceptStandardValues
{
    NSArray *validPromptBehaviors = @[@"none", @"login", @"consent", @"select_account"];
    
    for (NSString *promptBehavior in validPromptBehaviors) {
        __auto_type json = @{
            @"prompt_behavior": promptBehavior,
            @"is_cached": @(NO),
            @"api_error_code": @(0),
            @"ui_visible": @(NO),
            @"silent_code": @(0),
            @"silent_bi_sub_code": @(0),
            @"silent_status": @(MSIDMATSSilentStatusSuccess),
            @"http_status": @(200),
            @"http_event_count": @(1)
        };
        
        NSError *error;
        __auto_type report = [[MSIDBrokerOperationBrowserNativeMessageMATSReport alloc] initWithJSONDictionary:json error:&error];
        
        XCTAssertNil(error);
        XCTAssertNotNil(report);
        XCTAssertEqualObjects(promptBehavior, report.promptBehavior);
    }
}
@end
