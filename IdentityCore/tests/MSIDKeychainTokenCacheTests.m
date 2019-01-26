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
#import "MSIDKeychainTokenCache.h"

@interface MSIDKeychainTokenCache (testUtil)

- (NSString *)extractAppKey:(NSString *)cacheKeyString;

@end

@interface MSIDKeychainTokenCacheTests : XCTestCase

@end

@implementation MSIDKeychainTokenCacheTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testExtractAppKey_whenNilKeyString_shouldReturnNil
{
    MSIDKeychainTokenCache *cache = [MSIDKeychainTokenCache new];
    
    XCTAssertNil([cache extractAppKey:nil]);
}

- (void)testExtractAppKey_whenEmptyKeyString_shouldReturnNil
{
    MSIDKeychainTokenCache *cache = [MSIDKeychainTokenCache new];

    XCTAssertNil([cache extractAppKey:@""]);
}

- (void)testExtractAppKey_whenInvalidKeyStringWithoutDelimiter_shouldReturnNil
{
    MSIDKeychainTokenCache *cache = [MSIDKeychainTokenCache new];

    XCTAssertNil([cache extractAppKey:@"abc"]);
}

- (void)testExtractAppKey_whenInvalidKeyStringWithIncorrectNumberOfDelimiters_shouldReturnNil
{
    MSIDKeychainTokenCache *cache = [MSIDKeychainTokenCache new];

    XCTAssertNil([cache extractAppKey:@"abc|d|e"]);
    XCTAssertNil([cache extractAppKey:@"abc|d|e|f|g|i|j"]);
}

- (void)testExtractAppKey_whenEmptyAppKey_shouldReturnNil
{
    MSIDKeychainTokenCache *cache = [MSIDKeychainTokenCache new];
    
    XCTAssertNil([cache extractAppKey:@"MSOpenTech.ADAL.1|aHR0cHM6Ly9s|aHR0cHM6Ly9tc2|NGIwZGI4YzItOWYyNi00NDE3|"]);
}

- (void)testExtractAppKey_whenLegacyKeyString_shouldReturnAppKey
{
    MSIDKeychainTokenCache *cache = [MSIDKeychainTokenCache new];

    XCTAssertEqualObjects([cache extractAppKey:@"MSOpenTech.ADAL.1|aHR0cHM6Ly9s|aHR0cHM6Ly9tc2|NGIwZGI4YzItOWYyNi00NDE3|LThiZGUtM2YwZTM2NTZmOGUw"], @"LThiZGUtM2YwZTM2NTZmOGUw");
}

- (void)testExtractAppKey_whenDefaultKeyString_shouldReturnAppKey
{
    MSIDKeychainTokenCache *cache = [MSIDKeychainTokenCache new];
    
    XCTAssertEqualObjects([cache extractAppKey:@"accesstoken-b6c69a37-df96-4db0-f645ad92-e38d--openid profile email calendars.read tasks.read user.read|LThiZGUtM2YwZTM2NTZmOGUw"], @"LThiZGUtM2YwZTM2NTZmOGUw");
}

@end
