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
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDAdfsToken.h"
#import "MSIDIdToken.h"

@interface MSIDBaseTokenTests : XCTestCase

@end

@implementation MSIDBaseTokenTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

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

- (void)testBaseTokenIsEqual_whenTokenTypeIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@0 forKey:@"tokenType"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@0 forKey:@"tokenType"];
    
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

#pragma mark - MSIDAccessToken

- (void)testAccessTokenIsEqual_whenTokenIsNotEqual_shouldReturnFalse
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:@"token 1" forKey:@"idToken"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:@"token 2" forKey:@"idToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testAccessTokenIsEqual_whenTokenIsEqual_shouldReturnTrue
{
    MSIDAccessToken *lhs = [MSIDAccessToken new];
    [lhs setValue:@"token 1" forKey:@"idToken"];
    MSIDAccessToken *rhs = [MSIDAccessToken new];
    [rhs setValue:@"token 1" forKey:@"idToken"];
    
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

- (void)testAccessTokenIsEqual_whenCachedAtExpiresOnIsEqual_shouldReturnTrue
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

#pragma mark - MSIDRefreshToken

- (void)testRefreshTokenIsEqual_whenFamilyIdIsNotEqual_shouldReturnFalse
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"familyId"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"value 2" forKey:@"familyId"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testRefreshTokenIsEqual_whenFamilyIdIsEqual_shouldReturnTrue
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"familyId"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"value 1" forKey:@"familyId"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testRefreshTokenIsEqual_whenTokenIsNotEqual_shouldReturnFalse
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"refreshToken"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"value 2" forKey:@"refreshToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testRefreshTokenIsEqual_whenTokenIsEqual_shouldReturnTrue
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"refreshToken"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"value 1" forKey:@"refreshToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testRefreshTokenIsEqual_whenIdTokenIsNotEqual_shouldReturnFalse
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"value 2" forKey:@"idToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testRefreshTokenIsEqual_whenIdTokenIsEqual_shouldReturnTrue
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"value 1" forKey:@"idToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testRefreshTokenIsEqual_whenUsernameIsNotEqual_shouldReturnFalse
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"username"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"value 2" forKey:@"username"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testRefreshTokenIsEqual_whenUsernameIsEqual_shouldReturnTrue
{
    MSIDRefreshToken *lhs = [MSIDRefreshToken new];
    [lhs setValue:@"value 1" forKey:@"username"];
    MSIDRefreshToken *rhs = [MSIDRefreshToken new];
    [rhs setValue:@"value 1" forKey:@"username"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - MSIDAdfsToken

- (void)testAdfsTokenIsEqual_whenRefreshTokenIsNotEqual_shouldReturnFalse
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:@"value 1" forKey:@"refreshToken"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:@"value 2" forKey:@"refreshToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testAdfsTokenIsEqual_whenRefreshTokenIsEqual_shouldReturnTrue
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:@"value 1" forKey:@"refreshToken"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:@"value 1" forKey:@"refreshToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - MSIDIdToken

- (void)testIDTokenIsEqual_whenRefreshTokenIsNotEqual_shouldReturnFalse
{
    MSIDIdToken *lhs = [MSIDIdToken new];
    [lhs setValue:@"value 1" forKey:@"rawIdToken"];
    MSIDIdToken *rhs = [MSIDIdToken new];
    [rhs setValue:@"value 2" forKey:@"rawIdToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIDTokenIsEqual_whenRefreshTokenIsEqual_shouldReturnTrue
{
    MSIDIdToken *lhs = [MSIDIdToken new];
    [lhs setValue:@"value 1" forKey:@"rawIdToken"];
    MSIDIdToken *rhs = [MSIDIdToken new];
    [rhs setValue:@"value 1" forKey:@"rawIdToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - Json, Conditional fields

- (void)testInitWithJson_whenJsonContainsEnvironment_shouldParseItAsAuthority
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_ENVIRONMENT : @"evironment_value",
                                   } mutableCopy];
    
    NSError *error;
    MSIDBaseCacheItem *token = [[MSIDBaseCacheItem alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"https://evironment_value/common", token.authority.absoluteString);
}

- (void)testJsonDictionary_whenJsonContainsEnvironment_shouldReturnJsonWithEnvironmentAndAuthority
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_ENVIRONMENT : @"evironment_value",
                                   } mutableCopy];
    NSMutableDictionary *expectedJson = [@{
                                           MSID_OAUTH2_ENVIRONMENT : @"evironment_value",
                                           MSID_OAUTH2_AUTHORITY : @"https://evironment_value/common",
                                           } mutableCopy];
    
    NSError *error;
    MSIDBaseCacheItem *token = [[MSIDBaseCacheItem alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(expectedJson, [token jsonDictionary]);
}

- (void)testInitWithJson_whenJsonContainsAuthority_shouldParseItAsAuthority
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_AUTHORITY : @"https://contoso.com",
                                   } mutableCopy];
    
    NSError *error;
    MSIDBaseCacheItem *token = [[MSIDBaseCacheItem alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"https://contoso.com", token.authority.absoluteString);
}

- (void)testJsonDictionary_whenJsonContainsAuthority_shouldReturnJsonWithEnvironmentAndAuthority
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_AUTHORITY : @"https://contoso.com",
                                   } mutableCopy];
    NSMutableDictionary *expectedJson = [@{
                                           MSID_OAUTH2_ENVIRONMENT : @"contoso.com",
                                           MSID_OAUTH2_AUTHORITY : @"https://contoso.com",
                                           } mutableCopy];
    
    NSError *error;
    MSIDBaseCacheItem *token = [[MSIDBaseCacheItem alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(expectedJson, [token jsonDictionary]);
}

- (void)testInitWithJson_whenJsonContainsAuthorityAndEnvironment_shouldParseAuthorityAsAuthority
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_AUTHORITY : @"https://contoso.com",
                                   MSID_OAUTH2_ENVIRONMENT : @"evironment_value",
                                   } mutableCopy];
    
    NSError *error;
    MSIDBaseCacheItem *token = [[MSIDBaseCacheItem alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"https://contoso.com", token.authority.absoluteString);
}

- (void)testJsonDictionary_whenJsonContainsAuthorityAuthorityAndEnvironment_shouldReturnJsonWithEnvironmentAndAuthorityAndReplaceEnvironmentWithAuthroityValue
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_AUTHORITY : @"https://contoso.com",
                                   MSID_OAUTH2_ENVIRONMENT : @"evironment_value",
                                   } mutableCopy];
    NSMutableDictionary *expectedJson = [@{
                                           MSID_OAUTH2_ENVIRONMENT : @"contoso.com",
                                           MSID_OAUTH2_AUTHORITY : @"https://contoso.com",
                                           } mutableCopy];
    
    NSError *error;
    MSIDBaseCacheItem *token = [[MSIDBaseCacheItem alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(expectedJson, [token jsonDictionary]);
}

- (void)testInitWithJson_whenJsonContainsAccessToken_shouldParseItAsToken
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_ACCESS_TOKEN : @"access token value",
                                   } mutableCopy];
    
    NSError *error;
    MSIDBaseCacheItem *token = [[MSIDBaseCacheItem alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"access token value", token.token);
    XCTAssertEqual(MSIDTokenTypeAccessToken, token.tokenType);
}

- (void)testJsonDictionary_whenJsonContainsAccessToken_shouldReturnJsonWithAccessToken
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_ACCESS_TOKEN : @"access token value",
                                   } mutableCopy];
    NSMutableDictionary *expectedJson = [@{
                                           MSID_OAUTH2_ACCESS_TOKEN : @"access token value",
                                           } mutableCopy];
    
    NSError *error;
    MSIDBaseCacheItem *token = [[MSIDBaseCacheItem alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(expectedJson, [token jsonDictionary]);
}

- (void)testInitWithJson_whenJsonContainsRefreshToken_shouldParseItAsToken
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_REFRESH_TOKEN : @"refresh token value",
                                   } mutableCopy];
    
    NSError *error;
    MSIDBaseCacheItem *token = [[MSIDBaseCacheItem alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"refresh token value", token.token);
    XCTAssertEqual(MSIDTokenTypeRefreshToken, token.tokenType);
}

- (void)testJsonDictionary_whenJsonContainsRefreshToken_shouldReturnJsonWithRefreshToken
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_REFRESH_TOKEN : @"refresh token value",
                                   } mutableCopy];
    NSMutableDictionary *expectedJson = [@{
                                           MSID_OAUTH2_REFRESH_TOKEN : @"refresh token value",
                                           } mutableCopy];
    
    NSError *error;
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(expectedJson, [token jsonDictionary]);
}

- (void)testJsonDictionary_whenJsonContainsAccessAndRefreshToken_shouldReturnBoth
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_ACCESS_TOKEN : @"access token value",
                                   MSID_OAUTH2_REFRESH_TOKEN : @"refresh token value",
                                   } mutableCopy];
    
    NSError *error;
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(json, [token jsonDictionary]);
}

#pragma mark - Json, Nonconditional fields

- (void)testInitWithJson_whenJsonContainsNonconditionalFields_shouldInitCorrespondingProperties
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_ID_TOKEN : @"id_token_value",
                                   MSID_FAMILY_ID : @"family_id_value",
                                   MSID_OAUTH2_RESOURCE : @"resource_value",
                                   MSID_OAUTH2_CLIENT_ID : @"client_id_value",
                                   MSID_OAUTH2_SCOPE : @"v1 v2",
                                   MSID_OAUTH2_CLIENT_INFO : [@{@"key" : @"value"} msidBase64UrlJson],
                                   MSID_OAUTH2_EXPIRES_ON : @1500000000,
                                   MSID_OAUTH2_ADDITIONAL_SERVER_INFO : @{@"key2" : @"value2"},
                                   } mutableCopy];
    
    NSError *error;
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"id_token_value", token.idToken);
    XCTAssertEqualObjects(@"family_id_value", token.familyId);
    XCTAssertEqualObjects(@"resource_value", token.resource);
    XCTAssertEqualObjects(@"client_id_value", token.clientId);
    NSArray *expectedScopes = @[@"v1", @"v2"];
    XCTAssertEqualObjects(expectedScopes, [token.scopes array]);
    XCTAssertEqualObjects([@{@"key" : @"value"} msidBase64UrlJson], token.clientInfo.rawClientInfo);
    XCTAssertEqualObjects(@{@"key2" : @"value2"}, token.additionalServerInfo);
}

- (void)testJsonDictionary_whenJsonContainsNonconditionalFields_shouldReturnSameJson
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_ID_TOKEN : @"id_token_value",
                                   MSID_FAMILY_ID : @"family_id_value",
                                   MSID_OAUTH2_RESOURCE : @"resource_value",
                                   MSID_OAUTH2_CLIENT_ID : @"client_id_value",
                                   MSID_OAUTH2_SCOPE : @"v1 v2",
                                   MSID_OAUTH2_CLIENT_INFO : [@{@"key" : @"value"} msidBase64UrlJson],
                                   MSID_OAUTH2_EXPIRES_ON : @"1500000000",
                                   MSID_OAUTH2_ADDITIONAL_SERVER_INFO : @{@"key2" : @"value2"},
                                   } mutableCopy];
    
    NSError *error;
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(json, [token jsonDictionary]);
}

#pragma mark - Json, Extra fields

- (void)test_whenJsonContainsExtraFields_shouldKeepThem
{
    NSMutableDictionary *json = [@{
                                   @"some key" : @"some value",
                                   MSID_OAUTH2_ID_TOKEN : @"id_token_value",
                                   MSID_FAMILY_ID : @"family_id_value",
                                   MSID_OAUTH2_RESOURCE : @"resource_value",
                                   MSID_OAUTH2_CLIENT_ID : @"client_id_value",
                                   MSID_OAUTH2_SCOPE : @"v1 v2",
                                   MSID_OAUTH2_CLIENT_INFO : [@{@"key" : @"value"} msidBase64UrlJson],
                                   MSID_OAUTH2_EXPIRES_ON : @"1500000000",
                                   MSID_OAUTH2_ADDITIONAL_SERVER_INFO : @{@"key2" : @"value2"},
                                   } mutableCopy];
    
    NSError *error;
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(json, [token jsonDictionary]);
}

#pragma mark - Private

- (MSIDBaseToken *)createToken
{
    MSIDBaseToken *token = [MSIDBaseToken new];
    [token setValue:[self createClientInfo:@{@"key" : @"value"}] forKey:@"clientInfo"];
    [token setValue:@{@"spe_info" : @"value2"} forKey:@"additionalInfo"];
    [token setValue:[NSURL URLWithString:@"https://contoso.com/common"] forKey:@"authority"];
    [token setValue:@"some clientId" forKey:@"clientId"];
    [token setValue:@"uid.utid" forKey:@"uniqueUserId"];
    [token setValue:[[NSOrderedSet alloc] initWithArray:@[@"1", @"2"]] forKey:@"scopes"];
    
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
