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
#import "MSIDAuthenticationScheme.h"
#import "MSIDConstants.h"
#import "MSIDAccessToken.h"
#import "MSIDTelemetryAPIEvent.h"
#import "MSIDTelemetryEventStrings.h"

@interface MSIDAuthenticationSchemeTest : XCTestCase

@end

@implementation MSIDAuthenticationSchemeTest

- (void)test_whenDefaultInit_shouldReturnBearerScheme
{
    MSIDAuthenticationScheme *scheme = [[MSIDAuthenticationScheme alloc] init];
    [self test_assertDefaultAttributesInScheme:scheme];
}

- (void)test_whenInitWithEmptySchemeParameters_shouldReturnBearerScheme
{
    MSIDAuthenticationScheme *scheme = [[MSIDAuthenticationScheme alloc] initWithSchemeParameters: [self prepareBearerSchemeParams]];
    [self test_assertDefaultAttributesInScheme:scheme];
}

- (void)test_whenInitBearerScheme_shouldMatchingThumbprintAlwaysYes
{
    MSIDAuthenticationScheme *scheme = [[MSIDAuthenticationScheme alloc] initWithSchemeParameters:[self prepareBearerSchemeParams]];
    XCTAssertEqual([scheme matchAccessTokenKeyThumbprint:[MSIDAccessToken new]], YES);
}

- (void)test_whenInitBearerParameters_shouldAccessTokenNoKid
{
    MSIDAuthenticationScheme *scheme = [[MSIDAuthenticationScheme alloc] initWithSchemeParameters:[self prepareBearerSchemeParams]];
    XCTAssertNil(scheme.accessToken.kid);
}

- (void)testConfigureTelemetryEvent_whenBaseScheme_shouldLeavePopKeySourceUnset
{
    MSIDAuthenticationScheme *scheme = [[MSIDAuthenticationScheme alloc] initWithSchemeParameters:[self prepareBearerSchemeParams]];
    MSIDTelemetryAPIEvent *event = [[MSIDTelemetryAPIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_API_EVENT context:nil];

    [scheme configureTelemetryEvent:event];

    XCTAssertNil([event propertyWithName:MSID_TELEMETRY_KEY_POP_KEY_SOURCE]);
}

- (void) test_assertDefaultAttributesInScheme:(MSIDAuthenticationScheme *) scheme
{
    XCTAssertEqual(scheme.authScheme, MSIDAuthSchemeBearer);
    XCTAssertEqual(scheme.credentialType, MSIDAccessTokenType);
    XCTAssertNil(scheme.tokenType);
    XCTAssertNil(scheme.accessToken.kid);
}

- (NSDictionary *)prepareBearerSchemeParams
{
    return [NSMutableDictionary new];
}

@end
