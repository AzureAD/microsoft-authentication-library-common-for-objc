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
#import "MSIDWebProfileInstallTriggerResponse.h"

@interface MSIDWebProfileInstallTriggerResponseTests : XCTestCase

@end

@implementation MSIDWebProfileInstallTriggerResponseTests

- (void)setUp {
    [super setUp];
}

- (void)testInit_whenWrongScheme_shouldReturnNilWithError
{
    NSError *error = nil;
    MSIDWebProfileInstallTriggerResponse *response = [[MSIDWebProfileInstallTriggerResponse alloc] initWithURL:[NSURL URLWithString:@"https://profileInstall"]
                                                                                                    httpResponse:nil
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
    MSIDWebProfileInstallTriggerResponse *response = [[MSIDWebProfileInstallTriggerResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://wronghost"]
                                                                                                    httpResponse:nil
                                                                                                         context:nil
                                                                                                           error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

- (void)testInit_whenCorrectURL_shouldReturnResponse
{
    NSError *error = nil;
    MSIDWebProfileInstallTriggerResponse *response = [[MSIDWebProfileInstallTriggerResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://profileInstall"]
                                                                                                    httpResponse:nil
                                                                                                         context:nil
                                                                                                           error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
}

- (void)testInit_whenCorrectURLWithHeaders_shouldExtractProfileURL
{
    // Create mock HTTP response with headers
    NSDictionary *headers = @{@"X-Profile-Install-URL": @"https://profile.install.url/install"};
    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                  statusCode:302
                                                                 HTTPVersion:@"HTTP/1.1"
                                                                headerFields:headers];
    
    NSError *error = nil;
    MSIDWebProfileInstallTriggerResponse *response = [[MSIDWebProfileInstallTriggerResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://profileInstall"]
                                                                                                    httpResponse:httpResponse
                                                                                                         context:nil
                                                                                                           error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.profileInstallURL, @"https://profile.install.url/install");
}

- (void)testInit_whenCaseInsensitiveHost_shouldReturnResponse
{
    NSError *error = nil;
    MSIDWebProfileInstallTriggerResponse *response = [[MSIDWebProfileInstallTriggerResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://ProfileInstall"]
                                                                                                    httpResponse:nil
                                                                                                         context:nil
                                                                                                           error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
}

- (void)testInit_whenSystemWebviewFormat_shouldReturnResponse
{
    NSError *error = nil;
    // System webview format: myscheme://auth/msauth/profileInstall
    MSIDWebProfileInstallTriggerResponse *response = [[MSIDWebProfileInstallTriggerResponse alloc] initWithURL:[NSURL URLWithString:@"myscheme://auth/msauth/profileInstall"]
                                                                                                    httpResponse:nil
                                                                                                         context:nil
                                                                                                           error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
}

- (void)testInit_whenHeaderCaseInsensitive_shouldExtractProfileURL
{
    // Create mock HTTP response with lowercase header
    NSDictionary *headers = @{@"x-profile-install-url": @"https://profile.install.url/install"};
    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                  statusCode:302
                                                                 HTTPVersion:@"HTTP/1.1"
                                                                headerFields:headers];
    
    NSError *error = nil;
    MSIDWebProfileInstallTriggerResponse *response = [[MSIDWebProfileInstallTriggerResponse alloc] initWithURL:[NSURL URLWithString:@"msauth://profileInstall"]
                                                                                                    httpResponse:httpResponse
                                                                                                         context:nil
                                                                                                           error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.profileInstallURL, @"https://profile.install.url/install");
}

- (void)testOperation_shouldReturnTriggerOperation
{
    NSString *operation = [MSIDWebProfileInstallTriggerResponse operation];
    XCTAssertEqualObjects(operation, @"profile_install_trigger");
}

@end
