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
#import "MSIDTestContext.h"

@interface MSIDHttpTestRequest : NSObject <MSIDHttpRequestProtocol>

@property (nonatomic) int sendWithBlockCounter;
@property (nonatomic, copy) MSIDHttpRequestDidCompleteBlock passedBlock;

@end

@implementation MSIDHttpTestRequest

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _sendWithBlockCounter = 0;
    }
    return self;
}

- (void)cancel
{
}

- (void)sendWithBlock:(MSIDHttpRequestDidCompleteBlock _Nullable)completionBlock
{
    self.sendWithBlockCounter++;
    self.passedBlock = completionBlock;
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

#pragma mark - Test Default Settings

- (void)testByDefaultRetryCounterIsOne
{
    XCTAssertEqual(self.errorHandler.retryCounter, 1);
}

- (void)testByDefaultRetryIntervalIsHalfOfSecond
{
    XCTAssertEqual(self.errorHandler.retryInterval, 0.5);
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
                           context:context
                   completionBlock:block];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqualObjects(block, httpRequest.passedBlock);
    XCTAssertEqual(1, httpRequest.sendWithBlockCounter);
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
                           context:context
                   completionBlock:block];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(httpRequest.passedBlock);
    XCTAssertEqual(0, httpRequest.sendWithBlockCounter);
    XCTAssertTrue(isBlockInvoked);
}

- (void)testHandleError_whenItIsNotServerError_shouldParseJsonErrorPayload
{
    __auto_type error = [NSError new];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new]
                                                           statusCode:400
                                                          HTTPVersion:nil
                                                         headerFields:nil];
    __auto_type httpRequest = [MSIDHttpTestRequest new];
    __auto_type context = [MSIDTestContext new];
    
    __block id jsonResponse;
    XCTestExpectation *expectation = [self expectationWithDescription:@"Block invoked"];
    __auto_type block = ^(id response, NSError *error) {
        jsonResponse = response;
        [expectation fulfill];
    };
    __auto_type jsonErrorPayload = @{@"p1" : @"v1"};
    id data = [NSJSONSerialization dataWithJSONObject:jsonErrorPayload options:0 error:nil];
    
    [self.errorHandler handleError:error
                      httpResponse:httpResponse
                              data:data
                       httpRequest:httpRequest
                           context:context
                   completionBlock:block];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqualObjects(jsonErrorPayload, jsonResponse);
}

@end
