//
//  MSIDLastRequestTelemetryTests.m
//  IdentityCore
//
//  Created by Mihai Petriuc on 5/1/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MSIDLastRequestTelemetry.h"

@interface MSIDLastRequestTelemetryTests : XCTestCase

@end

@implementation MSIDLastRequestTelemetryTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testInitWithTelemetryString_whenValidString_shouldInit
{
    NSString *testString = @"2|0|300,48432850-c45c-486c-a50a-a84cdb220c06,82,a4e7dfa8-5883-426a-96b5-81a325d0abd5|interaction_required,user_cancelled|";
    NSError *error;
    MSIDLastRequestTelemetry *telemetryObject = [[MSIDLastRequestTelemetry alloc] initWithTelemetryString:testString error:&error];
    
    XCTAssertNotNil(telemetryObject);
    XCTAssertEqual(telemetryObject.schemaVersion, 2);
    XCTAssertEqual(telemetryObject.silentSuccessfulCount, 0);
    XCTAssertEqual(telemetryObject.errorsInfo[0].apiId, 300);
    XCTAssertEqualObjects(telemetryObject.errorsInfo[0].correlationId, @"48432850-c45c-486c-a50a-a84cdb220c06");
    XCTAssertEqualObjects(telemetryObject.errorsInfo[0].error, @"interaction_required");
    XCTAssertEqual(telemetryObject.errorsInfo[1].apiId, 82);
    XCTAssertEqualObjects(telemetryObject.errorsInfo[1].correlationId, @"a4e7dfa8-5883-426a-96b5-81a325d0abd5");
    XCTAssertEqualObjects(telemetryObject.errorsInfo[1].error, @"user_cancelled");
}

- (void)testInitWithTelemetryString_whenNullString_shouldError
{
    NSString *testString = nil;
    NSError *error;
    MSIDLastRequestTelemetry *telemetryObject = [[MSIDLastRequestTelemetry alloc] initWithTelemetryString:testString error:&error];
    
    XCTAssertNil(telemetryObject);
}

- (void)testInitWithTelemetryString_whenEmptyString_shouldError
{
    NSString *testString = @"";
    NSError *error;
    MSIDLastRequestTelemetry *telemetryObject = [[MSIDLastRequestTelemetry alloc] initWithTelemetryString:testString error:&error];
    
    XCTAssertNil(telemetryObject);
}

- (void)testInitWithTelemetryString_whenInvalidString_shouldError
{
    NSString *testString = @"sjsdjasdkdsjsdlkdsfsdf";
    NSError *error;
    MSIDLastRequestTelemetry *telemetryObject = [[MSIDLastRequestTelemetry alloc] initWithTelemetryString:testString error:&error];
    
    XCTAssertNil(telemetryObject);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Initialized server telemetry string with invalid string format");
}

-(void)testTelemetryString_whenValidProperties_shouldCreateString
{
    NSString *testString = @"2|0|300,48432850-c45c-486c-a50a-a84cdb220c06,82,a4e7dfa8-5883-426a-96b5-81a325d0abd5|interaction_required, user_cancelled|";
    NSError *error;
    MSIDLastRequestTelemetry *telemetryObject = [[MSIDLastRequestTelemetry alloc] initWithTelemetryString:testString error:&error];
    NSString *result = [telemetryObject telemetryString];
    
    XCTAssertEqualObjects(result, @"2|0|300,48432850-c45c-486c-a50a-a84cdb220c06,82,a4e7dfa8-5883-426a-96b5-81a325d0abd5|interaction_required, user_cancelled|");
}

-(void)testTelemetryString_whenEmptyProperties_shouldCreateString
{
    NSString *testString = @"0|0|,|error|";
    NSError *error;
    MSIDLastRequestTelemetry *telemetryObject = [[MSIDLastRequestTelemetry alloc] initWithTelemetryString:testString error:&error];
    NSString *result = [telemetryObject telemetryString];
    
    // MSIDLastRequestTelemetry.ErrorsInfo.apiId is an NSInteger in our code, so it will be 0 instead of null
    XCTAssertEqualObjects(result, @"0|0|0,|error|");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
