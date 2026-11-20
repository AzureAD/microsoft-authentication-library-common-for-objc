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
#import "MSIDDefaultSilentTokenRequest.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDRefreshToken.h"
#import "MSIDBoundRefreshToken.h"
#import "MSIDBaseToken.h"
#import "MSIDRefreshableToken.h"
#import "MSIDTestIdentifiers.h"
#import "NSString+MSIDTestUtil.h"

#if TARGET_OS_OSX
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDTestURLSession.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "MSIDAccount.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDLRUCache.h"
#import "MSIDIdToken.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDPrimaryRefreshToken.h"
#endif

@interface MSIDDefaultSilentTokenRequest (BoundRefreshTokenTests)

- (MSIDRefreshToken *)familyRefreshTokenWithError:(NSError *__autoreleasing *)error;
- (MSIDBaseToken<MSIDRefreshableToken> *)appRefreshTokenWithError:(NSError *__autoreleasing *)error;

@end

@interface MSIDBoundRefreshTokenCacheAccessorMock : MSIDDefaultTokenCacheAccessor

@property (nonatomic) MSIDRefreshToken *refreshToken;
@property (nonatomic) NSUInteger refreshTokenLookupCount;

@end

@implementation MSIDBoundRefreshTokenCacheAccessorMock

- (MSIDRefreshToken *)getRefreshTokenWithAccount:(__unused MSIDAccountIdentifier *)account
                                        familyId:(__unused NSString *)familyId
                                   configuration:(__unused MSIDConfiguration *)configuration
                                         context:(__unused id<MSIDRequestContext>)context
                                           error:(__unused NSError *__autoreleasing *)error
{
    self.refreshTokenLookupCount++;
    return self.refreshToken;
}

@end

@interface MSIDDefaultSilentTokenRequestBoundRefreshTokenTests : XCTestCase

@end

@implementation MSIDDefaultSilentTokenRequestBoundRefreshTokenTests

- (MSIDBoundRefreshTokenCacheAccessorMock *)tokenCacheWithRefreshToken:(MSIDRefreshToken *)refreshToken
{
    MSIDBoundRefreshTokenCacheAccessorMock *tokenCache =
    [[MSIDBoundRefreshTokenCacheAccessorMock alloc] initWithDataSource:[MSIDTestCacheDataSource new]
                                                   otherCacheAccessors:nil];
    tokenCache.refreshToken = refreshToken;
    return tokenCache;
}

- (MSIDDefaultSilentTokenRequest *)silentRequestWithTokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
{
    MSIDRequestParameters *parameters = [MSIDRequestParameters new];
    parameters.authority = [DEFAULT_TEST_AUTHORITY_GUID aadAuthority];
    parameters.clientId = @"client-id";
    parameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                                          homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    MSIDAccountMetadataCacheAccessor *metadataCache =
    [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:[MSIDTestCacheDataSource new]];

    return [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:parameters
                                                               forceRefresh:NO
                                                               oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                     tokenResponseValidator:[MSIDTokenResponseValidator new]
                                                                 tokenCache:tokenCache
                                                       accountMetadataCache:metadataCache];
}

- (void)testRequiresBoundRefreshToken_whenNotSet_shouldAllowRegularRefreshToken
{
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    MSIDBoundRefreshTokenCacheAccessorMock *tokenCache = [self tokenCacheWithRefreshToken:refreshToken];
    MSIDDefaultSilentTokenRequest *silentRequest = [self silentRequestWithTokenCache:tokenCache];

    XCTAssertFalse(silentRequest.requiresBoundRefreshToken);
    XCTAssertEqual([silentRequest appRefreshTokenWithError:nil], refreshToken);
    XCTAssertEqual(tokenCache.refreshTokenLookupCount, 1u);
}

- (void)testRequiresBoundRefreshToken_whenRegularRefreshTokenFound_shouldRejectToken
{
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    MSIDBoundRefreshTokenCacheAccessorMock *tokenCache = [self tokenCacheWithRefreshToken:refreshToken];
    MSIDDefaultSilentTokenRequest *silentRequest = [self silentRequestWithTokenCache:tokenCache];
    silentRequest.requiresBoundRefreshToken = YES;

    XCTAssertNil([silentRequest appRefreshTokenWithError:nil]);
    XCTAssertEqual(tokenCache.refreshTokenLookupCount, 1u);
}

- (void)testRequiresBoundRefreshToken_whenBoundRefreshTokenFound_shouldReturnToken
{
    MSIDRefreshToken *regularRefreshToken = [MSIDRefreshToken new];
    MSIDBoundRefreshToken *refreshToken = [[MSIDBoundRefreshToken alloc] initWithRefreshToken:regularRefreshToken
                                                                               boundDeviceId:@"device-id"];
    MSIDBoundRefreshTokenCacheAccessorMock *tokenCache = [self tokenCacheWithRefreshToken:refreshToken];
    MSIDDefaultSilentTokenRequest *silentRequest = [self silentRequestWithTokenCache:tokenCache];
    silentRequest.requiresBoundRefreshToken = YES;

    XCTAssertEqual([silentRequest appRefreshTokenWithError:nil], refreshToken);
    XCTAssertEqual(tokenCache.refreshTokenLookupCount, 1u);
}

- (void)testRequiresBoundRefreshToken_whenFamilyRefreshTokenRequested_shouldSkipLookup
{
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    MSIDBoundRefreshTokenCacheAccessorMock *tokenCache = [self tokenCacheWithRefreshToken:refreshToken];
    MSIDDefaultSilentTokenRequest *silentRequest = [self silentRequestWithTokenCache:tokenCache];
    silentRequest.requiresBoundRefreshToken = YES;

    XCTAssertNil([silentRequest familyRefreshTokenWithError:nil]);
    XCTAssertEqual(tokenCache.refreshTokenLookupCount, 0u);
}

@end

#if TARGET_OS_OSX
@interface MSIDDefaultSilentTokenRequestCacheFlowTests : XCTestCase

@property (nonatomic) MSIDTestCacheDataSource *dataSource;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nonatomic) MSIDRequestParameters *parameters;

@end

@implementation MSIDDefaultSilentTokenRequestCacheFlowTests

- (void)setUp
{
    [super setUp];
    self.dataSource = [MSIDTestCacheDataSource new];
    self.tokenCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:self.dataSource otherCacheAccessors:nil];
    self.parameters = [MSIDRequestParameters new];
    self.parameters.authority = [DEFAULT_TEST_AUTHORITY_GUID aadAuthority];
    self.parameters.clientId = @"my_client_id";
    self.parameters.target = @"user.read tasks.read";
    self.parameters.oidcScope = @"openid profile offline_access";
    self.parameters.redirectUri = @"my_redirect_uri";
    self.parameters.correlationId = [NSUUID UUID];
    self.parameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                             homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:@"v2.0" forKey:@"aadApiVersion"];
}

- (void)tearDown
{
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
    [MSIDTestURLSession clearResponses];
    [[MSIDAadAuthorityCache sharedInstance] removeAllObjects];
    [[MSIDAuthority openIdConfigurationCache] removeAllObjects];
    [[MSIDLRUCache sharedInstance] removeAllObjects:nil];
    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:nil forKey:@"aadApiVersion"];
    [self.dataSource reset];
    [super tearDown];
}

- (MSIDDefaultSilentTokenRequest *)requestWithForceRefresh:(BOOL)forceRefresh
{
    MSIDAccountMetadataCacheAccessor *metadata =
    [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:[MSIDTestCacheDataSource new]];
    return [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:self.parameters
                                                               forceRefresh:forceRefresh
                                                               oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                     tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                 tokenCache:self.tokenCache
                                                       accountMetadataCache:metadata];
}

- (void)saveTokensExpiringIn:(NSString *)expiresIn
{
    [self saveTokensExpiringIn:expiresIn familyId:nil];
}

- (void)saveTokensExpiringIn:(NSString *)expiresIn familyId:(NSString *)familyId
{
    [self addDiscovery];
    XCTestExpectation *resolved = [self expectationWithDescription:@"resolve cache environment"];
    [self.parameters.authority resolveAndValidate:NO
                                userPrincipalName:self.parameters.accountIdentifier.displayableId
                                          context:self.parameters
                                  completionBlock:^(__unused NSURL *endpoint, __unused BOOL validated, NSError *error)
    {
        XCTAssertNil(error);
        [resolved fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];

    NSDictionary *response = [MSIDTestURLResponse tokenResponseWithAT:nil
                                                            responseRT:nil
                                                            responseID:nil
                                                         responseScope:@"user.read tasks.read"
                                                    responseClientInfo:nil
                                                             expiresIn:expiresIn
                                                                  foci:familyId
                                                          extExpiresIn:self.parameters.extendedLifetimeEnabled ? @"3600000" : nil];
    NSError *error = nil;
    MSIDAADV2TokenResponse *tokenResponse = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:response error:&error];
    XCTAssertNotNil(tokenResponse);
    XCTAssertNil(error);
    BOOL saved = [self.tokenCache saveTokensWithConfiguration:self.parameters.msidConfiguration
                                                     response:tokenResponse
                                                      factory:[MSIDAADV2Oauth2Factory new]
                                                      context:self.parameters
                                                        error:&error];
    XCTAssertTrue(saved, @"%@", error);
    XCTAssertNil(error);
}

- (void)addDiscovery
{
    [MSIDTestURLSession addResponse:[MSIDTestURLResponse discoveryResponseForAuthority:DEFAULT_TEST_AUTHORITY_GUID]];
}

- (void)testExecute_whenAccountMissing_returnsCorrelatedErrorWithoutNetwork
{
    self.parameters.accountIdentifier = nil;
    XCTestExpectation *completion = [self expectationWithDescription:@"missing account"];
    [[self requestWithForceRefresh:NO] executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        XCTAssertNil(result);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorMissingAccountParameter);
        XCTAssertEqualObjects(error.userInfo[MSIDCorrelationIdKey], self.parameters.correlationId.UUIDString);
        [completion fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqual(self.dataSource.allDefaultAccessTokens.count, 0u);
}

- (void)testExecute_whenCachedTokenValid_returnsCachedAccountAndTokensWithoutRedemption
{
    [self saveTokensExpiringIn:@"3600"];
    XCTestExpectation *completion = [self expectationWithDescription:@"cached access token"];
    [[self requestWithForceRefresh:NO] executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result.accessToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, DEFAULT_TEST_HOME_ACCOUNT_ID);
        XCTAssertNotNil(result.rawIdToken);
        XCTAssertFalse(result.extendedLifeTimeToken);
        [completion fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqual(self.dataSource.allDefaultAccessTokens.count, 1u);
}

- (void)assertSuccessfulRefreshWithForceRefresh:(BOOL)forceRefresh expiresIn:(NSString *)expiresIn
{
    [self saveTokensExpiringIn:expiresIn];
    [MSIDTestURLSession addResponse:[MSIDTestURLResponse oidcResponseForAuthority:DEFAULT_TEST_AUTHORITY_GUID]];
    [MSIDTestURLSession addResponse:[MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                           requestClaims:nil
                                                                           requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                              responseAT:@"renewed-access-token"
                                                                              responseRT:@"rotated-refresh-token"
                                                                              responseID:nil
                                                                           responseScope:@"user.read tasks.read"
                                                                      responseClientInfo:nil
                                                                                     url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                            responseCode:200
                                                                               expiresIn:nil]];
    XCTestExpectation *completion = [self expectationWithDescription:@"refresh access token"];
    [[self requestWithForceRefresh:forceRefresh] executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"renewed-access-token");
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"rotated-refresh-token");
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, DEFAULT_TEST_HOME_ACCOUNT_ID);
        XCTAssertEqualObjects(result.authority.url.absoluteString, DEFAULT_TEST_AUTHORITY_GUID);
        XCTAssertFalse(result.extendedLifeTimeToken);
        [completion fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    NSError *error = nil;
    MSIDAccessToken *cached = [self.tokenCache getAccessTokenForAccount:self.parameters.accountIdentifier
                                                        configuration:self.parameters.msidConfiguration
                                                              context:self.parameters
                                                                error:&error];
    XCTAssertNotNil(cached);
    XCTAssertNil(error);
    XCTAssertEqualObjects(cached.accessToken, @"renewed-access-token");
    XCTAssertEqual(self.dataSource.allDefaultAccessTokens.count, 1u);
    XCTAssertEqual(self.dataSource.allDefaultRefreshTokens.count, 1u);
}

- (void)testExecute_whenAccessTokenExpired_renewsAndReplacesCachedTokens
{
    [self assertSuccessfulRefreshWithForceRefresh:NO expiresIn:@"1"];
}

- (void)testExecute_whenForceRefreshRequested_doesNotReturnValidCachedToken
{
    [self assertSuccessfulRefreshWithForceRefresh:YES expiresIn:@"3600"];
}

- (void)assertRefreshFailure:(NSString *)oauthError
                    subError:(NSString *)subError
                expectedCode:(MSIDErrorCode)expectedCode
         removesRefreshToken:(BOOL)removesRefreshToken
{
    [self saveTokensExpiringIn:@"1"];
    [MSIDTestURLSession addResponse:[MSIDTestURLResponse oidcResponseForAuthority:DEFAULT_TEST_AUTHORITY_GUID]];
    [MSIDTestURLSession addResponse:[MSIDTestURLResponse errorRefreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                responseError:oauthError
                                                                                  description:@"refresh rejected"
                                                                                     subError:subError
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200]];
    XCTestExpectation *completion = [self expectationWithDescription:@"refresh rejected"];
    [[self requestWithForceRefresh:NO] executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        XCTAssertNil(result);
        XCTAssertEqualObjects(error.domain, expectedCode == MSIDErrorInteractionRequired ? MSIDErrorDomain : MSIDOAuthErrorDomain);
        XCTAssertEqual(error.code, expectedCode);
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], oauthError);
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], subError);
        if (expectedCode == MSIDErrorInteractionRequired)
        {
            XCTAssertNotNil(error.userInfo[NSUnderlyingErrorKey]);
        }
        [completion fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqual(self.dataSource.allDefaultAccessTokens.count, 0u);
    XCTAssertEqual(self.dataSource.allDefaultRefreshTokens.count, removesRefreshToken ? 0u : 1u);
    XCTAssertEqual(self.dataSource.allAccounts.count, 1u);
}

- (void)testExecute_whenRefreshRequiresInteraction_removesExpiredAccessTokenButPreservesRefreshToken
{
    [self assertRefreshFailure:@"invalid_grant" subError:@"consent_required"
                  expectedCode:MSIDErrorInteractionRequired removesRefreshToken:NO];
}

- (void)testExecute_whenRefreshTokenInvalid_removesRejectedRefreshTokenButPreservesAccount
{
    [self assertRefreshFailure:@"invalid_grant" subError:@"bad_token"
                  expectedCode:MSIDErrorInteractionRequired removesRefreshToken:YES];
}

- (void)testExecute_whenClientInvalid_returnsNonInteractiveErrorAndPreservesRefreshToken
{
    [self assertRefreshFailure:@"invalid_client" subError:@""
                  expectedCode:MSIDErrorServerInvalidClient removesRefreshToken:NO];
}

- (void)testExecute_whenScopeInvalid_returnsNonInteractiveErrorAndPreservesRefreshToken
{
    [self assertRefreshFailure:@"invalid_scope" subError:@""
                  expectedCode:MSIDErrorServerInvalidScope removesRefreshToken:NO];
}

- (void)testExecute_whenServerUnavailable_returnsEligibleExtendedLifetimeTokenWithoutReplacingCache
{
    [self assertServerUnavailableFallbackWithExtendedLifetime:YES];
}

- (void)testExecute_whenProactiveRefreshFails_returnsUnexpiredTokenWithoutExtendedLifetime
{
    [self assertServerUnavailableFallbackWithExtendedLifetime:NO];
}

- (void)assertServerUnavailableFallbackWithExtendedLifetime:(BOOL)extendedLifetime
{
    self.parameters.extendedLifetimeEnabled = extendedLifetime;
    [self saveTokensExpiringIn:extendedLifetime ? @"1" : @"3600"];
    if (!extendedLifetime)
    {
        MSIDAccessToken *token = [self.tokenCache getAccessTokenForAccount:self.parameters.accountIdentifier
                                                            configuration:self.parameters.msidConfiguration
                                                                  context:self.parameters error:nil];
        XCTAssertNotNil(token);
        token.refreshOn = [NSDate dateWithTimeIntervalSince1970:946684800];
        XCTAssertTrue([self.tokenCache saveToken:token context:self.parameters error:nil]);
    }
    [MSIDTestURLSession addResponse:[MSIDTestURLResponse oidcResponseForAuthority:DEFAULT_TEST_AUTHORITY_GUID]];
    MSIDTestURLResponse *unavailable = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"must-not-be-cached"
                                                                                   responseRT:@"must-not-be-cached"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:500
                                                                                    expiresIn:nil];
    [MSIDTestURLSession addResponse:unavailable];
    [MSIDTestURLSession addResponse:unavailable];
    XCTestExpectation *completion = [self expectationWithDescription:@"extended lifetime fallback"];
    [[self requestWithForceRefresh:NO] executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqual(result.extendedLifeTimeToken, extendedLifetime);
        XCTAssertEqualObjects(result.accessToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, DEFAULT_TEST_HOME_ACCOUNT_ID);
        [completion fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqual(self.dataSource.allDefaultAccessTokens.count, 1u);
    XCTAssertEqual(self.dataSource.allDefaultRefreshTokens.count, 1u);
}

- (void)addRefreshForToken:(NSString *)refreshToken error:(NSString *)oauthError subError:(NSString *)subError
{
    if (oauthError)
    {
        [MSIDTestURLSession addResponse:[MSIDTestURLResponse errorRefreshTokenGrantResponseWithRT:refreshToken
                                                                                    requestClaims:nil
                                                                                    requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                    responseError:oauthError
                                                                                      description:@"refresh rejected"
                                                                                         subError:subError
                                                                                              url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                     responseCode:200]];
        return;
    }
    [MSIDTestURLSession addResponse:[MSIDTestURLResponse refreshTokenGrantResponseWithRT:refreshToken
                                                                           requestClaims:nil
                                                                           requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                              responseAT:@"renewed-access-token"
                                                                              responseRT:@"rotated-refresh-token"
                                                                              responseID:nil
                                                                           responseScope:@"user.read tasks.read"
                                                                      responseClientInfo:nil
                                                                                     url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                            responseCode:200 expiresIn:nil]];
}

- (MSIDRefreshToken *)cachedRefreshTokenForFamily:(NSString *)familyId
{
    NSError *error = nil;
    MSIDRefreshToken *token = [self.tokenCache getRefreshTokenWithAccount:self.parameters.accountIdentifier
                                                                  familyId:familyId
                                                             configuration:self.parameters.msidConfiguration
                                                                   context:self.parameters error:&error];
    XCTAssertNotNil(token);
    XCTAssertNil(error);
    return token;
}

- (void)testExecute_whenAppRefreshRejected_recoversWithDistinctFamilyRefreshToken
{
    [self saveTokensExpiringIn:@"1" familyId:@"1"];
    MSIDRefreshToken *familyToken = [self cachedRefreshTokenForFamily:@"1"];
    familyToken.refreshToken = @"family-refresh-token";
    XCTAssertTrue([self.tokenCache saveToken:familyToken context:self.parameters error:nil]);
    [MSIDTestURLSession addResponse:[MSIDTestURLResponse oidcResponseForAuthority:DEFAULT_TEST_AUTHORITY_GUID]];
    [self addRefreshForToken:DEFAULT_TEST_REFRESH_TOKEN error:@"invalid_grant" subError:@"consent_required"];
    [self addRefreshForToken:@"family-refresh-token" error:nil subError:nil];
    XCTestExpectation *completion = [self expectationWithDescription:@"family refresh recovery"];
    [[self requestWithForceRefresh:NO] executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"renewed-access-token");
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"rotated-refresh-token");
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, DEFAULT_TEST_HOME_ACCOUNT_ID);
        [completion fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqual(self.dataSource.allDefaultAccessTokens.count, 1u);
    XCTAssertEqualObjects([self cachedRefreshTokenForFamily:nil].refreshToken, @"rotated-refresh-token");
}

- (void)testExecute_whenFamilyClientMismatch_persistsFamilyOptOutAndSkipsSecondRedemption
{
    [self saveTokensExpiringIn:@"1" familyId:@"1"];
    XCTAssertTrue([self.tokenCache removeToken:[self cachedRefreshTokenForFamily:nil] context:self.parameters error:nil]);
    [MSIDTestURLSession addResponse:[MSIDTestURLResponse oidcResponseForAuthority:DEFAULT_TEST_AUTHORITY_GUID]];
    [self addRefreshForToken:DEFAULT_TEST_REFRESH_TOKEN error:@"invalid_grant" subError:@"client_mismatch"];
    XCTestExpectation *first = [self expectationWithDescription:@"family client mismatch"];
    [[self requestWithForceRefresh:NO] executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        XCTAssertNil(result);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"client_mismatch");
        [first fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    NSError *cacheError = nil;
    NSArray<MSIDAppMetadataCacheItem *> *metadata = [self.tokenCache getAppMetadataEntries:self.parameters.msidConfiguration
                                                                                   context:self.parameters error:&cacheError];
    XCTAssertNotNil(metadata);
    XCTAssertNil(cacheError);
    XCTAssertTrue(metadata.count > 0);
    for (MSIDAppMetadataCacheItem *item in metadata)
    {
        XCTAssertEqualObjects(item.familyId, @"");
    }
    XCTestExpectation *second = [self expectationWithDescription:@"skip opted-out family"];
    [[self requestWithForceRefresh:NO] executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        XCTAssertNil(result);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        XCTAssertNil(error.userInfo[MSIDOAuthSubErrorKey]);
        [second fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqual(self.dataSource.allDefaultRefreshTokens.count, 1u);
}

- (void)testExecute_whenCachedIDTokenMissing_recoversByRefreshingInsteadOfReturningPartialResult
{
    [self saveTokensExpiringIn:@"3600"];
    MSIDIdToken *idToken = [self.tokenCache getIDTokenForAccount:self.parameters.accountIdentifier
                                                   configuration:self.parameters.msidConfiguration
                                                     idTokenType:MSIDIDTokenType context:self.parameters error:nil];
    XCTAssertNotNil(idToken);
    XCTAssertTrue([self.tokenCache removeToken:idToken context:self.parameters error:nil]);
    [MSIDTestURLSession addResponse:[MSIDTestURLResponse oidcResponseForAuthority:DEFAULT_TEST_AUTHORITY_GUID]];
    [self addRefreshForToken:DEFAULT_TEST_REFRESH_TOKEN error:nil subError:nil];
    XCTestExpectation *completion = [self expectationWithDescription:@"recover missing id token"];
    [[self requestWithForceRefresh:NO] executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"renewed-access-token");
        XCTAssertNotNil(result.rawIdToken);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"rotated-refresh-token");
        [completion fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqual(self.dataSource.allDefaultIDTokens.count, 1u);
}

- (void)testExecute_whenLocalRefreshForbidden_doesNotRedeemOrDeleteValidCachedTokens
{
    [self saveTokensExpiringIn:@"3600"];
    MSIDDefaultSilentTokenRequest *request = [self requestWithForceRefresh:YES];
    request.skipLocalRt = YES;
    XCTestExpectation *completion = [self expectationWithDescription:@"local refresh forbidden"];
    [request executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        XCTAssertNil(result);
        XCTAssertNil(error);
        [completion fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqual(self.dataSource.allDefaultAccessTokens.count, 1u);
    XCTAssertEqual(self.dataSource.allDefaultRefreshTokens.count, 1u);
}

- (MSIDPrimaryRefreshToken *)primaryRefreshTokenForAccount:(MSIDAccountIdentifier *)account token:(NSString *)secret
{
    MSIDPrimaryRefreshToken *token = [MSIDPrimaryRefreshToken new];
    token.accountIdentifier = account;
    token.environment = [self.parameters.authority cacheEnvironmentWithContext:self.parameters];
    token.clientId = self.parameters.clientId;
    token.refreshToken = secret;
    token.sessionKey = [@"test-session-key" dataUsingEncoding:NSUTF8StringEncoding];
    token.prtProtocolVersion = @"3.0";
    token.expiresOn = [NSDate dateWithTimeIntervalSince1970:4102444800];
    return token;
}

- (void)testPrimaryRefreshTokens_filterByAccountWithoutReturningOtherAccountsCredentials
{
    [self saveTokensExpiringIn:@"3600"];
    MSIDPrimaryRefreshToken *first = [self primaryRefreshTokenForAccount:self.parameters.accountIdentifier token:@"primary-one"];
    MSIDAccountIdentifier *otherAccount = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"other@contoso.com"
                                                                                homeAccountId:@"other.tenant"];
    MSIDPrimaryRefreshToken *second = [self primaryRefreshTokenForAccount:otherAccount token:@"primary-two"];
    XCTAssertTrue([self.tokenCache saveToken:first context:self.parameters error:nil]);
    XCTAssertTrue([self.tokenCache saveToken:second context:self.parameters error:nil]);
    NSError *error = nil;
    NSArray<MSIDPrimaryRefreshToken *> *all = [self.tokenCache getPrimaryRefreshTokensForConfiguration:self.parameters.msidConfiguration
                                                                                                context:self.parameters error:&error];
    XCTAssertNotNil(all);
    XCTAssertNil(error);
    XCTAssertEqual(all.count, 2u);
    NSArray<MSIDPrimaryRefreshToken *> *filtered =
    [self.tokenCache getPrimaryRefreshTokensForConfiguration:self.parameters.msidConfiguration
                                                       account:self.parameters.accountIdentifier
                                                       context:self.parameters error:&error];
    XCTAssertNotNil(filtered);
    XCTAssertNil(error);
    XCTAssertEqual(filtered.count, 1u);
    XCTAssertEqualObjects(filtered.firstObject.refreshToken, @"primary-one");
    XCTAssertEqualObjects(filtered.firstObject.sessionKey, first.sessionKey);
}

- (void)testPrimaryRefreshTokenValidation_preservesRotatedTokenAndRemovesOnlyMatchingVersion
{
    [self saveTokensExpiringIn:@"3600"];
    MSIDPrimaryRefreshToken *original = [self primaryRefreshTokenForAccount:self.parameters.accountIdentifier token:@"primary-old"];
    XCTAssertTrue([self.tokenCache saveToken:original context:self.parameters error:nil]);
    MSIDPrimaryRefreshToken *rotated = [self primaryRefreshTokenForAccount:self.parameters.accountIdentifier token:@"primary-rotated"];
    XCTAssertTrue([self.tokenCache saveToken:rotated context:self.parameters error:nil]);
    NSError *error = nil;
    BOOL removed = [self.tokenCache validateAndRemovePrimaryRefreshToken:original context:self.parameters error:&error];
    XCTAssertTrue(removed);
    XCTAssertNil(error);
    MSIDPrimaryRefreshToken *retained = [self.tokenCache getPrimaryRefreshTokenWithAccount:self.parameters.accountIdentifier
                                                                                  familyId:nil
                                                                             configuration:self.parameters.msidConfiguration
                                                                                   context:self.parameters error:&error];
    XCTAssertNotNil(retained);
    XCTAssertNil(error);
    XCTAssertEqualObjects(retained.refreshToken, @"primary-rotated");
    removed = [self.tokenCache validateAndRemovePrimaryRefreshToken:retained context:self.parameters error:&error];
    XCTAssertTrue(removed);
    XCTAssertNil(error);
    NSArray *remaining = [self.tokenCache getPrimaryRefreshTokensForConfiguration:self.parameters.msidConfiguration
                                                                            context:self.parameters error:&error];
    XCTAssertNotNil(remaining);
    XCTAssertNil(error);
    XCTAssertEqual(remaining.count, 0u);
    XCTAssertEqual(self.dataSource.allDefaultRefreshTokens.count, 1u);
}

- (void)testPrimaryRefreshToken_whenOnlySecondaryCacheHasToken_readsFallbackAndClearsBothCaches
{
    [self saveTokensExpiringIn:@"3600"];
    MSIDDefaultTokenCacheAccessor *secondary =
    [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:[MSIDTestCacheDataSource new] otherCacheAccessors:nil];
    MSIDPrimaryRefreshToken *token = [self primaryRefreshTokenForAccount:self.parameters.accountIdentifier token:@"secondary-primary"];
    XCTAssertTrue([secondary saveToken:token context:self.parameters error:nil]);
    MSIDDefaultTokenCacheAccessor *combined =
    [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:self.dataSource otherCacheAccessors:@[secondary]];
    NSError *error = nil;
    MSIDPrimaryRefreshToken *result = [combined getPrimaryRefreshTokenWithAccount:self.parameters.accountIdentifier
                                                                           familyId:nil
                                                                      configuration:self.parameters.msidConfiguration
                                                                            context:self.parameters error:&error];
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    XCTAssertEqualObjects(result.refreshToken, @"secondary-primary");
    BOOL cleared = [combined clearCacheForAllAccountsWithContext:self.parameters error:&error];
    XCTAssertTrue(cleared);
    XCTAssertNil(error);
    NSArray *remaining = [secondary getPrimaryRefreshTokensForConfiguration:self.parameters.msidConfiguration
                                                                       context:self.parameters error:&error];
    XCTAssertNotNil(remaining);
    XCTAssertNil(error);
    XCTAssertEqual(remaining.count, 0u);
    XCTAssertEqual(self.dataSource.allAccounts.count, 0u);
    XCTAssertEqual(self.dataSource.allDefaultRefreshTokens.count, 0u);
}

- (void)testUpdateAppMetadata_createsThenReplacesFamilyWithoutLeavingStaleEntries
{
    [self saveTokensExpiringIn:@"3600"];
    MSIDDefaultTokenCacheAccessor *empty =
    [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:[MSIDTestCacheDataSource new] otherCacheAccessors:nil];
    for (NSString *familyId in @[@"1", @"2", @""])
    {
        NSError *error = nil;
        BOOL updated = [empty updateAppMetadataWithFamilyId:familyId
                                                     clientId:self.parameters.clientId
                                                    authority:self.parameters.authority
                                                      context:self.parameters error:&error];
        XCTAssertTrue(updated);
        XCTAssertNil(error);
        NSArray<MSIDAppMetadataCacheItem *> *entries = [empty getAppMetadataEntries:self.parameters.msidConfiguration
                                                                             context:self.parameters error:&error];
        XCTAssertNotNil(entries);
        XCTAssertNil(error);
        XCTAssertEqual(entries.count, 1u);
        XCTAssertEqualObjects(entries.firstObject.familyId, familyId);
        XCTAssertEqualObjects(entries.firstObject.clientId, self.parameters.clientId);
    }
}

- (void)testExecute_whenRefreshTokenMissing_returnsInteractionRequiredAndRemovesExpiredAccessToken
{
    [self saveTokensExpiringIn:@"1"];
    MSIDRefreshToken *refreshToken = [self.tokenCache getRefreshTokenWithAccount:self.parameters.accountIdentifier
                                                                       familyId:nil
                                                                  configuration:self.parameters.msidConfiguration
                                                                        context:self.parameters
                                                                          error:nil];
    XCTAssertNotNil(refreshToken);
    XCTAssertTrue([self.tokenCache removeToken:refreshToken context:self.parameters error:nil]);
    XCTestExpectation *completion = [self expectationWithDescription:@"missing refresh token"];
    [[self requestWithForceRefresh:NO] executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        XCTAssertNil(result);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [completion fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqual(self.dataSource.allDefaultAccessTokens.count, 0u);
    XCTAssertEqual(self.dataSource.allDefaultRefreshTokens.count, 0u);
    XCTAssertEqual(self.dataSource.allAccounts.count, 1u);
}

@end
#endif
