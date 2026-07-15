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
#import "MSIDBrowserNativeMessageGetTokenRequestParametersFactory.h"
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

- (void)acquireTokenSilentlyWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                   request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                   context:(nullable id<MSIDRequestContext>)context
                           completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock;

- (void)acquireTokenInteractivelyWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                        request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                        context:(nullable id<MSIDRequestContext>)context
                                completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock;

- (MSIDDefaultTokenCacheAccessor *)defaultTokenCache:(nullable id<MSIDRequestContext>)context;
- (MSIDAccountMetadataCacheAccessor *)accountMetadataCache:(nullable id<MSIDRequestContext>)context;

- (MSIDDefaultSilentTokenRequest *)silentTokenRequestWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                                         tokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
                                               accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache;

- (NSString *)responsePayloadFromResult:(MSIDTokenResult *)result
                                request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                  error:(NSError *__autoreleasing *)error;

- (NSDictionary *)responseDictionaryFromResult:(MSIDTokenResult *)result
                                       request:(MSIDBrowserNativeMessageGetTokenRequest *)request;

- (NSDictionary *)responseDictionaryFromCachedResult:(MSIDTokenResult *)result
                                             request:(MSIDBrowserNativeMessageGetTokenRequest *)request;

@end

#pragma mark - Silent request test seam

@interface MSIDDefaultSilentTokenRequest (BoundTokenProviderUnitTest)

- (MSIDRefreshToken *)familyRefreshTokenWithError:(NSError *__autoreleasing *)error;
- (MSIDBaseToken<MSIDRefreshableToken> *)appRefreshTokenWithError:(NSError *__autoreleasing *)error;

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
@property (nonatomic) BOOL interactiveRequestCreated;
@property (nonatomic, nullable) MSIDDefaultSilentTokenRequest *createdSilentRequest;

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
    self.createdSilentRequest = stub;
    return stub;
}

- (void)acquireTokenInteractivelyWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                        request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                        context:(nullable id<MSIDRequestContext>)context
                                completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock
{
    self.interactiveRequestCreated = YES;
    [super acquireTokenInteractivelyWithParameters:parameters
                                           request:request
                                           context:context
                                   completionBlock:completionBlock];
}

@end

#pragma mark - Invalid JSON response stub

@interface MSIDBoundTokenProviderInvalidJSONStub : MSIDBoundTokenProvider

@end

@implementation MSIDBoundTokenProviderInvalidJSONStub

- (NSDictionary *)responseDictionaryFromResult:(__unused MSIDTokenResult *)result
                                       request:(__unused MSIDBrowserNativeMessageGetTokenRequest *)request
{
    return @{@"invalid": NSDate.date};
}

@end

@interface MSIDBoundTokenProviderTests : XCTestCase

- (MSIDBoundTokenProviderTestStub *)configuredProviderStub;

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
    MSIDInteractiveTokenRequestParameters *parameters =
    [MSIDBrowserNativeMessageGetTokenRequestParametersFactory requestParametersWithRequest:request
                                                                                requestType:MSIDRequestBrokeredType
                                                            boundAppRefreshTokenRequested:YES
                                                                       correlationIdOverride:nil
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
        XCTAssertNotNil(error.userInfo[NSUnderlyingErrorKey]);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

#pragma mark - End-to-end routing

// A request that requires UI returns interaction-required when UI is prohibited.
- (void)testAcquireBoundToken_promptForcesUIAndUIProhibited_returnsInteractionRequired
{
    MSIDBoundTokenProviderTestStub *provider = [MSIDBoundTokenProviderTestStub new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.prompt = MSIDPromptTypeLogin;
    request.canShowUI = NO;

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

    XCTAssertFalse(provider.silentRequestCreated);
    XCTAssertFalse(provider.interactiveRequestCreated);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// With no account identifier, UI-prohibited requests return interaction-required.
- (void)testAcquireBoundToken_noAccountIdentifierAndUIProhibited_returnsInteractionRequired
{
    MSIDBoundTokenProviderTestStub *provider = [MSIDBoundTokenProviderTestStub new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.accountId = nil;
    request.canShowUI = NO;

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

    XCTAssertFalse(provider.silentRequestCreated);
    XCTAssertFalse(provider.interactiveRequestCreated);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// A request that requires UI routes directly to interactive when UI is allowed.
- (void)testAcquireBoundToken_promptForcesUIAndUIAllowed_routesToInteractive
{
    MSIDBoundTokenProviderTestStub *provider = [MSIDBoundTokenProviderTestStub new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.prompt = MSIDPromptTypeLogin;

    XCTestExpectation *expectation = [self expectationWithDescription:@"interactive"];

    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    XCTAssertFalse(provider.silentRequestCreated);
    XCTAssertTrue(provider.interactiveRequestCreated);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// An eligible request uses the silent engine before considering interactive fallback.
- (void)testAcquireBoundToken_eligibleRequest_routesToSilent
{
    MSIDBoundTokenProviderTestStub *provider = [self configuredProviderStub];
    provider.silentResult = [self cachedTokenResult];

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    XCTestExpectation *expectation = [self expectationWithDescription:@"silent"];

    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNotNil(response);
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    XCTAssertTrue(provider.silentRequestCreated);
    XCTAssertFalse(provider.interactiveRequestCreated);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// The in-process BART path can resolve a displayable-ID-only account and must not inherit
// the broker-local non-STS home-account requirement.
- (void)testAcquireBoundToken_loginHintOnlyAccount_routesToSilent
{
    MSIDBoundTokenProviderTestStub *provider = [self configuredProviderStub];
    provider.silentResult = [self cachedTokenResult];

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.accountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:request.loginHint
                                                              homeAccountId:nil];
    XCTestExpectation *expectation = [self expectationWithDescription:@"login hint silent"];

    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNotNil(response);
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    XCTAssertTrue(provider.silentRequestCreated);
    XCTAssertFalse(provider.interactiveRequestCreated);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// When silent acquisition requires interaction and UI is allowed, the provider falls back exactly once.
- (void)testAcquireBoundToken_silentRequiresInteractionAndUIAllowed_fallsBackToInteractive
{
    MSIDBoundTokenProviderTestStub *provider = [self configuredProviderStub];
    provider.silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                           @"User interaction is required", nil, nil, nil, nil, nil, NO);

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    XCTestExpectation *expectation = [self expectationWithDescription:@"interactive fallback"];

    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    XCTAssertTrue(provider.silentRequestCreated);
    XCTAssertTrue(provider.interactiveRequestCreated);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

- (void)testAcquireBoundToken_silentRequiresInteractionAndUIProhibited_returnsInteractionRequired
{
    MSIDBoundTokenProviderTestStub *provider = [self configuredProviderStub];
    provider.silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                           @"User interaction is required", nil, nil, nil, nil, nil, NO);

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.canShowUI = NO;
    XCTestExpectation *expectation = [self expectationWithDescription:@"interaction required without fallback"];

    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertEqual(error, provider.silentError);
        [expectation fulfill];
    }];

    XCTAssertTrue(provider.silentRequestCreated);
    XCTAssertFalse(provider.interactiveRequestCreated);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

- (void)testAcquireBoundToken_promptNeverSilentRequiresInteraction_doesNotFallBackToInteractive
{
    MSIDBoundTokenProviderTestStub *provider = [self configuredProviderStub];
    provider.silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                           @"User interaction is required", nil, nil, nil, nil, nil, NO);

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.prompt = MSIDPromptTypeNever;
    request.canShowUI = YES;
    XCTestExpectation *expectation = [self expectationWithDescription:@"no interactive fallback"];

    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    XCTAssertTrue(provider.silentRequestCreated);
    XCTAssertFalse(provider.interactiveRequestCreated);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

#pragma mark - Response shaping

- (void)testResponsePayloadFromResult_whenResponseIsNotValidJSON_returnsError
{
    MSIDBoundTokenProviderInvalidJSONStub *provider = [MSIDBoundTokenProviderInvalidJSONStub new];
    NSError *error = nil;

    NSString *response = [provider responsePayloadFromResult:[self cachedTokenResult]
                                                     request:[self validRequest]
                                                       error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testResponseDictionaryFromCachedResult_whenExpirationIsPresent_returnsStringValues
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];
    NSDictionary *response = [provider responseDictionaryFromCachedResult:[self cachedTokenResult]
                                                                  request:[self validRequest]];

    XCTAssertTrue([response[@"expires_on"] isKindOfClass:NSString.class]);
    XCTAssertTrue([response[@"expires_in"] isKindOfClass:NSString.class]);
}

- (void)testResponseDictionaryFromCachedResult_whenOptionalValuesAreMissing_omitsFields
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];
    MSIDTokenResult *result = [self cachedTokenResult];
    [result.accessToken setValue:@"" forKey:@"accessToken"];
    [result.accessToken setValue:@"" forKey:@"tokenType"];
    [result.accessToken setValue:nil forKey:@"scopes"];
    [result.accessToken setValue:nil forKey:@"expiresOn"];
    [result setValue:@"" forKey:@"rawIdToken"];
    [result.account setValue:nil forKey:@"accountIdentifier"];
    [result.account setValue:@"" forKey:@"username"];

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.loginHint = @"";
    request.state = @"";

    NSDictionary *response = [provider responseDictionaryFromCachedResult:result request:request];

    XCTAssertEqual(response.count, 0);
}

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

#if TARGET_OS_IPHONE

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
    XCTAssertTrue(provider.createdSilentRequest.requiresBoundRefreshToken);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// When the silent engine reports interaction is required, the provider returns the original error
// so the host can explicitly start an interactive request.
- (void)testAcquireTokenSilently_engineReturnsInteractionRequired_returnsOriginalError
{
    MSIDBoundTokenProviderTestStub *provider = [self configuredProviderStub];
    provider.silentResult = nil;
    provider.silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                           @"User interaction is required", nil, nil, nil, nil, nil, NO);

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.canShowUI = NO;
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
        XCTAssertEqual(error, provider.silentError);
        [expectation fulfill];
    }];

    XCTAssertFalse(provider.interactiveRequestCreated);
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
        XCTAssertEqualObjects(error.userInfo[NSUnderlyingErrorKey], provider.silentError);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

// When the token cache cannot be constructed, the provider returns interaction-required without
// creating the silent engine or launching UI.
- (void)testAcquireTokenSilently_cacheUnavailable_returnsInteractionRequired
{
    MSIDBoundTokenProviderTestStub *provider = [MSIDBoundTokenProviderTestStub new];
    provider.injectedTokenCache = nil;
    provider.injectedAccountMetadataCache = nil;

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.canShowUI = NO;
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
    XCTAssertFalse(provider.interactiveRequestCreated);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// When the token cache is unavailable and UI is allowed, the provider falls back to interactive.
- (void)testAcquireTokenSilently_cacheUnavailableAndUIAllowed_routesToInteractive
{
    MSIDBoundTokenProviderTestStub *provider = [MSIDBoundTokenProviderTestStub new];
    provider.injectedTokenCache = nil;
    provider.injectedAccountMetadataCache = nil;

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];
    XCTestExpectation *expectation = [self expectationWithDescription:@"interactive fallback"];

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
    XCTAssertTrue(provider.interactiveRequestCreated);
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

// Proves that the cache lookup used by the silent engine returns a bound token when a BART is
// cached and the feature is enabled.
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
    XCTAssertTrue(refreshToken.isBoundRefreshToken);
    XCTAssertEqualObjects([(MSIDBoundRefreshToken *)refreshToken boundDeviceId], @"test-device-id");

    [[MSIDBartFeatureUtil sharedInstance] setBartSupportInAppCache:NO];
}

- (void)testSilentRequest_whenBoundRefreshTokenRequired_rejectsRegularRefreshToken
{
    [[MSIDBartFeatureUtil sharedInstance] setBartSupportInAppCache:YES];

    MSIDDefaultTokenCacheAccessor *tokenCache = [self inMemoryTokenCache];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];
    [self seedRefreshTokenInCache:tokenCache parameters:parameters boundDeviceId:nil];

    MSIDAccessToken *accessToken = [tokenCache getAccessTokenForAccount:parameters.accountIdentifier
                                                         configuration:parameters.msidConfiguration
                                                               context:nil
                                                                 error:nil];
    XCTAssertNotNil(accessToken);
    XCTAssertTrue([tokenCache removeToken:accessToken context:nil error:nil]);

    MSIDDefaultSilentTokenRequest *silentRequest =
    [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:parameters
                                                        forceRefresh:NO
                                                        oauthFactory:[MSIDAADV2Oauth2Factory new]
                                              tokenResponseValidator:[MSIDTokenResponseValidator new]
                                                          tokenCache:tokenCache
                                                accountMetadataCache:[self inMemoryAccountMetadataCache]];

    XCTAssertFalse(silentRequest.requiresBoundRefreshToken);
    MSIDRefreshToken *regularRefreshToken = (MSIDRefreshToken *)[silentRequest appRefreshTokenWithError:nil];
    XCTAssertNotNil(regularRefreshToken);
    XCTAssertFalse(regularRefreshToken.isBoundRefreshToken);

    silentRequest.requiresBoundRefreshToken = YES;
    XCTAssertNil([silentRequest familyRefreshTokenWithError:nil]);
    XCTAssertNil([silentRequest appRefreshTokenWithError:nil]);

    [[MSIDBartFeatureUtil sharedInstance] setBartSupportInAppCache:NO];
}

- (void)testSilentRequest_whenBoundRefreshTokenRequired_acceptsBoundRefreshToken
{
    [[MSIDBartFeatureUtil sharedInstance] setBartSupportInAppCache:YES];

    MSIDDefaultTokenCacheAccessor *tokenCache = [self inMemoryTokenCache];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];
    [self seedRefreshTokenInCache:tokenCache parameters:parameters boundDeviceId:@"test-device-id"];

    MSIDAccessToken *accessToken = [tokenCache getAccessTokenForAccount:parameters.accountIdentifier
                                                         configuration:parameters.msidConfiguration
                                                               context:nil
                                                                 error:nil];
    XCTAssertNotNil(accessToken);
    XCTAssertTrue([tokenCache removeToken:accessToken context:nil error:nil]);

    MSIDDefaultSilentTokenRequest *silentRequest =
    [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:parameters
                                                        forceRefresh:NO
                                                        oauthFactory:[MSIDAADV2Oauth2Factory new]
                                              tokenResponseValidator:[MSIDTokenResponseValidator new]
                                                          tokenCache:tokenCache
                                                accountMetadataCache:[self inMemoryAccountMetadataCache]];
    silentRequest.requiresBoundRefreshToken = YES;

    MSIDRefreshToken *boundRefreshToken = (MSIDRefreshToken *)[silentRequest appRefreshTokenWithError:nil];
    XCTAssertNotNil(boundRefreshToken);
    XCTAssertTrue(boundRefreshToken.isBoundRefreshToken);

    [[MSIDBartFeatureUtil sharedInstance] setBartSupportInAppCache:NO];
}

#endif

@end
