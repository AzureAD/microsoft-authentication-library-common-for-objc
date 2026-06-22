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
#import "MSIDCertAuthIdentityProviding.h"
#import "MSIDDIContainer.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDConstants.h"
#import "MSIDBasicContext.h"

// A throwaway, self-signed DER certificate (base64) used only to obtain a real,
// CFRelease-safe Security object for tests that need a non-NULL identity to flow
// through the handler. Identity validity is controlled via the fake provider
// (see MSIDFakeCertAuthIdentityProvider.validityResult), so this certificate's
// expiry is irrelevant and the tests never become time-dependent.
static NSString *const kMSIDTestCertBase64 =
    @"MIIDQzCCAiugAwIBAgIUB2VNuPzb/F6+tbWxz22smxWggzUwDQYJKoZIhvcNAQELBQAwMTEvMC0GA1UE"
    @"AwwmTVNJRENlcnRBdXRoSGFuZGxlclRlc3RzIFRlc3QgSWRlbnRpdHkwHhcNMjYwNjIyMjEyNzA0WhcN"
    @"MzYwNjE5MjEyNzA0WjAxMS8wLQYDVQQDDCZNU0lEQ2VydEF1dGhIYW5kbGVyVGVzdHMgVGVzdCBJZGVu"
    @"dGl0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALMeoGpTbJs3uW09nvm029IIyK/R5f4a"
    @"3w6FwkYerxDOGwp3VJu8fVTqRefxJRpX/8sjbUTv/u3Nc/rdp9Wa/maM5Ue/gWsPnwUP3FsTj7cd1M7"
    @"wNXVw7/neCwB5LIv4mQ+7pbQaxX0F3GC7t53hcxv6KI7rtnOsGiyrT5aN22XkHR+LzdWFA5AxWTT3+t"
    @"FT9JX+CHXtD/aW9o8I2000ecBIjEceD2HnTQX1VHrOeVPeiv3mrFQs5X42zloKiiEiG1KomfsTt0e/F"
    @"KFKM/4g5k+lC9iuxAWMjMEX4YzVZts3N6Ux3psPCMzp6/j3I8oIeh4m4BDo+qpOqcMrvDFqvTMCAwEA"
    @"AaNTMFEwHQYDVR0OBBYEFG9Z6HudYdSBYk8IoE4ItxemqTFkMB8GA1UdIwQYMBaAFG9Z6HudYdSBYk8I"
    @"oE4ItxemqTFkMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAHeRQKRmcTkeEbb5KBfj"
    @"Y6hRQPB/4jkrkrmaqhg9NoTRhDDeM8ZQX130uMCeypcOdn0v5jcEY8vpJAgHGcCnNrrmO3wucJnvx+T"
    @"HTi3nh2kUDQjgjrwlSqfWOC4hUVo+nbPZLxcKkYueT8B9Sh0EBnhE2PvEQGIVZXtVAoVX4cVrsBvDqX"
    @"/G2pOXW/GEFTjilKa6HmKEDTDxhflUsMUgEfhY4mo5LWE5JKSwFdyZNpj4aE8Er4c8ccmDiLAGioVSS"
    @"ReobD0wjGBHjxF7AW2FZGf+x4USpsHfZCph8+n8R+TgxbDdtvIcQ8jfV1XKaIDszed6SdnzIVR1HOY7"
    @"cnnIAks=";

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

#pragma mark - Fake Identity Provider (DI seam)

// Conforms to the production seam protocol so tests can drive every branch of
// handleChallenge: without touching the Keychain or presenting UI. Installed via
// -[MSIDDIContainer registerProtocol:lifetime:factory:] in -setUp.
@interface MSIDFakeCertAuthIdentityProvider : NSObject <MSIDCertAuthIdentityProviding>

// When non-nil, copyPreferredIdentityForHost: returns preferredIdentity only for
// this exact host (NULL for any other host). nil means "no preferred identity".
@property (class, nonatomic, copy, nullable) NSString *preferredIdentityHost;
// Result of isIdentityValid:.
@property (class, nonatomic, assign) BOOL validityResult;
// Identity handed back from the simulated cert picker (NULL == user cancelled).
@property (class, nonatomic, assign) SecIdentityRef promptIdentity;

// Recording.
@property (class, nonatomic, readonly) NSArray<NSString *> *queriedHosts;     // hosts passed to copyPreferredIdentityForHost:
@property (class, nonatomic, readonly) NSArray<NSString *> *setPreferredHosts; // hosts passed to setPreferredIdentity:
@property (class, nonatomic, readonly) BOOL promptInvoked;

+ (void)reset;

@end

@implementation MSIDFakeCertAuthIdentityProvider

static NSString *gPreferredIdentityHost = nil;
static BOOL gValidityResult = NO;
static SecIdentityRef gPromptIdentity = NULL;
static SecIdentityRef gPreferredIdentity = NULL; // owned by the test, shared backing object
static NSMutableArray<NSString *> *gQueriedHosts = nil;
static NSMutableArray<NSString *> *gSetPreferredHosts = nil;
static BOOL gPromptInvoked = NO;

+ (NSString *)preferredIdentityHost { return gPreferredIdentityHost; }
+ (void)setPreferredIdentityHost:(NSString *)v { gPreferredIdentityHost = [v copy]; }

+ (BOOL)validityResult { return gValidityResult; }
+ (void)setValidityResult:(BOOL)v { gValidityResult = v; }

+ (SecIdentityRef)promptIdentity { return gPromptIdentity; }
+ (void)setPromptIdentity:(SecIdentityRef)v { gPromptIdentity = v; }

+ (NSArray<NSString *> *)queriedHosts { return [gQueriedHosts copy]; }
+ (NSArray<NSString *> *)setPreferredHosts { return [gSetPreferredHosts copy]; }
+ (BOOL)promptInvoked { return gPromptInvoked; }

// Test-only backing identity used by tests that need a non-NULL preferred identity.
+ (void)setSharedPreferredIdentity:(SecIdentityRef)identity { gPreferredIdentity = identity; }

+ (void)reset
{
    gPreferredIdentityHost = nil;
    gValidityResult = NO;
    gPromptIdentity = NULL;
    gPreferredIdentity = NULL;
    gQueriedHosts = [NSMutableArray new];
    gSetPreferredHosts = [NSMutableArray new];
    gPromptInvoked = NO;
}

#pragma mark MSIDCertAuthIdentityProviding

+ (SecIdentityRef)copyPreferredIdentityForHost:(NSString *)host
                            distinguishedNames:(__unused NSArray<NSData *> *)distinguishedNames
{
    [gQueriedHosts addObject:(host ?: @"")];

    if (gPreferredIdentityHost && [gPreferredIdentityHost isEqualToString:host] && gPreferredIdentity)
    {
        // Honour the +1 contract (CF_RETURNS_RETAINED) declared on the protocol.
        CFRetain(gPreferredIdentity);
        return gPreferredIdentity;
    }

    return NULL;
}

+ (BOOL)isIdentityValid:(SecIdentityRef)identity
                context:(__unused id<MSIDRequestContext>)context
{
    // A NULL identity is never valid; mirror the production semantics so a missing
    // preferred identity falls through to the picker instead of being treated as usable.
    if (identity == NULL)
    {
        return NO;
    }

    return gValidityResult;
}

+ (OSStatus)setPreferredIdentity:(__unused SecIdentityRef)identity
                         forHost:(NSString *)host
                     keyUsageRef:(__unused CFArrayRef)keyUsage
{
    [gSetPreferredHosts addObject:(host ?: @"")];
    return errSecSuccess;
}

+ (void)promptUserForIdentity:(__unused NSArray *)issuers
                         host:(__unused NSString *)host
                      webview:(__unused WKWebView *)webview
                correlationId:(__unused NSUUID *)correlationId
            completionHandler:(void (^)(SecIdentityRef identity))completionHandler
{
    gPromptInvoked = YES;
    // The production prompt callback is invoked on the main queue; mirror that.
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(gPromptIdentity);
    });
}

@end

#pragma mark - Test Class

@interface MSIDCertAuthHandlerTests : XCTestCase

@property (nonatomic, strong) MSIDFlightManagerMockProvider *flightProvider;
@property (nonatomic, assign) SecIdentityRef testIdentity; // SecCertificateRef cast as SecIdentityRef

@end

@implementation MSIDCertAuthHandlerTests

#pragma mark - Setup / Teardown

- (void)setUp
{
    [super setUp];

    // Enable identity persistence by default (flight = NO means NOT disabled).
    self.flightProvider = [MSIDFlightManagerMockProvider new];
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_PREFERRED_IDENTITY_CBA: @NO};
    MSIDFlightManager.sharedInstance.flightProvider = self.flightProvider;

    // A real, CFRelease-safe Security object used wherever a non-NULL identity is
    // required to flow through the handler. Validity is controlled by the fake, so
    // a certificate (rather than a full identity) is sufficient and keeps the test
    // free of any Keychain dependency.
    NSData *certData = [[NSData alloc] initWithBase64EncodedString:kMSIDTestCertBase64 options:0];
    self.testIdentity = (SecIdentityRef)SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certData);

    [MSIDFakeCertAuthIdentityProvider reset];
    [MSIDFakeCertAuthIdentityProvider setSharedPreferredIdentity:self.testIdentity];

    [[MSIDDIContainer sharedInstance] registerProtocol:@protocol(MSIDCertAuthIdentityProviding)
                                              lifetime:MSIDDIContainerLifetimeTransient
                                               factory:^id { return (id)[MSIDFakeCertAuthIdentityProvider class]; }];
}

- (void)tearDown
{
    [MSIDFakeCertAuthIdentityProvider reset];
    [[MSIDDIContainer sharedInstance] reset];
    MSIDFlightManager.sharedInstance.flightProvider = nil;

    if (self.testIdentity)
    {
        CFRelease(self.testIdentity);
        self.testIdentity = NULL;
    }

    [super tearDown];
}

#pragma mark - Helpers

- (NSURLAuthenticationChallenge *)challengeWithHost:(NSString *)host
{
    MSIDMockProtectionSpace *space =
        [[MSIDMockProtectionSpace alloc] initWithHost:host
                                                 port:443
                                             protocol:NSURLProtectionSpaceHTTPS
                                                realm:nil
                                 authenticationMethod:NSURLAuthenticationMethodClientCertificate];
    space.mockDistinguishedNames = @[];
    return [[MSIDMockAuthenticationChallenge alloc] initWithProtectionSpace:space];
}

// Drives handleChallenge: and returns the disposition / credential passed to the
// completion handler. Returns the disposition through the out-params.
- (void)runChallengeWithHost:(NSString *)host
                  disposition:(NSURLSessionAuthChallengeDisposition *)outDisposition
                   credential:(NSURLCredential * __autoreleasing *)outCredential
{
    NSURLAuthenticationChallenge *challenge = [self challengeWithHost:host];
    WKWebView *webview = [[WKWebView alloc] initWithFrame:NSZeroRect];
    MSIDBasicContext *context = [MSIDBasicContext new];

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called once"];

    __block NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;
    __block NSInteger completionCount = 0;

    BOOL handled = [MSIDCertAuthHandler handleChallenge:challenge
                                                webview:webview
                                                context:context
                                      completionHandler:^(NSURLSessionAuthChallengeDisposition d,
                                                          NSURLCredential *c)
    {
        completionCount++;
        disposition = d;
        credential = c;
        [expectation fulfill];
    }];

    XCTAssertTrue(handled, @"handleChallenge: must return YES (challenge handled)");
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    XCTAssertEqual(completionCount, 1, @"Completion handler must be invoked exactly once");

    if (outDisposition) *outDisposition = disposition;
    if (outCredential) *outCredential = credential;
}

#pragma mark - Tests

// A trusted host with a stored preferred identity responds silently with a
// credential and never shows the picker. Verifies the legitimate CBA flow is
// preserved after the FR-1 fix.
- (void)testHandleChallenge_whenPreferredIdentityExistsForHost_shouldUseCredentialWithoutPrompting
{
    NSString *host = @"login.microsoftonline.com";
    MSIDFakeCertAuthIdentityProvider.preferredIdentityHost = host;
    MSIDFakeCertAuthIdentityProvider.validityResult = YES;

    NSURLSessionAuthChallengeDisposition disposition;
    [self runChallengeWithHost:host disposition:&disposition credential:nil];

    XCTAssertEqual(disposition, NSURLSessionAuthChallengeUseCredential);
    XCTAssertFalse(MSIDFakeCertAuthIdentityProvider.promptInvoked, @"A stored preferred identity must not trigger the picker");
}

// No preferred identity for the host and the user cancels the picker: the handler
// must reject the protection space and must NOT send a credential.
- (void)testHandleChallenge_whenNoPreferredIdentityAndUserCancelsPrompt_shouldRejectProtectionSpace
{
    MSIDFakeCertAuthIdentityProvider.preferredIdentityHost = nil; // lookup returns NULL
    MSIDFakeCertAuthIdentityProvider.validityResult = NO;
    MSIDFakeCertAuthIdentityProvider.promptIdentity = NULL;       // user cancels

    NSURLSessionAuthChallengeDisposition disposition;
    NSURLCredential *credential = nil;
    [self runChallengeWithHost:@"login.microsoftonline.com" disposition:&disposition credential:&credential];

    XCTAssertTrue(MSIDFakeCertAuthIdentityProvider.promptInvoked);
    XCTAssertEqual(disposition, NSURLSessionAuthChallengeRejectProtectionSpace);
    XCTAssertNil(credential);
    XCTAssertNotEqual(disposition, NSURLSessionAuthChallengeUseCredential);
}

// FR-1 regression: the preferred-identity lookup must be keyed ONLY by the
// challenge host, never by the webview's top-level URL. The old, vulnerable code
// performed a second SecIdentityCopyPreferred(webview.URL.absoluteString) lookup.
- (void)testHandleChallenge_whenChallengeHostDiffersFromWebviewURL_shouldQueryPreferredIdentityWithChallengeHostOnly
{
    NSString *challengeHost = @"attacker.example.com";
    MSIDFakeCertAuthIdentityProvider.preferredIdentityHost = nil; // no stored preference -> NULL
    MSIDFakeCertAuthIdentityProvider.promptIdentity = NULL;       // user cancels

    NSURLSessionAuthChallengeDisposition disposition;
    [self runChallengeWithHost:challengeHost disposition:&disposition credential:nil];

    XCTAssertEqualObjects(MSIDFakeCertAuthIdentityProvider.queriedHosts, @[challengeHost],
                          @"Lookup must be performed exactly once, with the challenge host only");
}

// Security contract: an attacker-controlled host that issues a CBA challenge while
// the trusted page is loaded must NEVER receive the enterprise credential.
- (void)testHandleChallenge_whenAttackerHostHasNoPreferredIdentity_shouldNotUseCredential
{
    // A preferred identity exists for the trusted host, but the challenge comes
    // from the attacker host -> lookup for the attacker host returns NULL.
    MSIDFakeCertAuthIdentityProvider.preferredIdentityHost = @"login.microsoftonline.com";
    MSIDFakeCertAuthIdentityProvider.validityResult = YES;
    MSIDFakeCertAuthIdentityProvider.promptIdentity = NULL; // user cancels the picker

    NSURLSessionAuthChallengeDisposition disposition;
    NSURLCredential *credential = nil;
    [self runChallengeWithHost:@"attacker.example.com" disposition:&disposition credential:&credential];

    XCTAssertNotEqual(disposition, NSURLSessionAuthChallengeUseCredential,
                      @"The enterprise certificate must never be sent to an untrusted host");
    XCTAssertEqual(disposition, NSURLSessionAuthChallengeRejectProtectionSpace);
    XCTAssertNil(credential);
}

// When the user picks a certificate in the prompt, the handler responds with a
// credential and persists the preference for the challenge host.
- (void)testHandleChallenge_whenUserSelectsIdentityInPrompt_shouldUseCredentialAndPersistPreferenceForHost
{
    NSString *host = @"login.microsoftonline.com";
    MSIDFakeCertAuthIdentityProvider.preferredIdentityHost = nil;          // no stored preference
    MSIDFakeCertAuthIdentityProvider.validityResult = NO;
    MSIDFakeCertAuthIdentityProvider.promptIdentity = self.testIdentity;   // user selects a cert

    NSURLSessionAuthChallengeDisposition disposition;
    [self runChallengeWithHost:host disposition:&disposition credential:nil];

    XCTAssertEqual(disposition, NSURLSessionAuthChallengeUseCredential);
    XCTAssertEqualObjects(MSIDFakeCertAuthIdentityProvider.setPreferredHosts, @[host],
                          @"The selected identity must be persisted for the challenge host");
}

// When identity persistence is disabled by flight, the handler must skip the
// preferred-identity lookup entirely and go straight to the picker.
- (void)testHandleChallenge_whenIdentityPersistenceDisabled_shouldNotQueryPreferredIdentity
{
    self.flightProvider.boolForKeyContainer = @{MSID_FLIGHT_DISABLE_PREFERRED_IDENTITY_CBA: @YES};
    MSIDFakeCertAuthIdentityProvider.promptIdentity = NULL; // user cancels

    NSURLSessionAuthChallengeDisposition disposition;
    [self runChallengeWithHost:@"login.microsoftonline.com" disposition:&disposition credential:nil];

    XCTAssertEqual(MSIDFakeCertAuthIdentityProvider.queriedHosts.count, 0u,
                   @"Preferred-identity lookup must be skipped when persistence is disabled");
    XCTAssertTrue(MSIDFakeCertAuthIdentityProvider.promptInvoked);
    XCTAssertEqual(disposition, NSURLSessionAuthChallengeRejectProtectionSpace);
}

@end
