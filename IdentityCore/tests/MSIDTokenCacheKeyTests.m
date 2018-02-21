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
#import "MSIDTokenCacheKey.h"

@interface MSIDTokenCacheKeyTests : XCTestCase

@end

@implementation MSIDTokenCacheKeyTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Tests

- (void)testKeyWithAuthorityClientIdResourceUpn_shouldCreateKeyWithAccountAndService
{
    MSIDTokenCacheKey *msidTokenCacheKey = [MSIDTokenCacheKey keyWithAuthority:[[NSURL alloc] initWithString:@"https://contoso.com"] clientId:@"client_id_value" resource:@"resource_value" upn:@"eric_cartman@contoso.com"];
    
    XCTAssertEqualObjects(@"eric_cartman@contoso.com", msidTokenCacheKey.account);
    XCTAssertEqualObjects(@"MSOpenTech.ADAL.1|aHR0cHM6Ly9jb250b3NvLmNvbQ|Y21WemIzVnlZMlZmZG1Gc2RXVQ|Y2xpZW50X2lkX3ZhbHVl", msidTokenCacheKey.service);
}

@end
