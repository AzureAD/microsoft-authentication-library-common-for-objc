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

- (void)testRefreshTokenIsEqual_whenIdTokenIsNotEqual_shouldReturnFalse
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"token 1" forKey:@"idToken"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"token 2" forKey:@"idToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testRefreshTokenIsEqual_whenIdTokenIsEqual_shouldReturnTrue
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"token 1" forKey:@"idToken"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"token 1" forKey:@"idToken"];
    
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
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeIDToken;
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenNoRefreshToken_shouldReturnNil
{
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeRefreshToken;
    cacheItem.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    cacheItem.clientInfo = [self createClientInfo:@{@"key" : @"value"}];
    cacheItem.additionalInfo = @{@"test": @"test2"};
    cacheItem.username = @"test";
    cacheItem.uniqueUserId = @"uid.utid";
    cacheItem.clientId = @"client id";
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenAllFieldsSet_shouldReturnToken
{
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeRefreshToken;
    cacheItem.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    cacheItem.clientInfo = [self createClientInfo:@{@"key" : @"value"}];
    cacheItem.additionalInfo = @{@"test": @"test2"};
    cacheItem.username = @"test";
    cacheItem.uniqueUserId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.refreshToken = @"refresh token";
    cacheItem.idToken = @"ID TOKEN";
    
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.authority, [NSURL URLWithString:@"https://login.microsoftonline.com/common"]);
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.clientInfo, [self createClientInfo:@{@"key" : @"value"}]);
    XCTAssertEqualObjects(token.additionalServerInfo, @{@"test": @"test2"});
    XCTAssertEqualObjects(token.uniqueUserId, @"uid.utid");
    XCTAssertEqualObjects(token.username, @"test");
    XCTAssertEqualObjects(token.idToken, @"ID TOKEN");
    XCTAssertEqualObjects(token.refreshToken, @"refresh token");
    
    MSIDTokenCacheItem *newCacheItem = [token tokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}

#pragma mark - Private

- (MSIDRefreshToken *)createToken
{
    MSIDRefreshToken *token = [MSIDRefreshToken new];
    [token setValue:[NSURL URLWithString:@"https://contoso.com/common"] forKey:@"authority"];
    [token setValue:@"some clientId" forKey:@"clientId"];
    [token setValue:[self createClientInfo:@{@"key" : @"value"}] forKey:@"clientInfo"];
    [token setValue:@{@"spe_info" : @"value2"} forKey:@"additionalServerInfo"];
    [token setValue:@"uid.utid" forKey:@"uniqueUserId"];
    [token setValue:@"username" forKey:@"username"];
    [token setValue:@"refreshToken" forKey:@"refreshToken"];
    [token setValue:@"familyId" forKey:@"familyId"];
    [token setValue:@"idToken" forKey:@"idToken"];
    
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
