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
#import "MSIDWebWPJResponse.h"
#import "MSIDWebUpgradeRegResponse.h"
#import "MSIDClientInfo.h"

@interface MSIDWebMSAuthResponseTests : XCTestCase

@end

@implementation MSIDWebMSAuthResponseTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)testInit_whenWrongScheme_shouldReturnNilWithError
{
    NSError *error = nil;
    MSIDWebWPJResponse *response = [[MSIDWebWPJResponse alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://wpj"]]
                                                                           context:nil
                                                                             error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);

    XCTAssertEqualObjects(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}


- (void)testInit_whenMSAuthScheme_shouldReturnResponsewithNoError
{
    NSError *error = nil;
    MSIDWebWPJResponse *response = [[MSIDWebWPJResponse alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"msauth://wpj?app_link=applink&username=user&token_protection_required=true"]]
                                                                           context:nil
                                                                             error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    XCTAssertEqualObjects(response.upn, @"user");
    XCTAssertEqualObjects(response.appInstallLink, @"applink");
    XCTAssertTrue(response.tokenProtectionRequired);

}

- (void)testInit_whenMSAuthScheme_withUpgradeReg_shouldReturnResponsewithNoError
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://upgradeReg?username=XXX@upn.com&client_info="
                  "eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
    MSIDWebUpgradeRegResponse *upgradeResponse = [[MSIDWebUpgradeRegResponse alloc] initWithURL:url
                                                                                        context:nil
                                                                                          error:&error];
    
    XCTAssertNotNil(upgradeResponse);
    XCTAssertNil(error);
    
    XCTAssertTrue([upgradeResponse isKindOfClass:MSIDWebUpgradeRegResponse.class]);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(upgradeResponse.upn, @"XXX@upn.com");
    XCTAssertNotNil(upgradeResponse.clientInfo, @"clientInfo should be valid");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.uid, @"9f4880d8-80ba-4c40-97bc-f7a23c703084");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.utid, @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca");
    XCTAssertNil(upgradeResponse.appInstallLink);
}

@end
