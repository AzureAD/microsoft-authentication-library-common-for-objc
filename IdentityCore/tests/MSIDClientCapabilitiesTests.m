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
#import "MSIDClientCapabilitiesUtil.h"
#import "MSIDClaimsRequest.h"

@interface MSIDClientCapabilitiesTests : XCTestCase

@end

@implementation MSIDClientCapabilitiesTests

#pragma mark - claimsParameterFromCapabilities:developerClaims:

- (void)testclaimsParameterFromCapabilitiesAndDeveloperClaims_whenNilCapabilities_andNilDeveloperClaims_shouldReturnNil
{
    NSArray *inputCapabilities = nil;
    MSIDClaimsRequest *claimsRequest = nil;
    
    MSIDClaimsRequest *result = [MSIDClientCapabilitiesUtil msidClaimsRequestFromCapabilities:inputCapabilities
                                                                                claimsRequest:claimsRequest];

    XCTAssertNil(result);
}

- (void)testclaimsParameterFromCapabilitiesAndDeveloperClaims_whenNilCapabilities_andNonNilDeveloperClaims_shouldReturnDeveloperClaims
{
    NSArray *inputCapabilities = nil;
    MSIDClaimsRequest *claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:@{@"access_token":@{@"polids":@{@"essential":@YES,@"values":@[@"d77e91f0-fc60-45e4-97b8-14a1337faa28"]}}} error:nil];

    MSIDClaimsRequest *result = [MSIDClientCapabilitiesUtil msidClaimsRequestFromCapabilities:inputCapabilities
                                                                                claimsRequest:claimsRequest];

    XCTAssertNotNil(result);

    NSString *expectedResult = @"{\"access_token\":{\"polids\":{\"values\":[\"d77e91f0-fc60-45e4-97b8-14a1337faa28\"],\"essential\":true}}}";
    NSString *jsonString = [[result jsonDictionary] msidJSONSerializeWithContext:nil];
    XCTAssertEqualObjects(jsonString, expectedResult);
}

- (void)testclaimsParameterFromCapabilitiesAndDeveloperClaims_whenNonNilCapabilities_andNilDeveloperClaims_shouldReturnCapabilitiesClaims
{
    NSArray *inputCapabilities = @[@"llt"];
    MSIDClaimsRequest *claimsRequest = nil;

    MSIDClaimsRequest *result = [MSIDClientCapabilitiesUtil msidClaimsRequestFromCapabilities:inputCapabilities
                                                                                claimsRequest:claimsRequest];

    XCTAssertNotNil(result);

    NSString *expectedResult = @"{\"access_token\":{\"xms_cc\":{\"values\":[\"llt\"]}}}";
    NSString *jsonString = [[result jsonDictionary] msidJSONSerializeWithContext:nil];
    XCTAssertEqualObjects(jsonString, expectedResult);
}

- (void)testclaimsParameterFromCapabilitiesAndDeveloperClaims_whenNonNilCapabilities_andNonNilDeveloperClaims_shouldReturnBoth
{
    NSArray *inputCapabilities = @[@"llt"];
    MSIDClaimsRequest *claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:@{@"id_token":@{@"polids":@{@"essential":@YES,@"values":@[@"d77e91f0-fc60-45e4-97b8-14a1337faa28"]}}} error:nil];

    MSIDClaimsRequest *result = [MSIDClientCapabilitiesUtil msidClaimsRequestFromCapabilities:inputCapabilities
                                                                                claimsRequest:claimsRequest];

    XCTAssertNotNil(result);

    NSString *expectedResult = @"{\"access_token\":{\"xms_cc\":{\"values\":[\"llt\"]}},\"id_token\":{\"polids\":{\"values\":[\"d77e91f0-fc60-45e4-97b8-14a1337faa28\"],\"essential\":true}}}";
    NSString *jsonString = [[result jsonDictionary] msidJSONSerializeWithContext:nil];
    XCTAssertEqualObjects(jsonString, expectedResult);
}

- (void)testclaimsParameterFromCapabilitiesAndDeveloperClaims_whenNonNilCapabilities_andNonNilDeveloperClaims_andAccessTokenClaimsInBoth_shouldMergeClaims
{
    NSArray *inputCapabilities = @[@"cp1", @"llt"];
    MSIDClaimsRequest *claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:@{@"access_token":@{@"polids":@{@"essential":@YES,@"values":@[@"d77e91f0-fc60-45e4-97b8-14a1337faa28"]}}} error:nil];
    
    MSIDClaimsRequest *result = [MSIDClientCapabilitiesUtil msidClaimsRequestFromCapabilities:inputCapabilities
                                                                                claimsRequest:claimsRequest];

    XCTAssertNotNil(result);

    NSString *expectedResult = @"{\"access_token\":{\"polids\":{\"values\":[\"d77e91f0-fc60-45e4-97b8-14a1337faa28\"],\"essential\":true},\"xms_cc\":{\"values\":[\"cp1\",\"llt\"]}}}";
    NSString *jsonString = [[result jsonDictionary] msidJSONSerializeWithContext:nil];
    XCTAssertEqualObjects(jsonString, expectedResult);
}

@end
