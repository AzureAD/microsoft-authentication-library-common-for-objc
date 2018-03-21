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
#import "MSIDLegacySingleResourceToken.h"

@interface MSIDLegacySingleResourceTokenTests : XCTestCase

@end

@implementation MSIDLegacySingleResourceTokenTests

#pragma mark - Copy tests

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    MSIDLegacySingleResourceToken *token = [self createToken];
    MSIDLegacySingleResourceToken *tokenCopy = [token copy];
    
    XCTAssertEqualObjects(tokenCopy, token);
}

#pragma mark - isEqual tests

- (void)testLegacyTokenIsEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    MSIDLegacySingleResourceToken *lhs = [self createToken];
    MSIDLegacySingleResourceToken *rhs = [self createToken];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - MSIDLegacySingleResourceToken

- (void)testLegacyTokenIsEqual_whenTokenIsNotEqual_shouldReturnFalse
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:@"token 1" forKey:@"accessToken"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:@"token 2" forKey:@"accessToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenTokenIsEqual_shouldReturnTrue
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:@"token 1" forKey:@"accessToken"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:@"token 1" forKey:@"accessToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenIdTokenIsNotEqual_shouldReturnFalse
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:@"value 2" forKey:@"idToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenIdTokenIsEqual_shouldReturnTrue
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:@"value 1" forKey:@"idToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenExpiresOnIsNotEqual_shouldReturnFalse
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:2000000000] forKey:@"expiresOn"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenExpiresOnIsEqual_shouldReturnTrue
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenCachedAtIsNotEqual_shouldReturnFalse
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"cachedAt"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:2000000000] forKey:@"cachedAt"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenCachedAtIsEqual_shouldReturnTrue
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"cachedAt"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"cachedAt"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenScopesIsNotEqual_shouldReturnFalse
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:@"1 2" forKey:@"target"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:@"1 3" forKey:@"target"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenScopesIsEqual_shouldReturnTrue
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:@"1 2" forKey:@"target"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:@"1 2" forKey:@"target"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenResourceIsNotEqual_shouldReturnFalse
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:@"value 1" forKey:@"target"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:@"value 2" forKey:@"target"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenResourceIsEqual_shouldReturnTrue
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:@"value 1" forKey:@"target"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:@"value 1" forKey:@"target"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenRefreshTokenIsNotEqual_shouldReturnFalse
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:@"value 1" forKey:@"refreshToken"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:@"value 2" forKey:@"refreshToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenRefreshTokenIsEqual_shouldReturnTrue
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:@"value 1" forKey:@"refreshToken"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:@"value 1" forKey:@"refreshToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenFamilyIDIsNotEqual_shouldReturnFalse
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:@"value 1" forKey:@"familyId"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:@"value 2" forKey:@"familyId"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testLegacyTokenIsEqual_whenFamilyIDIsEqual_shouldReturnTrue
{
    MSIDLegacySingleResourceToken *lhs = [MSIDLegacySingleResourceToken new];
    [lhs setValue:@"value 1" forKey:@"familyId"];
    MSIDLegacySingleResourceToken *rhs = [MSIDLegacySingleResourceToken new];
    [rhs setValue:@"value 1" forKey:@"familyId"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - Token cache item

- (void)testInitWithTokenCacheItem_whenNilCacheItem_shouldReturnNil
{
    MSIDLegacySingleResourceToken *token = [[MSIDLegacySingleResourceToken alloc] initWithTokenCacheItem:nil];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenWrongTokenType_shouldReturnNil
{
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeIDToken;
    
    MSIDLegacySingleResourceToken *token = [[MSIDLegacySingleResourceToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenAllFieldsSet_shouldReturnToken
{
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeLegacySingleResourceToken;
    cacheItem.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    cacheItem.clientInfo = [self createClientInfo:@{@"key" : @"value"}];
    cacheItem.additionalInfo = @{@"test": @"test2"};
    cacheItem.username = @"test";
    cacheItem.uniqueUserId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.accessToken = @"token";
    
    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    
    cacheItem.expiresOn = expiresOn;
    cacheItem.cachedAt = cachedAt;
    cacheItem.idToken = @"ID TOKEN";
    cacheItem.target = @"target";
    cacheItem.refreshToken = @"refresh token";
    cacheItem.familyId = @"1";
    
    MSIDLegacySingleResourceToken *token = [[MSIDLegacySingleResourceToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.authority, [NSURL URLWithString:@"https://login.microsoftonline.com/common"]);
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.clientInfo, [self createClientInfo:@{@"key" : @"value"}]);
    XCTAssertEqualObjects(token.additionaServerInfo, @{@"test": @"test2"});
    XCTAssertEqualObjects(token.uniqueUserId, @"uid.utid");
    XCTAssertEqualObjects(token.username, @"test");
    XCTAssertEqualObjects(token.expiresOn, expiresOn);
    XCTAssertEqualObjects(token.cachedAt, cachedAt);
    XCTAssertEqualObjects(token.idToken, @"ID TOKEN");
    XCTAssertEqualObjects(token.resource, @"target");
    XCTAssertEqualObjects(token.refreshToken, @"refresh token");
    XCTAssertEqualObjects(token.accessToken, @"token");
    XCTAssertEqualObjects(token.familyId, @"1");
    
    MSIDTokenCacheItem *newCacheItem = [token tokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}


#pragma mark - Private

- (MSIDLegacySingleResourceToken *)createToken
{
    MSIDLegacySingleResourceToken *token = [MSIDLegacySingleResourceToken new];
    [token setValue:[NSURL URLWithString:@"https://contoso.com/common"] forKey:@"authority"];
    [token setValue:@"some clientId" forKey:@"clientId"];
    [token setValue:[self createClientInfo:@{@"key" : @"value"}] forKey:@"clientInfo"];
    [token setValue:@{@"spe_info" : @"value2"} forKey:@"additionaServerInfo"];
    [token setValue:@"uid.utid" forKey:@"uniqueUserId"];
    [token setValue:@"username" forKey:@"username"];
    [token setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    [token setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"cachedAt"];
    [token setValue:@"token" forKey:@"accessToken"];
    [token setValue:@"idtoken" forKey:@"idToken"];
    [token setValue:@"resource" forKey:@"target"];
    [token setValue:@"scopes" forKey:@"target"];
    [token setValue:@"refreshToken" forKey:@"refreshToken"];
    [token setValue:@"1" forKey:@"familyId"];
    
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
