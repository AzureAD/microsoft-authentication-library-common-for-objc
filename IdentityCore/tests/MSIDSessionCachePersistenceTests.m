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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDSessionCachePersistence.h"

static NSString * const kTestSuiteName = @"test.MSIDSessionCachePersistence";
static NSString * const kCacheKey = @"com.microsoft.oneauth.session_correlation_cache";

@interface MSIDSessionCachePersistence ()

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults;

@end

@interface MSIDSessionCachePersistenceTests : XCTestCase

@property (nonatomic) MSIDSessionCachePersistence *persistence;
@property (nonatomic) NSUserDefaults *testDefaults;

@end

@implementation MSIDSessionCachePersistenceTests

- (void)setUp
{
    [super setUp];
    self.testDefaults = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    [self.testDefaults removeObjectForKey:kCacheKey];
    self.persistence = [[MSIDSessionCachePersistence alloc] initWithUserDefaults:self.testDefaults];
}

- (void)tearDown
{
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kTestSuiteName];
    [super tearDown];
}

#pragma mark - Tests

- (void)testLoad_whenKeyAbsent_shouldReturnNil
{
    NSString *result = [self.persistence load];
    XCTAssertNil(result);
}

- (void)testSaveAndLoad_whenValueProvided_shouldRoundTrip
{
    NSString *expected = @"test-session-correlation-data";
    [self.persistence save:expected];

    NSString *result = [self.persistence load];
    XCTAssertEqualObjects(result, expected);
}

- (void)testSave_whenNilValue_shouldRemoveKey
{
    [self.persistence save:@"some-value"];
    [self.persistence save:nil];

    NSString *result = [self.persistence load];
    XCTAssertNil(result);
}

- (void)testSave_whenEmptyString_shouldPersistEmptyString
{
    [self.persistence save:@""];

    NSString *result = [self.persistence load];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result, @"");
}

- (void)testSave_whenCalledMultipleTimes_shouldReturnLatestValue
{
    [self.persistence save:@"first"];
    [self.persistence save:@"second"];

    NSString *result = [self.persistence load];
    XCTAssertEqualObjects(result, @"second");
}

@end
