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
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAADIdTokenClaimsFactory.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSIDAADV1IdTokenClaims.h"
#import "MSIDIdTokenClaims.h"

@interface MSIDAADIdTokenClaimsFactoryTests : XCTestCase

@end

@implementation MSIDAADIdTokenClaimsFactoryTests

- (void)testClaimsFromRawIDToken_whenAADV2IDToken_shouldReturnAADV2Claims
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"test" subject:@"sub" givenName:@"name" familyName:@"name2" version:@"2.0"];

    MSIDIdTokenClaims *claims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken];
    XCTAssertTrue([claims isKindOfClass:[MSIDAADV2IdTokenClaims class]]);
}

- (void)testClaimsFromRawIDToken_whenAADV1IDToken_shouldReturnAADV1Claims
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"test" subject:@"sub" givenName:@"name" familyName:@"name2" version:@"1.0"];

    MSIDIdTokenClaims *claims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken];
    XCTAssertTrue([claims isKindOfClass:[MSIDAADV1IdTokenClaims class]]);
}

- (void)testClaimsFromRawIDToken_whenNonAADIDToken_shouldReturnIDTokenClaims
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"test" subject:@"sub"];

    MSIDIdTokenClaims *claims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken];
    XCTAssertTrue([claims isKindOfClass:[MSIDIdTokenClaims class]]);
    XCTAssertFalse([claims isKindOfClass:[MSIDAADV2IdTokenClaims class]]);
    XCTAssertFalse([claims isKindOfClass:[MSIDAADV1IdTokenClaims class]]);
}

@end
