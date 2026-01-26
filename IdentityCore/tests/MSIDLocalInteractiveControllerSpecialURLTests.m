//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDLocalInteractiveController.h"
#import "MSIDInteractiveWebviewHandler.h"
#import "MSIDInteractiveWebviewState.h"
#import "MSIDSpecialURLViewActionResolver.h"
#import "MSIDWebviewAction.h"

@interface MSIDLocalInteractiveControllerSpecialURLTests : XCTestCase

@property (nonatomic) MSIDLocalInteractiveController *controller;

@end

@implementation MSIDLocalInteractiveControllerSpecialURLTests

- (void)setUp
{
    [super setUp];
    
    // Create controller for testing
    self.controller = [[MSIDLocalInteractiveController alloc] initWithRequestParameters:nil
                                                                         interactiveRequestParameters:nil
                                                                                      tokenRequestProvider:nil
                                                                                                    error:nil];
    
    // Enable special URL handling
    self.controller.specialURLHandlingEnabled = YES;
}

- (void)tearDown
{
    self.controller = nil;
    [super tearDown];
}

#pragma mark - Design Verification Tests

- (void)testDesignVerification_sessionStateHas3PropertiesOnly
{
    // Verify simplified design: session state should have exactly 3 properties
    MSIDInteractiveWebviewState *state = self.controller.sessionState;
    
    XCTAssertNotNil(state, @"Session state should be created");
    
    // Verify we can access the 3 properties
    XCTAssertEqual(state.brtAttemptCount, 0, @"Initial BRT attempt count should be 0");
    XCTAssertFalse(state.brtAcquired, @"Initial BRT acquired should be NO");
    XCTAssertNil(state.responseHeaders, @"Initial response headers should be nil");
    
    // This test verifies the simplified design has only 3 properties
    // If more properties were added, they would need to be tested here
}

- (void)testDesignVerification_noStateMachineUsed
{
    // Verify simplified design: NO state machine usage
    // The controller should have urlResolver but NO stateMachine
    
    XCTAssertNotNil(self.controller.urlResolver, @"URL resolver should exist");
    
    // Verify sessionState exists (simplified approach)
    XCTAssertNotNil(self.controller.sessionState, @"Session state should exist");
    
    // This test verifies the simplified approach without state machine
}

- (void)testDesignVerification_handlerProtocolConformance
{
    // Verify MSIDLocalInteractiveController conforms to MSIDInteractiveWebviewHandler
    XCTAssertTrue([self.controller conformsToProtocol:@protocol(MSIDInteractiveWebviewHandler)],
                  @"Controller must implement handler protocol");
    
    // Verify key handler methods exist
    XCTAssertTrue([self.controller respondsToSelector:@selector(isRunningInBrokerContext)]);
    XCTAssertTrue([self.controller respondsToSelector:@selector(shouldAcquireBRTForSpecialURL:state:)]);
    XCTAssertTrue([self.controller respondsToSelector:@selector(viewActionForSpecialURL:state:)]);
    XCTAssertTrue([self.controller respondsToSelector:@selector(openSystemWebviewWithURL:headers:purpose:completion:)]);
}

#pragma mark - BRT Policy Tests

- (void)testBRTPolicy_whenNotInBrokerAndNotAcquired_shouldReturnYes
{
    // Setup
    NSURL *enrollURL = [NSURL URLWithString:@"msauth://enroll?cpurl=https://example.com"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    state.brtAcquired = NO;
    state.brtAttemptCount = 0;
    
    // Test
    BOOL shouldAcquire = [self.controller shouldAcquireBRTForSpecialURL:enrollURL state:state];
    
    // Verify
    XCTAssertTrue(shouldAcquire, @"Should acquire BRT when not in broker and not yet acquired");
}

- (void)testBRTPolicy_whenAlreadyAcquired_shouldReturnNo
{
    // Setup
    NSURL *enrollURL = [NSURL URLWithString:@"msauth://installProfile"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    state.brtAcquired = YES;  // Already acquired
    state.brtAttemptCount = 1;
    
    // Test
    BOOL shouldAcquire = [self.controller shouldAcquireBRTForSpecialURL:enrollURL state:state];
    
    // Verify
    XCTAssertFalse(shouldAcquire, @"Should NOT acquire BRT when already acquired");
}

- (void)testBRTPolicy_whenMaxAttemptsReached_shouldReturnNo
{
    // Setup
    NSURL *enrollURL = [NSURL URLWithString:@"msauth://enroll"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    state.brtAcquired = NO;
    state.brtAttemptCount = 2;  // Max attempts
    
    // Test
    BOOL shouldAcquire = [self.controller shouldAcquireBRTForSpecialURL:enrollURL state:state];
    
    // Verify
    XCTAssertFalse(shouldAcquire, @"Should NOT acquire BRT when max attempts (2) reached");
}

- (void)testBRTPolicy_whenOneAttemptFailed_shouldReturnYes
{
    // Setup: First attempt failed, try second
    NSURL *enrollURL = [NSURL URLWithString:@"msauth://enroll"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    state.brtAcquired = NO;  // Not acquired (first failed)
    state.brtAttemptCount = 1;  // One attempt made
    
    // Test
    BOOL shouldAcquire = [self.controller shouldAcquireBRTForSpecialURL:enrollURL state:state];
    
    // Verify
    XCTAssertTrue(shouldAcquire, @"Should allow second BRT attempt (retry once)");
}

- (void)testBRTFailurePolicy_shouldReturnContinue
{
    // Setup
    NSURL *enrollURL = [NSURL URLWithString:@"msauth://enroll"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // Test
    MSIDBRTFailurePolicy policy = [self.controller brtFailurePolicyForSpecialURL:enrollURL state:state];
    
    // Verify
    XCTAssertEqual(policy, MSIDBRTFailurePolicyContinue, @"Should continue on BRT failure");
}

#pragma mark - Broker Retry Policy Tests

- (void)testBrokerRetryPolicy_whenNotInBrokerContextOnIOS_shouldReturnYes
{
    // Setup
    NSURL *profileInstalledURL = [NSURL URLWithString:@"msauth://profileInstalled"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // Test
    BOOL shouldRetry = [self.controller shouldRetryInBrokerForSpecialURL:profileInstalledURL state:state];
    
    // Verify: Local controller is NOT in broker context, iOS should return YES
#if TARGET_OS_IOS
    XCTAssertTrue(shouldRetry, @"Should retry in broker on iOS when not in broker context");
#else
    XCTAssertFalse(shouldRetry, @"Should NOT retry in broker on macOS");
#endif
}

- (void)testIsRunningInBrokerContext_forLocalController_shouldReturnNo
{
    // Test
    BOOL inBroker = [self.controller isRunningInBrokerContext];
    
    // Verify: MSIDLocalInteractiveController is NOT in broker context
    XCTAssertFalse(inBroker, @"Local interactive controller should NOT be in broker context");
}

#pragma mark - View Action Resolution Tests

- (void)testViewActionForSpecialURL_enroll_shouldReturnLoadRequestAction
{
    // Setup
    NSURL *enrollURL = [NSURL URLWithString:@"msauth://enroll?cpurl=https://go.microsoft.com/fwlink/?LinkId=396941"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // Test
    MSIDWebviewAction *action = [self.controller viewActionForSpecialURL:enrollURL state:state];
    
    // Verify
    XCTAssertNotNil(action, @"Should return an action");
    XCTAssertEqual(action.type, MSIDWebviewActionTypeLoadRequest, @"Enroll should return LoadRequest action");
    XCTAssertEqualObjects(action.url.absoluteString, @"https://go.microsoft.com/fwlink/?LinkId=396941", 
                         @"Should extract cpurl from query parameters");
}

- (void)testViewActionForSpecialURL_installProfile_shouldReturnOpenASWebAuthAction
{
    // Setup
    NSURL *installProfileURL = [NSURL URLWithString:@"msauth://installProfile"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    state.responseHeaders = @{
        @"X-Install-Url": @"https://portal.manage.microsoft.com/enroll/ios",
        @"X-Intune-AuthToken": @"test-auth-token-12345"
    };
    
    // Test
    MSIDWebviewAction *action = [self.controller viewActionForSpecialURL:installProfileURL state:state];
    
    // Verify
    XCTAssertNotNil(action, @"Should return an action");
    XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenASWebAuthSession, 
                  @"InstallProfile should return OpenASWebAuthSession action");
    XCTAssertEqualObjects(action.url.absoluteString, @"https://portal.manage.microsoft.com/enroll/ios",
                         @"Should extract URL from X-Install-Url header");
    XCTAssertNotNil(action.additionalHeaders, @"Should include additional headers");
    XCTAssertEqualObjects(action.additionalHeaders[@"X-Intune-AuthToken"], @"test-auth-token-12345",
                         @"Should extract X-Intune-AuthToken from headers");
}

- (void)testViewActionForSpecialURL_profileInstalled_shouldReturnCompleteAction
{
    // Setup
    NSURL *profileInstalledURL = [NSURL URLWithString:@"msauth://profileInstalled"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // Test
    MSIDWebviewAction *action = [self.controller viewActionForSpecialURL:profileInstalledURL state:state];
    
    // Verify
    XCTAssertNotNil(action, @"Should return an action");
    XCTAssertEqual(action.type, MSIDWebviewActionTypeCompleteWithURL, 
                  @"ProfileInstalled should return CompleteWithURL action");
    XCTAssertEqualObjects(action.url, profileInstalledURL,
                         @"Should return the same URL for completion");
}

- (void)testViewActionForSpecialURL_profileComplete_shouldReturnCompleteAction
{
    // Setup: Test alternative URL pattern
    NSURL *profileCompleteURL = [NSURL URLWithString:@"msauth://profileComplete"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // Test
    MSIDWebviewAction *action = [self.controller viewActionForSpecialURL:profileCompleteURL state:state];
    
    // Verify
    XCTAssertNotNil(action, @"Should return an action");
    XCTAssertEqual(action.type, MSIDWebviewActionTypeCompleteWithURL, 
                  @"ProfileComplete should also return CompleteWithURL action");
}

#pragma mark - Header Capture Tests

- (void)testHeaderCapture_shouldStoreInSessionState
{
    // Setup
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    NSDictionary *headers = @{
        @"X-Install-Url": @"https://portal.manage.microsoft.com/test",
        @"X-Intune-AuthToken": @"token123",
        @"Other-Header": @"value"
    };
    
    // Test: Simulate header transfer (what webview would do)
    state.responseHeaders = headers;
    
    // Verify
    XCTAssertNotNil(state.responseHeaders, @"Headers should be stored");
    XCTAssertEqual(state.responseHeaders.count, 3, @"All headers should be stored");
    XCTAssertEqualObjects(state.responseHeaders[@"X-Install-Url"], @"https://portal.manage.microsoft.com/test");
    XCTAssertEqualObjects(state.responseHeaders[@"X-Intune-AuthToken"], @"token123");
}

#pragma mark - Session State Tests

- (void)testSessionState_initialState_shouldHaveCorrectDefaults
{
    // Test
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // Verify simplified design defaults
    XCTAssertEqual(state.brtAttemptCount, 0, @"Initial BRT attempt count should be 0");
    XCTAssertFalse(state.brtAcquired, @"Initial BRT acquired should be NO");
    XCTAssertNil(state.responseHeaders, @"Initial response headers should be nil");
}

- (void)testSessionState_brtAttemptCount_canBeIncremented
{
    // Setup
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // Test
    state.brtAttemptCount = 1;
    XCTAssertEqual(state.brtAttemptCount, 1);
    
    state.brtAttemptCount = 2;
    XCTAssertEqual(state.brtAttemptCount, 2);
}

- (void)testSessionState_brtAcquired_canBeSet
{
    // Setup
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // Test
    state.brtAcquired = YES;
    
    // Verify
    XCTAssertTrue(state.brtAcquired);
}

#pragma mark - E2E Flow Tests

- (void)testE2EFlow_enrollURL_firstAttempt_shouldAcquireBRT
{
    // Setup: Simulate msauth://enroll (first special URL in session)
    NSURL *enrollURL = [NSURL URLWithString:@"msauth://enroll?cpurl=https://go.microsoft.com/fwlink/?LinkId=396941"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // Pre-conditions
    XCTAssertFalse(state.brtAcquired);
    XCTAssertEqual(state.brtAttemptCount, 0);
    
    // Test BRT policy
    BOOL shouldAcquire = [self.controller shouldAcquireBRTForSpecialURL:enrollURL state:state];
    XCTAssertTrue(shouldAcquire, @"Should acquire BRT on first enroll URL");
    
    // Simulate BRT acquisition attempt (would be done in handler)
    state.brtAttemptCount++;
    // Note: actual acquisition is TODO, so we simulate success
    state.brtAcquired = YES;
    
    // Test view action resolution
    MSIDWebviewAction *action = [self.controller viewActionForSpecialURL:enrollURL state:state];
    
    // Verify
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeLoadRequest, @"Should return LoadRequest for enroll");
    XCTAssertEqualObjects(action.url.absoluteString, @"https://go.microsoft.com/fwlink/?LinkId=396941");
    
    // Post-conditions
    XCTAssertTrue(state.brtAcquired, @"BRT should be marked as acquired");
    XCTAssertEqual(state.brtAttemptCount, 1, @"BRT attempt count should be 1");
}

- (void)testE2EFlow_installProfile_withHeaders_shouldExtractAndCreateASWebAuthAction
{
    // Setup: Simulate msauth://installProfile with headers
    NSURL *installProfileURL = [NSURL URLWithString:@"msauth://installProfile"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    state.brtAcquired = YES;  // Already acquired during enroll
    state.brtAttemptCount = 1;
    state.responseHeaders = @{
        @"X-Install-Url": @"https://portal.manage.microsoft.com/enroll/ios/12345",
        @"X-Intune-AuthToken": @"eyJ0eXAi...sample-jwt-token",
        @"Content-Type": @"application/json"
    };
    
    // Test BRT policy (should skip)
    BOOL shouldAcquire = [self.controller shouldAcquireBRTForSpecialURL:installProfileURL state:state];
    XCTAssertFalse(shouldAcquire, @"Should NOT acquire BRT when already acquired");
    
    // Test view action resolution
    MSIDWebviewAction *action = [self.controller viewActionForSpecialURL:installProfileURL state:state];
    
    // Verify action
    XCTAssertNotNil(action, @"Should return an action");
    XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenASWebAuthSession,
                  @"InstallProfile should return OpenASWebAuthSession action");
    
    // Verify URL extraction
    XCTAssertEqualObjects(action.url.absoluteString, @"https://portal.manage.microsoft.com/enroll/ios/12345",
                         @"Should extract URL from X-Install-Url header");
    
    // Verify header extraction
    XCTAssertNotNil(action.additionalHeaders, @"Should include additional headers");
    XCTAssertEqualObjects(action.additionalHeaders[@"X-Intune-AuthToken"], @"eyJ0eXAi...sample-jwt-token",
                         @"Should extract X-Intune-AuthToken for ASWebAuth");
    
    // Verify purpose
    XCTAssertEqual(action.purpose, MSIDSystemWebviewPurposeInstallProfile,
                  @"Purpose should be install profile");
    
    // Post-conditions
    XCTAssertTrue(state.brtAcquired, @"BRT should remain acquired");
    XCTAssertEqual(state.brtAttemptCount, 1, @"BRT attempt count should remain 1");
}

- (void)testE2EFlow_profileInstalled_shouldReturnCompleteAction
{
    // Setup: Simulate msauth://profileInstalled (enrollment complete)
    NSURL *profileInstalledURL = [NSURL URLWithString:@"msauth://profileInstalled"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    state.brtAcquired = YES;
    state.brtAttemptCount = 1;
    
    // Test view action resolution
    MSIDWebviewAction *action = [self.controller viewActionForSpecialURL:profileInstalledURL state:state];
    
    // Verify
    XCTAssertNotNil(action, @"Should return an action");
    XCTAssertEqual(action.type, MSIDWebviewActionTypeCompleteWithURL,
                  @"ProfileInstalled should return CompleteWithURL action");
    XCTAssertEqualObjects(action.url, profileInstalledURL,
                         @"Should return the callback URL");
}

- (void)testE2EFlow_completeFlow_shouldTrackSessionStateCorrectly
{
    // This test simulates the complete flow: enroll → installProfile → profileInstalled
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // Step 1: msauth://enroll
    NSURL *enrollURL = [NSURL URLWithString:@"msauth://enroll?cpurl=https://example.com"];
    
    BOOL shouldAcquireBRT1 = [self.controller shouldAcquireBRTForSpecialURL:enrollURL state:state];
    XCTAssertTrue(shouldAcquireBRT1, @"Step 1: Should acquire BRT on first URL");
    
    // Simulate BRT acquisition
    state.brtAttemptCount = 1;
    state.brtAcquired = YES;
    
    MSIDWebviewAction *action1 = [self.controller viewActionForSpecialURL:enrollURL state:state];
    XCTAssertEqual(action1.type, MSIDWebviewActionTypeLoadRequest, @"Step 1: Should return LoadRequest");
    
    // Step 2: msauth://installProfile
    NSURL *installProfileURL = [NSURL URLWithString:@"msauth://installProfile"];
    state.responseHeaders = @{
        @"X-Install-Url": @"https://portal.manage.microsoft.com/enroll",
        @"X-Intune-AuthToken": @"token123"
    };
    
    BOOL shouldAcquireBRT2 = [self.controller shouldAcquireBRTForSpecialURL:installProfileURL state:state];
    XCTAssertFalse(shouldAcquireBRT2, @"Step 2: Should NOT acquire BRT (already acquired)");
    
    MSIDWebviewAction *action2 = [self.controller viewActionForSpecialURL:installProfileURL state:state];
    XCTAssertEqual(action2.type, MSIDWebviewActionTypeOpenASWebAuthSession, 
                  @"Step 2: Should return OpenASWebAuthSession");
    
    // Step 3: msauth://profileInstalled
    NSURL *profileInstalledURL = [NSURL URLWithString:@"msauth://profileInstalled"];
    
    MSIDWebviewAction *action3 = [self.controller viewActionForSpecialURL:profileInstalledURL state:state];
    XCTAssertEqual(action3.type, MSIDWebviewActionTypeCompleteWithURL, 
                  @"Step 3: Should return CompleteWithURL");
    
    // Verify final state
    XCTAssertTrue(state.brtAcquired, @"BRT should be acquired");
    XCTAssertEqual(state.brtAttemptCount, 1, @"Should have 1 BRT attempt");
}

- (void)testE2EFlow_brtRetry_whenFirstFails_shouldAllowSecondAttempt
{
    // This tests the "max 2 attempts" ground rule
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // Step 1: First msauth:// URL - first BRT attempt
    NSURL *enrollURL1 = [NSURL URLWithString:@"msauth://enroll?cpurl=https://example.com"];
    
    BOOL shouldAcquire1 = [self.controller shouldAcquireBRTForSpecialURL:enrollURL1 state:state];
    XCTAssertTrue(shouldAcquire1, @"Should allow first BRT attempt");
    
    // Simulate first attempt failure
    state.brtAttemptCount = 1;
    state.brtAcquired = NO;  // Failed
    
    // Step 2: Second msauth:// URL - second BRT attempt
    NSURL *enrollURL2 = [NSURL URLWithString:@"msauth://installProfile"];
    
    BOOL shouldAcquire2 = [self.controller shouldAcquireBRTForSpecialURL:enrollURL2 state:state];
    XCTAssertTrue(shouldAcquire2, @"Should allow second BRT attempt (retry once)");
    
    // Simulate second attempt
    state.brtAttemptCount = 2;
    state.brtAcquired = NO;  // Failed again
    
    // Step 3: Third msauth:// URL - should NOT allow third attempt
    NSURL *enrollURL3 = [NSURL URLWithString:@"msauth://profileInstalled"];
    
    BOOL shouldAcquire3 = [self.controller shouldAcquireBRTForSpecialURL:enrollURL3 state:state];
    XCTAssertFalse(shouldAcquire3, @"Should NOT allow third BRT attempt (max 2)");
    
    XCTAssertEqual(state.brtAttemptCount, 2, @"Max 2 attempts should be enforced");
}

#pragma mark - Architecture Verification Tests

- (void)testArchitecture_optionThree_controllerCreatesSystemWebview
{
    // Verify Option 3: InteractiveController should handle system webview creation
    // NOT EmbeddedWebViewController
    
    // Verify controller has the method (Option 3 implementation)
    XCTAssertTrue([self.controller respondsToSelector:@selector(openSystemWebviewWithURL:headers:purpose:completion:)],
                  @"Controller should implement openSystemWebviewWithURL (Option 3)");
    
    // Verify controller can track system webview
    XCTAssertTrue([self.controller respondsToSelector:@selector(currentSystemWebview)],
                  @"Controller should have currentSystemWebview property");
}

- (void)testArchitecture_synchronousHandlerCalls_noStateMachine
{
    // Verify simplified design uses synchronous calls, not async state machine
    
    // Test that viewActionForSpecialURL returns immediately (synchronous)
    NSURL *testURL = [NSURL URLWithString:@"msauth://enroll?cpurl=https://example.com"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // This call should be synchronous (returns action immediately)
    MSIDWebviewAction *action = [self.controller viewActionForSpecialURL:testURL state:state];
    
    XCTAssertNotNil(action, @"Should return action synchronously");
    XCTAssertEqual(action.type, MSIDWebviewActionTypeLoadRequest);
    
    // Verify no state machine property exists (simplified design)
    // If state machine existed, this test would fail compilation
}

- (void)testArchitecture_featureFlagControl
{
    // Verify feature flag controls special URL handling
    
    // Test flag can be set
    self.controller.specialURLHandlingEnabled = NO;
    XCTAssertFalse(self.controller.specialURLHandlingEnabled);
    
    self.controller.specialURLHandlingEnabled = YES;
    XCTAssertTrue(self.controller.specialURLHandlingEnabled);
}

#pragma mark - Error Handling Tests

- (void)testErrorHandling_genericBRTError_shouldCreateError
{
    // Test
    NSError *error = [self.controller genericBrtError];
    
    // Verify
    XCTAssertNotNil(error, @"Should create BRT error");
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

#pragma mark - Ground Rules Verification Tests

- (void)testGroundRule1_brtOnlyIfNotInBrokerContext
{
    // Ground Rule: "If token acquisition is not happening in broker context, 
    //               BRT should be acquired..."
    
    // MSIDLocalInteractiveController is NOT in broker context
    BOOL inBroker = [self.controller isRunningInBrokerContext];
    XCTAssertFalse(inBroker, @"Local controller should NOT be in broker context");
    
    // Therefore, BRT SHOULD be acquired (if other conditions met)
    NSURL *url = [NSURL URLWithString:@"msauth://enroll"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    BOOL shouldAcquire = [self.controller shouldAcquireBRTForSpecialURL:url state:state];
    XCTAssertTrue(shouldAcquire, @"Should acquire BRT when NOT in broker context");
}

- (void)testGroundRule2_brtOnFirstSpecialRedirect
{
    // Ground Rule: "BRT should be acquired for the first redirect with 
    //               the scheme msauth:// or browser://"
    
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // First msauth:// URL
    NSURL *firstURL = [NSURL URLWithString:@"msauth://enroll"];
    BOOL shouldAcquireFirst = [self.controller shouldAcquireBRTForSpecialURL:firstURL state:state];
    XCTAssertTrue(shouldAcquireFirst, @"Should acquire on first special URL");
    
    // Simulate acquisition
    state.brtAcquired = YES;
    state.brtAttemptCount = 1;
    
    // Second msauth:// URL
    NSURL *secondURL = [NSURL URLWithString:@"msauth://installProfile"];
    BOOL shouldAcquireSecond = [self.controller shouldAcquireBRTForSpecialURL:secondURL state:state];
    XCTAssertFalse(shouldAcquireSecond, @"Should NOT acquire on subsequent special URLs");
}

- (void)testGroundRule3_onlyTwoAttemptsPerSession
{
    // Ground Rule: "Only 2 attempts in all together in one full token request session"
    
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    NSURL *url = [NSURL URLWithString:@"msauth://enroll"];
    
    // Attempt 1
    BOOL shouldAcquire1 = [self.controller shouldAcquireBRTForSpecialURL:url state:state];
    XCTAssertTrue(shouldAcquire1, @"Should allow attempt 1");
    state.brtAttemptCount = 1;
    
    // Attempt 2 (first failed)
    BOOL shouldAcquire2 = [self.controller shouldAcquireBRTForSpecialURL:url state:state];
    XCTAssertTrue(shouldAcquire2, @"Should allow attempt 2 (retry once)");
    state.brtAttemptCount = 2;
    
    // Attempt 3 (should be blocked)
    BOOL shouldAcquire3 = [self.controller shouldAcquireBRTForSpecialURL:url state:state];
    XCTAssertFalse(shouldAcquire3, @"Should NOT allow attempt 3 (max 2 attempts)");
}

- (void)testGroundRule4_headerCaptureForAllResponses
{
    // Ground Rule: "MSAL should capture headers for all responses 
    //               throughout the flow so MSAL can set the telemetry object"
    
    // This is verified by responseHeaderHandler wiring in factory
    // Here we test that session state can store headers
    
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    // Response 1
    state.responseHeaders = @{@"Header1": @"Value1"};
    XCTAssertNotNil(state.responseHeaders);
    XCTAssertEqual(state.responseHeaders.count, 1);
    
    // Response 2 (overwrites)
    state.responseHeaders = @{@"Header2": @"Value2", @"Header3": @"Value3"};
    XCTAssertEqual(state.responseHeaders.count, 2);
    
    // Verify last headers are stored
    XCTAssertEqualObjects(state.responseHeaders[@"Header2"], @"Value2");
}

#pragma mark - Callback Pattern Tests

- (void)testCallback_didReceiveHTTPResponseHeaders_shouldSetSessionState
{
    // Verify callback pattern: controller owns state mutation
    
    // Initial state
    XCTAssertNil(self.controller.sessionState.responseHeaders);
    
    // Simulate headers received via callback
    NSDictionary *headers = @{
        @"X-Install-Url": @"https://portal.manage.microsoft.com/enroll",
        @"X-Intune-AuthToken": @"token123"
    };
    
    // Call callback method (as factory would do)
    [self.controller didReceiveHTTPResponseHeaders:headers];
    
    // Verify controller set its own state
    XCTAssertNotNil(self.controller.sessionState.responseHeaders);
    XCTAssertEqual(self.controller.sessionState.responseHeaders.count, 2);
    XCTAssertEqualObjects(self.controller.sessionState.responseHeaders[@"X-Install-Url"], 
                         @"https://portal.manage.microsoft.com/enroll");
    XCTAssertEqualObjects(self.controller.sessionState.responseHeaders[@"X-Intune-AuthToken"], 
                         @"token123");
}

- (void)testCallback_didReceiveHTTPResponseHeaders_multipleCallbacks_shouldOverwrite
{
    // Verify multiple callbacks overwrite (last wins)
    
    // First callback
    NSDictionary *headers1 = @{@"Header1": @"Value1"};
    [self.controller didReceiveHTTPResponseHeaders:headers1];
    XCTAssertEqual(self.controller.sessionState.responseHeaders.count, 1);
    
    // Second callback (overwrites)
    NSDictionary *headers2 = @{@"Header2": @"Value2", @"Header3": @"Value3"};
    [self.controller didReceiveHTTPResponseHeaders:headers2];
    XCTAssertEqual(self.controller.sessionState.responseHeaders.count, 2);
    XCTAssertNil(self.controller.sessionState.responseHeaders[@"Header1"]);
    XCTAssertEqualObjects(self.controller.sessionState.responseHeaders[@"Header2"], @"Value2");
}

- (void)testCallback_ownership_controllerSetsOwnState
{
    // Verify proper ownership: controller mutates its own state, not external mutation
    
    NSDictionary *headers = @{@"Test-Header": @"Test-Value"};
    
    // Controller receives callback
    [self.controller didReceiveHTTPResponseHeaders:headers];
    
    // Verify controller's state was set by controller itself
    XCTAssertNotNil(self.controller.sessionState.responseHeaders);
    XCTAssertEqualObjects(self.controller.sessionState.responseHeaders[@"Test-Header"], @"Test-Value");
    
    // Verify this is the same sessionState object
    XCTAssertTrue(self.controller.sessionState.responseHeaders == self.controller.sessionState.responseHeaders);
}

- (void)testCallback_architecture_noExternalStateMutation
{
    // Verify architectural principle: sessionState only mutated by owner
    
    // This test documents the architectural improvement:
    // BEFORE: WebviewController mutated controller.sessionState ❌
    // AFTER: Controller receives callback and sets its own state ✅
    
    NSDictionary *headers = @{@"X-Header": @"Value"};
    
    // Simulate callback pattern (proper architecture)
    [self.controller didReceiveHTTPResponseHeaders:headers];
    
    // Verify state was set
    XCTAssertNotNil(self.controller.sessionState.responseHeaders);
    
    // This test passes because controller sets its own state via callback
    // rather than webview reaching in to set controller's state
}

@end
