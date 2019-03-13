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

- (void)testMsidOrderedSetFromString_NormalizeNO_whenSpaceSeparatedString_shouldReturnSeparatedStringWithCasePreserved
{
    NSString *string = @"scoPe1 Scope2   SCOPE3 ";
    NSOrderedSet *set = [NSOrderedSet msidOrderedSetFromString:string normalize:NO];

    XCTAssertTrue(set.count == 3);

    XCTAssertTrue([set containsObject:@"scoPe1"]);
    XCTAssertTrue([set containsObject:@"Scope2"]);
    XCTAssertTrue([set containsObject:@"SCOPE3"]);
}

- (void)testNormalizeOrderedSet_whenNotNormalizedInput_shouldReturnLowerCaseSet
{
    NSOrderedSet *inputSet = [NSOrderedSet orderedSetWithObjects:@"HHH", @" LLL  ", @"xXx", nil];
    NSOrderedSet *expectedResultSet = [NSOrderedSet orderedSetWithObjects:@"hhh", @"lll", @"xxx", nil];
    NSOrderedSet *actualResultSet = [inputSet normalizedScopeSet];
    XCTAssertEqualObjects(expectedResultSet, actualResultSet);
}

- (void)testMinusSet_whenNormalizeNO_andSecondSetEmpty_shouldReturnOriginalSet
{
    NSOrderedSet *inputSet = [NSOrderedSet orderedSetWithObjects:@"HHH", @" LLL  ", @"xXx", nil];
    NSOrderedSet *minusSet = [NSOrderedSet new];
    NSOrderedSet *resultSet = [inputSet msidMinusOrderedSet:minusSet normalize:NO];
    XCTAssertEqualObjects(inputSet, resultSet);
}

- (void)testMinusSet_whenNormalizeNO_andSecondSetContainsItems_shouldReturnModifiedSet
{
    NSOrderedSet *inputSet = [NSOrderedSet orderedSetWithObjects:@"HHH", @" LLL  ", @"xXx", nil];
    NSOrderedSet *minusSet = [NSOrderedSet orderedSetWithObjects:@"HHH", @"xXx", nil];
    NSOrderedSet *resultSet = [inputSet msidMinusOrderedSet:minusSet normalize:NO];
    NSOrderedSet *expectedResultSet = [NSOrderedSet orderedSetWithObjects:@" LLL  ", nil];
    XCTAssertEqualObjects(expectedResultSet, resultSet);
}

- (void)testMinusSet_whenNormalizeNO_andSecondSetContainsOtherItems_shouldReturnOriginalSet
{
    NSOrderedSet *inputSet = [NSOrderedSet orderedSetWithObjects:@"HHH", @" LLL  ", @"xXx", nil];
    NSOrderedSet *minusSet = [NSOrderedSet orderedSetWithObjects:@"llll", @"mmmm", nil];
    NSOrderedSet *resultSet = [inputSet msidMinusOrderedSet:minusSet normalize:NO];
    XCTAssertEqualObjects(inputSet, resultSet);
}

- (void)testMinusSet_whenNormalizeNO_andSecondSetContainsItemsWithDifferentCase_shouldReturnOriginalSet
{
    NSOrderedSet *inputSet = [NSOrderedSet orderedSetWithObjects:@"HHH", @" LLL  ", @"xXx", nil];
    NSOrderedSet *minusSet = [NSOrderedSet orderedSetWithObjects:@"hhh", @"xxx", nil];
    NSOrderedSet *resultSet = [inputSet msidMinusOrderedSet:minusSet normalize:NO];
    XCTAssertEqualObjects(inputSet, resultSet);
}

- (void)testMinusSet_whenNormalizeYES_andSecondSetContainsItems_shouldReturnModifiedSetWithOriginalCase
{
    NSOrderedSet *inputSet = [NSOrderedSet orderedSetWithObjects:@"HHH", @" LLL  ", @"xXx", nil];
    NSOrderedSet *minusSet = [NSOrderedSet orderedSetWithObjects:@"hhh", @" xXX ", nil];
    NSOrderedSet *resultSet = [inputSet msidMinusOrderedSet:minusSet normalize:YES];
    NSOrderedSet *expectedResultSet = [NSOrderedSet orderedSetWithObjects:@" LLL  ", nil];
    XCTAssertEqualObjects(expectedResultSet, resultSet);
}

- (void)testMinusSet_whenNormalizeYES_andSecondSetContainsOtherItems_shouldReturnOriginalSet
{
    NSOrderedSet *inputSet = [NSOrderedSet orderedSetWithObjects:@"HHH", @" LLL  ", @"xXx", nil];
    NSOrderedSet *minusSet = [NSOrderedSet orderedSetWithObjects:@" xYx ", nil];
    NSOrderedSet *resultSet = [inputSet msidMinusOrderedSet:minusSet normalize:YES];
    XCTAssertEqualObjects(inputSet, resultSet);
}

@end
