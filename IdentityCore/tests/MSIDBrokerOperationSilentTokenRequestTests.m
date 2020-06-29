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
#import "MSIDBrokerOperationSilentTokenRequest.h"
#import "MSIDConfiguration.h"
#import "MSIDClaimsRequest.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDAADAuthority.h"

@interface MSIDBrokerOperationSilentTokenRequestTests : XCTestCase

@end

@implementation MSIDBrokerOperationSilentTokenRequestTests

- (void)testOperationName_isLogin
{
    XCTAssertEqualObjects(@"refresh", MSIDBrokerOperationSilentTokenRequest.operation);
}

- (void)testIsSubclassOfOperationTokenRequest_shouldReturnTrue
{
    XCTAssertTrue([MSIDBrokerOperationSilentTokenRequest.class isSubclassOfClass:MSIDBrokerOperationTokenRequest.class]);
}

- (void)testInitWithJSONDictionary_whenAllProperties_shouldInitRequest
{
    NSDictionary *json = @{
        @"authority": @"https://login.microsoftonline.com/common",
        @"broker_key": @"broker_key_value",
        @"claims": @"{\"id_token\": {\"given_name\": {\"essential\": true}}}",
        @"client_app_name": @"MSAL Test App",
        @"client_app_version": @"1.0",
        @"client_capabilities": @"cp1,cp2",
        @"client_id": @"client id",
        @"client_version": @"1.0.0",
        @"correlation_id": @"00000000-0000-0000-0000-000000000001",
        @"extra_consent_scopes": @"scope 3",
        @"extra_oidc_scopes": @"profile",
        @"extra_query_param": @"qp1=value1",
        @"home_account_id": DEFAULT_TEST_HOME_ACCOUNT_ID,
        @"instance_aware": @"1",
        @"intune_enrollment_ids": @"{\"enrollment_ids\":[{\"tid\":\"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1\"}]}",
        @"intune_mam_resource": @"{\"login.microsoftonline.com\":\"https:\\/\\/www.microsoft.com\\/intune\",\"login.microsoftonline.de\":\"https:\\/\\/www.microsoft.com\\/intune-de\"}",
        @"msg_protocol_ver": @"99",
        @"provider_type": @"provider_aad_v1",
        @"redirect_uri": @"redirect uri",
        @"scope": @"scope scope2",
        @"username": @"user@contoso.com",
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationSilentTokenRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"broker_key_value", request.brokerKey);
    XCTAssertEqual(99, request.protocolVersion);
    XCTAssertEqualObjects(@"1.0.0", request.clientVersion);
    XCTAssertEqualObjects(@"1.0", request.clientAppVersion);
    XCTAssertEqualObjects(@"MSAL Test App", request.clientAppName);
    XCTAssertEqualObjects(@"00000000-0000-0000-0000-000000000001", request.correlationId.UUIDString);
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/common", request.configuration.authority.url.absoluteString);
    XCTAssertEqualObjects(@"redirect uri", request.configuration.redirectUri);
    XCTAssertEqualObjects(@"client id", request.configuration.clientId);
    XCTAssertEqualObjects(@"scope scope2", request.configuration.target);
    XCTAssertEqual(MSIDProviderTypeAADV1, request.providerType);
    XCTAssertEqualObjects(@"profile", request.oidcScope);
    XCTAssertEqualObjects(@{@"qp1": @"value1"}, request.extraQueryParameters);
    XCTAssertTrue(request.instanceAware);
    __auto_type enrollmentIds = @{ @"enrollment_ids": @[ @{@"tid": @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1"} ]};
    XCTAssertEqualObjects(enrollmentIds, request.enrollmentIds);
    __auto_type mamResources = @{
        @"login.microsoftonline.com": @"https://www.microsoft.com/intune",
        @"login.microsoftonline.de": @"https://www.microsoft.com/intune-de",
    };
    XCTAssertEqualObjects(mamResources, request.mamResources);
    __auto_type clientCapabilities = @[@"cp1", @"cp2"];
    XCTAssertEqualObjects(clientCapabilities, request.clientCapabilities);
    XCTAssertNotNil(request.claimsRequest);
    XCTAssertTrue(request.claimsRequest.hasClaims);
    XCTAssertEqualObjects(DEFAULT_TEST_ID_TOKEN_USERNAME, request.accountIdentifier.displayableId);
    XCTAssertEqualObjects(DEFAULT_TEST_HOME_ACCOUNT_ID, request.accountIdentifier.homeAccountId);
}

- (void)testJsonDictionary_whenAllPropertiesSet_shouldReturnJson
{
    __auto_type request = [MSIDBrokerOperationSilentTokenRequest new];
    request.brokerKey = @"broker_key_value";
    request.protocolVersion = 99;
    request.clientVersion = @"1.0.0";
    request.clientAppVersion = @"1.0";
    request.clientAppName = @"MSAL Test App";
    request.correlationId = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000001"];
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:nil context:nil error:nil];
    request.configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                 redirectUri:@"redirect uri"
                                                                    clientId:@"client id"
                                                                      target:@"scope scope2"];
    request.providerType = MSIDProviderTypeAADV1;
    request.oidcScope = @"profile";
    request.extraQueryParameters = @{@"qp1": @"value1"};
    request.instanceAware = YES;
    __auto_type enrollmentIds = @{
        @"enrollment_ids": @[ @{@"tid": @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1"} ]
    };
    request.enrollmentIds = enrollmentIds;
    __auto_type mamResources = @{
        @"login.microsoftonline.com": @"https://www.microsoft.com/intune",
        @"login.microsoftonline.de": @"https://www.microsoft.com/intune-de",
    };
    request.mamResources = mamResources;
    request.clientCapabilities = @[@"cp1", @"cp2"];
    __auto_type claimsJson = @{@"id_token": @{@"nickname": [NSNull new]}};
    request.claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJson error:nil];
    request.accountIdentifier =  [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                        homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    NSDictionary *json = [request jsonDictionary];
    
    XCTAssertEqual(20, json.allKeys.count);
    XCTAssertEqualObjects(json[@"authority"], @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(json[@"broker_key"], @"broker_key_value");
    XCTAssertEqualObjects(json[@"claims"], @"{\"id_token\":{\"nickname\":null}}");
    XCTAssertEqualObjects(json[@"client_app_name"], @"MSAL Test App");
    XCTAssertEqualObjects(json[@"client_app_version"], @"1.0");
    XCTAssertEqualObjects(json[@"client_capabilities"], @"cp1,cp2");
    XCTAssertEqualObjects(json[@"client_id"], @"client id");
    XCTAssertEqualObjects(json[@"client_version"], @"1.0.0");
    XCTAssertEqualObjects(json[@"correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertEqualObjects(json[@"extra_oidc_scopes"], @"profile");
    XCTAssertEqualObjects(json[@"extra_query_param"], @"qp1=value1");
    XCTAssertEqualObjects(json[@"home_account_id"], DEFAULT_TEST_HOME_ACCOUNT_ID);
    XCTAssertEqualObjects(json[@"instance_aware"], @"1");
    XCTAssertEqualObjects(json[@"intune_enrollment_ids"], @"{\"enrollment_ids\":[{\"tid\":\"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1\"}]}");
    XCTAssertEqualObjects(json[@"intune_mam_resource"], @"{\"login.microsoftonline.com\":\"https:\\/\\/www.microsoft.com\\/intune\",\"login.microsoftonline.de\":\"https:\\/\\/www.microsoft.com\\/intune-de\"}");
    XCTAssertEqualObjects(json[@"msg_protocol_ver"], @"99");
    XCTAssertEqualObjects(json[@"provider_type"], @"provider_aad_v1");
    XCTAssertEqualObjects(json[@"redirect_uri"], @"redirect uri");
    XCTAssertEqualObjects(json[@"scope"], @"scope scope2");
    XCTAssertEqualObjects(json[@"username"], @"user@contoso.com");
}

- (void)testJsonDictionary_whenRequiredPropertiesSet_shouldReturnJson
{
    __auto_type request = [MSIDBrokerOperationSilentTokenRequest new];
    request.brokerKey = @"broker_key_value";
    request.protocolVersion = 99;
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:nil context:nil error:nil];
    request.configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                             redirectUri:@"redirect uri"
                                                                clientId:@"client id"
                                                                  target:@"scope scope2"];
    request.providerType = MSIDProviderTypeAADV1;
    request.accountIdentifier =  [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
    homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    
    NSDictionary *json = [request jsonDictionary];
    
    XCTAssertEqual(10, json.allKeys.count);
    XCTAssertEqualObjects(json[@"authority"], @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(json[@"broker_key"], @"broker_key_value");
    XCTAssertEqualObjects(json[@"client_id"], @"client id");
    XCTAssertEqualObjects(json[@"home_account_id"], DEFAULT_TEST_HOME_ACCOUNT_ID);
    XCTAssertEqualObjects(json[@"instance_aware"], @"0");
    XCTAssertEqualObjects(json[@"msg_protocol_ver"], @"99");
    XCTAssertEqualObjects(json[@"provider_type"], @"provider_aad_v1");
    XCTAssertEqualObjects(json[@"redirect_uri"], @"redirect uri");
    XCTAssertEqualObjects(json[@"scope"], @"scope scope2");
    XCTAssertEqualObjects(json[@"username"], @"user@contoso.com");
}

- (void)testInitWithJSONDictionary_whenRequiredPropertiesWithHomeAccountId_shouldInitRequest
{
    NSDictionary *json = @{
        @"authority": @"https://login.microsoftonline.com/common",
        @"broker_key": @"broker_key_value",
        @"client_id": @"client id",
        @"msg_protocol_ver": @"99",
        @"provider_type": @"provider_aad_v1",
        @"redirect_uri": @"redirect uri",
        @"scope": @"scope scope2",
        @"home_account_id": DEFAULT_TEST_HOME_ACCOUNT_ID,
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationSilentTokenRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"broker_key_value", request.brokerKey);
    XCTAssertEqual(99, request.protocolVersion);
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/common", request.configuration.authority.url.absoluteString);
    XCTAssertEqualObjects(@"client id", request.configuration.clientId);
    XCTAssertEqual(MSIDProviderTypeAADV1, request.providerType);
    XCTAssertNil(request.accountIdentifier.displayableId);
    XCTAssertEqualObjects(DEFAULT_TEST_HOME_ACCOUNT_ID, request.accountIdentifier.homeAccountId);
}

- (void)testInitWithJSONDictionary_whenRequiredPropertiesWithUsername_shouldInitRequest
{
    NSDictionary *json = @{
        @"authority": @"https://login.microsoftonline.com/common",
        @"broker_key": @"broker_key_value",
        @"client_id": @"client id",
        @"msg_protocol_ver": @"99",
        @"provider_type": @"provider_aad_v1",
        @"redirect_uri": @"redirect uri",
        @"scope": @"scope scope2",
        @"username": @"user@contoso.com",
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationSilentTokenRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"broker_key_value", request.brokerKey);
    XCTAssertEqual(99, request.protocolVersion);
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/common", request.configuration.authority.url.absoluteString);
    XCTAssertEqualObjects(@"client id", request.configuration.clientId);
    XCTAssertEqual(MSIDProviderTypeAADV1, request.providerType);
    XCTAssertEqualObjects(DEFAULT_TEST_ID_TOKEN_USERNAME, request.accountIdentifier.displayableId);
    XCTAssertNil(request.accountIdentifier.homeAccountId);
}

@end
#endif
