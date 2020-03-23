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

#if MSID_ENABLE_SSO_EXTENSION
#import <XCTest/XCTest.h>
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDAADAuthority.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDDeviceInfo.h"

@interface MSIDBrokerOperationTokenResponseTests : XCTestCase

@end

@implementation MSIDBrokerOperationTokenResponseTests

- (void)testIsSubclassOfOperationTokenRequest_shouldReturnTrue
{
    XCTAssertTrue([MSIDBrokerOperationTokenResponse.class isSubclassOfClass:MSIDBrokerOperationResponse.class]);
}

- (void)testJsonDictionary_whenAllPropertiesSetForSuccessResponse_shouldReturnJson
{
    __auto_type tokenResponse = [MSIDAADV2TokenResponse new];
    tokenResponse.accessToken = @"access_token";
    tokenResponse.scope = @"scope 1";
    tokenResponse.expiresIn = 300;
    tokenResponse.tokenType = MSID_OAUTH2_BEARER;
    tokenResponse.idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                      subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.operation = @"login";
    response.success = true;
    response.clientAppVersion = @"1.0";
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    response.authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:nil context:nil error:nil];
    response.tokenResponse = tokenResponse;
    response.additionalTokenResponse = tokenResponse;
    
    NSDictionary *json = [response jsonDictionary];
    
    XCTAssertEqual(18, json.allKeys.count);
    XCTAssertEqualObjects(json[@"access_token"], @"access_token");
    XCTAssertEqualObjects(json[@"authority"], @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(json[@"client_app_version"], @"1.0");
    XCTAssertEqualObjects(json[@"expires_in"], @"300");
    XCTAssertEqualObjects(json[@"expires_on"], @"0");
    XCTAssertEqualObjects(json[@"ext_expires_in"], @"0");
    XCTAssertEqualObjects(json[@"ext_expires_on"], @"0");
    XCTAssertEqualObjects(json[@"id_token"], @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ");
    XCTAssertEqualObjects(json[@"operation"], @"login");
    XCTAssertEqualObjects(json[@"operation_response_type"], @"operation_token_response");
    XCTAssertEqualObjects(json[@"provider_type"], @"provider_aad_v2");
    XCTAssertEqualObjects(json[@"scope"], @"scope 1");
    XCTAssertEqualObjects(json[@"success"], @"1");
    XCTAssertEqualObjects(json[@"token_type"], @"Bearer");
    XCTAssertEqualObjects(json[@"additional_token_reponse"], @"{\"token_type\":\"Bearer\",\"scope\":\"scope 1\",\"ext_expires_in\":\"0\",\"provider_type\":\"provider_aad_v2\",\"ext_expires_on\":\"0\",\"expires_on\":\"0\",\"id_token\":\"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ\",\"access_token\":\"access_token\",\"expires_in\":\"300\"}");
    XCTAssertEqualObjects(json[@"device_mode"], @"personal");
    XCTAssertEqualObjects(json[@"sso_extension_mode"], @"full");
    XCTAssertEqualObjects(json[@"wpj_status"], @"notJoined");
}

- (void)testJsonDictionary_whenNoAdditionalTokenResponseForSuccessResponse_shouldReturnJson
{
    __auto_type tokenResponse = [MSIDAADV2TokenResponse new];
    tokenResponse.accessToken = @"access_token";
    tokenResponse.scope = @"scope 1";
    tokenResponse.expiresIn = 300;
    tokenResponse.tokenType = MSID_OAUTH2_BEARER;
    tokenResponse.idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                      subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.operation = @"login";
    response.success = true;
    response.clientAppVersion = @"1.0";
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    response.authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:nil context:nil error:nil];
    response.tokenResponse = tokenResponse;
    
    NSDictionary *json = [response jsonDictionary];
    
    XCTAssertEqual(17, json.allKeys.count);
    XCTAssertEqualObjects(json[@"access_token"], @"access_token");
    XCTAssertEqualObjects(json[@"authority"], @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(json[@"client_app_version"], @"1.0");
    XCTAssertEqualObjects(json[@"expires_in"], @"300");
    XCTAssertEqualObjects(json[@"ext_expires_in"], @"0");
    XCTAssertEqualObjects(json[@"ext_expires_on"], @"0");
    XCTAssertEqualObjects(json[@"id_token"], @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ");
    XCTAssertEqualObjects(json[@"operation"], @"login");
    XCTAssertEqualObjects(json[@"operation_response_type"], @"operation_token_response");
    XCTAssertEqualObjects(json[@"provider_type"], @"provider_aad_v2");
    XCTAssertEqualObjects(json[@"scope"], @"scope 1");
    XCTAssertEqualObjects(json[@"success"], @"1");
    XCTAssertEqualObjects(json[@"token_type"], @"Bearer");
}

- (void)testJsonDictionary_whenNoAuthorityForSuccessResponse_shouldReturnNil
{
    __auto_type tokenResponse = [MSIDAADV2TokenResponse new];
    tokenResponse.accessToken = @"access_token";
    tokenResponse.scope = @"scope 1";
    tokenResponse.expiresIn = 300;
    tokenResponse.tokenType = MSID_OAUTH2_BEARER;
    tokenResponse.idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                      subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.operation = @"login";
    response.success = true;
    response.clientAppVersion = @"1.0";
    response.tokenResponse = tokenResponse;
    
    NSDictionary *json = [response jsonDictionary];
    
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenNoTokenResponseForSuccessResponse_shouldReturnNil
{
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.operation = @"login";
    response.success = true;
    response.clientAppVersion = @"1.0";
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    response.authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:nil context:nil error:nil];
    
    NSDictionary *json = [response jsonDictionary];
    
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenNoAuthorityForFailureResponse_shouldReturnJson
{
    __auto_type tokenResponse = [MSIDAADV2TokenResponse new];
    tokenResponse.accessToken = @"access_token";
    tokenResponse.scope = @"scope 1";
    tokenResponse.expiresIn = 300;
    tokenResponse.tokenType = MSID_OAUTH2_BEARER;
    tokenResponse.idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                      subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.operation = @"login";
    response.success = NO;
    response.clientAppVersion = @"1.0";
    response.tokenResponse = tokenResponse;
    response.additionalTokenResponse = tokenResponse;
    
    NSDictionary *json = [response jsonDictionary];
    
    XCTAssertEqual(17, json.allKeys.count);
    XCTAssertEqualObjects(json[@"access_token"], @"access_token");
    XCTAssertEqualObjects(json[@"client_app_version"], @"1.0");
    XCTAssertEqualObjects(json[@"expires_in"], @"300");
    XCTAssertEqualObjects(json[@"ext_expires_in"], @"0");
    XCTAssertEqualObjects(json[@"ext_expires_on"], @"0");
    XCTAssertEqualObjects(json[@"id_token"], @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ");
    XCTAssertEqualObjects(json[@"operation"], @"login");
    XCTAssertEqualObjects(json[@"operation_response_type"], @"operation_token_response");
    XCTAssertEqualObjects(json[@"provider_type"], @"provider_aad_v2");
    XCTAssertEqualObjects(json[@"scope"], @"scope 1");
    XCTAssertEqualObjects(json[@"success"], @"0");
    XCTAssertEqualObjects(json[@"token_type"], @"Bearer");
    XCTAssertEqualObjects(json[@"additional_token_reponse"], @"{\"token_type\":\"Bearer\",\"scope\":\"scope 1\",\"ext_expires_in\":\"0\",\"provider_type\":\"provider_aad_v2\",\"ext_expires_on\":\"0\",\"expires_on\":\"0\",\"id_token\":\"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ\",\"access_token\":\"access_token\",\"expires_in\":\"300\"}");
}

- (void)testJsonDictionary_whenNoAdditionalTokenResponseForFailureResponse_shouldReturnJson
{
    __auto_type tokenResponse = [MSIDAADV2TokenResponse new];
    tokenResponse.accessToken = @"access_token";
    tokenResponse.scope = @"scope 1";
    tokenResponse.expiresIn = 300;
    tokenResponse.tokenType = MSID_OAUTH2_BEARER;
    tokenResponse.idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                      subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.operation = @"login";
    response.success = NO;
    response.clientAppVersion = @"1.0";
    response.tokenResponse = tokenResponse;
    
    NSDictionary *json = [response jsonDictionary];
    
    XCTAssertEqual(16, json.allKeys.count);
    XCTAssertEqualObjects(json[@"access_token"], @"access_token");
    XCTAssertEqualObjects(json[@"client_app_version"], @"1.0");
    XCTAssertEqualObjects(json[@"expires_in"], @"300");
    XCTAssertEqualObjects(json[@"ext_expires_in"], @"0");
    XCTAssertEqualObjects(json[@"ext_expires_on"], @"0");
    XCTAssertEqualObjects(json[@"id_token"], @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ");
    XCTAssertEqualObjects(json[@"operation"], @"login");
    XCTAssertEqualObjects(json[@"operation_response_type"], @"operation_token_response");
    XCTAssertEqualObjects(json[@"provider_type"], @"provider_aad_v2");
    XCTAssertEqualObjects(json[@"scope"], @"scope 1");
    XCTAssertEqualObjects(json[@"success"], @"0");
    XCTAssertEqualObjects(json[@"token_type"], @"Bearer");
}

- (void)testJsonDictionary_whenNoTokenResponseForFailureResponse_shouldReturnNil
{
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:[MSIDDeviceInfo new]];
    response.operation = @"login";
    response.success = NO;
    response.clientAppVersion = @"1.0";
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    response.authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:nil context:nil error:nil];
    
    NSDictionary *json = [response jsonDictionary];
    
    XCTAssertNil(json);
}

- (void)testInitWithJSONDictionary_whenAllPropertiesForSuccessResponse_shouldInitResponse
{
    NSDictionary *json = @{
        @"access_token": @"access_token",
        @"authority": @"https://login.microsoftonline.com/common",
        @"client_app_version": @"1.0",
        @"expires_in": @"300",
        @"id_token": @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ",
        @"operation": @"login",
        @"operation_response_type": @"operation_token_response",
        @"provider_type": @"provider_aad_v2",
        @"scope": @"scope 1",
        @"success": @"1",
        @"token_type": @"Bearer",
        @"additional_token_reponse": @"{\"token_type\":\"Bearer\",\"scope\":\"scope 1\",\"ext_expires_in\":\"0\",\"provider_type\":\"provider_aad_v2\",\"ext_expires_on\":\"0\",\"expires_on\":\"0\",\"id_token\":\"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ\",\"access_token\":\"access_token\",\"expires_in\":\"300\"}",
        @"device_mode": @"personal",
        @"wpj_status": @"notJoined",
        @"broker_version": @"1.2"
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/common", response.authority.url.absoluteString);
    XCTAssertNotNil(response.tokenResponse);
    XCTAssertNotNil(response.additionalTokenResponse);
    XCTAssertTrue(response.success);
    XCTAssertEqual(@"1.2", response.deviceInfo.brokerVersion);
    XCTAssertEqual(MSIDDeviceModePersonal, response.deviceInfo.deviceMode);
    XCTAssertEqual(MSIDWorkPlaceJoinStatusNotJoined, response.deviceInfo.wpjStatus);
}

- (void)testInitWithJSONDictionary_whenNoAdditionalTokenResponseForSuccessResponse_shouldInitResponse
{
    NSDictionary *json = @{
        @"access_token": @"access_token",
        @"authority": @"https://login.microsoftonline.com/common",
        @"client_app_version": @"1.0",
        @"expires_in": @"300",
        @"id_token": @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ",
        @"operation": @"login",
        @"operation_response_type": @"operation_token_response",
        @"provider_type": @"provider_aad_v2",
        @"scope": @"scope 1",
        @"success": @"1",
        @"token_type": @"Bearer",
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/common", response.authority.url.absoluteString);
    XCTAssertNotNil(response.tokenResponse);
    XCTAssertNil(response.additionalTokenResponse);
    XCTAssertTrue(response.success);
}

- (void)testInitWithJSONDictionary_whenNoAuthorityForSuccessResponse_shouldReturnError
{
    NSDictionary *json = @{
        @"access_token": @"access_token",
        @"client_app_version": @"1.0",
        @"expires_in": @"300",
        @"id_token": @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ",
        @"operation": @"login",
        @"operation_response_type": @"operation_token_response",
        @"provider_type": @"provider_aad_v2",
        @"scope": @"scope 1",
        @"success": @"1",
        @"token_type": @"Bearer",
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Failed to init MSIDAADAuthority from json: authority is either nil or not a url.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitWithJSONDictionary_whenNoProviderTypeForSuccessResponse_shouldReturnError
{
    NSDictionary *json = @{
        @"access_token": @"access_token",
        @"client_app_version": @"1.0",
        @"expires_in": @"300",
        @"id_token": @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ",
        @"operation": @"login",
        @"operation_response_type": @"operation_token_response",
        @"scope": @"scope 1",
        @"success": @"1",
        @"token_type": @"Bearer",
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"provider_type key is missing in dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitWithJSONDictionary_whenAllPropertiesForFailureResponse_shouldInitResponse
{
    NSDictionary *json = @{
        @"client_app_version": @"1.0",
        @"operation": @"login",
        @"operation_response_type": @"operation_token_response",
        @"provider_type": @"provider_aad_v2",
        @"error": @"invalid_grant",
        @"success": @"0",
        @"additional_token_reponse": @"{\"token_type\":\"Bearer\",\"scope\":\"scope 1\",\"ext_expires_in\":\"0\",\"provider_type\":\"provider_aad_v2\",\"ext_expires_on\":\"0\",\"expires_on\":\"0\",\"id_token\":\"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ\",\"access_token\":\"access_token\",\"expires_in\":\"300\"}",
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertNil(response.authority);
    XCTAssertNotNil(response.tokenResponse);
    XCTAssertEqualObjects(@"invalid_grant", response.tokenResponse.error);
    XCTAssertNotNil(response.additionalTokenResponse);
    XCTAssertFalse(response.success);
}

- (void)testInitWithJSONDictionary_whenNoAdditionalTokenResponseForFailureResponse_shouldInitResponse
{
    NSDictionary *json = @{
        @"client_app_version": @"1.0",
        @"operation": @"login",
        @"operation_response_type": @"operation_token_response",
        @"provider_type": @"provider_aad_v2",
        @"error": @"invalid_grant",
        @"suberror": @"consent_required",
        @"success": @"0",
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertNil(response.authority);
    XCTAssertNotNil(response.tokenResponse);
    XCTAssertEqualObjects(@"invalid_grant", response.tokenResponse.error);
    XCTAssertEqualObjects(@"consent_required", ((MSIDAADTokenResponse *)response.tokenResponse).suberror);
    XCTAssertNil(response.additionalTokenResponse);
    XCTAssertFalse(response.success);
}

- (void)testInitWithJSONDictionary_whenNoProviderTypeForFailureResponse_shouldReturnError
{
    NSDictionary *json = @{
        @"client_app_version": @"1.0",
        @"operation": @"login",
        @"operation_response_type": @"operation_token_response",
        @"error": @"invalid_grant",
        @"success": @"0",
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationTokenResponse alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"provider_type key is missing in dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
}

@end
#endif
