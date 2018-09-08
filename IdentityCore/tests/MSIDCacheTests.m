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
#import "MSIDCache.h"

@interface MSIDCacheTests : XCTestCase

@end

@implementation MSIDCacheTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Tests

- (void)testInit_countShouldBe0
{
    __auto_type cache = [MSIDCache new];
    
    XCTAssertEqual([cache count], 0);
}

- (void)testGetObject_whenKeyIsNil_shouldReturnNil
{
    __auto_type cache = [MSIDCache new];
    id key = nil;
    
    id result = [cache objectForKey:key];
    
    XCTAssertNil(result);
}

- (void)testSetObject_whenSetSuccessfully_shouldReturnSameOnObjectForKey
{
    __auto_type cache = [MSIDCache new];
    
    [cache setObject:@"v1" forKey:@"k1"];
    id object = [cache objectForKey:@"k1"];
    
    XCTAssertEqual([cache count], 1);
    XCTAssertEqualObjects(object, @"v1");
}

- (void)testSetObject_whenObjectNil_shouldRemoteItFromCache
{
    __auto_type cache = [MSIDCache new];
    
    [cache setObject:@"v1" forKey:@"k1"];
    [cache setObject:nil forKey:@"k1"];
    
    XCTAssertEqual([cache count], 0);
}

- (void)testRemoveObjectForKey_whenObjectInCache_shouldRemoveObject
{
    __auto_type cache = [MSIDCache new];
    
    [cache setObject:@"v1" forKey:@"k1"];
    [cache setObject:@"v2" forKey:@"k2"];
    
    [cache removeObjectForKey:@"k1"];
    
    id object1 = [cache objectForKey:@"k1"];
    id object2 = [cache objectForKey:@"k2"];
    
    XCTAssertEqual([cache count], 1);
    XCTAssertNil(object1);
    XCTAssertEqualObjects(object2, @"v2");
}

- (void)testRemoveAllObjects_whenCacheContainsObjects_shouldRemoveAll
{
    __auto_type cache = [MSIDCache new];
    
    [cache setObject:@"v1" forKey:@"k1"];
    [cache setObject:@"v2" forKey:@"k2"];
    
    [cache removeAllObjects];
    
    id object1 = [cache objectForKey:@"k1"];
    id object2 = [cache objectForKey:@"k2"];
    
    XCTAssertEqual([cache count], 0);
    XCTAssertNil(object1);
    XCTAssertNil(object2);
}

@end
