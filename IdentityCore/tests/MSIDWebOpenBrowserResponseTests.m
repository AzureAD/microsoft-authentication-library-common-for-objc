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
#import "MSIDWebOpenBrowserResponse.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDConstants.h"

@interface MSIDWebBrowserResponseTests : XCTestCase

@property (nonatomic) MSIDFlightManagerMockProvider *flightProvider;

@end

@implementation MSIDWebBrowserResponseTests
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
- (void)testInit_whenNoBrowserScheme_shouldReturnNilWithError
{
    NSError *error = nil;
    MSIDWebOpenBrowserResponse *response = [[MSIDWebOpenBrowserResponse alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://somehost"]]
                                                                                   context:nil
                                                                                     error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    
    XCTAssertEqualObjects(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}
- (void)testInit_whenBrowserInput_shouldReturnResponsewithNoError
{
    NSError *error = nil;
    MSIDWebOpenBrowserResponse *response = [[MSIDWebOpenBrowserResponse alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"browser://somehost"]]
                                                                                                         context:nil
                                                                                                           error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.browserURL.absoluteString, @"https://somehost");
}

- (void)testHardenedInit_whenReportFlightEnabled_shouldPreserveLegacyDestination
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_REPORT_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSURL *url = [NSURL URLWithString:@"browser://somehost/path?state=c3RhdGU&destination_parameter=value"];
    NSError *error = nil;

    MSIDWebOpenBrowserResponse *response = [[MSIDWebOpenBrowserResponse alloc] initWithURL:url
                                                                              requestState:@"state"
                                                                        ignoreInvalidState:NO
                                                                                   context:nil
                                                                                     error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.browserURL.absoluteString,
                          @"https://somehost/path?state=c3RhdGU&destination_parameter=value");
}

- (void)testHardenedInit_whenEnforcementEnabledAndStateMatches_shouldReturnResponse
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENFORCE_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSError *error = nil;

    MSIDWebOpenBrowserResponse *response = [[MSIDWebOpenBrowserResponse alloc] initWithURL:[NSURL URLWithString:@"browser://somehost/path?state=ZXhwZWN0ZWQtc3RhdGU"]
                                                                              requestState:@"expected-state"
                                                                        ignoreInvalidState:NO
                                                                                   context:nil
                                                                                     error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
}

- (void)testHardenedInit_whenEnforcementEnabledAndStateMismatches_shouldReturnInvalidState
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENFORCE_SPECIAL_WEB_RESPONSE_STATE: @YES};
    NSError *error = nil;

    MSIDWebOpenBrowserResponse *response = [[MSIDWebOpenBrowserResponse alloc] initWithURL:[NSURL URLWithString:@"browser://evil.tld/phish?state=ZGlmZmVyZW50LXN0YXRl"]
                                                                              requestState:@"expected-state"
                                                                        ignoreInvalidState:NO
                                                                                   context:nil
                                                                                     error:&error];

    XCTAssertNil(response);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}

@end
