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

@interface MSIDBoundTokenProviderTests : XCTestCase

@end

@implementation MSIDBoundTokenProviderTests

- (MSIDBrowserNativeMessageGetTokenRequest *)validRequest
{
    MSIDBrowserNativeMessageGetTokenRequest *request = [MSIDBrowserNativeMessageGetTokenRequest new];
    request.clientId = @"00000000-0000-0000-0000-000000000001";
    request.redirectUri = @"brk-com.microsoft.test://auth";
    request.scopes = @"user.read";
    request.state = @"test-state";
    return request;
}

// A GetToken request handed to the provider is serviced entirely in-process,
// returning a payload, with no SSO extension / ASAuthorization involvement.
- (void)testAcquireBoundToken_inProc_returnsPayload
{
    MSIDBoundTokenProvider *provider = [MSIDBoundTokenProvider new];
    XCTestExpectation *expectation = [self expectationWithDescription:@"in-proc completion"];

    [provider acquireBoundTokenWithRequest:[self validRequest]
                                   context:nil
                           completionBlock:^(NSString *response, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertTrue([response containsString:@"in_proc_common_core"]);
        XCTAssertTrue([response containsString:@"MSIDBoundTokenProvider"]);
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
