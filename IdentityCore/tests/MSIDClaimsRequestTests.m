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
#import "MSIDClaimsRequest.h"
#import "MSIDClaimsRequest+ClientCapabilities.h"

@interface MSIDClaimsRequestTests : XCTestCase

@end

@implementation MSIDClaimsRequestTests

- (void)setUp
{
}

- (void)tearDown
{
}

#pragma mark - requestCapabilities

- (void)testRequestCapabilities_whenNilCapabilities_shouldIgnoreThem
{
    NSArray *inputCapabilities = nil;
    
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    
    [claimsRequest requestCapabilities:inputCapabilities];
    
    XCTAssertFalse(claimsRequest.hasClaims);
}

- (void)testRequestCapabilities_whenNonNilCapabilities_shouldRequestCapabilities
{
    NSArray *inputCapabilities = @[@"llt"];
    
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    
    [claimsRequest requestCapabilities:inputCapabilities];
    
    NSString *expectedResult = @"{\"access_token\":{\"xms_cc\":{\"values\":[\"llt\"]}}}";
    NSString *jsonString = [[claimsRequest jsonDictionary] msidJSONSerializeWithContext:nil];
    XCTAssertEqualObjects(jsonString, expectedResult);
}

- (void)testRequestCapabilities_whenNonNilCapabilitiesAndNonNilDeveloperClaims_shouldReturnBoth
{
    NSArray *inputCapabilities = @[@"llt"];
    MSIDClaimsRequest *claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:@{@"id_token":@{@"polids":@{@"essential":@YES,@"values":@[@"d77e91f0-fc60-45e4-97b8-14a1337faa28"]}}} error:nil];
    
    [claimsRequest requestCapabilities:inputCapabilities];
    
    NSString *expectedResult = @"{\"access_token\":{\"xms_cc\":{\"values\":[\"llt\"]}},\"id_token\":{\"polids\":{\"values\":[\"d77e91f0-fc60-45e4-97b8-14a1337faa28\"],\"essential\":true}}}";
    NSString *jsonString = [[claimsRequest jsonDictionary] msidJSONSerializeWithContext:nil];
    XCTAssertEqualObjects(jsonString, expectedResult);
}

- (void)testRequestCapabilities_whenNonNilCapabilitiesAndNonNilDeveloperClaimsAndAccessTokenClaimsInBoth_shouldMergeClaims
{
    NSArray *inputCapabilities = @[@"cp1", @"llt"];
    MSIDClaimsRequest *claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:@{@"access_token":@{@"polids":@{@"essential":@YES,@"values":@[@"d77e91f0-fc60-45e4-97b8-14a1337faa28"]}}} error:nil];
    
    [claimsRequest requestCapabilities:inputCapabilities];
    
    NSString *expectedResult = @"{\"access_token\":{\"polids\":{\"values\":[\"d77e91f0-fc60-45e4-97b8-14a1337faa28\"],\"essential\":true},\"xms_cc\":{\"values\":[\"cp1\",\"llt\"]}}}";
    NSString *jsonString = [[claimsRequest jsonDictionary] msidJSONSerializeWithContext:nil];
    XCTAssertEqualObjects(jsonString, expectedResult);
}

@end
