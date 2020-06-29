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
#import "MSIDAccessToken.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDConfiguration.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDAccessTokenTests : XCTestCase

@end

@implementation MSIDAccessTokenTests

#pragma mark - Copy tests

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    MSIDAccessToken *token = [self createToken];
    MSIDAccessToken *tokenCopy = [token copy];
    
    XCTAssertEqualObjects(tokenCopy, token);
}

#pragma mark - isEqual tests

- (void)testAccessTokenIsEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    MSIDAccessToken *lhs = [self createToken];
    MSIDAccessToken *rhs = [self createToken];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - MSIDAccessToken

- (void)testAccessTokenIsEqual_whenTokenIsNotEqual_shouldReturnFalse
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:@"token 1" forKey:@"accessToken"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:@"token 2" forKey:@"accessToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenTokenIsEqual_shouldReturnTrue
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:@"token 1" forKey:@"accessToken"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:@"token 1" forKey:@"accessToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenExpiresOnIsNotEqual_shouldReturnFalse
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:2000000000] forKey:@"expiresOn"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenExpiresOnIsEqual_shouldReturnTrue
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenCachedAtIsNotEqual_shouldReturnFalse
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"cachedAt"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:2000000000] forKey:@"cachedAt"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenCachedAtIsEqual_shouldReturnTrue
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"cachedAt"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"cachedAt"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenScopesIsNotEqual_shouldReturnFalse
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:@"1 2" forKey:@"target"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:@"1 3" forKey:@"target"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenScopesIsEqual_shouldReturnTrue
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:@"1 2" forKey:@"target"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:@"1 2" forKey:@"target"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenResourceIsNotEqual_shouldReturnFalse
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:@"value 1" forKey:@"target"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:@"value 2" forKey:@"target"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenResourceIsEqual_shouldReturnTrue
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:@"value 1" forKey:@"target"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:@"value 1" forKey:@"target"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenAppIdentifierIsNotEqual_shouldReturnFalse
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    lhs.applicationIdentifier = @"value 1";
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    rhs.applicationIdentifier = @"value 2";
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenAppIdentifierIsEqual_shouldReturnTrue
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    lhs.applicationIdentifier = @"value 1";
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    rhs.applicationIdentifier = @"value 1";
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - Token cache item

- (void)testInitWithTokenCacheItem_whenNilCacheItem_shouldReturnNil
{
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenCacheItem:nil];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenWrongTokenType_shouldReturnNil
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDIDTokenType;
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenNoAccessToken_shouldReturnNil
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDAccessTokenType;
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.realm = @"contoso.com";
    cacheItem.speInfo = @"test";
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.target = @"target";
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenNoTarget_shouldReturnNil
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDAccessTokenType;
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.realm = @"contoso.com";
    cacheItem.speInfo = @"test";
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.secret = @"access token";
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenAllFieldsSet_andNoEnrollmentId_shouldReturnToken
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDAccessTokenType;
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.realm = @"contoso.com";
    cacheItem.speInfo = @"test";
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.secret = @"token";
    
    NSDate *expiresOn = [NSDate date];
    NSDate *extExpireTime = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    
    cacheItem.expiresOn = expiresOn;
    cacheItem.extendedExpiresOn = extExpireTime;
    cacheItem.cachedAt = cachedAt;
    cacheItem.target = @"target";
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"contoso.com");
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.speInfo, @"test");
    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.extendedExpiresOn, extExpireTime);
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(token.expiresOn, expiresOn);
    XCTAssertEqualObjects(token.cachedAt, cachedAt);
    XCTAssertEqualObjects(token.resource, @"target");
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"target", nil];
    XCTAssertEqualObjects(token.scopes, scopes);
    XCTAssertEqualObjects(token.accessToken, @"token");
    XCTAssertNil(token.enrollmentId);
    XCTAssertEqual(token.credentialType, MSIDAccessTokenType);

    MSIDCredentialCacheItem *newCacheItem = [token tokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}

- (void)testInitWithTokenCacheItem_whenAllFieldsSet_shouldReturnToken
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.credentialType = MSIDAccessTokenType;
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.realm = @"contoso.com";
    cacheItem.speInfo = @"test";
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.secret = @"token";
    cacheItem.enrollmentId = @"enrollmentId";

    NSDate *expiresOn = [NSDate date];
    NSDate *extExpireTime = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    
    cacheItem.expiresOn = expiresOn;
    cacheItem.extendedExpiresOn = extExpireTime;
    cacheItem.cachedAt = cachedAt;
    cacheItem.target = @"target";

    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"contoso.com");
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.speInfo, @"test");
    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.extendedExpiresOn, extExpireTime);
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(token.expiresOn, expiresOn);
    XCTAssertEqualObjects(token.cachedAt, cachedAt);
    XCTAssertEqualObjects(token.resource, @"target");
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"target", nil];
    XCTAssertEqualObjects(token.scopes, scopes);
    XCTAssertEqualObjects(token.accessToken, @"token");
    XCTAssertEqual(token.enrollmentId, @"enrollmentId");
    XCTAssertEqual(token.credentialType, MSIDAccessTokenType);

    MSIDCredentialCacheItem *newCacheItem = [token tokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}

#pragma mark - expiry

- (void)testExpiryTimeValid_whenDateValid_shouldReturnYES
{
    MSIDAccessToken *token = [MSIDAccessToken new];
    NSDate *extExpireTime = [[NSDate date] dateByAddingTimeInterval:3600];
    token.extendedExpiresOn = extExpireTime;
    token.accessToken = @"at";

    XCTAssertTrue(token.isExtendedLifetimeValid);
}

- (void)testExpiryTimeValid_whenDateNotValid_shouldReturnNO
{
    MSIDAccessToken *token = [MSIDAccessToken new];
    NSDate *extExpireTime = [[NSDate date] dateByAddingTimeInterval:-3600];
    token.additionalServerInfo = @{@"test": @"test2", @"ext_expires_on": extExpireTime};
    token.accessToken = @"at";

    XCTAssertFalse(token.isExtendedLifetimeValid);
}

- (void)testExpiryTimeValid_whenDateValid_andNoAccessToken_shouldReturnNO
{
    MSIDAccessToken *token = [MSIDAccessToken new];
    NSDate *extExpireTime = [[NSDate date] dateByAddingTimeInterval:3600];
    token.additionalServerInfo = @{@"test": @"test2", @"ext_expires_on": extExpireTime};

    XCTAssertFalse(token.isExtendedLifetimeValid);
}

- (void)testIsExpired_whenTokenNotExpired_shouldReturnNO
{
    MSIDAccessToken *token = [MSIDAccessToken new];
    token.expiresOn = [[NSDate date] dateByAddingTimeInterval:3600];
    XCTAssertFalse(token.isExpired);
}

- (void)testIsExpired_whenTokenExpired_shouldReturnYES
{
    MSIDAccessToken *token = [MSIDAccessToken new];
    token.expiresOn = [[NSDate date] dateByAddingTimeInterval:-3600];
    XCTAssertTrue(token.isExpired);
}

- (void)testIsExpired_whenNotExpired_butCachedAtInFuture_shouldReturnYES
{
    MSIDAccessToken *token = [MSIDAccessToken new];
    token.expiresOn = [[NSDate date] dateByAddingTimeInterval:3600];
    token.cachedAt = [[NSDate date] dateByAddingTimeInterval:7200];
    XCTAssertTrue(token.isExpired);
}

- (void)testIsExpired_whenNotExpired_andCachedAtCorrect_shouldReturnNO
{
    MSIDAccessToken *token = [MSIDAccessToken new];
    token.expiresOn = [[NSDate date] dateByAddingTimeInterval:3600];
    token.cachedAt = [[NSDate date] dateByAddingTimeInterval:-7200];
    XCTAssertFalse(token.isExpired);
}

- (void)testIsExpired_whenTokenNotExpired_AndCustomExpiryBuffer_shouldReturnNO
{
    MSIDAccessToken *token = [MSIDAccessToken new];
    token.expiresOn = [[NSDate date] dateByAddingTimeInterval:700];
    XCTAssertFalse([token isExpiredWithExpiryBuffer:601]);
}

- (void)testIsExpired_whenTokenExpired_AndCustomExpiryBuffer_shouldReturnYES
{
    MSIDAccessToken *token = [MSIDAccessToken new];
    token.expiresOn = [[NSDate date] dateByAddingTimeInterval:600];
    XCTAssertTrue([token isExpiredWithExpiryBuffer:601]);
}

#pragma mark - Private

- (MSIDAccessToken *)createToken
{
    MSIDAccessToken *token = [MSIDAccessToken new];
    token.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy_id" homeAccountId:@"uid.utid"];
    token.environment = @"contoso.com";
    token.realm = @"common";
    token.clientId = @"clientId";
    token.additionalServerInfo = @{@"spe_info" : @"value2"};
    token.expiresOn = [NSDate dateWithTimeIntervalSince1970:1500000000];
    token.cachedAt = [NSDate dateWithTimeIntervalSince1970:1500000000];
    token.accessToken = @"token";
    token.resource = @"target";
    token.enrollmentId = @"enrollmentId";
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end

