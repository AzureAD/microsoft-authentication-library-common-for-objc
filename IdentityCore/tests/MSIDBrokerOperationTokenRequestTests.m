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
#import "MSIDBrokerOperationTokenRequest.h"
#import "MSIDConfiguration.h"
#import "MSIDAADAuthority.h"

@interface MSIDBrokerOperationTokenRequestTests : XCTestCase

@end

@implementation MSIDBrokerOperationTokenRequestTests

- (void)testIsSubclassOfOperationRequest_shouldReturnTrue
{
    XCTAssertTrue([MSIDBrokerOperationTokenRequest.class isSubclassOfClass:MSIDBrokerOperationTokenRequest.class]);
}

- (void)testJsonDictionary_whenNoConfiguration_shouldReturnNilJson
{
    __auto_type request = [MSIDBrokerOperationTokenRequest new];
    request.brokerKey = @"broker_key_value";
    request.protocolVersion = 99;
    
    NSDictionary *json = [request jsonDictionary];
    
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenNoAuthority_shouldReturnNilJson
{
    __auto_type request = [MSIDBrokerOperationTokenRequest new];
    request.brokerKey = @"broker_key_value";
    request.protocolVersion = 99;
    request.configuration = [[MSIDConfiguration alloc] initWithAuthority:nil
                                                             redirectUri:@"redirect uri"
                                                                clientId:@"client id"
                                                                  target:@"scope scope2"];
    
    NSDictionary *json = [request jsonDictionary];
    
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenNoRedirectUri_shouldReturnNilJson
{
    __auto_type request = [MSIDBrokerOperationTokenRequest new];
    request.brokerKey = @"broker_key_value";
    request.protocolVersion = 99;
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:nil context:nil error:nil];
    request.configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                             redirectUri:nil
                                                                clientId:@"client id"
                                                                  target:@"scope scope2"];
    
    NSDictionary *json = [request jsonDictionary];
    
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenNoClientId_shouldReturnNilJson
{
    __auto_type request = [MSIDBrokerOperationTokenRequest new];
    request.brokerKey = @"broker_key_value";
    request.protocolVersion = 99;
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:nil context:nil error:nil];
    request.configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                             redirectUri:@"redirect uri"
                                                                clientId:nil
                                                                  target:@"scope scope2"];
    
    NSDictionary *json = [request jsonDictionary];
    
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenNoTarget_shouldReturnNilJson
{
    __auto_type request = [MSIDBrokerOperationTokenRequest new];
    request.brokerKey = @"broker_key_value";
    request.protocolVersion = 99;
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:nil context:nil error:nil];
    request.configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                             redirectUri:@"redirect uri"
                                                                clientId:@"client id"
                                                                  target:nil];
    
    NSDictionary *json = [request jsonDictionary];
    
    XCTAssertNil(json);
}

- (void)testInitWithJSONDictionary_whenNoProviderType_shouldReturnError
{
    NSDictionary *json = @{
        @"broker_key": @"broker_key_value",
        @"msg_protocol_ver": @"99",
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationTokenRequest alloc] initWithJSONDictionary:json error:&error];
    
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
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationTokenRequest alloc] initWithJSONDictionary:json error:&error];
    
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
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationTokenRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"redirect_uri key is missing in dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitWithJSONDictionary_whenNoClientId_shouldReturnError
{
    NSDictionary *json = @{
        @"broker_key": @"broker_key_value",
        @"msg_protocol_ver": @"99",
        @"provider_type": @"provider_aad_v1",
        @"authority": @"https://login.microsoftonline.com/common",
        @"redirect_uri": @"redirect uri",
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationTokenRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"client_id key is missing in dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitWithJSONDictionary_whenNo_shouldReturnError
{
    NSDictionary *json = @{
        @"broker_key": @"broker_key_value",
        @"msg_protocol_ver": @"99",
        @"provider_type": @"provider_aad_v1",
        @"authority": @"https://login.microsoftonline.com/common",
        @"redirect_uri": @"redirect uri",
        @"client_id": @"client id",
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationTokenRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"scope key is missing in dictionary.", error.userInfo[MSIDErrorDescriptionKey]);
}

@end
