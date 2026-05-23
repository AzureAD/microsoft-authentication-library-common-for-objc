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
#import "MSIDDeviceTokenResponseHandler.h"
#import "MSIDRequestParameters.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDOauth2Factory.h"
#import "MSIDAuthenticationScheme.h"
#import "MSIDTokenResult.h"
#import "MSIDDeviceTokenResponseHandler.h"

@interface MSIDDeviceTokenResponseHandlerTests : XCTestCase

@end

@implementation MSIDDeviceTokenResponseHandlerTests

#pragma mark - init

- (void)testInit_whenValidParameters_shouldReturnNonNilHandler
{
    // Arrange
    MSIDRequestParameters *requestParameters = [MSIDRequestParameters new];
    requestParameters.clientId = @"test-client-id";
    MSIDOauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    // Act
    MSIDDeviceTokenResponseHandler *handler = [[MSIDDeviceTokenResponseHandler alloc] initWithRequestParameters:requestParameters
                                                                                                   oauthFactory:factory];

    // Assert
    XCTAssertNotNil(handler);
}

#pragma mark - handleTokenResponse: error path

- (void)testHandleTokenResponse_whenErrorProvided_shouldReturnErrorInCompletionBlock
{
    // Arrange
    MSIDRequestParameters *requestParameters = [MSIDRequestParameters new];
    requestParameters.clientId = @"test-client-id";
    MSIDOauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDDeviceTokenResponseHandler *handler = [[MSIDDeviceTokenResponseHandler alloc] initWithRequestParameters:requestParameters
                                                                                                   oauthFactory:factory];

    NSError *inputError = [NSError errorWithDomain:@"TestDomain" code:42 userInfo:@{NSLocalizedDescriptionKey: @"Test error"}];

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];

    // Act
    [handler handleTokenResponse:@{}
                         context:requestParameters
                           error:inputError
                 completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        // Assert
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, 42);
        XCTAssertEqualObjects(error.domain, @"TestDomain");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
@end

