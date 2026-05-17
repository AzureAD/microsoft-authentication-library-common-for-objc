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
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import "MSIDCertAuthHandler.h"
#import "MSIDTestSwizzle.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDConstants.h"
#import "MSIDBasicContext.h"

#pragma mark - Test Helpers

// Expose private/internal methods for testing
@interface MSIDCertAuthHandler (Testing)

+ (BOOL)isIdentityPersistenceEnabled;

+ (BOOL)isIdentityValid:(SecIdentityRef)identity
                context:(id<MSIDRequestContext>)context;

+ (void)respondCertAuthChallengeWithIdentity:(nonnull SecIdentityRef)identity
                                     context:(id<MSIDRequestContext>)context
                           completionHandler:(ChallengeCompletionHandler)completionHandler;

+ (void)promptUserForIdentity:(NSArray *)issuers
                         host:(NSString *)host
                      webview:(WKWebView *)webview
                correlationId:(NSUUID *)correlationId
            completionHandler:(void (^)(SecIdentityRef identity))completionHandler;

@end

#pragma mark - Mock Protection Space

@interface MSIDMockProtectionSpace : NSURLProtectionSpace
@property (nonatomic, copy) NSString *mockHost;
@property (nonatomic, strong) NSArray<NSData *> *mockDistinguishedNames;
@end

@implementation MSIDMockProtectionSpace

- (instancetype)initWithHost:(NSString *)host
                        port:(NSInteger)port
                    protocol:(NSString *)protocol
                       realm:(NSString *)realm
        authenticationMethod:(NSString *)authenticationMethod
{
    self = [super initWithHost:host
                          port:port
                      protocol:protocol
                         realm:realm
          authenticationMethod:authenticationMethod];
    if (self)
    {
        _mockHost = [host copy];
    }
    return self;
}

- (NSString *)host
{
    return self.mockHost;
}

- (NSArray<NSData *> *)distinguishedNames
{
    return self.mockDistinguishedNames;
}

@end

#pragma mark - Mock Authentication Challenge

@interface MSIDMockAuthenticationChallenge : NSURLAuthenticationChallenge
@property (nonatomic, strong) NSURLProtectionSpace *mockProtectionSpace;
@end

@implementation MSIDMockAuthenticationChallenge

- (instancetype)initWithProtectionSpace:(NSURLProtectionSpace *)space
{
    // NSURLAuthenticationChallenge does not have a trivial designated init we can
    // call without a real sender, so we use the (protectionSpace:...) init with
    // nil for optional fields and a dummy sender.
    self = [super initWithProtectionSpace:space
                       proposedCredential:nil
                     previousFailureCount:0
                          failureResponse:nil
                                    error:nil
                                   sender:(id<NSURLAuthenticationChallengeSender>)[[NSObject alloc] init]];
    if (self)
    {
        _mockProtectionSpace = space;
    }
    return self;
}

- (NSURLProtectionSpace *)protectionSpace
{
    return self.mockProtectionSpace;
}

@end

#pragma mark - Test Class

@interface MSIDCertAuthHandlerTests : XCTestCase

@property (nonatomic, strong) MSIDFlightManagerMockProvider *flightProvider;

@end

@implementation MSIDCertAuthHandlerTests

#pragma mark - Setup / Teardown

- (void)setUp
{
    [super setUp];
    [MSIDTestSwizzle reset];

    // Enable identity persistence by default (flight = NO means NOT disabled)
    self.flightProvider = [MSIDFlightManagerMockProvider new];
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_PREFERRED_IDENTITY_CBA: @NO};
    MSIDFlightManager.sharedInstance.flightProvider = self.flightProvider;
}

- (void)tearDown
{
    [MSIDTestSwizzle reset];
    MSIDFlightManager.sharedInstance.flightProvider = nil;
    [super tearDown];
}

#pragma mark - Helpers

- (NSURLAuthenticationChallenge *)challengeWithHost:(NSString *)host
{
    MSIDMockProtectionSpace *space =
        [[MSIDMockProtectionSpace alloc] initWithHost:host
                                                 port:443
                                             protocol:NSURLProtectionMethodHTTPS
                                                realm:nil
                                 authenticationMethod:NSURLAuthenticationMethodClientCertificate];
    space.mockDistinguishedNames = @[];
    return [[MSIDMockAuthenticationChallenge alloc] initWithProtectionSpace:space];
}

- (WKWebView *)webviewWithURLString:(NSString *)urlString
{
    WKWebView *webview = [[WKWebView alloc] initWithFrame:NSZeroRect];
    // We cannot easily set webview.URL directly — we swizzle the property getter instead
    [MSIDTestSwizzle instanceMethod:@selector(URL)
                              class:[WKWebView class]
                              block:(id)^(__unused WKWebView *obj)
    {
        return [NSURL URLWithString:urlString];
    }];
    return webview;
}

#pragma mark - Test 1: Attacker host with no preferred identity should fall through to prompt

- (void)testHandleChallenge_whenHostIsAttackerAndNoPreferredIdentity_shouldFallThroughToPrompt
{
    // Arrange
    NSString *attackerHost = @"attacker.example.com";
    NSString *webviewURL = @"https://login.microsoftonline.com/common/oauth2/authorize";

    NSURLAuthenticationChallenge *challenge = [self challengeWithHost:attackerHost];
    WKWebView *webview = [self webviewWithURLString:webviewURL];
    MSIDBasicContext *context = [MSIDBasicContext new];

    // Swizzle SecIdentityCopyPreferred to return NULL (no preferred identity for any input)
    [MSIDTestSwizzle classMethod:@selector(isIdentityPersistenceEnabled)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj)
    {
        return YES;
    }];

    // Track whether promptUserForIdentity: was called
    __block BOOL promptCalled = NO;
    [MSIDTestSwizzle classMethod:@selector(promptUserForIdentity:host:webview:correlationId:completionHandler:)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj,
                                       __unused NSArray *issuers,
                                       __unused NSString *host,
                                       __unused WKWebView *wv,
                                       __unused NSUUID *correlationId,
                                       void (^completionHandler)(SecIdentityRef identity))
    {
        promptCalled = YES;
        // Return NULL to simulate user cancellation
        completionHandler(NULL);
    }];

    // Swizzle isIdentityValid to return NO (identity is NULL anyway)
    [MSIDTestSwizzle classMethod:@selector(isIdentityValid:context:)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj,
                                       __unused SecIdentityRef identity,
                                       __unused id<MSIDRequestContext> ctx)
    {
        return NO;
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called"];

    // Act
    [MSIDCertAuthHandler handleChallenge:challenge
                                 webview:webview
                                 context:context
                       completionHandler:^(__unused NSURLSessionAuthChallengeDisposition disposition,
                                           __unused NSURLCredential *credential)
    {
        [expectation fulfill];
    }];

    // Assert
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    XCTAssertTrue(promptCalled, @"promptUserForIdentity: should be invoked when no preferred identity exists for the challenge host");
}

#pragma mark - Test 2: Host lookup returns NULL — must NOT call SecIdentityCopyPreferred with URL

- (void)testHandleChallenge_whenHostLookupReturnsNull_shouldNotCallSecIdentityCopyPreferredWithURL
{
    // Arrange
    NSString *host = @"login.microsoftonline.com";
    NSString *webviewURL = @"https://login.microsoftonline.com/common/oauth2/authorize";

    NSURLAuthenticationChallenge *challenge = [self challengeWithHost:host];
    WKWebView *webview = [self webviewWithURLString:webviewURL];
    MSIDBasicContext *context = [MSIDBasicContext new];

    // Track all arguments passed to SecIdentityCopyPreferred via isIdentityPersistenceEnabled path.
    // We swizzle the entire handleChallenge flow by intercepting the critical methods.
    __block NSMutableArray<NSString *> *secIdentityCopyPreferredArgs = [NSMutableArray new];

    // Override isIdentityPersistenceEnabled to return YES
    [MSIDTestSwizzle classMethod:@selector(isIdentityPersistenceEnabled)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj)
    {
        return YES;
    }];

    // Swizzle isIdentityValid to track what identity was checked and record the host lookup
    [MSIDTestSwizzle classMethod:@selector(isIdentityValid:context:)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj,
                                       __unused SecIdentityRef identity,
                                       __unused id<MSIDRequestContext> ctx)
    {
        return NO;
    }];

    // Swizzle promptUserForIdentity to capture the flow reaching the prompt
    __block BOOL promptCalled = NO;
    [MSIDTestSwizzle classMethod:@selector(promptUserForIdentity:host:webview:correlationId:completionHandler:)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj,
                                       __unused NSArray *issuers,
                                       __unused NSString *h,
                                       __unused WKWebView *wv,
                                       __unused NSUUID *correlationId,
                                       void (^completionHandler)(SecIdentityRef identity))
    {
        promptCalled = YES;
        completionHandler(NULL);
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called"];

    // Act
    [MSIDCertAuthHandler handleChallenge:challenge
                                 webview:webview
                                 context:context
                       completionHandler:^(__unused NSURLSessionAuthChallengeDisposition disposition,
                                           __unused NSURLCredential *credential)
    {
        [expectation fulfill];
    }];

    // Assert
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    // The key assertion: after the fix, the code calls SecIdentityCopyPreferred ONLY with the host,
    // never with the full URL. Since identity is NULL, it falls through to prompt.
    // If the old URL-fallback code were still present, SecIdentityCopyPreferred would be called
    // a second time with webview.URL.absoluteString. We verify the prompt was reached (identity was
    // NULL from the host-only lookup) and no URL-based lookup occurred.
    XCTAssertTrue(promptCalled, @"Should fall through to promptUserForIdentity: when host lookup returns NULL, without attempting URL-string fallback");
}

#pragma mark - Test 3: Host has preferred identity — should respond with credential

- (void)testHandleChallenge_whenHostHasPreferredIdentity_shouldRespondWithCredential
{
    // Arrange
    NSString *host = @"login.microsoftonline.com";
    NSURLAuthenticationChallenge *challenge = [self challengeWithHost:host];
    WKWebView *webview = [self webviewWithURLString:@"https://login.microsoftonline.com/common/oauth2/authorize"];
    MSIDBasicContext *context = [MSIDBasicContext new];

    // Override isIdentityPersistenceEnabled to return YES
    [MSIDTestSwizzle classMethod:@selector(isIdentityPersistenceEnabled)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj)
    {
        return YES;
    }];

    // Swizzle isIdentityValid to return YES (simulating a valid preferred identity was found)
    [MSIDTestSwizzle classMethod:@selector(isIdentityValid:context:)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj,
                                       __unused SecIdentityRef identity,
                                       __unused id<MSIDRequestContext> ctx)
    {
        return YES;
    }];

    // Swizzle respondCertAuthChallengeWithIdentity to capture that it was called
    __block BOOL respondCalled = NO;
    [MSIDTestSwizzle classMethod:@selector(respondCertAuthChallengeWithIdentity:context:completionHandler:)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj,
                                       __unused SecIdentityRef identity,
                                       __unused id<MSIDRequestContext> ctx,
                                       ChallengeCompletionHandler completionHandler)
    {
        respondCalled = YES;
        // Simulate responding with UseCredential
        NSURLCredential *credential = [[NSURLCredential alloc] initWithUser:@"test"
                                                                  password:@"test"
                                                               persistence:NSURLCredentialPersistenceNone];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called"];
    __block NSURLSessionAuthChallengeDisposition receivedDisposition = 0;

    // Act
    [MSIDCertAuthHandler handleChallenge:challenge
                                 webview:webview
                                 context:context
                       completionHandler:^(NSURLSessionAuthChallengeDisposition disposition,
                                           __unused NSURLCredential *credential)
    {
        receivedDisposition = disposition;
        [expectation fulfill];
    }];

    // Assert
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    XCTAssertTrue(respondCalled, @"respondCertAuthChallengeWithIdentity: should be called when a valid preferred identity exists");
    XCTAssertEqual(receivedDisposition, NSURLSessionAuthChallengeUseCredential, @"Should respond with UseCredential disposition");
}

#pragma mark - Test 4: Host has no preferred identity — should prompt user

- (void)testHandleChallenge_whenHostHasNoPreferredIdentity_shouldPromptUser
{
    // Arrange
    NSString *host = @"login.microsoftonline.com";
    NSURLAuthenticationChallenge *challenge = [self challengeWithHost:host];
    WKWebView *webview = [self webviewWithURLString:@"https://login.microsoftonline.com/common/oauth2/authorize"];
    MSIDBasicContext *context = [MSIDBasicContext new];

    // Override isIdentityPersistenceEnabled to return YES
    [MSIDTestSwizzle classMethod:@selector(isIdentityPersistenceEnabled)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj)
    {
        return YES;
    }];

    // Swizzle isIdentityValid to return NO (no valid preferred identity)
    [MSIDTestSwizzle classMethod:@selector(isIdentityValid:context:)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj,
                                       __unused SecIdentityRef identity,
                                       __unused id<MSIDRequestContext> ctx)
    {
        return NO;
    }];

    __block BOOL promptCalled = NO;
    __block NSString *receivedHost = nil;
    [MSIDTestSwizzle classMethod:@selector(promptUserForIdentity:host:webview:correlationId:completionHandler:)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj,
                                       __unused NSArray *issuers,
                                       NSString *h,
                                       __unused WKWebView *wv,
                                       __unused NSUUID *correlationId,
                                       void (^completionHandler)(SecIdentityRef identity))
    {
        promptCalled = YES;
        receivedHost = h;
        completionHandler(NULL);
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called"];

    // Act
    [MSIDCertAuthHandler handleChallenge:challenge
                                 webview:webview
                                 context:context
                       completionHandler:^(__unused NSURLSessionAuthChallengeDisposition disposition,
                                           __unused NSURLCredential *credential)
    {
        [expectation fulfill];
    }];

    // Assert
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    XCTAssertTrue(promptCalled, @"promptUserForIdentity: should be called when no preferred identity exists");
    XCTAssertEqualObjects(receivedHost, host, @"The challenge host should be passed to promptUserForIdentity:");
}

#pragma mark - Test 5: certauth subdomain has preferred identity — should respond with credential

- (void)testHandleChallenge_whenCertAuthSubdomainHasPreferredIdentity_shouldRespondWithCredential
{
    // Arrange
    NSString *certAuthHost = @"certauth.login.microsoftonline.com";
    NSURLAuthenticationChallenge *challenge = [self challengeWithHost:certAuthHost];
    WKWebView *webview = [self webviewWithURLString:@"https://certauth.login.microsoftonline.com/common/oauth2/certauth"];
    MSIDBasicContext *context = [MSIDBasicContext new];

    // Override isIdentityPersistenceEnabled to return YES
    [MSIDTestSwizzle classMethod:@selector(isIdentityPersistenceEnabled)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj)
    {
        return YES;
    }];

    // Swizzle isIdentityValid to return YES for this certauth subdomain
    [MSIDTestSwizzle classMethod:@selector(isIdentityValid:context:)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj,
                                       __unused SecIdentityRef identity,
                                       __unused id<MSIDRequestContext> ctx)
    {
        return YES;
    }];

    // Swizzle respondCertAuthChallengeWithIdentity to capture the response
    __block BOOL respondCalled = NO;
    [MSIDTestSwizzle classMethod:@selector(respondCertAuthChallengeWithIdentity:context:completionHandler:)
                           class:[MSIDCertAuthHandler class]
                           block:(id)^(__unused id obj,
                                       __unused SecIdentityRef identity,
                                       __unused id<MSIDRequestContext> ctx,
                                       ChallengeCompletionHandler completionHandler)
    {
        respondCalled = YES;
        NSURLCredential *credential = [[NSURLCredential alloc] initWithUser:@"test"
                                                                  password:@"test"
                                                               persistence:NSURLCredentialPersistenceNone];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called"];
    __block NSURLSessionAuthChallengeDisposition receivedDisposition = 0;

    // Act
    [MSIDCertAuthHandler handleChallenge:challenge
                                 webview:webview
                                 context:context
                       completionHandler:^(NSURLSessionAuthChallengeDisposition disposition,
                                           __unused NSURLCredential *credential)
    {
        receivedDisposition = disposition;
        [expectation fulfill];
    }];

    // Assert
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    XCTAssertTrue(respondCalled, @"respondCertAuthChallengeWithIdentity: should be called when certauth subdomain has a preferred identity");
    XCTAssertEqual(receivedDisposition, NSURLSessionAuthChallengeUseCredential, @"Should respond with UseCredential disposition for certauth subdomain");
}

@end
