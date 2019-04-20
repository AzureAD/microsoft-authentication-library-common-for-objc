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
#import "MSIDOAuthRequestConfigurator.h"
#import "MSIDHttpRequest.h"
#import "MSIDTestContext.h"

@interface MSIDOAuthRequestConfiguratorTests : XCTestCase

@end

@implementation MSIDOAuthRequestConfiguratorTests

- (void)testConfigure_shouldConfigureBaseOAuthRequest
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type httpRequest = [MSIDHttpRequest new];
    __auto_type context = [MSIDTestContext new];
    context.correlationId = [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"];
    httpRequest.context = context;
    httpRequest.urlRequest = [[NSURLRequest alloc] initWithURL:baseUrl];
    
    MSIDOAuthRequestConfigurator *requestConfigurator = [MSIDOAuthRequestConfigurator new];
    requestConfigurator.timeoutInterval = 3333;
    
    [requestConfigurator configure:httpRequest];
    XCTAssertEqual(httpRequest.urlRequest.timeoutInterval, 3333);
    XCTAssertEqual(httpRequest.urlRequest.cachePolicy, NSURLRequestReloadIgnoringCacheData);
    XCTAssertEqualObjects(httpRequest.urlRequest.URL.absoluteString, @"https://fake.url");
}

@end
