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
#import "MSIDWebAADAuthResponse.h"

@interface MSIDWebAADAuthResponseTests : XCTestCase

@end

@implementation MSIDWebAADAuthResponseTests

MSIDWebUIStateVerifier stateVerifierNO = ^BOOL(NSDictionary *dictionary, NSString *requestState) {
    return NO;
};
MSIDWebUIStateVerifier stateVerifierYES = ^BOOL(NSDictionary *dictionary, NSString *requestState) {
    return YES;
};

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)testInit_whenStateVerifierSucceedsWithValidParams_shouldReturnResponse
{
    NSError *error;
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithParameters:@{
                                                                                            MSID_OAUTH2_CODE : @"code",
                                                                                            MSID_OAUTH2_STATE : @"state",
                                                                                            MSID_AUTH_CLOUD_INSTANCE_HOST_NAME : @"cloudHost"
                                                                                            }
                                                                             requestState:@"state"
                                                                            stateVerifier:stateVerifierYES context:nil error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.authorizationCode, @"code");
    XCTAssertEqualObjects(response.cloudHostName, @"cloudHost");
}


- (void)testInit_whenStateVerifierFailsWithValidParams_shouldReturnNilWithError
{
    NSError *error;
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithParameters:@{
                                                                                            MSID_OAUTH2_CODE : @"code",
                                                                                            MSID_OAUTH2_STATE : @"state",
                                                                                            MSID_AUTH_CLOUD_INSTANCE_HOST_NAME : @"cloudHost"
                                                                                            }
                                                                             requestState:@"state"
                                                                            stateVerifier:stateVerifierNO context:nil error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    
    XCTAssertEqualObjects(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidState);
}

- (void)testInit_whenStateVerifierMissingWithValidParams_shouldReturnResponse
{
    NSError *error;
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithParameters:@{
                                                                                            MSID_OAUTH2_CODE : @"code",
                                                                                            MSID_OAUTH2_STATE : @"state",
                                                                                            MSID_AUTH_CLOUD_INSTANCE_HOST_NAME : @"cloudHost"
                                                                                            }
                                                                             requestState:@"state"
                                                                            stateVerifier:nil context:nil error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.authorizationCode, @"code");
    XCTAssertEqualObjects(response.cloudHostName, @"cloudHost");
}



@end
