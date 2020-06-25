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
    
    XCTestExpectation *exp1 = [[XCTestExpectation alloc] initWithDescription:@"Expectation 1"];
    XCTestExpectation *exp2 = [[XCTestExpectation alloc] initWithDescription:@"Expectation 2"];
    XCTestExpectation *exp3 = [[XCTestExpectation alloc] initWithDescription:@"Expectation 3"];
    XCTestExpectation *exp4 = [[XCTestExpectation alloc] initWithDescription:@"Expectation 4"];
    
    NSArray<XCTestExpectation *> *expectations = @[exp1, exp2, exp3, exp4];
    
    dispatch_async(testQ1, ^{
        [telemetryObject updateWithApiId:1 errorString:@"error1" context:nil];
        [exp1 fulfill];
    });
    
    dispatch_async(testQ2, ^{
        [telemetryObject updateWithApiId:2 errorString:@"error2" context:nil];
        [exp2 fulfill];
    });
    
    dispatch_async(testQ1, ^{
        [telemetryObject updateWithApiId:3 errorString:@"error3" context:nil];
        [exp3 fulfill];
    });
    
    dispatch_async(testQ2, ^{
        [telemetryObject updateWithApiId:4 errorString:@"error4" context:nil];
        [exp4 fulfill];
    });
    
    [self waitForExpectations:expectations timeout:5];
    
    XCTAssertEqual(telemetryObject.errorsInfo.count, 4);
}

-(void)testSerialization_whenSingleValidProperty_shouldCreateString
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:30 errorString:@"error" context:self.context];
    NSString *result = [telemetryObject telemetryString];
    
    XCTAssertEqualObjects(result, @"2|0|30,00000000-0000-0000-0000-000000000001|error|");
}

-(void)testSerialization_whenValidProperties_shouldCreateString
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:30 errorString:@"error" context:self.context];
    [telemetryObject updateWithApiId:40 errorString:@"error2" context:self.context];
    [telemetryObject updateWithApiId:50 errorString:@"error3" context:self.context];
    [telemetryObject updateWithApiId:60 errorString:@"error4" context:self.context];
    [telemetryObject updateWithApiId:70 errorString:@"error5" context:self.context];
    
    NSString *result = [telemetryObject telemetryString];
    
    XCTAssertEqualObjects(result, @"2|0|30,00000000-0000-0000-0000-000000000001,40,00000000-0000-0000-0000-000000000001,50,00000000-0000-0000-0000-000000000001,60,00000000-0000-0000-0000-000000000001,70,00000000-0000-0000-0000-000000000001|error,error2,error3,error4,error5|");
}

-(void)testSerialization_whenEmptyError_shouldCreateString
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:30 errorString:@"" context:nil];
    NSString *result = [telemetryObject telemetryString];
    
    XCTAssertEqualObjects(result, @"2|0|30,||");
}

-(void)testSerialization_whenEmptyErrors_shouldCreateString
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:30 errorString:@"" context:nil];
    [telemetryObject updateWithApiId:40 errorString:@"" context:nil];
    [telemetryObject updateWithApiId:50 errorString:@"" context:nil];
    NSString *result = [telemetryObject telemetryString];
    
    XCTAssertEqualObjects(result, @"2|0|30,,40,,50,|,,|");
}

-(void)testSerialization_whenNilError_shouldCreateString
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:30 errorString:nil context:nil];
    NSString *result = [telemetryObject telemetryString];
    
    XCTAssertEqualObjects(result, @"2|0|||");
}

-(void)testSerialization_whenNilErrors_shouldCreateString
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:30 errorString:nil context:nil];
    [telemetryObject updateWithApiId:30 errorString:nil context:nil];
    [telemetryObject updateWithApiId:30 errorString:nil context:nil];
    [telemetryObject updateWithApiId:30 errorString:nil context:nil];
    [telemetryObject updateWithApiId:30 errorString:nil context:nil];
    
    NSString *result = [telemetryObject telemetryString];
    
    XCTAssertEqualObjects(result, @"2|0|||");
}

-(void)testSerialization_whenValidandNilProperties_shouldCreateString
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    
    [telemetryObject updateWithApiId:30 errorString:@"error" context:self.context];
    
    // Telemetry object update with nil error: errorsInfo is set to nil and
    // silentSuccessful count back down to 0
    [telemetryObject updateWithApiId:0 errorString:nil context:nil];
    
    [telemetryObject updateWithApiId:50 errorString:@"error3" context:self.context];
    [telemetryObject updateWithApiId:0 errorString:nil context:nil];
    
    // "error5" should be only error serialzed, because it was added after a nil error
    [telemetryObject updateWithApiId:70 errorString:@"error5" context:self.context];
    
    NSString *result = [telemetryObject telemetryString];
    
    XCTAssertEqualObjects(result, @"2|0|70,00000000-0000-0000-0000-000000000001|error5|");
}

-(void)testSaveToDisk_whenSingleErrorSaved_shouldSaveAndRestoreToSameObject
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:30 errorString:@"error" context:self.context];

    MSIDLastRequestTelemetry *restoredTelemetryObject = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePathOfSavedTelemetry]];
    
    XCTAssertEqualObjects([restoredTelemetryObject telemetryString], [telemetryObject telemetryString]);
}

-(void)testSaveToDisk_whenMultipleSaves_shouldOverwriteAndRestoreToSameObject
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:10 errorString:@"error1" context:self.context];
    [telemetryObject updateWithApiId:20 errorString:@"error2" context:self.context];
    [telemetryObject updateWithApiId:30 errorString:@"error3" context:self.context];

    MSIDLastRequestTelemetry *restoredTelemetryObject = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePathOfSavedTelemetry]];
    
    XCTAssertEqualObjects([restoredTelemetryObject telemetryString], [telemetryObject telemetryString]);
    
    [telemetryObject updateWithApiId:40 errorString:@"error4" context:self.context];
    [telemetryObject updateWithApiId:50 errorString:@"error5" context:self.context];
    
    restoredTelemetryObject = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePathOfSavedTelemetry]];
    XCTAssertEqualObjects([restoredTelemetryObject telemetryString], [telemetryObject telemetryString]);
}

-(void)testSaveToDisk_whenMultipleSavesThenReset_shouldOverwriteAndRestoreToSameObject
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:10 errorString:@"error1" context:self.context];
    [telemetryObject updateWithApiId:20 errorString:@"error2" context:self.context];
    [telemetryObject updateWithApiId:30 errorString:@"error3" context:self.context];

    MSIDLastRequestTelemetry *restoredTelemetryObject = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePathOfSavedTelemetry]];
    
    XCTAssertEqualObjects([restoredTelemetryObject telemetryString], [telemetryObject telemetryString]);
    
    [[MSIDLastRequestTelemetry sharedInstance] setValue:@0 forKey:@"silentSuccessfulCount"];
    [[MSIDLastRequestTelemetry sharedInstance] setValue:nil forKey:@"errorsInfo"];
    
    [telemetryObject updateWithApiId:90 errorString:@"error9" context:self.context];
    
    restoredTelemetryObject = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePathOfSavedTelemetry]];
    XCTAssertEqualObjects([restoredTelemetryObject telemetryString], [telemetryObject telemetryString]);
}

-(void)testSaveToDisk_whenSuccessfulSilentCall_shouldOverwriteAndRestoreToSameObject
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject updateWithApiId:10 errorString:@"error1" context:self.context];
    [telemetryObject updateWithApiId:20 errorString:@"error2" context:self.context];
    [telemetryObject updateWithApiId:30 errorString:@"error3" context:self.context];

    MSIDLastRequestTelemetry *restoredTelemetryObject = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePathOfSavedTelemetry]];
    
    XCTAssertEqualObjects([restoredTelemetryObject telemetryString], [telemetryObject telemetryString]);
    
    [telemetryObject updateWithApiId:30 errorString:nil context:nil];
    
    restoredTelemetryObject = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePathOfSavedTelemetry]];
    XCTAssertEqualObjects([restoredTelemetryObject telemetryString], [telemetryObject telemetryString]);
    
    [telemetryObject increaseSilentSuccessfulCount];
    restoredTelemetryObject = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePathOfSavedTelemetry]];
    XCTAssertEqualObjects([restoredTelemetryObject telemetryString], [telemetryObject telemetryString]);
}

-(void)testSaveToDisk_whenManySilentCalls_shouldOverwriteAndRestoreToSameObject
{
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetryObject increaseSilentSuccessfulCount];
    [telemetryObject increaseSilentSuccessfulCount];
    [telemetryObject increaseSilentSuccessfulCount];

    MSIDLastRequestTelemetry *restoredTelemetryObject = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePathOfSavedTelemetry]];
    XCTAssertEqualObjects([restoredTelemetryObject telemetryString], [telemetryObject telemetryString]);
}

#pragma mark - Helper

- (NSString *)filePathOfSavedTelemetry
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:@"lastRequest"];
    return filePath;
}


@end
