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
#import "MSIDOnboardingReadinessProvider.h"
#if TARGET_OS_IPHONE && !TARGET_OS_VISION
#import "MSIDApplicationTestUtil.h"
#import "MSIDBrokerInteractiveController.h"
#import "MSIDBrokerInvocationOptions.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDTestSwizzle.h"
#endif
#if MSID_ENABLE_SSO_EXTENSION && !TARGET_OS_VISION
#import "MSIDSSOExtensionInteractiveTokenRequestController.h"
#endif

@interface MSIDOnboardingReadinessProviderTests : XCTestCase
@end

@implementation MSIDOnboardingReadinessProviderTests

#if TARGET_OS_IPHONE && !TARGET_OS_VISION
- (void)tearDown
{
    MSIDApplicationTestUtil.canOpenURLSchemes = nil;
    [MSIDApplicationTestUtil reset];
    [MSIDTestSwizzle reset];
    [super tearDown];
}

- (void)testReadiness_usesExistingControllersAndReturnsBooleans
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest:)
                          class:[MSIDBrokerInteractiveController class]
                          block:(id)^BOOL(__unused Class controller, MSIDInteractiveTokenRequestParameters *parameters)
    {
        XCTAssertEqual(parameters.brokerInvocationOptions.minRequiredBrokerType, MSIDRequiredBrokerTypeWithNonceSupport);
        return YES;
    }];
#if MSID_ENABLE_SSO_EXTENSION && !TARGET_OS_VISION
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                          class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                          block:(id)^BOOL(__unused Class controller)
    {
        return YES;
    }];
#endif
    MSIDOnboardingReadiness *readiness = [MSIDOnboardingReadinessProvider new].readiness;
    XCTAssertNotNil(readiness);
    XCTAssertTrue(readiness.brokerAvailability);
#if MSID_ENABLE_SSO_EXTENSION && !TARGET_OS_VISION
    XCTAssertTrue(readiness.ssoExtensionAvailability);
#else
    XCTAssertFalse(readiness.ssoExtensionAvailability);
#endif
    XCTAssertEqualObjects(readiness.jsonDictionary[@"brokerAvailability"], @YES);
    XCTAssertNil(readiness.jsonDictionary[@"unknownReasons"]);
}

- (void)testReadiness_whenControllerCannotPerformRequest_returnsFalse
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest:)
                          class:[MSIDBrokerInteractiveController class]
                          block:(id)^BOOL(__unused Class controller, __unused MSIDInteractiveTokenRequestParameters *parameters)
    {
        return NO;
    }];
#if MSID_ENABLE_SSO_EXTENSION && !TARGET_OS_VISION
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                          class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                          block:(id)^BOOL(__unused Class controller)
    {
        return NO;
    }];
#endif
    MSIDOnboardingReadiness *readiness = [MSIDOnboardingReadinessProvider new].readiness;
    XCTAssertNotNil(readiness);
    XCTAssertFalse(readiness.brokerAvailability);
    XCTAssertFalse(readiness.ssoExtensionAvailability);
    XCTAssertEqualObjects(readiness.jsonDictionary[@"brokerAvailability"], @NO);
    XCTAssertEqualObjects(readiness.jsonDictionary[@"ssoExtensionAvailability"], @NO);
}

- (void)testReadiness_whenBrokerOptionsCannotBeCreated_fails
{
    [MSIDTestSwizzle instanceMethod:@selector(initWithRequiredBrokerType:protocolType:aadRequestVersion:)
                             class:[MSIDBrokerInvocationOptions class]
                             block:(id)^id(__unused MSIDBrokerInvocationOptions *options,
                                          __unused MSIDRequiredBrokerType brokerType,
                                          __unused MSIDBrokerProtocolType protocolType,
                                          __unused MSIDBrokerAADRequestVersion aadRequestVersion)
    {
        return nil;
    }];
    XCTAssertNil([MSIDOnboardingReadinessProvider new].readiness);
}

#if !AD_BROKER
- (void)testReadiness_whenBrokerSchemeIsMissing_returnsFalse
{
    MSIDApplicationTestUtil.canOpenURLSchemes = @[@"msauthv2"];
    MSIDOnboardingReadiness *readiness = [MSIDOnboardingReadinessProvider new].readiness;
    XCTAssertNotNil(readiness);
    XCTAssertFalse(readiness.brokerAvailability);
}

- (void)testReadiness_whenCalledOffMainThread_completesBrokerCheck
{
    MSIDApplicationTestUtil.canOpenURLSchemes = @[@"msauthv2", @"msauthv3"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Background readiness completes"];
    __block MSIDOnboardingReadiness *readiness = nil;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        readiness = [MSIDOnboardingReadinessProvider new].readiness;
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertTrue(readiness.brokerAvailability);
}
#endif
#endif

@end
