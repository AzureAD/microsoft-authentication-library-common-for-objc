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

@property (nonatomic) NSString *expectedUpn;

@end

@implementation MSIDLegacyCacheKeyTests

- (void)setUp
{
    [super setUp];
    
    self.expectedUpn = @"test_upn@test_devex.com";
#if TARGET_OS_IPHONE
    self.expectedUpn = @"dGVzdF91cG5AdGVzdF9kZXZleC5jb20";
#endif
}

- (void)testLegacyTokenCacheKey_withAllParameters_shouldReturnKey
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

    MSIDLegacyTokenCacheKey *legacyKey = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                   clientId:@"client"
                                                                                   resource:@"resource"
                                                                               legacyUserId:@"test_upn@test_devex.com"];

    XCTAssertEqualObjects(legacyKey.account, self.expectedUpn);
    XCTAssertEqualObjects(legacyKey.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|cmVzb3VyY2U|Y2xpZW50");
    XCTAssertEqualObjects(legacyKey.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(legacyKey.type);
}

- (void)testLegacyTokenCacheKey_withAllParametersUpperCase_shouldReturnKeyLowerCase
{
    NSURL *authority = [NSURL URLWithString:@"https://loGin.microsoftonline.com/common"];

    MSIDLegacyTokenCacheKey *legacyKey = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                   clientId:@"clIENt"
                                                                                   resource:@"reSOURce"
                                                                               legacyUserId:@"TEst_upn@test_DEVEX.com"];
    XCTAssertEqualObjects(legacyKey.account, self.expectedUpn);
    XCTAssertEqualObjects(legacyKey.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|cmVzb3VyY2U|Y2xpZW50");
    XCTAssertEqualObjects(legacyKey.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(legacyKey.type);
}

- (void)testLegacyTokenCacheKey_whenNoResource_shouldReturnKey
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    MSIDLegacyTokenCacheKey *legacyKey = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                   clientId:@"client"
                                                                                   resource:nil
                                                                               legacyUserId:@"test_upn@test_devex.com"];
    XCTAssertEqualObjects(legacyKey.account, self.expectedUpn);
    XCTAssertEqualObjects(legacyKey.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|CC3513A0-0E69-4B4D-97FC-DFB6C91EE132|Y2xpZW50");
    XCTAssertEqualObjects(legacyKey.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(legacyKey.type);
}

- (void)testCopy_withAllAttributes_shouldReturnKey
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

    MSIDLegacyTokenCacheKey *legacyKey = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                   clientId:@"client"
                                                                                   resource:@"resource"
                                                                               legacyUserId:@"test_upn@test_devex.com"];

    MSIDLegacyTokenCacheKey *copiedKey = [legacyKey copy];

    XCTAssertEqualObjects(copiedKey.account, self.expectedUpn);
    XCTAssertEqualObjects(copiedKey.service, @"MSOpenTech.ADAL.1|aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg|cmVzb3VyY2U|Y2xpZW50");
    XCTAssertEqualObjects(copiedKey.generic, [@"MSOpenTech.ADAL.1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(copiedKey.type);
}

- (void)testIsEqual_whenAllAttributesEqual_shouldReturnYES
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

    MSIDLegacyTokenCacheKey *legacyKey1 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                   clientId:@"client"
                                                                                   resource:@"resource"
                                                                               legacyUserId:@"test_upn@test_devex.com"];

    MSIDLegacyTokenCacheKey *legacyKey2 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                    clientId:@"client"
                                                                                    resource:@"resource"
                                                                                legacyUserId:@"test_upn@test_devex.com"];

    XCTAssertEqualObjects(legacyKey1, legacyKey2);
}

- (void)testIsEqual_whenAuthorityNotEqual_shouldReturnNO
{
    NSURL *authority1 = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    NSURL *authority2 = [NSURL URLWithString:@"https://login.windows.com/common"];

    MSIDLegacyTokenCacheKey *legacyKey1 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority1
                                                                                    clientId:@"client"
                                                                                    resource:@"resource"
                                                                                legacyUserId:@"test_upn@test_devex.com"];

    MSIDLegacyTokenCacheKey *legacyKey2 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority2
                                                                                    clientId:@"client"
                                                                                    resource:@"resource"
                                                                                legacyUserId:@"test_upn@test_devex.com"];

    XCTAssertNotEqualObjects(legacyKey1, legacyKey2);
}

- (void)testIsEqual_whenClientIdNotEqual_shouldReturnNO
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

    MSIDLegacyTokenCacheKey *legacyKey1 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                    clientId:@"client1"
                                                                                    resource:@"resource"
                                                                                legacyUserId:@"test_upn@test_devex.com"];

    MSIDLegacyTokenCacheKey *legacyKey2 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                    clientId:@"client2"
                                                                                    resource:@"resource"
                                                                                legacyUserId:@"test_upn@test_devex.com"];

    XCTAssertNotEqualObjects(legacyKey1, legacyKey2);
}

- (void)testIsEqual_whenResourceNotEqual_shouldReturnNO
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

    MSIDLegacyTokenCacheKey *legacyKey1 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                    clientId:@"client1"
                                                                                    resource:@"resource1"
                                                                                legacyUserId:@"test_upn@test_devex.com"];

    MSIDLegacyTokenCacheKey *legacyKey2 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                    clientId:@"client2"
                                                                                    resource:@"resource2"
                                                                                legacyUserId:@"test_upn@test_devex.com"];

    XCTAssertNotEqualObjects(legacyKey1, legacyKey2);
}

- (void)testIsEqual_whenLegacyUserIdNotEqual_shouldReturnNO
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

    MSIDLegacyTokenCacheKey *legacyKey1 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                    clientId:@"client1"
                                                                                    resource:@"resource1"
                                                                                legacyUserId:@"test_upn@test_devex.com"];

    MSIDLegacyTokenCacheKey *legacyKey2 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                    clientId:@"client2"
                                                                                    resource:@"resource2"
                                                                                legacyUserId:@"test_upn2@test_devex.com"];

    XCTAssertNotEqualObjects(legacyKey1, legacyKey2);
}

- (void)testEncoding_andDecoding_shouldDecodeSameObject
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];

    MSIDLegacyTokenCacheKey *legacyKey1 = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:authority
                                                                                    clientId:@"client"
                                                                                    resource:@"resource"
                                                                                legacyUserId:@"test_upn@test_devex.com"];

    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:legacyKey1];

    XCTAssertNotNil(archivedData);

    MSIDLegacyTokenCacheKey *legacyKey2 = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];

    XCTAssertNotNil(legacyKey2);
    XCTAssertEqualObjects(legacyKey1, legacyKey2);
}


@end
