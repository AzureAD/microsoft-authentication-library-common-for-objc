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
#import "MSIDCurrentRequestTelemetry.h"

@interface MSIDCurrentRequestTelemetryTests : XCTestCase

@end

@implementation MSIDCurrentRequestTelemetryTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testInitWithTelemetryString_whenValidString_shouldInit
{
    NSString *testString = @"2|82,0|";
    NSError *error;
    MSIDCurrentRequestTelemetry *telemetryObject = [[MSIDCurrentRequestTelemetry alloc] initWithTelemetryString:testString error:&error];
    
    
    XCTAssertNotNil(telemetryObject);
    XCTAssertEqual(telemetryObject.schemaVersion, 2);
    XCTAssertEqual(telemetryObject.apiId, 82);
    XCTAssertEqual(telemetryObject.forceRefresh, 0);
}

- (void)testInitWithTelemetryString_whenNullString_shouldReturnNil
{
    NSString *testString = nil;
    NSError *error;
    MSIDCurrentRequestTelemetry *telemetryObject = [[MSIDCurrentRequestTelemetry alloc] initWithTelemetryString:testString error:&error];
    
    
    XCTAssertNil(telemetryObject);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Initialized server telemetry string with nil or empty string");
}

- (void)testInitWithTelemetryString_whenEmptyString_shouldError
{
    NSString *testString = @"";
    NSError *error;
    MSIDCurrentRequestTelemetry *telemetryObject = [[MSIDCurrentRequestTelemetry alloc] initWithTelemetryString:testString error:&error];
    
    
    XCTAssertNil(telemetryObject);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Initialized server telemetry string with nil or empty string");
}

- (void)testInitWithTelemetryString_whenInvalidString_shouldError
{
    NSString *testString = @"sjsdjasdkdsjsdlkdsfsdf";
    NSError *error;
    MSIDCurrentRequestTelemetry *telemetryObject = [[MSIDCurrentRequestTelemetry alloc] initWithTelemetryString:testString error:&error];
    
    
    XCTAssertNil(telemetryObject);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Initialized server telemetry string with invalid string format");
}

-(void)testTelemetryString_whenValidProperties_shouldCreateString
{
    NSString *testString = @"2|82,0|";
    NSError *error;
    MSIDCurrentRequestTelemetry *telemetryObject = [[MSIDCurrentRequestTelemetry alloc] initWithTelemetryString:testString error:&error];
    NSString *result = [telemetryObject telemetryString];
    
    XCTAssertEqualObjects(result, @"2|82,0|");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
