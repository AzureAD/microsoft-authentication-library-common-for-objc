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
#import "MSIDWebWPJResponse.h"
#import "MSIDWebWPJResponse+Internal.h"
#import "MSIDWebUpgradeRegResponse.h"
#import "MSIDClientInfo.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDConstants.h"
#import "NSString+MSIDExtensions.h"

@interface MSIDWebMSAuthResponseTests : XCTestCase

@property (nonatomic) MSIDFlightManagerMockProvider *flightProvider;

@end

@implementation MSIDWebMSAuthResponseTests

- (void)setUp
{
    [super setUp];
    self.flightProvider = [MSIDFlightManagerMockProvider new];
    self.flightProvider.boolForKeyContainer = @{};
    MSIDFlightManager.sharedInstance.flightProvider = self.flightProvider;
}

- (void)tearDown
{
    MSIDFlightManager.sharedInstance.flightProvider = nil;
    self.flightProvider = nil;
    [super tearDown];
}

- (void)testInit_whenWrongScheme_shouldReturnNilWithError
{
    NSError *error = nil;
    MSIDWebWPJResponse *response = [[MSIDWebWPJResponse alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://wpj"]]
                                                                           context:nil
                                                                             error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);

    XCTAssertEqualObjects(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}


- (void)testInit_whenMSAuthScheme_shouldReturnResponsewithNoError
{
    NSError *error = nil;
    MSIDWebWPJResponse *response = [[MSIDWebWPJResponse alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"msauth://wpj?app_link=applink&username=user&token_protection_required=true"]]
                                                                           context:nil
                                                                             error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    XCTAssertEqualObjects(response.upn, @"user");
    XCTAssertEqualObjects(response.appInstallLink, @"applink");
    XCTAssertTrue(response.tokenProtectionRequired);

}

- (void)testInit_whenMSAuthScheme_withUpgradeReg_shouldReturnResponsewithNoError
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://upgradeReg?username=XXX@upn.com&client_info="
                  "eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
    MSIDWebUpgradeRegResponse *upgradeResponse = [[MSIDWebUpgradeRegResponse alloc] initWithURL:url
                                                                                        context:nil
                                                                                          error:&error];
    
    XCTAssertNotNil(upgradeResponse);
    XCTAssertNil(error);
    
    XCTAssertTrue([upgradeResponse isKindOfClass:MSIDWebUpgradeRegResponse.class]);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(upgradeResponse.upn, @"XXX@upn.com");
    XCTAssertNotNil(upgradeResponse.clientInfo, @"clientInfo should be valid");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.uid, @"9f4880d8-80ba-4c40-97bc-f7a23c703084");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.utid, @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca");
    XCTAssertNil(upgradeResponse.appInstallLink);
}

- (void)testHardenedWPJInit_whenEnforcementEnabledAndStateMatches_shouldReturnResponse
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENFORCE_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSString *requestState = @"expected-state";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://wpj?state=%@&app_link=applink",
                                      requestState.msidBase64UrlEncode]];
    NSError *error = nil;

    MSIDWebWPJResponse *response = [[MSIDWebWPJResponse alloc] initWithURL:url
                                                             requestState:requestState
                                                       ignoreInvalidState:NO
                                                                  context:nil
                                                                    error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
}

- (void)testHardenedWPJInit_whenEnforcementEnabledAndStateMissing_shouldReturnInvalidState
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENFORCE_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSError *error = nil;

    MSIDWebWPJResponse *response = [[MSIDWebWPJResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://wpj?app_link=applink"]
                                                             requestState:@"expected-state"
                                                       ignoreInvalidState:NO
                                                                  context:nil
                                                                    error:&error];

    XCTAssertNil(response);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}

- (void)testHardenedWPJInit_whenEnforcementEnabledAndStateMismatches_shouldNotHonorIgnoreInvalidState
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENFORCE_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://wpj?state=%@",
                                      @"different-state".msidBase64UrlEncode]];
    NSError *error = nil;

    MSIDWebWPJResponse *response = [[MSIDWebWPJResponse alloc] initWithURL:url
                                                             requestState:@"expected-state"
                                                       ignoreInvalidState:YES
                                                                  context:nil
                                                                    error:&error];

    XCTAssertNil(response);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}

- (void)testHardenedWPJInit_whenEnforcementEnabledAndStateIsDuplicated_shouldReturnInvalidState
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENFORCE_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSString *encodedState = @"expected-state".msidBase64UrlEncode;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://wpj?state=%@&state=%@",
                                      encodedState,
                                      encodedState]];
    NSError *error = nil;

    MSIDWebWPJResponse *response = [[MSIDWebWPJResponse alloc] initWithURL:url
                                                             requestState:@"expected-state"
                                                       ignoreInvalidState:NO
                                                                  context:nil
                                                                    error:&error];

    XCTAssertNil(response);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}

- (void)testHardenedWPJInit_whenReportEnabledAndStateMissing_shouldReturnResponse
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_REPORT_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSError *error = nil;

    MSIDWebWPJResponse *response = [[MSIDWebWPJResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://wpj?app_link=applink"]
                                                             requestState:@"expected-state"
                                                       ignoreInvalidState:NO
                                                                  context:nil
                                                                    error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
}

- (void)testHardenedWPJInit_whenWrappedResponseStateMatches_shouldReturnResponse
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENFORCE_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSString *requestState = @"expected-state";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth.com.microsoft.myapp://auth/msauth/wpj?state=%@&app_link=applink",
                                      requestState.msidBase64UrlEncode]];
    NSError *error = nil;

    MSIDWebWPJResponse *response = [[MSIDWebWPJResponse alloc] initWithURL:url
                                                             requestState:requestState
                                                       ignoreInvalidState:NO
                                                                  context:nil
                                                                    error:&error];

    XCTAssertNotNil(response);
    XCTAssertEqualObjects(response.appInstallLink, @"applink");
    XCTAssertNil(error);
}

- (void)testHardenedUpgradeInit_whenEnforcementEnabledAndStateMatches_shouldReturnUpgradeResponse
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENFORCE_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSString *requestState = @"expected-state";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://upgradeReg?state=%@&username=user",
                                      requestState.msidBase64UrlEncode]];
    NSError *error = nil;

    MSIDWebUpgradeRegResponse *response = [[MSIDWebUpgradeRegResponse alloc] initWithURL:url
                                                                           requestState:requestState
                                                                     ignoreInvalidState:NO
                                                                                context:nil
                                                                                  error:&error];

    XCTAssertNotNil(response);
    XCTAssertTrue([response isKindOfClass:MSIDWebUpgradeRegResponse.class]);
    XCTAssertEqualObjects(response.upn, @"user");
    XCTAssertNil(error);
}

- (void)testHardenedUpgradeInit_whenWrappedResponseStateMatches_shouldReturnUpgradeResponse
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENFORCE_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSString *requestState = @"expected-state";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth.com.microsoft.myapp://auth/msauth/upgradeReg?state=%@&username=user",
                                      requestState.msidBase64UrlEncode]];
    NSError *error = nil;

    MSIDWebUpgradeRegResponse *response = [[MSIDWebUpgradeRegResponse alloc] initWithURL:url
                                                                           requestState:requestState
                                                                     ignoreInvalidState:NO
                                                                                context:nil
                                                                                  error:&error];

    XCTAssertNotNil(response);
    XCTAssertTrue([response isKindOfClass:MSIDWebUpgradeRegResponse.class]);
    XCTAssertEqualObjects(response.upn, @"user");
    XCTAssertNil(error);
}

- (void)testHardenedUpgradeInit_whenEnforcementEnabledAndStateMissing_shouldReturnInvalidState
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENFORCE_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSError *error = nil;

    MSIDWebUpgradeRegResponse *response = [[MSIDWebUpgradeRegResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://upgradeReg?username=user"]
                                                                           requestState:@"expected-state"
                                                                     ignoreInvalidState:NO
                                                                                context:nil
                                                                                  error:&error];

    XCTAssertNil(response);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}

- (void)testLegacyWPJInit_whenEnforcementEnabledAndStateMissing_shouldPreserveCompatibility
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENFORCE_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSError *error = nil;

    MSIDWebWPJResponse *response = [[MSIDWebWPJResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://wpj?app_link=applink"]
                                                                  context:nil
                                                                    error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
}

@end
