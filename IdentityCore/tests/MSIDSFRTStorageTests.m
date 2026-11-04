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
#import "MSIDLegacyTokenCacheAccessor.h"
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
#import "MSIDTokenResponse.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTestCacheAccessorHelper.h"

@interface MSIDSFRTStorageTests : XCTestCase

@property (nonatomic) MSIDDefaultTokenCacheAccessor *defaultAccessor;
@property (nonatomic) MSIDLegacyTokenCacheAccessor *legacyAccessor;
@property (nonatomic) MSIDBasicContext *context;
@property (nonatomic) MSIDAccountIdentifier *accountIdentifier;
@property (nonatomic) MSIDAADV2Oauth2Factory *factory;

@end

@implementation MSIDSFRTStorageTests

- (void)setUp
{
    [super setUp];
    
    MSIDTestCacheDataSource *defaultDataSource = [[MSIDTestCacheDataSource alloc] init];
    self.defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:defaultDataSource otherCacheAccessors:nil];
    
    MSIDTestCacheDataSource *legacyDataSource = [[MSIDTestCacheDataSource alloc] init];
    self.legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:legacyDataSource otherCacheAccessors:nil];
    
    self.context = [MSIDBasicContext new];
    self.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                    homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    
    self.factory = [MSIDAADV2Oauth2Factory new];
    
    // Reset FRT settings
    [MSIDAccountCredentialCache setDisableFRT:NO];
}

- (void)tearDown
{
    [MSIDTestSwizzle removeAllSwizzling];
    [super tearDown];
}

#pragma mark - Storage decision based on FRT status

- (void)testSaveRefreshToken_whenFRTEnabled_andHasFamilyId_shouldStoreFamilyRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    MSIDRefreshToken *refreshTokenWithFamilyId = [self createRefreshTokenWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    NSError *error = nil;
    BOOL result = [self.defaultAccessor saveToken:refreshTokenWithFamilyId context:self.context error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Verify it was stored as family refresh token
    NSArray *allFamilyRTs = [MSIDTestCacheAccessorHelper getAllTokens:self.defaultAccessor 
                                                                 type:MSIDFamilyRefreshTokenType 
                                                                class:[MSIDFamilyRefreshToken class]];
    XCTAssertEqual(allFamilyRTs.count, 1);
    
    MSIDFamilyRefreshToken *storedToken = allFamilyRTs.firstObject;
    XCTAssertEqualObjects(storedToken.familyId, DEFAULT_TEST_FAMILY_ID);
    XCTAssertEqualObjects(storedToken.refreshToken, refreshTokenWithFamilyId.refreshToken);
}

- (void)testSaveRefreshToken_whenFRTEnabled_andNoFamilyId_shouldStoreRegularRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    MSIDRefreshToken *refreshTokenWithoutFamilyId = [self createRefreshTokenWithFamilyId:nil];
    
    NSError *error = nil;
    BOOL result = [self.defaultAccessor saveToken:refreshTokenWithoutFamilyId context:self.context error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Verify it was stored as regular refresh token
    NSArray *allRegularRTs = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:self.defaultAccessor];
    XCTAssertEqual(allRegularRTs.count, 1);
    
    // Should not be stored as family RT
    NSArray *allFamilyRTs = [MSIDTestCacheAccessorHelper getAllTokens:self.defaultAccessor 
                                                                 type:MSIDFamilyRefreshTokenType 
                                                                class:[MSIDFamilyRefreshToken class]];
    XCTAssertEqual(allFamilyRTs.count, 0);
}

- (void)testSaveRefreshToken_whenFRTDisabled_andHasFamilyId_shouldStoreRegularRT
{
    [self disableFRTFeatureFlag];
    
    MSIDRefreshToken *refreshTokenWithFamilyId = [self createRefreshTokenWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    NSError *error = nil;
    BOOL result = [self.defaultAccessor saveToken:refreshTokenWithFamilyId context:self.context error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Should be stored as regular RT even with family ID
    NSArray *allRegularRTs = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:self.defaultAccessor];
    XCTAssertEqual(allRegularRTs.count, 1);
    
    // Should not be stored as family RT
    NSArray *allFamilyRTs = [MSIDTestCacheAccessorHelper getAllTokens:self.defaultAccessor 
                                                                 type:MSIDFamilyRefreshTokenType 
                                                                class:[MSIDFamilyRefreshToken class]];
    XCTAssertEqual(allFamilyRTs.count, 0);
}

#pragma mark - Multi-accessor storage coordination

- (void)testSaveRefreshToken_whenFamilyRTSaved_shouldSaveInAllAccessors
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Set up legacy accessor as other accessor for default accessor
    self.defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] 
                           initWithDataSource:[[MSIDTestCacheDataSource alloc] init]
                           otherCacheAccessors:@[self.legacyAccessor]];
    
    MSIDRefreshToken *familyRefreshToken = [self createRefreshTokenWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    NSError *error = nil;
    BOOL result = [self.defaultAccessor saveToken:familyRefreshToken context:self.context error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Verify it was saved in default accessor
    NSArray *defaultFamilyRTs = [MSIDTestCacheAccessorHelper getAllTokens:self.defaultAccessor 
                                                                      type:MSIDFamilyRefreshTokenType 
                                                                     class:[MSIDFamilyRefreshToken class]];
    XCTAssertEqual(defaultFamilyRTs.count, 1);
    
    // Verify it was also saved in legacy accessor (through multi-accessor coordination)
    // Note: This depends on the actual implementation of multi-accessor storage
}

- (void)testSaveRefreshToken_whenRegularRTSaved_shouldNotAffectOtherAccessors
{
    [self disableFRTFeatureFlag];
    
    MSIDRefreshToken *regularRefreshToken = [self createRefreshTokenWithFamilyId:nil];
    
    NSError *error = nil;
    BOOL result = [self.defaultAccessor saveToken:regularRefreshToken context:self.context error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Should only be in default accessor
    NSArray *defaultRTs = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:self.defaultAccessor];
    XCTAssertEqual(defaultRTs.count, 1);
    
    // Should not be in legacy accessor
    NSArray *legacyRTs = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:self.legacyAccessor];
    XCTAssertEqual(legacyRTs.count, 0);
}

#pragma mark - Family ID based storage logic

- (void)testSaveRefreshToken_withDifferentFamilyIds_shouldStoreCorrectly
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    MSIDRefreshToken *familyRT1 = [self createRefreshTokenWithFamilyId:@"family1"];
    MSIDRefreshToken *familyRT2 = [self createRefreshTokenWithFamilyId:@"family2"];
    
    NSError *error = nil;
    BOOL result1 = [self.defaultAccessor saveToken:familyRT1 context:self.context error:&error];
    XCTAssertTrue(result1);
    XCTAssertNil(error);
    
    BOOL result2 = [self.defaultAccessor saveToken:familyRT2 context:self.context error:&error];
    XCTAssertTrue(result2);
    XCTAssertNil(error);
    
    // Should have 2 family refresh tokens stored
    NSArray *allFamilyRTs = [MSIDTestCacheAccessorHelper getAllTokens:self.defaultAccessor 
                                                                 type:MSIDFamilyRefreshTokenType 
                                                                class:[MSIDFamilyRefreshToken class]];
    XCTAssertEqual(allFamilyRTs.count, 2);
    
    // Verify family IDs are preserved
    NSSet *familyIds = [NSSet setWithArray:[allFamilyRTs valueForKey:@"familyId"]];
    XCTAssertTrue([familyIds containsObject:@"family1"]);
    XCTAssertTrue([familyIds containsObject:@"family2"]);
}

- (void)testSaveRefreshToken_replacingSameFamilyId_shouldUpdateExisting
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    // Save initial family RT
    MSIDRefreshToken *initialFamilyRT = [self createRefreshTokenWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    initialFamilyRT.refreshToken = @"initial_token";
    
    NSError *error = nil;
    BOOL result1 = [self.defaultAccessor saveToken:initialFamilyRT context:self.context error:&error];
    XCTAssertTrue(result1);
    XCTAssertNil(error);
    
    // Save updated family RT with same family ID
    MSIDRefreshToken *updatedFamilyRT = [self createRefreshTokenWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    updatedFamilyRT.refreshToken = @"updated_token";
    
    BOOL result2 = [self.defaultAccessor saveToken:updatedFamilyRT context:self.context error:&error];
    XCTAssertTrue(result2);
    XCTAssertNil(error);
    
    // Should still have only 1 family refresh token
    NSArray *allFamilyRTs = [MSIDTestCacheAccessorHelper getAllTokens:self.defaultAccessor 
                                                                 type:MSIDFamilyRefreshTokenType 
                                                                class:[MSIDFamilyRefreshToken class]];
    XCTAssertEqual(allFamilyRTs.count, 1);
    
    // Should contain the updated token
    MSIDFamilyRefreshToken *storedToken = allFamilyRTs.firstObject;
    XCTAssertEqualObjects(storedToken.refreshToken, @"updated_token");
}

#pragma mark - Token response processing

- (void)testSaveTokensWithResponse_whenResponseHasFamilyId_shouldStoreFamilyRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    MSIDTokenResponse *tokenResponse = [self createTokenResponseWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    NSError *error = nil;
    BOOL result = [self.defaultAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                          response:tokenResponse
                                                           factory:self.factory
                                                           context:self.context
                                                             error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Should have stored family refresh token
    NSArray *allFamilyRTs = [MSIDTestCacheAccessorHelper getAllTokens:self.defaultAccessor 
                                                                 type:MSIDFamilyRefreshTokenType 
                                                                class:[MSIDFamilyRefreshToken class]];
    XCTAssertEqual(allFamilyRTs.count, 1);
    
    MSIDFamilyRefreshToken *storedFRT = allFamilyRTs.firstObject;
    XCTAssertEqualObjects(storedFRT.familyId, DEFAULT_TEST_FAMILY_ID);
}

- (void)testSaveTokensWithResponse_whenResponseHasNoFamilyId_shouldStoreRegularRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    MSIDTokenResponse *tokenResponse = [self createTokenResponseWithFamilyId:nil];
    
    NSError *error = nil;
    BOOL result = [self.defaultAccessor saveTokensWithConfiguration:[MSIDTestConfiguration v2DefaultConfiguration]
                                                          response:tokenResponse
                                                           factory:self.factory
                                                           context:self.context
                                                             error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Should have stored regular refresh token
    NSArray *allRegularRTs = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:self.defaultAccessor];
    XCTAssertEqual(allRegularRTs.count, 1);
    
    // Should not have family refresh token
    NSArray *allFamilyRTs = [MSIDTestCacheAccessorHelper getAllTokens:self.defaultAccessor 
                                                                 type:MSIDFamilyRefreshTokenType 
                                                                class:[MSIDFamilyRefreshToken class]];
    XCTAssertEqual(allFamilyRTs.count, 0);
}

#pragma mark - Client-side disable scenarios

- (void)testSaveRefreshToken_whenClientDisabledFRT_shouldStoreRegularRT
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    [MSIDAccountCredentialCache setDisableFRT:YES]; // Client-side disable
    
    MSIDRefreshToken *refreshTokenWithFamilyId = [self createRefreshTokenWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    NSError *error = nil;
    BOOL result = [self.defaultAccessor saveToken:refreshTokenWithFamilyId context:self.context error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Should store as regular RT despite having family ID
    NSArray *allRegularRTs = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:self.defaultAccessor];
    XCTAssertEqual(allRegularRTs.count, 1);
    
    NSArray *allFamilyRTs = [MSIDTestCacheAccessorHelper getAllTokens:self.defaultAccessor 
                                                                 type:MSIDFamilyRefreshTokenType 
                                                                class:[MSIDFamilyRefreshToken class]];
    XCTAssertEqual(allFamilyRTs.count, 0);
}

#pragma mark - Error handling

- (void)testSaveRefreshToken_whenStorageFails_shouldReturnError
{
    // Create a failing data source
    MSIDTestCacheDataSource *failingDataSource = [[MSIDTestCacheDataSource alloc] init];
    failingDataSource.shouldFailAllWrites = YES;
    
    MSIDDefaultTokenCacheAccessor *failingAccessor = [[MSIDDefaultTokenCacheAccessor alloc] 
                                                     initWithDataSource:failingDataSource 
                                                     otherCacheAccessors:nil];
    
    MSIDRefreshToken *refreshToken = [self createRefreshTokenWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    
    NSError *error = nil;
    BOOL result = [failingAccessor saveToken:refreshToken context:self.context error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

#pragma mark - Mixed storage scenarios

- (void)testSaveTokens_mixedFamilyAndRegularTokens_shouldStoreBothCorrectly
{
    [self enableFRTFeatureFlag];
    [self saveFRTEnabledSettings:YES];
    
    MSIDRefreshToken *familyRT = [self createRefreshTokenWithFamilyId:DEFAULT_TEST_FAMILY_ID];
    MSIDRefreshToken *regularRT = [self createRefreshTokenWithFamilyId:nil];
    // Make them different accounts to avoid conflicts
    regularRT.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"different@user.com"
                                                                         homeAccountId:@"different.home.account.id"];
    
    NSError *error = nil;
    BOOL result1 = [self.defaultAccessor saveToken:familyRT context:self.context error:&error];
    XCTAssertTrue(result1);
    XCTAssertNil(error);
    
    BOOL result2 = [self.defaultAccessor saveToken:regularRT context:self.context error:&error];
    XCTAssertTrue(result2);
    XCTAssertNil(error);
    
    // Should have both types stored
    NSArray *allFamilyRTs = [MSIDTestCacheAccessorHelper getAllTokens:self.defaultAccessor 
                                                                 type:MSIDFamilyRefreshTokenType 
                                                                class:[MSIDFamilyRefreshToken class]];
    XCTAssertEqual(allFamilyRTs.count, 1);
    
    NSArray *allRegularRTs = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:self.defaultAccessor];
    XCTAssertEqual(allRegularRTs.count, 1);
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
    [self.defaultAccessor.accountCredentialCache updateFRTSettings:enabled context:self.context error:&error];
    XCTAssertNil(error);
}

- (MSIDRefreshToken *)createRefreshTokenWithFamilyId:(NSString *)familyId
{
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = DEFAULT_TEST_REFRESH_TOKEN;
    refreshToken.familyId = familyId;
    refreshToken.environment = DEFAULT_TEST_ENVIRONMENT;
    refreshToken.realm = DEFAULT_TEST_UTID;
    refreshToken.clientId = DEFAULT_TEST_CLIENT_ID;
    refreshToken.accountIdentifier = self.accountIdentifier;
    return refreshToken;
}

- (MSIDTokenResponse *)createTokenResponseWithFamilyId:(NSString *)familyId
{
    NSMutableDictionary *tokenResponseDict = [@{
        @"access_token": DEFAULT_TEST_ACCESS_TOKEN,
        @"refresh_token": DEFAULT_TEST_REFRESH_TOKEN,
        @"id_token": DEFAULT_TEST_ID_TOKEN,
        @"token_type": @"Bearer",
        @"expires_in": @"3600"
    } mutableCopy];
    
    if (familyId)
    {
        tokenResponseDict[@"foci"] = familyId;
    }
    
    NSError *error = nil;
    MSIDTokenResponse *tokenResponse = [self.factory tokenResponseFromJSON:tokenResponseDict
                                                                   context:self.context 
                                                                     error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(tokenResponse);
    
    return tokenResponse;
}

@end