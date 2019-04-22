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
#import "MSIDAADAuthorityMetadataResponseSerializer.h"
#import "MSIDAADAuthorityMetadataResponse.h"

@interface MSIDAADAuthorityMetadataResponseSerializerTests : XCTestCase

@end

@implementation MSIDAADAuthorityMetadataResponseSerializerTests

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
                                 @"tenant_discovery_endpoint" : @"https://login.microsoftonline.com/common/.well-known/openid-configuration"
                                 };
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDAADAuthorityMetadataResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDAADAuthorityMetadataResponse *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.openIdConfigurationEndpoint.absoluteString, @"https://login.microsoftonline.com/common/.well-known/openid-configuration");
}

- (void)testResponseObjectForResponse_whenTenantDiscoveryEndpointIsMissed_shouldReturnNilWithError
{
    __auto_type responseJson = @{
                                 @"qwe" : @"https://login.microsoftonline.com/common/.well-known/openid-configuration"
                                 };
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDAADAuthorityMetadataResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDAADAuthorityMetadataResponse *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(response);
}

- (void)testResponseObjectForResponse_whenTenantDiscoveryEndpointIsNotString_shouldReturnNilWithError
{
    __auto_type responseJson = @{ @"tenant_discovery_endpoint" : @1 };
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDAADAuthorityMetadataResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDAADAuthorityMetadataResponse *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(response);
}

- (void)testResponseObjectForResponse_whenJsonNil_shouldReturnNilWithNilError
{
    __auto_type responseSerializer = [MSIDAADAuthorityMetadataResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDAADAuthorityMetadataResponse *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:nil context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(response);
}

- (void)testResponseObjectForResponse_whenErrorMessage_shouldReturnNilWithError
{
    __auto_type responseJson = @{ @"error": @"invalid_instance",
                                  @"error_description": @"Unknown or invalid instance.",
                                  @"error_codes": @5049,
                                  @"timestamp": @"2019-02-22 07:49:38Z",
                                  @"trace_id": @"d855",
                                  @"correlation_id": @"6f62"
                                  };
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDAADAuthorityMetadataResponseSerializer new];
    
    NSError *error = nil;
    __auto_type response = (MSIDAADAuthorityMetadataResponse *)[responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorAuthorityValidation);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Unknown or invalid instance.");
}

@end
