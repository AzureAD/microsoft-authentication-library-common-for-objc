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
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDRequestParameters.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDTestURLResponse.h"
#import "MSIDDeviceId.h"
#import "MSIDTestURLSession.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDRefreshToken.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDError.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDClaimsRequest.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDB2COauth2Factory.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDIdToken.h"
#import "MSIDLRUCache.h"
#import "MSIDAccountMetadataCacheItem.h"

@interface MSIDDefaultSilentTokenRequestTests : XCTestCase

@end

@implementation MSIDDefaultSilentTokenRequestTests

#pragma mark - Helpers

- (MSIDDefaultTokenCacheAccessor *)tokenCache
{
    id<MSIDExtendedTokenCacheDataSource> dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:@"com.microsoft.adalcache" error:nil];
    MSIDDefaultTokenCacheAccessor *tokenCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    return tokenCache;
}

- (MSIDAccountMetadataCacheAccessor *)accountMetadataCache
{
    id<MSIDMetadataCacheDataSource> dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:@"com.microsoft.adalcache" error:nil];
    MSIDAccountMetadataCacheAccessor *accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
    return accountMetadataCache;
}

- (MSIDAccountCredentialCache *)accountCredentialCache
{
    return [[MSIDAccountCredentialCache alloc] initWithDataSource:[[MSIDKeychainTokenCache alloc] initWithGroup:@"com.microsoft.adalcache" error:nil]];
}

- (MSIDRequestParameters *)silentRequestParameters
{
    MSIDRequestParameters *parameters = [MSIDRequestParameters new];
    parameters.authority = [DEFAULT_TEST_AUTHORITY_GUID aadAuthority];
    parameters.clientId = @"my_client_id";
    parameters.target = @"user.read tasks.read";
    parameters.oidcScope = @"openid profile offline_access";
    parameters.redirectUri = @"my_redirect_uri";
    parameters.correlationId = [NSUUID new];
    parameters.extendedLifetimeEnabled = YES;
    return parameters;

}

- (MSIDRequestParameters *)silentB2CParameters
{
    MSIDRequestParameters *parameters = [MSIDRequestParameters new];
    parameters.authority = [@"https://login.microsoftonline.com/tfp/contoso.com/signup" b2cAuthority];
    parameters.clientId = @"my_client_id";
    parameters.target = @"user.read tasks.read";
    parameters.oidcScope = @"openid profile offline_access";
    parameters.redirectUri = @"my_redirect_uri";
    parameters.correlationId = [NSUUID new];
    return parameters;
}

- (void)setUp
{
    [super setUp];
    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:@"v2.0" forKey:@"aadApiVersion"];
    MSIDKeychainTokenCache *cache = [[MSIDKeychainTokenCache alloc] initWithGroup:@"com.microsoft.adalcache" error:nil];
    [cache clearWithContext:nil error:nil];
}

- (void)tearDown
{
    [[MSIDAadAuthorityCache sharedInstance] removeAllObjects];
    [[MSIDAuthority openIdConfigurationCache] removeAllObjects];
    [[MSIDLRUCache sharedInstance] removeAllObjects:nil];
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:nil forKey:@"aadApiVersion"];
    [[MSIDLRUCache sharedInstance] removeAllObjects:nil];
    [super tearDown];
}

#pragma mark - Silent

- (void)testAcquireTokenSilent_whenNoAccountProvided_shouldReturnError
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters forceRefresh:NO oauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new] tokenCache:self.tokenCache accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorMissingAccountParameter);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenAccessAndRefreshTokensInCache_shouldReturnATAndRT
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                       accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read user.write tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        XCTAssertEqualObjects(result.authority, silentParameters.authority);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
        XCTAssertNil(result.refreshToken.familyId);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenAccessAndRefreshTokensInCache_andNestedAuthAndMatchRedirectUri_shouldReturnATAndRT
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    silentParameters.nestedAuthBrokerClientId = @"1234-5678";
    silentParameters.nestedAuthBrokerRedirectUri = @"brk-hub-app://auth";
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                       accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read user.write tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        XCTAssertEqualObjects(result.authority, silentParameters.authority);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
        XCTAssertNil(result.refreshToken.familyId);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenAccessAndFociRefreshTokensInCache_andNoAppRefreshToken_shouldReturnATAndFociRT
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:@"1"
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:nil
               extExpiresIn:nil
                  refreshIn:nil];

    // Remove MRRT
    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:silentParameters.accountIdentifier
                                                                   familyId:nil
                                                              configuration:silentParameters.msidConfiguration
                                                                    context:silentParameters
                                                                      error:nil];
    XCTAssertNotNil(refreshToken);

    XCTAssertTrue([tokenCache removeToken:refreshToken context:silentParameters error:nil]);

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read user.write tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        XCTAssertEqualObjects(result.authority, silentParameters.authority);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
        XCTAssertEqualObjects(@"1", result.refreshToken.familyId);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenAccessToken_butNoIDToken_andServerUnavailable_shouldFail
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:nil
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:@"1"
               extExpiresIn:@"3600000"
                  refreshIn:nil];

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    MSIDIdToken *idToken = [tokenCache getIDTokenForAccount:silentParameters.accountIdentifier configuration:silentParameters.msidConfiguration idTokenType:MSIDIDTokenType context:nil error:nil];
    XCTAssertNotNil(idToken);

    BOOL removeResult = [tokenCache removeToken:idToken context:nil error:nil];
    XCTAssertTrue(removeResult);

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    // Simulate server unavailable situation
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:500
                                                                                    expiresIn:nil];

    // MSAL will retry twice
    [MSIDTestURLSession addResponse:tokenResponse];
    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                               accountMetadataCache:self.accountMetadataCache];


    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertNil(result);
        XCTAssertEqual(error.code, MSIDErrorServerUnhandledResponse);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenAccessToken_butNoIDToken_shouldRefreshToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:@"1"
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:nil
               extExpiresIn:nil
                  refreshIn:nil];

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    MSIDIdToken *idToken = [tokenCache getIDTokenForAccount:silentParameters.accountIdentifier configuration:silentParameters.msidConfiguration idTokenType:MSIDIDTokenType context:nil error:nil];
    XCTAssertNotNil(idToken);

    BOOL removeResult = [tokenCache removeToken:idToken context:nil error:nil];
    XCTAssertTrue(removeResult);

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                               accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        XCTAssertEqualObjects(result.authority.url, silentParameters.authority.url);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenNoAccessTokenFound_shouldRefreshToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    MSIDAccessToken *accessToken = [tokenCache getAccessTokenForAccount:silentParameters.accountIdentifier configuration:silentParameters.msidConfiguration context:nil error:nil];

    XCTAssertNotNil(accessToken);

    BOOL removeResult = [tokenCache removeToken:accessToken context:nil error:nil];
    XCTAssertTrue(removeResult);

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        NSURL *tenantURL = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY_GUID];
        XCTAssertEqualObjects(result.authority.url, tenantURL);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenNoMatchingAccessTokenFound_shouldRefreshToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    silentParameters.target = @"new.scope1 new.scope2";

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"new.scope1 new.scope2 openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"new.scope1 new.scope2"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"new.scope1 new.scope2"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        NSURL *tenantURL = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY_GUID];
        XCTAssertEqualObjects(result.authority.url, tenantURL);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenExpiredAccessTokenInCache_shouldRefreshToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveExpiredTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    silentParameters.accountIdentifier = accountIdentifier;

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        NSURL *tenantURL = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY_GUID];
        XCTAssertEqualObjects(result.authority.url, tenantURL);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    MSIDAccessToken *accessToken = [tokenCache getAccessTokenForAccount:accountIdentifier configuration:silentParameters.msidConfiguration context:nil error:nil];
    XCTAssertNotNil(accessToken);
}

- (void)testAcquireTokenSilent_whenATExpired_AndFailedToRefreshToken_shouldReturnError_AndRemoveExpiredAccesstoken_AndKeepRefreshTokenInCache
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveExpiredTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    silentParameters.accountIdentifier = accountIdentifier;

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse errorRefreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                     requestClaims:nil
                                                                                     requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                     responseError:@"invalid_grant"
                                                                                       description:@"test"
                                                                                          subError:@"my_suberror"
                                                                                               url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                      responseCode:200];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(__unused MSIDTokenResult * _Nullable result, __unused NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"my_suberror");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    MSIDAccessToken *accessToken = [tokenCache getAccessTokenForAccount:accountIdentifier configuration:silentParameters.msidConfiguration context:nil error:nil];
    XCTAssertNil(accessToken);

    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:accountIdentifier familyId:nil configuration:silentParameters.msidConfiguration context:nil error:nil];
    XCTAssertNotNil(refreshToken);
}

- (void)testAcquireTokenSilent_whenATExpiredAndFailedToRefreshTokenWithProtectionPoliciesRequired_shouldReturnIt
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveExpiredTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    silentParameters.accountIdentifier = accountIdentifier;

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse errorRefreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                     requestClaims:nil
                                                                                     requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                     responseError:@"unauthorized_client"
                                                                                       description:@"test"
                                                                                          subError:@"protection_policy_required"
                                                                                               url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                      responseCode:400];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(__unused MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorServerProtectionPoliciesRequired);
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"unauthorized_client");
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"protection_policy_required");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenATExpired_AndFailedToRefreshTokenWithBadTokenError_shouldReturnError_AndRemoveExpiredAccesstoken_AndRemoveRefreshTokenInCache
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveExpiredTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    silentParameters.accountIdentifier = accountIdentifier;

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse errorRefreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                     requestClaims:nil
                                                                                     requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                     responseError:@"invalid_grant"
                                                                                       description:@"test"
                                                                                          subError:@"bad_token"
                                                                                               url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                      responseCode:200];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(__unused MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"bad_token");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    MSIDAccessToken *accessToken = [tokenCache getAccessTokenForAccount:accountIdentifier configuration:silentParameters.msidConfiguration context:nil error:nil];
    XCTAssertNil(accessToken);

    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:accountIdentifier familyId:nil configuration:silentParameters.msidConfiguration context:nil error:nil];
    XCTAssertNil(refreshToken);
}

- (void)testAcquireTokenSilent_whenATExpired_AndFailedToRefreshTokenWithUserAccountDeleted_shouldReturnError_AndRemoveAccountMetadata_AndRemoveRefreshTokenInCache
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    silentParameters.accountIdentifier = accountIdentifier;
    [self saveExpiredTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    
    NSError *updateError = nil;
    [self.accountMetadataCache updateSignInStateForHomeAccountId:silentParameters.accountIdentifier.homeAccountId
                                                        clientId:silentParameters.clientId
                                                           state:MSIDAccountMetadataStateSignedIn
                                                         context:nil
                                                           error:&updateError];
    XCTAssertNil(updateError);
    
    NSError *metadataCacheError;
    MSIDAccountMetadataCacheItem *accountMetadataCacheItem = [self.accountMetadataCache retrieveAccountMetadataCacheItemForClientId:silentParameters.clientId
                                                                                                                            context:nil
                                                                                                                              error:&metadataCacheError];
    XCTAssertNil(metadataCacheError);
    XCTAssertEqualObjects(silentParameters.clientId, accountMetadataCacheItem.clientId, "Valid item should be in the metadata cache");
    MSIDAccountMetadata *accountMetadata = [accountMetadataCacheItem accountMetadataForHomeAccountId:silentParameters.accountIdentifier.homeAccountId];
    XCTAssertNil(metadataCacheError);
    XCTAssertNotNil(accountMetadata);

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse errorRefreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                     requestClaims:nil
                                                                                     requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                     responseError:@"invalid_grant"
                                                                                       description:@"test"
                                                                                          subError:@"user_account_deleted"
                                                                                               url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                      responseCode:200];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    MSIDAccessToken *accessToken = [tokenCache getAccessTokenForAccount:accountIdentifier configuration:silentParameters.msidConfiguration context:nil error:nil];
    XCTAssertNotNil(accessToken);
    
    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:accountIdentifier familyId:nil configuration:silentParameters.msidConfiguration context:nil error:nil];
    XCTAssertNotNil(refreshToken);
    
    [silentRequest executeRequestWithCompletion:^(__unused MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"user_account_deleted");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    accessToken = [tokenCache getAccessTokenForAccount:accountIdentifier configuration:silentParameters.msidConfiguration context:nil error:nil];
    XCTAssertNil(accessToken, "AT have removed access token from cache");

    refreshToken = [tokenCache getRefreshTokenWithAccount:accountIdentifier familyId:nil configuration:silentParameters.msidConfiguration context:nil error:nil];
    XCTAssertNil(refreshToken, "RT have removed access token from cache");
    
    accountMetadataCacheItem = [self.accountMetadataCache retrieveAccountMetadataCacheItemForClientId:silentParameters.clientId
                                                                                              context:nil
                                                                                                error:&metadataCacheError];
    XCTAssertNil(metadataCacheError);
    accountMetadata = [accountMetadataCacheItem accountMetadataForHomeAccountId:silentParameters.accountIdentifier.homeAccountId];
    XCTAssertNil(metadataCacheError);
    XCTAssertNil(accountMetadata, "Account metadata should have been removed from cache");
}

- (void)testAcquireTokenSilent_whenATExpiresIn50WithinExpirationBuffer100_shouldReAcquireToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;
    silentParameters.tokenExpirationBuffer = 100;

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:nil
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:@"50"
               extExpiresIn:nil
                  refreshIn:nil];

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        NSURL *tenantURL = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY_GUID];
        XCTAssertEqualObjects(result.authority.url, tenantURL);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenExpiredAccessTokenInCache_andTenantedAuthority_shouldRefreshToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveExpiredTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    silentParameters.authority = [authority aadAuthority];

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        NSURL *tenantURL = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY_GUID];
        XCTAssertEqualObjects(result.authority.url, tenantURL);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenNestedAuthAndNoMatchRedirectUri_shouldRefreshToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    silentParameters.nestedAuthBrokerClientId = @"1234-5678";
    silentParameters.nestedAuthBrokerRedirectUri = @"brk-hub-app://auth";
    silentParameters.msidConfiguration.redirectUri = @"real-app-cached://auth";
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    silentParameters.redirectUri = @"other-app-request://auth";

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    NSDictionary *additionalBodyParams = @{
                                            @"redirect_uri": @"other-app-request://auth",
                                            @"brk_redirect_uri": @"brk-hub-app://auth",
                                            @"brk_client_id": @"1234-5678"
    };
    
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil
                                                                         additionalBodyParams:additionalBodyParams];

    
    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenExpiredAccessTokenInCache_andNoRefreshTokenFound_shouldReturnError
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveExpiredTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    // Remove MRRT
    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:silentParameters.accountIdentifier
                                                                   familyId:nil
                                                              configuration:silentParameters.msidConfiguration
                                                                    context:silentParameters
                                                                      error:nil];

    XCTAssertNotNil(refreshToken);

    XCTAssertTrue([tokenCache removeToken:refreshToken context:silentParameters error:nil]);

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertNil(result);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenAccessTokenInCache_andForceRefreshYES_shouldRefreshToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:YES
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        NSURL *tenantURL = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY_GUID];
        XCTAssertEqualObjects(result.authority.url, tenantURL);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenAccessTokenInCache_andForceRefreshYES_andNoRefreshTokenFound_shouldReturnError
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveExpiredTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    // Remove MRRT
    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:silentParameters.accountIdentifier
                                                                   familyId:nil
                                                              configuration:silentParameters.msidConfiguration
                                                                    context:silentParameters
                                                                      error:nil];

    XCTAssertNotNil(refreshToken);

    XCTAssertTrue([tokenCache removeToken:refreshToken context:silentParameters error:nil]);

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:YES
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertNil(result);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenExpiredAccessTokenInCache_andDifferentAccountReturn_shouldReturnValidResult
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:YES
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    NSDictionary *clientInfoClaims = @{ @"uid" : @"new_uid", @"utid" : @"new_utid"};
    NSString *differentClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:differentClientInfo
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenAccessTokenInCache_andForceRefreshYES_andNoATReturned_shouldReturnError
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:YES
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    NSDictionary *clientInfoClaims = @{ @"uid" : @"new_uid", @"utid" : @"new_utid"};
    NSString *differentClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@""
                                                                                   responseRT:@"new rt"
                                                                                   responseID:@""
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:differentClientInfo
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertNil(result);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenResiliencyErrorReturned_shouldRetryRequestOnceAndSucceed
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveExpiredTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *errorTokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                     requestClaims:nil
                                                                                     requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                        responseAT:@"new at 1"
                                                                                        responseRT:@"new rt 1"
                                                                                        responseID:nil
                                                                                     responseScope:@"user.read tasks.read"
                                                                                responseClientInfo:nil
                                                                                               url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                      responseCode:500
                                                                                         expiresIn:nil];

    [MSIDTestURLSession addResponse:errorTokenResponse];

    MSIDTestURLResponse *successTokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                       requestClaims:nil
                                                                                       requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                          responseAT:@"new at 2"
                                                                                          responseRT:@"new rt 2"
                                                                                          responseID:nil
                                                                                       responseScope:@"user.read tasks.read"
                                                                                  responseClientInfo:nil
                                                                                                 url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                        responseCode:200
                                                                                           expiresIn:nil];

    [MSIDTestURLSession addResponse:successTokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at 2");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        NSURL *tenantURL = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY_GUID];
        XCTAssertEqualObjects(result.authority.url, tenantURL);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt 2");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_when429ThrottledErrorReturned_shouldReturnAllHeadersAnd429ErrorCode
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveExpiredTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    NSMutableDictionary *reqHeaders = [[MSIDTestURLResponse msidDefaultRequestHeaders] mutableCopy];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];

    MSIDTestURLResponse *errorTokenResponse =
    [MSIDTestURLResponse requestURLString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"client_id" : @"my_client_id",
                                             @"scope" : @"user.read tasks.read openid profile offline_access",
                                             @"grant_type" : @"refresh_token",
                                             @"refresh_token" : DEFAULT_TEST_REFRESH_TOKEN,
                                             MSID_OAUTH2_REDIRECT_URI : [[self silentRequestParameters] redirectUri],
                                             @"client_info" : @"1"}
                        responseURLString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                             responseCode:429
                         httpHeaderFields:@{@"Retry-After": @"256",
                                            @"Other-Header-Field": @"Other header field"
                                            }
                         dictionaryAsJSON:nil];

    [errorTokenResponse->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:errorTokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertNil(result);
        XCTAssertEqual(error.code, MSIDErrorServerUnhandledResponse);
        XCTAssertEqualObjects(error.domain, MSIDHttpErrorCodeDomain);
        XCTAssertEqualObjects(error.userInfo[MSIDHTTPHeadersKey][@"Retry-After"], @"256");
        XCTAssertEqualObjects(error.userInfo[MSIDHTTPHeadersKey][@"Other-Header-Field"], @"Other header field");
        XCTAssertEqualObjects(error.userInfo[MSIDHTTPResponseCodeKey], @"429");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}


- (void)testAcquireTokenSilent_when403HttpCodeReturned_shouldReturnMSIDErrorUnexpectedHttpResponseInUnderlyingError
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveExpiredTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    NSMutableDictionary *reqHeaders = [[MSIDTestURLResponse msidDefaultRequestHeaders] mutableCopy];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];

    MSIDTestURLResponse *errorTokenResponse =
    [MSIDTestURLResponse requestURLString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"client_id" : @"my_client_id",
                                             @"scope" : @"user.read tasks.read openid profile offline_access",
                                             @"grant_type" : @"refresh_token",
                                             @"refresh_token" : DEFAULT_TEST_REFRESH_TOKEN,
                                             MSID_OAUTH2_REDIRECT_URI : [[self silentRequestParameters] redirectUri],
                                             @"client_info" : @"1"}
                        responseURLString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                             responseCode:403
                         httpHeaderFields:@{@"Retry-After": @"256",
                                            @"Other-Header-Field": @"Other header field"
                                            }
                         dictionaryAsJSON:nil];

    [errorTokenResponse->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:errorTokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertNil(result);
        XCTAssertEqual(error.code, MSIDErrorServerUnhandledResponse);
        NSError *underlyingError = error.userInfo[NSUnderlyingErrorKey];
        XCTAssertEqual(underlyingError.code, MSIDErrorUnexpectedHttpResponse);
        XCTAssertEqualObjects(error.domain, MSIDHttpErrorCodeDomain);
        XCTAssertEqualObjects(error.userInfo[MSIDHTTPResponseCodeKey], @"403");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
- (void)testAcquireTokenSilent_whenTokenEndpointInDifferentCloud_shouldReturnInteractionRequired
{
    // Prepare RT in cache
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    MSIDAccessToken *accessToken = [tokenCache getAccessTokenForAccount:silentParameters.accountIdentifier configuration:silentParameters.msidConfiguration context:nil error:nil];

    XCTAssertNotNil(accessToken);

    BOOL removeResult = [tokenCache removeToken:accessToken context:nil error:nil];
    XCTAssertTrue(removeResult);

    // Prepare Open Id Configuration response with token endpoint in a different cloud
    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    NSDictionary *oidcJson =
    @{ @"token_endpoint" : [NSString stringWithFormat:@"%@/oauth2/v2.0/token", @"login.partner.microsoftonline.cn"],
       @"authorization_endpoint" : @"auth_endpoint",
       @"issuer" : @"issuer"
    };
    [oidcResponse setResponseJSON:oidcJson];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"User interaction is required (unable to use token from a different cloud).");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark - B2C

- (void)testAcquireTokenSilent_whenExpiredB2CAccessTokenInCache_shouldReturnToken
{
    MSIDRequestParameters *silentParameters = [self silentB2CParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveExpiredTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = @"https://login.microsoftonline.com/tfp/contoso.com/signup";

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new b2c at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:@"https://login.microsoftonline.com/tfp/contoso.com/signup/oauth2/v2.0/token"
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDB2COauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new b2c at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        NSURL *tenantURL = [NSURL URLWithString:@"https://login.microsoftonline.com/tfp/"DEFAULT_TEST_UTID@"/signup"];
        XCTAssertEqualObjects(result.authority.url, tenantURL);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark - Claims

- (void)testAcquireTokenSilent_whenNonExpiredAccessTokenInCache_andClaims_shouldRefreshToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    NSDictionary *claimsJsonDictionary = @{@"access_token":@{@"polids":@{@"values":@[@"5ce770ea-8690-4747-aa73-c5b3cd509cd4"], @"essential":@YES}}};
    silentParameters.claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:nil];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:@"{\"access_token\":{\"polids\":{\"essential\":true,\"values\":[\"5ce770ea-8690-4747-aa73-c5b3cd509cd4\"]}}}"
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        NSURL *tenantURL = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY_GUID];
        XCTAssertEqualObjects(result.authority.url, tenantURL);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark - Extended expires in

- (void)testAcquireTokenSilent_whenATExpiredButExtendedExpiresInFlagPresent_andServerIsUnavailable_shouldReturnExtendedToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:nil
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:@"1"
               extExpiresIn:@"3600000"
                  refreshIn:nil];

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    // Simulate server unavailable situation
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:500
                                                                                    expiresIn:nil];

    // MSAL will retry twice
    [MSIDTestURLSession addResponse:tokenResponse];
    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read user.write tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertTrue(result.extendedLifeTimeToken);
        XCTAssertEqualObjects(result.authority, silentParameters.authority);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark - FOCI

- (void)testAcquireTokenSilent_whenExpiredAccessTokenInCache_andFamilyRefreshTokenInCache_shouldRefreshToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:@"1"
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:@"1"
               extExpiresIn:nil
                  refreshIn:nil];

    // Remove MRRT
    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:silentParameters.accountIdentifier
                                                                   familyId:nil
                                                              configuration:silentParameters.msidConfiguration
                                                                    context:silentParameters
                                                                      error:nil];

    XCTAssertNotNil(refreshToken);

    XCTAssertTrue([tokenCache removeToken:refreshToken context:silentParameters error:nil]);

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        NSURL *tenantURL = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY_GUID];
        XCTAssertEqualObjects(result.authority.url, tenantURL);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenFamilyRefreshTokenInCache_andNoAppRefresh_ClientMismatch_shouldSkip
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    silentParameters.authority = [@"https://login.windows.net/"DEFAULT_TEST_UTID aadAuthority];

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:@"1"
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:@"1"
               extExpiresIn:nil
                  refreshIn:nil];

    // Remove MRRT
    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:silentParameters.accountIdentifier
                                                                   familyId:nil
                                                              configuration:silentParameters.msidConfiguration
                                                                    context:silentParameters
                                                                      error:nil];
    XCTAssertNotNil(refreshToken);

    XCTAssertTrue([tokenCache removeToken:refreshToken context:silentParameters error:nil]);

    // Update FRT
    refreshToken = [tokenCache getRefreshTokenWithAccount:silentParameters.accountIdentifier
                                                                   familyId:@"1"
                                                              configuration:silentParameters.msidConfiguration
                                                                    context:silentParameters
                                                                      error:nil];

    XCTAssertNotNil(refreshToken);

    refreshToken.refreshToken = @"family refresh token";

    XCTAssertTrue([[self accountCredentialCache] saveCredential:refreshToken.tokenCacheItem context:nil error:nil]);

    NSString *authority = @"https://login.windows.net/"DEFAULT_TEST_UTID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:DEFAULT_TEST_AUTHORITY_GUID];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse errorRefreshTokenGrantResponseWithRT:@"family refresh token"
                                                                                     requestClaims:nil
                                                                                     requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                     responseError:@"invalid_grant"
                                                                                       description:nil
                                                                                          subError:@"client_mismatch"
                                                                                               url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                      responseCode:200];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(result);
        XCTAssertNotNil(error);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    // Next silent request shouldn't try to use FRT anymore, but return error with not finding FRT in cache

    MSIDDefaultSilentTokenRequest *secondSilentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                             forceRefresh:NO
                                                                                                             oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                   tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                               tokenCache:tokenCache
                                                                                                            accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *secondExpecation = [self expectationWithDescription:@"silent request"];

    [secondSilentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.userInfo[MSIDErrorDescriptionKey], @"No token matching arguments found in the cache, user interaction is required");

        [secondExpecation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenRevokedFamilyRefreshTokenInCache_andNoMRRT_shouldFail
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:@"1"
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:@"1"
               extExpiresIn:nil
                  refreshIn:nil];

    // Update MRRT
    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:silentParameters.accountIdentifier
                                                                   familyId:nil
                                                              configuration:silentParameters.msidConfiguration
                                                                    context:silentParameters
                                                                      error:nil];

    XCTAssertNotNil(refreshToken);

    XCTAssertTrue([self.tokenCache removeToken:refreshToken context:nil error:nil]);

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse errorRefreshTokenGrantResponseWithRT:@"refresh_token"
                                                                                     requestClaims:nil
                                                                                     requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                     responseError:@"invalid_grant"
                                                                                       description:nil
                                                                                          subError:nil
                                                                                               url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                      responseCode:200];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertNil(result);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenRevokedAppRefreshTokenInCache_andNoFRT_shouldFail
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:@"1"
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:@"1"
               extExpiresIn:nil
                  refreshIn:nil];

    // Remove FRT
    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:silentParameters.accountIdentifier
                                                                   familyId:@"1"
                                                              configuration:silentParameters.msidConfiguration
                                                                    context:silentParameters
                                                                      error:nil];
    XCTAssertNotNil(refreshToken);

    XCTAssertTrue([self.tokenCache removeToken:refreshToken context:silentParameters error:nil]);

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse errorRefreshTokenGrantResponseWithRT:@"refresh_token"
                                                                                     requestClaims:nil
                                                                                     requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                     responseError:@"invalid_grant"
                                                                                       description:nil
                                                                                          subError:nil
                                                                                               url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                      responseCode:200];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertNil(result);
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
        XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"User interaction is required");
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenRevokedAppRefreshTokenInCache_shouldFallbackToFamilyRefreshToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:@"1"
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:@"1"
               extExpiresIn:nil
                  refreshIn:nil];

    // Update FRT
    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:silentParameters.accountIdentifier
                                                                   familyId:@"1"
                                                              configuration:silentParameters.msidConfiguration
                                                                    context:silentParameters
                                                                      error:nil];
    XCTAssertNotNil(refreshToken);

    refreshToken.refreshToken = @"family refresh token";

    XCTAssertTrue([[self accountCredentialCache] saveCredential:refreshToken.tokenCacheItem context:nil error:nil]);

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse errorRefreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                     requestClaims:nil
                                                                                     requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                     responseError:@"invalid_grant"
                                                                                       description:nil
                                                                                          subError:nil
                                                                                               url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                      responseCode:200];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDTestURLResponse *frtTokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:@"family refresh token"
                                                                                    requestClaims:nil
                                                                                    requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                       responseAT:@"new at frt"
                                                                                       responseRT:@"new rt"
                                                                                       responseID:nil
                                                                                    responseScope:@"user.read tasks.read"
                                                                               responseClientInfo:nil
                                                                                              url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                     responseCode:200
                                                                                        expiresIn:nil];

    [MSIDTestURLSession addResponse:frtTokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at frt");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        NSURL *tenantURL = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY_GUID];
        XCTAssertEqualObjects(result.authority.url, tenantURL);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}


#pragma mark - Scopes

- (void)testAcquireTokenSilent_whenATExpired_andTokenRefreshReturnsLessScopes_shouldReturnErrorButCacheTokens
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache configuration:silentParameters.msidConfiguration];
    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    silentParameters.target = @"new.SCOPE1 new.sCope2";

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"new.SCOPE1 new.sCope2 openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"new.scope New.Scope1"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(error);
        XCTAssertNil(result);
        XCTAssertEqual(error.code, MSIDErrorServerDeclinedScopes);
        NSArray *declinedScopes = @[@"new.sCope2"];
        XCTAssertEqualObjects(error.userInfo[MSIDDeclinedScopesKey], declinedScopes);
        NSArray *grantedScopes = @[@"new.scope",@"New.Scope1"];
        XCTAssertEqualObjects(error.userInfo[MSIDGrantedScopesKey], grantedScopes);
        MSIDTokenResult *invalidTokenResult = error.userInfo[MSIDInvalidTokenResultKey];
        XCTAssertNotNil(invalidTokenResult);
        XCTAssertEqualObjects(invalidTokenResult.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(invalidTokenResult.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"new.scope New.Scope1"]);
        XCTAssertEqualObjects(invalidTokenResult.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(invalidTokenResult.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(invalidTokenResult.extendedLifeTimeToken);
        XCTAssertEqualObjects(invalidTokenResult.authority.url.absoluteString, authority);
        XCTAssertEqualObjects(invalidTokenResult.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    silentParameters.target = @"new.scope";

    MSIDDefaultSilentTokenRequest *secondSilentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                             forceRefresh:NO
                                                                                                             oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                   tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                               tokenCache:tokenCache
                                                                                                            accountMetadataCache:self.accountMetadataCache];
    XCTestExpectation *secondExpectation = [self expectationWithDescription:@"silent request"];

    [secondSilentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"new.scope New.Scope1"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        XCTAssertEqualObjects(result.authority.url, silentParameters.authority.url);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);

        [secondExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

}

#pragma mark - RefreshIn

- (void)testAcquireTokenSilent_whenAT_RefreshInExpires_shouldRefreshToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:nil
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:@"5000"
               extExpiresIn:nil
                  refreshIn:@"1"];

    // Adding sleep time to allow refresh On expiry
    [NSThread sleepForTimeInterval:2.0f];

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:200
                                                                                    expiresIn:nil];

    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new at");
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        NSURL *tenantURL = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY_GUID];
        XCTAssertEqualObjects(result.authority.url, tenantURL);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, @"new rt");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenRefreshExpired_and_ServerIsUnavailable_shouldReturnRefreshExpiredAccessToken
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:nil
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:@"5000"
               extExpiresIn:nil
                  refreshIn:@"1"];

    // Adding sleep time to allow refresh On expiry
    [NSThread sleepForTimeInterval:2.0f];

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];

    // Simulate server unavailable situation
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:DEFAULT_TEST_REFRESH_TOKEN
                                                                                requestClaims:nil
                                                                                requestScopes:@"user.read tasks.read openid profile offline_access"
                                                                                   responseAT:@"new at"
                                                                                   responseRT:@"new rt"
                                                                                   responseID:nil
                                                                                responseScope:@"user.read tasks.read"
                                                                           responseClientInfo:nil
                                                                                          url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                 responseCode:500
                                                                                    expiresIn:nil];

    // MSAL will retry twice
    [MSIDTestURLSession addResponse:tokenResponse];
    [MSIDTestURLSession addResponse:tokenResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read user.write tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        XCTAssertEqualObjects(result.authority, silentParameters.authority);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

}

- (void)testAcquireTokenSilent_whenAccessATNotRefreshExpired_shouldReturnATAndRT
{
    MSIDRequestParameters *silentParameters = [self silentRequestParameters];
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCache;

    [self saveTokensInCache:tokenCache
              configuration:silentParameters.msidConfiguration
                      scope:nil
                       foci:nil
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:@"500"
               extExpiresIn:nil
                  refreshIn:@"70"];

    silentParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSString *authority = DEFAULT_TEST_AUTHORITY_GUID;
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDDefaultSilentTokenRequest *silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:silentParameters
                                                                                                       forceRefresh:NO
                                                                                                       oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                         tokenCache:tokenCache
                                                                                                       accountMetadataCache:self.accountMetadataCache];

    XCTestExpectation *expectation = [self expectationWithDescription:@"silent request"];

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
        XCTAssertEqualObjects(result.accessToken.scopes, [NSOrderedSet msidOrderedSetFromString:@"user.read user.write tasks.read"]);
        XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, silentParameters.accountIdentifier.homeAccountId);
        XCTAssertEqualObjects(result.rawIdToken, [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID]);
        XCTAssertFalse(result.extendedLifeTimeToken);
        XCTAssertEqualObjects(result.authority, silentParameters.authority);
        XCTAssertEqualObjects(result.refreshToken.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
        XCTAssertNil(result.refreshToken.familyId);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}


#pragma mark - Cache

- (void)saveExpiredTokensInCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
                   configuration:(MSIDConfiguration *)configuration
{
    [self saveTokensInCache:tokenCache
              configuration:configuration
                      scope:nil
                       foci:nil
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:@"1"
               extExpiresIn:nil
                  refreshIn:nil];
}

- (void)saveTokensInCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
            configuration:(MSIDConfiguration *)configuration
{
    [self saveTokensInCache:tokenCache
              configuration:configuration
                      scope:nil
                       foci:nil
                accessToken:nil
               refreshToken:nil
                    idToken:nil
                 clientInfo:nil
                  expiresIn:nil
               extExpiresIn:nil
                  refreshIn:nil];
}

- (void)saveTokensInCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
            configuration:(MSIDConfiguration *)configuration
                    scope:(NSString *)scopes
                     foci:(NSString *)fociFlag
              accessToken:(NSString *)accessToken
             refreshToken:(NSString *)refreshToken
                  idToken:(NSString *)idToken
               clientInfo:(NSString *)clientInfo
                expiresIn:(NSString *)expiresIn
             extExpiresIn:(NSString *)extExpiresIn
                refreshIn:(NSString *)refreshIn

{

    NSDictionary *response = [MSIDTestURLResponse tokenResponseWithAT:accessToken
                                                           responseRT:refreshToken
                                                           responseID:idToken
                                                        responseScope:scopes
                                                   responseClientInfo:clientInfo
                                                            expiresIn:expiresIn
                                                                 foci:fociFlag
                                                         extExpiresIn:extExpiresIn
                                                            refreshIn:refreshIn];

    MSIDAADV2TokenResponse *tokenResponse = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:response error:nil];

    NSError *error = nil;
    BOOL result = [tokenCache saveTokensWithConfiguration:configuration
                                                 response:tokenResponse
                                                  factory:[MSIDAADV2Oauth2Factory new]
                                                  context:nil
                                                    error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

@end
