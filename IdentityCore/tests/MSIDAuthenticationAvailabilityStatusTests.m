//------------------------------------------------------------------------------
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
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDAuthenticationAvailabilityStatus.h"

@interface MSIDAuthenticationAvailabilityStatus (Testing)

- (instancetype)initWithBrokerAppAvailabilityProbe:(BOOL (^)(void))brokerAppAvailabilityProbe
                     ssoExtensionAvailabilityProbe:(BOOL (^)(void))ssoExtensionAvailabilityProbe;

@end

@interface MSIDAuthenticationAvailabilityStatusTests : XCTestCase

@end

@implementation MSIDAuthenticationAvailabilityStatusTests

- (void)testInit_whenBothCapabilitiesAreAvailable_shouldExposeBothValues
{
    MSIDAuthenticationAvailabilityStatus *status = [[MSIDAuthenticationAvailabilityStatus alloc]
        initWithBrokerAppAvailabilityProbe:^BOOL
        {
            return YES;
        }
        ssoExtensionAvailabilityProbe:^BOOL
        {
            return YES;
        }];

    XCTAssertTrue(status.brokerAppAvailable);
    XCTAssertTrue(status.ssoExtensionAvailable);
    XCTAssertEqualObjects(status.statusDictionary, (@{
        @"brokerAppAvailable" : @YES,
        @"ssoExtensionAvailable" : @YES
    }));
}

- (void)testInit_whenCapabilitiesAreUnavailable_shouldExposeBothValues
{
    MSIDAuthenticationAvailabilityStatus *status = [[MSIDAuthenticationAvailabilityStatus alloc]
        initWithBrokerAppAvailabilityProbe:^BOOL
        {
            return NO;
        }
        ssoExtensionAvailabilityProbe:^BOOL
        {
            return NO;
        }];

    XCTAssertFalse(status.brokerAppAvailable);
    XCTAssertFalse(status.ssoExtensionAvailable);
    XCTAssertEqualObjects(status.statusDictionary, (@{
        @"brokerAppAvailable" : @NO,
        @"ssoExtensionAvailable" : @NO
    }));
}

- (void)testInit_whenCalledOffMainThread_shouldProbeBrokerOnMainThread
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Status completed"];
    __block BOOL brokerProbedOnMainThread = NO;
    __block MSIDAuthenticationAvailabilityStatus *status = nil;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^
    {
        status = [[MSIDAuthenticationAvailabilityStatus alloc]
            initWithBrokerAppAvailabilityProbe:^BOOL
            {
                brokerProbedOnMainThread = NSThread.isMainThread;
                return YES;
            }
            ssoExtensionAvailabilityProbe:^BOOL
            {
                return NO;
            }];
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertTrue(brokerProbedOnMainThread);
    XCTAssertTrue(status.brokerAppAvailable);
    XCTAssertFalse(status.ssoExtensionAvailable);
}

@end
