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
#import "MSIDB2CTokenResponse.h"
#import "MSIDB2COauth2Factory.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDTestConfiguration.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAADV1TokenResponse.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDBaseToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"
#import "MSIDAccount.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDB2COauth2FactoryTests : XCTestCase

@end

@implementation MSIDB2COauth2FactoryTests

#pragma mark - Token response

- (void)testTokenResponseFromJSON_whenNilJSON_shouldReturnError
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];

    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:nil context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testTokenResponseFromJSON_whenValidJSON_shouldReturnB2CTokenResponse
{
    NSDictionary *tokenResponse = @{@"access_token": @"access token",
                                    @"refresh_token": @"refresh token"
                                    };

    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];

    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:tokenResponse context:nil error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    BOOL expectedClass = [response isKindOfClass:[MSIDB2CTokenResponse class]];
    XCTAssertTrue(expectedClass);
    XCTAssertEqualObjects(response.accessToken, @"access token");
    XCTAssertEqualObjects(response.refreshToken, @"refresh token");
}

#pragma mark - Verify response

- (void)testVerifyResponse_whenWrongResponseProvided_shouldReturnError
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];
    MSIDAADV1TokenResponse *response = [MSIDAADV1TokenResponse new];

    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testVerifyResponse_whenValidResponseWithTokens_shouldReturnNoError
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];

    NSString *rawClientInfo = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    MSIDB2CTokenResponse *response = [[MSIDB2CTokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                            @"refresh_token":@"fake_refresh_token",
                                                                                                @"client_info":rawClientInfo
                                                                                                }
                                                                                        error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testVerifyResponse_whenOAuthErrorViaAuthCode_shouldReturnError
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];

    MSIDB2CTokenResponse *response = [[MSIDB2CTokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"}
                                                                                    error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidGrant);
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
}

- (void)testVerifyResponse_whenNoClientInfo_shouldReturnError
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];

    MSIDB2CTokenResponse *response = [[MSIDB2CTokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                            @"refresh_token":@"fake_refresh_token"}
                                                                                        error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Client info was not returned in the server response");
}

#pragma mark - Tokens

- (MSIDB2CTokenResponse *)testB2CTokenResponseWithTenantId:(NSString *)tenantId
{
    return [self testB2CTokenResponseWithTenantId:tenantId utid:nil];
}

- (MSIDB2CTokenResponse *)testB2CTokenResponseWithTenantId:(NSString *)tenantId
                                                      utid:(NSString *)utid
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:nil
                                                                  subject:@"sub"
                                                                givenName:@"name"
                                                               familyName:@"family"
                                                                     name:@"name"
                                                                  version:@"2.0"
                                                                      tid:tenantId];

    NSDictionary *responseDictionary = @{@"access_token":DEFAULT_TEST_ACCESS_TOKEN,
                                         @"refresh_token":DEFAULT_TEST_REFRESH_TOKEN,
                                         @"scope": DEFAULT_TEST_SCOPE,
                                         @"id_token": idToken,
                                         @"client_info": [@{ @"uid" : @"1", @"utid" : utid ? utid : @"1234-5678-90abcdefg"} msidBase64UrlJson]
                                         };

    MSIDB2CTokenResponse *response = [[MSIDB2CTokenResponse alloc] initWithJSONDictionary:responseDictionary error:nil];
    return response;
}

- (void)testAccessTokenFromResponse_whenB2CTokenResponse_withTenantId_shouldReturnToken
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];

    MSIDB2CTokenResponse *response = [self testB2CTokenResponseWithTenantId:@"test_tenantid" utid:@"1234-5678-90abcdefg"];
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithB2CAuthority:@"https://login.microsoftonline.com/tfp/test_tenantid/policy"
                                                                                   clientId:DEFAULT_TEST_CLIENT_ID
                                                                                redirectUri:nil
                                                                                     target:DEFAULT_TEST_SCOPE];

    MSIDAccessToken *token = [factory accessTokenFromResponse:response configuration:configuration];

    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"1234-5678-90abcdefg");
    XCTAssertEqualObjects(token.clientId, configuration.clientId);

    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil];

    XCTAssertEqualObjects(token.scopes, scopes);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testAccessTokenFromResponse_whenB2CTokenResponse_withNilTenantId_shouldReturnToken
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];

    MSIDB2CTokenResponse *response = [self testB2CTokenResponseWithTenantId:nil];
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithB2CAuthority:@"https://login.microsoftonline.com/tfp/1234-5678-90abcdefg/policy"
                                                                                   clientId:DEFAULT_TEST_CLIENT_ID
                                                                                redirectUri:nil
                                                                                     target:DEFAULT_TEST_SCOPE];

    MSIDAccessToken *token = [factory accessTokenFromResponse:response configuration:configuration];

    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"1234-5678-90abcdefg");
    XCTAssertEqualObjects(token.clientId, configuration.clientId);

    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNotNil(token.cachedAt);
    XCTAssertEqualObjects(token.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil];

    XCTAssertEqualObjects(token.scopes, scopes);
    XCTAssertNotNil(token.expiresOn);
}

- (void)testRefreshTokenFromResponse_whenB2CTokenResponse_withTenantId_shouldReturnToken
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];

    MSIDB2CTokenResponse *response = [self testB2CTokenResponseWithTenantId:@"test_tenantid"];
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithB2CAuthority:@"https://login.microsoftonline.com/tfp/test_tenantid/policy"
                                                                                   clientId:DEFAULT_TEST_CLIENT_ID
                                                                                redirectUri:nil
                                                                                     target:DEFAULT_TEST_SCOPE];

    MSIDRefreshToken *token = [factory refreshTokenFromResponse:response configuration:configuration];

    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"1234-5678-90abcdefg");
    XCTAssertEqualObjects(token.clientId, configuration.clientId);

    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertNil(token.familyId);
}

- (void)testIDTokenFromResponse_whenB2CTokenResponse_withTenantId_shouldReturnToken
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];

    MSIDB2CTokenResponse *response = [self testB2CTokenResponseWithTenantId:@"test_tenantid" utid:@"1234-5678-90abcdefg"];
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithB2CAuthority:@"https://login.microsoftonline.com/tfp/test_tenantid/policy"
                                                                                   clientId:DEFAULT_TEST_CLIENT_ID
                                                                                redirectUri:nil
                                                                                     target:DEFAULT_TEST_SCOPE];

    MSIDIdToken *token = [factory idTokenFromResponse:response configuration:configuration];

    XCTAssertEqualObjects(token.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(token.realm, @"1234-5678-90abcdefg");
    XCTAssertEqualObjects(token.clientId, configuration.clientId);

    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(token.accountIdentifier.homeAccountId, homeAccountId);

    XCTAssertNil(token.additionalServerInfo);
    XCTAssertEqualObjects(token.rawIdToken, response.idToken);
}

- (void)testAccountFromTokenResponse_whenB2CTokenResponse_withTenantId_shouldInitAccountAndSetProperties
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];

    MSIDB2CTokenResponse *response = [self testB2CTokenResponseWithTenantId:@"test_tenantid" utid:@"1234-5678-90abcdefg"];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration configurationWithB2CAuthority:@"https://login.microsoftonline.com/tfp/test_tenantid/policy"
                                                                                   clientId:@"client id"
                                                                                redirectUri:@"redirect uri"
                                                                                     target:@"target"];

    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertNotNil(account.clientInfo);
    XCTAssertEqual(account.accountType, MSIDAccountTypeMSSTS);
    XCTAssertEqualObjects(account.username, @"Missing from the token response");
    XCTAssertEqualObjects(account.givenName, @"name");
    XCTAssertEqualObjects(account.familyName, @"family");
    XCTAssertEqualObjects(account.name, @"name");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.realm, @"1234-5678-90abcdefg");
}


@end
