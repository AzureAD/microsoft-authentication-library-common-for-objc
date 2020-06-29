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
#import "MSIDAADV1TokenResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDTestIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDAADV1TokenResponseTests : XCTestCase

@end

@implementation MSIDAADV1TokenResponseTests

- (void)testIsMultiResource_whenResourceAndRTPresent_shouldReturnYes
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"refresh_token": @"rt",
                                @"resource": @"resource"
                                };
    
    NSError *error = nil;
    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    BOOL result = [response isMultiResource];
    XCTAssertTrue(result);
}

- (void)testIsMultiResource_whenResourceMissingAndRTPresent_shouldReturnNO
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"refresh_token": @"rt",
                                };
    
    NSError *error = nil;
    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    BOOL result = [response isMultiResource];
    XCTAssertFalse(result);
}

- (void)testIsMultiResource_whenResourcePresentAndRTMissing_shouldReturnNO
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"resource": @"resource",
                                };
    
    NSError *error = nil;
    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    BOOL result = [response isMultiResource];
    XCTAssertFalse(result);
}

- (void)testIsMultiResource_whenResourceMissingAndRTMissing_shouldReturnNO
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                };
    
    NSError *error = nil;
    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    BOOL result = [response isMultiResource];
    XCTAssertFalse(result);
}

- (void)testJsonDictionary_whenAllPropertiesSetForSuccessResponse_shouldReturnJson
{
    __auto_type tokenResponse = [MSIDAADV1TokenResponse new];
    tokenResponse.expiresIn = 300;
    tokenResponse.expiresOn = 1575635662;
    tokenResponse.accessToken = @"access_token";
    tokenResponse.refreshToken = @"refresh_token";
    tokenResponse.tokenType = MSID_OAUTH2_BEARER;
    tokenResponse.resource = @"https://contoso.com";
    tokenResponse.state = @"state 1";
    tokenResponse.additionalServerInfo = @{@"k": @"v"};
    tokenResponse.clientAppVersion = @"1.0";
    tokenResponse.idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                      subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    tokenResponse.correlationId = @"00000000-0000-0000-0000-000000000001";
    tokenResponse.extendedExpiresIn = 500;
    tokenResponse.extendedExpiresOn = 1585635662;
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    tokenResponse.clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
    tokenResponse.familyId = @"family 1";
    tokenResponse.additionalUserId = @"user@contoso.com";
    tokenResponse.speInfo = @"spe info";
    
    NSDictionary *json = [tokenResponse jsonDictionary];
    
    XCTAssertEqual(18, json.allKeys.count);
    XCTAssertEqualObjects(json[@"access_token"], @"access_token");
    XCTAssertEqualObjects(json[@"refresh_token"], @"refresh_token");
    XCTAssertEqualObjects(json[@"adi"], @"user@contoso.com");
    XCTAssertEqualObjects(json[@"client_app_version"], @"1.0");
    XCTAssertEqualObjects(json[@"client_info"], @"eyJ1aWQiOiIxIiwidXRpZCI6IjEyMzQtNTY3OC05MGFiY2RlZmcifQ");
    XCTAssertEqualObjects(json[@"correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertEqualObjects(json[@"expires_in"], @"300");
    XCTAssertEqualObjects(json[@"expires_on"], @"1575635662");
    XCTAssertEqualObjects(json[@"ext_expires_in"], @"500");
    XCTAssertEqualObjects(json[@"ext_expires_on"], @"1585635662");
    XCTAssertEqualObjects(json[@"foci"], @"family 1");
    XCTAssertEqualObjects(json[@"id_token"], @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ.eyJpc3MiOiJpc3N1ZXIiLCJuYW1lIjoiVGVzdCBuYW1lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBjb250b3NvLmNvbSIsInN1YiI6InN1YiJ9.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9raWRfdmFsdWUifQ");
    XCTAssertEqualObjects(json[@"provider_type"], @"provider_aad_v1");
    XCTAssertEqualObjects(json[@"resource"], @"https://contoso.com");
    XCTAssertEqualObjects(json[@"token_type"], @"Bearer");
    XCTAssertEqualObjects(json[@"k"], @"v");
    XCTAssertEqualObjects(json[@"state"], @"state 1");
    XCTAssertEqualObjects(json[@"spe_info"], @"spe info");
}

- (void)testJsonDictionary_whenAllPropertiesSetForErrorResponse_shouldReturnJson
{
    __auto_type tokenResponse = [MSIDAADV1TokenResponse new];
    tokenResponse.error = @"unauthorized_client";
    tokenResponse.errorDescription = @"AADSTS53005: Application needs to enforce Intune protection policies. Trace ID: 0ec6f651-1b0f-4147-8461-c8ecfb9c0400 Correlation ID: e6317b1d-726e-4d63-a824-d530336101e6 Timestamp: 2019-11-28 00:13:53Z";
    tokenResponse.state = @"state 1";
    tokenResponse.additionalServerInfo = @{@"k": @"v"};
    tokenResponse.clientAppVersion = @"1.0";
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    tokenResponse.clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
    tokenResponse.additionalUserId = @"user@contoso.com";
    
    NSDictionary *json = [tokenResponse jsonDictionary];
    
    XCTAssertEqual(8, json.allKeys.count);
    XCTAssertEqualObjects(json[@"error"], @"unauthorized_client");
    XCTAssertEqualObjects(json[@"error_description"], @"AADSTS53005%3A%20Application%20needs%20to%20enforce%20Intune%20protection%20policies.%20Trace%20ID%3A%200ec6f651-1b0f-4147-8461-c8ecfb9c0400%20Correlation%20ID%3A%20e6317b1d-726e-4d63-a824-d530336101e6%20Timestamp%3A%202019-11-28%2000%3A13%3A53Z");
    XCTAssertEqualObjects(json[@"client_app_version"], @"1.0");
    XCTAssertEqualObjects(json[@"k"], @"v");
    XCTAssertEqualObjects(json[@"state"], @"state 1");
    XCTAssertEqualObjects(json[@"adi"], @"user@contoso.com");
    XCTAssertEqualObjects(json[@"client_info"], @"eyJ1aWQiOiIxIiwidXRpZCI6IjEyMzQtNTY3OC05MGFiY2RlZmcifQ");
}

@end
