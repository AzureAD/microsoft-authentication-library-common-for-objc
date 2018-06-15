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
#import "MSIDIdTokenClaims.h"

@interface MSIDIdTokenClaimsTests : XCTestCase

@end

@implementation MSIDIdTokenClaimsTests

- (void)testInitWithRawIdToken_whenInvalidJSONInOnePart_shouldReturnNilNonNilError
{
    NSString *testIdToken = @"W10.e30.";
    NSError *error = nil;
    MSIDIdTokenClaims *claims = [[MSIDIdTokenClaims alloc] initWithRawIdToken:testIdToken error:&error];
    XCTAssertNil(claims);
    XCTAssertNotNil(error);
}

- (void)testInitWithRawIdToken_whenNonDictionaryJSONInOnePart_shouldReturnNilNonNilError
{
    NSString *testIdToken = @"e30.e30.";
    NSError *error = nil;
    MSIDIdTokenClaims *claims = [[MSIDIdTokenClaims alloc] initWithRawIdToken:testIdToken error:&error];
    XCTAssertNil(claims);
    XCTAssertNil(claims);
}

- (void)testInitWithRawIdToken_whenNilToken_shouldReturnNilAndNonNilError
{
    NSError *error = nil;
    MSIDIdTokenClaims *claims = [[MSIDIdTokenClaims alloc] initWithRawIdToken:nil error:&error];
    XCTAssertNil(claims);
    XCTAssertNotNil(error);
}

- (void)testInitWithRawIdToken_whenValidIDToken_andUnsignedWithTwoParts_shouldReturnNoNilClaimsNilError
{
    NSString *testIdToken = @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlRlc3QiLCJpYXQiOjE1MTYyMzkwMjJ9";
    NSError *error = nil;
    MSIDIdTokenClaims *claims = [[MSIDIdTokenClaims alloc] initWithRawIdToken:testIdToken error:&error];
    XCTAssertNotNil(claims);
    XCTAssertNil(error);
    XCTAssertNotNil([claims jsonDictionary]);
    XCTAssertEqualObjects([claims jsonDictionary][@"name"], @"Test");
    XCTAssertEqualObjects([claims jsonDictionary][@"sub"], @"1234567890");
    XCTAssertEqualObjects([claims jsonDictionary][@"iat"], @1516239022);
}

- (void)testInitWithRawIdToken_whenValidIDToken_andUnsigned_shouldReturnNoNilClaimsNilError
{
    NSString *testIdToken = @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlRlc3QiLCJpYXQiOjE1MTYyMzkwMjJ9.";
    NSError *error = nil;
    MSIDIdTokenClaims *claims = [[MSIDIdTokenClaims alloc] initWithRawIdToken:testIdToken error:&error];
    XCTAssertNotNil(claims);
    XCTAssertNil(error);
    XCTAssertNotNil([claims jsonDictionary]);
    XCTAssertEqualObjects([claims jsonDictionary][@"name"], @"Test");
    XCTAssertEqualObjects([claims jsonDictionary][@"sub"], @"1234567890");
    XCTAssertEqualObjects([claims jsonDictionary][@"iat"], @1516239022);
}

- (void)testInitWithRawIdToken_whenValidIDToken_andSigned_shouldReturnNoNilClaimsNilError
{
    NSString *testIdToken = @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlRlc3QiLCJpYXQiOjE1MTYyMzkwMjJ9.N8AkaYjoO2a_G5vpSKJxL-YCPWfX47VWoUzLwneVb8Y";
    NSError *error = nil;
    MSIDIdTokenClaims *claims = [[MSIDIdTokenClaims alloc] initWithRawIdToken:testIdToken error:&error];
    XCTAssertNotNil(claims);
    XCTAssertNil(error);
    XCTAssertNotNil([claims jsonDictionary]);
    XCTAssertEqualObjects([claims jsonDictionary][@"name"], @"Test");
    XCTAssertEqualObjects([claims jsonDictionary][@"sub"], @"1234567890");
    XCTAssertEqualObjects([claims jsonDictionary][@"iat"], @1516239022);
}

@end
