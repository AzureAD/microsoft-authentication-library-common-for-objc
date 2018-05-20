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
#import "MSIDDefaultAccountCacheQuery.h"

@interface MSIDDefaultAccountCacheQueryTests : XCTestCase

@end

@implementation MSIDDefaultAccountCacheQueryTests

- (void)testAccountCacheQuery_withAllParameters_shouldReturnKey
{
    MSIDDefaultAccountCacheQuery *query = [[MSIDDefaultAccountCacheQuery alloc] initWithHomeAccountId:@"uid.utid"
                                                                                        environment:@"login.microsoftonline.com"
                                                                                              realm:@"contoso.com"
                                                                                               type:MSIDAccountTypeMSSTS];

    query.username = @"username";

    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(query.service, @"contoso.com");
    XCTAssertEqualObjects(query.type, @1003);
    XCTAssertEqualObjects(query.generic, [@"username" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertTrue(query.exactMatch);
}

- (void)testAccountCacheQuery_whenNoHomeAccountId_shouldReturnNoExactMatch
{
    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    query.accountType = MSIDAccountTypeMSSTS;

    XCTAssertFalse(query.exactMatch);
    XCTAssertNil(query.account);
    XCTAssertEqualObjects(query.service, @"contoso.com");
    XCTAssertEqualObjects(query.type, @1003);
    XCTAssertNil(query.generic);
}

- (void)testAccountCacheQuery_whenNoEnvironment_shouldReturnNoExactMatch
{
    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.realm = @"contoso.com";
    query.accountType = MSIDAccountTypeMSSTS;

    XCTAssertFalse(query.exactMatch);
    XCTAssertNil(query.account);
    XCTAssertEqualObjects(query.service, @"contoso.com");
    XCTAssertEqualObjects(query.type, @1003);
    XCTAssertNil(query.generic);
}

- (void)testAccountCacheQuery_whenNoRealm_shouldReturnNoExactMatch
{
    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.accountType = MSIDAccountTypeMSSTS;

    XCTAssertFalse(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(query.type, @1003);
    XCTAssertNil(query.generic);
}

@end
