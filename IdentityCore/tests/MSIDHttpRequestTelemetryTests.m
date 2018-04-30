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
#import "MSIDHttpRequestTelemetry.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTestContext.h"

@interface MSIDTelemetry (Tests)

- (id)initInternal;

@end

@interface MSIDTestTelemetry : MSIDTelemetry

@property (nonatomic) int startEventCounter;
@property (nonatomic) NSString *passedEventName;
@property (nonatomic) NSString *passedRequestId;
@property (nonatomic) int stopEventCounter;
@property (nonatomic) id<MSIDTelemetryEventInterface> passedEvent;

@end

@implementation MSIDTestTelemetry

- (void)startEvent:(NSString *)requestId eventName:(NSString *)eventName
{
    self.startEventCounter++;
    self.passedRequestId = requestId;
    self.passedEventName = eventName;
}

- (void)stopEvent:(NSString *)requestId event:(id<MSIDTelemetryEventInterface>)event
{
    self.stopEventCounter++;
    self.passedEvent = event;
}

@end

@interface MSIDHttpRequestTelemetryTests : XCTestCase

@property (nonatomic) MSIDHttpRequestTelemetry *requestTelemetry;

@end

@implementation MSIDHttpRequestTelemetryTests

- (void)setUp
{
    [super setUp];
    
    self.requestTelemetry = [MSIDHttpRequestTelemetry new];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testTelemetry_byDefaultIsSharedInstance
{
    XCTAssertEqual(self.requestTelemetry.telemetry, MSIDTelemetry.sharedInstance);
}

- (void)testSendRequestEventWithId_shouldInvokeTelemtryStartEvent
{
    __auto_type telemetry = [[MSIDTestTelemetry alloc] initInternal];
    self.requestTelemetry.telemetry = telemetry;
    
    [self.requestTelemetry sendRequestEventWithId:@"some id"];
    
    XCTAssertEqual(telemetry.startEventCounter, 1);
    XCTAssertEqualObjects(telemetry.passedEventName, @"http_event");
    XCTAssertEqualObjects(telemetry.passedRequestId, @"some id");
}

- (void)testResponseReceivedEventWithId_shouldInvokeTelemtryStopEventWithConfiguredEvent
{
    __auto_type telemetry = [[MSIDTestTelemetry alloc] initInternal];
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type urlRequest = [[NSURLRequest alloc] initWithURL:baseUrl];
    __auto_type headers = @{@"client-request-id" : @"client request id"};
    __auto_type jsonData = @{@"error" : @"invalid_grant"};
    __auto_type data = [NSJSONSerialization dataWithJSONObject:jsonData options:0 error:nil];
    __auto_type response = [[NSHTTPURLResponse alloc] initWithURL:baseUrl statusCode:0 HTTPVersion:nil headerFields:headers];
    __auto_type error = [[NSError alloc] initWithDomain:@"Test Domain" code:1 userInfo:nil];
    __auto_type context = [MSIDTestContext new];
    context.telemetryRequestId = @"some id";
    context.correlationId = [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"];
    self.requestTelemetry.telemetry = telemetry;
    
    [self.requestTelemetry responseReceivedEventWithContext:context
                                                 urlRequest:urlRequest
                                               httpResponse:response
                                                       data:data
                                                      error:error];
    
    XCTAssertEqual(telemetry.stopEventCounter, 1);
    __auto_type eventProperties = [telemetry.passedEvent getProperties];
    XCTAssertEqualObjects(eventProperties[@"correlation_id"], @"E621E1F8-C36C-495A-93FC-0C247A3E6E5F");
    XCTAssertEqualObjects(eventProperties[@"event_name"], @"http_event");
    XCTAssertEqualObjects(eventProperties[@"http_error_domain"], @"Test Domain");
    XCTAssertEqualObjects(eventProperties[@"http_path"], @"https://fake.url/");
    XCTAssertEqualObjects(eventProperties[@"method"], @"GET");
    XCTAssertEqualObjects(eventProperties[@"oauth_error_code"], @"invalid_grant");
    XCTAssertEqualObjects(eventProperties[@"request_id"], @"some id");
    XCTAssertEqualObjects(eventProperties[@"response_code"], @"1");
    XCTAssertEqualObjects(eventProperties[@"x_ms_request_id"], @"client request id");
}

@end
