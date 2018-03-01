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
#import "MSIDBaseToken.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDBaseTokenTests : XCTestCase

@end

@implementation MSIDBaseTokenTests

#pragma mark - Copy tests

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    MSIDBaseToken *token = [self createToken];
    MSIDBaseToken *tokenCopy = [token copy];
    
    XCTAssertEqualObjects(tokenCopy, token);
}

#pragma mark - isEqual tests

- (void)testBaseTokenIsEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [self createToken];
    MSIDBaseToken *rhs = [self createToken];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testBaseTokenIsEqual_whenClientInfoIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:[self createClientInfo:@{@"key1" : @"value1"}] forKey:@"clientInfo"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:[self createClientInfo:@{@"key2" : @"value2"}] forKey:@"clientInfo"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testBaseTokenIsEqual_whenClientInfoIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:[self createClientInfo:@{@"key1" : @"value1"}] forKey:@"clientInfo"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:[self createClientInfo:@{@"key1" : @"value1"}] forKey:@"clientInfo"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testBaseTokenIsEqual_whenAdditionalInfoIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@{@"key1" : @"value1"} forKey:@"additionalInfo"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@{@"key2" : @"value2"} forKey:@"additionalInfo"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testBaseTokenIsEqual_whenAdditionalInfoIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@{@"key" : @"value"} forKey:@"additionalInfo"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@{@"key" : @"value"} forKey:@"additionalInfo"];
    
    XCTAssertEqualObjects(lhs, rhs);
}
- (void)testBaseTokenIsEqual_whenAuthorityIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:[NSURL URLWithString:@"https://contoso2.com"] forKey:@"authority"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testBaseTokenIsEqual_whenAuthorityIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testBaseTokenIsEqual_whenClientIdIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"clientId"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 2" forKey:@"clientId"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testBaseTokenIsEqual_whenClientIdIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"clientId"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 1" forKey:@"clientId"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testBaseTokenIsEqual_whenUniqueUserIdIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"uniqueUserId"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 2" forKey:@"uniqueUserId"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testBaseTokenIsEqual_whenUniqueUserIdIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"uniqueUserId"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 1" forKey:@"uniqueUserId"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testBaseTokenIsEqual_whenUsernameIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"username"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 2" forKey:@"username"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testBaseTokenIsEqual_whenUsernameIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"username"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 1" forKey:@"username"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - Token cache item

- (void)testInitWithTokenCacheItem_whenNilCacheItem_shouldReturnNil
{
    MSIDBaseToken *token = [[MSIDBaseToken alloc] initWithTokenCacheItem:nil];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenWrongTokenType_shouldReturnNil
{
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeIDToken;
    
    MSIDBaseToken *token = [[MSIDBaseToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenNoAuthority_shouldReturnNil
{
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeOther;
    cacheItem.clientId = @"test";
    
    MSIDBaseToken *token = [[MSIDBaseToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenNoClientId_shouldReturnNil
{
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeOther;
    cacheItem.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    
    MSIDBaseToken *token = [[MSIDBaseToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenAllFieldsSet_shouldReturnToken
{
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeOther;
    cacheItem.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    cacheItem.clientInfo = [self createClientInfo:@{@"key" : @"value"}];
    cacheItem.additionalInfo = @{@"test": @"test2"};
    cacheItem.username = @"test";
    cacheItem.uniqueUserId = @"uid.utid";
    cacheItem.clientId = @"client id";
    
    MSIDBaseToken *token = [[MSIDBaseToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.authority, [NSURL URLWithString:@"https://login.microsoftonline.com/common"]);
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.clientInfo, [self createClientInfo:@{@"key" : @"value"}]);
    XCTAssertEqualObjects(token.additionalInfo, @{@"test": @"test2"});
    XCTAssertEqualObjects(token.uniqueUserId, @"uid.utid");
    XCTAssertEqualObjects(token.username, @"test");
    
    MSIDCacheItem *newCacheItem = [token tokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}

#pragma mark - Private

- (MSIDBaseToken *)createToken
{
    MSIDBaseToken *token = [MSIDBaseToken new];
    [token setValue:[NSURL URLWithString:@"https://contoso.com/common"] forKey:@"authority"];
    [token setValue:@"some clientId" forKey:@"clientId"];
    [token setValue:[self createClientInfo:@{@"key" : @"value"}] forKey:@"clientInfo"];
    [token setValue:@{@"spe_info" : @"value2"} forKey:@"additionalInfo"];
    [token setValue:@"uid.utid" forKey:@"uniqueUserId"];
    [token setValue:@"username" forKey:@"username"];
    
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
