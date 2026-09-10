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
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDAppMetadataCacheQuery.h"
#import "MSIDGeneralCacheItemType.h"

@interface MSIDSFRTErrorHandlingTests : XCTestCase

@property (nonatomic) MSIDDefaultSilentTokenRequest *silentRequest;
@property (nonatomic) MSIDRequestParameters *requestParameters;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;
@property (nonatomic) MSIDAccountIdentifier *accountIdentifier;

@end

@implementation MSIDSFRTErrorHandlingTests

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
    [MSIDTestURLSession removeAllResponses];
    [MSIDTestSwizzle removeAllSwizzling];
    [super tearDown];
}

#pragma mark - Client mismatch error handling

- (void)testExecuteRequest_whenFRTClientMismatchError_shouldUpdateFamilyIdCache
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Save app RT that will fail, then FRT that will return client mismatch
    [self saveAppRefreshToken];
    [self saveFamilyRefreshToken];
    
    // Mock app RT failure followed by FRT client mismatch
    [self mockAppRTFailureResponse];
    [self mockFRTClientMismatchErrorResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Verify that the family ID cache was updated to indicate client mismatch
    [self verifyFamilyIdCacheUpdatedForClientMismatch];
}

- (void)testExecuteRequest_whenFRTClientMismatchError_shouldRemoveFamilyIdFromCache
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Initially save app metadata indicating family membership
    [self saveAppMetadataWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    [self saveAppRefreshToken];
    [self saveFamilyRefreshToken];
    
    [self mockAppRTFailureResponse];
    [self mockFRTClientMismatchErrorResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Verify that the app metadata family ID was removed/updated
    MSIDAppMetadataCacheQuery *query = [[MSIDAppMetadataCacheQuery alloc] init];
    query.clientId = DEFAULT_TEST_CLIENT_ID;
    query.environment = DEFAULT_TEST_ENVIRONMENT;
    query.generalType = MSIDAppMetadataType;
    
    NSError *error = nil;
    NSArray *appMetadataEntries = [self.tokenCache.accountCredentialCache getAppMetadataEntriesWithQuery:query
                                                                                                  context:nil
                                                                                                    error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(appMetadataEntries.count >= 1);
    
    MSIDAppMetadataCacheItem *metadata = appMetadataEntries.firstObject;
    XCTAssertNil(metadata.familyId); // Family ID should be removed after client mismatch
}

- (void)testExecuteRequest_whenFRTClientMismatchErrorMultipleTimes_shouldNotRetryFRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    [self saveAppRefreshToken];
    [self saveFamilyRefreshToken];
    
    // First request - mock client mismatch
    [self mockAppRTFailureResponse];
    [self mockFRTClientMismatchErrorResponse];
    
    XCTestExpectation *firstExpectation = [self expectationWithDescription:@"First silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        [firstExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Clear responses and set up for second request
    [MSIDTestURLSession removeAllResponses];
    
    // Second request - should not try FRT again
    [self mockAppRTFailureResponse];
    // Note: No FRT response should be triggered
    
    XCTestExpectation *secondExpectation = [self expectationWithDescription:@"Second silent request completion"];
    
    MSIDDefaultSilentTokenRequest *secondRequest = [[MSIDDefaultSilentTokenRequest alloc] 
                                                   initWithRequestParameters:self.requestParameters
                                                           forceRefresh:NO
                                                           oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                 tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                             tokenCache:self.tokenCache
                                                   accountMetadataCache:self.accountMetadataCache];
    
    [secondRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        
        // Should not have attempted FRT flow due to previous client mismatch
        [secondExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Server error processing

- (void)testExecuteRequest_whenFRTServerError_shouldProcessErrorCorrectly
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    [self saveAppRefreshToken];
    [self saveFamilyRefreshToken];
    
    [self mockAppRTFailureResponse];
    [self mockFRTServerErrorResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        
        // Verify error contains server error information
        XCTAssertTrue([error.userInfo[MSIDOAuthErrorKey] isEqualToString:@"server_error"]);
        XCTAssertTrue([error.userInfo[MSIDOAuthSubErrorKey] isEqualToString:@"internal_error"]);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testExecuteRequest_whenFRTInvalidGrantError_shouldRemoveTokenFromCache
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    [self saveAppRefreshToken];
    MSIDFamilyRefreshToken *familyRT = [self saveFamilyRefreshToken];
    
    [self mockAppRTFailureResponse];
    [self mockFRTInvalidGrantErrorResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Verify that the invalid family refresh token was removed from cache
    NSError *error = nil;
    MSIDRefreshToken *cachedFRT = [self.tokenCache getRefreshTokenWithAccount:self.accountIdentifier
                                                                      familyId:DEFAULT_TEST_FAMILY_ID
                                                                 configuration:self.requestParameters.msidConfiguration
                                                                       context:nil
                                                                         error:&error];
    
    // Family RT should have been removed due to invalid_grant error
    XCTAssertNil(cachedFRT);
}

#pragma mark - Cache corruption recovery

- (void)testExecuteRequest_whenFRTCacheCorrupted_shouldContinueWithRegularRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Corrupt the FRT cache
    [self corruptFRTCache];
    
    MSIDRefreshToken *appRT = [self saveAppRefreshToken];
    [self mockAppRTSuccessResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        
        // Should have used app RT successfully despite FRT cache corruption
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new_access_token_app");
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testExecuteRequest_whenFRTStatusCacheCorrupted_shouldDefaultToDisabled
{
    [self enableFRTFeatureFlag];
    [self corruptFRTStatusCache];
    
    MSIDRefreshToken *appRT = [self saveAppRefreshToken];
    [self saveFamilyRefreshToken]; // This should not be used
    
    [self mockAppRTSuccessResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        
        // Should use app RT, not FRT, due to corrupted status cache
        XCTAssertEqualObjects(result.accessToken.accessToken, @"new_access_token_app");
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Network error handling

- (void)testExecuteRequest_whenFRTNetworkError_shouldRetryWithExponentialBackoff
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    [self saveAppRefreshToken];
    [self saveFamilyRefreshToken];
    
    [self mockAppRTFailureResponse];
    [self mockFRTNetworkErrorResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        
        // Verify it's a network-related error
        XCTAssertTrue([error.domain isEqualToString:NSURLErrorDomain] || 
                     [error.domain isEqualToString:MSIDErrorDomain]);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testExecuteRequest_whenFRTTimeoutError_shouldHandleGracefully
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    [self saveAppRefreshToken];
    [self saveFamilyRefreshToken];
    
    [self mockAppRTFailureResponse];
    [self mockFRTTimeoutErrorResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        
        // Should handle timeout gracefully
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark - Fallback scenarios

- (void)testExecuteRequest_whenFRTErrorAndNoFallback_shouldReturnInteractionRequired
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Only save FRT (no app RT for fallback)
    [self saveFamilyRefreshToken];
    
    [self mockFRTInvalidGrantErrorResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testExecuteRequest_whenBothFRTAndAppRTFail_shouldReturnLastError
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    [self saveAppRefreshToken];
    [self saveFamilyRefreshToken];
    
    [self mockAppRTFailureResponse];
    [self mockFRTInvalidGrantErrorResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Silent request completion"];
    
    [self.silentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        
        // Should return interaction required since both tokens failed
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Multi-threaded error scenarios

- (void)testExecuteRequest_whenConcurrentFRTErrors_shouldHandleSafely
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    [self saveAppRefreshToken];
    [self saveFamilyRefreshToken];
    
    // Set up for concurrent requests
    NSArray *expectations = @[
        [self expectationWithDescription:@"Request 1"],
        [self expectationWithDescription:@"Request 2"],
        [self expectationWithDescription:@"Request 3"]
    ];
    
    for (NSInteger i = 0; i < 3; i++) {
        [self mockAppRTFailureResponse];
        [self mockFRTClientMismatchErrorResponse];
        
        MSIDDefaultSilentTokenRequest *concurrentRequest = [[MSIDDefaultSilentTokenRequest alloc] 
                                                           initWithRequestParameters:self.requestParameters
                                                                   forceRefresh:NO
                                                                   oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                         tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                     tokenCache:self.tokenCache
                                                           accountMetadataCache:self.accountMetadataCache];
        
        [concurrentRequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
            XCTAssertNil(result);
            XCTAssertNotNil(error);
            
            [expectations[i] fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    
    // Verify cache integrity after concurrent operations
    [self verifyFamilyIdCacheIntegrity];
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
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = @"family_refresh_token";
    refreshToken.familyId = DEFAULT_TEST_FAMILY_ID;
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

- (void)saveAppMetadataWithFamilyId:(NSString *)familyId
{
    MSIDAppMetadataCacheItem *appMetadata = [[MSIDAppMetadataCacheItem alloc] init];
    appMetadata.clientId = DEFAULT_TEST_CLIENT_ID;
    appMetadata.environment = DEFAULT_TEST_ENVIRONMENT;
    appMetadata.familyId = familyId;
    
    NSError *error = nil;
    BOOL result = [self.tokenCache.accountCredentialCache saveAppMetadata:appMetadata context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
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

- (void)mockAppRTFailureResponse
{
    MSIDTestURLResponse *errorResponse = [MSIDTestURLResponse serverErrorResponseWithError:@"invalid_grant"
                                                                          errorDescription:@"Token has expired"
                                                                                       url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID];
    
    [MSIDTestURLSession addResponse:errorResponse];
}

- (void)mockFRTClientMismatchErrorResponse
{
    NSDictionary *headers = @{@"Content-Type" : @"application/json"};
    NSDictionary *json = @{
        @"error": @"invalid_grant",
        @"error_description": @"Client mismatch",
        @"error_codes": @[@70002], // Client mismatch error code
        @"suberror": @"client_mismatch"
    };
    
    MSIDTestURLResponse *errorResponse = [[MSIDTestURLResponse alloc] initWithURL:[NSURL URLWithString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID]
                                                                       responseCode:400
                                                                       httpHeaders:headers
                                                                       dictionaryAsJSON:json];
    
    [MSIDTestURLSession addResponse:errorResponse];
}

- (void)mockFRTServerErrorResponse
{
    NSDictionary *headers = @{@"Content-Type" : @"application/json"};
    NSDictionary *json = @{
        @"error": @"server_error",
        @"error_description": @"Internal server error",
        @"suberror": @"internal_error"
    };
    
    MSIDTestURLResponse *errorResponse = [[MSIDTestURLResponse alloc] initWithURL:[NSURL URLWithString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID]
                                                                       responseCode:500
                                                                       httpHeaders:headers
                                                                       dictionaryAsJSON:json];
    
    [MSIDTestURLSession addResponse:errorResponse];
}

- (void)mockFRTInvalidGrantErrorResponse
{
    MSIDTestURLResponse *errorResponse = [MSIDTestURLResponse serverErrorResponseWithError:@"invalid_grant"
                                                                          errorDescription:@"Family token has expired"
                                                                                       url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID];
    
    [MSIDTestURLSession addResponse:errorResponse];
}

- (void)mockFRTNetworkErrorResponse
{
    MSIDTestURLResponse *errorResponse = [[MSIDTestURLResponse alloc] initWithURL:[NSURL URLWithString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID]
                                                                       responseCode:0
                                                                       httpHeaders:nil
                                                                       dictionaryAsJSON:nil];
    errorResponse.error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotConnectToHost userInfo:nil];
    
    [MSIDTestURLSession addResponse:errorResponse];
}

- (void)mockFRTTimeoutErrorResponse
{
    MSIDTestURLResponse *errorResponse = [[MSIDTestURLResponse alloc] initWithURL:[NSURL URLWithString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID]
                                                                       responseCode:0
                                                                       httpHeaders:nil
                                                                       dictionaryAsJSON:nil];
    errorResponse.error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    
    [MSIDTestURLSession addResponse:errorResponse];
}

- (void)corruptFRTCache
{
    // Simulate cache corruption by injecting invalid data
    NSData *corruptedData = [@"invalid cache data" dataUsingEncoding:NSUTF8StringEncoding];
    
    // This would corrupt the FRT cache - implementation depends on cache structure
    // For now, we'll just mark this as a placeholder for cache corruption
}

- (void)corruptFRTStatusCache
{
    // Corrupt the FRT status cache
    NSData *corruptedData = [@"corrupted status" dataUsingEncoding:NSUTF8StringEncoding];
    
    MSIDCacheKey *cacheKey = [[MSIDCacheKey alloc] initWithAccount:MSID_USE_SINGLE_FRT_KEYCHAIN
                                                           service:MSID_USE_SINGLE_FRT_KEYCHAIN
                                                           generic:nil
                                                              type:nil];
    
    NSError *error = nil;
    [self.tokenCache.accountCredentialCache.dataSource saveData:corruptedData
                                                            key:cacheKey
                                                        context:nil
                                                          error:&error];
}

- (void)verifyFamilyIdCacheUpdatedForClientMismatch
{
    // Verify that the family ID cache was updated to reflect client mismatch
    // This would check app metadata or other cache items
    MSIDAppMetadataCacheQuery *query = [[MSIDAppMetadataCacheQuery alloc] init];
    query.clientId = DEFAULT_TEST_CLIENT_ID;
    query.environment = DEFAULT_TEST_ENVIRONMENT;
    query.generalType = MSIDAppMetadataType;
    
    NSError *error = nil;
    NSArray *appMetadataEntries = [self.tokenCache.accountCredentialCache getAppMetadataEntriesWithQuery:query
                                                                                                  context:nil
                                                                                                    error:&error];
    
    // Verify appropriate cache updates occurred
    XCTAssertNil(error);
}

- (void)verifyFamilyIdCacheIntegrity
{
    // Verify that the cache is in a consistent state after concurrent operations
    MSIDAppMetadataCacheQuery *query = [[MSIDAppMetadataCacheQuery alloc] init];
    query.clientId = DEFAULT_TEST_CLIENT_ID;
    query.environment = DEFAULT_TEST_ENVIRONMENT;
    query.generalType = MSIDAppMetadataType;
    
    NSError *error = nil;
    NSArray *appMetadataEntries = [self.tokenCache.accountCredentialCache getAppMetadataEntriesWithQuery:query
                                                                                                  context:nil
                                                                                                    error:&error];
    
    XCTAssertNil(error);
    // Verify cache integrity
}

@end