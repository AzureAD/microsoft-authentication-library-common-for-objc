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
#import "MSIDTestURLResponse+Util.h"
#import "MSIDThrottlingServiceMock.h"


@interface MSIDThrottlingService (MSIDThrottlingServiceIntegrationTests)

@property (nonatomic) NSUInteger shouldThrottleRequestInvokedCount;
@property (nonatomic) NSUInteger updateThrottlingServiceInvokedCount;

@end

@interface MSIDSilentTokenRequest (MSIDThrottlingServiceIntegrationTests)

@property (nonatomic) MSIDThrottlingService *throttlingService;

- (void)acquireTokenWithRefreshTokenImpl:(MSIDBaseToken<MSIDRefreshableToken> *)refreshToken
                         completionBlock:(MSIDRequestCompletionBlock)completionBlock;

@end


//Need to set category method, since tokenEndpoint is read-only property that relies on yet another readonly property called metadata
//and this API gets used in refreshTokenRequestWithRequestParamters within the OAuth Factory
@interface MSIDRequestParameters (MSIDThrottlingServiceIntegrationTests)

@property (nonatomic, readonly) NSURL *tokenEndpoint;

@end

@implementation MSIDRequestParameters (MSIDThrottlingServiceIntegrationTests)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

- (NSURL *)tokenEndpoint
{
    return [[NSURL alloc] initWithString:DEFAULT_TEST_TOKEN_ENDPOINT_GUID];
}

#pragma clang diagnostic pop

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

@end

@implementation MSIDThrottlingServiceIntegrationTests

#pragma mark - Helper APIs

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
    parameters.keychainAccessGroup = @"com.microsoft.adalcache";
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
                                                                                 ]}};
    
    MSIDCache *msidCache = [[MSIDCache alloc] initWithDictionary:enrollmentJsonDict];
    MSIDIntuneInMemoryCacheDataSource *memoryCache = [[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:msidCache];
    MSIDIntuneEnrollmentIdsCache *enrollmentIdsCache = [[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:memoryCache];
    [MSIDIntuneEnrollmentIdsCache setSharedCache:enrollmentIdsCache];
    
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
    
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testMSIDThrottlingServiceIntegration_ThrottlingServiceShouldExecuteDesiredBehaviors_WhenUsedWithinMSIDDefaultSilentTokenRequestContext
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
    MSIDThrottlingServiceMock *throttlingServiceMock = [[MSIDThrottlingServiceMock alloc] initWithAccessGroup:@"com.microsoft.adalcache"
                                                                                                      context:self.silentRequestParameters];
    
    defaultSilentTokenRequest.throttlingService = throttlingServiceMock;
    
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
                                                                                         redirectUri:self.redirectUri];

    
    tokenResponse->_error = [NSError new];
    NSDictionary *userInfo = @{MSIDHTTPResponseCodeKey : @"429",
                               @"Retry-After": @"100"
                               
                                };


    tokenResponse->_error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"429 error test", @"oAuthError", @"subError", nil, nil, userInfo, NO);
    
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



@end
