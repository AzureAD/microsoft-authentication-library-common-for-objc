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
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDBasicContext.h"
#import "MSIDConfiguration.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDRefreshToken.h"
#import "MSIDFamilyRefreshToken.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDTestSwizzle.h"
#import "MSIDFlightManager.h"
#import "MSIDConstants.h"
#import "MSIDAuthority.h"
#import "MSIDTestCacheAccessorHelper.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDJsonObject.h"
#import "MSIDTestConfiguration.h"

@interface MSIDDefaultTokenCacheAccessorSFRTTests : XCTestCase

@property (nonatomic) MSIDDefaultTokenCacheAccessor *accessor;
@property (nonatomic) MSIDBasicContext *context;
@property (nonatomic) MSIDConfiguration *configuration;
@property (nonatomic) MSIDAccountIdentifier *accountIdentifier;

@end

@implementation MSIDDefaultTokenCacheAccessorSFRTTests

- (void)setUp
{
    [super setUp];
    
    MSIDTestCacheDataSource *dataSource = [[MSIDTestCacheDataSource alloc] init];
    self.accessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    
    self.context = [MSIDBasicContext new];
    self.configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    self.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                    homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    
    // Reset FRT settings
    [MSIDAccountCredentialCache setDisableFRT:NO];
}

- (void)tearDown
{
    [MSIDTestSwizzle removeAllSwizzling];
    [super tearDown];
}

#pragma mark - FRT enabled scenarios

- (void)testGetRefreshToken_whenFRTEnabled_shouldReturnFamilyRefreshToken
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Save both family refresh token and regular refresh token
    MSIDFamilyRefreshToken *familyRT = [self saveFamilyRefreshToken];
    [self saveRegularRefreshToken];
    
    NSError *error = nil;
    MSIDRefreshToken *retrievedToken = [self.accessor getRefreshTokenWithAccount:self.accountIdentifier
                                                                        familyId:DEFAULT_TEST_FAMILY_ID
                                                                   configuration:self.configuration
                                                                         context:self.context
                                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(retrievedToken);
    XCTAssertEqual(retrievedToken.credentialType, MSIDFamilyRefreshTokenType);
    XCTAssertEqualObjects(retrievedToken.refreshToken, familyRT.refreshToken);
    XCTAssertEqualObjects(retrievedToken.familyId, DEFAULT_TEST_FAMILY_ID);
}

- (void)testGetRefreshToken_whenFRTEnabled_andNoFamilyRT_shouldFallbackToRegularRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Save only regular refresh token
    MSIDRefreshToken *regularRT = [self saveRegularRefreshToken];
    
    NSError *error = nil;
    MSIDRefreshToken *retrievedToken = [self.accessor getRefreshTokenWithAccount:self.accountIdentifier
                                                                        familyId:DEFAULT_TEST_FAMILY_ID
                                                                   configuration:self.configuration
                                                                         context:self.context
                                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(retrievedToken);
    XCTAssertEqual(retrievedToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(retrievedToken.refreshToken, regularRT.refreshToken);
}

- (void)testGetRefreshToken_whenFRTEnabled_andNoTokens_shouldReturnNil
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    NSError *error = nil;
    MSIDRefreshToken *retrievedToken = [self.accessor getRefreshTokenWithAccount:self.accountIdentifier
                                                                        familyId:DEFAULT_TEST_FAMILY_ID
                                                                   configuration:self.configuration
                                                                         context:self.context
                                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(retrievedToken);
}

#pragma mark - FRT disabled scenarios

- (void)testGetRefreshToken_whenFRTDisabled_shouldReturnRegularRefreshToken
{
    [self disableFRTFeatureFlag];
    
    // Save both types of tokens
    [self saveFamilyRefreshToken];
    MSIDRefreshToken *regularRT = [self saveRegularRefreshToken];
    
    NSError *error = nil;
    MSIDRefreshToken *retrievedToken = [self.accessor getRefreshTokenWithAccount:self.accountIdentifier
                                                                        familyId:nil
                                                                   configuration:self.configuration
                                                                         context:self.context
                                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(retrievedToken);
    XCTAssertEqual(retrievedToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(retrievedToken.refreshToken, regularRT.refreshToken);
}

- (void)testGetRefreshToken_whenFRTDisabledByClient_shouldReturnRegularRefreshToken
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    [MSIDAccountCredentialCache setDisableFRT:YES]; // Client-side disable
    
    [self saveFamilyRefreshToken];
    MSIDRefreshToken *regularRT = [self saveRegularRefreshToken];
    
    NSError *error = nil;
    MSIDRefreshToken *retrievedToken = [self.accessor getRefreshTokenWithAccount:self.accountIdentifier
                                                                        familyId:nil
                                                                   configuration:self.configuration
                                                                         context:self.context
                                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(retrievedToken);
    XCTAssertEqual(retrievedToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(retrievedToken.refreshToken, regularRT.refreshToken);
}

#pragma mark - Cross-accessor scenarios

- (void)testGetRefreshToken_whenTokenInOtherAccessor_shouldReturnTokenFromOtherAccessor
{
    // Create another accessor with a token
    MSIDTestCacheDataSource *otherDataSource = [[MSIDTestCacheDataSource alloc] init];
    MSIDLegacyTokenCacheAccessor *otherAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:otherDataSource
                                                                                       otherCacheAccessors:nil];
    
    // Set up main accessor with other accessor
    self.accessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:[[MSIDTestCacheDataSource alloc] init]
                                                         otherCacheAccessors:@[otherAccessor]];
    
    // Save token only in other accessor
    MSIDRefreshToken *tokenInOtherAccessor = [self createRefreshTokenForAccessor:otherAccessor];
    
    NSError *error = nil;
    MSIDRefreshToken *retrievedToken = [self.accessor getRefreshTokenWithAccount:self.accountIdentifier
                                                                        familyId:nil
                                                                   configuration:self.configuration
                                                                         context:self.context
                                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(retrievedToken);
    XCTAssertEqualObjects(retrievedToken.refreshToken, tokenInOtherAccessor.refreshToken);
}

#pragma mark - Error handling scenarios

- (void)testGetRefreshToken_whenFRTStatusCheckFails_shouldContinueWithRegularFlow
{
    // Mock FRT status check to return error
    [self mockFRTStatusCheckToFail];
    
    MSIDRefreshToken *regularRT = [self saveRegularRefreshToken];
    
    NSError *error = nil;
    MSIDRefreshToken *retrievedToken = [self.accessor getRefreshTokenWithAccount:self.accountIdentifier
                                                                        familyId:nil
                                                                   configuration:self.configuration
                                                                         context:self.context
                                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(retrievedToken);
    XCTAssertEqual(retrievedToken.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(retrievedToken.refreshToken, regularRT.refreshToken);
}

#pragma mark - Family ID scenarios

- (void)testGetRefreshToken_whenFRTEnabled_withSpecificFamilyId_shouldReturnMatchingFamilyRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Save family tokens with different family IDs
    MSIDFamilyRefreshToken *familyRT1 = [self saveFamilyRefreshTokenWithFamilyId:@"family1"];
    [self saveFamilyRefreshTokenWithFamilyId:@"family2"];
    
    NSError *error = nil;
    MSIDRefreshToken *retrievedToken = [self.accessor getRefreshTokenWithAccount:self.accountIdentifier
                                                                        familyId:@"family1"
                                                                   configuration:self.configuration
                                                                         context:self.context
                                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(retrievedToken);
    XCTAssertEqualObjects(retrievedToken.familyId, @"family1");
    XCTAssertEqualObjects(retrievedToken.refreshToken, familyRT1.refreshToken);
}

- (void)testGetRefreshToken_whenFRTEnabled_withNilFamilyId_shouldReturnAnyFamilyRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    MSIDFamilyRefreshToken *familyRT = [self saveFamilyRefreshToken];
    
    NSError *error = nil;
    MSIDRefreshToken *retrievedToken = [self.accessor getRefreshTokenWithAccount:self.accountIdentifier
                                                                        familyId:nil
                                                                   configuration:self.configuration
                                                                         context:self.context
                                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(retrievedToken);
    XCTAssertEqualObjects(retrievedToken.refreshToken, familyRT.refreshToken);
}

#pragma mark - Mixed scenarios

- (void)testGetRefreshToken_whenFRTEnabledAndBothTokenTypesExist_shouldPreferFamilyRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    MSIDFamilyRefreshToken *familyRT = [self saveFamilyRefreshToken];
    [self saveRegularRefreshToken];
    
    NSError *error = nil;
    MSIDRefreshToken *retrievedToken = [self.accessor getRefreshTokenWithAccount:self.accountIdentifier
                                                                        familyId:DEFAULT_TEST_FAMILY_ID
                                                                   configuration:self.configuration
                                                                         context:self.context
                                                                           error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(retrievedToken);
    XCTAssertEqual(retrievedToken.credentialType, MSIDFamilyRefreshTokenType);
    XCTAssertEqualObjects(retrievedToken.refreshToken, familyRT.refreshToken);
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
    [self.accessor.accountCredentialCache updateFRTSettings:enabled context:self.context error:&error];
    XCTAssertNil(error);
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
    BOOL result = [self.accessor saveToken:familyRT context:self.context error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    return familyRT;
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
    BOOL result = [self.accessor saveToken:refreshToken context:self.context error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    return refreshToken;
}

- (MSIDRefreshToken *)createRefreshTokenForAccessor:(id<MSIDCacheAccessor>)accessor
{
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = @"other_accessor_refresh_token";
    refreshToken.environment = DEFAULT_TEST_ENVIRONMENT;
    refreshToken.realm = DEFAULT_TEST_UTID;
    refreshToken.clientId = DEFAULT_TEST_CLIENT_ID;
    refreshToken.accountIdentifier = self.accountIdentifier;
    
    NSError *error = nil;
    BOOL result = [accessor saveToken:refreshToken context:self.context error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    return refreshToken;
}

- (void)mockFRTStatusCheckToFail
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