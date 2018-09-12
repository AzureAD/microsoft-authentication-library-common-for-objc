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
#import "MSIDTelemetryTestDispatcher.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryAPIEvent.h"
#import "NSData+MSIDExtensions.h"

@interface MSIDTelemetryIntegrationTests : XCTestCase
{
    NSMutableArray *_receivedEvents;
}

@end

@implementation MSIDTelemetryIntegrationTests

- (void)setUp
{
    [super setUp];
    _receivedEvents = [NSMutableArray array];
    
    MSIDTelemetryTestDispatcher* dispatcher = [MSIDTelemetryTestDispatcher new];
    [dispatcher setTestCallback:^(id<MSIDTelemetryEventInterface> event)
     {
         [_receivedEvents addObject:event];
     }];
    
    // register the dispatcher
    [[MSIDTelemetry sharedInstance] addDispatcher:dispatcher];
}

- (void)tearDown
{
    [super tearDown];
    
    _receivedEvents = nil;
    [[MSIDTelemetry sharedInstance] removeAllDispatchers];
    [MSIDTelemetry sharedInstance].piiEnabled = NO;
}

- (void)testDispatchEvent_whenPiiEnabled_shouldReturnUnhashedOiiAndHashedPii
{
    [MSIDTelemetry sharedInstance].piiEnabled = YES;
    
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    [[MSIDTelemetry sharedInstance] startEvent:requestId
                                     eventName:MSID_TELEMETRY_EVENT_API_EVENT];
    
    MSIDTelemetryAPIEvent *event = [[MSIDTelemetryAPIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_API_EVENT
                                                                     requestId:requestId
                                                                 correlationId:nil];
    [event setUserId:@"user"]; //Pii
    [event setClientId:@"clientid"]; //Oii
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:event];
    
    XCTAssertEqual(_receivedEvents.count, 1);
    //expect hashed Pii
    XCTAssertEqualObjects([_receivedEvents[0] propertyWithName:MSID_TELEMETRY_KEY_USER_ID], [[[@"user" dataUsingEncoding:NSUTF8StringEncoding] msidSHA256] msidHexString]);
    //expect unhashed Oii
    XCTAssertEqualObjects([_receivedEvents[0] propertyWithName:MSID_TELEMETRY_KEY_CLIENT_ID], @"clientid");
}

- (void)testDispatchEvent_whenPiiDisabled_shouldNotReturnOiiPii
{
    [MSIDTelemetry sharedInstance].piiEnabled = NO;
    
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    [[MSIDTelemetry sharedInstance] startEvent:requestId
                                     eventName:MSID_TELEMETRY_EVENT_API_EVENT];
    
    MSIDTelemetryAPIEvent *event = [[MSIDTelemetryAPIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_API_EVENT
                                                                     requestId:requestId
                                                                 correlationId:nil];
    [event setUserId:@"user"]; //Pii
    [event setClientId:@"clientid"]; //Oii
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:event];
    
    XCTAssertEqual(_receivedEvents.count, 1);
    //no Pii or Oii is returned
    XCTAssertEqualObjects([_receivedEvents[0] propertyWithName:MSID_TELEMETRY_KEY_USER_ID], nil);
    XCTAssertEqualObjects([_receivedEvents[0] propertyWithName:MSID_TELEMETRY_KEY_CLIENT_ID], nil);
}

@end
