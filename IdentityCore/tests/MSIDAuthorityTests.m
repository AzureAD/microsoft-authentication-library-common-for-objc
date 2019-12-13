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
#import "MSIDAuthority+Internal.h"

@interface MSIDTestsAuthority : MSIDAuthority

@end

@implementation MSIDTestsAuthority

@end

@interface MSIDAuthorityTests : XCTestCase

@end

@implementation MSIDAuthorityTests

- (void)testJsonDictionary_whenUrlSet_shouldReturnJson
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSIDTestsAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    NSDictionary *json = [authority jsonDictionary];
    
    XCTAssertEqual(1, json.allKeys.count);
    XCTAssertEqualObjects(json[@"authority"], @"https://login.microsoftonline.com/common");
}

- (void)testInitWithJSONDictionary_whenAuthorityProvided_shouldInitResponse
{
    NSDictionary *json = @{
        @"authority": @"https://login.microsoftonline.com/common",
    };
    
    NSError *error;
    __auto_type authority = [[MSIDAuthority alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/common", authority.url.absoluteString);
}

- (void)testInitWithJSONDictionary_whenNoAuthority_shouldReturnError
{
    NSDictionary *json = @{};
    
    NSError *error;
    __auto_type authority = [[MSIDAuthority alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Failed to init MSIDAuthority from json: authority is either nil or not a url.", error.userInfo[MSIDErrorDescriptionKey]);
}

@end
