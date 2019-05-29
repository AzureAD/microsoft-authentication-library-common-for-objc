//
//  MSIDDictionaryExtensionsTests.m
//  IdentityCore
//
//  Created by Olga Dalton on 5/29/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSDictionary+MSIDExtensions.h"

@interface MSIDDictionaryExtensionsTests : XCTestCase

@end

@implementation MSIDDictionaryExtensionsTests

- (void)testMSIDNormalizedDictionary_whenNoNulls_returnDictionary
{
    NSDictionary *input = @{@"test1": @"test2", @"tets3": @"test4"};
    NSDictionary *result = [input msidNormalizedJSONDictionary];
    XCTAssertEqualObjects(input, result);
}

- (void)testMSIDNormalizedDictionary_whenDictionaryContainsNulls_returnNormalizedDictionary
{
    NSDictionary *input = @{@"test1": @"test2", @"test3": @"test4", @"null-test": [NSNull null]};
    NSDictionary *expectedResult = @{@"test1": @"test2", @"test3": @"test4"};
    NSDictionary *result = [input msidNormalizedJSONDictionary];
    XCTAssertEqualObjects(expectedResult, result);
}

- (void)testMSIDNormalizedDictionary_whenDictionaryContainsDictionariesWithNulls_returnNormalizedDictionary
{
    NSDictionary *input = @{@"test1":@"test2", @"test3": @"test4", @"test5": @{@"test1": [NSNull null], @"test2": @"test3", @"test4": @{@"test5": [NSNull null]}}};
    NSDictionary *expectedResult = @{@"test1":@"test2", @"test3": @"test4", @"test5": @{@"test2": @"test3", @"test4": @{}}};
    NSDictionary *result = [input msidNormalizedJSONDictionary];
    XCTAssertEqualObjects(expectedResult, result);
}

- (void)testMSIDNornalizedDictionary_whenDictionaryContainsArraysWithDictionariesWithNulls_returnNormalizedDictionary
{
    NSDictionary *input = @{@"input1": @"test2", @"test3": @[[NSNull null], @{@"test1": @{@"test1": [NSNull null], @"test3": @"test4"}}]};
    NSDictionary *expectedResult = @{@"input1": @"test2", @"test3": @[@{@"test1": @{@"test3": @"test4"}}]};
    NSDictionary *result = [input msidNormalizedJSONDictionary];
    XCTAssertEqualObjects(expectedResult, result);
}

@end
