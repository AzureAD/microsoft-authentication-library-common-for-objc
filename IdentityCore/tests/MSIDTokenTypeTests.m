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
#import "MSIDTokenType.h"

@interface MSIDTokenTypeTests : XCTestCase

@end

@implementation MSIDTokenTypeTests

- (void)testTokenTypeAsString_whenAccessTokenType_shouldReturnAccessTokenString
{
    NSString *result = [MSIDTokenTypeHelpers tokenTypeAsString:MSIDTokenTypeAccessToken];
    XCTAssertEqualObjects(result, @"AccessToken");
}

- (void)testTokenTypeAsString_whenRefreshTokenType_shouldReturnRefreshTokenString
{
    NSString *result = [MSIDTokenTypeHelpers tokenTypeAsString:MSIDTokenTypeRefreshToken];
    XCTAssertEqualObjects(result, @"RefreshToken");
}

- (void)testTokenTypeAsString_whenIDTokenType_shouldReturnIDTokenString
{
    NSString *result = [MSIDTokenTypeHelpers tokenTypeAsString:MSIDTokenTypeIDToken];
    XCTAssertEqualObjects(result, @"IdToken");
}

- (void)testTokenTypeAsString_whenADFSTokenType_shouldReturnADFSTokenString
{
    NSString *result = [MSIDTokenTypeHelpers tokenTypeAsString:MSIDTokenTypeLegacyADFSToken];
    XCTAssertEqualObjects(result, @"LegacyADFSToken");
}

- (void)testTokenTypeAsString_whenOtherTokenType_shouldReturnOtherTokenString
{
    NSString *result = [MSIDTokenTypeHelpers tokenTypeAsString:MSIDTokenTypeOther];
    XCTAssertEqualObjects(result, @"Token");
}

- (void)testTokenTypeFromString_whenAccessTokenString_shouldReturnAccessTokenType
{
    MSIDTokenType result = [MSIDTokenTypeHelpers tokenTypeFromString:@"AccessToken"];
    XCTAssertEqual(result, MSIDTokenTypeAccessToken);
}

- (void)testTokenTypeFromString_whenRefreshTokenString_shouldReturnRefreshTokenType
{
    MSIDTokenType result = [MSIDTokenTypeHelpers tokenTypeFromString:@"RefreshToken"];
    XCTAssertEqual(result, MSIDTokenTypeRefreshToken);
}

- (void)testTokenTypeFromString_whenIDTokenString_shouldReturnIDTokenType
{
    MSIDTokenType result = [MSIDTokenTypeHelpers tokenTypeFromString:@"IdToken"];
    XCTAssertEqual(result, MSIDTokenTypeIDToken);
}

- (void)testTokenTypeFromString_whenADFSTokenString_shouldReturnADFSTokenType
{
    MSIDTokenType result = [MSIDTokenTypeHelpers tokenTypeFromString:@"LegacyADFSToken"];
    XCTAssertEqual(result, MSIDTokenTypeLegacyADFSToken);
}

- (void)testTokenTypeFromString_whenOtherTokenString_shouldReturnOtherTokenType
{
    MSIDTokenType result = [MSIDTokenTypeHelpers tokenTypeFromString:@"Token"];
    XCTAssertEqual(result, MSIDTokenTypeOther);
}

@end
