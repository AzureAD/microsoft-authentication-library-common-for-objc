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
#import "MSIDCredentialType.h"

@interface MSIDCredentialTypeTests : XCTestCase

@end

@implementation MSIDCredentialTypeTests

- (void)testcredentialTypeAsString_whenAccessTokenType_shouldReturnAccessTokenString
{
    NSString *result = [MSIDCredentialTypeHelpers credentialTypeAsString:MSIDAccessTokenType];
    XCTAssertEqualObjects(result, @"AccessToken");
}

- (void)testcredentialTypeAsString_whenRefreshTokenType_shouldReturnRefreshTokenString
{
    NSString *result = [MSIDCredentialTypeHelpers credentialTypeAsString:MSIDRefreshTokenType];
    XCTAssertEqualObjects(result, @"RefreshToken");
}

- (void)testcredentialTypeAsString_whenIDTokenType_shouldReturnIDTokenString
{
    NSString *result = [MSIDCredentialTypeHelpers credentialTypeAsString:MSIDIDTokenType];
    XCTAssertEqualObjects(result, @"IdToken");
}

- (void)testcredentialTypeAsString_whenLegacyTokenType_shouldReturnLegacyTokenString
{
    NSString *result = [MSIDCredentialTypeHelpers credentialTypeAsString:MSIDLegacySingleResourceTokenType];
    XCTAssertEqualObjects(result, @"LegacySingleResourceToken");
}

- (void)testcredentialTypeAsString_whenOtherTokenType_shouldReturnOtherTokenString
{
    NSString *result = [MSIDCredentialTypeHelpers credentialTypeAsString:MSIDCredentialTypeOther];
    XCTAssertEqualObjects(result, @"token");
}

- (void)testTokenTypeFromString_whenAccessTokenString_shouldReturnAccessTokenType
{
    MSIDCredentialType result = [MSIDCredentialTypeHelpers credentialTypeFromString:@"AccessToken"];
    XCTAssertEqual(result, MSIDAccessTokenType);
}

- (void)testTokenTypeFromString_whenRefreshTokenString_shouldReturnRefreshTokenType
{
    MSIDCredentialType result = [MSIDCredentialTypeHelpers credentialTypeFromString:@"RefreshToken"];
    XCTAssertEqual(result, MSIDRefreshTokenType);
}

- (void)testTokenTypeFromString_whenIDTokenString_shouldReturnIDTokenType
{
    MSIDCredentialType result = [MSIDCredentialTypeHelpers credentialTypeFromString:@"IdToken"];
    XCTAssertEqual(result, MSIDIDTokenType);
}

- (void)testTokenTypeFromString_whenLegacyTokenString_shouldReturnLegacyTokenType
{
    MSIDCredentialType result = [MSIDCredentialTypeHelpers credentialTypeFromString:@"LegacySingleResourceToken"];
    XCTAssertEqual(result, MSIDLegacySingleResourceTokenType);
}

- (void)testTokenTypeFromString_whenOtherTokenString_shouldReturnOtherTokenType
{
    MSIDCredentialType result = [MSIDCredentialTypeHelpers credentialTypeFromString:@"token"];
    XCTAssertEqual(result, MSIDCredentialTypeOther);
}

@end
