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

#if !MSID_EXCLUDE_WEBKIT

#import <XCTest/XCTest.h>
#import "MSIDWebviewNavigationHandler.h"
#import "MSIDWebviewNavigationDecision.h"
#import "MSIDWebviewConstants.h"
#import "MSIDError.h"
#import "MSIDTestContext.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDTestWebviewInteractingViewController.h"
#import "MSIDWebviewNavigationDelegate.h"
#import "MSIDUXCallbackProvider.h"
#import "MSIDUXCallbackProtocol.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDConstants.h"
#import "MSIDMockUXCallbackProvider.h"
#import "MSIDOnboardingBlobBuilder.h"
#import "MSIDOnboardingBlobFieldKeys.h"
#import "MSIDTestSwizzle.h"
#if !MSID_EXCLUDE_SYSTEMWV
#import "MSIDSystemWebviewTransitionManager.h"
#endif

// Stub conforming to MSIDWebviewNavigationDelegate for delegate-wiring assertions.
@interface MSIDTestNavigationDelegateStub : NSObject <MSIDWebviewNavigationDelegate>
@end

@implementation MSIDTestNavigationDelegateStub
@end

// Expose private methods and properties for testing
@interface MSIDWebviewNavigationHandler (Testing)

// Expose private methods and properties for testing.
@property (nonatomic) NSDictionary *lastResponseHeaders;
@property (nonatomic, weak) MSIDOnboardingBlobBuilder *onboardingBlobBuilder;

- (BOOL)isValidHandoffURL:(NSURL *)url error:(NSError *__autoreleasing *)error;
- (BOOL)isURLInAllowedDomains:(NSURL *)url;
- (NSDictionary<NSString *, id> *)normalizeHeaders:(NSDictionary *)headers;
- (NSString *)callbackURLScheme;
- (BOOL)shouldUseEphemeralSession;
- (nullable NSDictionary<NSString *, NSString *> *)extractAdditionalHeadersToForward;
- (NSDictionary<NSString *, NSString *> *)buildAdditionalHeadersFromList:(NSString *)attachHeadersList;
- (void)scheduleMDMProfileInstalledNotificationIfNeeded;

@end

@interface MSIDWebviewNavigationHandlerTests : XCTestCase

@property (nonatomic) MSIDWebviewNavigationHandler *handler;
@property (nonatomic) MSIDTestContext *context;
@property (nonatomic) MSIDFlightManagerMockProvider *flightProvider;

@end

@implementation MSIDWebviewNavigationHandlerTests

- (void)setUp
{
    [super setUp];
    self.context = [MSIDTestContext new];
    self.handler = [[MSIDWebviewNavigationHandler alloc] initWithContext:self.context];

    self.flightProvider = [MSIDFlightManagerMockProvider new];
    MSIDFlightManager.sharedInstance.flightProvider = self.flightProvider;
}

- (void)tearDown
{
    [MSIDTestSwizzle reset];
    self.handler = nil;
    self.context = nil;
    MSIDUXCallbackProvider.uxCallbackProvider = nil;
    MSIDFlightManager.sharedInstance.flightProvider = nil;
    self.flightProvider = nil;
    [super tearDown];
}

#pragma mark - isValidHandoffURL tests

- (void)testIsValidHandoffURL_whenURLIsNil_shouldReturnNO
{
    NSError *error = nil;
    BOOL result = [self.handler isValidHandoffURL:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidASWebAuthenticationURL);
}

- (void)testIsValidHandoffURL_whenURLHasNoScheme_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"//login.microsoftonline.com/path"];
    NSError *error = nil;
    BOOL result = [self.handler isValidHandoffURL:url error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidASWebAuthenticationURL);
}

- (void)testIsValidHandoffURL_whenURLIsHTTP_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"http://portal.manage.microsoft.com/path"];
    NSError *error = nil;
    BOOL result = [self.handler isValidHandoffURL:url error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidASWebAuthenticationURL);
}

- (void)testIsValidHandoffURL_whenURLHasNonAllowedDomain_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://evil.example.com/path"];
    NSError *error = nil;
    BOOL result = [self.handler isValidHandoffURL:url error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidASWebAuthenticationURL);
}

- (void)testIsValidHandoffURL_whenURLIsValidHTTPSAndAllowedDomain_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage.microsoft.com/path"];
    NSError *error = nil;
    BOOL result = [self.handler isValidHandoffURL:url error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testIsValidHandoffURL_whenURLSchemeIsUppercase_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"HTTPS://portal.manage.microsoft.com/path"];
    NSError *error = nil;
    BOOL result = [self.handler isValidHandoffURL:url error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

#pragma mark - isURLInAllowedDomains tests

- (void)testIsURLInAllowedDomains_whenURLIsNil_shouldReturnNO
{
    XCTAssertFalse([self.handler isURLInAllowedDomains:nil]);
}

- (void)testIsURLInAllowedDomains_whenHostIsNil_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://"];
    XCTAssertFalse([self.handler isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenDomainIsAllowed_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage.microsoft.com/path"];
    XCTAssertTrue([self.handler isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenDomainIsNotAllowed_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://attacker.example.com/path"];
    XCTAssertFalse([self.handler isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenDomainIsAllowedDogfood_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage-dogfood.microsoft.com/path"];
    XCTAssertTrue([self.handler isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenAllowedDomainIsSubdomainOfAttackerDomain_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage.microsoft.com.attacker.com/path"];
    XCTAssertFalse([self.handler isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenAttackerControlledSubdomainUsesAllowedDomainSuffix_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://evil.portal.manage.microsoft.com/path"];
    XCTAssertFalse([self.handler isURLInAllowedDomains:url]);
}


#pragma mark - normalizeHeaders tests

- (void)testNormalizeHeaders_whenMixedCaseKeys_shouldLowercaseAllKeys
{
    NSDictionary *input = @{@"Content-Type": @"application/json",
                            @"X-MS-ASWEBAUTH-HANDOFF-URL": @"https://example.com"};
    NSDictionary *result = [self.handler normalizeHeaders:input];
    
    XCTAssertEqualObjects(result[@"content-type"], @"application/json");
    XCTAssertEqualObjects(result[@"x-ms-aswebauth-handoff-url"], @"https://example.com");
    XCTAssertNil(result[@"Content-Type"]);
}

- (void)testNormalizeHeaders_whenEmptyDictionary_shouldReturnEmptyDictionary
{
    NSDictionary *result = [self.handler normalizeHeaders:@{}];
    XCTAssertEqual(result.count, 0U);
}

#pragma mark - callbackURLScheme tests

- (void)testCallbackURLScheme_whenHeaderAbsent_shouldReturnDefaultMsauth
{
    self.handler.lastResponseHeaders = @{};
    XCTAssertEqualObjects([self.handler callbackURLScheme], MSID_SCHEME_MSAUTH);
}

- (void)testCallbackURLScheme_whenHeaderIsNonString_shouldReturnDefaultMsauth
{
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @42};
    XCTAssertEqualObjects([self.handler callbackURLScheme], MSID_SCHEME_MSAUTH);
}

- (void)testCallbackURLScheme_whenHeaderIsEmptyString_shouldReturnDefaultMsauth
{
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @""};
    XCTAssertEqualObjects([self.handler callbackURLScheme], MSID_SCHEME_MSAUTH);
}

- (void)testCallbackURLScheme_whenHeaderIsWhitespaceOnly_shouldReturnDefaultMsauth
{
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @"   "};
    XCTAssertEqualObjects([self.handler callbackURLScheme], MSID_SCHEME_MSAUTH);
}

- (void)testCallbackURLScheme_whenHeaderHasValidScheme_shouldReturnTrimmedScheme
{
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @"myapp"};
    XCTAssertEqualObjects([self.handler callbackURLScheme], @"myapp");
}

- (void)testCallbackURLScheme_whenHeaderHasPaddedScheme_shouldReturnTrimmedScheme
{
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @"  myapp  "};
    XCTAssertEqualObjects([self.handler callbackURLScheme], @"myapp");
}

#pragma mark - shouldUseEphemeralSession tests

- (void)testShouldUseEphemeralSession_whenHeaderAbsent_shouldReturnYES
{
    self.handler.lastResponseHeaders = @{};
    XCTAssertTrue([self.handler shouldUseEphemeralSession]);
}

- (void)testShouldUseEphemeralSession_whenHeaderIsNonString_shouldReturnYES
{
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY: @42};
    XCTAssertTrue([self.handler shouldUseEphemeralSession]);
}

- (void)testShouldUseEphemeralSession_whenHeaderIsFalse_shouldReturnNO
{
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY: @"false"};
    XCTAssertFalse([self.handler shouldUseEphemeralSession]);
}

- (void)testShouldUseEphemeralSession_whenHeaderIsFalseUppercase_shouldReturnNO
{
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY: @"FALSE"};
    XCTAssertFalse([self.handler shouldUseEphemeralSession]);
}

- (void)testShouldUseEphemeralSession_whenHeaderIsTrue_shouldReturnYES
{
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY: @"true"};
    XCTAssertTrue([self.handler shouldUseEphemeralSession]);
}

#pragma mark - extractAdditionalHeadersToForward tests

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersAbsent_shouldReturnNil
{
    self.handler.lastResponseHeaders = @{};
    XCTAssertNil([self.handler extractAdditionalHeadersToForward]);
}

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersIsFalse_shouldReturnNil
{
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY: @"false"};
    XCTAssertNil([self.handler extractAdditionalHeadersToForward]);
}

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersIsNonString_shouldReturnNil
{
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY: @42};
    XCTAssertNil([self.handler extractAdditionalHeadersToForward]);
}

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersTrueButAttachHeadersMissing_shouldReturnNil
{
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY: @"true"};
    XCTAssertNil([self.handler extractAdditionalHeadersToForward]);
}

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersTrueAndHeaderPresent_shouldReturnHeaders
{
    NSString *customHeader = [NSString stringWithFormat:@"%@custom", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    self.handler.lastResponseHeaders = @{
        MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY: @"true",
        MSID_ASWEBAUTH_HANDOFF_ATTACH_HEADERS_KEY: customHeader,
        customHeader: @"value123"
    };
    
    NSDictionary *result = [self.handler extractAdditionalHeadersToForward];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result[customHeader], @"value123");
}

#pragma mark - buildAdditionalHeadersFromList tests

- (void)testBuildAdditionalHeadersFromList_whenHeaderWithAllowedPrefix_shouldInclude
{
    NSString *headerName = [NSString stringWithFormat:@"%@token", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    self.handler.lastResponseHeaders = @{headerName: @"tokenvalue"};
    
    NSDictionary *result = [self.handler buildAdditionalHeadersFromList:headerName];
    XCTAssertEqualObjects(result[headerName], @"tokenvalue");
}

- (void)testBuildAdditionalHeadersFromList_whenHeaderWithoutAllowedPrefix_shouldExclude
{
    self.handler.lastResponseHeaders = @{@"authorization": @"Bearer token"};
    
    NSDictionary *result = [self.handler buildAdditionalHeadersFromList:@"authorization"];
    XCTAssertEqual(result.count, 0U);
}

- (void)testBuildAdditionalHeadersFromList_whenMultipleHeaders_shouldReturnOnlyPresentAndPrefixed
{
    NSString *validHeader = [NSString stringWithFormat:@"%@valid", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    NSString *missingHeader = [NSString stringWithFormat:@"%@missing", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    self.handler.lastResponseHeaders = @{validHeader: @"val"};
    
    NSString *list = [NSString stringWithFormat:@"%@,%@,authorization", validHeader, missingHeader];
    NSDictionary *result = [self.handler buildAdditionalHeadersFromList:list];
    
    XCTAssertEqualObjects(result[validHeader], @"val");
    XCTAssertNil(result[missingHeader]);
    XCTAssertNil(result[@"authorization"]);
    XCTAssertEqual(result.count, 1U);
}

- (void)testBuildAdditionalHeadersFromList_whenHeaderNameHasSpaces_shouldTrimAndLookup
{
    NSString *headerName = [NSString stringWithFormat:@"%@spaced", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    self.handler.lastResponseHeaders = @{headerName: @"spacedval"};
    
    NSString *list = [NSString stringWithFormat:@"  %@  ", headerName];
    NSDictionary *result = [self.handler buildAdditionalHeadersFromList:list];
    
    XCTAssertEqualObjects(result[headerName], @"spacedval");
    XCTAssertEqual(result.count, 1U);
}

- (void)testBuildAdditionalHeadersFromList_whenHeaderKeyIsMixedCase_shouldNormalizeAndFind
{
    // This end-to-end test verifies that the key-casing contract between normalizeHeaders:
    // and buildAdditionalHeadersFromList: is upheld: normalizeHeaders: lowercases all keys,
    // so the lookup in buildAdditionalHeadersFromList: (which uses lowercaseTrimmed) must
    // still find values stored with any original casing.
    NSString *upperCaseHeader = [[NSString stringWithFormat:@"%@token", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX] uppercaseString];
    NSString *lowerCaseHeader = [upperCaseHeader lowercaseString];
    
    // Simulate what processNavigationResponseAndCheckForASWebAuthHandoff:embeddedWebviewController: does: normalize the raw server headers first
    NSDictionary *rawHeaders = @{upperCaseHeader: @"tok123"};
    NSDictionary *normalised = [self.handler normalizeHeaders:rawHeaders];
    self.handler.lastResponseHeaders = normalised;
    
    // attach-headers names are delivered in their original (uppercase) casing from the server
    NSDictionary *result = [self.handler buildAdditionalHeadersFromList:upperCaseHeader];
    
    // The value should be found regardless of the key casing in attach-headers
    XCTAssertEqualObjects(result[upperCaseHeader], @"tok123");
    XCTAssertEqual(result.count, 1U);
    
    // The normalised dictionary should have stored the value under the lowercased key
    XCTAssertEqualObjects(normalised[lowerCaseHeader], @"tok123");
    XCTAssertNil(normalised[upperCaseHeader]);
}


#pragma mark - configureWebviewController:delegate:

- (void)testConfigureWebviewController_whenWebviewIsNil_shouldBeNoop
{
    // Nil parameter is explicitly allowed by the @c nullable annotation; the handler
    // must skip silently without throwing or asserting.
    XCTAssertNoThrow([self.handler configureWebviewController:nil
                                                    delegate:[MSIDTestNavigationDelegateStub new]]);
}

- (void)testConfigureWebviewController_whenWebviewIsNotEmbeddedKind_shouldNotSetDelegate
{
    // Non-embedded MSIDWebviewInteracting implementors (e.g. Safari / ASWebAuth hosts)
    // must NOT be cast/assigned to. Using the test mock here as a stand-in.
    MSIDTestWebviewInteractingViewController *fakeSafari = [MSIDTestWebviewInteractingViewController new];
    fakeSafari.actAsSafariViewController = YES;

    XCTAssertNoThrow([self.handler configureWebviewController:fakeSafari
                                                    delegate:[MSIDTestNavigationDelegateStub new]]);
    // The mock does not declare a navigationDelegate property; the only contract here
    // is that nothing crashes and the handler does not perform an unsafe cast. The
    // absence of an exception above is the assertion.
}

- (void)testConfigureWebviewController_whenWebviewIsEmbedded_shouldSetNavigationDelegate
{
    MSIDOAuth2EmbeddedWebviewController *embedded =
        [[MSIDOAuth2EmbeddedWebviewController alloc] initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                               endURL:[NSURL URLWithString:@"endurl://host"]
                                                              webview:nil
                                                        customHeaders:nil
                                                       platfromParams:nil
                                                              context:nil];
    MSIDTestNavigationDelegateStub *delegate = [MSIDTestNavigationDelegateStub new];

    [self.handler configureWebviewController:embedded delegate:delegate];

    // navigationDelegate is weak; keep `delegate` alive via the local variable above.
    XCTAssertEqual(embedded.navigationDelegate, delegate);
}

#pragma mark - handleSpecialRedirectURL:embeddedWebviewController:completion:

- (void)testHandleSpecialRedirectURL_whenURLIsNil_shouldCompleteWithFailWithError
{
    // The resolver returns a failWithError decision (not nil) for a nil URL; the
    // handler must propagate that decision and invoke the completion exactly once.
    // Routed through a typed local to suppress the call-site -Wnonnull warning.
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    NSURL *nilURL = nil;

    [self.handler handleSpecialRedirectURL:nilURL
                embeddedWebviewController:nil
                               completion:^(MSIDWebviewNavigationDecision * _Nullable decision, NSError * _Nullable error)
    {
        XCTAssertNotNil(decision);
        XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
        XCTAssertNotNil(decision.error);
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1.0];
}

- (void)testHandleSpecialRedirectURL_whenBrowserScheme_shouldCompleteWithContinueDefault
{
    // browser:// URLs are routed to "continue default" by the resolver; the handler
    // must hand that decision back through completion with a nil error.
    NSURL *URL = [NSURL URLWithString:@"browser://some.host/path"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];

    [self.handler handleSpecialRedirectURL:URL
                embeddedWebviewController:nil
                               completion:^(MSIDWebviewNavigationDecision * _Nullable decision, NSError * _Nullable error)
    {
        XCTAssertNotNil(decision);
        XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionContinueDefault);
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1.0];
}

- (void)testHandleSpecialRedirectURL_whenEmbeddedControllerIsNil_shouldNotCrashAndStillComplete
{
    // The embeddedWebviewController argument is nullable; passing nil must not crash
    // and the completion still has to fire exactly once. Use a benign URL so the
    // resolver path doesn't depend on a real controller.
    NSURL *URL = [NSURL URLWithString:@"browser://some.host"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];

    XCTAssertNoThrow([self.handler handleSpecialRedirectURL:URL
                                 embeddedWebviewController:nil
                                                completion:^(MSIDWebviewNavigationDecision * _Nullable decision, __unused NSError * _Nullable error)
    {
        XCTAssertNotNil(decision);
        [expectation fulfill];
    }]);

    [self waitForExpectations:@[expectation] timeout:1.0];
}

- (void)testHandleSpecialRedirectURL_shouldInvokeCompletionExactlyOnce
{
    // Guard the "completion fires exactly once" contract — accidental double-call
    // would cause downstream completion handlers to be invoked twice with stale state.
    NSURL *URL = [NSURL URLWithString:@"browser://some.host"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    expectation.assertForOverFulfill = YES;

    [self.handler handleSpecialRedirectURL:URL
                embeddedWebviewController:nil
                               completion:^(__unused MSIDWebviewNavigationDecision * _Nullable decision,
                                            __unused NSError * _Nullable error)
    {
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1.0];
}

- (void)testHandleSpecialRedirectURL_whenBrokerVersionProvided_shouldAttachBrokerVersionHeaderOnEnrollRequest
{
    // The four-argument overload must forward the broker version through to the
    // resolver so the MDM enrollment request advertises the x-client-brkrver header.
    NSString *targetURL = @"https://manage.microsoft.com/enroll";
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_MDM_ENROLL_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURL *URL = [NSURL URLWithString:urlString];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];

    [self.handler handleSpecialRedirectURL:URL
                 embeddedWebviewController:nil
                             brokerVersion:@"6.1.2"
                                completion:^(MSIDWebviewNavigationDecision * _Nullable decision, NSError * _Nullable error)
    {
        XCTAssertNotNil(decision);
        XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
        XCTAssertEqualObjects([decision.request valueForHTTPHeaderField:MSID_BROKER_VER_KEY], @"6.1.2");
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1.0];
}

- (void)testHandleSpecialRedirectURL_whenBrokerVersionOmitted_shouldNotAttachBrokerVersionHeaderOnEnrollRequest
{
    // The three-argument variant forwards a nil broker version, so the enrollment
    // request must not carry the x-client-brkrver header.
    NSString *targetURL = @"https://manage.microsoft.com/enroll";
    NSString *encoded = [targetURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"msauth://%@?%@=%@",
                           MSID_MDM_ENROLL_HOST, MSID_INTUNE_URL_KEY, encoded];
    NSURL *URL = [NSURL URLWithString:urlString];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];

    [self.handler handleSpecialRedirectURL:URL
                 embeddedWebviewController:nil
                                completion:^(MSIDWebviewNavigationDecision * _Nullable decision, NSError * _Nullable error)
    {
        XCTAssertNotNil(decision);
        XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionLoadRequest);
        XCTAssertNil([decision.request valueForHTTPHeaderField:MSID_BROKER_VER_KEY]);
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1.0];
}

#pragma mark - processNavigationResponseAndCheckForASWebAuthHandoff:embeddedWebviewController: (synchronous)

// An allowed response URL used by happy-path tests below. Matches an entry in
// MSIDASWebAuthenticationConstants.asWebAuthAllowedDomains so the origin check passes.
static NSURL *MSIDTestAllowedResponseURL(void)
{
    return [NSURL URLWithString:@"https://portal.manage.microsoft.com/some/path"];
}

// Helper to create an NSHTTPURLResponse with given headers and URL.
static NSHTTPURLResponse *MSIDTestHTTPResponse(NSDictionary *headers, NSURL *url)
{
    return [[NSHTTPURLResponse alloc] initWithURL:url
                                      statusCode:200
                                     HTTPVersion:@"HTTP/1.1"
                                    headerFields:headers];
}

- (void)testProcessResponseHeaders_whenNoHandoffHeader_shouldReturnNO
{
    NSDictionary *headers = @{@"Content-Type": @"application/json"};

    NSHTTPURLResponse *response = MSIDTestHTTPResponse(headers, MSIDTestAllowedResponseURL());

    BOOL hasHandoff = [self.handler processNavigationResponseAndCheckForASWebAuthHandoff:response
                                    embeddedWebviewController:nil];

    XCTAssertFalse(hasHandoff);
    // Side effect: headers are still normalized into lastResponseHeaders for later use.
    XCTAssertEqualObjects(self.handler.lastResponseHeaders[@"content-type"], @"application/json");
}

- (void)testProcessResponseHeaders_whenHandoffHeaderIsEmptyString_shouldReturnNO
{
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @""};

    NSHTTPURLResponse *response = MSIDTestHTTPResponse(headers, MSIDTestAllowedResponseURL());

    BOOL hasHandoff = [self.handler processNavigationResponseAndCheckForASWebAuthHandoff:response
                                    embeddedWebviewController:nil];

    XCTAssertFalse(hasHandoff);
}

- (void)testProcessResponseHeaders_whenHandoffHeaderIsMixedCase_shouldStillBeDetected
{
    // Server may send the header in any casing; normalization must catch it.
    NSString *uppercaseKey = MSID_ASWEBAUTH_HANDOFF_URL_KEY.uppercaseString;
    NSDictionary *headers = @{uppercaseKey: @"https://www.example.com/handoff"};

    NSHTTPURLResponse *response = MSIDTestHTTPResponse(headers, MSIDTestAllowedResponseURL());

    BOOL hasHandoff = [self.handler processNavigationResponseAndCheckForASWebAuthHandoff:response
                                    embeddedWebviewController:nil];

    XCTAssertTrue(hasHandoff);
    // The normalized headers should expose the lowercased key for later use.
    XCTAssertEqualObjects(self.handler.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_URL_KEY],
                          @"https://www.example.com/handoff");
}

- (void)testProcessResponseHeaders_alwaysUpdatesLastResponseHeadersToNormalizedForm
{
    self.handler.lastResponseHeaders = @{@"stale": @"value"};

    NSDictionary *headers = @{@"X-Custom": @"v1", @"Other-Header": @"v2"};
    NSHTTPURLResponse *response = MSIDTestHTTPResponse(headers, MSIDTestAllowedResponseURL());

    (void)[self.handler processNavigationResponseAndCheckForASWebAuthHandoff:response
                                    embeddedWebviewController:nil];

    XCTAssertEqualObjects(self.handler.lastResponseHeaders[@"x-custom"], @"v1");
    XCTAssertEqualObjects(self.handler.lastResponseHeaders[@"other-header"], @"v2");
    XCTAssertNil(self.handler.lastResponseHeaders[@"stale"], @"Previous headers must be replaced, not merged.");
}

#pragma mark - processNavigationResponseAndCheckForASWebAuthHandoff:embeddedWebviewController: (response-URL origin gate)

- (void)testProcessResponseHeaders_whenHandoffHeaderPresentButResponseURLIsInvalid_shouldReturnNOAndStillCacheHeaders
{
    // Security gate: an attacker-controlled page (or a non-HTTP response somehow reaching here)
    // must not be able to force a hand-off by injecting only the header. Use a syntactically valid
    // but non-HTTPS origin (about:blank) so the origin gate — not URL construction — is exercised.
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};

    NSHTTPURLResponse *response = MSIDTestHTTPResponse(headers, [NSURL URLWithString:@"about:blank"]);

    BOOL hasHandoff = [self.handler processNavigationResponseAndCheckForASWebAuthHandoff:response
                                    embeddedWebviewController:nil];

    XCTAssertFalse(hasHandoff);
    // Headers are still cached so downstream consumers see consistent state.
    XCTAssertEqualObjects(self.handler.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_URL_KEY],
                          @"https://portal.manage.microsoft.com/handoff");
}

- (void)testProcessResponseHeaders_whenHandoffHeaderPresentButResponseURLIsHTTP_shouldReturnNO
{
    // HTTP origin must never be allowed as a hand-off issuer, even if the host itself is on the allowlist.
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};
    NSURL *httpResponseURL = [NSURL URLWithString:@"http://portal.manage.microsoft.com/some/path"];

    NSHTTPURLResponse *response = MSIDTestHTTPResponse(headers, httpResponseURL);

    BOOL hasHandoff = [self.handler processNavigationResponseAndCheckForASWebAuthHandoff:response
                                    embeddedWebviewController:nil];

    XCTAssertFalse(hasHandoff);
}

- (void)testProcessResponseHeaders_whenHandoffHeaderPresentButResponseURLHostNotAllowlisted_shouldReturnNO
{
    // Classic attacker scenario: a malicious page injects the hand-off header pointing at a real Microsoft URL.
    // Because the page itself is not served from an allowlisted host, the hand-off must be refused.
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};
    NSURL *attackerOrigin = [NSURL URLWithString:@"https://evil.example.com/landing"];

    NSHTTPURLResponse *response = MSIDTestHTTPResponse(headers, attackerOrigin);

    BOOL hasHandoff = [self.handler processNavigationResponseAndCheckForASWebAuthHandoff:response
                                    embeddedWebviewController:nil];

    XCTAssertFalse(hasHandoff);
}

- (void)testProcessResponseHeaders_whenHandoffHeaderPresentButResponseURLLooksLikeAllowedAsSubdomain_shouldReturnNO
{
    // Defense against suffix-style spoofing — `portal.manage.microsoft.com.attacker.com` must NOT be allowed.
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};
    NSURL *spoofedOrigin = [NSURL URLWithString:@"https://portal.manage.microsoft.com.attacker.com/path"];

    NSHTTPURLResponse *response = MSIDTestHTTPResponse(headers, spoofedOrigin);

    BOOL hasHandoff = [self.handler processNavigationResponseAndCheckForASWebAuthHandoff:response
                                    embeddedWebviewController:nil];

    XCTAssertFalse(hasHandoff);
}

- (void)testProcessResponseHeaders_whenHandoffHeaderPresentAndResponseURLIsAllowed_shouldReturnYES
{
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};

    NSHTTPURLResponse *response = MSIDTestHTTPResponse(headers, MSIDTestAllowedResponseURL());

    BOOL hasHandoff = [self.handler processNavigationResponseAndCheckForASWebAuthHandoff:response
                                    embeddedWebviewController:nil];

    XCTAssertTrue(hasHandoff);
}

- (void)testProcessResponseHeaders_whenHandoffHeaderPresentAndResponseURLHostIsUppercased_shouldStillBeAllowed
{
    // Hosts are case-insensitive in DNS; the allowlist check must lowercase the host before matching.
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};
    NSURL *mixedCaseOrigin = [NSURL URLWithString:@"https://PORTAL.MANAGE.microsoft.com/path"];

    NSHTTPURLResponse *response = MSIDTestHTTPResponse(headers, mixedCaseOrigin);

    BOOL hasHandoff = [self.handler processNavigationResponseAndCheckForASWebAuthHandoff:response
                                    embeddedWebviewController:nil];

    XCTAssertTrue(hasHandoff);
}

#if !MSID_EXCLUDE_SYSTEMWV

#pragma mark - performASWebAuthenticationHandoffWithParentController:completion:

- (void)testPerformASWebAuthHandoff_whenCompletionIsNil_shouldNotCrash
{
    // Nil completion should be handled defensively (early return, no crash).
    // Routed through a typed local to suppress the call-site -Wnonnull warning.
    MSIDViewController *parent = [MSIDViewController new];
    void (^nilCompletion)(MSIDWebviewNavigationDecision * _Nullable, NSError * _Nullable) = nil;
    XCTAssertNoThrow([self.handler performASWebAuthenticationHandoffWithParentController:parent
                                                                             completion:nilCompletion]);
}

- (void)testPerformASWebAuthHandoff_whenNoHandoffURLCaptured_shouldCompleteWithFailWithError
{
    // No prior processNavigationResponseAndCheckForASWebAuthHandoff:embeddedWebviewController: call captured a hand-off URL.
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    MSIDViewController *parent = [MSIDViewController new];

    [self.handler performASWebAuthenticationHandoffWithParentController:parent
                                                            completion:^(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                         NSError * _Nullable error)
    {
        XCTAssertNotNil(decision);
        XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
        XCTAssertNotNil(decision.error);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error, decision.error);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1.0];
}

- (void)testPerformASWebAuthHandoff_whenHandoffURLFailsValidation_shouldCompleteWithFailWithError
{
    // Capture a hand-off URL whose domain is not in the allowlist so validation
    // short-circuits before reaching the system webview transition manager.
    // Bypass the processNavigationResponseAndCheckForASWebAuthHandoff:embeddedWebviewController: origin gate by
    // populating lastResponseHeaders directly — this test isolates the perform-side validation.
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://www.example.com/handoff"};

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    MSIDViewController *parent = [MSIDViewController new];

    [self.handler performASWebAuthenticationHandoffWithParentController:parent
                                                            completion:^(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                         NSError * _Nullable error)
    {
        XCTAssertNotNil(decision);
        XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
        XCTAssertNotNil(decision.error);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error, decision.error);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1.0];
}

#pragma mark - scheduleMDMProfileInstalledNotificationIfNeeded

- (void)testScheduleMDMProfileInstalledNotification_whenPurposeIsDownloadProfileAndProviderSet_shouldScheduleWithDefaultDelay
{
    MSIDMockUXCallbackProvider *mockProvider = [MSIDMockUXCallbackProvider new];
    MSIDUXCallbackProvider.uxCallbackProvider = mockProvider;

    self.handler.lastResponseHeaders = @{ MSID_ASWEBAUTH_HANDOFF_PURPOSE_KEY: MSID_ASWEBAUTH_HANDOFF_PURPOSE_VALUE_DOWNLOAD_PROFILE };

    [self.handler scheduleMDMProfileInstalledNotificationIfNeeded];

    XCTAssertTrue(mockProvider.scheduleCalled, @"Notification should be scheduled for the profile-download hand-off.");
    XCTAssertEqualWithAccuracy(mockProvider.receivedDelay, MSIDMDMProfileInstalledNotificationDefaultDelay, 0.01);
}

- (void)testScheduleMDMProfileInstalledNotification_whenFlightConfiguresDelay_shouldPassFlightDelay
{
    MSIDMockUXCallbackProvider *mockProvider = [MSIDMockUXCallbackProvider new];
    MSIDUXCallbackProvider.uxCallbackProvider = mockProvider;

    self.flightProvider.stringForKeyContainer = @{ MSID_FLIGHT_MDM_PROFILE_INSTALLED_NOTIFICATION_DELAY: @"5" };

    self.handler.lastResponseHeaders = @{ MSID_ASWEBAUTH_HANDOFF_PURPOSE_KEY: MSID_ASWEBAUTH_HANDOFF_PURPOSE_VALUE_DOWNLOAD_PROFILE };

    [self.handler scheduleMDMProfileInstalledNotificationIfNeeded];

    XCTAssertTrue(mockProvider.scheduleCalled);
    XCTAssertEqualWithAccuracy(mockProvider.receivedDelay, 5.0, 0.01);
}

- (void)testScheduleMDMProfileInstalledNotification_whenFlightDelayIsNegative_shouldFallbackToDefault
{
    MSIDMockUXCallbackProvider *mockProvider = [MSIDMockUXCallbackProvider new];
    MSIDUXCallbackProvider.uxCallbackProvider = mockProvider;

    self.flightProvider.stringForKeyContainer = @{ MSID_FLIGHT_MDM_PROFILE_INSTALLED_NOTIFICATION_DELAY: @"-5" };

    self.handler.lastResponseHeaders = @{ MSID_ASWEBAUTH_HANDOFF_PURPOSE_KEY: MSID_ASWEBAUTH_HANDOFF_PURPOSE_VALUE_DOWNLOAD_PROFILE };

    [self.handler scheduleMDMProfileInstalledNotificationIfNeeded];

    XCTAssertTrue(mockProvider.scheduleCalled);
    XCTAssertEqualWithAccuracy(mockProvider.receivedDelay, MSIDMDMProfileInstalledNotificationDefaultDelay, 0.01);
}

- (void)testScheduleMDMProfileInstalledNotification_whenPurposeHasDifferentCase_shouldSchedule
{
    MSIDMockUXCallbackProvider *mockProvider = [MSIDMockUXCallbackProvider new];
    MSIDUXCallbackProvider.uxCallbackProvider = mockProvider;

    self.handler.lastResponseHeaders = @{ MSID_ASWEBAUTH_HANDOFF_PURPOSE_KEY: @"Download-Profile" };

    [self.handler scheduleMDMProfileInstalledNotificationIfNeeded];

    XCTAssertTrue(mockProvider.scheduleCalled, @"Match on the purpose value should be case-insensitive.");
}

- (void)testScheduleMDMProfileInstalledNotification_whenPurposeIsDifferentValue_shouldNotSchedule
{
    MSIDMockUXCallbackProvider *mockProvider = [MSIDMockUXCallbackProvider new];
    MSIDUXCallbackProvider.uxCallbackProvider = mockProvider;

    self.handler.lastResponseHeaders = @{ MSID_ASWEBAUTH_HANDOFF_PURPOSE_KEY: @"sign-in" };

    [self.handler scheduleMDMProfileInstalledNotificationIfNeeded];

    XCTAssertFalse(mockProvider.scheduleCalled, @"Notification must not be scheduled for a non profile-download purpose.");
}

- (void)testScheduleMDMProfileInstalledNotification_whenPurposeHeaderAbsent_shouldNotSchedule
{
    MSIDMockUXCallbackProvider *mockProvider = [MSIDMockUXCallbackProvider new];
    MSIDUXCallbackProvider.uxCallbackProvider = mockProvider;

    self.handler.lastResponseHeaders = @{};

    [self.handler scheduleMDMProfileInstalledNotificationIfNeeded];

    XCTAssertFalse(mockProvider.scheduleCalled, @"With no purpose header (no fallback), the notification must not be scheduled.");
}

- (void)testScheduleMDMProfileInstalledNotification_whenProviderIsNil_shouldNotCrash
{
    MSIDUXCallbackProvider.uxCallbackProvider = nil;

    self.handler.lastResponseHeaders = @{ MSID_ASWEBAUTH_HANDOFF_PURPOSE_KEY: MSID_ASWEBAUTH_HANDOFF_PURPOSE_VALUE_DOWNLOAD_PROFILE };

    XCTAssertNoThrow([self.handler scheduleMDMProfileInstalledNotificationIfNeeded]);
}

#pragma mark - performASWebAuthenticationHandoff onboarding telemetry

// Finalizes the given builder and returns the ordered list of stamped step_id values.
- (NSArray<NSString *> *)stampedStepIdsFromBuilder:(MSIDOnboardingBlobBuilder *)builder
{
    NSData *data = [[builder finalizeBlob] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSMutableArray<NSString *> *stepIds = [NSMutableArray new];
    for (NSDictionary *step in parsed[@"steps_list"])
    {
        [stepIds addObject:step[@"step_id"]];
    }
    return stepIds;
}

- (MSIDOnboardingBlobBuilder *)onboardingBuilderForHandoffTest
{
    NSDictionary *seed = @{@"schema_version": @"1.0.0", @"session_correlation_id": @"abc-123", @"onboarding_mode": @"non-brokered"};
    NSString *seedJson = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:seed options:0 error:nil]
                                               encoding:NSUTF8StringEncoding];
    return [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"clientA" target:@"resource1"];
}

- (void)testPerformASWebAuthHandoff_whenBuilderPresent_shouldStampSessionStarted
{
    MSIDOnboardingBlobBuilder *builder = [self onboardingBuilderForHandoffTest];
    self.handler.onboardingBlobBuilder = builder;

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    MSIDViewController *parent = [MSIDViewController new];
    [self.handler performASWebAuthenticationHandoffWithParentController:parent
                                                            completion:^(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                         NSError * _Nullable error)
    {
        (void)decision; (void)error;
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1.0];

    XCTAssertTrue([[self stampedStepIdsFromBuilder:builder] containsObject:MSIDOnboardingBlobStepProfileDownloadFlowStarted]);
}

- (void)testPerformASWebAuthHandoff_whenNoHandoffURLCaptured_shouldStampSessionStartFailedNotCompleted
{
    MSIDOnboardingBlobBuilder *builder = [self onboardingBuilderForHandoffTest];
    self.handler.onboardingBlobBuilder = builder;

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    MSIDViewController *parent = [MSIDViewController new];
    [self.handler performASWebAuthenticationHandoffWithParentController:parent
                                                            completion:^(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                         NSError * _Nullable error)
    {
        (void)decision; (void)error;
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1.0];

    NSArray<NSString *> *steps = [self stampedStepIdsFromBuilder:builder];
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepProfileDownloadFlowStarted]);
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepProfileDownloadFlowFailed]);
}

- (void)testPerformASWebAuthHandoff_whenHandoffURLFailsValidation_shouldStampSessionStartFailedNotCompleted
{
    MSIDOnboardingBlobBuilder *builder = [self onboardingBuilderForHandoffTest];
    self.handler.onboardingBlobBuilder = builder;
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://www.example.com/handoff"};

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    MSIDViewController *parent = [MSIDViewController new];
    [self.handler performASWebAuthenticationHandoffWithParentController:parent
                                                            completion:^(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                         NSError * _Nullable error)
    {
        (void)decision; (void)error;
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1.0];

    NSArray<NSString *> *steps = [self stampedStepIdsFromBuilder:builder];
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepProfileDownloadFlowFailed]);
}

// Swizzles the ASWeb transition so it completes synchronously with the injected
// (callbackURL, error), exercising the hand-off outcome classification without
// launching a real ASWebAuthenticationSession.
- (void)swizzleTransitionWithCallbackURL:(NSURL *)callbackURL error:(NSError *)error
{
    [MSIDTestSwizzle instanceMethod:@selector(transitionToSystemWebviewWithURL:redirectURI:parentController:useAuthenticationSession:allowSafariViewController:useEphemeralSession:additionalHeaders:context:completionBlock:)
                              class:[MSIDSystemWebviewTransitionManager class]
                              block:(id)^(__unused id obj,
                                         __unused NSURL *URL,
                                         __unused NSString *redirectURI,
                                         __unused MSIDViewController *parentController,
                                         __unused BOOL useAuthenticationSession,
                                         __unused BOOL allowSafariViewController,
                                         __unused BOOL useEphemeralSession,
                                         __unused NSDictionary *additionalHeaders,
                                         __unused id context,
                                         MSIDWebUICompletionHandler completionBlock)
    {
        if (completionBlock)
        {
            completionBlock(callbackURL, error);
        }
    }];
}

- (void)testPerformASWebAuthHandoff_whenTransitionCancelledByUser_shouldStampCancelledNotFailed
{
    MSIDOnboardingBlobBuilder *builder = [self onboardingBuilderForHandoffTest];
    self.handler.onboardingBlobBuilder = builder;
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};

    NSError *cancelError = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"User cancelled", nil, nil, nil, nil, nil, NO);
    [self swizzleTransitionWithCallbackURL:nil error:cancelError];

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    MSIDViewController *parent = [MSIDViewController new];
    [self.handler performASWebAuthenticationHandoffWithParentController:parent
                                                            completion:^(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                         NSError * _Nullable error)
    {
        (void)decision; (void)error;
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1.0];

    NSArray<NSString *> *steps = [self stampedStepIdsFromBuilder:builder];
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepProfileDownloadFlowCancelled]);
    XCTAssertFalse([steps containsObject:MSIDOnboardingBlobStepProfileDownloadFlowFailed]);
}

- (void)testPerformASWebAuthHandoff_whenTransitionFailsWithNonCancelError_shouldStampFailedNotCancelled
{
    MSIDOnboardingBlobBuilder *builder = [self onboardingBuilderForHandoffTest];
    self.handler.onboardingBlobBuilder = builder;
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};

    NSError *serverError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidResponse, @"Server error", nil, nil, nil, nil, nil, NO);
    [self swizzleTransitionWithCallbackURL:nil error:serverError];

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    MSIDViewController *parent = [MSIDViewController new];
    [self.handler performASWebAuthenticationHandoffWithParentController:parent
                                                            completion:^(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                         NSError * _Nullable error)
    {
        (void)decision; (void)error;
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1.0];

    NSArray<NSString *> *steps = [self stampedStepIdsFromBuilder:builder];
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepProfileDownloadFlowFailed]);
    XCTAssertFalse([steps containsObject:MSIDOnboardingBlobStepProfileDownloadFlowCancelled]);
}

- (void)testPerformASWebAuthHandoff_whenCancelCodeFromForeignDomain_shouldStampFailedNotCancelled
{
    MSIDOnboardingBlobBuilder *builder = [self onboardingBuilderForHandoffTest];
    self.handler.onboardingBlobBuilder = builder;
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};

    // Same numeric code as MSIDErrorUserCancel but from a foreign domain: the domain
    // guard must classify this as Failed, not Cancelled.
    NSError *foreignError = [NSError errorWithDomain:@"SomeOtherDomain" code:MSIDErrorUserCancel userInfo:nil];
    [self swizzleTransitionWithCallbackURL:nil error:foreignError];

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    MSIDViewController *parent = [MSIDViewController new];
    [self.handler performASWebAuthenticationHandoffWithParentController:parent
                                                            completion:^(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                         NSError * _Nullable error)
    {
        (void)decision; (void)error;
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1.0];

    NSArray<NSString *> *steps = [self stampedStepIdsFromBuilder:builder];
    XCTAssertTrue([steps containsObject:MSIDOnboardingBlobStepProfileDownloadFlowFailed]);
    XCTAssertFalse([steps containsObject:MSIDOnboardingBlobStepProfileDownloadFlowCancelled]);
}

- (void)testPerformASWebAuthHandoff_whenNoBuilder_shouldNotCrash
{
    self.handler.onboardingBlobBuilder = nil;

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    MSIDViewController *parent = [MSIDViewController new];
    XCTAssertNoThrow([self.handler performASWebAuthenticationHandoffWithParentController:parent
                                                                            completion:^(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                                         NSError * _Nullable error)
    {
        (void)decision; (void)error;
        [expectation fulfill];
    }]);
    [self waitForExpectations:@[expectation] timeout:1.0];
}

- (void)testPerformASWebAuthHandoff_whenHandoffHeaderIsNonString_shouldFailWithoutHandoff
{
    MSIDOnboardingBlobBuilder *builder = [self onboardingBuilderForHandoffTest];
    self.handler.onboardingBlobBuilder = builder;
    // Non-string handoff header value: the isKindOfClass:NSString guard must reject it
    // so the flow fails cleanly instead of misinterpreting it as a valid hand-off URL.
    self.handler.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @42};

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    MSIDViewController *parent = [MSIDViewController new];
    __block MSIDWebviewNavigationDecision *capturedDecision = nil;
    __block NSError *capturedError = nil;
    [self.handler performASWebAuthenticationHandoffWithParentController:parent
                                                            completion:^(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                         NSError * _Nullable error)
    {
        capturedDecision = decision;
        capturedError = error;
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1.0];

    XCTAssertNotNil(capturedError);
    XCTAssertEqualObjects(capturedError.domain, MSIDErrorDomain);
    XCTAssertEqual(capturedError.code, MSIDErrorInternal);
    XCTAssertNotNil(capturedDecision);

    NSArray<NSString *> *steps = [self stampedStepIdsFromBuilder:builder];
    XCTAssertFalse([steps containsObject:MSIDOnboardingBlobStepProfileDownloadFlowCancelled]);
}

#endif // !MSID_EXCLUDE_SYSTEMWV

@end

#endif
