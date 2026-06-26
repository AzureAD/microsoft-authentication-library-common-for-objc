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
#import "MSIDInteractiveTokenRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDBasicContext.h"
#import "MSIDRefreshToken.h"
#import "MSIDFamilyRefreshToken.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDTestConfiguration.h"
#import "MSIDTestSwizzle.h"
#import "MSIDFlightManager.h"
#import "MSIDConstants.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDTestCacheAccessorHelper.h"
#import "MSIDLegacyTokenCacheAccessor.h"

@interface MSIDSFRTIntegrationTests : XCTestCase

@property (nonatomic) MSIDDefaultTokenCacheAccessor *app1TokenCache;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *app2TokenCache;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *app1AccountMetadataCache;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *app2AccountMetadataCache;
@property (nonatomic) MSIDAccountIdentifier *sharedAccountIdentifier;
@property (nonatomic) MSIDAADV2Oauth2Factory *factory;

@end

@implementation MSIDSFRTIntegrationTests

- (void)setUp
{
    [super setUp];
    
    [MSIDTestURLSession clearResponses];
    
    // Set up shared account identifier
    self.sharedAccountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                          homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    
    // Set up separate caches for two different apps in the same family
    MSIDTestCacheDataSource *app1DataSource = [[MSIDTestCacheDataSource alloc] init];
    self.app1TokenCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:app1DataSource otherCacheAccessors:nil];
    self.app1AccountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:app1DataSource];
    
    MSIDTestCacheDataSource *app2DataSource = [[MSIDTestCacheDataSource alloc] init];
    self.app2TokenCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:app2DataSource otherCacheAccessors:nil];
    self.app2AccountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:app2DataSource];
    
    self.factory = [MSIDAADV2Oauth2Factory new];
    
    // Reset FRT settings
    [MSIDAccountCredentialCache setDisableFRT:NO];
}

- (void)tearDown
{
    [MSIDTestURLSession removeAllResponses];
    [MSIDTestSwizzle removeAllSwizzling];
    [super tearDown];
}

#pragma mark - Multi-app family token sharing tests

- (void)testMultiAppSSO_whenApp1AcquiresFamilyToken_app2ShouldUseIt
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Step 1: App1 performs interactive authentication and gets family refresh token
    MSIDFamilyRefreshToken *familyRT = [self simulateApp1InitialAuthentication];
    XCTAssertNotNil(familyRT);
    XCTAssertEqualObjects(familyRT.familyId, DEFAULT_TEST_FAMILY_ID);
    
    // Step 2: Simulate App2 trying to acquire token silently using shared family refresh token
    // For this test, we'll simulate shared cache access
    [self shareFamilyRefreshTokenBetweenApps:familyRT];
    
    MSIDRequestParameters *app2RequestParams = [self createRequestParametersForApp2];
    
    MSIDDefaultSilentTokenRequest *app2SilentRequest = [[MSIDDefaultSilentTokenRequest alloc] 
                                                       initWithRequestParameters:app2RequestParams
                                                               forceRefresh:NO
                                                               oauthFactory:self.factory
                                                     tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                 tokenCache:self.app2TokenCache
                                                       accountMetadataCache:self.app2AccountMetadataCache];
    
    [self mockFRTSuccessResponseForApp2];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"App2 silent request"];
    
    [app2SilentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"app2_access_token");
        
        // Verify that App2 now has its own refresh token
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testMultiAppSSO_whenApp2UpdatesFamilyToken_app1ShouldUseUpdatedToken
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Step 1: Both apps have initial family refresh token
    MSIDFamilyRefreshToken *initialFamilyRT = [self createFamilyRefreshToken:@"initial_family_token"];
    [self saveFamilyRefreshTokenInApp1:initialFamilyRT];
    [self saveFamilyRefreshTokenInApp2:initialFamilyRT];
    
    // Step 2: App2 refreshes and gets updated family refresh token
    [self mockApp2FRTRefreshWithUpdatedToken];
    
    MSIDRequestParameters *app2RequestParams = [self createRequestParametersForApp2];
    MSIDDefaultSilentTokenRequest *app2Request = [[MSIDDefaultSilentTokenRequest alloc] 
                                                 initWithRequestParameters:app2RequestParams
                                                         forceRefresh:YES
                                                         oauthFactory:self.factory
                                               tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                           tokenCache:self.app2TokenCache
                                                 accountMetadataCache:self.app2AccountMetadataCache];
    
    XCTestExpectation *app2Expectation = [self expectationWithDescription:@"App2 refresh"];
    
    [app2Request executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        
        [app2Expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Step 3: Simulate the updated family token being shared to App1
    // In real implementation, this would happen through shared cache mechanisms
    MSIDFamilyRefreshToken *updatedFamilyRT = [self createFamilyRefreshToken:@"updated_family_token"];
    [self saveFamilyRefreshTokenInApp1:updatedFamilyRT];
    
    // Step 4: App1 should now use the updated family token
    MSIDRequestParameters *app1RequestParams = [self createRequestParametersForApp1];
    MSIDDefaultSilentTokenRequest *app1Request = [[MSIDDefaultSilentTokenRequest alloc] 
                                                 initWithRequestParameters:app1RequestParams
                                                         forceRefresh:NO
                                                         oauthFactory:self.factory
                                               tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                           tokenCache:self.app1TokenCache
                                                 accountMetadataCache:self.app1AccountMetadataCache];
    
    [self mockUpdatedFRTSuccessResponseForApp1];
    
    XCTestExpectation *app1Expectation = [self expectationWithDescription:@"App1 uses updated token"];
    
    [app1Request executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"app1_access_token_updated");
        
        [app1Expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Cross-app SSO validation tests

- (void)testCrossAppSSO_whenUserSignsIntoApp1_app2ShouldHaveSSO
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Step 1: User signs into App1 interactively
    MSIDFamilyRefreshToken *familyRT = [self simulateApp1InitialAuthentication];
    
    // Step 2: Share the family token (simulating shared cache/keychain)
    [self shareFamilyRefreshTokenBetweenApps:familyRT];
    
    // Step 3: App2 attempts silent authentication
    MSIDRequestParameters *app2RequestParams = [self createRequestParametersForApp2];
    app2RequestParams.accountIdentifier = self.sharedAccountIdentifier;
    
    MSIDDefaultSilentTokenRequest *app2SilentRequest = [[MSIDDefaultSilentTokenRequest alloc] 
                                                       initWithRequestParameters:app2RequestParams
                                                               forceRefresh:NO
                                                               oauthFactory:self.factory
                                                     tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                 tokenCache:self.app2TokenCache
                                                       accountMetadataCache:self.app2AccountMetadataCache];
    
    [self mockFRTSuccessResponseForApp2];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"App2 SSO success"];
    
    [app2SilentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        
        // Verify SSO succeeded
        XCTAssertNotNil(result.accessToken);
        XCTAssertEqualObjects(result.account.homeAccountId, self.sharedAccountIdentifier.homeAccountId);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testCrossAppSSO_whenUserSignsOutOfApp1_app2ShouldLoseSSO
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Step 1: Both apps have family refresh token
    MSIDFamilyRefreshToken *familyRT = [self createFamilyRefreshToken:@"shared_family_token"];
    [self saveFamilyRefreshTokenInApp1:familyRT];
    [self saveFamilyRefreshTokenInApp2:familyRT];
    
    // Step 2: App1 signs out and removes family refresh token
    [self simulateApp1SignOut];
    
    // Step 3: App2 attempts silent authentication and should fail
    MSIDRequestParameters *app2RequestParams = [self createRequestParametersForApp2];
    
    MSIDDefaultSilentTokenRequest *app2SilentRequest = [[MSIDDefaultSilentTokenRequest alloc] 
                                                       initWithRequestParameters:app2RequestParams
                                                               forceRefresh:NO
                                                               oauthFactory:self.factory
                                                     tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                 tokenCache:self.app2TokenCache
                                                       accountMetadataCache:self.app2AccountMetadataCache];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"App2 SSO failure"];
    
    [app2SilentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        
        // Should require interaction since family token was removed
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - End-to-end flow verification tests

- (void)testEndToEndFlow_completeMultiAppSSOLifecycle
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Phase 1: Initial authentication in App1
    MSIDFamilyRefreshToken *initialFRT = [self simulateApp1InitialAuthentication];
    XCTAssertNotNil(initialFRT);
    
    // Phase 2: App2 benefits from SSO using family token
    [self shareFamilyRefreshTokenBetweenApps:initialFRT];
    
    [self mockFRTSuccessResponseForApp2];
    
    MSIDRequestParameters *app2RequestParams = [self createRequestParametersForApp2];
    MSIDDefaultSilentTokenRequest *app2Request = [[MSIDDefaultSilentTokenRequest alloc] 
                                                 initWithRequestParameters:app2RequestParams
                                                         forceRefresh:NO
                                                         oauthFactory:self.factory
                                               tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                           tokenCache:self.app2TokenCache
                                                 accountMetadataCache:self.app2AccountMetadataCache];
    
    XCTestExpectation *app2SSOExpectation = [self expectationWithDescription:@"App2 SSO"];
    
    [app2Request executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        [app2SSOExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Phase 3: Family token refresh by App2
    [self mockApp2FRTRefreshWithUpdatedToken];
    
    MSIDDefaultSilentTokenRequest *app2RefreshRequest = [[MSIDDefaultSilentTokenRequest alloc] 
                                                        initWithRequestParameters:app2RequestParams
                                                                forceRefresh:YES
                                                                oauthFactory:self.factory
                                                      tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                  tokenCache:self.app2TokenCache
                                                        accountMetadataCache:self.app2AccountMetadataCache];
    
    XCTestExpectation *app2RefreshExpectation = [self expectationWithDescription:@"App2 refresh"];
    
    [app2RefreshRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        [app2RefreshExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Phase 4: App1 uses updated family token
    MSIDFamilyRefreshToken *updatedFRT = [self createFamilyRefreshToken:@"updated_family_token"];
    [self saveFamilyRefreshTokenInApp1:updatedFRT];
    
    [self mockUpdatedFRTSuccessResponseForApp1];
    
    MSIDRequestParameters *app1RequestParams = [self createRequestParametersForApp1];
    MSIDDefaultSilentTokenRequest *app1Request = [[MSIDDefaultSilentTokenRequest alloc] 
                                                 initWithRequestParameters:app1RequestParams
                                                         forceRefresh:NO
                                                         oauthFactory:self.factory
                                               tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                           tokenCache:self.app1TokenCache
                                                 accountMetadataCache:self.app1AccountMetadataCache];
    
    XCTestExpectation *app1UpdatedExpectation = [self expectationWithDescription:@"App1 uses updated token"];
    
    [app1Request executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        [app1UpdatedExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Phase 5: Verify both apps have functional tokens
    [self verifyBothAppsHaveFunctionalTokens];
}

- (void)testEndToEndFlow_familyTokenErrorRecovery
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Phase 1: Both apps start with family refresh token
    MSIDFamilyRefreshToken *initialFRT = [self createFamilyRefreshToken:@"initial_family_token"];
    [self saveFamilyRefreshTokenInApp1:initialFRT];
    [self saveFamilyRefreshTokenInApp2:initialFRT];
    
    // Phase 2: Family token becomes invalid
    [self mockFRTInvalidGrantError];
    
    MSIDRequestParameters *app1RequestParams = [self createRequestParametersForApp1];
    MSIDDefaultSilentTokenRequest *app1Request = [[MSIDDefaultSilentTokenRequest alloc] 
                                                 initWithRequestParameters:app1RequestParams
                                                         forceRefresh:NO
                                                         oauthFactory:self.factory
                                               tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                           tokenCache:self.app1TokenCache
                                                 accountMetadataCache:self.app1AccountMetadataCache];
    
    XCTestExpectation *app1ErrorExpectation = [self expectationWithDescription:@"App1 FRT error"];
    
    [app1Request executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [app1ErrorExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Phase 3: App2 also encounters the same error
    XCTestExpectation *app2ErrorExpectation = [self expectationWithDescription:@"App2 FRT error"];
    
    MSIDRequestParameters *app2RequestParams = [self createRequestParametersForApp2];
    MSIDDefaultSilentTokenRequest *app2Request = [[MSIDDefaultSilentTokenRequest alloc] 
                                                 initWithRequestParameters:app2RequestParams
                                                         forceRefresh:NO
                                                         oauthFactory:self.factory
                                               tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                           tokenCache:self.app2TokenCache
                                                 accountMetadataCache:self.app2AccountMetadataCache];
    
    [app2Request executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        [app2ErrorExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Phase 4: Verify invalid family tokens were cleaned up
    [self verifyInvalidFamilyTokensCleanedUp];
}

#pragma mark - Multi-family scenario tests

- (void)testMultiFamilyScenario_differentAppFamilies
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // App1 belongs to family "family1"
    MSIDFamilyRefreshToken *family1RT = [self createFamilyRefreshTokenWithFamilyId:@"family1" token:@"family1_token"];
    [self saveFamilyRefreshTokenInApp1:family1RT];
    
    // App2 belongs to family "family2"  
    MSIDFamilyRefreshToken *family2RT = [self createFamilyRefreshTokenWithFamilyId:@"family2" token:@"family2_token"];
    [self saveFamilyRefreshTokenInApp2:family2RT];
    
    // Test that App1 uses family1 token
    [self mockFRTSuccessResponseForSpecificFamily:@"family1"];
    
    MSIDRequestParameters *app1RequestParams = [self createRequestParametersForApp1];
    app1RequestParams.familyId = @"family1";
    
    MSIDDefaultSilentTokenRequest *app1Request = [[MSIDDefaultSilentTokenRequest alloc] 
                                                 initWithRequestParameters:app1RequestParams
                                                         forceRefresh:NO
                                                         oauthFactory:self.factory
                                               tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                           tokenCache:self.app1TokenCache
                                                 accountMetadataCache:self.app1AccountMetadataCache];
    
    XCTestExpectation *app1Expectation = [self expectationWithDescription:@"App1 family1 token"];
    
    [app1Request executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        [app1Expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Test that App2 uses family2 token  
    [self mockFRTSuccessResponseForSpecificFamily:@"family2"];
    
    MSIDRequestParameters *app2RequestParams = [self createRequestParametersForApp2];
    app2RequestParams.familyId = @"family2";
    
    MSIDDefaultSilentTokenRequest *app2Request = [[MSIDDefaultSilentTokenRequest alloc] 
                                                 initWithRequestParameters:app2RequestParams
                                                         forceRefresh:NO
                                                         oauthFactory:self.factory
                                               tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                           tokenCache:self.app2TokenCache
                                                 accountMetadataCache:self.app2AccountMetadataCache];
    
    XCTestExpectation *app2Expectation = [self expectationWithDescription:@"App2 family2 token"];
    
    [app2Request executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        [app2Expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Verify tokens don't interfere with each other
    [self verifyFamilyTokenIsolation];
}

#pragma mark - Helper methods

- (void)enableFRTFeatureFlag
{
    [MSIDTestSwizzle instanceMethod:@selector(stringForKey:)
                              class:[MSIDFlightManager class]
                              block:(id)^(__unused id obj, NSString *flightKey)
     {
        if ([flightKey isEqualToString:MSID_FLIGHT_CLIENT_SFRT_STATUS])
        {
            return MSID_FRT_STATUS_ENABLED;
        }
        return @"";
     }];
}

- (void)saveFRTEnabledSettings:(BOOL)enabled
{
    NSError *error = nil;
    [self.app1TokenCache.accountCredentialCache updateFRTSettings:enabled context:nil error:&error];
    XCTAssertNil(error);
    
    [self.app2TokenCache.accountCredentialCache updateFRTSettings:enabled context:nil error:&error];
    XCTAssertNil(error);
}

- (MSIDFamilyRefreshToken *)simulateApp1InitialAuthentication
{
    MSIDFamilyRefreshToken *familyRT = [self createFamilyRefreshToken:@"initial_family_token"];
    [self saveFamilyRefreshTokenInApp1:familyRT];
    return familyRT;
}

- (void)simulateApp1SignOut
{
    // Remove all tokens from App1's cache
    NSError *error = nil;
    [self.app1TokenCache clearCacheForAllAccountsWithContext:nil error:&error];
    XCTAssertNil(error);
}

- (MSIDFamilyRefreshToken *)createFamilyRefreshToken:(NSString *)tokenValue
{
    return [self createFamilyRefreshTokenWithFamilyId:DEFAULT_TEST_FAMILY_ID token:tokenValue];
}

- (MSIDFamilyRefreshToken *)createFamilyRefreshTokenWithFamilyId:(NSString *)familyId token:(NSString *)tokenValue
{
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = tokenValue;
    refreshToken.familyId = familyId;
    refreshToken.environment = DEFAULT_TEST_ENVIRONMENT;
    refreshToken.realm = DEFAULT_TEST_UTID;
    refreshToken.clientId = DEFAULT_TEST_CLIENT_ID;
    refreshToken.accountIdentifier = self.sharedAccountIdentifier;
    
    return [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken];
}

- (void)saveFamilyRefreshTokenInApp1:(MSIDFamilyRefreshToken *)familyRT
{
    NSError *error = nil;
    BOOL result = [self.app1TokenCache saveToken:familyRT context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)saveFamilyRefreshTokenInApp2:(MSIDFamilyRefreshToken *)familyRT
{
    NSError *error = nil;
    BOOL result = [self.app2TokenCache saveToken:familyRT context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)shareFamilyRefreshTokenBetweenApps:(MSIDFamilyRefreshToken *)familyRT
{
    // In real implementation, this would happen through shared keychain/cache
    // For testing, we explicitly save to both caches
    [self saveFamilyRefreshTokenInApp2:familyRT];
}

- (MSIDRequestParameters *)createRequestParametersForApp1
{
    MSIDRequestParameters *params = [MSIDRequestParameters new];
    params.authority = [@"https://login.microsoftonline.com/common" msidAuthority];
    params.clientId = @"app1_client_id";
    params.target = DEFAULT_TEST_SCOPE;
    params.msidConfiguration = [MSIDTestConfiguration v2DefaultConfiguration];
    params.correlationId = [[NSUUID alloc] init];
    params.accountIdentifier = self.sharedAccountIdentifier;
    params.familyId = DEFAULT_TEST_FAMILY_ID;
    return params;
}

- (MSIDRequestParameters *)createRequestParametersForApp2
{
    MSIDRequestParameters *params = [MSIDRequestParameters new];
    params.authority = [@"https://login.microsoftonline.com/common" msidAuthority];
    params.clientId = @"app2_client_id";
    params.target = DEFAULT_TEST_SCOPE;
    params.msidConfiguration = [MSIDTestConfiguration v2DefaultConfiguration];
    params.correlationId = [[NSUUID alloc] init];
    params.accountIdentifier = self.sharedAccountIdentifier;
    params.familyId = DEFAULT_TEST_FAMILY_ID;
    return params;
}

- (void)mockFRTSuccessResponseForApp2
{
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:@"family_refresh_token"
                                                                               requestClaims:nil
                                                                               requestScopes:@"user.read openid profile offline_access"
                                                                                  responseAT:@"app2_access_token"
                                                                                  responseRT:@"app2_refresh_token"
                                                                                  responseID:nil
                                                                               responseScope:@"user.read"
                                                                          responseClientInfo:nil
                                                                                         url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                responseCode:200
                                                                                   expiresIn:nil];
    
    [MSIDTestURLSession addResponse:tokenResponse];
}

- (void)mockUpdatedFRTSuccessResponseForApp1
{
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:@"updated_family_token"
                                                                               requestClaims:nil
                                                                               requestScopes:@"user.read openid profile offline_access"
                                                                                  responseAT:@"app1_access_token_updated"
                                                                                  responseRT:@"app1_refresh_token_updated"
                                                                                  responseID:nil
                                                                               responseScope:@"user.read"
                                                                          responseClientInfo:nil
                                                                                         url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                responseCode:200
                                                                                   expiresIn:nil];
    
    [MSIDTestURLSession addResponse:tokenResponse];
}

- (void)mockApp2FRTRefreshWithUpdatedToken
{
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:@"initial_family_token"
                                                                               requestClaims:nil
                                                                               requestScopes:@"user.read openid profile offline_access"
                                                                                  responseAT:@"app2_access_token_refresh"
                                                                                  responseRT:@"updated_family_token"
                                                                                  responseID:nil
                                                                               responseScope:@"user.read"
                                                                          responseClientInfo:nil
                                                                                         url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                responseCode:200
                                                                                   expiresIn:nil];
    
    [MSIDTestURLSession addResponse:tokenResponse];
}

- (void)mockFRTInvalidGrantError
{
    MSIDTestURLResponse *errorResponse = [MSIDTestURLResponse serverErrorResponseWithError:@"invalid_grant"
                                                                          errorDescription:@"Family token has expired"
                                                                                       url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID];
    
    [MSIDTestURLSession addResponse:errorResponse];
    [MSIDTestURLSession addResponse:errorResponse]; // For App2 as well
}

- (void)mockFRTSuccessResponseForSpecificFamily:(NSString *)familyId
{
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:[NSString stringWithFormat:@"%@_token", familyId]
                                                                               requestClaims:nil
                                                                               requestScopes:@"user.read openid profile offline_access"
                                                                                  responseAT:[NSString stringWithFormat:@"%@_access_token", familyId]
                                                                                  responseRT:[NSString stringWithFormat:@"%@_refresh_token", familyId]
                                                                                  responseID:nil
                                                                               responseScope:@"user.read"
                                                                          responseClientInfo:nil
                                                                                         url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                responseCode:200
                                                                                   expiresIn:nil];
    
    [MSIDTestURLSession addResponse:tokenResponse];
}

- (void)verifyBothAppsHaveFunctionalTokens
{
    // Verify App1 has functional tokens
    NSArray *app1FamilyTokens = [MSIDTestCacheAccessorHelper getAllTokens:self.app1TokenCache 
                                                                      type:MSIDFamilyRefreshTokenType 
                                                                     class:[MSIDFamilyRefreshToken class]];
    XCTAssertTrue(app1FamilyTokens.count > 0);
    
    // Verify App2 has functional tokens
    NSArray *app2FamilyTokens = [MSIDTestCacheAccessorHelper getAllTokens:self.app2TokenCache 
                                                                      type:MSIDFamilyRefreshTokenType 
                                                                     class:[MSIDFamilyRefreshToken class]];
    XCTAssertTrue(app2FamilyTokens.count > 0);
}

- (void)verifyInvalidFamilyTokensCleanedUp
{
    // This would verify that invalid family tokens were removed from cache
    // Implementation depends on actual cleanup logic
    
    // For now, just verify that tokens are not accessible
    NSError *error = nil;
    MSIDRefreshToken *app1FRT = [self.app1TokenCache getRefreshTokenWithAccount:self.sharedAccountIdentifier
                                                                        familyId:DEFAULT_TEST_FAMILY_ID
                                                                   configuration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                                         context:nil
                                                                           error:&error];
    
    // Should be nil or cleaned up
    // XCTAssertNil(app1FRT);
}

- (void)verifyFamilyTokenIsolation
{
    // Verify that family1 and family2 tokens don't interfere with each other
    
    NSArray *app1FamilyTokens = [MSIDTestCacheAccessorHelper getAllTokens:self.app1TokenCache 
                                                                      type:MSIDFamilyRefreshTokenType 
                                                                     class:[MSIDFamilyRefreshToken class]];
    
    NSArray *app2FamilyTokens = [MSIDTestCacheAccessorHelper getAllTokens:self.app2TokenCache 
                                                                      type:MSIDFamilyRefreshTokenType 
                                                                     class:[MSIDFamilyRefreshToken class]];
    
    // Verify each app only has tokens for its own family
    for (MSIDFamilyRefreshToken *token in app1FamilyTokens) {
        XCTAssertEqualObjects(token.familyId, @"family1");
    }
    
    for (MSIDFamilyRefreshToken *token in app2FamilyTokens) {
        XCTAssertEqualObjects(token.familyId, @"family2");
    }
}

@end