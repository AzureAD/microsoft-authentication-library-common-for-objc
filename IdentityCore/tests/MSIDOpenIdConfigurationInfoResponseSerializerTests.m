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
#import "MSIDAADOpenIdConfigurationInfoResponseSerializer.h"
#import "MSIDOpenIdProviderMetadata.h"

@interface MSIDAADOpenIdConfigurationInfoResponseSerializerTests : XCTestCase

@end

@implementation MSIDAADOpenIdConfigurationInfoResponseSerializerTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Tests

- (void)testResponseObjectForResponse_whenJsonValid_shouldReturnEndpointUrl
{
    __auto_type responseJson = @{
                                 @"authorization_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                                 @"token_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/token",
                                 @"issuer" : @"https://login.microsoftonline.com/common/v2.0",
                                 };
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDAADOpenIdConfigurationInfoResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDOpenIdProviderMetadata *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.authorizationEndpoint.absoluteString, @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize");
    XCTAssertEqualObjects(response.tokenEndpoint.absoluteString, @"https://login.microsoftonline.com/common/oauth2/v2.0/token");
    XCTAssertEqualObjects(response.issuer.absoluteString, @"https://login.microsoftonline.com/common/v2.0");
}

- (void)testResponseObjectForResponse_whenJsonNil_shouldReturnNilWithNilError
{
    __auto_type responseSerializer = [MSIDAADOpenIdConfigurationInfoResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDOpenIdProviderMetadata *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:nil context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(response);
}

#pragma mark - authorization_endpoint

- (void)testResponseObjectForResponse_whenAuthorizationEndpointIsMissed_shouldReturnNilWithError
{
    __auto_type responseJson = @{
                                 @"qwe" : @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                                 @"token_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/token",
                                 @"issuer" : @"https://login.microsoftonline.com/common/v2.0",
                                 };
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDAADOpenIdConfigurationInfoResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDOpenIdProviderMetadata *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];

    XCTAssertNotNil(error);
    XCTAssertNil(response);
}

- (void)testResponseObjectForResponse_whenAuthorizationEndpointIsNotString_shouldReturnNilWithError
{
    __auto_type responseJson = @{
                                 @"authorization_endpoint" : @1,
                                 @"token_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/token",
                                 @"issuer" : @"https://login.microsoftonline.com/common/v2.0",
                                 };
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDAADOpenIdConfigurationInfoResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDOpenIdProviderMetadata *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];

    XCTAssertNotNil(error);
    XCTAssertNil(response);
}

#pragma mark - token_endpoint

- (void)testResponseObjectForResponse_whenTokenEndpointIsMissed_shouldReturnNilWithError
{
    __auto_type responseJson = @{
                                 @"authorization_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                                 @"qwe" : @"https://login.microsoftonline.com/common/oauth2/v2.0/token",
                                 @"issuer" : @"https://login.microsoftonline.com/common/v2.0",
                                 };
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDAADOpenIdConfigurationInfoResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDOpenIdProviderMetadata *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(response);
}

- (void)testResponseObjectForResponse_whenTokenEndpointIsNotString_shouldReturnNilWithError
{
    __auto_type responseJson = @{
                                 @"authorization_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                                 @"token_endpoint" : @1,
                                 @"issuer" : @"https://login.microsoftonline.com/common/v2.0",
                                 };
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDAADOpenIdConfigurationInfoResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDOpenIdProviderMetadata *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(response);
}

#pragma mark - issuer

- (void)testResponseObjectForResponse_whenIssuerIsMissed_shouldReturnNilWithError
{
    __auto_type responseJson = @{
                                 @"authorization_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                                 @"token_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/token",
                                 @"qwe" : @"https://login.microsoftonline.com/common/v2.0",
                                 };
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDAADOpenIdConfigurationInfoResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDOpenIdProviderMetadata *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(response);
}

- (void)testResponseObjectForResponse_whenIssuerIsNotString_shouldReturnNilWithError
{
    __auto_type responseJson = @{
                                 @"authorization_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                                 @"token_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/token",
                                 @"issuer" : @1,
                                 };
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDAADOpenIdConfigurationInfoResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDOpenIdProviderMetadata *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(response);
}

- (void)testResponseObjectForResponse_whenErrorMessage_shouldReturnNilWithError
{
    __auto_type responseJson = @{ @"error": @"invalid_tenant",
                                  @"error_description": @"Tenant not found.",
                                  @"error_codes": @5049,
                                  @"timestamp": @"2019-02-22 07:49:38Z",
                                  @"trace_id": @"d855",
                                  @"correlation_id": @"6f62"
                                  };
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDAADOpenIdConfigurationInfoResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDOpenIdProviderMetadata *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorAuthorityValidation);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Tenant not found.");
}

@end
