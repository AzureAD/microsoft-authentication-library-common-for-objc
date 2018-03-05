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
#import "MSIDLegacyTokenCacheKey.h"

@interface MSIDLegacyCacheKeyTests : XCTestCase

@end

@implementation MSIDLegacyCacheKeyTests

- (void)testLegacyTokenCacheKey_withAllParameters_shouldReturnKey
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    MSIDLegacyTokenCacheKey *legacyKey = [MSIDLegacyTokenCacheKey keyWithAuthority:authority
                                                                          clientId:@"client"
                                                                          resource:@"resource"
                                                                      legacyUserId:@"user"];
    XCTAssertEqualObjects(legacyKey.account, @"user");
    XCTAssertEqualObjects(legacyKey.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|Y21WemIzVnlZMlU|Y2xpZW50");
    XCTAssertEqualObjects(legacyKey.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(legacyKey.type);
}

- (void)testLegacyTokenCacheKey_whenNoResource_shouldReturnKey
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    MSIDLegacyTokenCacheKey *legacyKey = [MSIDLegacyTokenCacheKey keyWithAuthority:authority
                                                                          clientId:@"client"
                                                                          resource:nil
                                                                      legacyUserId:@"user"];
    XCTAssertEqualObjects(legacyKey.account, @"user");
    XCTAssertEqualObjects(legacyKey.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|CC3513A0-0E69-4B4D-97FC-DFB6C91EE132|Y2xpZW50");
    XCTAssertEqualObjects(legacyKey.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(legacyKey.type);
}

- (void)testLegacyQuery_withAllParameters_shouldReturnKey
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    MSIDLegacyTokenCacheKey *legacyKey = [MSIDLegacyTokenCacheKey queryWithAuthority:authority
                                                                            clientId:@"client"
                                                                            resource:@"resource"
                                                                        legacyUserId:@"user"];
    XCTAssertEqualObjects(legacyKey.account, @"user");
    XCTAssertEqualObjects(legacyKey.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|Y21WemIzVnlZMlU|Y2xpZW50");
    XCTAssertEqualObjects(legacyKey.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(legacyKey.type);
}

- (void)testLegacyQuery_withEmptyAccount_shouldReturnKeyWithEmptyAccount
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    MSIDLegacyTokenCacheKey *legacyKey = [MSIDLegacyTokenCacheKey queryWithAuthority:authority
                                                                            clientId:@"client"
                                                                            resource:@"resource"
                                                                        legacyUserId:@""];
    XCTAssertEqualObjects(legacyKey.account, @"");
    XCTAssertEqualObjects(legacyKey.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|Y21WemIzVnlZMlU|Y2xpZW50");
    XCTAssertEqualObjects(legacyKey.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(legacyKey.type);
}

- (void)testLegacyQuery_withNilAccount_shouldReturnKeyWithNilAccount
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    MSIDLegacyTokenCacheKey *legacyKey = [MSIDLegacyTokenCacheKey queryWithAuthority:authority
                                                                            clientId:@"client"
                                                                            resource:@"resource"
                                                                        legacyUserId:nil];
    XCTAssertNil(legacyKey.account);
    XCTAssertEqualObjects(legacyKey.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|Y21WemIzVnlZMlU|Y2xpZW50");
    XCTAssertEqualObjects(legacyKey.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(legacyKey.type);
}

@end
