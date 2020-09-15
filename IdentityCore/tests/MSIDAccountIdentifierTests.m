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
#import "MSIDAccountIdentifier.h"

@interface MSIDAccountIdentifierTests : XCTestCase

@end

@implementation MSIDAccountIdentifierTests

- (void)testInitWithJSONDictionary_whenNoDisplayableAndHomeAccountIDs_shouldReturnError
{
    NSDictionary *json = @{};
    
    NSError *error;
    __auto_type identifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(identifier);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Failed to init MSIDAccountIdentifier from json: displayableId and homeAccountId are nil.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitWithJSONDictionary_whenDisplayableIDOnly_shouldInit
{
    NSDictionary *json = @{
        @"username": @"user@contoso.com",
    };
    
    NSError *error;
    __auto_type identifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(identifier);
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"user@contoso.com", identifier.displayableId);
    XCTAssertNil(identifier.homeAccountId);
}

- (void)testInitWithJSONDictionary_whenHomeAccountIDOnly_shouldInit
{
    NSDictionary *json = @{
        @"home_account_id": @"1.1234-5678-90abcdefg",
    };
    
    NSError *error;
    __auto_type identifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(identifier);
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"1.1234-5678-90abcdefg", identifier.homeAccountId);
    XCTAssertNil(identifier.displayableId);
}

- (void)testInitWithJSONDictionary_whenDisplayableAndHomeAccountIDs_shouldInitAndNormalize
{
    NSDictionary *json = @{
        @"username": @"user@contoso.com",
        @"home_account_id": @"1.1234-5678-90ABCdefg",
    };
    
    NSError *error;
    __auto_type identifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNotNil(identifier);
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"1.1234-5678-90abcdefg", identifier.homeAccountId);
    XCTAssertEqualObjects(@"user@contoso.com", identifier.displayableId);
}

- (void)testJsonDictionary_whenNoIDsSet_shouldReturnNil
{
    __auto_type identifier = [MSIDAccountIdentifier new];
    
    NSDictionary *json = [identifier jsonDictionary];
    
    XCTAssertNil(json);
}

- (void)testJsonDictionary_whenAllIDsSet_shouldReturnNormalizedJson
{
    __auto_type identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                                    homeAccountId:@"1.1234-5678-90abcdEFG"];
    
    NSDictionary *json = [identifier jsonDictionary];
    
    XCTAssertEqual(2, json.allKeys.count);
    XCTAssertEqualObjects(json[@"username"], @"user@contoso.com");
    XCTAssertEqualObjects(json[@"home_account_id"], @"1.1234-5678-90abcdefg");
}

- (void)testJsonDictionary_whenHomeAccountIDOnly_shouldReturnJson
{
    __auto_type identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil
                                                                    homeAccountId:@"1.1234-5678-90abcdefg"];
    
    NSDictionary *json = [identifier jsonDictionary];
    
    XCTAssertEqual(1, json.allKeys.count);
    XCTAssertEqualObjects(json[@"home_account_id"], @"1.1234-5678-90abcdefg");
}

- (void)testJsonDictionary_whenHomeDisplayableIDOnly_shouldReturnJson
{
    __auto_type identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                                    homeAccountId:nil];
    
    NSDictionary *json = [identifier jsonDictionary];
    
    XCTAssertEqual(1, json.allKeys.count);
    XCTAssertEqualObjects(json[@"username"], @"user@contoso.com");
}

@end
