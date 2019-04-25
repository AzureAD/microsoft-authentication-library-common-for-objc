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

#if !MSID_EXCLUDE_SYSTEMWV

#import <XCTest/XCTest.h>
#import "MSIDSystemWebviewController.h"

@interface MSIDSystemWebviewControllerTests : XCTestCase

@end

@implementation MSIDSystemWebviewControllerTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)testInitWithStartURL_whenURLisNil_shouldFail
{
    MSIDSystemWebviewController *webVC = [[MSIDSystemWebviewController alloc] initWithStartURL:nil
                                                                             callbackURLScheme:@"scheme"
                                                                              parentController:nil
                                                                              presentationType:UIModalPresentationFullScreen
                                                                      useAuthenticationSession:YES
                                                                     allowSafariViewController:YES
                                                                                       context:nil];
    XCTAssertNil(webVC);
}


- (void)testInitWithStartURL_whenCallbackURLSchemeisNil_shouldFail
{
    MSIDSystemWebviewController *webVC = [[MSIDSystemWebviewController alloc] initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                                             callbackURLScheme:nil
                                                                              parentController:nil
                                                                              presentationType:UIModalPresentationFullScreen
                                                                      useAuthenticationSession:YES
                                                                     allowSafariViewController:YES
                                                                                       context:nil];
    XCTAssertNil(webVC);

}


- (void)testInitWithStartURL_whenStartURLandCallbackURLSchemeValid_shouldSucceed
{
    MSIDSystemWebviewController *webVC = [[MSIDSystemWebviewController alloc] initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                                             callbackURLScheme:@"scheme"
                                                                              parentController:nil
                                                                              presentationType:UIModalPresentationFullScreen
                                                                      useAuthenticationSession:YES
                                                                     allowSafariViewController:YES
                                                                                       context:nil];
    XCTAssertNotNil(webVC);
    
}

@end

#endif
