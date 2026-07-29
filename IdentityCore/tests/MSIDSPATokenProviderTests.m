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
#import "MSIDSPATokenProvider.h"
#import "MSIDSPATokenAcquiring.h"
#import "MSIDLocalSPATokenAcquirer.h"
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

#pragma mark - Test seams (private methods under test)

// Surface the provider's private orchestration + response-shaping methods so the suite can exercise
// them directly. Only calling (never overriding) these methods keeps the class-under-test intact.
@interface MSIDSPATokenProvider (UnitTest)

- (void)acquireTokenSilentlyWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                   request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                   context:(nullable id<MSIDRequestContext>)context
                           completionBlock:(MSIDSPATokenProviderCompletionBlock)completionBlock;

- (NSString *)serializedResponseFromDictionary:(NSDictionary *)responseDictionary
                                 correlationId:(nullable NSUUID *)correlationId
                                         error:(NSError *__autoreleasing *)error;

- (NSDictionary *)responseDictionaryFromResult:(MSIDTokenResult *)result
                                       request:(MSIDBrowserNativeMessageGetTokenRequest *)request;

@end

// Surface the local acquirer's production cache accessors so the shared-keychain expectations can be
// verified without touching production wiring.
@interface MSIDLocalSPATokenAcquirer (UnitTest)

- (MSIDDefaultTokenCacheAccessor *)defaultTokenCache:(nullable id<MSIDRequestContext>)context;
- (MSIDAccountMetadataCacheAccessor *)accountMetadataCache:(nullable id<MSIDRequestContext>)context;

@end

// Surface the silent request lookup seams used by the BART assertions.
@interface MSIDDefaultSilentTokenRequest (SPATokenProviderUnitTest)

- (MSIDRefreshToken *)familyRefreshTokenWithError:(NSError *__autoreleasing *)error;
- (MSIDBaseToken<MSIDRefreshableToken> *)appRefreshTokenWithError:(NSError *__autoreleasing *)error;

@end

#pragma mark - Stub acquisition backend (dependency-injected)

// A canned id<MSIDSPATokenAcquiring> injected into MSIDSPATokenProvider via initWithAcquirer:, so the
// provider's routing / fallback / response-shaping orchestration can be verified without touching the
// real silent engine, caches, or network. Request-parameter shaping reuses the real factory so routing
// reflects the incoming request exactly as production would.
@interface MSIDSPAStubAcquirer : NSObject <MSIDSPATokenAcquiring>

@property (nonatomic) BOOL silentCalled;
@property (nonatomic) BOOL interactiveCalled;
@property (nonatomic, nullable) MSIDSPATokenAcquisitionResult *silentOutcome;
@property (nonatomic, nullable) NSError *silentError;
@property (nonatomic, nullable) MSIDSPATokenAcquisitionResult *interactiveOutcome;
@property (nonatomic, nullable) NSError *interactiveError;
@property (nonatomic, nullable) MSIDSPAPreRouteDecision *decision;
@property (nonatomic, nullable) NSError *parametersError;

@end

@implementation MSIDSPAStubAcquirer

- (MSIDInteractiveTokenRequestParameters *)requestParametersForRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                                               context:(id<MSIDRequestContext>)context
                                                                 error:(NSError *__autoreleasing *)error
{
    if (self.parametersError)
    {
        if (error)
        {
            *error = self.parametersError;
        }
        return nil;
    }

    return [[MSIDBrowserNativeMessageGetTokenRequestParametersFactory sharedInstance] requestParametersWithRequest:request
                                                                                                      requestType:MSIDRequestBrokeredType
                                                                                    boundAppRefreshTokenRequested:YES
                                                                                            correlationIdOverride:context.correlationId
                                                                                                            error:error];
}

- (MSIDSPAPreRouteDecision *)preRouteDecisionForParameters:(__unused MSIDInteractiveTokenRequestParameters *)parameters
                                                   request:(__unused MSIDBrowserNativeMessageGetTokenRequest *)request
                                                   context:(__unused id<MSIDRequestContext>)context
{
    return self.decision ?: [MSIDSPAPreRouteDecision new];
}

- (void)acquireSilentWithParameters:(__unused MSIDInteractiveTokenRequestParameters *)parameters
                            request:(__unused MSIDBrowserNativeMessageGetTokenRequest *)request
                            context:(__unused id<MSIDRequestContext>)context
                    completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock
{
    self.silentCalled = YES;
    completionBlock(self.silentOutcome, self.silentError);
}

- (void)acquireInteractiveWithParameters:(__unused MSIDInteractiveTokenRequestParameters *)parameters
                                request:(__unused MSIDBrowserNativeMessageGetTokenRequest *)request
                                context:(id<MSIDRequestContext>)context
                        completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock
{
    self.interactiveCalled = YES;

    if (self.interactiveOutcome || self.interactiveError)
    {
        completionBlock(self.interactiveOutcome, self.interactiveError);
        return;
    }

    // Mirror the local acquirer's current stubbed interactive behavior.
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                     @"Interactive acquisition is required.",
                                     nil, nil, nil, context.correlationId, nil, NO);
    completionBlock(nil, error);
}

@end

#pragma mark - Silent engine fake (injected collaborator)

// Stands in for a real MSIDDefaultSilentTokenRequest so the local acquirer's silent orchestration can
// be driven with canned outcomes. Injected through MSIDLocalSPASilentTokenRequestProvider — the class
// under test is never subclassed.
@interface MSIDSPATestSilentRequestStub : MSIDDefaultSilentTokenRequest

@property (nonatomic, nullable) MSIDTokenResult *stubResult;
@property (nonatomic, nullable) NSError *stubError;

@end

@implementation MSIDSPATestSilentRequestStub

- (void)executeRequestWithCompletion:(MSIDRequestCompletionBlock)completionBlock
{
    completionBlock(self.stubResult, self.stubError);
}

@end

@interface MSIDSPATokenProviderTests : XCTestCase
@end

@implementation MSIDSPATokenProviderTests

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
    [[MSIDBrowserNativeMessageGetTokenRequestParametersFactory sharedInstance] requestParametersWithRequest:request
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

- (MSIDSPATokenAcquisitionResult *)outcomeWithCachedResult
{
    MSIDSPATokenAcquisitionResult *outcome = [MSIDSPATokenAcquisitionResult new];
    outcome.tokenResult = [self cachedTokenResult];
    return outcome;
}

- (MSIDSPATokenProvider *)providerWithAcquirer:(MSIDSPAStubAcquirer *)acquirer
{
    return [[MSIDSPATokenProvider alloc] initWithAcquirer:acquirer];
}

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

#pragma mark - Request validation

- (void)testAcquireToken_missingClientId_returnsError
{
    MSIDSPATokenProvider *provider = [MSIDSPATokenProvider new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.clientId = @"";

    XCTestExpectation *expectation = [self expectationWithDescription:@"validation error"];

    [provider acquireTokenWithRequest:request
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

- (void)testAcquireToken_missingAuthority_returnsError
{
    MSIDSPATokenProvider *provider = [MSIDSPATokenProvider new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.authority = nil;

    XCTestExpectation *expectation = [self expectationWithDescription:@"missing authority error"];

    [provider acquireTokenWithRequest:request
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
- (void)testAcquireToken_promptForcesUIAndUIProhibited_returnsInteractionRequired
{
    MSIDSPAStubAcquirer *acquirer = [MSIDSPAStubAcquirer new];
    MSIDSPATokenProvider *provider = [self providerWithAcquirer:acquirer];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.prompt = MSIDPromptTypeLogin;
    request.canShowUI = NO;

    XCTestExpectation *expectation = [self expectationWithDescription:@"interaction required"];

    [provider acquireTokenWithRequest:request
                              context:nil
                      completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    XCTAssertFalse(acquirer.silentCalled);
    XCTAssertFalse(acquirer.interactiveCalled);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// With no account identifier, UI-prohibited requests return interaction-required.
- (void)testAcquireToken_noAccountIdentifierAndUIProhibited_returnsInteractionRequired
{
    MSIDSPAStubAcquirer *acquirer = [MSIDSPAStubAcquirer new];
    MSIDSPATokenProvider *provider = [self providerWithAcquirer:acquirer];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.accountId = nil;
    request.canShowUI = NO;

    XCTestExpectation *expectation = [self expectationWithDescription:@"interaction required"];

    [provider acquireTokenWithRequest:request
                              context:nil
                      completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    XCTAssertFalse(acquirer.silentCalled);
    XCTAssertFalse(acquirer.interactiveCalled);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// A request that requires UI routes directly to interactive when UI is allowed.
- (void)testAcquireToken_promptForcesUIAndUIAllowed_routesToInteractive
{
    MSIDSPAStubAcquirer *acquirer = [MSIDSPAStubAcquirer new];
    MSIDSPATokenProvider *provider = [self providerWithAcquirer:acquirer];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.prompt = MSIDPromptTypeLogin;

    XCTestExpectation *expectation = [self expectationWithDescription:@"interactive"];

    [provider acquireTokenWithRequest:request
                              context:nil
                      completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    XCTAssertFalse(acquirer.silentCalled);
    XCTAssertTrue(acquirer.interactiveCalled);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// An eligible request uses the silent engine before considering interactive fallback.
- (void)testAcquireToken_eligibleRequest_routesToSilent
{
    MSIDSPAStubAcquirer *acquirer = [MSIDSPAStubAcquirer new];
    acquirer.silentOutcome = [self outcomeWithCachedResult];
    MSIDSPATokenProvider *provider = [self providerWithAcquirer:acquirer];

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    XCTestExpectation *expectation = [self expectationWithDescription:@"silent"];

    [provider acquireTokenWithRequest:request
                              context:nil
                      completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNotNil(response);
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    XCTAssertTrue(acquirer.silentCalled);
    XCTAssertFalse(acquirer.interactiveCalled);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// The in-process BART path can resolve a displayable-ID-only account and must not inherit
// the broker-local non-STS home-account requirement.
- (void)testAcquireToken_loginHintOnlyAccount_routesToSilent
{
    MSIDSPAStubAcquirer *acquirer = [MSIDSPAStubAcquirer new];
    acquirer.silentOutcome = [self outcomeWithCachedResult];
    MSIDSPATokenProvider *provider = [self providerWithAcquirer:acquirer];

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.accountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:request.loginHint
                                                              homeAccountId:nil];
    XCTestExpectation *expectation = [self expectationWithDescription:@"login hint silent"];

    [provider acquireTokenWithRequest:request
                              context:nil
                      completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNotNil(response);
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    XCTAssertTrue(acquirer.silentCalled);
    XCTAssertFalse(acquirer.interactiveCalled);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// When silent acquisition requires interaction and UI is allowed, the provider falls back exactly once.
- (void)testAcquireToken_silentRequiresInteractionAndUIAllowed_fallsBackToInteractive
{
    MSIDSPAStubAcquirer *acquirer = [MSIDSPAStubAcquirer new];
    acquirer.silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                           @"User interaction is required", nil, nil, nil, nil, nil, NO);
    MSIDSPATokenProvider *provider = [self providerWithAcquirer:acquirer];

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    XCTestExpectation *expectation = [self expectationWithDescription:@"interactive fallback"];

    [provider acquireTokenWithRequest:request
                              context:nil
                      completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    XCTAssertTrue(acquirer.silentCalled);
    XCTAssertTrue(acquirer.interactiveCalled);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

- (void)testAcquireToken_silentRequiresInteractionAndUIProhibited_returnsInteractionRequired
{
    MSIDSPAStubAcquirer *acquirer = [MSIDSPAStubAcquirer new];
    acquirer.silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                           @"User interaction is required", nil, nil, nil, nil, nil, NO);
    MSIDSPATokenProvider *provider = [self providerWithAcquirer:acquirer];

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.canShowUI = NO;
    XCTestExpectation *expectation = [self expectationWithDescription:@"interaction required without fallback"];

    [provider acquireTokenWithRequest:request
                              context:nil
                      completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertEqual(error, acquirer.silentError);
        [expectation fulfill];
    }];

    XCTAssertTrue(acquirer.silentCalled);
    XCTAssertFalse(acquirer.interactiveCalled);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

- (void)testAcquireToken_promptNeverSilentRequiresInteraction_doesNotFallBackToInteractive
{
    MSIDSPAStubAcquirer *acquirer = [MSIDSPAStubAcquirer new];
    acquirer.silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                           @"User interaction is required", nil, nil, nil, nil, nil, NO);
    MSIDSPATokenProvider *provider = [self providerWithAcquirer:acquirer];

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.prompt = MSIDPromptTypeNever;
    request.canShowUI = YES;
    XCTestExpectation *expectation = [self expectationWithDescription:@"no interactive fallback"];

    [provider acquireTokenWithRequest:request
                              context:nil
                      completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    XCTAssertTrue(acquirer.silentCalled);
    XCTAssertFalse(acquirer.interactiveCalled);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

#pragma mark - Response shaping

- (void)testSerializedResponse_whenDictionaryIsNotValidJSON_returnsError
{
    MSIDSPATokenProvider *provider = [MSIDSPATokenProvider new];
    NSError *error = nil;

    NSString *response = [provider serializedResponseFromDictionary:@{@"invalid": NSDate.date}
                                                      correlationId:nil
                                                              error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testResponseDictionaryFromCachedResult_whenExpirationIsPresent_returnsStringValues
{
    MSIDSPATokenProvider *provider = [MSIDSPATokenProvider new];
    NSDictionary *response = [provider responseDictionaryFromResult:[self cachedTokenResult]
                                                            request:[self validRequest]];

    XCTAssertTrue([response[@"expires_on"] isKindOfClass:NSString.class]);
    XCTAssertTrue([response[@"expires_in"] isKindOfClass:NSString.class]);
}

- (void)testResponseDictionaryFromCachedResult_whenOptionalValuesAreMissing_omitsFields
{
    MSIDSPATokenProvider *provider = [MSIDSPATokenProvider new];
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

    NSDictionary *response = [provider responseDictionaryFromResult:result request:request];

    XCTAssertEqual(response.count, 0);
}

#pragma mark - Silent path orchestration (provider)

// When the backend returns an outcome, the provider serializes it into the GetToken response payload
// and reports success.
- (void)testAcquireTokenSilently_backendReturnsOutcome_returnsPayload
{
    MSIDSPAStubAcquirer *acquirer = [MSIDSPAStubAcquirer new];
    acquirer.silentOutcome = [self outcomeWithCachedResult];
    MSIDSPATokenProvider *provider = [self providerWithAcquirer:acquirer];

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

    XCTAssertTrue(acquirer.silentCalled);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// When the backend reports interaction is required and UI is prohibited, the provider returns the
// original error so the host can explicitly start an interactive request.
- (void)testAcquireTokenSilently_backendReturnsInteractionRequired_returnsOriginalError
{
    MSIDSPAStubAcquirer *acquirer = [MSIDSPAStubAcquirer new];
    acquirer.silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                           @"User interaction is required", nil, nil, nil, nil, nil, NO);
    MSIDSPATokenProvider *provider = [self providerWithAcquirer:acquirer];

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
        XCTAssertEqual(error, acquirer.silentError);
        [expectation fulfill];
    }];

    XCTAssertFalse(acquirer.interactiveCalled);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// A hard failure from the backend (not interaction-required) is wrapped and propagated to the caller.
- (void)testAcquireTokenSilently_backendReturnsHardError_propagatesError
{
    MSIDSPAStubAcquirer *acquirer = [MSIDSPAStubAcquirer new];
    acquirer.silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerOauth,
                                           @"server rejected the request", nil, nil, nil, nil, nil, NO);
    MSIDSPATokenProvider *provider = [self providerWithAcquirer:acquirer];

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
        XCTAssertEqualObjects(error.userInfo[NSUnderlyingErrorKey], acquirer.silentError);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

#pragma mark - Local acquirer (dependency-injected)

// The local backend surfaces the silent result as a normalized outcome and requests a bound refresh
// token on the injected engine.
- (void)testLocalAcquirer_silentReturnsResult_returnsOutcomeAndRequiresBoundRefreshToken
{
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDTokenResult *result = [self cachedTokenResult];

    __block MSIDSPATestSilentRequestStub *createdRequest = nil;
    MSIDLocalSPATokenAcquirer *acquirer =
    [[MSIDLocalSPATokenAcquirer alloc] initWithTokenCacheProvider:^MSIDDefaultTokenCacheAccessor *(__unused id<MSIDRequestContext> context) {
        return [self inMemoryTokenCache];
    }
                                     accountMetadataCacheProvider:^MSIDAccountMetadataCacheAccessor *(__unused id<MSIDRequestContext> context) {
        return [self inMemoryAccountMetadataCache];
    }
                                       silentTokenRequestProvider:^MSIDDefaultSilentTokenRequest *(MSIDInteractiveTokenRequestParameters *parameters,
                                                                                                   MSIDDefaultTokenCacheAccessor *tokenCache,
                                                                                                   MSIDAccountMetadataCacheAccessor *accountMetadataCache) {
        MSIDSPATestSilentRequestStub *stub =
        [[MSIDSPATestSilentRequestStub alloc] initWithRequestParameters:parameters
                                                          forceRefresh:NO
                                                          oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                tokenResponseValidator:[MSIDTokenResponseValidator new]
                                                            tokenCache:tokenCache
                                                  accountMetadataCache:accountMetadataCache];
        stub.stubResult = result;
        createdRequest = stub;
        return stub;
    }];

    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];
    XCTestExpectation *expectation = [self expectationWithDescription:@"silent outcome"];

    [acquirer acquireSilentWithParameters:parameters
                                  request:request
                                  context:nil
                          completionBlock:^(MSIDSPATokenAcquisitionResult *outcome, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(outcome);
        XCTAssertEqual(outcome.tokenResult, result);
        XCTAssertNotNil(outcome.fallbackRequestAccountUpn);
        [expectation fulfill];
    }];

    XCTAssertNotNil(createdRequest);
    XCTAssertTrue(createdRequest.requiresBoundRefreshToken);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// When the token cache is unavailable, the local backend returns interaction-required without
// constructing the silent engine.
- (void)testLocalAcquirer_cacheUnavailable_returnsInteractionRequired
{
    __block BOOL silentRequestBuilt = NO;
    MSIDLocalSPATokenAcquirer *acquirer =
    [[MSIDLocalSPATokenAcquirer alloc] initWithTokenCacheProvider:^MSIDDefaultTokenCacheAccessor *(__unused id<MSIDRequestContext> context) {
        return nil;
    }
                                     accountMetadataCacheProvider:^MSIDAccountMetadataCacheAccessor *(__unused id<MSIDRequestContext> context) {
        return nil;
    }
                                       silentTokenRequestProvider:^MSIDDefaultSilentTokenRequest *(__unused MSIDInteractiveTokenRequestParameters *parameters,
                                                                                                   __unused MSIDDefaultTokenCacheAccessor *tokenCache,
                                                                                                   __unused MSIDAccountMetadataCacheAccessor *accountMetadataCache) {
        silentRequestBuilt = YES;
        return nil;
    }];

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"interaction required"];

    [acquirer acquireSilentWithParameters:parameters
                                  request:request
                                  context:nil
                          completionBlock:^(MSIDSPATokenAcquisitionResult *outcome, NSError *error) {
        XCTAssertNil(outcome);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    XCTAssertFalse(silentRequestBuilt);
    [self waitForExpectations:@[expectation] timeout:5.0];
}

// The local backend passes a non-interaction-required engine failure through untouched (wrapping is
// the provider's responsibility).
- (void)testLocalAcquirer_silentReturnsHardError_passesErrorThrough
{
    NSError *engineError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerOauth,
                                           @"server rejected the request", nil, nil, nil, nil, nil, NO);

    MSIDLocalSPATokenAcquirer *acquirer =
    [[MSIDLocalSPATokenAcquirer alloc] initWithTokenCacheProvider:^MSIDDefaultTokenCacheAccessor *(__unused id<MSIDRequestContext> context) {
        return [self inMemoryTokenCache];
    }
                                     accountMetadataCacheProvider:^MSIDAccountMetadataCacheAccessor *(__unused id<MSIDRequestContext> context) {
        return [self inMemoryAccountMetadataCache];
    }
                                       silentTokenRequestProvider:^MSIDDefaultSilentTokenRequest *(MSIDInteractiveTokenRequestParameters *parameters,
                                                                                                   MSIDDefaultTokenCacheAccessor *tokenCache,
                                                                                                   MSIDAccountMetadataCacheAccessor *accountMetadataCache) {
        MSIDSPATestSilentRequestStub *stub =
        [[MSIDSPATestSilentRequestStub alloc] initWithRequestParameters:parameters
                                                          forceRefresh:NO
                                                          oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                tokenResponseValidator:[MSIDTokenResponseValidator new]
                                                            tokenCache:tokenCache
                                                  accountMetadataCache:accountMetadataCache];
        stub.stubError = engineError;
        return stub;
    }];

    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"hard error passthrough"];

    [acquirer acquireSilentWithParameters:parameters
                                  request:request
                                  context:nil
                          completionBlock:^(MSIDSPATokenAcquisitionResult *outcome, NSError *error) {
        XCTAssertNil(outcome);
        XCTAssertEqual(error, engineError);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

// Request-parameter shaping produces valid parameters for the incoming request.
- (void)testLocalAcquirer_requestParameters_returnsParameters
{
    MSIDLocalSPATokenAcquirer *acquirer = [MSIDLocalSPATokenAcquirer new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];

    NSError *error = nil;
    MSIDInteractiveTokenRequestParameters *parameters = [acquirer requestParametersForRequest:request context:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    XCTAssertNotNil(parameters.accountIdentifier);
}

// The pre-route decision is an all-defaults no-op on the local path.
- (void)testLocalAcquirer_preRouteDecision_isNoOp
{
    MSIDLocalSPATokenAcquirer *acquirer = [MSIDLocalSPATokenAcquirer new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];

    MSIDSPAPreRouteDecision *decision = [acquirer preRouteDecisionForParameters:parameters request:request context:nil];

    XCTAssertNotNil(decision);
    XCTAssertFalse(decision.forceInteractive);
    XCTAssertNil(decision.resolvedAccountIdentifier);
    XCTAssertNil(decision.earlyError);
}

// Interactive acquisition is not yet implemented and surfaces interaction-required.
- (void)testLocalAcquirer_interactive_returnsInteractionRequired
{
    MSIDLocalSPATokenAcquirer *acquirer = [MSIDLocalSPATokenAcquirer new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersForRequest:request];

    XCTestExpectation *expectation = [self expectationWithDescription:@"interactive not implemented"];

    [acquirer acquireInteractiveWithParameters:parameters
                                       request:request
                                       context:nil
                               completionBlock:^(MSIDSPATokenAcquisitionResult *outcome, NSError *error) {
        XCTAssertNil(outcome);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

#if TARGET_OS_IPHONE

- (void)testLocalAcquirerDefaultCacheAccessors_useSharedAdalKeychainGroup
{
    MSIDLocalSPATokenAcquirer *acquirer = [MSIDLocalSPATokenAcquirer new];

    // The keychain data source stores the team-prefixed access group, so build the
    // expected value with the same helper the production cache uses.
    NSString *expectedKeychainGroup = [[MSIDKeychainUtil sharedInstance] accessGroup:[MSIDKeychainTokenCache defaultKeychainGroup]];

    MSIDDefaultTokenCacheAccessor *tokenCache = [acquirer defaultTokenCache:nil];
    XCTAssertNotNil(tokenCache);
    XCTAssertEqualObjects([(NSObject *)tokenCache.accountCredentialCache.dataSource valueForKey:@"keychainGroup"],
                          expectedKeychainGroup);

    MSIDAccountMetadataCacheAccessor *accountMetadataCache = [acquirer accountMetadataCache:nil];
    XCTAssertNotNil(accountMetadataCache);

    id metadataCache = [accountMetadataCache valueForKey:@"metadataCache"];
    XCTAssertEqualObjects([[metadataCache valueForKey:@"dataSource"] valueForKey:@"keychainGroup"],
                          expectedKeychainGroup);
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
