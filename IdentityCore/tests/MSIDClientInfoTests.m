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
#import "MSIDClientInfo.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDClientInfoTests : XCTestCase

@end

@implementation MSIDClientInfoTests

- (void)testInitWithRawClientInfo_whenUidAndUtid_shouldParse
{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    
    NSError *error = nil;
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(clientInfo);
    XCTAssertEqualObjects(clientInfo.uid, @"1");
    XCTAssertEqualObjects(clientInfo.utid, @"1234-5678-90abcdefg");
}

- (void)testInitWithRawClientInfo_whenBadJson_shouldReturnNilWithError
{
    NSString *base64String = @"badclientinfo";
    
    NSError *error = nil;
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(clientInfo);
}

- (void)testAccountIdentifier_whenHomeAccountId_shouldReturnUserIndentifier
{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    
    NSError *error = nil;
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(clientInfo);
    XCTAssertEqualObjects(clientInfo.accountIdentifier, @"1.1234-5678-90abcdefg");
}

#pragma mark - Copy tests

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    
    NSError *error = nil;
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:&error];
    MSIDClientInfo *clientInfoCopy = [clientInfo copy];
    
    XCTAssertEqualObjects(clientInfo, clientInfoCopy);
}

@end
