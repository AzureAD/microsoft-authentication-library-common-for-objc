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
#import "MSIDWebWPJAuthResponse.h"

@interface MSIDWebWPJResponseTests : XCTestCase

@end

@implementation MSIDWebWPJResponseTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)testInit_whenWrongScheme_shouldReturnNilWithError
{
    NSError *error = nil;
    MSIDWebWPJAuthResponse *response = [[MSIDWebWPJAuthResponse alloc] initWithScheme:@"https"
                                                                           parameters:nil context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    
    XCTAssertEqualObjects(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidParameter);
}

- (void)testInit_whenAppLinkMissing_shouldReturnNilWithError
{
    NSError *error = nil;
    MSIDWebWPJAuthResponse *response = [[MSIDWebWPJAuthResponse alloc] initWithScheme:@"msauth"
                                                                           parameters:@{} context:nil error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    
    XCTAssertEqualObjects(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidParameter);
}

- (void)testInit_whenGoodInput_shouldReturnResponsewithNoError
{
    NSError *error = nil;
    MSIDWebWPJAuthResponse *response = [[MSIDWebWPJAuthResponse alloc] initWithScheme:@"msauth"
                                                                           parameters:@{
                                                                                        @"app_link":@"https://link",
                                                                                        @"upn":@"user@sample.com"
                                                                                        }
                                                                              context:nil
                                                                                error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.upn, @"user@sample.com");
    XCTAssertEqualObjects(response.appInstallLink, @"https://link");   

}

@end
