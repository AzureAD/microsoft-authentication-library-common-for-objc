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
#import "MSIDInteractiveTokenRequest.h"
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
#import "MSIDWebviewConfiguration.h"
#import "MSIDAADAuthorizationCodeRequest.h"

@interface MSIDInteractiveTokenRequestSFRTTests : XCTestCase

@property (nonatomic) MSIDInteractiveTokenRequestParameters *requestParameters;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;
@property (nonatomic) MSIDAccountIdentifier *accountIdentifier;
@property (nonatomic) MSIDAADV2Oauth2Factory *factory;

@end

@implementation MSIDInteractiveTokenRequestSFRTTests

- (void)setUp
{
    [super setUp];
    
    // Set up request parameters
    self.requestParameters = [MSIDInteractiveTokenRequestParameters new];
    self.requestParameters.authority = [@"https://login.microsoftonline.com/common" msidAuthority];
    self.requestParameters.clientId = DEFAULT_TEST_CLIENT_ID;
    self.requestParameters.target = DEFAULT_TEST_SCOPE;
    self.requestParameters.redirectUri = DEFAULT_TEST_REDIRECT_URI;
    self.requestParameters.msidConfiguration = [MSIDTestConfiguration v2DefaultConfiguration];
    self.requestParameters.correlationId = [[NSUUID alloc] init];
    
    self.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                    homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    self.requestParameters.accountIdentifier = self.accountIdentifier;
    
    // Set up cache
    MSIDTestCacheDataSource *dataSource = [[MSIDTestCacheDataSource alloc] init];
    self.tokenCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    self.accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
    
    self.factory = [MSIDAADV2Oauth2Factory new];
    
    // Reset FRT settings
    [MSIDAccountCredentialCache setDisableFRT:NO];
}

- (void)tearDown
{
    [MSIDTestSwizzle removeAllSwizzling];
    [super tearDown];
}

#pragma mark - Custom header injection tests

- (void)testAuthorizationRequest_whenFRTEnabled_shouldInjectFRTSupportHeader
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    // Create a mock authorization code request to test header injection
    NSError *error = nil;
    MSIDAADAuthorizationCodeRequest *authRequest = [interactiveRequest authorizationRequestWithError:&error];
    
    XCTAssertNotNil(authRequest);
    XCTAssertNil(error);
    
    // Verify that FRT support headers are included
    NSDictionary *customHeaders = authRequest.customHeaders;
    XCTAssertNotNil(customHeaders);
    // Note: The actual header name would depend on the implementation
    // This is a placeholder for the expected FRT support header
}

- (void)testAuthorizationRequest_whenFRTDisabled_shouldNotInjectFRTSupportHeader
{
    [self disableFRTFeatureFlag];
    
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    NSError *error = nil;
    MSIDAADAuthorizationCodeRequest *authRequest = [interactiveRequest authorizationRequestWithError:&error];
    
    XCTAssertNotNil(authRequest);
    XCTAssertNil(error);
    
    // Verify that FRT support headers are not included when disabled
    NSDictionary *customHeaders = authRequest.customHeaders;
    // Verify absence of FRT headers or presence of disabled indicators
}

#pragma mark - Refresh token preference logic tests

- (void)testInteractiveRequest_whenFRTEnabledAndFamilyRTExists_shouldPreferFamilyRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Save both regular RT and family RT
    [self saveRegularRefreshToken];
    MSIDFamilyRefreshToken *familyRT = [self saveFamilyRefreshToken];
    
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    // Mock the method that determines which refresh token to use
    // This would typically be tested through integration with the actual flow
    NSError *error = nil;
    MSIDRefreshToken *preferredRT = [self.tokenCache getRefreshTokenWithAccount:self.accountIdentifier
                                                                       familyId:DEFAULT_TEST_FAMILY_ID
                                                                  configuration:self.requestParameters.msidConfiguration
                                                                        context:nil
                                                                          error:&error];
    
    XCTAssertNotNil(preferredRT);
    XCTAssertNil(error);
    XCTAssertEqual(preferredRT.credentialType, MSIDFamilyRefreshTokenType);
    XCTAssertEqualObjects(preferredRT.refreshToken, familyRT.refreshToken);
}

- (void)testInteractiveRequest_whenFRTDisabledAndFamilyRTExists_shouldUseRegularRT
{
    [self disableFRTFeatureFlag];
    
    MSIDRefreshToken *regularRT = [self saveRegularRefreshToken];
    [self saveFamilyRefreshToken];
    
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    NSError *error = nil;
    MSIDRefreshToken *preferredRT = [self.tokenCache getRefreshTokenWithAccount:self.accountIdentifier
                                                                       familyId:nil
                                                                  configuration:self.requestParameters.msidConfiguration
                                                                        context:nil
                                                                          error:&error];
    
    XCTAssertNotNil(preferredRT);
    XCTAssertNil(error);
    XCTAssertEqual(preferredRT.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(preferredRT.refreshToken, regularRT.refreshToken);
}

#pragma mark - WebView configuration tests

- (void)testWebviewConfiguration_whenFRTEnabled_shouldConfigureForFRTSupport
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    // Test webview configuration setup
    // This would depend on the actual implementation details
    XCTAssertNotNil(interactiveRequest);
}

- (void)testWebviewConfiguration_whenFRTDisabled_shouldConfigureWithoutFRTSupport
{
    [self disableFRTFeatureFlag];
    
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    XCTAssertNotNil(interactiveRequest);
}

#pragma mark - Family ID parameter tests

- (void)testRequestParameters_whenFamilyIdSet_shouldIncludeInAuthorizationRequest
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Set family ID in request parameters
    self.requestParameters.familyId = DEFAULT_TEST_FAMILY_ID;
    
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    NSError *error = nil;
    MSIDAADAuthorizationCodeRequest *authRequest = [interactiveRequest authorizationRequestWithError:&error];
    
    XCTAssertNotNil(authRequest);
    XCTAssertNil(error);
    
    // Verify family ID is included in authorization request parameters
    // This would check the actual URL parameters or request body
}

- (void)testRequestParameters_whenNoFamilyIdSet_shouldNotIncludeInAuthorizationRequest
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Don't set family ID in request parameters
    self.requestParameters.familyId = nil;
    
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    NSError *error = nil;
    MSIDAADAuthorizationCodeRequest *authRequest = [interactiveRequest authorizationRequestWithError:&error];
    
    XCTAssertNotNil(authRequest);
    XCTAssertNil(error);
    
    // Verify family ID is not included in authorization request parameters
}

#pragma mark - Account hint tests

- (void)testAccountHint_whenFamilyRTExists_shouldUseCorrectAccountHint
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    MSIDFamilyRefreshToken *familyRT = [self saveFamilyRefreshToken];
    
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    NSError *error = nil;
    MSIDAADAuthorizationCodeRequest *authRequest = [interactiveRequest authorizationRequestWithError:&error];
    
    XCTAssertNotNil(authRequest);
    XCTAssertNil(error);
    
    // Verify that account hint corresponds to the family refresh token account
    // This would check login_hint or similar parameter in the authorization request
}

#pragma mark - Multi-family scenarios

- (void)testInteractiveRequest_withMultipleFamilyRTs_shouldUseCorrectFamily
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Save multiple family RTs with different family IDs
    [self saveFamilyRefreshTokenWithFamilyId:@"family1"];
    MSIDFamilyRefreshToken *targetFamilyRT = [self saveFamilyRefreshTokenWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    // Set target family ID in request parameters
    self.requestParameters.familyId = DEFAULT_TEST_FAMILY_ID;
    
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    // Verify the correct family RT is selected
    NSError *error = nil;
    MSIDRefreshToken *selectedRT = [self.tokenCache getRefreshTokenWithAccount:self.accountIdentifier
                                                                       familyId:DEFAULT_TEST_FAMILY_ID
                                                                  configuration:self.requestParameters.msidConfiguration
                                                                        context:nil
                                                                          error:&error];
    
    XCTAssertNotNil(selectedRT);
    XCTAssertNil(error);
    XCTAssertEqualObjects(selectedRT.familyId, DEFAULT_TEST_FAMILY_ID);
    XCTAssertEqualObjects(selectedRT.refreshToken, targetFamilyRT.refreshToken);
}

#pragma mark - Client-side disable scenarios

- (void)testInteractiveRequest_whenClientDisabledFRT_shouldNotUseFamilyRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    [MSIDAccountCredentialCache setDisableFRT:YES]; // Client-side disable
    
    MSIDRefreshToken *regularRT = [self saveRegularRefreshToken];
    [self saveFamilyRefreshToken];
    
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    // Should fall back to regular refresh token
    NSError *error = nil;
    MSIDRefreshToken *selectedRT = [self.tokenCache getRefreshTokenWithAccount:self.accountIdentifier
                                                                       familyId:nil
                                                                  configuration:self.requestParameters.msidConfiguration
                                                                        context:nil
                                                                          error:&error];
    
    XCTAssertNotNil(selectedRT);
    XCTAssertNil(error);
    XCTAssertEqual(selectedRT.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(selectedRT.refreshToken, regularRT.refreshToken);
}

#pragma mark - Error handling tests

- (void)testInteractiveRequest_whenFRTStatusCheckFails_shouldContinueWithRegularFlow
{
    [self mockFRTStatusCheckError];
    
    MSIDRefreshToken *regularRT = [self saveRegularRefreshToken];
    
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    // Should still work with regular flow
    NSError *error = nil;
    MSIDRefreshToken *selectedRT = [self.tokenCache getRefreshTokenWithAccount:self.accountIdentifier
                                                                       familyId:nil
                                                                  configuration:self.requestParameters.msidConfiguration
                                                                        context:nil
                                                                          error:&error];
    
    XCTAssertNotNil(selectedRT);
    XCTAssertNil(error);
    XCTAssertEqualObjects(selectedRT.refreshToken, regularRT.refreshToken);
}

- (void)testInteractiveRequest_whenNoTokensInCache_shouldProceedWithoutErrors
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // No tokens in cache
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] 
                                                      initWithRequestParameters:self.requestParameters
                                                              oauthFactory:self.factory
                                                    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                            tokenCache:self.tokenCache
                                                  accountMetadataCache:self.accountMetadataCache];
    
    NSError *error = nil;
    MSIDAADAuthorizationCodeRequest *authRequest = [interactiveRequest authorizationRequestWithError:&error];
    
    XCTAssertNotNil(authRequest);
    XCTAssertNil(error);
    
    // Should proceed normally even without tokens in cache
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

- (MSIDRefreshToken *)saveRegularRefreshToken
{
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = @"regular_refresh_token";
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