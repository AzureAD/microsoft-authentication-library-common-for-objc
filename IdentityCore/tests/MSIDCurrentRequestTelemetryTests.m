//
//  MSIDCurrentRequestTelemetryTests.m
//  IdentityCore
//
//  Created by Mihai Petriuc on 5/1/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

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
