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
#import "MSIDDRSDiscoveryResponseSerializer.h"

@interface MSIDDRSDiscoveryResponseSerializerTests : XCTestCase

@end

@implementation MSIDDRSDiscoveryResponseSerializerTests

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
    __auto_type responseJson = @{@"IdentityProviderService" : @{@"PassiveAuthEndpoint" : @"https://example.com/adfs/ls"}};
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDDRSDiscoveryResponseSerializer new];
    
    NSError *error = nil;
    NSURL *url = [responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(url.absoluteString, @"https://example.com/adfs/ls");
}

- (void)testResponseObjectForResponse_whenJsonEmpty_shouldReturnNilWithError
{
    __auto_type responseJson = @{};
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDDRSDiscoveryResponseSerializer new];
    
    NSError *error = nil;
    NSURL *url = [responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(url);
}

- (void)testResponseObjectForResponse_whenIdentityProviderServiceIsNotDictionary_shouldReturnNilWithError
{
    __auto_type responseJson = @{@"IdentityProviderService" : @"qwe"};
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDDRSDiscoveryResponseSerializer new];
    
    NSError *error = nil;
    NSURL *url = [responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(url);
}

- (void)testResponseObjectForResponse_whenPassiveAuthEndpointIsMissed_shouldReturnNilWithError
{
    __auto_type responseJson = @{@"IdentityProviderService" : @{@"qwe" : @"https://example.com/adfs/ls"}};
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDDRSDiscoveryResponseSerializer new];
    
    NSError *error = nil;
    NSURL *url = [responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(url);
}

- (void)testResponseObjectForResponse_whenPassiveAuthEndpointIsNotString_shouldReturnNilWithError
{
    __auto_type responseJson = @{@"IdentityProviderService" : @{@"PassiveAuthEndpoint" : @1}};
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseJson options:0 error:nil];
    __auto_type responseSerializer = [MSIDDRSDiscoveryResponseSerializer new];
    
    NSError *error = nil;
    NSURL *url = [responseSerializer responseObjectForResponse:[NSHTTPURLResponse new] data:data context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(url);
}

@end
