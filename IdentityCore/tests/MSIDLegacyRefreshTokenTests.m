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
#import "MSIDLegacyRefreshToken.h"
#import "MSIDLegacyTokenCacheItem.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDLegacyRefreshTokenTests : XCTestCase

@end

@implementation MSIDLegacyRefreshTokenTests

#pragma mark - Copy tests

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    MSIDLegacyRefreshToken *token = [self createToken];
    MSIDLegacyRefreshToken *tokenCopy = [token copy];
    
    XCTAssertEqualObjects(tokenCopy, token);
}

#pragma mark - isEqual tests

- (void)testLegacyTokenIsEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    MSIDLegacyRefreshToken *lhs = [self createToken];
    MSIDLegacyRefreshToken *rhs = [self createToken];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - MSIDLegacyRefreshToken

- (void)testLegacyTokenIsEqual_whenIdTokenIsNotEqual_shouldReturnFalse
{
    MSIDLegacyRefreshToken *lhs = [MSIDLegacyRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDLegacyRefreshToken *rhs = [MSIDLegacyRefreshToken new];
    [rhs setValue:@"value 2" forKey:@"idToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenIdTokenIsEqual_shouldReturnTrue
{
    MSIDLegacyRefreshToken *lhs = [MSIDLegacyRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDLegacyRefreshToken *rhs = [MSIDLegacyRefreshToken new];
    [rhs setValue:@"value 1" forKey:@"idToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenRefreshTokenIsNotEqual_shouldReturnFalse
{
    MSIDLegacyRefreshToken *lhs = [MSIDLegacyRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"refreshToken"];
    MSIDLegacyRefreshToken *rhs = [MSIDLegacyRefreshToken new];
    [rhs setValue:@"value 2" forKey:@"refreshToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenRefreshTokenIsEqual_shouldReturnTrue
{
    MSIDLegacyRefreshToken *lhs = [MSIDLegacyRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"refreshToken"];
    MSIDLegacyRefreshToken *rhs = [MSIDLegacyRefreshToken new];
    [rhs setValue:@"value 1" forKey:@"refreshToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenFamilyIDIsNotEqual_shouldReturnFalse
{
    MSIDLegacyRefreshToken *lhs = [MSIDLegacyRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"familyId"];
    MSIDLegacyRefreshToken *rhs = [MSIDLegacyRefreshToken new];
    [rhs setValue:@"value 2" forKey:@"familyId"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenFamilyIDIsEqual_shouldReturnTrue
{
    MSIDLegacyRefreshToken *lhs = [MSIDLegacyRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"familyId"];
    MSIDLegacyRefreshToken *rhs = [MSIDLegacyRefreshToken new];
    [rhs setValue:@"value 1" forKey:@"familyId"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - Token cache item

- (void)testInitWithTokenCacheItem_whenNilCacheItem_shouldReturnNil
{
    MSIDLegacyRefreshToken *token = [[MSIDLegacyRefreshToken alloc] initWithTokenCacheItem:nil];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenWrongTokenType_shouldReturnNil
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDIDTokenType;
    
    MSIDLegacyRefreshToken *token = [[MSIDLegacyRefreshToken alloc] initWithTokenCacheItem:cacheItem];
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
    cacheItem.secret = @"token";
    cacheItem.familyId = @"1";
    
    MSIDLegacyRefreshToken *token = [[MSIDLegacyRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertNil(token.realm);
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.speInfo, @"test");
    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(token.familyId, @"1");
    
    MSIDCredentialCacheItem *newCacheItem = [token tokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}

- (void)testInitWithLegacyTokenCacheItem_whenAllFieldsSet_shouldReturnToken
{
    MSIDLegacyTokenCacheItem *cacheItem = [MSIDLegacyTokenCacheItem new];
    cacheItem.credentialType = MSIDRefreshTokenType;
    cacheItem.environment = @"login.windows.net";
    cacheItem.realm = @"contoso.com";
    cacheItem.additionalInfo = @{@"test": @"test2"};
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.secret = @"rt";
    cacheItem.refreshToken = @"rt";

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Test" upn:@"testuser@upn.com" oid:nil tenantId:@"contoso.com"];
    cacheItem.idToken = idToken;
    cacheItem.realm = @"contoso.com";
    cacheItem.environment = @"login.windows.net";
    cacheItem.familyId = @"1";

    MSIDLegacyRefreshToken *token = [[MSIDLegacyRefreshToken alloc] initWithLegacyTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.environment, @"login.windows.net");
    XCTAssertEqualObjects(token.realm, @"contoso.com");
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.additionalServerInfo, @{@"test": @"test2"});
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(token.familyId, @"1");
    XCTAssertEqualObjects(token.refreshToken, @"rt");
    XCTAssertEqualObjects(token.idToken, idToken);
    XCTAssertEqualObjects(token.accountIdentifier.displayableId, @"testuser@upn.com");

    MSIDCredentialCacheItem *newCacheItem = [token legacyTokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}


#pragma mark - Private

- (MSIDLegacyRefreshToken *)createToken
{
    MSIDLegacyRefreshToken *token = [MSIDLegacyRefreshToken new];
    token.environment = @"contoso.com";
    token.realm = @"common";
    token.clientId = @"some clientId";
    token.additionalServerInfo = @{@"spe_info" : @"value2"};
    token.idToken = @"idtoken";
    token.refreshToken = @"refreshtoken";
    token.familyId = @"1";
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
