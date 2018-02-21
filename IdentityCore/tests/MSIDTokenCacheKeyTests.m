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
    MSIDTokenCacheKey *msidTokenCacheKey = [MSIDTokenCacheKey keyWithAuthority:[[NSURL alloc] initWithString:@"https://login.windows.net/contoso.com"] clientId:@"c3c7f5e5-7153-44d4-90e6-329686d48d76" resource:@"resource" upn:@"eric_cartman@contoso.com"];
    
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(@"ZXJpY19jYXJ0bWFuQGNvbnRvc28uY29t", msidTokenCacheKey.account);
#elif
    XCTAssertEqualObjects(@"eric_cartman@contoso.com", msidTokenCacheKey.account);
#endif
    
    XCTAssertEqualObjects(@"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi53aW5kb3dzLm5ldC9jb250b3NvLmNvbQ|cmVzb3VyY2U|YzNjN2Y1ZTUtNzE1My00NGQ0LTkwZTYtMzI5Njg2ZDQ4ZDc2", msidTokenCacheKey.service);
}

@end
