//------------------------------------------------------------------------------
//
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDAADOauth2Factory.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDBaseToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"
#import "MSIDLegacySingleResourceToken.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDRefreshToken.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDTestConfiguration.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAadAuthorityCacheRecord.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAuthority.h"
#import "NSString+MSIDTestUtil.h"

@interface MSIDAADOauth2FactoryTest : XCTestCase

@end

@implementation MSIDAADOauth2FactoryTest

#pragma mark - Token response

- (void)testTokenResponseFromJSON_whenNilJSON_shouldReturnError
{
    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];
    
    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:nil context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testTokenResponseFromJSON_whenValidJSON_shouldReturnAADTokenResponse
{
    NSDictionary *tokenResponse = @{@"access_token": @"access token",
                                    @"refresh_token": @"refresh token"
                                    };
    
    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];
    
    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:tokenResponse context:nil error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    BOOL expectedClass = [response isKindOfClass:[MSIDAADTokenResponse class]];
    XCTAssertTrue(expectedClass);
    XCTAssertEqualObjects(response.accessToken, @"access token");
    XCTAssertEqualObjects(response.refreshToken, @"refresh token");
}

- (void)testTokenResponseFromJSON_whenValidJSON_andRefreshToken_shouldReturnAADTokenResponseWithAdditionalFields
{
    NSDictionary *tokenResponse = @{@"access_token": @"access token",
                                    @"refresh_token": @"refresh token"
                                    };
    
    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];
    
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:tokenResponse refreshToken:refreshToken context:nil error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    BOOL expectedClass = [response isKindOfClass:[MSIDAADTokenResponse class]];
    XCTAssertTrue(expectedClass);
    XCTAssertEqualObjects(response.accessToken, @"access token");
    XCTAssertEqualObjects(response.refreshToken, @"refresh token");
}

#pragma mark - Verify response

- (void)testVerifyResponse_whenWrongResponseProvided_shouldReturnError
{
    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];
    MSIDTokenResponse *response = [MSIDTokenResponse new];
    
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testVerifyResponse_whenValidResponseWithTokens_shouldReturnNoError
{
    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];
    
    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDAADTokenResponse *response = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                            @"refresh_token":@"fake_refresh_token",
                                                                                            @"client_info":rawClientInfo
                                                                                            }
                                                                                    error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

#pragma mark - Tokens

- (void)testBaseTokenFromResponse_whenAADTokenResponse_shouldReturnToken
{
    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];
    
    MSIDAADTokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    NSMutableDictionary *responseDict = [[response jsonDictionary] mutableCopy];
    responseDict[MSID_SPE_INFO_CACHE_KEY] = @"1";

    MSIDAADTokenResponse *modifiedResponse = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:responseDict refreshToken:nil error:nil];

    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];

    MSIDBaseToken *token = [factory baseTokenFromResponse:modifiedResponse configuration:configuration];

    XCTAssertEqualObjects(token.authority, configuration.authority);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.homeAccountId, homeAccountId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, @{@"spe_info": @"1"});
}

- (void)testBaseTokenFromResponse_whenOIDCTokenResponse_shouldReturnNil
{
    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];
    MSIDTokenResponse *response = [MSIDTokenResponse new];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];

    MSIDBaseToken *token = [factory baseTokenFromResponse:response configuration:configuration];
    XCTAssertNil(token);
}

- (void)testAccessTokenFromResponse_whenAADTokenResponse_shouldReturnToken
{
    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];

    MSIDAADTokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponseWithAdditionalFields:@{@"ext_expires_in": @"60"}];

    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];

    MSIDAccessToken *token = [factory accessTokenFromResponse:response configuration:configuration];

    XCTAssertEqualObjects(token.authority, configuration.authority);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.homeAccountId, homeAccountId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);

    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.resource, DEFAULT_TEST_RESOURCE);
    XCTAssertNotNil(token.expiresOn);
    XCTAssertNotNil(token.extendedExpireTime);
}

- (void)testRefreshTokenFromResponse_whenAADTokenResponse_shouldReturnToken
{
    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];
    
    MSIDAADTokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];
    
    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.authority, configuration.authority);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.homeAccountId, homeAccountId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertNil(token.familyId);
}

- (void)testRefreshTokenFromResponse_whenSingleResourceToken_shouldReturnNil
{
    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];
    
    MSIDAADTokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 rt:DEFAULT_TEST_REFRESH_TOKEN
                                                                           resource:nil
                                                                                uid:DEFAULT_TEST_UID
                                                                               utid:DEFAULT_TEST_UTID
                                                                                upn:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                           tenantId:DEFAULT_TEST_UTID
                                      additionalFields:nil];

    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response configuration:configuration];
    XCTAssertNil(token);
}

- (void)testIDTokenFromResponse_whenAADTokenResponse_shouldReturnToken
{
    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];
    
    MSIDAADTokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponse];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];
    
    MSIDIdToken *token = [factory idTokenFromResponse:response configuration:configuration];
    
    XCTAssertEqualObjects(token.authority, configuration.authority);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.homeAccountId, homeAccountId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.rawIdToken, idToken);
}

- (void)testLegacyTokenFromResponse_whenAADTokenResponse_shouldReturnToken
{
    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];

    MSIDAADTokenResponse *response = [MSIDTestTokenResponse v1DefaultTokenResponseWithAdditionalFields:@{@"foci": @"familyId"}];
    MSIDConfiguration *configuration = [MSIDTestConfiguration v1DefaultConfiguration];

    MSIDLegacySingleResourceToken *token = [factory legacyTokenFromResponse:response configuration:configuration];

    XCTAssertEqualObjects(token.authority, configuration.authority);
    XCTAssertEqualObjects(token.clientId, configuration.clientId);
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.homeAccountId, homeAccountId);
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    XCTAssertEqualObjects(token.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(token.additionalServerInfo, [NSMutableDictionary dictionary]);
    
    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(token.familyId, @"familyId");
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:DEFAULT_TEST_ID_TOKEN_USERNAME tenantId:DEFAULT_TEST_UTID];
    
    XCTAssertEqualObjects(token.idToken, idToken);
    XCTAssertEqualObjects(token.resource, DEFAULT_TEST_RESOURCE);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testRefreshTokenLookupAuthorities_whenAuthorityNil_shouldReturnEmptyAuthorities
{
    [self setupAADAuthorityCache];

    MSIDOauth2Factory *factory = [MSIDAADOauth2Factory new];
    NSArray *aliases = [factory refreshTokenLookupAuthorities:nil];
    XCTAssertEqualObjects(aliases, @[]);
}

- (void)testRefreshTokenLookupAuthorities_whenAuthorityProvided_shouldReturnAllAliases
{
    [self setupAADAuthorityCache];

    MSIDOauth2Factory *factory = [MSIDAADOauth2Factory new];
    NSURL *originalAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    NSArray *aliases = [factory refreshTokenLookupAuthorities:originalAuthority];
    NSArray *expectedAliases = @[[NSURL URLWithString:@"https://login.windows.net/contoso.com"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/contoso.com"],
                                 [NSURL URLWithString:@"https://login.windows.net/common"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/common"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/common"]];
    XCTAssertEqualObjects(aliases, expectedAliases);
}

- (void)testCacheAliasesForAuthority_whenAuthorityNil_shouldReturnNilAuthorities
{
    [self setupAADAuthorityCache];

    MSIDOauth2Factory *factory = [MSIDAADOauth2Factory new];
    NSArray *aliases = [factory cacheAliasesForAuthority:nil];
    XCTAssertEqualObjects(aliases, @[]);
}

- (void)testCacheAliasesForAuthority_whenAuthorityProvided_shouldReturnAllAliases
{
    [self setupAADAuthorityCache];

    MSIDOauth2Factory *factory = [MSIDAADOauth2Factory new];
    NSURL *originalAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    NSArray *aliases = [factory cacheAliasesForAuthority:originalAuthority];
    NSArray *expectedAliases = @[[NSURL URLWithString:@"https://login.windows.net/contoso.com"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/contoso.com"]];
    XCTAssertEqualObjects(aliases, expectedAliases);
}

- (void)testCacheAliasesForEnvironment_whenEnvironmentNil_shouldReturnNilAuthorities
{
    [self setupAADAuthorityCache];

    MSIDOauth2Factory *factory = [MSIDAADOauth2Factory new];
    NSArray *aliases = [factory cacheAliasesForEnvironment:nil];
    XCTAssertEqualObjects(aliases, @[]);
}

- (void)testCacheAliasesForEnvirobment_whenEnvironmentNil_shouldReturnAllAliases
{
    [self setupAADAuthorityCache];

    MSIDOauth2Factory *factory = [MSIDAADOauth2Factory new];
    NSString *originalEnvironment = @"login.microsoftonline.com";
    NSArray *aliases = [factory cacheAliasesForEnvironment:originalEnvironment];
    NSArray *expectedAliases = @[@"login.windows.net", @"login.microsoftonline.com", @"login.microsoft.com"];
    XCTAssertEqualObjects(aliases, expectedAliases);
}

- (void)setupAADAuthorityCache
{
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.networkHost = @"login.microsoftonline.com";
    record.cacheHost = @"login.windows.net";
    record.aliases = @[@"login.microsoft.com"];
    MSIDAadAuthorityCache *cache = [MSIDAadAuthorityCache sharedInstance];
    [cache setObject:record forKey:@"login.microsoftonline.com"];
}

@end

