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

#import <XCTest/XCTest.h>
#import "MSIDBrokerFlightProvider.h"

@interface MSIDBrokerFlightProviderTests : XCTestCase

@end

@implementation MSIDBrokerFlightProviderTests

- (void)testInitWithBase64EncodedFlightsPayload_whenNilOrEmptyPayload_shouldReturnNil
{
    NSString *flightsPayload = nil;
    MSIDBrokerFlightProvider *flightProvider = [[MSIDBrokerFlightProvider alloc] initWithBase64EncodedFlightsPayload:flightsPayload];
    
    XCTAssertNil(flightProvider);
    
    flightsPayload = @"";
    flightProvider = [[MSIDBrokerFlightProvider alloc] initWithBase64EncodedFlightsPayload:flightsPayload];
    
    XCTAssertNil(flightProvider);
}

- (void)testInitWithBase64EncodedFlightsPayload_whenInvalidPayload_shouldReturnNil
{
    NSString *flightsPayload = @"invalid_payload";
    MSIDBrokerFlightProvider *flightProvider = [[MSIDBrokerFlightProvider alloc] initWithBase64EncodedFlightsPayload:flightsPayload];
    
    XCTAssertNil(flightProvider);
}

- (void)testInitWithBase64EncodedFlightsPayload_whenNotDictionaryPayload_shouldReturnNil
{
    NSString *flightsPayload = @"bm90IGEgdmFsaWQgZGljdGlvbmFyeQ";
    MSIDBrokerFlightProvider *flightProvider = [[MSIDBrokerFlightProvider alloc] initWithBase64EncodedFlightsPayload:flightsPayload];
    
    XCTAssertNil(flightProvider);
}

- (void)testInitWithBase64EncodedFlightsPayload_whenBoolFlight_shouldReadValue
{
    NSString *flightsPayload = @"eyJmbGlnaHQxIjp0cnVlLCJmbGlnaHQyIjpbInRlbmFudDEiLCJ0ZW5hbnQyIl19";
    MSIDBrokerFlightProvider *flightProvider = [[MSIDBrokerFlightProvider alloc] initWithBase64EncodedFlightsPayload:flightsPayload];
    
    XCTAssertNotNil(flightProvider);
    XCTAssertTrue([flightProvider boolForKey:@"flight1"]);
}

- (void)testInitWithBase64EncodedFlightsPayload_whenNotBoolFlight_shouldReturnFalse
{
    NSString *flightsPayload = @"eyJmbGlnaHQxIjp0cnVlLCJmbGlnaHQyIjpbInRlbmFudDEiLCJ0ZW5hbnQyIl19";
    MSIDBrokerFlightProvider *flightProvider = [[MSIDBrokerFlightProvider alloc] initWithBase64EncodedFlightsPayload:flightsPayload];
    
    XCTAssertNotNil(flightProvider);
    XCTAssertFalse([flightProvider boolForKey:@"flight2"]);
}

- (void)testInitWithBase64EncodedFlightsPayload_whenStringListFlight_shouldReadValues
{
    NSString *flightsPayload = @"eyJmbGlnaHQxIjp0cnVlLCJmbGlnaHQyIjpbInRlbmFudDEiLCJ0ZW5hbnQyIl19";
    MSIDBrokerFlightProvider *flightProvider = [[MSIDBrokerFlightProvider alloc] initWithBase64EncodedFlightsPayload:flightsPayload];
    
    NSArray *strings = [flightProvider stringsForFlightKey:@"flight2"];
    
    XCTAssertNotNil(flightProvider);
    XCTAssertEqual(strings.count, 2);
}

- (void)testInitWithBase64EncodedFlightsPayload_whenNotStringListFlight_shouldReturnNil
{
    NSString *flightsPayload = @"eyJmbGlnaHQxIjp0cnVlLCJmbGlnaHQyIjpbInRlbmFudDEiLCJ0ZW5hbnQyIl19";
    MSIDBrokerFlightProvider *flightProvider = [[MSIDBrokerFlightProvider alloc] initWithBase64EncodedFlightsPayload:flightsPayload];
    
    NSArray *strings = [flightProvider stringsForFlightKey:@"flight1"];
    
    XCTAssertNotNil(flightProvider);
    XCTAssertEqual(strings.count, 0);
}

@end
