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
#import "MSIDBrokerOperationSignoutFromDeviceRequest.h"
#import "MSIDAADAuthority.h"
#import "MSIDAccountIdentifier.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDBrokerOperationSignoutFromDeviceRequestTests : XCTestCase

@end

@implementation MSIDBrokerOperationSignoutFromDeviceRequestTests

- (void)testJsonDictionary_whenNoAuthority_shouldReturnNilJson
{
    MSIDBrokerOperationSignoutFromDeviceRequest *request = [MSIDBrokerOperationSignoutFromDeviceRequest new];
    request.providerType = MSIDProviderTypeAADV2;
    request.redirectUri = @"myredirect";
    request.clientId = @"client";
    request.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@upn.com" homeAccountId:@"uid.utid"];
    request.brokerKey = @"key";
    request.protocolVersion = 99;
    
    NSDictionary *json = [request jsonDictionary];
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenNoRedirectUri_shouldReturnNilJson
{
    MSIDBrokerOperationSignoutFromDeviceRequest *request = [MSIDBrokerOperationSignoutFromDeviceRequest new];
    request.providerType = MSIDProviderTypeAADV2;
    request.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] rawTenant:nil context:nil error:nil];
    request.clientId = @"client";
    request.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@upn.com" homeAccountId:@"uid.utid"];
    request.brokerKey = @"key";
    request.protocolVersion = 99;
    
    NSDictionary *json = [request jsonDictionary];
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenAllElementsPresent_shouldReturnJson
{
    MSIDBrokerOperationSignoutFromDeviceRequest *request = [MSIDBrokerOperationSignoutFromDeviceRequest new];
    request.providerType = MSIDProviderTypeAADV2;
    request.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] rawTenant:nil context:nil error:nil];
    request.redirectUri = @"myredirect";
    request.signoutFromBrowser = YES;
    request.clientId = @"client";
    request.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@upn.com" homeAccountId:@"uid.utid"];
    request.brokerKey = @"key";
    request.protocolVersion = 99;
    request.clearSSOExtensionCookies = YES;
    
    NSDictionary *json = [request jsonDictionary];
    XCTAssertNotNil(json);
    
    NSDictionary *expectedJson = @{@"authority": @"https://login.microsoftonline.com/common",
                                   @"broker_key": @"key",
                                   @"client_id": @"client",
                                   @"home_account_id": @"uid.utid",
                                   @"msg_protocol_ver": @"99",
                                   @"provider_type": @"provider_aad_v2",
                                   @"redirect_uri": @"myredirect",
                                   @"signout_from_browser": @YES,
                                   @"username": @"upn@upn.com",
                                   @"clear_sso_extension_cookies": @YES
    };
    
    XCTAssertTrue([json compareAndPrintDiff:expectedJson]);
}

- (void)testInitWithJSONDictionary_whenNoProviderType_shouldReturnError
{
    NSDictionary *json = @{
        @"broker_key": @"broker_key_value",
        @"msg_protocol_ver": @"99",
        @"home_account_id": @"uid.utid",
        @"client_id": @"client"
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationSignoutFromDeviceRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"provider_type key is missing in dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitWithJSONDictionary_whenNoAuthority_shouldReturnError
{
    NSDictionary *json = @{
        @"broker_key": @"broker_key_value",
        @"msg_protocol_ver": @"99",
        @"provider_type": @"provider_aad_v1",
        @"home_account_id": @"uid.utid",
        @"client_id": @"client"
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationSignoutFromDeviceRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Failed to init MSIDAADAuthority from json: authority is either nil or not a url.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitWithJSONDictionary_whenNoRedirectUri_shouldReturnError
{
    NSDictionary *json = @{
        @"broker_key": @"broker_key_value",
        @"msg_protocol_ver": @"99",
        @"provider_type": @"provider_aad_v1",
        @"authority": @"https://login.microsoftonline.com/common",
        @"home_account_id": @"uid.utid",
        @"client_id": @"client"
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationSignoutFromDeviceRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"redirect_uri key is missing in dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitWithJSONDictionary_whenValidDictionary_shouldReturnRequest
{
    NSDictionary *json = @{@"authority": @"https://login.microsoftonline.com/common",
                                   @"broker_key": @"key",
                                   @"client_id": @"client",
                                   @"home_account_id": @"uid.utid",
                                   @"msg_protocol_ver": @"99",
                                   @"provider_type": @"provider_aad_v2",
                                   @"redirect_uri": @"myredirect",
                                   @"signout_from_browser": @YES,
                                   @"username": @"upn@upn.com"};
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationSignoutFromDeviceRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    XCTAssertEqualObjects(request.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(request.brokerKey, @"key");
    XCTAssertEqualObjects(request.clientId, @"client");
    XCTAssertEqualObjects(request.accountIdentifier.displayableId, @"upn@upn.com");
    XCTAssertEqualObjects(request.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqual(request.protocolVersion, 99);
    XCTAssertEqual(request.providerType, MSIDProviderTypeAADV2);
    XCTAssertEqualObjects(request.redirectUri, @"myredirect");
    XCTAssertTrue(request.signoutFromBrowser);
}

@end
