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
#import "MSIDBoundTokenProvider.h"
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDError.h"
#import "MSIDConstants.h"
#import "MSIDAADAuthority.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDDefaultSilentTokenRequest.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "MSIDAccount.h"
#import "MSIDConfiguration.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestConfiguration.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDBartFeatureUtil.h"
#import "MSIDBoundRefreshToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDBrokerConstants.h"
#import "MSIDCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDKeychainUtil.h"
#import "NSString+MSIDExtensions.h"

#pragma mark - Test seam (private methods under test)

// Surface the provider's private orchestration methods so the suite can exercise the routing
// decision and silent path directly, and so the stub subclass below can override the seams.
@interface MSIDBoundTokenProvider (UnitTest)

- (MSIDInteractiveTokenRequestParameters *)requestParametersFromRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                                                context:(nullable id<MSIDRequestContext>)context
                                                                  error:(NSError *__autoreleasing *)error;

- (BOOL)shouldServiceRequestSilently:(MSIDBrowserNativeMessageGetTokenRequest *)request
                          parameters:(MSIDInteractiveTokenRequestParameters *)parameters
                             context:(nullable id<MSIDRequestContext>)context;

- (BOOL)promptForcesInteraction:(MSIDPromptType)prompt;

- (void)acquireTokenSilentlyWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                   request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                   context:(nullable id<MSIDRequestContext>)context
                           completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock;

- (MSIDDefaultTokenCacheAccessor *)defaultTokenCache:(nullable id<MSIDRequestContext>)context;
- (MSIDAccountMetadataCacheAccessor *)accountMetadataCache:(nullable id<MSIDRequestContext>)context;

- (MSIDDefaultSilentTokenRequest *)silentTokenRequestWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                                         tokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
                                               accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache;

@end

#pragma mark - Silent engine stub

// Stands in for the real MSIDDefaultSilentTokenRequest so tests can drive the provider's silent
// orchestration with canned outcomes instead of resolving an authority and hitting the network.
@interface MSIDBoundTokenProviderTestSilentRequestStub : MSIDDefaultSilentTokenRequest

@property (nonatomic, nullable) MSIDTokenResult *stubResult;
@property (nonatomic, nullable) NSError *stubError;

@end

@implementation MSIDBoundTokenProviderTestSilentRequestStub

- (void)executeRequestWithCompletion:(MSIDRequestCompletionBlock)completionBlock
{
    completionBlock(self.stubResult, self.stubError);
}

@end

#pragma mark - Provider stub (injectable dependencies)

// Overrides the provider's dependency seams so the silent path runs against in-memory caches and a
// stubbed silent engine. Mirrors how production would wire a real cache + MSIDDefaultSilentTokenRequest.
@interface MSIDBoundTokenProviderTestStub : MSIDBoundTokenProvider

@property (nonatomic, nullable) MSIDDefaultTokenCacheAccessor *injectedTokenCache;
@property (nonatomic, nullable) MSIDAccountMetadataCacheAccessor *injectedAccountMetadataCache;
@property (nonatomic, nullable) MSIDTokenResult *silentResult;
@property (nonatomic, nullable) NSError *silentError;
@property (nonatomic) BOOL silentRequestCreated;

@end

@implementation MSIDBoundTokenProviderTestStub

- (MSIDDefaultTokenCacheAccessor *)defaultTokenCache:(__unused id<MSIDRequestContext>)context
{
    return self.injectedTokenCache;
}

- (MSIDAccountMetadataCacheAccessor *)accountMetadataCache:(__unused id<MSIDRequestContext>)context
{
    return self.injectedAccountMetadataCache;
}

- (MSIDDefaultSilentTokenRequest *)silentTokenRequestWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                                         tokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
                                               accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
{
    self.silentRequestCreated = YES;

    MSIDBoundTokenProviderTestSilentRequestStub *stub =
    [[MSIDBoundTokenProviderTestSilentRequestStub alloc] initWithRequestParameters:parameters
                                                                     forceRefresh:NO
                                                                     oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                           tokenResponseValidator:[MSIDTokenResponseValidator new]
                                                                       tokenCache:tokenCache
                                                             accountMetadataCache:accountMetadataCache];
    stub.stubResult = self.silentResult;
    stub.stubError = self.silentError;
    return stub;
}

@end

@interface MSIDBoundTokenProviderTests : XCTestCase

@end

@implementation MSIDBoundTokenProviderTests

#pragma mark - Fixtures

// A production-shaped GetToken request built from the real MSIDBrowserNativeMessageGetTokenRequest
// properties. Includes an account identifier, so it is eligible for the silent path by default.
- (MSIDBrowserNativeMessageGetTokenRequest *)validRequest
{
    MSIDBrowserNativeMessageGetTokenRequest *request = [MSIDBrowserNativeMessageGetTokenRequest new];
    request.clientId = @"00000000-0000-0000-0000-000000000001";
    request.redirectUri = @"brk-com.microsoft.test://auth";
    request.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                    rawTenant:nil
                                                      context:nil
                                                        error:nil];
    request.scopes = @"user.read";
    request.state = @"test-state";
    request.prompt = MSIDPromptTypeDefault;
    request.canShowUI = YES;
    request.isSts = NO;
    request.nonce = @"test-nonce";
    request.loginHint = @"user@contoso.com";
    request.instanceAware = NO;
    request.platformSequence = @"oneauth|1.2.3,msal|1.0.0";
    request.extraParameters = @{ @"foo": @"bar" };
    request.accountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                              homeAccountId:@"uid.utid"];
    return request;
}

- (MSIDInteractiveTokenRequestParameters *)parametersForRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
{
    NSError *error = nil;
    MSIDInteractiveTokenRequestParameters *parameters = [[MSIDBoundTokenProvider new] requestParametersFromRequest:request
                                                                                                          context:nil
                                                                                                            error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    return parameters;
}

// A token result shaped like a cache hit (no fresh server response), which the provider serializes
// directly from the cached access token.
- (MSIDTokenResult *)cachedTokenResult
{
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];

    return [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                           refreshToken:nil
                                                idToken:response.idToken
                                                account:account
                                              authority:configuration.authority
                                          correlationId:[NSUUID UUID]
                                          tokenResponse:nil];
}

#pragma mark - Request validation

- (void)testAcquireBoundToken_missingClientId_returnsError
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.clientId = @"";

    XCTestExpectation *expectation = [self expectationWithDescription:@"validation error"];

    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

- (void)testAcquireBoundToken_missingAuthority_returnsError
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.authority = nil;

    XCTestExpectation *expectation = [self expectationWithDescription:@"missing authority error"];

    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

#pragma mark - Routing decision

- (void)testShouldServiceRequestSilently_promptForcesUI_returnsNo
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.prompt = MSIDPromptTypeLogin;
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];

    XCTAssertFalse([provider shouldServiceRequestSilently:request parameters:parameters context:nil]);
}

- (void)testShouldServiceRequestSilently_noAccountIdentifier_returnsNo
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.accountId = nil;
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];

    XCTAssertFalse([provider shouldServiceRequestSilently:request parameters:parameters context:nil]);
}

- (void)testPromptForcesInteraction_interactivePrompts_returnYes
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];

    XCTAssertTrue([provider promptForcesInteraction:MSIDPromptTypeLogin]);
    XCTAssertTrue([provider promptForcesInteraction:MSIDPromptTypeConsent]);
    XCTAssertTrue([provider promptForcesInteraction:MSIDPromptTypeCreate]);
    XCTAssertTrue([provider promptForcesInteraction:MSIDPromptTypeSelectAccount]);
    XCTAssertTrue([provider promptForcesInteraction:MSIDPromptTypeRefreshSession]);
}

- (void)testPromptForcesInteraction_silentPrompts_returnNo
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];

    XCTAssertFalse([provider promptForcesInteraction:MSIDPromptTypeDefault]);
    XCTAssertFalse([provider promptForcesInteraction:MSIDPromptTypePromptIfNecessary]);
    XCTAssertFalse([provider promptForcesInteraction:MSIDPromptTypeNever]);
}

#pragma mark - End-to-end routing

// A prompt that forces UI must never be serviced silently; it routes straight to the (not-yet-
// implemented) interactive path regardless of cached token availability.
- (void)testAcquireBoundToken_promptForcesUI_routesToInteractive
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.prompt = MSIDPromptTypeLogin;

    XCTestExpectation *expectation = [self expectationWithDescription:@"interaction required"];

    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

// With no account identifier the request cannot be serviced silently, so the provider routes to the
// interactive path and surfaces a clear interaction-required signal.
- (void)testAcquireBoundToken_noAccountIdentifier_routesToInteractive
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.accountId = nil;

    XCTestExpectation *expectation = [self expectationWithDescription:@"interaction required"];

    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

#if TARGET_OS_IPHONE

#pragma mark - Silent path

- (MSIDDefaultTokenCacheAccessor *)inMemoryTokenCache
{
    MSIDTestCacheDataSource *dataSource = [MSIDTestCacheDataSource new];
    return [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
}

- (MSIDAccountMetadataCacheAccessor *)inMemoryAccountMetadataCache
{
    MSIDTestCacheDataSource *dataSource = [MSIDTestCacheDataSource new];
    return [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
}

- (MSIDBoundTokenProviderTestStub *)configuredProviderStub
{
    MSIDBoundTokenProviderTestStub *provider = [MSIDBoundTokenProviderTestStub new];
    provider.injectedTokenCache = [self inMemoryTokenCache];
    provider.injectedAccountMetadataCache = [self inMemoryAccountMetadataCache];
    return provider;
}

- (void)testDefaultCacheAccessors_useSharedAdalKeychainGroup
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];

    // The keychain data source stores the team-prefixed access group, so build the
    // expected value with the same helper the production cache uses.
    NSString *expectedKeychainGroup = [[MSIDKeychainUtil sharedInstance] accessGroup:[MSIDKeychainTokenCache defaultKeychainGroup]];

    MSIDDefaultTokenCacheAccessor *tokenCache = [provider defaultTokenCache:nil];
    XCTAssertNotNil(tokenCache);
    XCTAssertEqualObjects([(NSObject *)tokenCache.accountCredentialCache.dataSource valueForKey:@"keychainGroup"],
                          expectedKeychainGroup);

    MSIDAccountMetadataCacheAccessor *accountMetadataCache = [provider accountMetadataCache:nil];
    XCTAssertNotNil(accountMetadataCache);

    id metadataCache = [accountMetadataCache valueForKey:@"metadataCache"];
    XCTAssertEqualObjects([[metadataCache valueForKey:@"dataSource"] valueForKey:@"keychainGroup"],
                          expectedKeychainGroup);
}

// When the silent engine returns a token result, the provider serializes it into the GetToken
// response payload and reports success.
- (void)testAcquireTokenSilently_engineReturnsResult_returnsPayload
{
    MSIDBoundTokenProviderTestStub *provider = [self configuredProviderStub];
    provider.silentResult = [self cachedTokenResult];
    provider.silentError = nil;

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"payload"];

    [provider acquireTokenSilentlyWithParameters:parameters
                                         request:request
                                         context:nil
                                 completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertTrue([response containsString:@"access_token"]);
        [expectation fulfill];
    }];

    XCTAssertTrue(provider.silentRequestCreated);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// When the silent engine reports interaction is required, the provider falls back to the interactive
// path rather than surfacing the engine error directly.
- (void)testAcquireTokenSilently_engineReturnsInteractionRequired_routesToInteractive
{
    MSIDBoundTokenProviderTestStub *provider = [self configuredProviderStub];
    provider.silentResult = nil;
    provider.silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                           @"User interaction is required", nil, nil, nil, nil, nil, NO);

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"interaction required"];

    [provider acquireTokenSilentlyWithParameters:parameters
                                         request:request
                                         context:nil
                                 completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

// A hard failure from the silent engine (not interaction-required) is propagated to the caller as-is.
- (void)testAcquireTokenSilently_engineReturnsHardError_propagatesError
{
    MSIDBoundTokenProviderTestStub *provider = [self configuredProviderStub];
    provider.silentResult = nil;
    provider.silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerOauth,
                                           @"server rejected the request", nil, nil, nil, nil, nil, NO);

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"hard error"];

    [provider acquireTokenSilentlyWithParameters:parameters
                                         request:request
                                         context:nil
                                 completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorServerOauth);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

// When the token cache cannot be constructed the silent engine is never created and the provider
// routes to the interactive path.
- (void)testAcquireTokenSilently_cacheUnavailable_routesToInteractive
{
    MSIDBoundTokenProviderTestStub *provider = [MSIDBoundTokenProviderTestStub new];
    provider.injectedTokenCache = nil;
    provider.injectedAccountMetadataCache = nil;

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"interaction required"];

    [provider acquireTokenSilentlyWithParameters:parameters
                                         request:request
                                         context:nil
                                 completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    XCTAssertFalse(provider.silentRequestCreated);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

#pragma mark - Bound token cache lookup

// Seeds a refresh token into the supplied cache for the account/configuration derived from the
// request. When boundDeviceId is non-nil a Bound App Refresh Token (BART) is persisted; otherwise a
// regular (non-bound) refresh token is persisted.
- (void)seedRefreshTokenInCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
                     parameters:(MSIDInteractiveTokenRequestParameters *)parameters
                  boundDeviceId:(NSString *)boundDeviceId
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"user@contoso.com" subject:@"subject"];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:@"cached-at"
                                                                                RT:@"some-rt"
                                                                            scopes:[@"user.read" msidScopeSet]
                                                                           idToken:idToken
                                                                               uid:@"uid"
                                                                              utid:@"utid"
                                                                          familyId:nil];

    // A device-bound RT is denoted by the BART device id; re-hydrate the response from JSON so the
    // factory persists a MSIDBoundRefreshToken.
    if (boundDeviceId)
    {
        NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:response.jsonDictionary];
        json[MSID_BART_DEVICE_ID_KEY] = boundDeviceId;
        response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:json error:nil];
    }

    NSError *saveError = nil;
    BOOL saved = [tokenCache saveTokensWithConfiguration:parameters.msidConfiguration
                                                response:response
                                                 factory:[MSIDAADV2Oauth2Factory new]
                                                 context:nil
                                                   error:&saveError];
    XCTAssertNil(saveError);
    XCTAssertTrue(saved);
}

// Walkable proof of what MSIDBoundTokenProvider retrieves at hasCachedTokenForParameters (the
// getRefreshTokenWithAccount: call): when a BART is cached and the feature is enabled, the lookup
// returns a bound token (MSIDBoundRefreshToken), not a regular refresh token.
- (void)testCachedRefreshTokenLookup_whenBoundTokenSeeded_returnsBoundToken
{
    [[MSIDBartFeatureUtil sharedInstance] setBartSupportInAppCache:YES];

    MSIDDefaultTokenCacheAccessor *tokenCache = [self inMemoryTokenCache];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:[self validRequest]];
    [self seedRefreshTokenInCache:tokenCache parameters:parameters boundDeviceId:@"test-device-id"];

    NSError *lookupError = nil;
    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:parameters.accountIdentifier
                                                                  familyId:nil
                                                             configuration:parameters.msidConfiguration
                                                                   context:nil
                                                                     error:&lookupError];

    XCTAssertNil(lookupError);
    XCTAssertNotNil(refreshToken);
    XCTAssertTrue([refreshToken isKindOfClass:[MSIDBoundRefreshToken class]]);
    XCTAssertEqualObjects([(MSIDBoundRefreshToken *)refreshToken boundDeviceId], @"test-device-id");

    [[MSIDBartFeatureUtil sharedInstance] setBartSupportInAppCache:NO];
}

// Drives the provider's actual routing gate: with only a BART cached (no valid access token), the
// gate falls through to the refresh-token lookup and deems the request silent-eligible.
- (void)testShouldServiceRequestSilently_whenOnlyBoundRefreshTokenCached_returnsYes
{
    [[MSIDBartFeatureUtil sharedInstance] setBartSupportInAppCache:YES];

    MSIDDefaultTokenCacheAccessor *tokenCache = [self inMemoryTokenCache];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];
    [self seedRefreshTokenInCache:tokenCache parameters:parameters boundDeviceId:@"test-device-id"];

    // Remove the cached access token so the gate must consult the refresh-token lookup.
    MSIDAccessToken *accessToken = [tokenCache getAccessTokenForAccount:parameters.accountIdentifier
                                                         configuration:parameters.msidConfiguration
                                                               context:nil
                                                                 error:nil];
    XCTAssertNotNil(accessToken);
    XCTAssertTrue([tokenCache removeToken:accessToken context:nil error:nil]);

    MSIDBoundTokenProviderTestStub *provider = [MSIDBoundTokenProviderTestStub new];
    provider.injectedTokenCache = tokenCache;

    XCTAssertTrue([provider shouldServiceRequestSilently:request parameters:parameters context:nil]);

    [[MSIDBartFeatureUtil sharedInstance] setBartSupportInAppCache:NO];
}

// Per the BART SPA design, a regular (non-bound) refresh token does not make the request silent-
// eligible: with no cached BART the gate returns NO so orchestration falls back to interactive.
- (void)testShouldServiceRequestSilently_whenOnlyRegularRefreshTokenCached_returnsNo
{
    [[MSIDBartFeatureUtil sharedInstance] setBartSupportInAppCache:YES];

    MSIDDefaultTokenCacheAccessor *tokenCache = [self inMemoryTokenCache];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];
    [self seedRefreshTokenInCache:tokenCache parameters:parameters boundDeviceId:nil];

    // Remove the cached access token so the gate must consult the refresh-token lookup.
    MSIDAccessToken *accessToken = [tokenCache getAccessTokenForAccount:parameters.accountIdentifier
                                                         configuration:parameters.msidConfiguration
                                                               context:nil
                                                                 error:nil];
    XCTAssertNotNil(accessToken);
    XCTAssertTrue([tokenCache removeToken:accessToken context:nil error:nil]);

    MSIDBoundTokenProviderTestStub *provider = [MSIDBoundTokenProviderTestStub new];
    provider.injectedTokenCache = tokenCache;

    XCTAssertFalse([provider shouldServiceRequestSilently:request parameters:parameters context:nil]);

    [[MSIDBartFeatureUtil sharedInstance] setBartSupportInAppCache:NO];
}

#endif

@end
