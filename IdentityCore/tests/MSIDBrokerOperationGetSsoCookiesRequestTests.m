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
#import "MSIDBrokerOperationGetSsoCookiesRequest.h"
#import "MSIDAccountIdentifier.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDBrokerOperationGetSsoCookiesRequestTests : XCTestCase

@end

@implementation MSIDBrokerOperationGetSsoCookiesRequestTests

- (void)testJsonDictionary_whenNoSsoUrl_shouldReturnNilJson
{
    MSIDBrokerOperationGetSsoCookiesRequest *request = [MSIDBrokerOperationGetSsoCookiesRequest new];
    request.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"test@contoso.com" homeAccountId:@"uid.utid"];
    request.correlationId = [NSUUID UUID];
    request.brokerKey = @"key";
    request.protocolVersion = 99;
    
    NSDictionary *json = [request jsonDictionary];
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenEmptySsoUrl_shouldReturnNilJson
{
    MSIDBrokerOperationGetSsoCookiesRequest *request = [MSIDBrokerOperationGetSsoCookiesRequest new];
    request.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"test@contoso.com" homeAccountId:@"uid.utid"];
    request.correlationId = [NSUUID UUID];
    request.brokerKey = @"key";
    request.protocolVersion = 99;
    request.ssoUrl = @"";
    
    NSDictionary *json = [request jsonDictionary];
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenNoAccountIdentifier_shouldNotReturnNilJson
{
    MSIDBrokerOperationGetSsoCookiesRequest *request = [MSIDBrokerOperationGetSsoCookiesRequest new];
    request.brokerKey = @"key";
    request.protocolVersion = 99;
    request.ssoUrl = @"www.contoso.com";
    request.correlationId = [NSUUID UUID];
    
    NSDictionary *json = [request jsonDictionary];
    XCTAssertNotNil(json);
}

- (void)testJsonDictionary_whenNoHomeAccountId_shouldReturnNilJson
{
    MSIDBrokerOperationGetSsoCookiesRequest *request = [MSIDBrokerOperationGetSsoCookiesRequest new];
    request.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"test@contoso.com" homeAccountId:nil];
    request.correlationId = [NSUUID UUID];
    request.brokerKey = @"key";
    request.protocolVersion = 99;
    request.ssoUrl = @"www.contoso.com";
    
    NSDictionary *json = [request jsonDictionary];
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenEmptyHomeAccountId_shouldReturnNilJson
{
    MSIDBrokerOperationGetSsoCookiesRequest *request = [MSIDBrokerOperationGetSsoCookiesRequest new];
    request.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"test@contoso.com" homeAccountId:@""];
    request.correlationId = [NSUUID UUID];
    request.brokerKey = @"key";
    request.protocolVersion = 99;
    request.ssoUrl = @"www.contoso.com";
    
    NSDictionary *json = [request jsonDictionary];
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenEmptyCorrelationId_shouldReturnNilJson
{
    MSIDBrokerOperationGetSsoCookiesRequest *request = [MSIDBrokerOperationGetSsoCookiesRequest new];
    request.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"test@contoso.com" homeAccountId:@"uid.utid"];
    request.brokerKey = @"key";
    request.protocolVersion = 99;
    request.ssoUrl = @"www.contoso.com";
    
    NSDictionary *json = [request jsonDictionary];
    XCTAssertNil(json);
}

- (void)testJsonDictionary_shouldEqualToExpectedJson
{
    NSUUID * correlationId = [NSUUID UUID];
    MSIDBrokerOperationGetSsoCookiesRequest *request = [MSIDBrokerOperationGetSsoCookiesRequest new];
    request.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"test@contoso.com" homeAccountId:@"uid.utid"];
    request.correlationId = correlationId;
    request.brokerKey = @"key";
    request.protocolVersion = 99;
    request.ssoUrl = @"www.contoso.com";
    
    NSDictionary *json = [request jsonDictionary];
    XCTAssertNotNil(json);
    
    NSDictionary *expectedJson = @{@"sso_url": @"www.contoso.com",
                                   @"broker_key": @"key",
                                   @"account_identifier": @{
                                       @"home_account_id": @"uid.utid",
                                       @"username": @"test@contoso.com"
                                   },
                                   @"msg_protocol_ver": @"99",
                                   @"correlation_id": correlationId
    };
    
    XCTAssertTrue([json compareAndPrintDiff:expectedJson]);
}

- (void)testInitWithJSONDictionary_whenNoSsoUrl_shouldReturnError
{
    NSDictionary *json = @{
        @"broker_key": @"broker_key_value",
        @"msg_protocol_ver": @"99",
        @"correlation_id": [NSUUID UUID]
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationGetSsoCookiesRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"sso_url is missing in get Sso Cookies operation call.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitWithJSONDictionary_whenEmptySsoUrl_shouldReturnError
{
    NSDictionary *json = @{
        @"sso_url": @"",
        @"broker_key": @"broker_key_value",
        @"msg_protocol_ver": @"99",
        @"correlation_id": [NSUUID UUID]
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationGetSsoCookiesRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"sso_url is missing in get Sso Cookies operation call.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitWithJSONDictionary_whenNoHomeAccountId_shouldReturnError
{
    NSDictionary *json = @{
        @"sso_url": @"www.contoso.com",
        @"broker_key": @"broker_key_value",
        @"msg_protocol_ver": @"99",
        @"correlation_id": [NSUUID UUID],
        @"account_identifier": @{
            @"username": @"test@contoso.com"
        }
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationGetSsoCookiesRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Account is provided, but homeAccountId is missing from account identifier.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitWithJSONDictionary_whenNoAccountIdentifier_shouldNoReturnError
{
    NSDictionary *json = @{
        @"sso_url": @"www.contoso.com",
        @"broker_key": @"broker_key_value",
        @"msg_protocol_ver": @"99",
        @"correlation_id": [NSUUID UUID]
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationGetSsoCookiesRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(request);
}

- (void)testInitWithJSONDictionary_whenHaveAccountIdentifier_shouldNoReturnError
{
    NSUUID * correlationId = [NSUUID UUID];
    NSDictionary *json = @{
        @"sso_url": @"www.contoso.com",
        @"broker_key": @"broker_key_value",
        @"msg_protocol_ver": @"99",
        @"account_identifier": @{
            @"home_account_id": @"uid.utid",
            @"username": @"test@contoso.com"
        },
        @"correlation_id": correlationId
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationGetSsoCookiesRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(request);
    XCTAssertEqualObjects(request.ssoUrl, @"www.contoso.com");
    XCTAssertEqualObjects(request.accountIdentifier.displayableId, @"test@contoso.com");
    XCTAssertEqualObjects(request.accountIdentifier.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(request.correlationId, correlationId);
}

@end
