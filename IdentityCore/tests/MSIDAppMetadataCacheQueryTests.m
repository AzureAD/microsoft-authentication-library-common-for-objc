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
#import "MSIDAppMetadataCacheQuery.h"

@interface MSIDAppMetadataCacheQueryTests : XCTestCase

@end

@implementation MSIDAppMetadataCacheQueryTests

- (void)testAppMetadataCacheQuery_withAllParameters_shouldReturnKey
{
    MSIDAppMetadataCacheQuery *query = [[MSIDAppMetadataCacheQuery alloc] initWithClientId:@"client"
                                                                               environment:@"login.microsoftonline.com"
                                                                                  familyId:@"1" generalType:MSIDAppMetadataType];
    
    XCTAssertEqualObjects(query.clientId, @"client");
    XCTAssertEqualObjects(query.service, @"appmetadata-client");
    XCTAssertEqualObjects(query.type, @3001);
    XCTAssertEqualObjects(query.account, @"login.microsoftonline.com");
    XCTAssertEqualObjects(query.generic, [@"1" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertTrue(query.exactMatch);
}

- (void)testAppMetadataCacheQuery_whenClientIdSetButNoTypeisProvided_shouldReturnNoExactMatch
{
    MSIDAppMetadataCacheQuery *query = [MSIDAppMetadataCacheQuery new];
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"login.microsoftonline.com");
    XCTAssertEqualObjects(query.service, nil);
    XCTAssertNil(query.type);
    XCTAssertNil(query.generic);
}

- (void)testAppMetadataCacheQuery_whenNoEnvironment_shouldReturnNoExactMatch
{
    MSIDAppMetadataCacheQuery *query = [MSIDAppMetadataCacheQuery new];
    query.clientId = @"client";
    query.generalType = MSIDAppMetadataType;

    XCTAssertFalse(query.exactMatch);
    XCTAssertNil(query.account);
    XCTAssertEqualObjects(query.service, @"appmetadata-client");
    XCTAssertEqualObjects(query.type, @3001);
    XCTAssertNil(query.generic);
}

@end
