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
#import "MSIDTestIdentifiers.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDLRUCache.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse.h"
#import "MSIDDefaultSilentTokenRequest.h"
#import "MSIDSSOExtensionSilentTokenRequest.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDRequestParameters.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDAADRefreshTokenGrantRequest.h"
#import "MSIDRefreshToken.h"
#import "MSIDClaimsRequest.h"
#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDIntuneInMemoryCacheDataSource.h"
#import "MSIDIntuneMAMResourcesCache.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDThrottlingServiceMock.h"
#import "MSIDThrottlingModelBase.h"
#import "MSIDTestSwizzle.h"
#import "MSIDAccessToken.h"
#import "MSIDTokenResult.h"
#import "NSError+MSIDExtensions.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDTokenResponseHandler.h"
#import "MSIDAADRefreshTokenGrantRequest.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDInteractiveTokenRequest.h"
#import "MSIDDefaultTokenRequestProvider.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDAuthority.h"
#import "MSIDBrokerOperationSilentTokenRequest.h"
#import "MSIDThrottlingMetaDataCache.h"
#if MSID_ENABLE_SSO_EXTENSION
#import "MSIDSSOExtensionSilentTokenRequestController.h"
#import "MSIDSilentController+Internal.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDSSOExtensionSilentTokenRequest.h"
#import "MSIDSSOTokenResponseHandler.h"
#endif

#pragma mark - category methods for unit test

#define MSID_INTUNE_RESOURCE_ID @"intune_mam_resource_V"
#define MSID_INTUNE_RESOURCE_ID_VERSION @"1"
#define MSID_INTUNE_RESOURCE_ID_KEY (MSID_INTUNE_RESOURCE_ID MSID_INTUNE_RESOURCE_ID_VERSION)

#if TARGET_OS_IPHONE
    NSString *const MSIDThrottlingKeychainGroup = @"com.microsoft.adalcache";
#else
    NSString *const MSIDThrottlingKeychainGroup = @"com.microsoft.identity.universalstorage";
#endif


@interface MSIDSSOExtensionSilentTokenRequest (MSIDThrottlingServiceIntegrationTests)

@property (nonatomic) MSIDBrokerOperationSilentTokenRequest *operationRequest;

@end




@interface MSIDThrottlingService (MSIDThrottlingServiceIntegrationTests)

@property (nonatomic) NSUInteger shouldThrottleRequestInvokedCount;
@property (nonatomic) NSUInteger updateThrottlingServiceInvokedCount;

@end

@interface MSIDSilentTokenRequest (MSIDThrottlingServiceIntegrationTests)

@property (nonatomic) MSIDThrottlingService *throttlingService;

- (void)acquireTokenWithRefreshTokenImpl:(MSIDBaseToken<MSIDRefreshableToken> *)refreshToken
                         completionBlock:(MSIDRequestCompletionBlock)completionBlock;


@property (nonatomic) MSIDAccessToken *extendedLifetimeAccessToken;

@end

@interface MSIDDefaultSilentTokenRequest (MSIDThrottlingServiceIntegrationTests)

- (nullable MSIDTokenResult *)resultWithAccessToken:(MSIDAccessToken *)accessToken
                                       refreshToken:(id<MSIDRefreshableToken>)refreshToken
                                              error:(__unused NSError * _Nullable * _Nullable)error;

@end

@interface MSIDThrottlingServiceIntegrationTests : XCTestCase

@property (nonatomic) NSString *enrollmentId;
@property (nonatomic) NSString *refreshToken;
@property (nonatomic) NSString *grant_type;
@property (nonatomic) NSString *claims;
@property (nonatomic) MSIDOauth2Factory *oauthFactory;
@property (nonatomic) NSString *oidcScopeString;
@property (nonatomic) NSString *atRequestClaim;
@property (nonatomic) NSString *redirectUri;
@property (nonatomic) MSIDKeychainTokenCache *keychainTokenCache;

@end

@implementation MSIDThrottlingServiceIntegrationTests

#pragma mark - Helper APIs

- (MSIDDefaultTokenCacheAccessor *)tokenCache
{
    id<MSIDExtendedTokenCacheDataSource> dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:MSIDThrottlingKeychainGroup error:nil];
    MSIDDefaultTokenCacheAccessor *tokenCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    return tokenCache;
}

- (MSIDAccountMetadataCacheAccessor *)accountMetadataCache
{
    id<MSIDMetadataCacheDataSource> dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:MSIDThrottlingKeychainGroup error:nil];
    MSIDAccountMetadataCacheAccessor *accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
    return accountMetadataCache;
}

- (MSIDRequestParameters *)silentRequestParameters
{
    MSIDRequestParameters *parameters = [MSIDRequestParameters new];
    parameters.authority = [DEFAULT_TEST_AUTHORITY_GUID aadAuthority]; //MSIDAADAuthority
    parameters.clientId = @"my_client_id";
    parameters.target = @"user.read tasks.read";
    parameters.oidcScope = self.oidcScopeString;
    parameters.redirectUri = self.redirectUri;
    parameters.correlationId = [NSUUID new];
    parameters.extendedLifetimeEnabled = YES;
    parameters.keychainAccessGroup = MSIDThrottlingKeychainGroup;

   
    //claims request and capabilities - used by AADV2Authority refreshTokenRequestWithRequestParameters
    parameters.claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:@{@"id_token":@{@"polids":@{@"essential":@YES,@"values":@[@"d77e91f0-fc60-45e4-97b8-14a1337faa28"]}}} error:nil];
    parameters.clientCapabilities = @[@"cp1", @"llt"];
    //enrollmentID Cache
    NSDictionary *enrollmentJsonDict = @{MSID_INTUNE_ENROLLMENT_ID_KEY: @{@"enrollment_ids": @[@{
                                                                                     @"tid" : @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1",
                                                                                     @"oid" : @"d3444455-mike-4271-b6ea-e499cc0cab46",
                                                                                     @"home_account_id" : @"60406d5d-mike-41e1-aa70-e97501076a22",
                                                                                     @"user_id" : @"mike@contoso.com",
                                                                                     @"enrollment_id" : @"adf79e3f-mike-454d-9f0f-2299e76dbfd5"
                                                                                     },
                                                                                 @{
                                                                                     @"tid" : @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1",
                                                                                     @"oid" : @"6eec576f-dave-416a-9c4a-536b178a194a",
                                                                                     @"home_account_id" : @"1e4dd613-dave-4527-b50a-97aca38b57ba",
                                                                                     @"user_id" : @"dave@contoso.com",
                                                                                     @"enrollment_id" : @"64d0557f-dave-4193-b630-8491ffd3b180"
                                                                                     }
                                                                                 ]},
                                         MSID_INTUNE_RESOURCE_ID_KEY: @{@"resource_ids": @[@{
                                                                                                @"resource1" : @"dummyResourceForSSO1",
                                                                                                @"resource2" : @"dummyResourceForSSO2",
                                                                                                @"resource3" : @"dummyResourceForSSO3",
                                                                                                }
                                                                                            ]}
                                         
    };
    
    MSIDCache *msidCache = [[MSIDCache alloc] initWithDictionary:enrollmentJsonDict];
    MSIDIntuneInMemoryCacheDataSource *memoryCache = [[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:msidCache];
    MSIDIntuneEnrollmentIdsCache *enrollmentIdsCache = [[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:memoryCache];
    [MSIDIntuneEnrollmentIdsCache setSharedCache:enrollmentIdsCache];
    //intune mem resources cache
    MSIDIntuneMAMResourcesCache *mamResourceCache = [[MSIDIntuneMAMResourcesCache alloc] initWithDataSource:memoryCache];
    [MSIDIntuneMAMResourcesCache setSharedCache:mamResourceCache];
    
    return parameters;

}

- (void)setUp
{
    self.enrollmentId = @"customEnrollmentId";
    self.refreshToken = @"0.ARwAkq1F9o3jGk21ENGwmnSoygQgkidRUjBAsi2R7NmjfqQcADo.AgABAAAAAAB2UyzwtQEKR7-rWbgdcBZIAQDs_wIA9P-pC2Jew17JPTq51nYIbMNBqYUqRXoKqMeuNo-JnIaqgCULiag74RahCkNed_oy_TEIxdkb_rrCvkzifvcwVkSdJOdQkW452s9ZC8cdEwtaGviimxLF3CpI9yoTdKUV3Vy7raNooYEli1B1LcSFYkltLQvgiaU-YRZ5hpRAaCyB6s6x3mJc7-LVHDdSVu4RNc_fgp16HumZNF-ZiHxRCHGfYZL3MQNi8c-FVmV6-qh-yb0GQqEYH3qoQbiOjwPWg92npuH7AMzZyudgOBvKf07e5Nzn0393Yp9fK4W9pfGMDscvV_shos8S296w-ckcOFdVepnCJtGUIqIX3UuHXyYBkAlMEifuO_PfcmRMgwuX8suEGnm1N0rFWhOjHjOSw6koy0KV45nL5Ln3ktx2z1Hey0bHxV2wWq42bAnn2L8xgB-8UvNifRQC2045Ws0QKmV2yIw1fkz9WHukHdxVCdLiz1ZYeGbxyh_khiJfCk3iFu7j1cHChd7ajrX3XPzZoLusDTWY6sbsijafV6G7cHAndD64G1XEcUZ2M2ZmrNi7-uOA6-dkKyQ-btbE47fvTKhY1UCQ6f3Qu6IFrAEeG6zeOcWzIVMWRHVdp5PPrnzOCyqiYAxkpW6X65KqI2Wa4Cyb2hFczQxbmDm_MKpLPQBDJm4kqNpa1h1BBkgpLCh_H-jwQGBaJoatGWhdKQNUIS7G17DvMV-6EGBb1YQmlFzUEaxFRbFCrOc2e_XtfNl8fAq5pQYDNuygDy8Yw2B9Gj3F3hlZTGMJ4UXPRliuNH0lAoXNy78wjNytPaR3TAEghimZvT-B08JTjz8WWuwpoXBHzhw_noida5dlL1GL4yHv77zwXh3ntqCjJJajX-prpADK8yyq9xscq8mTtzgdIVgbeDy_5sfvgygNnnAw5x0aPj_-lDNgZ";
    self.claims = @"customRefreshTokenClaims";
    self.oidcScopeString = @"user.read tasks.read openid profile offline_access";
    self.atRequestClaim = @"{\"access_token\":{\"xms_cc\":{\"values\":[\"cp1\",\"llt\"]}},\"id_token\":{\"polids\":{\"values\":[\"d77e91f0-fc60-45e4-97b8-14a1337faa28\"],\"essential\":true}}}";
    self.redirectUri = @"x-msauth-outlook-prod://com.microsoft.Office.Outlook";
    self.keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:MSIDThrottlingKeychainGroup error:nil];

    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[MSIDLRUCache sharedInstance] removeAllObjects:nil];
    [MSIDIntuneEnrollmentIdsCache.sharedCache clear];
    [MSIDIntuneMAMResourcesCache.sharedCache clear];
    [self.keychainTokenCache clearWithContext:nil error:nil];
}



#pragma mark - nonSSO Silent Request Tests
- (void)testMSIDThrottlingServiceIntegration_NonSSOSilentRequestThatReturns429Response_ShouldBeThrottledByThrottlingService
{
    MSIDDefaultSilentTokenRequest *defaultSilentTokenRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:self.silentRequestParameters
                                                                                                                   forceRefresh:NO
                                                                                                                   oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                         tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                                     tokenCache:self.tokenCache
                                                                                                           accountMetadataCache:self.accountMetadataCache];
    
    
    //refresh token
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = self.refreshToken;
    
    //throttlingServiceMock
    MSIDThrottlingServiceMock *throttlingServiceMock = [[MSIDThrottlingServiceMock alloc] initWithDataSource:self.keychainTokenCache
                                                                                                     context:self.silentRequestParameters];

    
    defaultSilentTokenRequest.throttlingService = throttlingServiceMock;

    [MSIDTestSwizzle instanceMethod:@selector(tokenEndpoint)
                              class:[MSIDRequestParameters class]
                              block:(id)^(void)
    {
       return [[NSURL alloc] initWithString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID];

    }];
   
    
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseForThrottling:self.refreshToken
                                                                                       requestClaims:self.atRequestClaim
                                                                                       requestScopes:self.oidcScopeString
                                                                                          responseAT:@"new at"
                                                                                          responseRT:self.refreshToken
                                                                                          responseID:nil
                                                                                       responseScope:@"user.read tasks.read"
                                                                                  responseClientInfo:nil
                                                                                                 url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                        responseCode:429
                                                                                           expiresIn:nil
                                                                                        enrollmentId:@"adf79e3f-mike-454d-9f0f-2299e76dbfd5"
                                                                                         redirectUri:self.redirectUri
                                                                                            clientId:self.silentRequestParameters.clientId];

    
    tokenResponse->_error = [NSError new];
    NSDictionary *userInfo = @{MSIDHTTPResponseCodeKey : @"429",
                               MSIDHTTPHeadersKey: @{
                                    @"Retry-After": @"100"
                               }
                            };


    tokenResponse->_error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"429 error test", @"oAuthError", @"subError", nil, nil, userInfo, NO);
    
    
    //First attempt - there shouldn't be any throttling
    [MSIDTestURLSession addResponse:tokenResponse];
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"silent request"];
    [defaultSilentTokenRequest acquireTokenWithRefreshTokenImpl:refreshToken completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        //First time around, no throttling
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.shouldThrottleRequestInvokedCount,0);
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.updateThrottlingServiceInvokedCount,1);
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        [expectation1 fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    

    NSError *subError = nil;
    NSString *expectedThumbprintKey = @"9671032187006166342";
    //check and see if cache record exists that is mapped by the thumbprint value
    MSIDThrottlingCacheRecord *record = [[MSIDLRUCache sharedInstance] objectForKey:expectedThumbprintKey error:&subError];
    XCTAssertNotNil(record);
    XCTAssertNil(subError);
    
    XCTAssertEqual(record.throttleType,MSIDThrottlingType429);
    XCTAssertEqualObjects(record.cachedErrorResponse,tokenResponse->_error);
    XCTAssertEqual(record.throttledCount,1);


    [MSIDTestURLSession addResponse:tokenResponse];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"throttled request"];
    [defaultSilentTokenRequest acquireTokenWithRefreshTokenImpl:refreshToken completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        //Second time, throttle, also check updateThrottlingServiceInvokedCount to make sure that logic didn't get hit.
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.shouldThrottleRequestInvokedCount,1);
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.updateThrottlingServiceInvokedCount,1);
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        [expectation2 fulfill];
    }];
    

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
        

}


- (void)testMSIDThrottlingServiceIntegration_ThrottledNonSSOSilentRequestThatReturns429Response_ShouldBeClearedAndNotThrottledUponExpiration
{
    
    NSString *refreshTokenForThisTest = @"customRTForThisTest";
    MSIDRequestParameters *newRequestParam = self.silentRequestParameters;
    newRequestParam.clientId = @"customClientId";
    newRequestParam.oidcScope = @"dummyScopeForThisTest";
    newRequestParam.target = @"dummyTarget";

    
    MSIDDefaultSilentTokenRequest *defaultSilentTokenRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:newRequestParam
                                                                                                                   forceRefresh:NO
                                                                                                                   oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                         tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                                     tokenCache:self.tokenCache
                                                                                                           accountMetadataCache:self.accountMetadataCache];
    
    
    //refresh token
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = refreshTokenForThisTest;
    
    //throttlingServiceMock
   MSIDThrottlingServiceMock *throttlingServiceMock = [[MSIDThrottlingServiceMock alloc] initWithDataSource:self.keychainTokenCache
                                                                                                    context:self.silentRequestParameters];
    
    defaultSilentTokenRequest.throttlingService = throttlingServiceMock;
    
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseForThrottling:refreshTokenForThisTest
                                                                                       requestClaims:self.atRequestClaim
                                                                                       requestScopes:@"dummyTarget dummyScopeForThisTest"
                                                                                          responseAT:@"new at"
                                                                                          responseRT:refreshTokenForThisTest
                                                                                          responseID:nil
                                                                                       responseScope:@"dummyTarget dummyScopeForThisTest"
                                                                                  responseClientInfo:nil
                                                                                                 url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                        responseCode:429
                                                                                           expiresIn:nil
                                                                                        enrollmentId:@"adf79e3f-mike-454d-9f0f-2299e76dbfd5"
                                                                                         redirectUri:self.redirectUri
                                                                                            clientId:newRequestParam.clientId];

    
    tokenResponse->_error = [NSError new];
    NSDictionary *userInfo = @{MSIDHTTPResponseCodeKey : @"429",
                               MSIDHTTPHeadersKey: @{
                                    @"Retry-After": @"-5"
                               }
                            };


    tokenResponse->_error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"429 error test", @"oAuthError", @"subError", nil, nil, userInfo, NO);
    
    [MSIDTestSwizzle instanceMethod:@selector(tokenEndpoint)
                             class:[MSIDRequestParameters class]
                             block:(id)^(void)
    {
       return [[NSURL alloc] initWithString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID];

    }];

   [MSIDTestSwizzle classMethod:@selector(dateWithTimeIntervalSinceNow:)
                          class:[NSDate class]
                          block:(id)^(void)
   {
      return [[NSDate new] dateByAddingTimeInterval:-10];

   }];
   
   
    
    //First attempt - there shouldn't be any throttling
    [MSIDTestURLSession addResponse:tokenResponse];
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"silent request"];
    [defaultSilentTokenRequest acquireTokenWithRefreshTokenImpl:refreshToken completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        //First time around, no throttling
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.shouldThrottleRequestInvokedCount,0);
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.updateThrottlingServiceInvokedCount,1);
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    NSError *subError = nil;
    NSString *expectedThumbprintKey = @"6959237555979563609";
    //check and see if cache record exists that is mapped by the thumbprint value
    MSIDThrottlingCacheRecord *record = [[MSIDLRUCache sharedInstance] objectForKey:expectedThumbprintKey error:&subError];
    XCTAssertNotNil(record);
    XCTAssertNil(subError);
    
    XCTAssertEqual(record.throttleType,MSIDThrottlingType429);
    XCTAssertEqualObjects(record.cachedErrorResponse,tokenResponse->_error);
    XCTAssertEqual(record.throttledCount,1);
    
 
    //Second attempt - throttling should be triggered
    [MSIDTestURLSession addResponse:tokenResponse];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"throttled request"];
    [defaultSilentTokenRequest acquireTokenWithRefreshTokenImpl:refreshToken completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        //Request shouldn't get throttled this time, since it has already expired.
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.shouldThrottleRequestInvokedCount,0);
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.updateThrottlingServiceInvokedCount,2);
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        [expectation2 fulfill];
    }];
    
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    
}

- (void)testMSIDThrottlingServiceIntegration_NonSSOSilentRequestThatHasExtendedLifeTimeEnabled_ShouldReturnTokenResultInitially_AndThenThrottled
{
    //modulating strict request thumbprint parameters.
    NSString *refreshTokenForThisTest = @"extendedRT";
    MSIDRequestParameters *newRequestParam = self.silentRequestParameters;
    newRequestParam.clientId = @"joeRogan";
    newRequestParam.oidcScope = @"joeRoganScope";
    newRequestParam.target = @"joeRoganTarget";
    NSString *customScopeForTokenResponse = [NSString stringWithFormat:@"%@ %@", newRequestParam.target, newRequestParam.oidcScope];
    

    
    MSIDDefaultSilentTokenRequest *defaultSilentTokenRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:newRequestParam
                                                                                                                   forceRefresh:NO
                                                                                                                   oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                         tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                                     tokenCache:self.tokenCache
                                                                                                           accountMetadataCache:self.accountMetadataCache];
    //add extended lifetime access token
    defaultSilentTokenRequest.extendedLifetimeAccessToken = [MSIDAccessToken new];
    
    
    //refresh token
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = refreshTokenForThisTest;
   
    //Swizzle resultWithAccessToken
    __block NSUInteger extendedAccessTokenInvokedCount = 0;
    [MSIDTestSwizzle instanceMethod:@selector(resultWithAccessToken:refreshToken:error:)
                              class:[MSIDDefaultSilentTokenRequest class]
                              block:(id)^(void)
    {
         extendedAccessTokenInvokedCount++;
         MSIDTokenResult *result = [MSIDTokenResult new];
         return result;
    }];
    
   
    
    //throttlingServiceMock
   MSIDThrottlingServiceMock *throttlingServiceMock = [[MSIDThrottlingServiceMock alloc] initWithDataSource:self.keychainTokenCache
                                                                                                    context:self.silentRequestParameters];
    
    defaultSilentTokenRequest.throttlingService = throttlingServiceMock;
    
   //first token response
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseForThrottling:refreshTokenForThisTest
                                                                                       requestClaims:self.atRequestClaim
                                                                                       requestScopes:customScopeForTokenResponse
                                                                                          responseAT:@"new at"
                                                                                          responseRT:refreshTokenForThisTest
                                                                                          responseID:nil
                                                                                       responseScope:customScopeForTokenResponse
                                                                                  responseClientInfo:nil
                                                                                                 url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                        responseCode:429
                                                                                           expiresIn:nil
                                                                                        enrollmentId:@"adf79e3f-mike-454d-9f0f-2299e76dbfd5"
                                                                                         redirectUri:self.redirectUri
                                                                                            clientId:newRequestParam.clientId];

    
    tokenResponse->_error = [NSError new];
    NSDictionary *userInfo = @{MSIDHTTPResponseCodeKey : @"429",
                               MSIDHTTPHeadersKey: @{
                                    @"Retry-After": @"100"
                               },
                               MSIDServerUnavailableStatusKey: @"notAvailable"
                            };


    tokenResponse->_error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"429 error test", @"oAuthError", @"subError", nil, nil, userInfo, NO);
    
    [MSIDTestSwizzle instanceMethod:@selector(tokenEndpoint)
                             class:[MSIDRequestParameters class]
                             block:(id)^(void)
    {
       return [[NSURL alloc] initWithString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID];

    }];
   
    
    //First attempt - there shouldn't be any throttling.
    //
    [MSIDTestURLSession addResponse:tokenResponse];
   
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"silent request"];
    [defaultSilentTokenRequest acquireTokenWithRefreshTokenImpl:refreshToken completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.shouldThrottleRequestInvokedCount,0);
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.updateThrottlingServiceInvokedCount,1);
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqual(extendedAccessTokenInvokedCount,1);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    NSError *subError = nil;
    NSString *expectedThumbprintKey = @"15218151831260745817";
    //check and see if cache record exists that is mapped by the thumbprint value
    MSIDThrottlingCacheRecord *record = [[MSIDLRUCache sharedInstance] objectForKey:expectedThumbprintKey error:&subError];
    XCTAssertNotNil(record);
    XCTAssertNil(subError);
    
    XCTAssertEqual(record.throttleType,MSIDThrottlingType429);
    XCTAssertEqualObjects(record.cachedErrorResponse,tokenResponse->_error);
    XCTAssertEqual(record.throttledCount,1);
    

    //Second attempt - throttling should be triggered
    [MSIDTestURLSession addResponse:tokenResponse];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"throttled request"];
    [defaultSilentTokenRequest acquireTokenWithRefreshTokenImpl:refreshToken completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.shouldThrottleRequestInvokedCount,1);
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.updateThrottlingServiceInvokedCount,1);
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        [expectation2 fulfill];
    }];
    
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    
}


- (void)testMSIDThrottlingServiceIntegration_NonSSOSilentRequestWithUIRequredError_ShouldBeThrottledAccordingly
{
    //modulating strict request thumbprint parameters.
    NSString *refreshTokenForThisTest = @"expiredRT";
    MSIDRequestParameters *newRequestParam = self.silentRequestParameters;
    newRequestParam.clientId = @"contosoClient";
    newRequestParam.oidcScope = @"contosoEmployeeScope";
    newRequestParam.target = @"contosoEmployeeTarget";
    NSString *customScopeForTokenResponse = [NSString stringWithFormat:@"%@ %@", newRequestParam.target, newRequestParam.oidcScope];
    

    
    MSIDDefaultSilentTokenRequest *defaultSilentTokenRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:newRequestParam
                                                                                                                   forceRefresh:NO
                                                                                                                   oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                         tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                                     tokenCache:self.tokenCache
                                                                                                           accountMetadataCache:self.accountMetadataCache];
    //add extended lifetime access token
    defaultSilentTokenRequest.extendedLifetimeAccessToken = [MSIDAccessToken new];
    
    
    //refresh token
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = refreshTokenForThisTest;
   

    //throttlingServiceMock
   MSIDThrottlingServiceMock *throttlingServiceMock = [[MSIDThrottlingServiceMock alloc] initWithDataSource:self.keychainTokenCache
                                                                                                    context:self.silentRequestParameters];
    defaultSilentTokenRequest.throttlingService = throttlingServiceMock;
    
   //first token response
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseForThrottling:refreshTokenForThisTest
                                                                                       requestClaims:self.atRequestClaim
                                                                                       requestScopes:customScopeForTokenResponse
                                                                                          responseAT:@"new at"
                                                                                          responseRT:refreshTokenForThisTest
                                                                                          responseID:nil
                                                                                       responseScope:customScopeForTokenResponse
                                                                                  responseClientInfo:nil
                                                                                                 url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                        responseCode:200
                                                                                           expiresIn:nil
                                                                                        enrollmentId:@"adf79e3f-mike-454d-9f0f-2299e76dbfd5"
                                                                                         redirectUri:self.redirectUri
                                                                                            clientId:newRequestParam.clientId];

   //initially token response should contain no error to trigger UI required error type (ex: invalid grant)
   tokenResponse->_error = nil;
    
   //Swizzle token endpoint
    [MSIDTestSwizzle instanceMethod:@selector(tokenEndpoint)
                             class:[MSIDRequestParameters class]
                             block:(id)^(void)
    {
       return [[NSURL alloc] initWithString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID];

    }];
   
   //Swizzle token response handler
   __block NSError *expectedError;
   [MSIDTestSwizzle instanceMethod:@selector(handleTokenResponse:
                                               requestParameters:
                                                   homeAccountId:
                                          tokenResponseValidator:
                                                    oauthFactory:
                                                      tokenCache:
                                            accountMetadataCache:
                                                 validateAccount:
                                                saveSSOStateOnly:
                                                           error:
                                                 completionBlock:)
                             class:[MSIDTokenResponseHandler class]
                             block:(id)^(
                                         __unused id obj,
                                         __unused MSIDTokenResponse *tokenResponse,
                                         __unused MSIDRequestParameters *requestParameters,
                                         __unused NSString *homeAccountId,
                                         __unused MSIDTokenResponseValidator *tokenResponseValidator,
                                         __unused MSIDOauth2Factory *oauthFactory,
                                         __unused id<MSIDCacheAccessor> tokenCache,
                                         __unused MSIDAccountMetadataCacheAccessor *accountMetadataCache,
                                         __unused BOOL validateAccount,
                                         __unused BOOL saveSSOStateOnly,
                                         __unused NSError *error,
                                         MSIDRequestCompletionBlock completionBlock)
    {
         NSError *subError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired, @"interaction_required test", @"invalid_grant", MSIDServerErrorBadToken, nil, nil, nil, NO);
         expectedError = subError;
         completionBlock(nil,subError);
         return;
   }];
   
   //Swizzle token cache accessor
   __block NSUInteger validateAndRemoveRefreshTokenInvokeCount = 0;
   [MSIDTestSwizzle instanceMethod:@selector(validateAndRemoveRefreshToken:context:error:)
                             class:[MSIDDefaultTokenCacheAccessor class]
                             block:(id)^(void)
    {
         validateAndRemoveRefreshTokenInvokeCount++;
         return YES;
   }];
   
   //Token grant request
   MSIDAADRefreshTokenGrantRequest *expectedRequest = (MSIDAADRefreshTokenGrantRequest *) [defaultSilentTokenRequest.oauthFactory refreshTokenRequestWithRequestParameters:defaultSilentTokenRequest.requestParameters
                                                                                                                                                              refreshToken:refreshTokenForThisTest];
   //expected full request thumbprint value
   NSString *expectedFullRequestThumbprintValue = [expectedRequest fullRequestThumbprint];
   
   //First attempt - there shouldn't be any throttling.
   [MSIDTestURLSession addResponse:tokenResponse];
   
   XCTestExpectation *expectation1 = [self expectationWithDescription:@"silent request with interaction require error"];
   [defaultSilentTokenRequest acquireTokenWithRefreshTokenImpl:refreshToken completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.shouldThrottleRequestInvokedCount,0);
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.updateThrottlingServiceInvokedCount,1);
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(validateAndRemoveRefreshTokenInvokeCount,1);
        [expectation1 fulfill];
   }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    NSError *subError = nil;
    //check and see if cache record exists that is mapped by the thumbprint value
    MSIDThrottlingCacheRecord *record = [[MSIDLRUCache sharedInstance] objectForKey:expectedFullRequestThumbprintValue error:&subError];
    XCTAssertNotNil(record);
    XCTAssertNil(subError);
    
    XCTAssertEqual(record.throttleType,MSIDThrottlingTypeInteractiveRequired);
    XCTAssertEqualObjects(record.cachedErrorResponse,expectedError);
    XCTAssertEqual(record.throttledCount,1);
    

    //Second attempt - throttling should be triggered
    [MSIDTestURLSession addResponse:tokenResponse];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"throttled request"];
    [defaultSilentTokenRequest acquireTokenWithRefreshTokenImpl:refreshToken completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.shouldThrottleRequestInvokedCount,1);
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.updateThrottlingServiceInvokedCount,1);
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}


//#if TARGET_OS_IPHONE
- (void)testMSIDThrottlingServiceIntegration_ThrottledNonSSOSilentRequestWithUIRequredError_ShouldBeClearedBySuccessfulIntearctiveRequest
{
    //modulating strict request thumbprint parameters.
    NSString *refreshTokenForThisTest = @"expiredRT2";
    MSIDRequestParameters *newRequestParam = self.silentRequestParameters;
    newRequestParam.clientId = @"contosoClient2";
    newRequestParam.oidcScope = @"contosoEmployeeScope2";
    newRequestParam.target = @"contosoEmployeeTarget2";
    NSString *customScopeForTokenResponse = [NSString stringWithFormat:@"%@ %@", newRequestParam.target, newRequestParam.oidcScope];
    

    
    MSIDDefaultSilentTokenRequest *defaultSilentTokenRequest = [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:newRequestParam
                                                                                                                   forceRefresh:NO
                                                                                                                   oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                         tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                                     tokenCache:self.tokenCache
                                                                                                           accountMetadataCache:self.accountMetadataCache];
    //add extended lifetime access token
    defaultSilentTokenRequest.extendedLifetimeAccessToken = [MSIDAccessToken new];
    
    
    //refresh token
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = refreshTokenForThisTest;
   

    //throttlingServiceMock
   MSIDThrottlingServiceMock *throttlingServiceMock = [[MSIDThrottlingServiceMock alloc] initWithDataSource:self.keychainTokenCache
                                                                                                    context:self.silentRequestParameters];
    
    defaultSilentTokenRequest.throttlingService = throttlingServiceMock;
    
   //first token response
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse refreshTokenGrantResponseForThrottling:refreshTokenForThisTest
                                                                                       requestClaims:self.atRequestClaim
                                                                                       requestScopes:customScopeForTokenResponse
                                                                                          responseAT:@"new at"
                                                                                          responseRT:refreshTokenForThisTest
                                                                                          responseID:nil
                                                                                       responseScope:customScopeForTokenResponse
                                                                                  responseClientInfo:nil
                                                                                                 url:DEFAULT_TEST_TOKEN_ENDPOINT_GUID
                                                                                        responseCode:200
                                                                                           expiresIn:nil
                                                                                        enrollmentId:@"adf79e3f-mike-454d-9f0f-2299e76dbfd5"
                                                                                         redirectUri:self.redirectUri
                                                                                            clientId:newRequestParam.clientId];

   //initially token response should contain no error to trigger UI required error type (ex: invalid grant)
   tokenResponse->_error = nil;
    
   //Swizzle token endpoint
    [MSIDTestSwizzle instanceMethod:@selector(tokenEndpoint)
                             class:[MSIDRequestParameters class]
                             block:(id)^(void)
    {
       return [[NSURL alloc] initWithString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID];

    }];
   
   //Swizzle token response handler
   __block NSError *expectedError;
   [MSIDTestSwizzle instanceMethod:@selector(handleTokenResponse:
                                               requestParameters:
                                                   homeAccountId:
                                          tokenResponseValidator:
                                                    oauthFactory:
                                                      tokenCache:
                                            accountMetadataCache:
                                                 validateAccount:
                                                saveSSOStateOnly:
                                                           error:
                                                 completionBlock:)
                             class:[MSIDTokenResponseHandler class]
                             block:(id)^(
                                         __unused id obj,
                                         __unused MSIDTokenResponse *tokenResponse,
                                         __unused MSIDRequestParameters *requestParameters,
                                         __unused NSString *homeAccountId,
                                         __unused MSIDTokenResponseValidator *tokenResponseValidator,
                                         __unused MSIDOauth2Factory *oauthFactory,
                                         __unused id<MSIDCacheAccessor> tokenCache,
                                         __unused MSIDAccountMetadataCacheAccessor *accountMetadataCache,
                                         __unused BOOL validateAccount,
                                         __unused BOOL saveSSOStateOnly,
                                         __unused NSError *error,
                                         MSIDRequestCompletionBlock completionBlock)
    {
         NSError *subError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired, @"interaction_required test", @"invalid_grant", MSIDServerErrorBadToken, nil, nil, nil, NO);
         expectedError = subError;
         completionBlock(nil,subError);
         return;
   }];
   
   //Swizzle token cache accessor
   __block NSUInteger validateAndRemoveRefreshTokenInvokeCount = 0;
   [MSIDTestSwizzle instanceMethod:@selector(validateAndRemoveRefreshToken:context:error:)
                             class:[MSIDDefaultTokenCacheAccessor class]
                             block:(id)^(void)
    {
         validateAndRemoveRefreshTokenInvokeCount++;
         return YES;
   }];
   
   //Token grant request
   MSIDAADRefreshTokenGrantRequest *expectedRequest = (MSIDAADRefreshTokenGrantRequest *) [defaultSilentTokenRequest.oauthFactory refreshTokenRequestWithRequestParameters:defaultSilentTokenRequest.requestParameters
                                                                                                                                                              refreshToken:refreshTokenForThisTest];
   //expected full request thumbprint value
   NSString *expectedFullRequestThumbprintValue = [expectedRequest fullRequestThumbprint];
   
   //First attempt - there shouldn't be any throttling.
   [MSIDTestURLSession addResponse:tokenResponse];
   
   XCTestExpectation *expectation1 = [self expectationWithDescription:@"silent request with interaction require error"];
   [defaultSilentTokenRequest acquireTokenWithRefreshTokenImpl:refreshToken completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.shouldThrottleRequestInvokedCount,0);
        XCTAssertEqual(defaultSilentTokenRequest.throttlingService.updateThrottlingServiceInvokedCount,1);
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(validateAndRemoveRefreshTokenInvokeCount,1);
        [expectation1 fulfill];
   }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    NSError *subError = nil;
    //check and see if cache record exists that is mapped by the thumbprint value
    MSIDThrottlingCacheRecord *record = [[MSIDLRUCache sharedInstance] objectForKey:expectedFullRequestThumbprintValue error:&subError];
    XCTAssertNotNil(record);
    XCTAssertNil(subError);
    
    XCTAssertEqual(record.throttleType,MSIDThrottlingTypeInteractiveRequired);
    XCTAssertEqualObjects(record.cachedErrorResponse,expectedError);
    XCTAssertEqual(record.throttledCount,1);
    


   //Now let's create an interactive request
   MSIDInteractiveTokenRequestParameters *interactiveRequestParameters = [MSIDInteractiveTokenRequestParameters new];
   interactiveRequestParameters.target = @"fakescope1 fakescope2";
   interactiveRequestParameters.authority = [@"https://login.microsoftonline.com/common" aadAuthority];
   interactiveRequestParameters.redirectUri = @"x-msauth-test://com.microsoft.testapp";
   interactiveRequestParameters.clientId = @"my_client_id";
   interactiveRequestParameters.extraAuthorizeURLQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
   interactiveRequestParameters.loginHint = @"fakeuser@contoso.com";
   interactiveRequestParameters.correlationId = [NSUUID UUID];
   interactiveRequestParameters.webviewType = MSIDWebviewTypeWKWebView;
   interactiveRequestParameters.extraScopesToConsent = @"fakescope3";
   interactiveRequestParameters.oidcScope = @"openid profile offline_access";
   interactiveRequestParameters.promptType = MSIDPromptTypeConsent;
   interactiveRequestParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
   interactiveRequestParameters.enablePkce = YES;
   interactiveRequestParameters.keychainAccessGroup = MSIDThrottlingKeychainGroup;
   
   
   //intialize interactive controller
   MSIDDefaultTokenRequestProvider *provider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                             defaultAccessor:self.tokenCache
                                                                                     accountMetadataAccessor:self.accountMetadataCache
                                                                                      tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];

   NSError *error = nil;
   MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:interactiveRequestParameters tokenRequestProvider:provider error:&error];
   
   //swizzle class method
   [MSIDTestSwizzle instanceMethod:@selector(creationTime)
                             class:[MSIDThrottlingCacheRecord class]
                             block:(id)^(void)
   {
      return [[NSDate new] dateByAddingTimeInterval:-10];

   }];
   
   //swizzle interactive token request
   [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                             class:[MSIDInteractiveTokenRequest class]
                             block:(id)^(
                                         __unused id obj,
                                         MSIDInteractiveRequestCompletionBlock completionBlock)
    {
         MSIDTokenResult *tokenResult = [MSIDTokenResult new];
         completionBlock(tokenResult,nil,nil);
      
   }];
   
#if !TARGET_OS_IOS
      //swizzle interactive method - MacOS test app doesn't have entitlements that support keychain access group.
      //adding a host app that has valid entitlements would also require enabling code-signing, which could break CI/CD check
      //So at the moment, the best approach is to swizzle keychain access APIs
      [MSIDTestSwizzle classMethod:@selector(updateLastRefreshTimeDatasource:
                                                                     context:
                                                                       error:)
                                class:[MSIDThrottlingService class]
                                block:(id)^(void)
       {
            return TRUE;
      }];
      
      [MSIDTestSwizzle classMethod:@selector(getLastRefreshTimeWithDatasource:
                                                                      context:
                                                                        error:)
                                class:[MSIDThrottlingMetaDataCache class]
                                block:(id)^(void)
       {
            return [NSDate date];
      }];
#endif
   

   //acquire token interactively - which should trigger keychain update
   XCTestExpectation *expectation2 = [self expectationWithDescription:@"Acquire token Interactively - should trigger lastUpdateRefresh"];
   [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

       XCTAssertNotNil(result);
       XCTAssertNil(error);

       [expectation2 fulfill];
   }];
   [self waitForExpectationsWithTimeout:5.0 handler:nil];
   
   
   //Now let's call silent request again - request should not be throttled anymore.
   [MSIDTestURLSession addResponse:tokenResponse];
   XCTestExpectation *expectation3 = [self expectationWithDescription:@"throttled request - should be cleraed now"];
   [defaultSilentTokenRequest acquireTokenWithRefreshTokenImpl:refreshToken completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
       
       XCTAssertEqual(defaultSilentTokenRequest.throttlingService.shouldThrottleRequestInvokedCount,0);
       XCTAssertEqual(defaultSilentTokenRequest.throttlingService.updateThrottlingServiceInvokedCount,2);
       XCTAssertNil(result);
       XCTAssertNotNil(error);
       XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
       XCTAssertEqual(validateAndRemoveRefreshTokenInvokeCount,2);
       [expectation3 fulfill];
   }];
  
   [self waitForExpectationsWithTimeout:5.0 handler:nil];
   
   [self.keychainTokenCache clearWithContext:nil error:nil];
   
}
#if MSID_ENABLE_SSO_EXTENSION

- (void)testMSIDThrottlingServiceIntegration_SSOSilentRequestWith429MSIDError_ShouldBeThrottledSuccessfully_AndThenUnThrottledUponExpiration
{
   if (@available(iOS 13.0, macOS 10.15, *))
   {
      
      //NSError *error = nil;
      //NSString *refreshTokenForThisTest = @"SSORT";
      
      //initialize extra request parameters used by MSIDBrokerOperationSilentTokenRequst
      MSIDRequestParameters *newSSORequestParam = self.silentRequestParameters;
      newSSORequestParam.clientId = @"contosoClientForSSO";
      newSSORequestParam.oidcScope = @"contosoEmployeeScopeForSSO";
      newSSORequestParam.target = @"contosoEmployeeTargetForSSO";
      newSSORequestParam.appRequestMetadata = @{
         @"requestmetadata1": @"metadata",
         @"requestmetadata2": @"metahuman"
      };
      newSSORequestParam.msidConfiguration = [[MSIDConfiguration alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY_GUID aadAuthority]
                                                                              redirectUri:self.redirectUri
                                                                                 clientId:@"contosoClientForSSO"
                                                                                   target:@"contosoEmployeeTargetForSSO"];
      newSSORequestParam.extraURLQueryParameters = @{
         @"urlQueryParam1" : @"extra1",
         @"urlQueryParam2" : @"extra2",
         @"urlQueryParam3" : @"extra3"
      };
      newSSORequestParam.instanceAware = YES;
      newSSORequestParam.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"Satya" homeAccountId:@"Nadella"];
      
      
      //initialize SSO extension silent token requst
      MSIDSSOExtensionSilentTokenRequest *newSSORequest = [[MSIDSSOExtensionSilentTokenRequest alloc] initWithRequestParameters:newSSORequestParam
                                                                                                                   forceRefresh:NO
                                                                                                                   oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                         tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                                     tokenCache:self.tokenCache
                                                                                                           accountMetadataCache:self.accountMetadataCache];
      
      
      //throttlingServiceMock
      MSIDThrottlingServiceMock *throttlingServiceMock = [[MSIDThrottlingServiceMock alloc] initWithDataSource:self.keychainTokenCache
                                                                                                       context:self.silentRequestParameters];
      
      newSSORequest.throttlingService = throttlingServiceMock;
      
      
      
      //swizzle resolve and validate
      [MSIDTestSwizzle instanceMethod:@selector(resolveAndValidate:
                                                 userPrincipalName:
                                                           context:
                                                   completionBlock:)
                                class:[MSIDAuthority class]
                                block:(id)^(
                                            __unused id obj,
                                            __unused BOOL validate,
                                            __unused NSString *upn,
                                            __unused id<MSIDRequestContext> context,
                                            MSIDAuthorityInfoBlock completionBlock)
       {
            completionBlock(nil,YES,nil);
            return;
      }];
      
      
      //swizzle SSO extension method
      __block NSError *ssoErrorInternal = nil;
      [MSIDTestSwizzle instanceMethod:@selector(handleOperationResponse:
                                                      requestParameters:
                                                 tokenResponseValidator:
                                                           oauthFactory:
                                                             tokenCache:
                                                   accountMetadataCache:
                                                        validateAccount:
                                                                  error:
                                                        completionBlock:)
                                class:[MSIDSSOTokenResponseHandler class]
                                block:(id)^(
                                            __unused id obj,
                                            __unused MSIDBrokerOperationTokenResponse *operationResponse,
                                            __unused MSIDRequestParameters *requestParameters,
                                            __unused MSIDTokenResponseValidator *tokenResponseValidator,
                                            __unused MSIDOauth2Factory *oauthFactory,
                                            __unused id<MSIDCacheAccessor> tokenCache,
                                            __unused MSIDAccountMetadataCacheAccessor *accountMetadataCache,
                                            __unused BOOL validateAccount,
                                            __unused NSError *error,
                                            MSIDRequestCompletionBlock completionBlock)
       {
            NSDictionary *userInfo = @{MSIDHTTPResponseCodeKey : @"429",
                                             MSIDHTTPHeadersKey: @{
                                                   @"Retry-After": @"-5"
                                                                  }
                                       };


            NSError *ssoError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"429 error test", @"oAuthError", @"subError", nil, nil, userInfo, NO);
            ssoErrorInternal = ssoError;

            completionBlock(nil,ssoError);
            return;
      }];
      
      //Swizzle
      
      [MSIDTestSwizzle classMethod:@selector(dateWithTimeIntervalSinceNow:)
                             class:[NSDate class]
                             block:(id)^(void)
      {
         return [[NSDate new] dateByAddingTimeInterval:-10];

      }];
      
      
      //Swizzle shouldThrottleRequest to update brokerKey
      [MSIDTestSwizzle instanceMethod:@selector(brokerKey)
                                class:[MSIDBrokerOperationRequest class]
                                block:(id)^(void)
       {
            return @"danielLaRuSSO";
      }];
      
      //self.throttlingService shouldThrottleRequest:self.operationRequest resultBlock:^(BOOL shouldBeThrottled, NSError * _Nullable cachedError)
      
      
      XCTestExpectation *expectation1 = [self expectationWithDescription:@"throttling SSO extension request - should go through first time around"];
      [newSSORequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
          
           XCTAssertNil(result);
           XCTAssertNotNil(error);
           XCTAssertEqual(newSSORequest.throttlingService.shouldThrottleRequestInvokedCount,0);
           XCTAssertEqual(newSSORequest.throttlingService.updateThrottlingServiceInvokedCount,1);
           [expectation1 fulfill];
      }];
      
      [self waitForExpectationsWithTimeout:5.0 handler:nil];
      
      //Let's verify that request has been throttled and saved in the cache
      NSString *expectedThumbprintKey = @"5500108438307938860";
      
      NSError *subError = nil;
      MSIDThrottlingCacheRecord *record = [[MSIDLRUCache sharedInstance] objectForKey:expectedThumbprintKey error:&subError];
      XCTAssertNotNil(record);
      XCTAssertNil(subError);
      
      XCTAssertEqual(record.throttleType,MSIDThrottlingType429);
      XCTAssertEqualObjects(record.cachedErrorResponse,ssoErrorInternal);
      XCTAssertEqual(record.throttledCount,1);
      
     
      XCTestExpectation *expectation3 = [self expectationWithDescription:@"throttling SSO extension request - throttling has expired - should be cleared now"];
      [newSSORequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
           
           XCTAssertNil(result);
           XCTAssertNotNil(error);
           XCTAssertEqual(newSSORequest.throttlingService.shouldThrottleRequestInvokedCount,0);
           XCTAssertEqual(newSSORequest.throttlingService.updateThrottlingServiceInvokedCount,2);
           [expectation3 fulfill];
      }];
      
      [self waitForExpectationsWithTimeout:5.0 handler:nil];
      
      
   }
}

- (void)testMSIDThrottlingServiceIntegration_SSOSilentRequestWith5XXWithMSALError_ShouldBeThrottledSuccessfully_AndThenUnThrottledUponExpiration
{
   if (@available(iOS 13.0, macOS 10.15, *))
   {
      
      //NSError *error = nil;
      //NSString *refreshTokenForThisTest = @"SSORT";
      
      //initialize extra request parameters used by MSIDBrokerOperationSilentTokenRequst
      MSIDRequestParameters *newSSORequestParam = self.silentRequestParameters;
      newSSORequestParam.clientId = @"contosoClientForSSO";
      newSSORequestParam.oidcScope = @"contosoEmployeeScopeForSSO";
      newSSORequestParam.target = @"contosoEmployeeTargetForSSO";
      newSSORequestParam.appRequestMetadata = @{
         @"requestmetadata1": @"metadata",
         @"requestmetadata2": @"metahuman"
      };
      newSSORequestParam.msidConfiguration = [[MSIDConfiguration alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY_GUID aadAuthority]
                                                                              redirectUri:self.redirectUri
                                                                                 clientId:@"contosoClientForSSO"
                                                                                   target:@"contosoEmployeeTargetForSSO"];
      newSSORequestParam.extraURLQueryParameters = @{
         @"urlQueryParam1" : @"extra1",
         @"urlQueryParam2" : @"extra2",
         @"urlQueryParam3" : @"extra3"
      };
      newSSORequestParam.instanceAware = YES;
      newSSORequestParam.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"Satya" homeAccountId:@"Nadella"];
      
      
      //initialize SSO extension silent token requst
      MSIDSSOExtensionSilentTokenRequest *newSSORequest = [[MSIDSSOExtensionSilentTokenRequest alloc] initWithRequestParameters:newSSORequestParam
                                                                                                                   forceRefresh:NO
                                                                                                                   oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                         tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                                     tokenCache:self.tokenCache
                                                                                                           accountMetadataCache:self.accountMetadataCache];
      
      //throttlingServiceMock
      MSIDThrottlingServiceMock *throttlingServiceMock = [[MSIDThrottlingServiceMock alloc] initWithDataSource:self.keychainTokenCache
                                                                                                       context:self.silentRequestParameters];
      
      newSSORequest.throttlingService = throttlingServiceMock;
      
      
      
      //swizzle resolve and validate
      [MSIDTestSwizzle instanceMethod:@selector(resolveAndValidate:
                                                 userPrincipalName:
                                                           context:
                                                   completionBlock:)
                                class:[MSIDAuthority class]
                                block:(id)^(
                                            __unused id obj,
                                            __unused BOOL validate,
                                            __unused NSString *upn,
                                            __unused id<MSIDRequestContext> context,
                                            MSIDAuthorityInfoBlock completionBlock)
       {
            completionBlock(nil,YES,nil);
            return;
      }];
      
      
      //swizzle SSO extension method
      __block NSError *ssoErrorInternal = nil;
      [MSIDTestSwizzle instanceMethod:@selector(handleOperationResponse:
                                                      requestParameters:
                                                 tokenResponseValidator:
                                                           oauthFactory:
                                                             tokenCache:
                                                   accountMetadataCache:
                                                        validateAccount:
                                                                  error:
                                                        completionBlock:)
                                class:[MSIDSSOTokenResponseHandler class]
                                block:(id)^(
                                            __unused id obj,
                                            __unused MSIDBrokerOperationTokenResponse *operationResponse,
                                            __unused MSIDRequestParameters *requestParameters,
                                            __unused MSIDTokenResponseValidator *tokenResponseValidator,
                                            __unused MSIDOauth2Factory *oauthFactory,
                                            __unused id<MSIDCacheAccessor> tokenCache,
                                            __unused MSIDAccountMetadataCacheAccessor *accountMetadataCache,
                                            __unused BOOL validateAccount,
                                            __unused NSError *error,
                                            MSIDRequestCompletionBlock completionBlock)
       {
            NSDictionary *userInfo = @{@"MSALHTTPResponseCodeKey": @"515",
                                       @"MSALHTTPHeadersKey": @{
                                                      @"Retry-After": @"-5"
                                                                     }
                                       };


         
            //since MSALErrorConverter is in MSAL space, let's do a little hack
            NSError *msalError = MSIDCreateError(@"MSALErrorDomain", MSIDErrorInternal, @"5xx error test", @"MSAL Error", @"subError", nil, nil, userInfo, NO);
            ssoErrorInternal = msalError;

            completionBlock(nil,msalError);
            return;
      }];
      
      //Swizzle NSDate
      [MSIDTestSwizzle classMethod:@selector(dateWithTimeIntervalSinceNow:)
                             class:[NSDate class]
                             block:(id)^(void)
      {
         return [[NSDate new] dateByAddingTimeInterval:-10];

      }];
      
      //Swizzle shouldThrottleRequest to update brokerKey
      [MSIDTestSwizzle instanceMethod:@selector(brokerKey)
                                class:[MSIDBrokerOperationRequest class]
                                block:(id)^(void)
       {
            return @"danielLaRuSSO";
      }];
      
      
      XCTestExpectation *expectation1 = [self expectationWithDescription:@"throttling SSO extension request - should go through first time around"];
      [newSSORequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
          
           XCTAssertNil(result);
           XCTAssertNotNil(error);
           XCTAssertEqual(newSSORequest.throttlingService.shouldThrottleRequestInvokedCount,0);
           XCTAssertEqual(newSSORequest.throttlingService.updateThrottlingServiceInvokedCount,1);
           [expectation1 fulfill];
      }];
      
      [self waitForExpectationsWithTimeout:5.0 handler:nil];
      
      //Let's verify that request has been throttled and saved in the cache
      NSString *expectedThumbprintKey = @"5500108438307938860";
      
      NSError *subError = nil;
      MSIDThrottlingCacheRecord *record = [[MSIDLRUCache sharedInstance] objectForKey:expectedThumbprintKey error:&subError];
      XCTAssertNotNil(record);
      XCTAssertNil(subError);
      
      XCTAssertEqual(record.throttleType,MSIDThrottlingType429);
      XCTAssertEqualObjects(record.cachedErrorResponse,ssoErrorInternal);
      XCTAssertEqual(record.throttledCount,1);
      
      XCTestExpectation *expectation2 = [self expectationWithDescription:@"throttling SSO extension request - should be cleared"];
      [newSSORequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
          
           XCTAssertNil(result);
           XCTAssertNotNil(error);
           XCTAssertEqual(newSSORequest.throttlingService.shouldThrottleRequestInvokedCount,0);
           XCTAssertEqual(newSSORequest.throttlingService.updateThrottlingServiceInvokedCount,2);
           [expectation2 fulfill];
      }];
      
      [self waitForExpectationsWithTimeout:5.0 handler:nil];
     

   }
}

- (void)testMSIDThrottlingServiceIntegration_SSOSilentRequestThatReturnsInteractionRequiredError_ShouldBeThrottledSuccessfully_AndThenUnThrottledUponLaterSuccessfulInteractionRequest
{
   if (@available(iOS 13.0, macOS 10.15, *))
   {
      
      //initialize extra request parameters used by MSIDBrokerOperationSilentTokenRequst
      MSIDRequestParameters *newSSORequestParam = self.silentRequestParameters;
      newSSORequestParam.clientId = @"contosoClientForSSO";
      newSSORequestParam.oidcScope = @"contosoEmployeeScopeForSSO";
      newSSORequestParam.target = @"contosoEmployeeTargetForSSO";
      newSSORequestParam.appRequestMetadata = @{
         @"requestmetadata1": @"metadata",
         @"requestmetadata2": @"metahuman"
      };
      newSSORequestParam.msidConfiguration = [[MSIDConfiguration alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY_GUID aadAuthority]
                                                                              redirectUri:self.redirectUri
                                                                                 clientId:@"contosoClientForSSO"
                                                                                   target:@"contosoEmployeeTargetForSSO"];
      newSSORequestParam.extraURLQueryParameters = @{
         @"urlQueryParam1" : @"extra1",
         @"urlQueryParam2" : @"extra2",
         @"urlQueryParam3" : @"extra3"
      };
      newSSORequestParam.instanceAware = YES;
      newSSORequestParam.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"Satya" homeAccountId:@"Nadella"];
      
      
      //initialize SSO extension silent token requst
      MSIDSSOExtensionSilentTokenRequest *newSSORequest = [[MSIDSSOExtensionSilentTokenRequest alloc] initWithRequestParameters:newSSORequestParam
                                                                                                                   forceRefresh:NO
                                                                                                                   oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                         tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                                     tokenCache:self.tokenCache
                                                                                                           accountMetadataCache:self.accountMetadataCache];
      
      //throttlingServiceMock
      MSIDThrottlingServiceMock *throttlingServiceMock = [[MSIDThrottlingServiceMock alloc] initWithDataSource:self.keychainTokenCache
                                                                                                       context:self.silentRequestParameters];
      
      newSSORequest.throttlingService = throttlingServiceMock;
      
      
      
      //swizzle resolve and validate
      [MSIDTestSwizzle instanceMethod:@selector(resolveAndValidate:
                                                 userPrincipalName:
                                                           context:
                                                   completionBlock:)
                                class:[MSIDAuthority class]
                                block:(id)^(
                                            __unused id obj,
                                            __unused BOOL validate,
                                            __unused NSString *upn,
                                            __unused id<MSIDRequestContext> context,
                                            MSIDAuthorityInfoBlock completionBlock)
       {
            completionBlock(nil,YES,nil);
            return;
      }];
      
      
      //swizzle SSO extension method
      __block NSError *ssoErrorInternal = nil;
      [MSIDTestSwizzle instanceMethod:@selector(handleOperationResponse:
                                                      requestParameters:
                                                 tokenResponseValidator:
                                                           oauthFactory:
                                                             tokenCache:
                                                   accountMetadataCache:
                                                        validateAccount:
                                                                  error:
                                                        completionBlock:)
                                class:[MSIDSSOTokenResponseHandler class]
                                block:(id)^(
                                            __unused id obj,
                                            __unused MSIDBrokerOperationTokenResponse *operationResponse,
                                            __unused MSIDRequestParameters *requestParameters,
                                            __unused MSIDTokenResponseValidator *tokenResponseValidator,
                                            __unused MSIDOauth2Factory *oauthFactory,
                                            __unused id<MSIDCacheAccessor> tokenCache,
                                            __unused MSIDAccountMetadataCacheAccessor *accountMetadataCache,
                                            __unused BOOL validateAccount,
                                            __unused NSError *error,
                                            MSIDRequestCompletionBlock completionBlock)
       {

                     //since MSALErrorConverter is in MSAL space, let's do a little hack
            NSError *msalError = MSIDCreateError(@"MSALErrorDomain", -50002, @"SSO interaction required error type", @"MSAL Error", @"subError", nil, nil, nil, NO);
            ssoErrorInternal = msalError;

            completionBlock(nil,msalError);
            return;
      }];
      
      //swizzle time related methods
      //swizzle class method
      [MSIDTestSwizzle instanceMethod:@selector(creationTime)
                                class:[MSIDThrottlingCacheRecord class]
                                block:(id)^(void)
      {
         return [[NSDate new] dateByAddingTimeInterval:-10];

      }];
      
      [MSIDTestSwizzle instanceMethod:@selector(brokerKey)
                                class:[MSIDBrokerOperationRequest class]
                                block:(id)^(void)
       {
            return @"danielLaRuSSO";
      }];
      
      
      XCTestExpectation *expectation1 = [self expectationWithDescription:@"throttling SSO extension request - should go through first time around"];
      [newSSORequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
          
           XCTAssertNil(result);
           XCTAssertNotNil(error);
           XCTAssertEqual(newSSORequest.throttlingService.shouldThrottleRequestInvokedCount,0);
           XCTAssertEqual(newSSORequest.throttlingService.updateThrottlingServiceInvokedCount,1);
           [expectation1 fulfill];
      }];
      
      [self waitForExpectationsWithTimeout:5.0 handler:nil];
      
      //Let's verify that request has been throttled and saved in the cache
      NSString *expectedThumbprintKey = @"1051707737519838129";

      NSError *subError = nil;
      MSIDThrottlingCacheRecord *record = [[MSIDLRUCache sharedInstance] objectForKey:expectedThumbprintKey error:&subError];
      XCTAssertNotNil(record);
      XCTAssertNil(subError);
      
      XCTAssertEqual(record.throttleType,MSIDThrottlingTypeInteractiveRequired);
      XCTAssertEqualObjects(record.cachedErrorResponse,ssoErrorInternal);
      XCTAssertEqual(record.throttledCount,1);
      

      XCTestExpectation *expectation2 = [self expectationWithDescription:@"throttling SSO extension request - should be throttled now"];
      [newSSORequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
          
           XCTAssertNil(result);
           XCTAssertNotNil(error);
           XCTAssertEqual(newSSORequest.throttlingService.shouldThrottleRequestInvokedCount,1);
           XCTAssertEqual(newSSORequest.throttlingService.updateThrottlingServiceInvokedCount,1);
           [expectation2 fulfill];
      }];
      
      [self waitForExpectationsWithTimeout:5.0 handler:nil];
      
      
      //Now let's create an interactive request
      MSIDInteractiveTokenRequestParameters *interactiveRequestParameters = [MSIDInteractiveTokenRequestParameters new];
      interactiveRequestParameters.target = @"fakescope1 fakescope2";
      interactiveRequestParameters.authority = [@"https://login.microsoftonline.com/common" aadAuthority];
      interactiveRequestParameters.redirectUri = @"x-msauth-test://com.microsoft.testapp";
      interactiveRequestParameters.clientId = @"my_client_id";
      interactiveRequestParameters.extraAuthorizeURLQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
      interactiveRequestParameters.loginHint = @"fakeuser@contoso.com";
      interactiveRequestParameters.correlationId = [NSUUID UUID];
      interactiveRequestParameters.webviewType = MSIDWebviewTypeWKWebView;
      interactiveRequestParameters.extraScopesToConsent = @"fakescope3";
      interactiveRequestParameters.oidcScope = @"openid profile offline_access";
      interactiveRequestParameters.promptType = MSIDPromptTypeConsent;
      interactiveRequestParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
      interactiveRequestParameters.enablePkce = YES;
      interactiveRequestParameters.keychainAccessGroup = MSIDThrottlingKeychainGroup;
      
      
#if !TARGET_OS_IOS
      //swizzle interactive method - MacOS test app doesn't have entitlements that support keychain access group.
      //adding a host app that has valid entitlements would also require enabling code-signing, which could break CI/CD check
      //So at the moment, the best approach is to swizzle keychain access APIs
      [MSIDTestSwizzle classMethod:@selector(updateLastRefreshTimeDatasource:
                                                                     context:
                                                                       error:)
                                class:[MSIDThrottlingService class]
                                block:(id)^(void)
       {
            return TRUE;
      }];
      
      [MSIDTestSwizzle classMethod:@selector(getLastRefreshTimeWithDatasource:
                                                                      context:
                                                                        error:)
                                class:[MSIDThrottlingMetaDataCache class]
                                block:(id)^(void)
       {
            return [NSDate date];
      }];
#endif
      
      
      //intialize interactive controller
      MSIDDefaultTokenRequestProvider *provider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                defaultAccessor:self.tokenCache
                                                                                        accountMetadataAccessor:self.accountMetadataCache
                                                                                         tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];

      NSError *error = nil;
      MSIDLocalInteractiveController *interactiveController = [[MSIDLocalInteractiveController alloc] initWithInteractiveRequestParameters:interactiveRequestParameters tokenRequestProvider:provider error:&error];
      
      //swizzle interactive token request
      [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                                class:[MSIDInteractiveTokenRequest class]
                                block:(id)^(
                                            __unused id obj,
                                            MSIDInteractiveRequestCompletionBlock completionBlock)
       {
            MSIDTokenResult *tokenResult = [MSIDTokenResult new];
            completionBlock(tokenResult,nil,nil);
         
      }];

      //acquire token interactively - which should trigger keychain update
      XCTestExpectation *expectation3 = [self expectationWithDescription:@"Acquire token Interactively - should trigger lastUpdateRefresh"];
      [interactiveController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

          XCTAssertNotNil(result);
          XCTAssertNil(error);

          [expectation3 fulfill];
      }];
      [self waitForExpectationsWithTimeout:5.0 handler:nil];
      
      
      //Now let's try to submit the SSO request again.
      XCTestExpectation *expectation4 = [self expectationWithDescription:@"throttling SSO extension request - should be unthrottled by lastUpdateRefresh"];
      [newSSORequest executeRequestWithCompletion:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
          
           XCTAssertNil(result);
           XCTAssertNotNil(error);
           XCTAssertEqual(newSSORequest.throttlingService.shouldThrottleRequestInvokedCount,1);
           XCTAssertEqual(newSSORequest.throttlingService.updateThrottlingServiceInvokedCount,2);
           [expectation4 fulfill];
      }];
      
      [self waitForExpectationsWithTimeout:5.0 handler:nil];
     
      [self.keychainTokenCache clearWithContext:nil error:nil];
   }
}


#endif

//#endif

@end
