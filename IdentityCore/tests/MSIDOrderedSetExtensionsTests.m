//
//  MSIDOrderedSetExtensionsTests.m
//  IdentityCore
//
//  Created by Jason Kim on 9/4/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSOrderedSet+MSIDExtensions.h"

@interface MSIDOrderedSetExtensionsTests : XCTestCase

@end

@implementation MSIDOrderedSetExtensionsTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testMsidOrderedSetFromString_whenNilString_shouldReturnEmptySet
{
    NSString *string = nil;
    NSOrderedSet *set = [NSOrderedSet msidOrderedSetFromString:string];
    
    XCTAssertTrue(set.count == 0);
}

- (void)testMsidOrderedSetFromString_whenSpaceSeparatedStrings_shouldReturnSeparatedStrings
{
    NSString *string = @"scope1 scope2   scope3";
    NSOrderedSet *set = [NSOrderedSet msidOrderedSetFromString:string];
    
    XCTAssertTrue(set.count == 3);
    
    XCTAssertTrue([set containsObject:@"scope1"]);
    XCTAssertTrue([set containsObject:@"scope2"]);
    XCTAssertTrue([set containsObject:@"scope3"]);
}

@end
