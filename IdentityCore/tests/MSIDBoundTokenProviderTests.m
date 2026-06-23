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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <XCTest/XCTest.h>
#import "MSIDBoundTokenProvider.h"
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDError.h"
#import "MSIDConstants.h"
#import "MSIDAADAuthority.h"

@interface MSIDBoundTokenProviderTests : XCTestCase

@end

@implementation MSIDBoundTokenProviderTests

// A production-shaped GetToken request built from the real MSIDBrowserNativeMessageGetTokenRequest properties.
- (MSIDBrowserNativeMessageGetTokenRequest *)validRequest
{
    MSIDBrowserNativeMessageGetTokenRequest *request = [MSIDBrowserNativeMessageGetTokenRequest new];
    request.clientId = @"00000000-0000-0000-0000-000000000001";
    request.redirectUri = @"brk-com.microsoft.test://auth";
    request.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                    rawTenant:nil
                                                      context:nil
                                                        error:nil];
    request.scopes = @"user.read";
    request.state = @"test-state";
    request.prompt = MSIDPromptTypeDefault;
    request.canShowUI = YES;
    request.isSts = NO;
    request.nonce = @"test-nonce";
    request.loginHint = @"user@contoso.com";
    request.instanceAware = NO;
    request.platformSequence = @"oneauth|1.2.3,msal|1.0.0";
    request.extraParameters = @{ @"foo": @"bar" };
    return request;
}

// A GetToken request with no cached tokens cannot be serviced silently, so the provider
// routes to the (not-yet-implemented) interactive broker-flip path and surfaces a clear
// interaction-required signal. This exercises the silent/interactive routing decision.
- (void)testAcquireBoundToken_noCachedToken_routesToInteractive
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];
    XCTestExpectation *expectation = [self expectationWithDescription:@"interaction required"];

    [provider acquireBoundTokenWithRequest:[self validRequest]
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

// A prompt that forces UI must never be serviced silently; it routes straight to the
// interactive path regardless of cached token availability.
- (void)testAcquireBoundToken_promptForcesUI_routesToInteractive
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.prompt = MSIDPromptTypeLogin;

    XCTestExpectation *expectation = [self expectationWithDescription:@"interaction required"];

    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

- (void)testAcquireBoundToken_missingClientId_returnsError
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.clientId = @"";

    XCTestExpectation *expectation = [self expectationWithDescription:@"validation error"];

    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:5.0];
}

@end
