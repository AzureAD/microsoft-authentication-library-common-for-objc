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
#import "MSIDAppMetadataCacheKey.h"

@interface MSIDAppMetadataCacheKeyTests : XCTestCase

@end

@implementation MSIDAppMetadataCacheKeyTests

- (void)testAppMetadataCacheKey_withFamilyId_shouldReturnKey
{
    MSIDAppMetadataCacheKey *appMetadataKey = [[MSIDAppMetadataCacheKey alloc] initWithClientId:@"client"
                                                                                    environment:@"login.microsoftonline.com"
                                                                                       familyId:@"1" generalType:MSIDAppMetadataType];
    
    XCTAssertEqualObjects(appMetadataKey.account, @"login.microsoftonline.com");
    XCTAssertEqualObjects(appMetadataKey.service, @"appmetadata-client");
    XCTAssertEqualObjects(appMetadataKey.type, @3001);
    NSData *genericData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(appMetadataKey.generic, genericData);
}

- (void)testAppMetadataCacheKey_withNil_FamilyId_shouldReturnKeyWithNil_Generic
{
    MSIDAppMetadataCacheKey *appMetadataKey = [[MSIDAppMetadataCacheKey alloc] initWithClientId:@"client"
                                                                                    environment:@"login.microsoftonline.com"
                                                                                       familyId:nil
                                                                                    generalType:MSIDAppMetadataType];
    
    XCTAssertEqualObjects(appMetadataKey.account, @"login.microsoftonline.com");
    XCTAssertEqualObjects(appMetadataKey.service, @"appmetadata-client");
    XCTAssertEqualObjects(appMetadataKey.type, @3001);
    XCTAssertNil(appMetadataKey.generic);
}

@end
