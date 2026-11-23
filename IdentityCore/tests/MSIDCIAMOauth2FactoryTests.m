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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  

#import <XCTest/XCTest.h>
#import "MSIDCIAMTokenResponse.h"
#import "MSIDCIAMOauth2Factory.h"
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
#import "MSIDConfiguration.h"
#import "MSIDAuthority.h"
#import "NSString+MSIDTestUtil.h"

@interface MSIDCIAMOauth2FactoryTests :  XCTestCase

@end

@implementation MSIDCIAMOauth2FactoryTests

#pragma mark - Token response

- (void)testTokenResponseFromJSON_whenNilJSON_shouldReturnError
{
    MSIDCIAMOauth2Factory *factory = [MSIDCIAMOauth2Factory new];

    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:nil context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testTokenResponseFromJSON_whenValidJSON_shouldReturnCIAMTokenResponse
{
    NSDictionary *tokenResponse = @{@"access_token": @"access token",
                                    @"refresh_token": @"refresh token"
                                    };

    MSIDCIAMOauth2Factory *factory = [MSIDCIAMOauth2Factory new];

    NSError *error = nil;
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:tokenResponse context:nil error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    BOOL expectedClass = [response isKindOfClass:[MSIDCIAMTokenResponse class]];
    XCTAssertTrue(expectedClass);
    XCTAssertEqualObjects(response.accessToken, @"access token");
    XCTAssertEqualObjects(response.refreshToken, @"refresh token");
}

#pragma mark - Verify response

- (void)testVerifyResponse_whenWrongResponseProvided_shouldReturnError
{
    MSIDCIAMOauth2Factory *factory = [MSIDCIAMOauth2Factory new];
    MSIDAADV1TokenResponse *response = [MSIDAADV1TokenResponse new];

    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testVerifyResponse_whenValidResponseWithTokens_shouldReturnNoError
{
    MSIDCIAMOauth2Factory *factory = [MSIDCIAMOauth2Factory new];

    NSString *rawClientInfo = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    MSIDCIAMTokenResponse *response = [[MSIDCIAMTokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
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
    MSIDCIAMOauth2Factory *factory = [MSIDCIAMOauth2Factory new];

    MSIDCIAMTokenResponse *response = [[MSIDCIAMTokenResponse alloc] initWithJSONDictionary:@{@"error":@"invalid_grant"}
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
    MSIDCIAMOauth2Factory *factory = [MSIDCIAMOauth2Factory new];

    MSIDCIAMTokenResponse *response = [[MSIDCIAMTokenResponse alloc] initWithJSONDictionary:@{@"access_token":@"fake_access_token",
                                                                                            @"refresh_token":@"fake_refresh_token"}
                                                                                        error:nil];
    NSError *error = nil;
    BOOL result = [factory verifyResponse:response context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Client info was not returned in the server response");
}

#pragma mark - Result authority

- (MSIDConfiguration *)ciamConfiguration
{
    return [[MSIDConfiguration alloc] initWithAuthority:[@"https://contoso.ciamlogin.com/ciam-tenant-id" ciamAuthority]
                                            redirectUri:@"redirect uri"
                                               clientId:@"client id"
                                                 target:@"target"];
}

- (MSIDCIAMTokenResponse *)responseWithHomeTenant:(NSString *)homeTenant idTokenTenant:(NSString *)idTokenTenant
{
    NSMutableDictionary *json = [@{@"access_token": @"fake_access_token",
                                   @"refresh_token": @"fake_refresh_token",
                                   @"client_info": [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : homeTenant} msidBase64UrlJson]} mutableCopy];
    if (idTokenTenant)
    {
        json[@"id_token"] = [MSIDTestIdTokenUtil idTokenWithName:@"Test" preferredUsername:@"user@contoso.com" oid:@"oid" tenantId:idTokenTenant];
    }
    return [[MSIDCIAMTokenResponse alloc] initWithJSONDictionary:json error:nil];
}

- (void)testResultAuthority_whenHomeTenantDiffersFromTokenTenant_shouldUseIdTokenTenant
{
    // A guest or a user federated from another Entra tenant: client_info.utid is the home tenant.
    MSIDCIAMOauth2Factory *factory = [MSIDCIAMOauth2Factory new];
    MSIDCIAMTokenResponse *response = [self responseWithHomeTenant:@"home-tenant-id" idTokenTenant:@"ciam-tenant-id"];

    NSError *error = nil;
    MSIDAuthority *authority = [factory resultAuthorityWithConfiguration:[self ciamConfiguration] tokenResponse:response error:&error];

    XCTAssertNil(error);
    XCTAssertEqualObjects(authority.url.absoluteString, @"https://contoso.ciamlogin.com/ciam-tenant-id");
    XCTAssertEqualObjects(authority.realm, @"ciam-tenant-id");
}

- (void)testResultAuthority_whenNativeUser_shouldUseCIAMTenant
{
    MSIDCIAMOauth2Factory *factory = [MSIDCIAMOauth2Factory new];
    MSIDCIAMTokenResponse *response = [self responseWithHomeTenant:@"ciam-tenant-id" idTokenTenant:@"ciam-tenant-id"];

    NSError *error = nil;
    MSIDAuthority *authority = [factory resultAuthorityWithConfiguration:[self ciamConfiguration] tokenResponse:response error:&error];

    XCTAssertNil(error);
    XCTAssertEqualObjects(authority.url.absoluteString, @"https://contoso.ciamlogin.com/ciam-tenant-id");
}

- (void)testResultAuthority_whenNoIdToken_shouldReturnConfiguredAuthority
{
    MSIDCIAMOauth2Factory *factory = [MSIDCIAMOauth2Factory new];
    MSIDCIAMTokenResponse *response = [self responseWithHomeTenant:@"home-tenant-id" idTokenTenant:nil];
    MSIDConfiguration *configuration = [self ciamConfiguration];

    NSError *error = nil;
    MSIDAuthority *authority = [factory resultAuthorityWithConfiguration:configuration tokenResponse:response error:&error];

    XCTAssertNil(error);
    XCTAssertEqualObjects(authority.url, configuration.authority.url);
}

@end
