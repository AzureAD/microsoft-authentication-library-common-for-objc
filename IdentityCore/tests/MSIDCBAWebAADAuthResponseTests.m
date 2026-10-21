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
#import "MSIDCBAWebAADAuthResponse.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDConstants.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDCBAWebAADAuthResponseTests : XCTestCase

@property (nonatomic) MSIDFlightManagerMockProvider *flightProvider;

@end

@implementation MSIDCBAWebAADAuthResponseTests

- (void)setUp
{
    [super setUp];
    self.flightProvider = [[MSIDFlightManagerMockProvider alloc] init];
    MSIDFlightManager.sharedInstance.flightProvider = self.flightProvider;
}

- (void)tearDown
{
    self.flightProvider = nil;
    MSIDFlightManager.sharedInstance.flightProvider = nil;
    [super tearDown];
}

#pragma mark - Legacy Tests (Loose URL Matching)

- (void)testIsCBAWebAADAuthResponse_whenSchemeIncorrect_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"someother://code?querystring"];
    XCTAssertFalse([MSIDCBAWebAADAuthResponse isCBAWebAADAuthResponse:url]);
}

- (void)testIsCBAWebAADAuthResponse_whenHostIncorrect_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"msauth://somehost?querystring"];
    XCTAssertFalse([MSIDCBAWebAADAuthResponse isCBAWebAADAuthResponse:url]);
}

- (void)testIsCBAWebAADAuthResponse_whenSchemeAndHostAreCorrect_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"msauth://code?querystring"];
    XCTAssertTrue([MSIDCBAWebAADAuthResponse isCBAWebAADAuthResponse:url]);
}

- (void)testInitWithURL_whenAllValid_shouldReturnResponseWithRedirect
{
    NSURL *url = [NSURL URLWithString:@"msauth://code/redirect?code=somecode"];
    NSError *error;
    MSIDCBAWebAADAuthResponse *response = [[MSIDCBAWebAADAuthResponse alloc] initWithURL:url context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.authorizationCode, @"somecode");
    XCTAssertEqualObjects(response.redirectUri, @"msauth://code/redirect");
}

- (void)testInitWithURL_whenValidUrlWithPound_shouldParseRedirectUriWithoutPound
{
    NSURL *url = [NSURL URLWithString:@"msauth://code/redirect?code=somecode#"];
    NSError *error;
    MSIDCBAWebAADAuthResponse *response = [[MSIDCBAWebAADAuthResponse alloc] initWithURL:url context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.authorizationCode, @"somecode");
    XCTAssertEqualObjects(response.redirectUri, @"msauth://code/redirect");
}

#pragma mark - Strict URL Matching with Flight Flag

- (void)testInitWithURLAndState_withStrictMatchingEnabled_whenRedirectUriMatches_shouldSucceed
{
    // When flight flag is enabled, redirect URIs must match exactly
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_ENABLE_CBA_ORIGIN_FIX: @YES };
    
    NSURL *url = [NSURL URLWithString:@"msauth://code/redirect?code=somecode"];
    NSError *error;
    MSIDCBAWebAADAuthResponse *response = [[MSIDCBAWebAADAuthResponse alloc] initWithURL:url
                                                                    expectedRedirectUri:@"msauth://code/redirect"
                                                                           requestState:nil
                                                                     ignoreInvalidState:NO
                                                                                context:nil
                                                                                  error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(response);
}

- (void)testInitWithURLAndState_withStrictMatchingEnabled_whenRedirectUriMismatch_shouldFail
{
    // When flight flag is enabled, mismatched redirect URIs should be rejected
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_ENABLE_CBA_ORIGIN_FIX: @YES };
    
    NSURL *url = [NSURL URLWithString:@"msauth://code/attacker-redirect?code=somecode"];
    NSError *error;
    MSIDCBAWebAADAuthResponse *response = [[MSIDCBAWebAADAuthResponse alloc] initWithURL:url
                                                                    expectedRedirectUri:@"msauth://code/legitimate-redirect"
                                                                           requestState:nil
                                                                     ignoreInvalidState:NO
                                                                                context:nil
                                                                                  error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(response);
}

- (void)testInitWithURLAndState_withStrictMatchingDisabled_shouldIgnoreRedirectUri
{
    // When flight flag is disabled (legacy), redirect URIs are not validated
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_ENABLE_CBA_ORIGIN_FIX: @NO };
    
    NSURL *url = [NSURL URLWithString:@"msauth://code/attacker-redirect?code=somecode"];
    NSError *error;
    MSIDCBAWebAADAuthResponse *response = [[MSIDCBAWebAADAuthResponse alloc] initWithURL:url
                                                                    expectedRedirectUri:@"msauth://code/legitimate-redirect"
                                                                           requestState:nil
                                                                     ignoreInvalidState:NO
                                                                                context:nil
                                                                                  error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(response);
}

#pragma mark - State Validation with Flight Flag

- (void)testInitWithURLAndState_withStateValidationEnabled_whenStateMatches_shouldSucceed
{
    // When flight flag is enabled, state must be validated
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_ENABLE_CBA_ORIGIN_FIX: @YES };
    
    NSString *state = @"test-state";
    NSString *encodedState = [state msidBase64UrlEncode];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://code/redirect?code=somecode&state=%@", encodedState]];
    
    NSError *error;
    MSIDCBAWebAADAuthResponse *response = [[MSIDCBAWebAADAuthResponse alloc] initWithURL:url
                                                                    expectedRedirectUri:@"msauth://code/redirect"
                                                                            requestState:state
                                                                      ignoreInvalidState:NO
                                                                                 context:nil
                                                                                   error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(response);
    XCTAssertEqualObjects(response.authorizationCode, @"somecode");
}

- (void)testInitWithURLAndState_withStateValidationEnabled_whenStateMismatch_shouldFail
{
    // When flight flag is enabled, mismatched state should be rejected
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_ENABLE_CBA_ORIGIN_FIX: @YES };
    
    NSString *expectedState = @"expected-state";
    NSString *responseState = @"different-state";
    NSString *encodedState = [responseState msidBase64UrlEncode];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://code/redirect?code=somecode&state=%@", encodedState]];
    
    NSError *error;
    MSIDCBAWebAADAuthResponse *response = [[MSIDCBAWebAADAuthResponse alloc] initWithURL:url
                                                                    expectedRedirectUri:@"msauth://code/redirect"
                                                                            requestState:expectedState
                                                                      ignoreInvalidState:NO
                                                                                 context:nil
                                                                                   error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(response);
}

- (void)testInitWithURLAndState_withStateValidationDisabled_shouldSkipStateCheck
{
    // When flight flag is disabled (legacy), state validation is skipped
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_ENABLE_CBA_ORIGIN_FIX: @NO };
    
    NSString *expectedState = @"expected-state";
    NSString *responseState = @"different-state";
    NSString *encodedState = [responseState msidBase64UrlEncode];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://code/redirect?code=somecode&state=%@", encodedState]];
    
    NSError *error;
    MSIDCBAWebAADAuthResponse *response = [[MSIDCBAWebAADAuthResponse alloc] initWithURL:url
                                                                    expectedRedirectUri:@"msauth://code/redirect"
                                                                            requestState:expectedState
                                                                      ignoreInvalidState:NO
                                                                                 context:nil
                                                                                   error:&error];
    
    // With flight flag OFF, should succeed even with state mismatch (legacy behavior)
    XCTAssertNil(error);
    XCTAssertNotNil(response);
}

- (void)testInitWithURLAndState_whenMissingStateButExpected_shouldFail
{
    // When state was expected but response has no state, should fail
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_ENABLE_CBA_ORIGIN_FIX: @YES };
    
    NSString *expectedState = @"expected-state";
    NSURL *url = [NSURL URLWithString:@"msauth://code/redirect?code=somecode"];
    
    NSError *error;
    MSIDCBAWebAADAuthResponse *response = [[MSIDCBAWebAADAuthResponse alloc] initWithURL:url
                                                                    expectedRedirectUri:@"msauth://code/redirect"
                                                                            requestState:expectedState
                                                                      ignoreInvalidState:NO
                                                                                 context:nil
                                                                                   error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(response);
}

- (void)testInitWithURLAndState_whenNeitherStateExpectedNorProvided_shouldSucceed
{
    // When no state was expected and response has no state, should succeed
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_ENABLE_CBA_ORIGIN_FIX: @YES };
    
    NSURL *url = [NSURL URLWithString:@"msauth://code/redirect?code=somecode"];
    
    NSError *error;
    MSIDCBAWebAADAuthResponse *response = [[MSIDCBAWebAADAuthResponse alloc] initWithURL:url
                                                                    expectedRedirectUri:@"msauth://code/redirect"
                                                                            requestState:nil
                                                                      ignoreInvalidState:NO
                                                                                 context:nil
                                                                                   error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(response);
}

@end
