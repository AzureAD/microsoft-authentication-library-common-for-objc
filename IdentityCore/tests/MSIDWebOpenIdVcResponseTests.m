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
#import "MSIDWebOpenIdVcResponse.h"
#import "MSIDWebResponseOperationConstants.h"

@interface MSIDWebOpenIdVcResponseTests : XCTestCase
@end

@implementation MSIDWebOpenIdVcResponseTests

- (void)testInitWithURL_whenSchemeIsNotOpenIdVc_shouldReturnNilWithError
{
    NSError *error = nil;
    MSIDWebOpenIdVcResponse *response = [[MSIDWebOpenIdVcResponse alloc] initWithURL:[NSURL URLWithString:@"https://somehost"]
                                                                              context:nil
                                                                                error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testInitWithURL_whenSchemeIsOpenIdVc_shouldSucceedAndStoreURL
{
    NSURL *url = [NSURL URLWithString:@"openid-vc://credential-offer?credential_issuer=https%3A%2F%2Fexample.com&credential_configuration_ids=VerifiedEmployee"];

    NSError *error = nil;
    MSIDWebOpenIdVcResponse *response = [[MSIDWebOpenIdVcResponse alloc] initWithURL:url
                                                                              context:nil
                                                                                error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.openIdVcURL, url);
}

- (void)testInitWithURL_whenSchemeIsOpenIdVcMixedCase_shouldSucceedAndStoreURL
{
    NSURL *url = [NSURL URLWithString:@"OPENID-VC://mock.com/?request_uri=https://mock.com"];

    NSError *error = nil;
    MSIDWebOpenIdVcResponse *response = [[MSIDWebOpenIdVcResponse alloc] initWithURL:url
                                                                              context:nil
                                                                                error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.openIdVcURL, url);
}

- (void)testInitWithURL_whenSchemeIsBrowser_shouldReturnNilWithError
{
    NSError *error = nil;
    MSIDWebOpenIdVcResponse *response = [[MSIDWebOpenIdVcResponse alloc] initWithURL:[NSURL URLWithString:@"browser://somehost"]
                                                                              context:nil
                                                                                error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testOperation_shouldReturnOpenIdVcOperationConstant
{
    XCTAssertEqualObjects([MSIDWebOpenIdVcResponse operation], MSID_OPEN_OPENID_VC_OPERATION);
}

@end
