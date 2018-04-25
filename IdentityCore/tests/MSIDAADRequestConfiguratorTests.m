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
#import "MSIDAADRequestConfigurator.h"
#import "MSIDHttpRequest.h"
#import "MSIDAADResponseSerializer.h"
#import "MSIDAADRequestErrorHandler.h"
#import "MSIDTestContext.h"

@interface MSIDAADRequestConfiguratorTests : XCTestCase

@property (nonatomic) MSIDAADRequestConfigurator *requestConfigurator;

@end

@implementation MSIDAADRequestConfiguratorTests

- (void)setUp
{
    [super setUp];
    
    self.requestConfigurator = [MSIDAADRequestConfigurator new];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testRequestConfigurator_byDefaultIntervalIs300Seconds
{
    XCTAssertEqual(self.requestConfigurator.timeoutInterval, 300);
}

- (void)testConfigure_shouldConfigureAADRequest
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type httpRequest = [MSIDHttpRequest new];
    __auto_type context = [MSIDTestContext new];
    context.correlationId = [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"];
    httpRequest.context = context;
    httpRequest.urlRequest = [[NSURLRequest alloc] initWithURL:baseUrl];
    self.requestConfigurator.timeoutInterval = 60;
    
    [self.requestConfigurator configure:httpRequest];
    
    XCTAssertTrue([httpRequest.responseSerializer isKindOfClass:MSIDAADResponseSerializer.class]);
    XCTAssertTrue([httpRequest.errorHandler isKindOfClass:MSIDAADRequestErrorHandler.class]);
    XCTAssertEqualObjects(httpRequest.urlRequest.allHTTPHeaderFields[@"Accept"], @"application/json");
    XCTAssertEqual(httpRequest.urlRequest.timeoutInterval, 60);
    XCTAssertEqual(httpRequest.urlRequest.cachePolicy, NSURLRequestReloadIgnoringCacheData);
    XCTAssertEqualObjects(httpRequest.urlRequest.URL.absoluteString, @"https://fake.url?x-client-Ver=1.0.0");
    __auto_type headers = httpRequest.urlRequest.allHTTPHeaderFields;
    XCTAssertEqualObjects(headers[MSID_OAUTH2_CORRELATION_ID_REQUEST], @"true");
    XCTAssertEqualObjects(headers[MSID_OAUTH2_CORRELATION_ID_REQUEST_VALUE], @"E621E1F8-C36C-495A-93FC-0C247A3E6E5F");
    XCTAssertNotNil(headers[@"x-client-CPU"]);
    XCTAssertNotNil(headers[@"x-client-DM"]);
    XCTAssertNotNil(headers[@"x-client-OS"]);
    XCTAssertNotNil(headers[@"x-client-SKU"]);
    XCTAssertNotNil(headers[@"x-client-Ver"]);
}

@end
