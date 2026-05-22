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
#import "MSIDWebviewNavigationDelegateHelper.h"
#import "MSIDWebviewNavigationDecision.h"
#import "MSIDWebviewConstants.h"
#import "MSIDError.h"
#import "MSIDTestContext.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDTestWebviewInteractingViewController.h"
#import "MSIDWebviewNavigationDelegate.h"

// Stub conforming to MSIDWebviewNavigationDelegate for delegate-wiring assertions.
@interface MSIDTestNavigationDelegateStub : NSObject <MSIDWebviewNavigationDelegate>
@end

@implementation MSIDTestNavigationDelegateStub
@end

// Expose private methods and properties for testing
@interface MSIDWebviewNavigationDelegateHelper (Testing)

// Expose private methods and properties for testing.
@property (nonatomic) NSDictionary *lastResponseHeaders;

- (BOOL)isValidHandoffURL:(NSURL *)url error:(NSError *__autoreleasing *)error;
- (BOOL)isURLInAllowedDomains:(NSURL *)url;
- (NSDictionary<NSString *, id> *)normalizeHeaders:(NSDictionary *)headers;
- (NSString *)callbackURLScheme;
- (BOOL)shouldUseEphemeralSession;
- (nullable NSDictionary<NSString *, NSString *> *)extractAdditionalHeadersToForward;
- (NSDictionary<NSString *, NSString *> *)buildAdditionalHeadersFromList:(NSString *)attachHeadersList;

@end

@interface MSIDWebviewNavigationDelegateHelperTests : XCTestCase

@property (nonatomic) MSIDWebviewNavigationDelegateHelper *helper;
@property (nonatomic) MSIDTestContext *context;

@end

@implementation MSIDWebviewNavigationDelegateHelperTests

- (void)setUp
{
    [super setUp];
    self.context = [MSIDTestContext new];
    self.helper = [[MSIDWebviewNavigationDelegateHelper alloc] initWithContext:self.context];
}

- (void)tearDown
{
    self.helper = nil;
    self.context = nil;
    [super tearDown];
}

#pragma mark - isValidHandoffURL tests

- (void)testIsValidHandoffURL_whenURLIsNil_shouldReturnNO
{
    NSError *error = nil;
    BOOL result = [self.helper isValidHandoffURL:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidASWebAuthenticationURL);
}

- (void)testIsValidHandoffURL_whenURLHasNoScheme_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"//login.microsoftonline.com/path"];
    NSError *error = nil;
    BOOL result = [self.helper isValidHandoffURL:url error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidASWebAuthenticationURL);
}

- (void)testIsValidHandoffURL_whenURLIsHTTP_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"http://portal.manage.microsoft.com/path"];
    NSError *error = nil;
    BOOL result = [self.helper isValidHandoffURL:url error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidASWebAuthenticationURL);
}

- (void)testIsValidHandoffURL_whenURLHasNonAllowedDomain_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://evil.example.com/path"];
    NSError *error = nil;
    BOOL result = [self.helper isValidHandoffURL:url error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidASWebAuthenticationURL);
}

- (void)testIsValidHandoffURL_whenURLIsValidHTTPSAndAllowedDomain_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage.microsoft.com/path"];
    NSError *error = nil;
    BOOL result = [self.helper isValidHandoffURL:url error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testIsValidHandoffURL_whenURLSchemeIsUppercase_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"HTTPS://portal.manage.microsoft.com/path"];
    NSError *error = nil;
    BOOL result = [self.helper isValidHandoffURL:url error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

#pragma mark - isURLInAllowedDomains tests

- (void)testIsURLInAllowedDomains_whenURLIsNil_shouldReturnNO
{
    XCTAssertFalse([self.helper isURLInAllowedDomains:nil]);
}

- (void)testIsURLInAllowedDomains_whenHostIsNil_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://"];
    XCTAssertFalse([self.helper isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenDomainIsAllowed_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage.microsoft.com/path"];
    XCTAssertTrue([self.helper isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenDomainIsNotAllowed_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://attacker.example.com/path"];
    XCTAssertFalse([self.helper isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenDomainIsAllowedDogfood_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage-dogfood.microsoft.com/path"];
    XCTAssertTrue([self.helper isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenAllowedDomainIsSubdomainOfAttackerDomain_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage.microsoft.com.attacker.com/path"];
    XCTAssertFalse([self.helper isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenAttackerControlledSubdomainUsesAllowedDomainSuffix_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://evil.portal.manage.microsoft.com/path"];
    XCTAssertFalse([self.helper isURLInAllowedDomains:url]);
}


#pragma mark - normalizeHeaders tests

- (void)testNormalizeHeaders_whenMixedCaseKeys_shouldLowercaseAllKeys
{
    NSDictionary *input = @{@"Content-Type": @"application/json",
                            @"X-MS-ASWEBAUTH-HANDOFF-URL": @"https://example.com"};
    NSDictionary *result = [self.helper normalizeHeaders:input];
    
    XCTAssertEqualObjects(result[@"content-type"], @"application/json");
    XCTAssertEqualObjects(result[@"x-ms-aswebauth-handoff-url"], @"https://example.com");
    XCTAssertNil(result[@"Content-Type"]);
}

- (void)testNormalizeHeaders_whenEmptyDictionary_shouldReturnEmptyDictionary
{
    NSDictionary *result = [self.helper normalizeHeaders:@{}];
    XCTAssertEqual(result.count, 0U);
}

#pragma mark - callbackURLScheme tests

- (void)testCallbackURLScheme_whenHeaderAbsent_shouldReturnDefaultMsauth
{
    self.helper.lastResponseHeaders = @{};
    XCTAssertEqualObjects([self.helper callbackURLScheme], MSID_SCHEME_MSAUTH);
}

- (void)testCallbackURLScheme_whenHeaderIsNonString_shouldReturnDefaultMsauth
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @42};
    XCTAssertEqualObjects([self.helper callbackURLScheme], MSID_SCHEME_MSAUTH);
}

- (void)testCallbackURLScheme_whenHeaderIsEmptyString_shouldReturnDefaultMsauth
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @""};
    XCTAssertEqualObjects([self.helper callbackURLScheme], MSID_SCHEME_MSAUTH);
}

- (void)testCallbackURLScheme_whenHeaderIsWhitespaceOnly_shouldReturnDefaultMsauth
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @"   "};
    XCTAssertEqualObjects([self.helper callbackURLScheme], MSID_SCHEME_MSAUTH);
}

- (void)testCallbackURLScheme_whenHeaderHasValidScheme_shouldReturnTrimmedScheme
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @"myapp"};
    XCTAssertEqualObjects([self.helper callbackURLScheme], @"myapp");
}

- (void)testCallbackURLScheme_whenHeaderHasPaddedScheme_shouldReturnTrimmedScheme
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @"  myapp  "};
    XCTAssertEqualObjects([self.helper callbackURLScheme], @"myapp");
}

#pragma mark - shouldUseEphemeralSession tests

- (void)testShouldUseEphemeralSession_whenHeaderAbsent_shouldReturnYES
{
    self.helper.lastResponseHeaders = @{};
    XCTAssertTrue([self.helper shouldUseEphemeralSession]);
}

- (void)testShouldUseEphemeralSession_whenHeaderIsNonString_shouldReturnYES
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY: @42};
    XCTAssertTrue([self.helper shouldUseEphemeralSession]);
}

- (void)testShouldUseEphemeralSession_whenHeaderIsFalse_shouldReturnNO
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY: @"false"};
    XCTAssertFalse([self.helper shouldUseEphemeralSession]);
}

- (void)testShouldUseEphemeralSession_whenHeaderIsFalseUppercase_shouldReturnNO
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY: @"FALSE"};
    XCTAssertFalse([self.helper shouldUseEphemeralSession]);
}

- (void)testShouldUseEphemeralSession_whenHeaderIsTrue_shouldReturnYES
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY: @"true"};
    XCTAssertTrue([self.helper shouldUseEphemeralSession]);
}

#pragma mark - extractAdditionalHeadersToForward tests

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersAbsent_shouldReturnNil
{
    self.helper.lastResponseHeaders = @{};
    XCTAssertNil([self.helper extractAdditionalHeadersToForward]);
}

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersIsFalse_shouldReturnNil
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY: @"false"};
    XCTAssertNil([self.helper extractAdditionalHeadersToForward]);
}

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersIsNonString_shouldReturnNil
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY: @42};
    XCTAssertNil([self.helper extractAdditionalHeadersToForward]);
}

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersTrueButAttachHeadersMissing_shouldReturnNil
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY: @"true"};
    XCTAssertNil([self.helper extractAdditionalHeadersToForward]);
}

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersTrueAndHeaderPresent_shouldReturnHeaders
{
    NSString *customHeader = [NSString stringWithFormat:@"%@custom", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    self.helper.lastResponseHeaders = @{
        MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY: @"true",
        MSID_ASWEBAUTH_HANDOFF_ATTACH_HEADERS_KEY: customHeader,
        customHeader: @"value123"
    };
    
    NSDictionary *result = [self.helper extractAdditionalHeadersToForward];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result[customHeader], @"value123");
}

#pragma mark - buildAdditionalHeadersFromList tests

- (void)testBuildAdditionalHeadersFromList_whenHeaderWithAllowedPrefix_shouldInclude
{
    NSString *headerName = [NSString stringWithFormat:@"%@token", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    self.helper.lastResponseHeaders = @{headerName: @"tokenvalue"};
    
    NSDictionary *result = [self.helper buildAdditionalHeadersFromList:headerName];
    XCTAssertEqualObjects(result[headerName], @"tokenvalue");
}

- (void)testBuildAdditionalHeadersFromList_whenHeaderWithoutAllowedPrefix_shouldExclude
{
    self.helper.lastResponseHeaders = @{@"authorization": @"Bearer token"};
    
    NSDictionary *result = [self.helper buildAdditionalHeadersFromList:@"authorization"];
    XCTAssertEqual(result.count, 0U);
}

- (void)testBuildAdditionalHeadersFromList_whenMultipleHeaders_shouldReturnOnlyPresentAndPrefixed
{
    NSString *validHeader = [NSString stringWithFormat:@"%@valid", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    NSString *missingHeader = [NSString stringWithFormat:@"%@missing", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    self.helper.lastResponseHeaders = @{validHeader: @"val"};
    
    NSString *list = [NSString stringWithFormat:@"%@,%@,authorization", validHeader, missingHeader];
    NSDictionary *result = [self.helper buildAdditionalHeadersFromList:list];
    
    XCTAssertEqualObjects(result[validHeader], @"val");
    XCTAssertNil(result[missingHeader]);
    XCTAssertNil(result[@"authorization"]);
    XCTAssertEqual(result.count, 1U);
}

- (void)testBuildAdditionalHeadersFromList_whenHeaderNameHasSpaces_shouldTrimAndLookup
{
    NSString *headerName = [NSString stringWithFormat:@"%@spaced", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    self.helper.lastResponseHeaders = @{headerName: @"spacedval"};
    
    NSString *list = [NSString stringWithFormat:@"  %@  ", headerName];
    NSDictionary *result = [self.helper buildAdditionalHeadersFromList:list];
    
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
    
    // Simulate what processResponseHeadersAndCheckForASWebAuthHandoff:responseURL: does: normalize the raw server headers first
    NSDictionary *rawHeaders = @{upperCaseHeader: @"tok123"};
    NSDictionary *normalised = [self.helper normalizeHeaders:rawHeaders];
    self.helper.lastResponseHeaders = normalised;
    
    // attach-headers names are delivered in their original (uppercase) casing from the server
    NSDictionary *result = [self.helper buildAdditionalHeadersFromList:upperCaseHeader];
    
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
    // Nil parameter is explicitly allowed by the @c nullable annotation; the helper
    // must skip silently without throwing or asserting.
    XCTAssertNoThrow([self.helper configureWebviewController:nil
                                                    delegate:[MSIDTestNavigationDelegateStub new]]);
}

- (void)testConfigureWebviewController_whenWebviewIsNotEmbeddedKind_shouldNotSetDelegate
{
    // Non-embedded MSIDWebviewInteracting implementors (e.g. Safari / ASWebAuth hosts)
    // must NOT be cast/assigned to. Using the test mock here as a stand-in.
    MSIDTestWebviewInteractingViewController *fakeSafari = [MSIDTestWebviewInteractingViewController new];
    fakeSafari.actAsSafariViewController = YES;

    XCTAssertNoThrow([self.helper configureWebviewController:fakeSafari
                                                    delegate:[MSIDTestNavigationDelegateStub new]]);
    // The mock does not declare a navigationDelegate property; the only contract here
    // is that nothing crashes and the helper does not perform an unsafe cast. The
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

    [self.helper configureWebviewController:embedded delegate:delegate];

    // navigationDelegate is weak; keep `delegate` alive via the local variable above.
    XCTAssertEqual(embedded.navigationDelegate, delegate);
}

#pragma mark - handleSpecialRedirectURL:embeddedWebviewController:appName:appVersion:completion:

- (void)testHandleSpecialRedirectURL_whenURLIsNil_shouldCompleteWithFailWithError
{
    // The resolver returns a failWithError decision (not nil) for a nil URL; the
    // helper must propagate that decision and invoke the completion exactly once.
    // Routed through a typed local to suppress the call-site -Wnonnull warning.
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    NSURL *nilURL = nil;

    [self.helper handleSpecialRedirectURL:nilURL
                embeddedWebviewController:nil
                                  appName:@"App"
                               appVersion:@"1.0"
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
    // browser:// URLs are routed to "continue default" by the resolver; the helper
    // must hand that decision back through completion with a nil error.
    NSURL *URL = [NSURL URLWithString:@"browser://some.host/path"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];

    [self.helper handleSpecialRedirectURL:URL
                embeddedWebviewController:nil
                                  appName:@"App"
                               appVersion:@"1.0"
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

    XCTAssertNoThrow([self.helper handleSpecialRedirectURL:URL
                                 embeddedWebviewController:nil
                                                   appName:@"App"
                                                appVersion:@"1.0"
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

    [self.helper handleSpecialRedirectURL:URL
                embeddedWebviewController:nil
                                  appName:@"App"
                               appVersion:@"1.0"
                               completion:^(__unused MSIDWebviewNavigationDecision * _Nullable decision,
                                            __unused NSError * _Nullable error)
    {
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1.0];
}

#pragma mark - processResponseHeadersAndCheckForASWebAuthHandoff:responseURL: (synchronous)

// An allowed response URL used by happy-path tests below. Matches an entry in
// MSIDASWebAuthenticationConstants.asWebAuthAllowedDomains so the origin check passes.
static NSURL *MSIDTestAllowedResponseURL(void)
{
    return [NSURL URLWithString:@"https://portal.manage.microsoft.com/some/path"];
}

- (void)testProcessResponseHeaders_whenNoHandoffHeader_shouldReturnNO
{
    NSDictionary *headers = @{@"Content-Type": @"application/json"};

    BOOL hasHandoff = [self.helper processResponseHeadersAndCheckForASWebAuthHandoff:headers
                                                                         responseURL:MSIDTestAllowedResponseURL()];

    XCTAssertFalse(hasHandoff);
    // Side effect: headers are still normalized into lastResponseHeaders for later use.
    XCTAssertEqualObjects(self.helper.lastResponseHeaders[@"content-type"], @"application/json");
}

- (void)testProcessResponseHeaders_whenHandoffHeaderIsEmptyString_shouldReturnNO
{
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @""};

    BOOL hasHandoff = [self.helper processResponseHeadersAndCheckForASWebAuthHandoff:headers
                                                                         responseURL:MSIDTestAllowedResponseURL()];

    XCTAssertFalse(hasHandoff);
}

- (void)testProcessResponseHeaders_whenHandoffHeaderIsNonString_shouldReturnNO
{
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @42};

    BOOL hasHandoff = [self.helper processResponseHeadersAndCheckForASWebAuthHandoff:headers
                                                                         responseURL:MSIDTestAllowedResponseURL()];

    XCTAssertFalse(hasHandoff);
}

- (void)testProcessResponseHeaders_whenHandoffHeaderIsMixedCase_shouldStillBeDetected
{
    // Server may send the header in any casing; normalization must catch it.
    NSString *uppercaseKey = MSID_ASWEBAUTH_HANDOFF_URL_KEY.uppercaseString;
    NSDictionary *headers = @{uppercaseKey: @"https://www.example.com/handoff"};

    BOOL hasHandoff = [self.helper processResponseHeadersAndCheckForASWebAuthHandoff:headers
                                                                         responseURL:MSIDTestAllowedResponseURL()];

    XCTAssertTrue(hasHandoff);
    // The normalized headers should expose the lowercased key for later use.
    XCTAssertEqualObjects(self.helper.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_URL_KEY],
                          @"https://www.example.com/handoff");
}

- (void)testProcessResponseHeaders_alwaysUpdatesLastResponseHeadersToNormalizedForm
{
    self.helper.lastResponseHeaders = @{@"stale": @"value"};

    NSDictionary *headers = @{@"X-Custom": @"v1", @"Other-Header": @"v2"};
    (void)[self.helper processResponseHeadersAndCheckForASWebAuthHandoff:headers
                                                             responseURL:MSIDTestAllowedResponseURL()];

    XCTAssertEqualObjects(self.helper.lastResponseHeaders[@"x-custom"], @"v1");
    XCTAssertEqualObjects(self.helper.lastResponseHeaders[@"other-header"], @"v2");
    XCTAssertNil(self.helper.lastResponseHeaders[@"stale"], @"Previous headers must be replaced, not merged.");
}

#pragma mark - processResponseHeadersAndCheckForASWebAuthHandoff:responseURL: (response-URL origin gate)

- (void)testProcessResponseHeaders_whenHandoffHeaderPresentButResponseURLIsNil_shouldReturnNOAndStillCacheHeaders
{
    // Security gate: an attacker-controlled page (or a non-HTTP response somehow reaching here)
    // must not be able to force a hand-off by injecting only the header.
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};

    BOOL hasHandoff = [self.helper processResponseHeadersAndCheckForASWebAuthHandoff:headers
                                                                         responseURL:nil];

    XCTAssertFalse(hasHandoff);
    // Headers are still cached so downstream consumers see consistent state.
    XCTAssertEqualObjects(self.helper.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_URL_KEY],
                          @"https://portal.manage.microsoft.com/handoff");
}

- (void)testProcessResponseHeaders_whenHandoffHeaderPresentButResponseURLIsHTTP_shouldReturnNO
{
    // HTTP origin must never be allowed as a hand-off issuer, even if the host itself is on the allowlist.
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};
    NSURL *httpResponseURL = [NSURL URLWithString:@"http://portal.manage.microsoft.com/some/path"];

    BOOL hasHandoff = [self.helper processResponseHeadersAndCheckForASWebAuthHandoff:headers
                                                                         responseURL:httpResponseURL];

    XCTAssertFalse(hasHandoff);
}

- (void)testProcessResponseHeaders_whenHandoffHeaderPresentButResponseURLHostNotAllowlisted_shouldReturnNO
{
    // Classic attacker scenario: a malicious page injects the hand-off header pointing at a real Microsoft URL.
    // Because the page itself is not served from an allowlisted host, the hand-off must be refused.
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};
    NSURL *attackerOrigin = [NSURL URLWithString:@"https://evil.example.com/landing"];

    BOOL hasHandoff = [self.helper processResponseHeadersAndCheckForASWebAuthHandoff:headers
                                                                         responseURL:attackerOrigin];

    XCTAssertFalse(hasHandoff);
}

- (void)testProcessResponseHeaders_whenHandoffHeaderPresentButResponseURLLooksLikeAllowedAsSubdomain_shouldReturnNO
{
    // Defense against suffix-style spoofing — `portal.manage.microsoft.com.attacker.com` must NOT be allowed.
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};
    NSURL *spoofedOrigin = [NSURL URLWithString:@"https://portal.manage.microsoft.com.attacker.com/path"];

    BOOL hasHandoff = [self.helper processResponseHeadersAndCheckForASWebAuthHandoff:headers
                                                                         responseURL:spoofedOrigin];

    XCTAssertFalse(hasHandoff);
}

- (void)testProcessResponseHeaders_whenHandoffHeaderPresentAndResponseURLIsAllowed_shouldReturnYES
{
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};

    BOOL hasHandoff = [self.helper processResponseHeadersAndCheckForASWebAuthHandoff:headers
                                                                         responseURL:MSIDTestAllowedResponseURL()];

    XCTAssertTrue(hasHandoff);
}

- (void)testProcessResponseHeaders_whenHandoffHeaderPresentAndResponseURLHostIsUppercased_shouldStillBeAllowed
{
    // Hosts are case-insensitive in DNS; the allowlist check must lowercase the host before matching.
    NSDictionary *headers = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://portal.manage.microsoft.com/handoff"};
    NSURL *mixedCaseOrigin = [NSURL URLWithString:@"https://PORTAL.MANAGE.microsoft.com/path"];

    BOOL hasHandoff = [self.helper processResponseHeadersAndCheckForASWebAuthHandoff:headers
                                                                         responseURL:mixedCaseOrigin];

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
    XCTAssertNoThrow([self.helper performASWebAuthenticationHandoffWithParentController:parent
                                                                             completion:nilCompletion]);
}

- (void)testPerformASWebAuthHandoff_whenNoHandoffURLCaptured_shouldCompleteWithFailWithError
{
    // No prior processResponseHeadersAndCheckForASWebAuthHandoff:responseURL: call captured a hand-off URL.
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    MSIDViewController *parent = [MSIDViewController new];

    [self.helper performASWebAuthenticationHandoffWithParentController:parent
                                                            completion:^(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                         NSError * _Nullable error)
    {
        XCTAssertNotNil(decision);
        XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
        XCTAssertNotNil(decision.error);
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1.0];
}

- (void)testPerformASWebAuthHandoff_whenHandoffURLFailsValidation_shouldCompleteWithFailWithError
{
    // Capture a hand-off URL whose domain is not in the allowlist so validation
    // short-circuits before reaching the system webview transition manager.
    // Bypass the processResponseHeadersAndCheckForASWebAuthHandoff:responseURL: origin gate by
    // populating lastResponseHeaders directly — this test isolates the perform-side validation.
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_URL_KEY: @"https://www.example.com/handoff"};

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion invoked"];
    MSIDViewController *parent = [MSIDViewController new];

    [self.helper performASWebAuthenticationHandoffWithParentController:parent
                                                            completion:^(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                         NSError * _Nullable error)
    {
        XCTAssertNotNil(decision);
        XCTAssertEqual(decision.type, MSIDWebviewNavigationDecisionFailWithError);
        XCTAssertNotNil(decision.error);
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1.0];
}

#endif // !MSID_EXCLUDE_SYSTEMWV

@end

#endif
