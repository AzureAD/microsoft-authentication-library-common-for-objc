//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDTestContext.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDAggregatedDispatcher.h"
#import "MSIDTestTelemetryEventsObserver.h"
#import "MSIDTestTelemetryEventsObserver.h"
#import "MSIDTelemetryHttpEvent.h"
#import "MSIDTelemetryAPIEvent.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDTelemetryUIEvent.h"
#import "MSIDTelemetryBrokerEvent.h"
#import "MSIDTelemetryAuthorityValidationEvent.h"

@interface MSIDTelemetryDefaultTests : XCTestCase

@property (nonatomic) NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents;
@property (nonatomic) NSString *requestId;
@property (nonatomic) MSIDTestContext *context;
@property (nonatomic) MSIDDefaultDispatcher *dispatcher;
@property (nonatomic) MSIDTestTelemetryEventsObserver *observer;

@end

@implementation MSIDTelemetryDefaultTests

- (void)setUp
{
    [super setUp];
    
    self.receivedEvents = [NSMutableArray array];
    
    __auto_type observer = [MSIDTestTelemetryEventsObserver new];
    [observer setEventsReceivedBlock:^(NSArray<NSDictionary<NSString *,NSString *> *> *events)
     {
         self.receivedEvents = events;
     }];
    self.dispatcher = [[MSIDDefaultDispatcher alloc] initWithObserver:observer];
    self.observer = observer;
    
    [[MSIDTelemetry sharedInstance] addDispatcher:self.dispatcher];
    
    [MSIDTelemetry sharedInstance].piiEnabled = NO;
    MSIDTelemetry.sharedInstance.notifyOnFailureOnly = NO;
    
    self.requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    
    __auto_type context = [MSIDTestContext new];
    context.telemetryRequestId = self.requestId;
    context.correlationId = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000001"];
    self.context = context;
}

- (void)tearDown
{
    [super tearDown];
    
    [[MSIDTelemetry sharedInstance] removeAllDispatchers];
    self.receivedEvents = nil;
    self.observer = nil;
    self.dispatcher = nil;
}

#pragma mark - flush

- (void)testFlush_whenThereIsEventAndObserverIsSet_shouldSendEvents
{
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSString *eventName = @"test event";
    MSIDTelemetryBaseEvent *event = [[MSIDTelemetryBaseEvent alloc] initWithName:eventName context:nil];
    [event setProperty:MSID_TELEMETRY_KEY_USER_ID value:@"id1234"];
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    NSDictionary *dictionary = [self getEventPropertiesByEventName:eventName];
    XCTAssertNotNil(dictionary);
    XCTAssertNil([dictionary objectForKey:MSID_TELEMETRY_KEY_USER_ID]);
}

- (void)testFlush_whenThereIsEventAndObserverRemoved_shouldNotSendEvents
{
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSString *eventName = @"test event";
    MSIDTelemetryBaseEvent *event = [[MSIDTelemetryBaseEvent alloc] initWithName:eventName context:nil];
    [event setProperty:MSID_TELEMETRY_KEY_USER_ID value:@"id1234"];
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:event];
    [[MSIDTelemetry sharedInstance] removeDispatcher:self.dispatcher];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    XCTAssertEqual(self.receivedEvents.count, 0);
}

- (void)testFlush_whenThereIsNoEventAndObserverIsSet_shouldNotSendEvents
{
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    
    // Flush without adding any additional events
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    XCTAssertEqual(self.receivedEvents.count, 0);
}

- (void)testFlush_whenThereAre2EventsAndObserverIsSet_shouldSendEvents
{
    [MSIDTelemetry sharedInstance].piiEnabled = YES;
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSUUID *correlationId = [NSUUID UUID];
    __auto_type context = [MSIDTestContext new];
    context.telemetryRequestId = requestId;
    context.correlationId = correlationId;
    // API event
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"apiEvent"];
    MSIDTelemetryAPIEvent *apiEvent = [[MSIDTelemetryAPIEvent alloc] initWithName:@"apiEvent" context:context];
    [apiEvent setProperty:@"api_property" value:@"api_value"];
    [apiEvent setCorrelationId:correlationId];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:apiEvent];
    // HTTP event
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId
                                        event:[[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:context]];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    // Verify results: there should be 3 events (default, API, HTTP)
    XCTAssertEqual([self.receivedEvents count], 3);
    [self assertDefaultEvent:self.receivedEvents[0] piiEnabled:YES];
    [self assertAPIEvent:self.receivedEvents[1]];
    [self assertHTTPEvent:self.receivedEvents[2]];
}

- (void)testFlush_whenThereIsHttpEventWithClientTelemetry_shouldSendEvents
{
    [MSIDTelemetry sharedInstance].piiEnabled = YES;
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSUUID *correlationId = [NSUUID UUID];
    __auto_type context = [MSIDTestContext new];
    context.telemetryRequestId = requestId;
    context.correlationId = correlationId;
    
    // HTTP event
    __auto_type event = [[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:context];
    [event setClientTelemetry:@"1,123,1234,255.0643,I,qwe"];
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    // Verify results: there should be 2 events (default, HTTP)
    XCTAssertEqual([self.receivedEvents count], 2);
    [self assertDefaultEvent:self.receivedEvents[0] piiEnabled:YES];
    __auto_type httpEventInfo = self.receivedEvents[1];
    [self assertHTTPEvent:httpEventInfo];
    XCTAssertEqualObjects(httpEventInfo[@"Microsoft.Test.rt_age"], @"255.0643");
    XCTAssertEqualObjects(httpEventInfo[@"Microsoft.Test.server_error_code"], @"123");
    XCTAssertEqualObjects(httpEventInfo[@"Microsoft.Test.server_sub_error_code"], @"1234");
    XCTAssertEqualObjects(httpEventInfo[@"Microsoft.Test.spe_info"], @"I");
    XCTAssertEqualObjects(httpEventInfo[@"Microsoft.Test.x-ms-clitelem"], @"1,123,1234,255.0643,I,qwe");
}

- (void)testFlush_whenThereAre2EventsAndObserverIsSetAndSetTelemetryOnFailureYes_shouldFilterEvents
{
    MSIDTelemetry.sharedInstance.notifyOnFailureOnly = YES;
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSUUID *correlationId = [NSUUID UUID];
    __auto_type context = [MSIDTestContext new];
    context.telemetryRequestId = requestId;
    context.correlationId = correlationId;
    // HTTP event
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    MSIDTelemetryHttpEvent *httpEvent = [[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:context];
    [httpEvent setHttpErrorCode:@"error_code_123"];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:httpEvent];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    XCTAssertEqual([self.receivedEvents count], 2);
    [self assertDefaultEvent:self.receivedEvents[0] piiEnabled:NO];
    [self assertHTTPEvent:self.receivedEvents[1]];
    NSString *errorCode = self.receivedEvents[1][TELEMETRY_KEY(MSID_TELEMETRY_KEY_HTTP_RESPONSE_CODE)];
    XCTAssertNotNil(errorCode);
    XCTAssertEqualObjects(errorCode, @"error_code_123");
}

- (void)testFlush_whenThereIs1NonErrorEventsAndObserverIsSetAndSetTelemetryOnFailureYes_shouldNotSendEvents
{
    MSIDTelemetry.sharedInstance.notifyOnFailureOnly = YES;
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSUUID* correlationId = [NSUUID UUID];
    __auto_type context = [MSIDTestContext new];
    context.telemetryRequestId = requestId;
    context.correlationId = correlationId;
    // HTTP event
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    MSIDTelemetryHttpEvent *httpEvent = [[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:context];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:httpEvent];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    XCTAssertEqual(self.receivedEvents.count, 0);
}

#pragma mark - Private

- (NSDictionary *)getEventPropertiesByEventName:(NSString *)eventName
{
    for (NSDictionary *eventInfo in self.receivedEvents)
    {
        if ([[eventInfo objectForKey:TELEMETRY_KEY(MSID_TELEMETRY_KEY_EVENT_NAME)] isEqualToString:eventName])
        {
            return eventInfo;
        }
    }
    
    return nil;
}

- (void)assertDefaultEvent:(NSDictionary *)eventInfo piiEnabled:(BOOL)piiEnabled
{
    __auto_type defaultEventPropertyNames = [[NSSet alloc] initWithArray:[eventInfo allKeys]];
    
#if TARGET_OS_IPHONE
    XCTAssertEqual([defaultEventPropertyNames count], piiEnabled ? 9 : 6);
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.x_client_dm"]);
#else
    XCTAssertEqual([defaultEventPropertyNames count], piiEnabled ? 8 : 5);
#endif
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"Microsoft.Test.event_name"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"Microsoft.Test.x_client_cpu"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"Microsoft.Test.x_client_os"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"Microsoft.Test.x_client_sku"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"Microsoft.Test.x_client_ver"]);
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.event_name"], @"default_event");
    
    if (!piiEnabled) return;
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"Microsoft.Test.application_name"]);
#if TARGET_OS_IPHONE
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"Microsoft.Test.application_version"]);
#endif
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"Microsoft.Test.device_id"]);
}

- (void)assertAPIEvent:(NSDictionary *)eventInfo
{
    __auto_type apiEventPropertyNames = [[NSSet alloc] initWithArray:[eventInfo allKeys]];
    XCTAssertTrue([apiEventPropertyNames containsObject:@"Microsoft.Test.start_time"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"Microsoft.Test.stop_time"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"Microsoft.Test.correlation_id"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"Microsoft.Test.response_time"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"Microsoft.Test.request_id"]);
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.event_name"], @"apiEvent");
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.api_property"], @"api_value");
}

- (void)assertHTTPEvent:(NSDictionary *)eventInfo
{
    __auto_type httpEventPropertyNames = [[NSSet alloc] initWithArray:[eventInfo allKeys]];
    XCTAssertTrue([httpEventPropertyNames containsObject:@"Microsoft.Test.start_time"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"Microsoft.Test.stop_time"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"Microsoft.Test.response_time"]);
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.event_name"], @"httpEvent");
}

@end
