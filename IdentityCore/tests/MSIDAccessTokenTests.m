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
#import "MSIDRequestParameters.h"

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

- (void)testAccessTokenIsEqual_whenIdTokenIsNotEqual_shouldReturnFalse
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:@"value 2" forKey:@"idToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenIdTokenIsEqual_shouldReturnTrue
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:@"value 1" forKey:@"idToken"];
    
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

- (void)testAccessTokenIsEqual_whenAccessTokenTypeIsNotEqual_shouldReturnFalse
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:@"value 1" forKey:@"accessTokenType"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:@"value 2" forKey:@"accessTokenType"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenAccessTokenTypeIsEqual_shouldReturnTrue
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:@"value 1" forKey:@"accessTokenType"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:@"value 1" forKey:@"accessTokenType"];
    
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
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeIDToken;
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenNoAccessToken_shouldReturnNil
{
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeAccessToken;
    cacheItem.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    cacheItem.clientInfo = [self createClientInfo:@{@"key" : @"value"}];
    cacheItem.additionalInfo = @{@"test": @"test2"};
    cacheItem.username = @"test";
    cacheItem.uniqueUserId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.target = @"target";
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenNoTarget_shouldReturnNil
{
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeAccessToken;
    cacheItem.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    cacheItem.clientInfo = [self createClientInfo:@{@"key" : @"value"}];
    cacheItem.additionalInfo = @{@"test": @"test2"};
    cacheItem.username = @"test";
    cacheItem.uniqueUserId = @"uid.utid";
    cacheItem.clientId = @"client id";
    cacheItem.accessToken = @"access token";
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNil(token);
}

- (void)testInitWithTokenCacheItem_whenAllFieldsSet_shouldReturnToken
{
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.tokenType = MSIDTokenTypeAccessToken;
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
    cacheItem.oauthTokenType = @"Bearer";
    
    MSIDAccessToken *token = [[MSIDAccessToken alloc] initWithTokenCacheItem:cacheItem];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.authority, [NSURL URLWithString:@"https://login.microsoftonline.com/common"]);
    XCTAssertEqualObjects(token.clientId, @"client id");
    XCTAssertEqualObjects(token.clientInfo, [self createClientInfo:@{@"key" : @"value"}]);
    XCTAssertEqualObjects(token.additionalInfo, @{@"test": @"test2"});
    XCTAssertEqualObjects(token.uniqueUserId, @"uid.utid");
    XCTAssertEqualObjects(token.username, @"test");
    XCTAssertEqualObjects(token.expiresOn, expiresOn);
    XCTAssertEqualObjects(token.cachedAt, cachedAt);
    XCTAssertEqualObjects(token.idToken, @"ID TOKEN");
    XCTAssertEqualObjects(token.resource, @"target");
    XCTAssertEqualObjects(token.accessToken, @"token");
    XCTAssertEqualObjects(token.accessTokenType, @"Bearer");
    
    MSIDTokenCacheItem *newCacheItem = [token tokenCacheItem];
    XCTAssertEqualObjects(cacheItem, newCacheItem);
}

#pragma mark - Token response

- (void)testInitWithTokenResponse_whenV1ResponseAndNoResourceInRequest_shouldUseResourceInRequest
{
    NSString *resourceInRequest = @"https://contoso.com";
    MSIDRequestParameters *requestParams = [[MSIDRequestParameters alloc] initWithAuthority:[NSURL URLWithString:@"https://contoso.com/common"]
                                                                                redirectUri:@"fake_redirect_uri"
                                                                                   clientId:@"fake_client_id"
                                                                                     target:resourceInRequest];
    MSIDAADV1TokenResponse *tokenResponse = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                                     }
                                                                                             error:nil];
    
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenResponse:tokenResponse request:requestParams];
    
    XCTAssertEqual(accessToken.scopes.count, 1);
    XCTAssertEqualObjects(accessToken.resource, resourceInRequest);
}

- (void)testInitWithTokenResponse_whenV2ResponseAndDotDefaultScopeInRequest_shouldAddDotDefaultScope
{
    NSString *scopeInRequest = @"https://contoso.com/.Default";
    NSString *scopeInResponse = @"user.read";
    MSIDRequestParameters *requestParams = [[MSIDRequestParameters alloc] initWithAuthority:[NSURL URLWithString:@"https://contoso.com/common"]
                                                                                redirectUri:@"fake_redirect_uri"
                                                                                   clientId:@"fake_client_id"
                                                                                     target:scopeInRequest];
    MSIDAADV2TokenResponse *tokenResponse = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                                     @"scope":scopeInResponse
                                                                                                     }
                                                                                             error:nil];
    
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenResponse:tokenResponse request:requestParams];
    
    XCTAssertEqual(accessToken.scopes.count, 2);
    XCTAssertTrue([scopeInRequest.scopeSet isSubsetOfOrderedSet:accessToken.scopes]);
    XCTAssertTrue([scopeInResponse.scopeSet isSubsetOfOrderedSet:accessToken.scopes]);
}

- (void)testInitWithTokenResponse_whenV1ResponseAndDotDefaultInRequest_shouldNotAddDotDefaultScope
{
    NSString *resourceInRequest = @"https://contoso.com/.Default";
    NSString *resourceInResponse = @"https://contoso.com";
    MSIDRequestParameters *requestParams = [[MSIDRequestParameters alloc] initWithAuthority:[NSURL URLWithString:@"https://contoso.com/common"]
                                                                                redirectUri:@"fake_redirect_uri"
                                                                                   clientId:@"fake_client_id"
                                                                                     target:resourceInRequest];
    MSIDAADV1TokenResponse *tokenResponse = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                                     @"resource":resourceInResponse
                                                                                                     }
                                                                                             error:nil];
    
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenResponse:tokenResponse request:requestParams];
    
    XCTAssertEqual(accessToken.scopes.count, 1);
    XCTAssertEqualObjects(accessToken.resource, resourceInResponse);
}

#pragma mark - Private

- (MSIDAccessToken *)createToken
{
    MSIDAccessToken *token = [MSIDAccessToken new];
    [token setValue:[NSURL URLWithString:@"https://contoso.com/common"] forKey:@"authority"];
    [token setValue:@"some clientId" forKey:@"clientId"];
    [token setValue:[self createClientInfo:@{@"key" : @"value"}] forKey:@"clientInfo"];
    [token setValue:@{@"spe_info" : @"value2"} forKey:@"additionalInfo"];
    [token setValue:@"uid.utid" forKey:@"uniqueUserId"];
    [token setValue:@"username" forKey:@"username"];
    [token setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    [token setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"cachedAt"];
    [token setValue:@"token" forKey:@"accessToken"];
    [token setValue:@"idtoken" forKey:@"idToken"];
    [token setValue:@"resource" forKey:@"target"];
    [token setValue:@"scopes" forKey:@"target"];
    [token setValue:@"Bearer" forKey:@"accessTokenType"];
    
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
