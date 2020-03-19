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
#import "MSIDTokenResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDRefreshToken.h"
#import "MSIDTestIdentifiers.h"

@interface MSIDTestTokenResponseStub : MSIDTokenResponse

@end

@implementation MSIDTestTokenResponseStub

+ (MSIDProviderType)providerType
{
    return MSIDProviderTypeAADV2;
}

@end

@interface MSIDTokenResponseTests : XCTestCase

@end

@implementation MSIDTokenResponseTests

- (void)testExpiresIn_whenStringExpiresIn_shouldReturnValue
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSInteger expiresIn = [response expiresIn];
    XCTAssertEqual(expiresIn, 3600);
}

- (void)testExpiresIn_whenNumberExpiresIn_shouldReturnValue
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @3600,
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSInteger expiresIn = [response expiresIn];
    XCTAssertEqual(expiresIn, 3600);
}

- (void)testExpiryDate_whenExpiresInAvailable_shouldReturnDate
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @3600,
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSDate *expiryDate = [response expiryDate];
    XCTAssertNotNil(expiryDate);
}

- (void)testExpiryDate_whenExpiresInNotAvailable_shouldReturnNil
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSDate *expiryDate = [response expiryDate];
    XCTAssertNil(expiryDate);
}

- (void)testExpiryDate_whenExpiresOnOnly_shouldReturnDate
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_on": @"1538804860",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSDate *expiryDate = [response expiryDate];
    XCTAssertEqual(expiryDate.timeIntervalSince1970, 1538804860);
}

- (void)testExpiryDate_whenExpiresOnAndExpiresIn_shouldReturnExpiresOnDate
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_on": @"1538804860",
                                @"expires_in": @"10",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSDate *expiryDate = [response expiryDate];
    XCTAssertEqual(expiryDate.timeIntervalSince1970, 1538804860);
}

- (void)testIdTokenObj_whenIdTokenAvailable_shouldReturnIDToken
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"test" upn:@"upn" oid:nil tenantId:@"tenant"];
    
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"id_token": idToken,
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    MSIDIdTokenClaims *idTokenObj = response.idTokenObj;
    XCTAssertNotNil(idTokenObj);
    XCTAssertEqualObjects(idTokenObj.rawIdToken, idToken);
}

- (void)testIdTokenObj_whenIdTokenAvailableButCorrupted_shouldReturnNil
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"id_token": @"id token",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    MSIDIdTokenClaims *idTokenObj = response.idTokenObj;
    XCTAssertNil(idTokenObj);
}

- (void)testIdTokenObj_whenIdTokenNotAvailable_shouldReturnNil
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    MSIDIdTokenClaims *idTokenObj = response.idTokenObj;
    XCTAssertNil(idTokenObj);
}

#pragma mark - Refresh token

- (void)testInitWithJson_andNilRefreshToken_shouldNotTakeFieldsFromRefreshToken
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput
                                                                       refreshToken:nil
                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertNil(response.idToken);
}

- (void)testInitWithJson_andRefreshToken_shouldNotTakeFieldsFromRefreshTokenAndUpdate
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"refresh_token": @"rt",
                                @"id_token": @"id token 2"
                                };
    
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    refreshToken.refreshToken = @"rt";

    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput
                                                                       refreshToken:refreshToken
                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.idToken, @"id token 2");
}

- (void)testInitWithJSONDictionary_whenErrorDescriptionNotUrlEncoded_shouldParseIt
{
    NSDictionary *jsonInput = @{@"error": @"error_code",
                                @"error_description": @"some description"
    };
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.error, @"error_code");
    XCTAssertEqualObjects(response.errorDescription, @"some description");
}

- (void)testInitWithJSONDictionary_whenErrorDescriptionUrlEncoded_shouldParseIt
{
    NSDictionary *jsonInput = @{@"error": @"error_code",
                                @"error_description": @"AADSTS650052%3A%2BThe%2Bapp%2Bneeds%2Baccess%2Bto%2Ba%2Bservice."
    };
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.error, @"error_code");
    XCTAssertEqualObjects(response.errorDescription, @"AADSTS650052:+The+app+needs+access+to+a+service.");
}

- (void)testJsonDictionary_whenAllPropertiesSetForSuccessResponse_shouldReturnJson
{
    __auto_type tokenResponse = [MSIDTestTokenResponseStub new];
    tokenResponse.expiresIn = 300;
    tokenResponse.expiresOn = 1575635662;
    tokenResponse.accessToken = @"access_token";
    tokenResponse.refreshToken = @"refresh_token";
    tokenResponse.tokenType = MSID_OAUTH2_BEARER;
    tokenResponse.scope = @"scope 1";
    tokenResponse.state = @"state 1";
    tokenResponse.additionalServerInfo = @{@"k": @"v"};
    tokenResponse.clientAppVersion = @"1.0";
    tokenResponse.idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                      subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    
    NSDictionary *json = [tokenResponse jsonDictionary];
    
    XCTAssertEqual(11, json.allKeys.count);
    XCTAssertEqualObjects(json[@"access_token"], @"access_token");
    XCTAssertEqualObjects(json[@"client_app_version"], @"1.0");
    XCTAssertEqualObjects(json[@"expires_in"], @"300");
    XCTAssertEqualObjects(json[@"expires_on"], @"1575635662");
    XCTAssertEqualObjects(json[@"id_token"], @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ");
    XCTAssertEqualObjects(json[@"provider_type"], @"provider_aad_v2");
    XCTAssertEqualObjects(json[@"scope"], @"scope 1");
    XCTAssertEqualObjects(json[@"token_type"], @"Bearer");
    XCTAssertEqualObjects(json[@"k"], @"v");
    XCTAssertEqualObjects(json[@"state"], @"state 1");
}

- (void)testJsonDictionary_whenAllPropertiesSetForErrorResponse_shouldReturnJson
{
    __auto_type tokenResponse = [MSIDTestTokenResponseStub new];
    tokenResponse.error = @"unauthorized_client";
    tokenResponse.errorDescription = @"AADSTS53005: Application needs to enforce Intune protection policies. Trace ID: 0ec6f651-1b0f-4147-8461-c8ecfb9c0400 Correlation ID: e6317b1d-726e-4d63-a824-d530336101e6 Timestamp: 2019-11-28 00:13:53Z";
    tokenResponse.state = @"state 1";
    tokenResponse.additionalServerInfo = @{@"k": @"v"};
    tokenResponse.clientAppVersion = @"1.0";
    
    NSDictionary *json = [tokenResponse jsonDictionary];
    
    XCTAssertEqual(6, json.allKeys.count);
    XCTAssertEqualObjects(json[@"error"], @"unauthorized_client");
    XCTAssertEqualObjects(json[@"error_description"], @"AADSTS53005%3A%20Application%20needs%20to%20enforce%20Intune%20protection%20policies.%20Trace%20ID%3A%200ec6f651-1b0f-4147-8461-c8ecfb9c0400%20Correlation%20ID%3A%20e6317b1d-726e-4d63-a824-d530336101e6%20Timestamp%3A%202019-11-28%2000%3A13%3A53Z");
    XCTAssertEqualObjects(json[@"client_app_version"], @"1.0");
    XCTAssertEqualObjects(json[@"k"], @"v");
    XCTAssertEqualObjects(json[@"state"], @"state 1");
}

@end
