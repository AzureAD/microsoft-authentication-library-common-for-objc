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


#import <Foundation/Foundation.h>

#import <XCTest/XCTest.h>
#import "MSIDAADEndpointProvider.h"
#import "MSIDAADNetworkConfiguration.h"

@interface MSIDAADEndpointProviderTests : XCTestCase

@end

@implementation MSIDAADEndpointProviderTests
static NSString  *baseUrlString = @"https://login.microsoftonline.com/e966f473-64cd-4681-8bdc-cb4b768a0521";

- (void)testOauth2TokenEndpointWithUrl_shouldReturnExpectedUrl
{
    
    NSURL *tokenEndpointURL = [MSIDAADNetworkConfiguration.defaultConfiguration.endpointProvider oauth2TokenEndpointWithUrl:[NSURL URLWithString:baseUrlString]];
    NSString *expectedResultStr = @"https://login.microsoftonline.com/e966f473-64cd-4681-8bdc-cb4b768a0521/oauth2/test-api-version/token";
    NSURL *resultURL = [NSURL URLWithString:expectedResultStr];
    XCTAssertEqualObjects(tokenEndpointURL, resultURL);
}

- (void)testOauth2TokenEndpointWithNilUrl_shouldReturnNil
{
    
    NSString *baseUrl = nil;
    NSURL *tokenEndpointURL = [MSIDAADNetworkConfiguration.defaultConfiguration.endpointProvider oauth2TokenEndpointWithUrl:[NSURL URLWithString:baseUrl]];
    XCTAssertNil(tokenEndpointURL);
}

- (void)testOauth2TokenEndpointWithEmptyUrl_shouldReturnNil
{
    
    NSString *baseUrl = @"";
    NSURL *tokenEndpointURL = [MSIDAADNetworkConfiguration.defaultConfiguration.endpointProvider oauth2TokenEndpointWithUrl:[NSURL URLWithString:baseUrl]];
    XCTAssertNil(tokenEndpointURL);
}

- (void)testOauth2IssuerWithUrl_shouldReturnExpectedUrl
{
    NSURL *issuerURL = [MSIDAADNetworkConfiguration.defaultConfiguration.endpointProvider oauth2IssuerWithUrl:[NSURL URLWithString:baseUrlString]];
    NSString *expectedResultStr = @"https://login.microsoftonline.com/e966f473-64cd-4681-8bdc-cb4b768a0521/test-api-version";
    NSURL *resultURL = [NSURL URLWithString:expectedResultStr];
    XCTAssertEqualObjects(issuerURL, resultURL);
}

- (void)testOauth2IssuerWithNilUrl_shouldReturnNil
{
    
    NSString *baseUrl = nil;
    NSURL *issuerURL = [MSIDAADNetworkConfiguration.defaultConfiguration.endpointProvider oauth2IssuerWithUrl:[NSURL URLWithString:baseUrl]];
    XCTAssertNil(issuerURL);
}

- (void)testOauth2IssuerWithEmptyUrl_shouldReturnNil
{
    
    NSString *baseUrl = @"";
    NSURL *issuerURL = [MSIDAADNetworkConfiguration.defaultConfiguration.endpointProvider oauth2IssuerWithUrl:[NSURL URLWithString:baseUrl]];
    XCTAssertNil(issuerURL);
}

- (void)testOauth2jwksEndpointWithUrl_shouldReturnExpectedUrl
{
    NSURL *jwksEndpointURL = [MSIDAADNetworkConfiguration.defaultConfiguration.endpointProvider oauth2jwksEndpointWithUrl:[NSURL URLWithString:baseUrlString]];
    NSString *expectedResultStr = @"https://login.microsoftonline.com/e966f473-64cd-4681-8bdc-cb4b768a0521/discovery/test-api-version/keys";
    NSURL *resultURL = [NSURL URLWithString:expectedResultStr];
    XCTAssertEqualObjects(jwksEndpointURL, resultURL);
}

- (void)testOauth2jwksEndpointWithNilUrl_shouldReturnNil
{
    
    NSString *baseUrl = nil;
    NSURL *jwksEndpointURL = [MSIDAADNetworkConfiguration.defaultConfiguration.endpointProvider oauth2jwksEndpointWithUrl:[NSURL URLWithString:baseUrl]];
    XCTAssertNil(jwksEndpointURL);
}

- (void)testOauth2jwksEndpointWithEmptyUrl_shouldReturnNil
{
    
    NSString *baseUrl = @"";
    NSURL *jwksEndpointURL = [MSIDAADNetworkConfiguration.defaultConfiguration.endpointProvider oauth2jwksEndpointWithUrl:[NSURL URLWithString:baseUrl]];
    XCTAssertNil(jwksEndpointURL);
}

@end
