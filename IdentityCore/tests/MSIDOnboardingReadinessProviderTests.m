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
#import "MSIDBrokerInvocationOptions.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#endif

@interface MSIDOnboardingReadinessProviderTests : XCTestCase
@end

@implementation MSIDOnboardingReadinessProviderTests

#if TARGET_OS_IPHONE && !TARGET_OS_VISION
- (void)tearDown
{
    MSIDApplicationTestUtil.canOpenURLSchemes = nil;
    [MSIDApplicationTestUtil reset];
    [super tearDown];
}

- (void)testReadiness_usesExistingControllersAndReturnsBooleans
{
    __block NSUInteger brokerChecks = 0;
    __block NSUInteger ssoChecks = 0;
    MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
        initWithBrokerOptionsFactory:nil
             brokerAvailabilityCheck:^BOOL(MSIDInteractiveTokenRequestParameters *parameters) {
                 brokerChecks++;
                 XCTAssertEqual(parameters.brokerInvocationOptions.minRequiredBrokerType,
                                MSIDRequiredBrokerTypeWithNonceSupport);
                 XCTAssertEqual(parameters.brokerInvocationOptions.protocolType, MSIDBrokerProtocolTypeCustomScheme);
                 XCTAssertEqual(parameters.brokerInvocationOptions.brokerAADRequestVersion, MSIDBrokerAADRequestVersionV2);
                 return YES;
             }
      ssoExtensionAvailabilityCheck:^BOOL{
          ssoChecks++;
          return YES;
      }];
    MSIDOnboardingReadiness *readiness = provider.readiness;
    XCTAssertNotNil(readiness);
    XCTAssertTrue(readiness.brokerAvailability);
#if MSID_ENABLE_SSO_EXTENSION
    XCTAssertTrue(readiness.ssoExtensionAvailability);
    XCTAssertEqual(ssoChecks, 1u);
#else
    XCTAssertFalse(readiness.ssoExtensionAvailability);
    XCTAssertEqual(ssoChecks, 0u);
#endif
    XCTAssertEqual(brokerChecks, 1u);
    XCTAssertEqualObjects(readiness.jsonDictionary[@"brokerAvailability"], @YES);
    XCTAssertNil(readiness.jsonDictionary[@"unknownReasons"]);
}

- (void)testReadiness_whenControllerCannotPerformRequest_returnsFalse
{
    MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
        initWithBrokerOptionsFactory:nil
             brokerAvailabilityCheck:^BOOL(__unused MSIDInteractiveTokenRequestParameters *parameters) {
                 return NO;
             }
      ssoExtensionAvailabilityCheck:^BOOL{
          return NO;
      }];
    MSIDOnboardingReadiness *readiness = provider.readiness;
    XCTAssertNotNil(readiness);
    XCTAssertFalse(readiness.brokerAvailability);
    XCTAssertFalse(readiness.ssoExtensionAvailability);
    XCTAssertEqualObjects(readiness.jsonDictionary[@"brokerAvailability"], @NO);
    XCTAssertEqualObjects(readiness.jsonDictionary[@"ssoExtensionAvailability"], @NO);
}

- (void)testReadiness_whenBrokerOptionsCannotBeCreated_fails
{
    __block NSUInteger brokerChecks = 0;
    __block NSUInteger ssoChecks = 0;
    MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
        initWithBrokerOptionsFactory:^MSIDBrokerInvocationOptions *{
            return nil;
        }
             brokerAvailabilityCheck:^BOOL(__unused MSIDInteractiveTokenRequestParameters *parameters) {
                 brokerChecks++;
                 return YES;
             }
      ssoExtensionAvailabilityCheck:^BOOL{
          ssoChecks++;
          return YES;
      }];
    XCTAssertNil(provider.readiness);
    XCTAssertEqual(brokerChecks, 0u);
    XCTAssertEqual(ssoChecks, 0u);
}

#if MSID_ENABLE_SSO_EXTENSION
- (void)testReadiness_whenControllerResultsDiffer_keepsIndependentValues
{
    NSArray<NSArray<NSNumber *> *> *cases = @[@[@NO, @YES], @[@YES, @NO]];
    for (NSArray<NSNumber *> *availability in cases)
    {
        __block NSUInteger brokerChecks = 0;
        __block NSUInteger ssoChecks = 0;
        MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
            initWithBrokerOptionsFactory:nil
                 brokerAvailabilityCheck:^BOOL(__unused MSIDInteractiveTokenRequestParameters *parameters) {
                     brokerChecks++;
                     return availability[0].boolValue;
                 }
          ssoExtensionAvailabilityCheck:^BOOL{
              ssoChecks++;
              return availability[1].boolValue;
          }];
        MSIDOnboardingReadiness *readiness = provider.readiness;
        XCTAssertEqual(readiness.brokerAvailability, availability[0].boolValue);
        XCTAssertEqual(readiness.ssoExtensionAvailability, availability[1].boolValue);
        XCTAssertEqual(brokerChecks, 1u);
        XCTAssertEqual(ssoChecks, 1u);
    }
}
#endif

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
#elif TARGET_OS_OSX
- (void)testReadiness_onMac_doesNotProbeBrokerAndKeepsSSOIndependent
{
    __block NSUInteger brokerFactoryCalls = 0;
    __block NSUInteger brokerChecks = 0;
    __block NSUInteger ssoChecks = 0;
    MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
        initWithBrokerOptionsFactory:^MSIDBrokerInvocationOptions *{
            brokerFactoryCalls++;
            return nil;
        }
             brokerAvailabilityCheck:^BOOL(__unused MSIDInteractiveTokenRequestParameters *parameters) {
                 brokerChecks++;
                 return YES;
             }
      ssoExtensionAvailabilityCheck:^BOOL{
          ssoChecks++;
          return YES;
      }];
    MSIDOnboardingReadiness *readiness = provider.readiness;
    XCTAssertNotNil(readiness);
    XCTAssertFalse(readiness.brokerAvailability);
#if MSID_ENABLE_SSO_EXTENSION
    XCTAssertTrue(readiness.ssoExtensionAvailability);
    XCTAssertEqual(ssoChecks, 1u);
#else
    XCTAssertFalse(readiness.ssoExtensionAvailability);
    XCTAssertEqual(ssoChecks, 0u);
#endif
    XCTAssertEqual(brokerFactoryCalls, 0u);
    XCTAssertEqual(brokerChecks, 0u);
}
#elif TARGET_OS_VISION
- (void)testReadiness_onVision_doesNotProbeEitherController
{
    __block NSUInteger brokerFactoryCalls = 0;
    __block NSUInteger brokerChecks = 0;
    __block NSUInteger ssoChecks = 0;
    MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
        initWithBrokerOptionsFactory:^MSIDBrokerInvocationOptions *{
            brokerFactoryCalls++;
            return nil;
        }
             brokerAvailabilityCheck:^BOOL(__unused MSIDInteractiveTokenRequestParameters *parameters) {
                 brokerChecks++;
                 return YES;
             }
      ssoExtensionAvailabilityCheck:^BOOL{
          ssoChecks++;
          return YES;
      }];
    MSIDOnboardingReadiness *readiness = provider.readiness;
    XCTAssertNotNil(readiness);
    XCTAssertFalse(readiness.brokerAvailability);
    XCTAssertFalse(readiness.ssoExtensionAvailability);
    XCTAssertEqual(brokerFactoryCalls, 0u);
    XCTAssertEqual(brokerChecks, 0u);
    XCTAssertEqual(ssoChecks, 0u);
}
#endif

@end
