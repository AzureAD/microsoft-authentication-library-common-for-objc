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
#import "MSIDFamilyRefreshToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDCredentialCacheItem.h"
#import "MSIDCredentialType.h"
#import "MSIDAccessToken.h"

@interface MSIDFamilyRefreshTokenTests : XCTestCase

@end

@implementation MSIDFamilyRefreshTokenTests

#pragma mark - Initialization tests

- (void)testInitWithRefreshToken_whenValidRefreshToken_shouldReturnFamilyRefreshToken
{
    MSIDRefreshToken *refreshToken = [self createRefreshToken];
    
    MSIDFamilyRefreshToken *familyRefreshToken = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken];
    
    XCTAssertNotNil(familyRefreshToken);
    XCTAssertEqualObjects(familyRefreshToken.refreshToken, refreshToken.refreshToken);
    XCTAssertEqualObjects(familyRefreshToken.familyId, refreshToken.familyId);
    XCTAssertEqualObjects(familyRefreshToken.environment, refreshToken.environment);
    XCTAssertEqualObjects(familyRefreshToken.realm, refreshToken.realm);
    XCTAssertEqualObjects(familyRefreshToken.clientId, refreshToken.clientId);
    XCTAssertEqualObjects(familyRefreshToken.accountIdentifier, refreshToken.accountIdentifier);
}

- (void)testInitWithRefreshToken_whenNilRefreshToken_shouldReturnNil
{
    MSIDFamilyRefreshToken *familyRefreshToken = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:nil];
    
    XCTAssertNil(familyRefreshToken);
}

- (void)testInitWithRefreshToken_whenInvalidTokenClass_shouldReturnNil
{
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] init];
    
    MSIDFamilyRefreshToken *familyRefreshToken = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:(MSIDRefreshToken *)accessToken];
    
    XCTAssertNil(familyRefreshToken);
}

#pragma mark - Credential type tests

- (void)testCredentialType_shouldReturnFamilyRefreshTokenType
{
    MSIDRefreshToken *refreshToken = [self createRefreshToken];
    MSIDFamilyRefreshToken *familyRefreshToken = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken];
    
    XCTAssertEqual(familyRefreshToken.credentialType, MSIDFamilyRefreshTokenType);
}

#pragma mark - Token cache item tests

- (void)testTokenCacheItem_whenValidFamilyRefreshToken_shouldReturnCorrectCacheItem
{
    MSIDRefreshToken *refreshToken = [self createRefreshToken];
    MSIDFamilyRefreshToken *familyRefreshToken = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken];
    
    MSIDCredentialCacheItem *cacheItem = [familyRefreshToken tokenCacheItem];
    
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.secret, familyRefreshToken.refreshToken);
    XCTAssertEqualObjects(cacheItem.familyId, familyRefreshToken.familyId);
    XCTAssertEqual(cacheItem.credentialType, MSIDFamilyRefreshTokenType);
    XCTAssertNil(cacheItem.realm); // Family refresh tokens have nil realm
}

#pragma mark - Copy tests

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    MSIDRefreshToken *refreshToken = [self createRefreshToken];
    MSIDFamilyRefreshToken *familyRefreshToken = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken];
    
    MSIDFamilyRefreshToken *copy = [familyRefreshToken copy];
    
    XCTAssertNotNil(copy);
    XCTAssertEqualObjects(copy, familyRefreshToken);
    XCTAssertNotEqual(copy, familyRefreshToken); // Different memory addresses
}

#pragma mark - Equality tests

- (void)testIsEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    MSIDRefreshToken *refreshToken1 = [self createRefreshToken];
    MSIDRefreshToken *refreshToken2 = [self createRefreshToken];
    
    MSIDFamilyRefreshToken *frt1 = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken1];
    MSIDFamilyRefreshToken *frt2 = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken2];
    
    XCTAssertEqualObjects(frt1, frt2);
}

- (void)testIsEqual_whenFamilyIdDifferent_shouldReturnFalse
{
    MSIDRefreshToken *refreshToken1 = [self createRefreshToken];
    refreshToken1.familyId = @"family1";
    
    MSIDRefreshToken *refreshToken2 = [self createRefreshToken];
    refreshToken2.familyId = @"family2";
    
    MSIDFamilyRefreshToken *frt1 = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken1];
    MSIDFamilyRefreshToken *frt2 = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken2];
    
    XCTAssertNotEqualObjects(frt1, frt2);
}

- (void)testIsEqual_whenRefreshTokenDifferent_shouldReturnFalse
{
    MSIDRefreshToken *refreshToken1 = [self createRefreshToken];
    refreshToken1.refreshToken = @"token1";
    
    MSIDRefreshToken *refreshToken2 = [self createRefreshToken];
    refreshToken2.refreshToken = @"token2";
    
    MSIDFamilyRefreshToken *frt1 = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken1];
    MSIDFamilyRefreshToken *frt2 = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken2];
    
    XCTAssertNotEqualObjects(frt1, frt2);
}

#pragma mark - Description tests

- (void)testDescription_shouldContainTokenInfoAndFamilyId
{
    MSIDRefreshToken *refreshToken = [self createRefreshToken];
    refreshToken.refreshToken = @"test_refresh_token";
    refreshToken.familyId = @"test_family_id";
    
    MSIDFamilyRefreshToken *familyRefreshToken = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken];
    
    NSString *description = [familyRefreshToken description];
    
    XCTAssertTrue([description containsString:@"family refresh token"]);
    XCTAssertTrue([description containsString:@"family ID=test_family_id"]);
}

#pragma mark - Property inheritance tests

- (void)testPropertyInheritance_shouldInheritAllBaseTokenProperties
{
    MSIDRefreshToken *refreshToken = [self createRefreshToken];
    refreshToken.storageEnvironment = @"storage_env";
    refreshToken.environment = @"env";
    refreshToken.realm = @"realm";
    refreshToken.clientId = @"client_id";
    refreshToken.additionalServerInfo = @{@"key": @"value"};
    
    MSIDFamilyRefreshToken *familyRefreshToken = [[MSIDFamilyRefreshToken alloc] initWithRefreshToken:refreshToken];
    
    XCTAssertEqualObjects(familyRefreshToken.storageEnvironment, refreshToken.storageEnvironment);
    XCTAssertEqualObjects(familyRefreshToken.environment, refreshToken.environment);
    XCTAssertEqualObjects(familyRefreshToken.realm, refreshToken.realm);
    XCTAssertEqualObjects(familyRefreshToken.clientId, refreshToken.clientId);
    XCTAssertEqualObjects(familyRefreshToken.additionalServerInfo, refreshToken.additionalServerInfo);
}

#pragma mark - Helper methods

- (MSIDRefreshToken *)createRefreshToken
{
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    refreshToken.refreshToken = DEFAULT_TEST_REFRESH_TOKEN;
    refreshToken.familyId = DEFAULT_TEST_FAMILY_ID;
    refreshToken.environment = DEFAULT_TEST_ENVIRONMENT;
    refreshToken.realm = DEFAULT_TEST_UTID;
    refreshToken.clientId = DEFAULT_TEST_CLIENT_ID;
    refreshToken.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                             homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    return refreshToken;
}

@end