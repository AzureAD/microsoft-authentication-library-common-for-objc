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

@interface MSIDRefreshTokenTests : XCTestCase

@end

@implementation MSIDRefreshTokenTests

#pragma mark - Copy tests

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    MSIDRefreshToken *token = [self createToken];
    MSIDRefreshToken *tokenCopy = [token copy];
    
    XCTAssertEqualObjects(tokenCopy, token);
}

#pragma mark - isEqual tests

- (void)testRefreshTokenIsEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    MSIDRefreshToken *lhs = [self createToken];
    MSIDRefreshToken *rhs = [self createToken];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - MSIDRefreshToken

- (void)testRefreshTokenIsEqual_whenRefreshTokenIsNotEqual_shouldReturnFalse
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"token 1" forKey:@"refreshToken"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"token 2" forKey:@"refreshToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testRefreshTokenIsEqual_whenRefreshTokenIsEqual_shouldReturnTrue
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"token 1" forKey:@"refreshToken"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"token 1" forKey:@"refreshToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}


- (void)testRefreshTokenIsEqual_whenFamilyIdIsNotEqual_shouldReturnFalse
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"family 1" forKey:@"familyId"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"family 2" forKey:@"familyId"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testRefreshTokenIsEqual_whenFamilyIdIsEqual_shouldReturnTrue
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"family 1" forKey:@"familyId"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"family 1" forKey:@"familyId"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - Token cache item

- (void)testInitWithTokenCacheItem_whenNilCacheItem_shouldReturnNil
{
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenCacheItem:nil];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenWrongTokenType_shouldReturnNil
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDIDTokenType;
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenNoRefreshToken_shouldReturnNil
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDRefreshTokenType;
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.speInfo = @"test";
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenAllFieldsSet_shouldReturnToken
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDRefreshTokenType;
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.speInfo = @"test";
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.secret = @"refresh token";

    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertNil(token.realm);
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.speInfo, @"test");
    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(token.refreshToken, @"refresh token");
    
    MSIDCredentialCacheItem *newCacheItem = [token tokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}

#pragma mark - Private

- (MSIDRefreshToken *)createToken
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
