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
#import "MSIDLegacyTokenCacheItem.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAuthority.h"
#import "MSIDAccountIdentifier.h"

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
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDIDTokenType;
    
    MSIDLegacySingleResourceToken *token = [[MSIDLegacySingleResourceToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenAllFieldsSet_shouldReturnToken
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDLegacySingleResourceTokenType;
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.realm = @"common";
    cacheItem.speInfo = @"test";
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.secret = @"token";
    
    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    
    cacheItem.expiresOn = expiresOn;
    cacheItem.cachedAt = cachedAt;
    cacheItem.target = @"target";
    cacheItem.familyId = @"1";
    
    MSIDLegacySingleResourceToken *token = [[MSIDLegacySingleResourceToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"common");
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.speInfo, @"test");
    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(token.expiresOn, expiresOn);
    XCTAssertEqualObjects(token.cachedAt, cachedAt);
    XCTAssertEqualObjects(token.resource, @"target");
    XCTAssertEqualObjects(token.accessToken, @"token");
    XCTAssertEqualObjects(token.familyId, @"1");
    
    MSIDCredentialCacheItem *newCacheItem = [token tokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}

- (void)testInitWithLegacyTokenCacheItem_whenAllFieldsSet_shouldReturnToken
{
    MSIDLegacyTokenCacheItem *cacheItem = [MSIDLegacyTokenCacheItem new];
    cacheItem.credentialType = MSIDLegacySingleResourceTokenType;
    cacheItem.environment = @"login.windows.net";
    cacheItem.realm = @"contoso.com";
    cacheItem.additionalInfo = @{@"test": @"test2"};
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.secret = @"at";
    cacheItem.accessToken = @"at";
    cacheItem.refreshToken = @"rt";

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Test" upn:@"testuser@upn.com" oid:nil tenantId:@"contoso.com"];

    cacheItem.idToken = idToken;

    cacheItem.environment = @"login.windows.net";
    cacheItem.realm = @"contoso.com";
    cacheItem.oauthTokenType = @"token type";

    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];

    cacheItem.expiresOn = expiresOn;
    cacheItem.cachedAt = cachedAt;
    cacheItem.target = @"target";
    cacheItem.familyId = @"1";

    MSIDLegacySingleResourceToken *token = [[MSIDLegacySingleResourceToken alloc] initWithLegacyTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.environment, @"login.windows.net");
    XCTAssertEqualObjects(token.realm, @"contoso.com");
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.additionalServerInfo, @{@"test": @"test2"});
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(token.expiresOn, expiresOn);
    XCTAssertEqualObjects(token.cachedAt, cachedAt);
    XCTAssertEqualObjects(token.resource, @"target");
    XCTAssertEqualObjects(token.familyId, @"1");
    XCTAssertEqualObjects(token.accessToken, @"at");
    XCTAssertEqualObjects(token.refreshToken, @"rt");
    XCTAssertEqualObjects(token.idToken, idToken);
    XCTAssertEqualObjects(token.accountIdentifier.displayableId, @"testuser@upn.com");
    XCTAssertEqualObjects(token.accessTokenType, @"token type");

    MSIDCredentialCacheItem *newCacheItem = [token legacyTokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}


#pragma mark - Private

- (MSIDLegacySingleResourceToken *)createToken
{
    MSIDLegacySingleResourceToken *token = [MSIDLegacySingleResourceToken new];
    token.environment = @"contoso.com";
    token.realm = @"common";
    token.clientId = @"some clientId";
    token.additionalServerInfo = @{@"spe_info" : @"value2"};
    token.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy.id" homeAccountId:@"uid.utid"];
    token.expiresOn = [NSDate dateWithTimeIntervalSince1970:1500000000];
    token.cachedAt = [NSDate dateWithTimeIntervalSince1970:1500000000];
    token.accessToken = @"token";
    token.idToken = @"idtoken";
    token.resource = @"target";
    token.refreshToken = @"refreshToken";
    token.familyId = @"1";
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
