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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDCacheKey.h"

@interface MSIDCacheKeyTests : XCTestCase

@end

@implementation MSIDCacheKeyTests

- (void)testInitWithAccountServiceGenericType_shouldInitWithAllParameters
{
    NSString *account = @"account";
    NSString *service = @"service";
    NSData *generic = [@"generic" dataUsingEncoding:NSUTF8StringEncoding];
    NSNumber *type = @125;

    MSIDCacheKey *cacheKey = [[MSIDCacheKey alloc] initWithAccount:account
                                                           service:service
                                                           generic:generic
                                                              type:type];

    XCTAssertEqualObjects(cacheKey.account, account);
    XCTAssertEqualObjects(cacheKey.service, service);
    XCTAssertEqualObjects(cacheKey.generic, generic);
    XCTAssertEqualObjects(cacheKey.type, type);
}

- (void)testFamilyClientId_whenNilFamilyId_shouldReturnDefaultFamilyId
{
    NSString *familyId = nil;
    NSString *familyClientId = [MSIDCacheKey familyClientId:familyId];
    XCTAssertEqualObjects(familyClientId, @"foci-1");
}

- (void)testFamilyClientId_whenNonNilFamilyId_shouldReturnFamilyId
{
    NSString *familyId = [MSIDCacheKey familyClientId:@"test_family_id"];
    XCTAssertEqualObjects(familyId, @"foci-test_family_id");
}

@end
