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
#import "MSIDToken.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDTokenTests : XCTestCase

@end

@implementation MSIDTokenTests

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
    MSIDToken *token = [self createToken];
    MSIDToken *tokenCopy = [token copy];
    
    XCTAssertEqualObjects(tokenCopy, token);
}

#pragma mark - isEqual tests

- (void)testIsEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    MSIDToken *lhs = [self createToken];
    MSIDToken *rhs = [self createToken];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenTokenIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"token 1" forKey:@"token"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"token 2" forKey:@"token"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenTokenIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"token 1" forKey:@"token"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"token 1" forKey:@"token"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenIdTokenIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 2" forKey:@"idToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenIdTokenIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 1" forKey:@"idToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenExpiresOnIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:2000000000] forKey:@"expiresOn"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenExpiresOnIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenFamilyIdIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"familyId"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 2" forKey:@"familyId"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenFamilyIdIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"familyId"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 1" forKey:@"familyId"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenClientInfoIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:[self createClientInfo:@{@"key1" : @"value1"}] forKey:@"clientInfo"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:[self createClientInfo:@{@"key2" : @"value2"}] forKey:@"clientInfo"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenClientInfoIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:[self createClientInfo:@{@"key1" : @"value1"}] forKey:@"clientInfo"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:[self createClientInfo:@{@"key1" : @"value1"}] forKey:@"clientInfo"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenAdditionalServerInfoIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@{@"key1" : @"value1"} forKey:@"additionalServerInfo"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@{@"key2" : @"value2"} forKey:@"additionalServerInfo"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenAdditionalServerInfoIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@{@"key" : @"value"} forKey:@"additionalServerInfo"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@{@"key" : @"value"} forKey:@"additionalServerInfo"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenTokenTypeIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@0 forKey:@"tokenType"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@1 forKey:@"tokenType"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenTokenTypeIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@0 forKey:@"tokenType"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@0 forKey:@"tokenType"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenResourceIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"resource"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 2" forKey:@"resource"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenResourceIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"resource"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 1" forKey:@"resource"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenAuthorityIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:[NSURL URLWithString:@"https://contoso2.com"] forKey:@"authority"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenAuthorityIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenClientIdIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"clientId"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 2" forKey:@"clientId"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenClientIdIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"clientId"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 1" forKey:@"clientId"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenScopesIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:[[NSOrderedSet alloc] initWithArray:@[@1, @2]] forKey:@"scopes"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:[[NSOrderedSet alloc] initWithArray:@[@1, @3]] forKey:@"scopes"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenScopesIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:[[NSOrderedSet alloc] initWithArray:@[@1, @2]] forKey:@"scopes"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:[[NSOrderedSet alloc] initWithArray:@[@1, @2]] forKey:@"scopes"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - Json, Conditional fields

- (void)testInitWithJson_whenJsonContainsEnvironment_shouldParseItAsAuthority
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_ENVIRONMENT : @"evironment_value",
                                   } mutableCopy];
    
    NSError *error;
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
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
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(expectedJson, [token jsonDictionary]);
}

- (void)testInitWithJson_whenJsonContainsAuthority_shouldParseItAsAuthority
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_AUTHORITY : @"https://contoso.com",
                                   } mutableCopy];
    
    NSError *error;
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
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
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
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
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
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
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(expectedJson, [token jsonDictionary]);
}

- (void)testInitWithJson_whenJsonContainsAccessToken_shouldParseItAsToken
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_ACCESS_TOKEN : @"access token value",
                                   } mutableCopy];
    
    NSError *error;
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
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
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(expectedJson, [token jsonDictionary]);
}

- (void)testInitWithJson_whenJsonContainsRefreshToken_shouldParseItAsToken
{
    NSMutableDictionary *json = [@{
                                   MSID_OAUTH2_REFRESH_TOKEN : @"refresh token value",
                                   } mutableCopy];
    
    NSError *error;
    MSIDToken *token = [[MSIDToken alloc] initWithJSONDictionary:json error:&error];
    
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

- (MSIDToken *)createToken
{
    MSIDToken *token = [MSIDToken new];
    [token setValue:@"access token value" forKey:@"token"];
    [token setValue:@"id token value" forKey:@"idToken"];
    [token setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    [token setValue:@"familyId value" forKey:@"familyId"];
    [token setValue:[self createClientInfo:@{@"key" : @"value"}] forKey:@"clientInfo"];
    [token setValue:@{@"key2" : @"value2"} forKey:@"additionalServerInfo"];
    [token setValue:@"some resource" forKey:@"resource"];
    [token setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    [token setValue:@"some clientId" forKey:@"clientId"];
    [token setValue:[[NSOrderedSet alloc] initWithArray:@[@"1", @"2"]] forKey:@"scopes"];
    
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
