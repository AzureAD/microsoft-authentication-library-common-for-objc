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
#import "MSIDLastRequestTelemetry.h"
#import "MSIDTestContext.h"

@interface MSIDLastRequestTelemetryTests : XCTestCase

@property (nonatomic) MSIDTestContext *context;

@end

@implementation MSIDLastRequestTelemetryTests

- (void)setUp
{
    // Put setup code here. This method is called before the invocation of each test method in the class.
    __auto_type context = [MSIDTestContext new];
    context.correlationId = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000001"];
    self.context = context;
    
    [[MSIDLastRequestTelemetry sharedInstance] setValue:@0 forKey:@"silentSuccessfulCount"];
    [[MSIDLastRequestTelemetry sharedInstance] setValue:nil forKey:@"errorsInfo"];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

-(void)testUpdateTelemetryString_whenUpdatesFromDifferentThreads_shouldBeThreadSafe
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    
    dispatch_queue_t testQ1 = dispatch_queue_create([@"testQ1" cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t testQ2 = dispatch_queue_create([@"testQ2" cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    
    XCTestExpectation *expQ1 = [[XCTestExpectation alloc] initWithDescription:@"Dispatch queue 1"];
    expQ1.expectedFulfillmentCount = 2;
    XCTestExpectation *expQ2 = [[XCTestExpectation alloc] initWithDescription:@"Dispatch queue 2"];
    expQ2.expectedFulfillmentCount = 2;
    
    NSArray<XCTestExpectation *> *expectations = @[expQ1, expQ2];
    
    dispatch_async(testQ1, ^{
        [telemetryObject updateWithApiId:1 errorString:@"error1" context:nil];
        [expQ1 fulfill];
    });
    
    dispatch_sync(testQ2, ^{
        [telemetryObject updateWithApiId:2 errorString:@"error2" context:nil];
        [expQ2 fulfill];
    });
    
    dispatch_async(testQ1, ^{
        [telemetryObject updateWithApiId:3 errorString:@"error3" context:nil];
        [expQ1 fulfill];
    });
    
    dispatch_async(testQ2, ^{
        [telemetryObject updateWithApiId:4 errorString:@"error4" context:nil];
        [expQ2 fulfill];
    });
    
    [self waitForExpectations:expectations timeout:5];
    
    XCTAssertEqual(telemetryObject.errorsInfo.count, 4);
}

-(void)testSerialization_whenValidProperties_shouldCreateString
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:30 errorString:@"error" context:self.context];
    NSString *result = [telemetryObject telemetryString];
    
    XCTAssertEqualObjects(result, @"2|0|30,00000000-0000-0000-0000-000000000001|error|");
}

-(void)testSerialization_whenEmptyError_shouldCreateString
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:30 errorString:@"" context:nil];
    NSString *result = [telemetryObject telemetryString];
    
    XCTAssertEqualObjects(result, @"2|0|30,||");
}

-(void)testSerialization_whenNilError_shouldCreateString
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:30 errorString:nil context:nil];
    NSString *result = [telemetryObject telemetryString];
    
    XCTAssertEqualObjects(result, @"2|0|||");
}

@end
