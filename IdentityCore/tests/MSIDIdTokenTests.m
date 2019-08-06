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
#import "MSIDIdToken.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDIdTokenTests : XCTestCase

@end

@implementation MSIDIdTokenTests

#pragma mark - Copy tests

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    MSIDIdToken *token = [self createToken];
    MSIDIdToken *tokenCopy = [token copy];
    
    XCTAssertEqualObjects(tokenCopy, token);
}

#pragma mark - isEqual tests

- (void)testIdTokenIsEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    MSIDIdToken *lhs = [self createToken];
    MSIDIdToken *rhs = [self createToken];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - MSIDRefreshToken

- (void)testIdTokenIsEqual_whenIdTokenIsNotEqual_shouldReturnFalse
{
    MSIDIdToken *lhs = [MSIDIdToken new];
    [lhs setValue:@"token 1" forKey:@"rawIdToken"];
    MSIDIdToken *rhs = [MSIDIdToken new];
    [rhs setValue:@"token 2" forKey:@"rawIdToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIdTokenIsEqual_whenIdTokenIsEqual_shouldReturnTrue
{
    MSIDIdToken *lhs = [MSIDIdToken new];
    [lhs setValue:@"token 1" forKey:@"rawIdToken"];
    MSIDIdToken *rhs = [MSIDIdToken new];
    [rhs setValue:@"token 1" forKey:@"rawIdToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - Token cache item

- (void)testInitWithTokenCacheItem_whenNilCacheItem_shouldReturnNil
{
    MSIDIdToken *token = [[MSIDIdToken alloc] initWithTokenCacheItem:nil];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenWrongTokenType_shouldReturnNil
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDRefreshTokenType;
    
    MSIDIdToken *token = [[MSIDIdToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenNoIdToken_shouldReturnNil
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDIDTokenType;
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.realm = @"contoso.com";
    cacheItem.speInfo = @"test";
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    
    MSIDIdToken *token = [[MSIDIdToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenAllFieldsSet_shouldReturnToken
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDIDTokenType;
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.realm = @"contoso.com";
    cacheItem.speInfo = @"test";
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.secret = @"id token";
    
    MSIDIdToken *token = [[MSIDIdToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"contoso.com");
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.speInfo, @"test");
    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(token.rawIdToken, @"id token");
    
    MSIDCredentialCacheItem *newCacheItem = [token tokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}

#pragma mark - Private

- (MSIDIdToken *)createToken
{
    MSIDIdToken *token = [MSIDIdToken new];
    token.environment = @"contoso.com";
    token.realm = @"common";
    token.clientId = @"some clientId";
    token.additionalServerInfo = @{@"spe_info" : @"value2"};
    token.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy.id" homeAccountId:@"uid.utid"];
    token.rawIdToken = @"idToken";
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
