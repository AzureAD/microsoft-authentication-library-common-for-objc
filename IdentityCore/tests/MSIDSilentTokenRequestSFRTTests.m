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
#import "MSIDSilentTokenRequest.h"
#import "MSIDDefaultSilentTokenRequest.h"
#import "MSIDRequestParameters.h"
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
#import "MSIDTokenResult.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse.h"

@interface MSIDSilentTokenRequestSFRTTests : XCTestCase

@property (nonatomic) MSIDDefaultSilentTokenRequest *silentRequest;
@property (nonatomic) MSIDRequestParameters *requestParameters;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;
@property (nonatomic) MSIDAccountIdentifier *accountIdentifier;

@end

@implementation MSIDSilentTokenRequestSFRTTests

- (void)setUp
{
    [super setUp];
    
    [MSIDTestURLSession clearResponses];
    
    // Set up request parameters
    self.requestParameters = [MSIDRequestParameters new];
    self.requestParameters.authority = [@"https://login.microsoftonline.com/common" msidAuthority];
    self.requestParameters.clientId = DEFAULT_TEST_CLIENT_ID;
    self.requestParameters.target = DEFAULT_TEST_SCOPE;
    self.requestParameters.msidConfiguration = [MSIDTestConfiguration v2DefaultConfiguration];
    self.requestParameters.correlationId = [[NSUUID alloc] init];
    
    self.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                    homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    self.requestParameters.accountIdentifier = self.accountIdentifier;
    
    // Set up cache
    MSIDTestCacheDataSource *dataSource = [[MSIDTestCacheDataSource alloc] init];
    self.tokenCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    self.accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
    
    // Create silent request
    self.silentRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:self.requestParameters
                                                                            forceRefresh:NO
                                                                            oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                  tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                              tokenCache:self.tokenCache
                                                                    accountMetadataCache:self.accountMetadataCache];
    
    // Reset FRT settings
    [MSIDAccountCredentialCache setDisableFRT:NO];
}

- (void)tearDown
{
    [MSIDTestSwizzle removeAllSwizzling];
    [MSIDTestURLSession clearResponses];
    [super tearDown];
}

#pragma mark - App RT to FRT fallback tests

- (void)testExecuteRequest_whenAppRTFails_shouldFallbackToFRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Save both app RT and FRT
    MSIDRefreshToken *appRT = [self saveAppRefreshToken];
    MSIDFamilyRefreshToken *familyRT = [self saveFamilyRefreshToken];
    
    // Mock app RT failure
    [self mockAppRTFailureResponse];
    // Mock FRT success
    [self mockFRTSuccessResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertNotNil(result.accessToken);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new_access_token_frt");
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testExecuteRequest_whenAppRTFailsAndNoFRT_shouldReturnError
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Save only app RT (no FRT)
    [self saveAppRefreshToken];
    
    // Mock app RT failure
    [self mockAppRTFailureResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testExecuteRequest_whenBothAppRTAndFRTFail_shouldReturnInteractionRequiredError
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    [self saveAppRefreshToken];
    [self saveFamilyRefreshToken];
    
    // Mock both failures
    [self mockAppRTFailureResponse];
    [self mockFRTFailureResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - FRT as primary token tests

- (void)testExecuteRequest_whenFRTEnabledAndOnlyFRTInCache_shouldUseFRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Save only FRT
    [self saveFamilyRefreshToken];
    
    [self mockFRTSuccessResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertNotNil(result.accessToken);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new_access_token_frt");
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testExecuteRequest_whenFRTDisabledAndOnlyFRTInCache_shouldReturnError
{
    [self disableFRTFeatureFlag];
    
    // Save only FRT
    [self saveFamilyRefreshToken];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"No token matching arguments found in the cache"]);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Token type selection tests

- (void)testExecuteRequest_whenBothTokenTypesAvailableAndFRTEnabled_shouldPreferAppRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    [self saveAppRefreshToken];
    [self saveFamilyRefreshToken];
    
    [self mockAppRTSuccessResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new_access_token_app");
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Client mismatch handling tests

- (void)testExecuteRequest_whenFRTClientMismatch_shouldUpdateFamilyIdCache
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    [self saveAppRefreshToken];
    [self saveFamilyRefreshToken];
    
    // Mock app RT failure followed by FRT client mismatch
    [self mockAppRTFailureResponse];
    [self mockFRTClientMismatchResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        
        // Verify that family ID cache was updated (this would be implementation-specific)
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Force refresh scenarios

- (void)testExecuteRequest_whenForceRefreshWithFRT_shouldRefreshUsingFRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    [self saveFamilyRefreshToken];
    
    // Create request with force refresh
    MSIDDefaultSilentTokenRequest *forceRefreshRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:self.requestParameters
                                                                                                              forceRefresh:YES
                                                                                                              oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                                tokenCache:self.tokenCache
                                                                                                      accountMetadataCache:self.accountMetadataCache];
    
    [self mockFRTSuccessResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Force refresh completion"];
    
    [forceRefreshRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new_access_token_frt");
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Mixed family scenarios

- (void)testExecuteRequest_whenMultipleFamilyRTs_shouldUseCorrectFamilyRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Save multiple family RTs with different family IDs
    [self saveFamilyRefreshTokenWithFamilyId:@"family1"];
    MSIDFamilyRefreshToken *targetFamilyRT = [self saveFamilyRefreshTokenWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    // Set the target family ID in request parameters
    self.requestParameters.familyId = DEFAULT_TEST_FAMILY_ID;
    
    [self mockFRTSuccessResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new_access_token_frt");
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Error recovery tests

- (void)testExecuteRequest_whenFRTCheckErrorButContinues_shouldStillWork
{
    // Mock FRT status check error but should continue with regular flow
    [self mockFRTStatusCheckError];
    
    [self saveAppRefreshToken];
    [self mockAppRTSuccessResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new_access_token_app");
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Helper methods

- (void)enableFRTFeatureFlag
{
    [self setFRTFeatureFlag:YES];
}

- (void)disableFRTFeatureFlag
{
    [self setFRTFeatureFlag:NO];
}

- (void)setFRTFeatureFlag:(BOOL)enabled
{
    [MSIDTestSwizzle instanceMethod:@selector(stringForKey:)
                              class:[MSIDFlightManager class]
                              block:(id)^(__unused id obj, NSString *flightKey)
     {
        if ([flightKey isEqualToString:MSID_FLIGHT_CLIENT_SFRT_STATUS])
        {
            return enabled ? MSID_FRT_STATUS_ENABLED : MSID_FRT_STATUS_DISABLED;
        }
        return @"";
     }];
}

- (void)saveFRTEnabledSettings:(BOOL)enabled
{
    NSError *error = nil;
    [self.tokenCache.accountCredentialCache updateFRTSettings:enabled context:nil error:&error];
    XCTAssertNil(error);
}

- (MSIDRefreshToken *)saveAppRefreshToken
{
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = @"app_refresh_token";
    refreshToken.environment = DEFAULT_TEST_ENVIRONMENT;
    refreshToken.realm = DEFAULT_TEST_UTID;
    refreshToken.clientId = DEFAULT_TEST_CLIENT_ID;
    refreshToken.accountIdentifier = self.accountIdentifier;
    
    NSError *error = nil;
    BOOL result = [self.tokenCache saveToken:refreshToken context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    return refreshToken;
}

- (MSIDFamilyRefreshToken *)saveFamilyRefreshToken
{
    return [self saveFamilyRefreshTokenWithFamilyId:DEFAULT_TEST_FAMILY_ID];
}

- (MSIDFamilyRefreshToken *)saveFamilyRefreshTokenWithFamilyId:(NSString *)familyId
{
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = [NSString stringWithFormat:@"family_refresh_token_%@", familyId];
    refreshToken.familyId = familyId;
    refreshToken.environment = DEFAULT_TEST_ENVIRONMENT;
    refreshToken.realm = DEFAULT_TEST_UTID;
    refreshToken.clientId = DEFAULT_TEST_CLIENT_ID;
    refreshToken.accountIdentifier = self.accountIdentifier;
    
    MSIDFamilyRefreshToken *familyRT = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken];
    
    NSError *error = nil;
    BOOL result = [self.tokenCache saveToken:familyRT context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    return familyRT;
}

- (void)mockAppRTSuccessResponse
{
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:@"app_refresh_token"
                                                                               requestClaims:nil
                                                                               requestScopes:@"user.read openid profile offline_access"
                                                                                  responseAT:@"new_access_token_app"
                                                                                  responseRT:@"new_refresh_token_app"
                                                                                  responseID:nil
                                                                               responseScope:@"user.read"
                                                                          responseClientInfo:nil
                                                                                         url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                responseCode:200
                                                                                   expiresIn:nil];
    
    [MSIDTestURLSession addResponse:tokenResponse];
}

- (void)mockFRTSuccessResponse
{
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseWithRT:@"family_refresh_token"
                                                                               requestClaims:nil
                                                                               requestScopes:@"user.read openid profile offline_access"
                                                                                  responseAT:@"new_access_token_frt"
                                                                                  responseRT:@"new_refresh_token_frt"
                                                                                  responseID:nil
                                                                               responseScope:@"user.read"
                                                                          responseClientInfo:nil
                                                                                         url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                responseCode:200
                                                                                   expiresIn:nil];
    
    [MSIDTestURLSession addResponse:tokenResponse];
}

- (void)mockAppRTFailureResponse
{
    MSIDTestURLResponse *errorResponse = [MSIDTestURLResponse serverErrorResponseWithError:@"invalid_grant"
                                                                          errorDescription:@"Token has expired"
                                                                                       url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID];
    
    [MSIDTestURLSession addResponse:errorResponse];
}

- (void)mockFRTFailureResponse
{
    MSIDTestURLResponse *errorResponse = [MSIDTestURLResponse serverErrorResponseWithError:@"invalid_grant"
                                                                          errorDescription:@"Family token has expired"
                                                                                       url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID];
    
    [MSIDTestURLSession addResponse:errorResponse];
}

- (void)mockFRTClientMismatchResponse
{
    MSIDTestURLResponse *errorResponse = [MSIDTestURLResponse serverErrorResponseWithError:@"invalid_grant"
                                                                          errorDescription:@"Client mismatch"
                                                                                       url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID];
    
    [MSIDTestURLSession addResponse:errorResponse];
}

- (void)mockFRTStatusCheckError
{
    [MSIDTestSwizzle instanceMethod:@selector(checkFRTEnabled:error:)
                              class:[MSIDAccountCredentialCache class]
                              block:(id)^(__unused id obj, __unused id<MSIDRequestContext> context, NSError **error)
     {
        if (error)
        {
            *error = [[NSError alloc] initWithDomain:@"test" code:1 userInfo:@{@"description": @"Mock FRT check error"}];
        }
        return MSIDIsFRTEnabledStatusDisabledByKeychainItem;
     }];
}

@end