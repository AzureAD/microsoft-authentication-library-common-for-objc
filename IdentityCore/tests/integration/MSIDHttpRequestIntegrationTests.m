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
#import "MSIDHttpResponseSerializer.h"
#import "MSIDUrlRequestSerializer.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse.h"
#import "MSIDTestContext.h"
#import "MSIDHttpRequestErrorHandling.h"
#import "MSIDHttpRequestConfiguratorProtocol.h"
#import "MSIDHttpRequestTelemetry.h"
#import "MSIDJsonResponsePreprocessor.h"
#import "MSIDAADTokenResponseSerializer.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDHttpRequestInterceptorProtocol.h"

@interface MSIDTestRequestInterceptor : NSObject <MSIDHttpRequestInterceptorProtocol>

@property (nonatomic, nullable) NSDictionary<NSString *, NSString *> *additionalHeaders;
@property (nonatomic, nullable) NSURL *capturedURL;

@end

@implementation MSIDTestRequestInterceptor

- (void)addAdditionalHeaderFieldsForUrl:(nullable NSURL *)requestUrl withBlock:(nonnull MSIDHttpRequestInterceptorAddHeaderCompletionBlock)completionBlock
{
    self.capturedURL = requestUrl;
    completionBlock(self.additionalHeaders);
}

@end

@interface MSIDTestRequestConfigurator : NSObject <MSIDHttpRequestConfiguratorProtocol>

@property (nonatomic) int configureInvokedCounts;
@property (nonatomic) MSIDHttpRequest *passedHttpRequest;

@end

@implementation MSIDTestRequestConfigurator

- (void)configure:(MSIDHttpRequest *)request
{
    self.configureInvokedCounts++;
    self.passedHttpRequest = request;
}

@end

@interface MSIDTestErrorHandler : NSObject <MSIDHttpRequestErrorHandling>

@property (nonatomic) int handleErrorInvokedCounts;
@property (nonatomic) NSError *passedError;
@property (nonatomic) NSHTTPURLResponse *passedHttpResponse;
@property (nonatomic) NSData *passedData;
@property (nonatomic) id<MSIDHttpRequestProtocol> passedHttpRequest;
@property (nonatomic) id<MSIDRequestContext> passedContext;
@property (nonatomic, copy) MSIDHttpRequestDidCompleteBlock passedBlock;
@property (nonatomic) id<MSIDResponseSerialization> responseSerializer;
@property (nonatomic) MSIDExternalSSOContext *passedSSOContext;

@end

@implementation MSIDTestErrorHandler

- (void)handleError:(NSError *)error
       httpResponse:(NSHTTPURLResponse *)httpResponse
               data:(NSData *)data
        httpRequest:(id<MSIDHttpRequestProtocol>)httpRequest
 responseSerializer:(id<MSIDResponseSerialization>)responseSerializer
 externalSSOContext:(MSIDExternalSSOContext *)ssoContext
            context:(id<MSIDRequestContext>)context
    completionBlock:(MSIDHttpRequestDidCompleteBlock)completionBlock
{
    self.passedError = error;
    self.passedHttpResponse = httpResponse;
    self.passedData = data;
    self.passedHttpRequest = httpRequest;
    self.passedContext = context;
    self.passedBlock = completionBlock;
    self.responseSerializer = responseSerializer;
    self.handleErrorInvokedCounts++;
    self.passedSSOContext = ssoContext;
}

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

- (void)testUrlRequest_byDefaultIsNil
{
    XCTAssertNil(self.request.urlRequest);
}

- (void)testRequest_byDefaultUseMSIDHttpResponseSerializerWithMSIDJsonResponsePreprocessor
{
    XCTAssertTrue([self.request.responseSerializer isKindOfClass:MSIDHttpResponseSerializer.class]);
    __auto_type responseSerializer = (MSIDHttpResponseSerializer *)self.request.responseSerializer;
    XCTAssertTrue([responseSerializer.preprocessor isKindOfClass:MSIDJsonResponsePreprocessor.class]);
}

- (void)testRequest_byDefaultUseMSIDUrlRequestSerializer
{
    XCTAssertTrue([self.request.requestSerializer isKindOfClass:MSIDUrlRequestSerializer.class]);
}

- (void)testErrorHandler_byDefaultIsNil
{
    XCTAssertNil(self.request.errorHandler);
}

- (void)testRequestTelemtry_byDefaultIsNotNil
{
    XCTAssertTrue([self.request.telemetry isKindOfClass:MSIDHttpRequestTelemetry.class]);
}

#pragma mark - Test sendWithContext:completionBlock:

- (void)testSendWithContext_whenGetRequest_shouldEncodeParametersInUrl
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type urlWithParameters = [[NSURL alloc] initWithString:@"https://fake.url?p1=v1&p2=v2"];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    self.request.parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:urlWithParameters
                                                                reponse:[NSHTTPURLResponse new]];
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"GET Request"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithContext_whenGetRequestWithNilParameters_shouldReturnNilError
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:baseUrl
                                                                reponse:[NSHTTPURLResponse new]];
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"GET Request"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithContext_whenPostRequest_shouldEncodeParametersInBody
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"POST";
    self.request.urlRequest = urlRequest;
    self.request.parameters = parameters;

    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:baseUrl
                                                                reponse:[NSHTTPURLResponse new]];
    [testUrlResponse setUrlFormEncodedBody:parameters];
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"POST Request"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithContext_whenGetRequestWithError_shouldReturnError
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type urlWithParameters = [[NSURL alloc] initWithString:@"https://fake.url?p1=v1&p2=v2"];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    self.request.parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:urlWithParameters
                                                                reponse:[NSHTTPURLResponse new]];
    testUrlResponse->_error = [NSError new];
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"GET Request With Error"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNotNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithContext_whenGetRequestWithServerErrorAndErrorHandlerIsNotNil_shouldInvokeErrorHandler
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type urlWithParameters = [[NSURL alloc] initWithString:@"https://fake.url?p1=v1&p2=v2"];
    __auto_type passedContext = [MSIDTestContext new];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:baseUrl statusCode:500 HTTPVersion:nil headerFields:nil];
    __auto_type testErrorHandler = [MSIDTestErrorHandler new];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    self.request.parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    self.request.context = passedContext;
    self.request.errorHandler = testErrorHandler;
    self.request.responseSerializer = [[MSIDAADTokenResponseSerializer alloc] initWithOauth2Factory:[MSIDAADV2Oauth2Factory new]];
    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:urlWithParameters
                                                                reponse:httpResponse];
    [MSIDTestURLSession addResponses:@[testUrlResponse]];
    [self keyValueObservingExpectationForObject:testErrorHandler keyPath:@"handleErrorInvokedCounts" expectedValue:@1];

    [self.request sendWithBlock:^(__unused id response, __unused NSError *error) {}];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqualObjects(testErrorHandler.passedError, testUrlResponse->_error);
    XCTAssertEqualObjects(testErrorHandler.passedHttpResponse, testUrlResponse->_response);
    XCTAssertEqualObjects(testErrorHandler.passedHttpRequest, self.request);
    XCTAssertEqualObjects(testErrorHandler.passedContext, passedContext);
    XCTAssertEqualObjects(testErrorHandler.responseSerializer, self.request.responseSerializer);
    XCTAssertNotNil(testErrorHandler.passedBlock);
}

- (void)testSendWithContext_whenGetRequestWithServerErrorAndErrorHandlerIsNotNil_andDifferentErorResponseSerializer_shouldInvokeErrorHandlerWithErrorSerializer
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type urlWithParameters = [[NSURL alloc] initWithString:@"https://fake.url?p1=v1&p2=v2"];
    __auto_type passedContext = [MSIDTestContext new];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:baseUrl statusCode:500 HTTPVersion:nil headerFields:nil];
    __auto_type testErrorHandler = [MSIDTestErrorHandler new];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    self.request.parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    self.request.context = passedContext;
    self.request.errorHandler = testErrorHandler;
    self.request.responseSerializer = [[MSIDTokenResponseSerializer alloc] initWithOauth2Factory:[MSIDAADV2Oauth2Factory new]];
    self.request.errorResponseSerializer = [[MSIDAADTokenResponseSerializer alloc] initWithOauth2Factory:[MSIDAADV2Oauth2Factory new]];

    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:urlWithParameters
                                                                reponse:httpResponse];
    [MSIDTestURLSession addResponses:@[testUrlResponse]];
    [self keyValueObservingExpectationForObject:testErrorHandler keyPath:@"handleErrorInvokedCounts" expectedValue:@1];

    [self.request sendWithBlock:^(__unused id response, __unused NSError *error) {}];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqualObjects(testErrorHandler.passedError, testUrlResponse->_error);
    XCTAssertEqualObjects(testErrorHandler.passedHttpResponse, testUrlResponse->_response);
    XCTAssertEqualObjects(testErrorHandler.passedHttpRequest, self.request);
    XCTAssertEqualObjects(testErrorHandler.passedContext, passedContext);
    XCTAssertEqualObjects(testErrorHandler.responseSerializer, self.request.errorResponseSerializer);
    XCTAssertNotEqualObjects(testErrorHandler.responseSerializer, self.request.responseSerializer);
    XCTAssertNotNil(testErrorHandler.passedBlock);
}

- (void)testSendWithContext_whenErrorWithHttpResponseContainingClientData_shouldEnrichErrorUserInfo
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type urlWithParameters = [[NSURL alloc] initWithString:@"https://fake.url?p1=v1&p2=v2"];
    NSString *expectedClientData = @"test-client-data-value";
    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:baseUrl
                                                                 statusCode:200
                                                                HTTPVersion:nil
                                                               headerFields:@{MSID_CLIENT_DATA_HEADER_KEY : expectedClientData}];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    self.request.parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:urlWithParameters
                                                                reponse:httpResponse];
    testUrlResponse->_error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"GET Request With Error And ClientData"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNotNil(error);
         XCTAssertEqualObjects(error.userInfo[MSID_CLIENT_DATA_RESPONSE], expectedClientData);
         XCTAssertEqual(error.code, NSURLErrorTimedOut);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithContext_whenErrorWithHttpResponseWithoutClientData_shouldNotEnrichErrorUserInfo
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type urlWithParameters = [[NSURL alloc] initWithString:@"https://fake.url?p1=v1&p2=v2"];
    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:baseUrl
                                                                 statusCode:200
                                                                HTTPVersion:nil
                                                               headerFields:nil];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    self.request.parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:urlWithParameters
                                                                reponse:httpResponse];
    testUrlResponse->_error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"GET Request With Error No ClientData"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNotNil(error);
         XCTAssertNil(error.userInfo[MSID_CLIENT_DATA_RESPONSE]);
         XCTAssertEqual(error.code, NSURLErrorTimedOut);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithContext_whenGetRequestResponseHasData_shouldParseResponse
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type urlWithParameters = [[NSURL alloc] initWithString:@"https://fake.url?p1=v1&p2=v2"];
    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new]
                                                                  statusCode:200
                                                                 HTTPVersion:nil
                                                                headerFields:nil];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    self.request.parameters = @{@"p1" : @"v1", @"p2" : @"v2"};

    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:urlWithParameters
                                                                reponse:httpResponse];
    __auto_type responseJson = @{@"p" : @"v"};
    [testUrlResponse setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"GET Request"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNotNil(response);
         XCTAssertEqualObjects(responseJson, response);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - requestInterceptor tests

- (void)testSendWithBlock_whenNoInterceptorSet_shouldSendRequestSuccessfully
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;
    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:baseUrl
                                                                reponse:[NSHTTPURLResponse new]];
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"No interceptor request"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithBlock_whenInterceptorProvidesValidXHeader_shouldAddHeaderToRequest
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;

    __auto_type interceptor = [MSIDTestRequestInterceptor new];
    interceptor.additionalHeaders = @{@"x-custom-header" : @"customValue"};
    self.request.requestInterceptor = interceptor;

    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:baseUrl
                                                                reponse:[NSHTTPURLResponse new]];
    testUrlResponse->_expectedRequestHeaders = @{@"x-custom-header" : @"customValue"};
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Valid x- header interceptor"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithBlock_whenInterceptorProvidesNilHeaders_shouldSendRequestSuccessfully
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;

    __auto_type interceptor = [MSIDTestRequestInterceptor new];
    interceptor.additionalHeaders = nil;
    self.request.requestInterceptor = interceptor;

    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:baseUrl
                                                                reponse:[NSHTTPURLResponse new]];
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Nil headers interceptor"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithBlock_whenInterceptorProvidesEmptyHeaders_shouldSendRequestSuccessfully
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;

    __auto_type interceptor = [MSIDTestRequestInterceptor new];
    interceptor.additionalHeaders = @{};
    self.request.requestInterceptor = interceptor;

    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:baseUrl
                                                                reponse:[NSHTTPURLResponse new]];
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Empty headers interceptor"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithBlock_whenInterceptorProvidesHeaderWithoutXPrefix_shouldSkipHeaderAndSendRequest
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;

    __auto_type interceptor = [MSIDTestRequestInterceptor new];
    interceptor.additionalHeaders = @{@"invalid-header" : @"value"};
    self.request.requestInterceptor = interceptor;

    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:baseUrl
                                                                reponse:[NSHTTPURLResponse new]];
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Non x- header skipped"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithBlock_whenInterceptorProvidesMultipleHeaders_shouldAddValidAndSkipInvalid
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;

    __auto_type interceptor = [MSIDTestRequestInterceptor new];
    interceptor.additionalHeaders = @{
        @"x-valid-header" : @"validValue",
        @"invalid-header" : @"ignoredValue"
    };
    self.request.requestInterceptor = interceptor;

    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:baseUrl
                                                                reponse:[NSHTTPURLResponse new]];
    testUrlResponse->_expectedRequestHeaders = @{@"x-valid-header" : @"validValue"};
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Valid header added, invalid skipped"];
    [self.request sendWithBlock:^(id response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSendWithBlock_whenInterceptorIsSet_shouldCallInterceptorWithRequestURL
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";
    self.request.urlRequest = urlRequest;

    __auto_type interceptor = [MSIDTestRequestInterceptor new];
    interceptor.additionalHeaders = nil;
    self.request.requestInterceptor = interceptor;

    MSIDTestURLResponse *testUrlResponse = [MSIDTestURLResponse request:baseUrl
                                                                reponse:[NSHTTPURLResponse new]];
    [MSIDTestURLSession addResponse:testUrlResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Interceptor called with URL"];
    [self.request sendWithBlock:^(__unused id response, __unused NSError *error)
     {
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqualObjects(interceptor.capturedURL, baseUrl);
}

@end
