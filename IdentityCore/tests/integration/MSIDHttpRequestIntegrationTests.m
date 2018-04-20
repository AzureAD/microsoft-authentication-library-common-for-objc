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
#import "MSIDHttpRequest.h"
#import "MSIDJsonResponseSerializer.h"
#import "MSIDUrlRequestSerializer.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse.h"

@interface MSIDTestContext : NSObject <MSIDRequestContext>

@property (nonatomic) NSUUID *correlationId;
@property (nonatomic) NSString *logComponent;
@property (nonatomic) NSString *telemetryRequestId;

@end

@implementation MSIDTestContext
@end

@interface MSIDHttpRequestIntegrationTests : XCTestCase

@property (nonatomic) MSIDHttpRequest *request;

@end

@implementation MSIDHttpRequestIntegrationTests

- (void)setUp
{
    [super setUp];
    
    self.request = [MSIDHttpRequest new];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Test Default Settings

- (void)testUrlRequest_byDefaultIsNotNil
{
    XCTAssertNotNil(self.request.urlRequest);
}

- (void)testUrlRequest_byDefaultAcceptJson
{
    XCTAssertEqualObjects(self.request.urlRequest.allHTTPHeaderFields[@"Accept"], @"application/json");
}

- (void)testUrlRequest_byDefaultIntervalIs60Seconds
{
    XCTAssertEqual(self.request.urlRequest.timeoutInterval, 300);
}

- (void)testRequest_byDefaultUseMSIDJsonResponseSerializer
{
    XCTAssertTrue([self.request.responseSerializer isKindOfClass:MSIDJsonResponseSerializer.class]);
}

- (void)testRequest_byDefaultUseMSIDUrlRequestSerializer
{
    XCTAssertTrue([self.request.requestSerializer isKindOfClass:MSIDUrlRequestSerializer.class]);
}

- (void)testRequest_byDefaultRetryOnErrorCounterIsOne
{
    XCTAssertEqual(self.request.retryOnErrorCounter, 1);
}

#pragma mark - Test sendWithContext:completionBlock:

- (void)testSendWithContext_whenGetRequest_shouldEncodeParametersInUrl
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type urlWithParameters = [[NSURL alloc] initWithString:@"https://fake.url?p1=v1&p2=v2"];
    __auto_type passedContext = [MSIDTestContext new];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    self.request.parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    self.request.context = passedContext;
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:urlWithParameters
                                                         reponse:[NSHTTPURLResponse new]];
    [MSIDTestURLSession addResponse:response];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"GET Request"];
    [self.request sendWithBlock:^(id response, NSError *error, id<MSIDRequestContext> context)
     {
         XCTAssertNil(response);
         XCTAssertNil(error);
         XCTAssertEqualObjects(passedContext, context);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithContext_whenGetRequestWithNilParameters_shouldReturnNilError
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type passedContext = [MSIDTestContext new];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    self.request.context = passedContext;
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:baseUrl
                                                         reponse:[NSHTTPURLResponse new]];
    [MSIDTestURLSession addResponse:response];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"GET Request"];
    [self.request sendWithBlock:^(id response, NSError *error, id<MSIDRequestContext> context)
     {
         XCTAssertNil(response);
         XCTAssertNil(error);
         XCTAssertEqualObjects(passedContext, context);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithContext_whenPostRequest_shouldEncodeParametersInBody
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    __auto_type passedContext = [MSIDTestContext new];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"POST";
    self.request.urlRequest = urlRequest;
    self.request.parameters = parameters;
    self.request.context = passedContext;
    
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:baseUrl
                                                         reponse:[NSHTTPURLResponse new]];
    [response setUrlFormEncodedBody:parameters];
    [MSIDTestURLSession addResponse:response];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"POST Request"];
    [self.request sendWithBlock:^(id response, NSError *error, id<MSIDRequestContext> context)
     {
         XCTAssertNil(response);
         XCTAssertNil(error);
         XCTAssertEqualObjects(passedContext, context);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithContext_whenGetRequestWithError_shouldReturnError
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type urlWithParameters = [[NSURL alloc] initWithString:@"https://fake.url?p1=v1&p2=v2"];
    __auto_type passedContext = [MSIDTestContext new];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    self.request.parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    self.request.context = passedContext;
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:urlWithParameters
                                                         reponse:[NSHTTPURLResponse new]];
    response->_error = [NSError new];
    [MSIDTestURLSession addResponse:response];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"GET Request With Error"];
    [self.request sendWithBlock:^(id response, NSError *error, id<MSIDRequestContext> context)
     {
         XCTAssertNil(response);
         XCTAssertNotNil(error);
         XCTAssertEqualObjects(passedContext, context);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithContext_whenGetRequestWithServerError_shouldDecrementErrorCounterAndRetry
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type urlWithParameters = [[NSURL alloc] initWithString:@"https://fake.url?p1=v1&p2=v2"];
    __auto_type passedContext = [MSIDTestContext new];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:baseUrl statusCode:500 HTTPVersion:nil headerFields:nil];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    self.request.parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    self.request.context = passedContext;
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:urlWithParameters
                                                         reponse:httpResponse];
    response->_error = [NSError new];
    [MSIDTestURLSession addResponses:@[response, response]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"GET Request With Error"];
    [self.request sendWithBlock:^(id response, NSError *error, id<MSIDRequestContext> context)
     {
         XCTAssertNil(response);
         XCTAssertNotNil(error);
         XCTAssertEqualObjects(passedContext, context);

         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqual(0, self.request.retryOnErrorCounter);
}

- (void)testSendWithContext_whenGetRequestResponseHasData_shouldParseResponse
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type urlWithParameters = [[NSURL alloc] initWithString:@"https://fake.url?p1=v1&p2=v2"];
    __auto_type passedContext = [MSIDTestContext new];
    __auto_type httpResponse = [NSHTTPURLResponse new];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    self.request.parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    self.request.context = passedContext;
    
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:urlWithParameters
                                                         reponse:httpResponse];
    __auto_type responseJson = @{@"p" : @"v"};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"GET Request"];
    [self.request sendWithBlock:^(id response, NSError *error, id<MSIDRequestContext> context)
     {
         XCTAssertNotNil(response);
         XCTAssertEqualObjects(responseJson, response);
         XCTAssertNil(error);
         XCTAssertEqualObjects(passedContext, context);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
