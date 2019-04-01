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
#import "MSIDAADRequestErrorHandler.h"
#import "MSIDHttpResponseSerializer.h"
#import "MSIDTestContext.h"
#import "MSIDAADTokenResponseSerializer.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAADTokenResponse.h"

@interface MSIDHttpTestRequest : NSObject <MSIDHttpRequestProtocol>

@property (nonatomic) int sendWithBlockCounter;
@property (nonatomic, copy) MSIDHttpRequestDidCompleteBlock passedBlock;

@property (nonatomic) NSInteger retryCounter;
@property (nonatomic) NSTimeInterval retryInterval;
@property (nonatomic) NSURLRequest *urlRequest;

@end

@implementation MSIDHttpTestRequest

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _sendWithBlockCounter = 0;
        _retryCounter = 1;
        _retryInterval = 0.5;
    }
    return self;
}

- (void)finishAndInvalidate
{
}

- (void)cancel
{
}

- (void)sendWithBlock:(MSIDHttpRequestDidCompleteBlock _Nullable)completionBlock
{
    self.passedBlock = completionBlock;
    self.sendWithBlockCounter++;
}

@end

@interface MSIDAADRequestErrorHandlerTests : XCTestCase

@property (nonatomic) MSIDAADRequestErrorHandler *errorHandler;

@end

@implementation MSIDAADRequestErrorHandlerTests

- (void)setUp
{
    [super setUp];
    
    self.errorHandler = [MSIDAADRequestErrorHandler new];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark -

- (void)testHandleError_whenItIsServerError_shouldRetryRequestAndDecreseRetryCounter
{
    __auto_type error = [NSError new];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new]
                                                           statusCode:500
                                                          HTTPVersion:nil
                                                         headerFields:nil];
    __auto_type httpRequest = [MSIDHttpTestRequest new];
    __auto_type context = [MSIDTestContext new];
    __block BOOL isBlockInvoked = NO;
    __auto_type block = ^(id response, NSError *error) {
        isBlockInvoked = YES;
    };
    
    [self keyValueObservingExpectationForObject:httpRequest keyPath:@"sendWithBlockCounter" expectedValue:@1];
    
    [self.errorHandler handleError:error
                      httpResponse:httpResponse
                              data:nil
                       httpRequest:httpRequest
                responseSerializer:[MSIDHttpResponseSerializer new]
                           context:context
                   completionBlock:block];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqualObjects(block, httpRequest.passedBlock);
    XCTAssertEqual(1, httpRequest.sendWithBlockCounter);
    XCTAssertEqual(0, httpRequest.retryCounter);
    XCTAssertFalse(isBlockInvoked);
}

- (void)testHandleError_whenItIsNotServerError_shouldNotRetry
{
    __auto_type error = [NSError new];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new]
                                                           statusCode:400
                                                          HTTPVersion:nil
                                                         headerFields:nil];
    __auto_type httpRequest = [MSIDHttpTestRequest new];
    __auto_type context = [MSIDTestContext new];
    __block BOOL isBlockInvoked = NO;
    __auto_type block = ^(id response, NSError *error) {
        isBlockInvoked = YES;
    };
    
    __auto_type expectation = [self keyValueObservingExpectationForObject:httpRequest keyPath:@"sendWithBlockCounter" expectedValue:@1];
    expectation.inverted = YES;
    
    [self.errorHandler handleError:error
                      httpResponse:httpResponse
                              data:nil
                       httpRequest:httpRequest
                responseSerializer:[MSIDHttpResponseSerializer new]
                           context:context
                   completionBlock:block];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(httpRequest.passedBlock);
    XCTAssertEqual(0, httpRequest.sendWithBlockCounter);
    XCTAssertTrue(isBlockInvoked);
}

- (void)testHandleError_whenItIsNotServerError_shouldReturnStatusCodeAndHeaders
{
    __auto_type error = [NSError new];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new]
                                                           statusCode:403
                                                          HTTPVersion:nil
                                                         headerFields:@{@"headerKey":@"headerValue"}];
    __auto_type httpRequest = [MSIDHttpTestRequest new];
    __auto_type context = [MSIDTestContext new];
    
    __block id errorResponse;
    __block NSError *returnError;
    XCTestExpectation *expectation = [self expectationWithDescription:@"Block invoked"];
    __auto_type block = ^(id response, NSError *error) {
        errorResponse = response;
        returnError = error;
        [expectation fulfill];
    };
    __auto_type jsonErrorPayload = @{@"p1" : @"v1"};
    id data = [NSJSONSerialization dataWithJSONObject:jsonErrorPayload options:0 error:nil];
    
    MSIDAADTokenResponseSerializer *serializer = [[MSIDAADTokenResponseSerializer alloc] initWithOauth2Factory:[MSIDAADV2Oauth2Factory new]];
    
    [self.errorHandler handleError:error
                      httpResponse:httpResponse
                              data:data
                       httpRequest:httpRequest
                responseSerializer:serializer
                           context:context
                   completionBlock:block];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqualObjects(returnError.domain, MSIDHttpErrorCodeDomain);
    XCTAssertEqual(returnError.code, MSIDErrorServerUnhandledResponse);
    XCTAssertEqualObjects(returnError.userInfo[MSIDHTTPHeadersKey], @{@"headerKey":@"headerValue"});
    
    XCTAssertNil(errorResponse);
}

- (void)testHandleError_whenItIsServerErrorAndJSONResponseReturned_shouldReturnTokenResponse
{
    __auto_type error = [NSError new];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new]
                                                           statusCode:400
                                                          HTTPVersion:nil
                                                         headerFields:@{@"headerKey":@"headerValue"}];
    __auto_type httpRequest = [MSIDHttpTestRequest new];
    __auto_type context = [MSIDTestContext new];

    __block id errorResponse;
    __block NSError *returnError;
    XCTestExpectation *expectation = [self expectationWithDescription:@"Block invoked"];
    __auto_type block = ^(id response, NSError *error) {
        errorResponse = response;
        returnError = error;
        [expectation fulfill];
    };

    __auto_type jsonErrorPayload = @{@"error" : @"invalid_grant",
                                     @"error_description": @"I'm a description",
                                     @"correlation_id": @"I'm a correlation id",
                                     @"suberror": @"I'm a suberror"
                                     };
    id data = [NSJSONSerialization dataWithJSONObject:jsonErrorPayload options:0 error:nil];
    
    MSIDAADTokenResponseSerializer *serializer = [[MSIDAADTokenResponseSerializer alloc] initWithOauth2Factory:[MSIDAADV2Oauth2Factory new]];

    [self.errorHandler handleError:error
                      httpResponse:httpResponse
                              data:data
                       httpRequest:httpRequest
                responseSerializer:serializer
                           context:context
                   completionBlock:block];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(errorResponse);
    MSIDAADTokenResponse *tokenResponse = (MSIDAADTokenResponse *)errorResponse;
    XCTAssertTrue([tokenResponse isKindOfClass:[MSIDTokenResponse class]]);
    XCTAssertEqualObjects(tokenResponse.error, @"invalid_grant");
    XCTAssertEqualObjects(tokenResponse.errorDescription, @"I'm a description");
    XCTAssertEqualObjects(tokenResponse.suberror, @"I'm a suberror");

    XCTAssertNil(returnError);
}

- (void)testHandleError_whenItIsServerError_shouldReturnResponseCodeInError
{
    __auto_type error = [NSError new];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new]
                                                           statusCode:404
                                                          HTTPVersion:nil
                                                         headerFields:nil];
    __auto_type httpRequest = [MSIDHttpTestRequest new];
    __auto_type context = [MSIDTestContext new];
    __block NSError *returnError;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Block invoked"];
    __auto_type block = ^(id response, NSError *error) {
        returnError = error;
        [expectation fulfill];
    };
    
    MSIDAADTokenResponseSerializer *serializer = [[MSIDAADTokenResponseSerializer alloc] initWithOauth2Factory:[MSIDAADV2Oauth2Factory new]];
    
    [self.errorHandler handleError:error
                      httpResponse:httpResponse
                              data:nil
                       httpRequest:httpRequest
                responseSerializer:serializer
                           context:context
                   completionBlock:block];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqualObjects(returnError.domain, MSIDHttpErrorCodeDomain);
    XCTAssertEqual(returnError.code, MSIDErrorServerUnhandledResponse);
    XCTAssertEqualObjects(returnError.userInfo[MSIDHTTPResponseCodeKey], @"404");
}

- (void)testHandleError_whenNoErorDescriptionInBody_shouldReturnLocalizedErrorDescription
{
    __auto_type error = [NSError new];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new]
                                                           statusCode:403
                                                          HTTPVersion:nil
                                                         headerFields:nil];
    __auto_type httpRequest = [MSIDHttpTestRequest new];
    __auto_type context = [MSIDTestContext new];
    __block NSError *returnError;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Block invoked"];
    __auto_type block = ^(id response, NSError *error) {
        returnError = error;
        [expectation fulfill];
    };
    
    MSIDAADTokenResponseSerializer *serializer = [[MSIDAADTokenResponseSerializer alloc] initWithOauth2Factory:[MSIDAADV2Oauth2Factory new]];
    
    [self.errorHandler handleError:error
                      httpResponse:httpResponse
                              data:nil
                       httpRequest:httpRequest
                responseSerializer:serializer
                           context:context
                   completionBlock:block];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqualObjects(returnError.userInfo[MSIDErrorDescriptionKey], @"forbidden");
}

- (void)testHandleError_whenErorDescriptionInBody_shouldReturnDescriptionFromBody
{
    __auto_type error = [NSError new];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new]
                                                           statusCode:400
                                                          HTTPVersion:nil
                                                         headerFields:nil];
    __auto_type httpRequest = [MSIDHttpTestRequest new];
    __auto_type context = [MSIDTestContext new];
    __block MSIDAADTokenResponse *errorResponse;
    __block NSError *returnError;
    
    __auto_type json = @{@"error" : @"invalid_request", @"error_description": @"Invalid format for 'authorization_endpoint' value.",};
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Block invoked"];
    __auto_type block = ^(id response, NSError *error) {
        returnError = error;
        errorResponse = response;
        [expectation fulfill];
    };
    
    MSIDAADTokenResponseSerializer *serializer = [[MSIDAADTokenResponseSerializer alloc] initWithOauth2Factory:[MSIDAADV2Oauth2Factory new]];
    
    [self.errorHandler handleError:error
                      httpResponse:httpResponse
                              data:responseData
                       httpRequest:httpRequest
                responseSerializer:serializer
                           context:context
                   completionBlock:block];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqualObjects(errorResponse.errorDescription, @"Invalid format for 'authorization_endpoint' value.");
    XCTAssertEqualObjects(errorResponse.error, @"invalid_request");
}

@end
