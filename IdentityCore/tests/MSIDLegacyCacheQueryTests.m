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
#import "MSIDLegacyTokenCacheQuery.h"

@interface MSIDLegacyCacheQueryTests : XCTestCase

@property (nonatomic) NSString *expectedUpn;

@end

@implementation MSIDLegacyCacheQueryTests

- (void)setUp
{
    [super setUp];

    self.expectedUpn = @"test_upn@test_devex.com";
#if TARGET_OS_IPHONE
    self.expectedUpn = @"dGVzdF91cG5AdGVzdF9kZXZleC5jb20";
#endif
}

 - (void)testLegacyQuery_withAllParameters_shouldReturnKey
 {
     NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

     MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
     query.authority = authority;
     query.clientId = @"client";
     query.resource = @"resource";
     query.legacyUserId = @"test_upn@test_devex.com";

     XCTAssertEqualObjects(query.account, self.expectedUpn);
     XCTAssertEqualObjects(query.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|cmVzb3VyY2U|Y2xpZW50");
     XCTAssertEqualObjects(query.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
     XCTAssertNil(query.type);
     XCTAssertTrue(query.exactMatch);
 }

- (void)testLegacyQuery_withNilResource_shouldReturnKey
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    query.authority = authority;
    query.clientId = @"client";
    query.resource = nil;
    query.legacyUserId = @"test_upn@test_devex.com";

    XCTAssertEqualObjects(query.account, self.expectedUpn);
    XCTAssertEqualObjects(query.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|CC3513A0-0E69-4B4D-97FC-DFB6C91EE132|Y2xpZW50");
    XCTAssertEqualObjects(query.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(query.type);
    XCTAssertTrue(query.exactMatch);
}

 - (void)testLegacyQuery_withEmptyAccount_shouldReturnKeyWithEmptyAccount
 {
     NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

     MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
     query.authority = authority;
     query.clientId = @"client";
     query.resource = @"resource";
     query.legacyUserId = @"";

     XCTAssertEqualObjects(query.account, @"");
     XCTAssertEqualObjects(query.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|cmVzb3VyY2U|Y2xpZW50");
     XCTAssertEqualObjects(query.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
     XCTAssertNil(query.type);
     XCTAssertTrue(query.exactMatch);
 }

- (void)testLegacyQuery_withNilAccount_shouldReturnKeyWithNilAccount
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    query.authority = authority;
    query.clientId = @"client";
    query.resource = @"resource";
    query.legacyUserId = nil;

    XCTAssertNil(query.account);
    XCTAssertEqualObjects(query.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|cmVzb3VyY2U|Y2xpZW50");
    XCTAssertEqualObjects(query.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(query.type);
    XCTAssertFalse(query.exactMatch);
}

- (void)testLegacyQuery_withNilAuthority_shouldReturnKeyWithNilService
{
    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    query.authority = nil;
    query.clientId = @"client";
    query.resource = @"resource";
    query.legacyUserId = @"test_upn@test_devex.com";

    XCTAssertEqualObjects(query.account, self.expectedUpn);
    XCTAssertNil(query.service);
    XCTAssertEqualObjects(query.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(query.type);
    XCTAssertFalse(query.exactMatch);
}

- (void)testLegacyQuery_withNilClient_shouldReturnKeyWithNilClient
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

    MSIDLegacyTokenCacheQuery *query = [MSIDLegacyTokenCacheQuery new];
    query.authority = authority;
    query.clientId = nil;
    query.resource = @"resource";
    query.legacyUserId = @"test_upn@test_devex.com";

    XCTAssertEqualObjects(query.account, self.expectedUpn);
    XCTAssertNil(query.service);
    XCTAssertEqualObjects(query.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(query.type);
    XCTAssertFalse(query.exactMatch);
}

@end
