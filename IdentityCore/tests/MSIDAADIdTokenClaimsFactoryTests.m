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
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDAADIdTokenClaimsFactoryTests : XCTestCase

@end

@implementation MSIDAADIdTokenClaimsFactoryTests

- (void)testClaimsFromRawIDToken_whenAADV2IDToken_shouldReturnAADV2Claims
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"test" subject:@"sub" givenName:@"name" familyName:@"name2" name:@"name name2" version:@"2.0"];

    NSError *error = nil;
    MSIDIdTokenClaims *claims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken error:&error];
    XCTAssertTrue([claims isKindOfClass:[MSIDAADV2IdTokenClaims class]]);
    XCTAssertNil(error);
}

- (void)testClaimsFromRawIDToken_whenAADV1IDToken_shouldReturnAADV1Claims
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"test" subject:@"sub" givenName:@"name" familyName:@"name2" name:@"name name2" version:@"1.0"];

    NSError *error = nil;
    MSIDIdTokenClaims *claims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken error:&error];
    XCTAssertTrue([claims isKindOfClass:[MSIDAADV1IdTokenClaims class]]);
    XCTAssertNil(error);
}

- (void)testClaimsForRawIDToken_whenAADV1IDToken_withoutVerClaim_withUPNClaim_shouldReturnAADV1Claims
{
    NSString *idTokenp1 = [@{ @"typ": @"JWT", @"alg": @"RS256", @"kid": @"_kid_value"} msidBase64UrlJson];
    NSString *idTokenp2 = [@{ @"iss" : @"issuer",
                              @"preferred_username" : @"username",
                              @"sub" : @"sub",
                              @"tid": @"tenantId",
                              @"upn": @"upn"
                              } msidBase64UrlJson];
    NSString *idToken = [NSString stringWithFormat:@"%@.%@.%@", idTokenp1, idTokenp2, idTokenp1];

    NSError *error = nil;
    MSIDIdTokenClaims *claims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken error:&error];
    XCTAssertTrue([claims isKindOfClass:[MSIDAADV1IdTokenClaims class]]);
    XCTAssertNil(error);
}

- (void)testClaimsForRawIDToken_whenAADV1IDToken_withoutVerClaim_withUniqueNameClaim_shouldReturnAADV1Claims
{
    NSString *idTokenp1 = [@{ @"typ": @"JWT", @"alg": @"RS256", @"kid": @"_kid_value"} msidBase64UrlJson];
    NSString *idTokenp2 = [@{ @"iss" : @"issuer",
                              @"preferred_username" : @"username",
                              @"sub" : @"sub",
                              @"tid": @"tenantId",
                              @"unique_name": @"unique name"
                              } msidBase64UrlJson];
    NSString *idToken = [NSString stringWithFormat:@"%@.%@.%@", idTokenp1, idTokenp2, idTokenp1];

    NSError *error = nil;
    MSIDIdTokenClaims *claims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken error:&error];
    XCTAssertTrue([claims isKindOfClass:[MSIDAADV1IdTokenClaims class]]);
    XCTAssertNil(error);
}

- (void)testClaimsForRawIDToken_whenAADV2IDToken_withUPNClaim_shouldReturnAADV2Claims
{
    NSString *idTokenp1 = [@{ @"typ": @"JWT", @"alg": @"RS256", @"kid": @"_kid_value"} msidBase64UrlJson];
    NSString *idTokenp2 = [@{ @"iss" : @"issuer",
                              @"preferred_username" : @"username",
                              @"sub" : @"sub",
                              @"ver": @"2.0",
                              @"tid": @"tenantId",
                              @"upn": @"upn"
                              } msidBase64UrlJson];
    NSString *idToken = [NSString stringWithFormat:@"%@.%@.%@", idTokenp1, idTokenp2, idTokenp1];

    NSError *error = nil;
    MSIDIdTokenClaims *claims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken error:&error];
    XCTAssertTrue([claims isKindOfClass:[MSIDAADV2IdTokenClaims class]]);
    XCTAssertNil(error);
}

- (void)testClaimsFromRawIDToken_whenNonAADIDToken_shouldReturnIDTokenClaims
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"test" subject:@"sub"];

    NSError *error = nil;
    MSIDIdTokenClaims *claims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken error:&error];
    XCTAssertTrue([claims isKindOfClass:[MSIDIdTokenClaims class]]);
    XCTAssertFalse([claims isKindOfClass:[MSIDAADV2IdTokenClaims class]]);
    XCTAssertFalse([claims isKindOfClass:[MSIDAADV1IdTokenClaims class]]);
    XCTAssertNil(error);
}

@end
