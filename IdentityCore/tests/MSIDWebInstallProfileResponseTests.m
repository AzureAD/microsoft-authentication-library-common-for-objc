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
#import "MSIDWebInstallProfileResponse.h"

@interface MSIDWebInstallProfileResponseTests : XCTestCase

@end

@implementation MSIDWebInstallProfileResponseTests

- (void)setUp {
    [super setUp];
}

- (void)testInit_whenWrongScheme_shouldReturnNilWithError
{
    NSError *error = nil;
    MSIDWebInstallProfileResponse *response = [[MSIDWebInstallProfileResponse alloc] initWithURL:[NSURL URLWithString:@"https://profileInstalled"]
                                                                                          context:nil
                                                                                            error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);

    XCTAssertEqualObjects(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testInit_whenWrongHost_shouldReturnNilWithError
{
    NSError *error = nil;
    MSIDWebInstallProfileResponse *response = [[MSIDWebInstallProfileResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://wronghost?status=success"]
                                                                                          context:nil
                                                                                            error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);

    XCTAssertEqualObjects(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testInit_whenMSAuthScheme_shouldReturnResponseWithNoError
{
    NSError *error = nil;
    MSIDWebInstallProfileResponse *response = [[MSIDWebInstallProfileResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://profileInstalled?status=success"]
                                                                                          context:nil
                                                                                            error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    XCTAssertEqualObjects(response.status, @"success");
    XCTAssertNotNil(response.additionalInfo);
}

- (void)testInit_whenMSAuthScheme_withAdditionalParams_shouldReturnResponseWithNoError
{
    NSError *error = nil;
    MSIDWebInstallProfileResponse *response = [[MSIDWebInstallProfileResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://profileInstalled?status=success&profile_id=12345&user=test@example.com"]
                                                                                          context:nil
                                                                                            error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    XCTAssertEqualObjects(response.status, @"success");
    XCTAssertNotNil(response.additionalInfo);
    XCTAssertEqualObjects(response.additionalInfo[@"profile_id"], @"12345");
    XCTAssertEqualObjects(response.additionalInfo[@"user"], @"test@example.com");
}

- (void)testInit_whenMSAuthScheme_caseInsensitiveHost_shouldReturnResponseWithNoError
{
    NSError *error = nil;
    MSIDWebInstallProfileResponse *response = [[MSIDWebInstallProfileResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://ProfileInstalled?status=success"]
                                                                                          context:nil
                                                                                            error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    XCTAssertEqualObjects(response.status, @"success");
}

- (void)testInit_whenSystemWebviewFormat_shouldReturnResponseWithNoError
{
    NSError *error = nil;
    // System webview format: myscheme://auth/msauth/profileInstalled?status=success
    MSIDWebInstallProfileResponse *response = [[MSIDWebInstallProfileResponse alloc] initWithURL:[NSURL URLWithString:@"myscheme://auth/msauth/profileInstalled?status=success"]
                                                                                          context:nil
                                                                                            error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    XCTAssertEqualObjects(response.status, @"success");
}

- (void)testInit_whenFailureStatus_shouldReturnResponseWithNoError
{
    NSError *error = nil;
    MSIDWebInstallProfileResponse *response = [[MSIDWebInstallProfileResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://profileInstalled?status=failed&error_code=500"]
                                                                                          context:nil
                                                                                            error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    XCTAssertEqualObjects(response.status, @"failed");
    XCTAssertEqualObjects(response.additionalInfo[@"error_code"], @"500");
}

- (void)testOperation_shouldReturnInstallProfile
{
    NSString *operation = [MSIDWebInstallProfileResponse operation];
    XCTAssertEqualObjects(operation, @"install_profile");
}

@end
