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
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDRefreshToken.h"
#import "MSIDAuthority.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDClientInfo.h"
#import "MSIDBoundRefreshToken.h"
#import "MSIDBoundRefreshTokenCacheItem.h"

@interface MSIDBoundRefreshTokenTests : XCTestCase

@end

@implementation MSIDBoundRefreshTokenTests

#pragma mark - Copy tests

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    MSIDBoundRefreshToken *token = [self createToken];
    MSIDBoundRefreshToken *tokenCopy = [token copy];
    
    XCTAssertEqualObjects(tokenCopy, token);
}

#pragma mark - isEqual tests

- (void)testBoundRefreshTokenIsEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    MSIDBoundRefreshToken *lhs = [self createToken];
    MSIDBoundRefreshToken *rhs = [self createToken];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - MSIDBoundRefreshToken

- (void)testBoundRefreshTokenIsEqual_whenBoundDeviceIdIsNotEqual_shouldReturnFalse
{
    MSIDBoundRefreshToken *lhs = [self createToken];
    MSIDBoundRefreshToken *rhs = [self createToken];
    rhs.boundDeviceId = @"different_device_id";
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testBoundRefreshTokenIsEqual_whenBoundDeviceIdIsEqual_shouldReturnTrue
{
    MSIDBoundRefreshToken *lhs = [self createToken];
    MSIDBoundRefreshToken *rhs = [self createToken];
    lhs.boundDeviceId = @"abcdefgh";
    rhs.boundDeviceId = @"abcdefgh";
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testBoundRefreshTokenIsEqual_whenRefreshTokenIsNotEqual_shouldReturnFalse
{
    MSIDBoundRefreshToken *lhs = [self createToken];
    MSIDBoundRefreshToken *rhs = [self createToken];
    rhs.refreshToken = @"different_refresh_token";
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testBoundRefreshTokenInitWithRefreshToken_whenValidParameters_shouldCreateBoundRefreshToken
{
    MSIDRefreshToken *refreshToken = [self createRefreshToken];
    MSIDBoundRefreshToken *boundToken = [[MSIDBoundRefreshToken alloc] initWithRefreshToken:refreshToken boundDeviceId:@"device_id"];
    
    XCTAssertNotNil(boundToken);
    XCTAssertEqualObjects(boundToken.refreshToken, refreshToken.refreshToken);
    XCTAssertEqualObjects(boundToken.boundDeviceId, @"device_id");
    XCTAssertEqualObjects(boundToken.familyId, refreshToken.familyId);
    XCTAssertEqualObjects(boundToken.environment, refreshToken.environment);
    XCTAssertEqualObjects(boundToken.realm, refreshToken.realm);
    XCTAssertEqualObjects(boundToken.clientId, refreshToken.clientId);
    XCTAssertEqualObjects(boundToken.accountIdentifier.homeAccountId, refreshToken.accountIdentifier.homeAccountId);
    XCTAssertNotEqual(boundToken.hash, refreshToken.hash);
}

- (void)testBoundRefreshTokenInitWithRefreshToken_whenNilDeviceId_shouldReturnNil
{
    MSIDRefreshToken *refreshToken = [self createRefreshToken];
    NSString *deviceId = nil;
    MSIDBoundRefreshToken *boundToken = [[MSIDBoundRefreshToken alloc] initWithRefreshToken:refreshToken boundDeviceId:deviceId];
    
    XCTAssertNil(boundToken);
}

#pragma mark - Token cache item

- (void)testInitWithTokenCacheItem_whenNilCacheItem_shouldReturnNil
{
    MSIDBoundRefreshToken *token = [[MSIDBoundRefreshToken alloc] initWithTokenCacheItem:nil];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenWrongTokenType_shouldReturnNil
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDIDTokenType;
    
    MSIDBoundRefreshToken *token = [[MSIDBoundRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenNoRefreshToken_shouldReturnNil
{
    MSIDBoundRefreshTokenCacheItem *cacheItem = [MSIDBoundRefreshTokenCacheItem new];
    cacheItem.credentialType = MSIDBoundRefreshTokenType;
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.speInfo = @"test";
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.boundDeviceId = @"device id";
    
    MSIDBoundRefreshToken *token = [[MSIDBoundRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenNoDeviceId_shouldReturnNil
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDBoundRefreshTokenType;
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.speInfo = @"test";
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.secret = @"refresh token";
    
    MSIDBoundRefreshToken *token = [[MSIDBoundRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenAllFieldsSet_shouldReturnToken
{
    MSIDBoundRefreshTokenCacheItem *cacheItem = [MSIDBoundRefreshTokenCacheItem new];
    cacheItem.credentialType = MSIDBoundRefreshTokenType;
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.speInfo = @"test";
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.secret = @"refresh token";
    cacheItem.boundDeviceId = @"device id";

    MSIDBoundRefreshToken *token = [[MSIDBoundRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertNil(token.realm);
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.speInfo, @"test");
    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(token.refreshToken, @"refresh token");
    XCTAssertEqualObjects(token.boundDeviceId, @"device id");
    
    MSIDCredentialCacheItem *newCacheItem = [token tokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}

- (void)testTokenCacheItem_whenAllFieldsSet_shouldReturnValidCacheItem
{
    MSIDBoundRefreshToken *token = [self createToken];
    MSIDBoundRefreshTokenCacheItem *cacheItem = (MSIDBoundRefreshTokenCacheItem *)[token tokenCacheItem];
    
    XCTAssertNotNil(cacheItem);
    XCTAssertEqual(cacheItem.credentialType, MSIDBoundRefreshTokenType);
    XCTAssertEqualObjects(cacheItem.environment, @"contoso.com");
    XCTAssertNil(cacheItem.realm);
    XCTAssertEqualObjects(cacheItem.clientId, @"some clientId");
    XCTAssertEqualObjects(cacheItem.secret, @"refreshToken");
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(cacheItem.boundDeviceId, @"device_id");
}

- (void)testCredentialType_shouldReturnBoundRefreshTokenType
{
    MSIDBoundRefreshToken *token = [self createToken];
    XCTAssertEqual([token credentialType], MSIDBoundRefreshTokenType);
}

#pragma mark - Additional Coverage Tests

- (void)testInitWithRefreshToken_whenNilRefreshToken_shouldReturnNil
{
    MSIDRefreshToken *undefinedRefreshToken = nil;
    MSIDBoundRefreshToken *token = [[MSIDBoundRefreshToken alloc] initWithRefreshToken:undefinedRefreshToken boundDeviceId:@"device_id"];
    XCTAssertNil(token);
}

- (void)testInitWithRefreshToken_whenBlankDeviceId_shouldReturnNil
{
    MSIDRefreshToken *refreshToken = [self createRefreshToken];
    MSIDBoundRefreshToken *token = [[MSIDBoundRefreshToken alloc] initWithRefreshToken:refreshToken boundDeviceId:@""];
    XCTAssertNil(token);
}

- (void)testCopyWithZone_shouldReturnEqualButDistinctInstance
{
    MSIDBoundRefreshToken *token = [self createToken];
    MSIDBoundRefreshToken *tokenCopy = [token copyWithZone:nil];
    XCTAssertEqualObjects(token, tokenCopy);
    XCTAssertFalse(token == tokenCopy);
}

- (void)testIsEqualToItem_whenOtherIsNil_shouldReturnFalse
{
    MSIDBoundRefreshToken *token = [self createToken];
    XCTAssertFalse([token isEqualToItem:nil]);
}

- (void)testIsEqual_whenOtherClass_shouldReturnFalse
{
    MSIDBoundRefreshToken *token = [self createToken];
    NSObject *other = [NSObject new];
    XCTAssertFalse([token isEqual:other]);
}

- (void)testHash_shouldBeEqualForEqualObjects
{
    MSIDBoundRefreshToken *token1 = [self createToken];
    MSIDBoundRefreshToken *token2 = [self createToken];
    XCTAssertEqual(token1.hash, token2.hash);
}

- (void)testHash_shouldDifferForDifferentBoundDeviceId
{
    MSIDBoundRefreshToken *token1 = [self createToken];
    MSIDBoundRefreshToken *token2 = [self createToken];
    token2.boundDeviceId = @"other_device_id";
    XCTAssertNotEqual(token1.hash, token2.hash);
}

- (void)testTokenCacheItem_whenBoundDeviceIdIsNil_shouldReturnNil
{
    MSIDBoundRefreshToken *token = [self createToken];
    NSString *undefinedDeviceId = nil;
    token.boundDeviceId = undefinedDeviceId;
    XCTAssertNil([token tokenCacheItem]);
}

- (void)testDescription_shouldContainRefreshTokenAndDeviceId
{
    MSIDBoundRefreshToken *token = [self createToken];
    NSString *desc = [token description];
    XCTAssertTrue([desc containsString:@"bound refresh token"]);
    XCTAssertTrue([desc containsString:token.boundDeviceId]);
}

#pragma mark - Private

- (MSIDBoundRefreshToken *)createToken
{
    MSIDRefreshToken *refreshToken = [self createRefreshToken];
    return [[MSIDBoundRefreshToken alloc] initWithRefreshToken:refreshToken boundDeviceId:@"device_id"];
}

- (MSIDRefreshToken *)createRefreshToken
{
    MSIDRefreshToken *token = [MSIDRefreshToken new];
    token.environment = @"contoso.com";
    token.realm = @"common";
    token.clientId = @"some clientId";
    token.additionalServerInfo = @{@"spe_info" : @"value2"};
    token.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy.id" homeAccountId:@"uid.utid"];
    token.refreshToken = @"refreshToken";
    token.familyId = @"familyId";
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
