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

-(void)testSerialization_whenValidProperties_shouldCreateString
{
    MSIDCurrentRequestTelemetry *telemetryObject = [MSIDCurrentRequestTelemetry new];
    telemetryObject.schemaVersion = 2;
    telemetryObject.forceRefresh = NO;
    telemetryObject.apiId = 30;
    
    NSString *result = [telemetryObject telemetryString];
    XCTAssertEqualObjects(result, @"2|30,0|");
}

-(void)testSerialization_whenNilProperties_shouldCreateString
{
    MSIDCurrentRequestTelemetry *telemetryObject = [MSIDCurrentRequestTelemetry new];
    
    NSString *result = [telemetryObject telemetryString];
    XCTAssertEqualObjects(result, @"0|0,0|");
}

@end
