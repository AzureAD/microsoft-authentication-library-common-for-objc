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
#import "MSIDAuthenticationAvailabilityProvider.h"
@class MSIDBrokerInvocationOptions;
@class MSIDInteractiveTokenRequestParameters;
typedef MSIDBrokerInvocationOptions * _Nullable (^MSIDTestBrokerOptionsFactory)(void);
typedef BOOL (^MSIDTestBrokerAvailabilityCheck)(MSIDInteractiveTokenRequestParameters *parameters);
typedef BOOL (^MSIDTestSSOExtensionAvailabilityCheck)(void);
#if TARGET_OS_IPHONE && !TARGET_OS_VISION
#import "MSIDBrokerInvocationOptions.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#endif

@interface MSIDAuthenticationAvailabilityProvider (Testing)
- (instancetype)initWithBrokerOptionsFactory:(nullable MSIDTestBrokerOptionsFactory)brokerOptionsFactory
                     brokerAvailabilityCheck:(nullable MSIDTestBrokerAvailabilityCheck)brokerAvailabilityCheck
              ssoExtensionAvailabilityCheck:(nullable MSIDTestSSOExtensionAvailabilityCheck)ssoExtensionAvailabilityCheck;
@end

#if TARGET_OS_IPHONE && !TARGET_OS_VISION && !AD_BROKER
@interface MSIDUnavailableBrokerInvocationOptions : MSIDBrokerInvocationOptions
@end

@implementation MSIDUnavailableBrokerInvocationOptions
- (BOOL)isRequiredBrokerPresent
{
    return NO;
}
@end
#endif

@interface MSIDAuthenticationAvailabilityProviderTests : XCTestCase
@end

@implementation MSIDAuthenticationAvailabilityProviderTests

#if TARGET_OS_IPHONE && !TARGET_OS_VISION
- (void)testReadiness_usesExistingControllersAndReturnsBooleans
{
    __block NSUInteger brokerChecks = 0;
    __block NSUInteger ssoChecks = 0;
    MSIDAuthenticationAvailabilityProvider *provider = [[MSIDAuthenticationAvailabilityProvider alloc]
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
    MSIDAuthenticationAvailabilityStatus *readiness = provider.availabilityStatus;
    XCTAssertNotNil(readiness);
    XCTAssertTrue(readiness.brokerAppAvailable);
#if MSID_ENABLE_SSO_EXTENSION
    XCTAssertTrue(readiness.ssoExtensionAvailable);
    XCTAssertEqual(ssoChecks, 1u);
#else
    XCTAssertFalse(readiness.ssoExtensionAvailable);
    XCTAssertEqual(ssoChecks, 0u);
#endif
    XCTAssertEqual(brokerChecks, 1u);
}

- (void)testReadiness_whenControllerCannotPerformRequest_returnsFalse
{
    MSIDAuthenticationAvailabilityProvider *provider = [[MSIDAuthenticationAvailabilityProvider alloc]
        initWithBrokerOptionsFactory:nil
             brokerAvailabilityCheck:^BOOL(__unused MSIDInteractiveTokenRequestParameters *parameters) {
                 return NO;
             }
      ssoExtensionAvailabilityCheck:^BOOL{
          return NO;
      }];
    MSIDAuthenticationAvailabilityStatus *readiness = provider.availabilityStatus;
    XCTAssertNotNil(readiness);
    XCTAssertFalse(readiness.brokerAppAvailable);
    XCTAssertFalse(readiness.ssoExtensionAvailable);
}

- (void)testReadiness_whenBrokerOptionsCannotBeCreated_fails
{
    __block NSUInteger brokerChecks = 0;
    __block NSUInteger ssoChecks = 0;
    MSIDAuthenticationAvailabilityProvider *provider = [[MSIDAuthenticationAvailabilityProvider alloc]
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
    XCTAssertNil(provider.availabilityStatus);
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
        MSIDAuthenticationAvailabilityProvider *provider = [[MSIDAuthenticationAvailabilityProvider alloc]
            initWithBrokerOptionsFactory:nil
                 brokerAvailabilityCheck:^BOOL(__unused MSIDInteractiveTokenRequestParameters *parameters) {
                     brokerChecks++;
                     return availability[0].boolValue;
                 }
          ssoExtensionAvailabilityCheck:^BOOL{
              ssoChecks++;
              return availability[1].boolValue;
          }];
        MSIDAuthenticationAvailabilityStatus *readiness = provider.availabilityStatus;
        XCTAssertEqual(readiness.brokerAppAvailable, availability[0].boolValue);
        XCTAssertEqual(readiness.ssoExtensionAvailable, availability[1].boolValue);
        XCTAssertEqual(brokerChecks, 1u);
        XCTAssertEqual(ssoChecks, 1u);
    }
}
#endif

#if !AD_BROKER
- (void)testReadiness_whenBrokerOptionsReportUnavailable_returnsFalse
{
    MSIDAuthenticationAvailabilityProvider *provider = [[MSIDAuthenticationAvailabilityProvider alloc]
        initWithBrokerOptionsFactory:^MSIDBrokerInvocationOptions *{
            return [[MSIDUnavailableBrokerInvocationOptions alloc]
                initWithRequiredBrokerType:MSIDRequiredBrokerTypeWithNonceSupport
                              protocolType:MSIDBrokerProtocolTypeCustomScheme
                         aadRequestVersion:MSIDBrokerAADRequestVersionV2];
        }
             brokerAvailabilityCheck:nil
      ssoExtensionAvailabilityCheck:^BOOL{
          return YES;
      }];
    MSIDAuthenticationAvailabilityStatus *readiness = provider.availabilityStatus;
    XCTAssertNotNil(readiness);
    XCTAssertFalse(readiness.brokerAppAvailable);
#if MSID_ENABLE_SSO_EXTENSION
    XCTAssertTrue(readiness.ssoExtensionAvailable);
#endif
}
#endif

- (void)testReadiness_whenCalledOffMainThread_completesWithStubbedAvailabilityChecks
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Background readiness completes"];
    __block MSIDAuthenticationAvailabilityStatus *readiness = nil;
    __block BOOL calledOffMainThread = NO;
    __block NSUInteger brokerChecks = 0;
    __block NSUInteger ssoChecks = 0;
    MSIDAuthenticationAvailabilityProvider *provider = [[MSIDAuthenticationAvailabilityProvider alloc]
        initWithBrokerOptionsFactory:nil
             brokerAvailabilityCheck:^BOOL(__unused MSIDInteractiveTokenRequestParameters *parameters) {
                 brokerChecks++;
                 return YES;
             }
      ssoExtensionAvailabilityCheck:^BOOL{
          ssoChecks++;
          return YES;
      }];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        calledOffMainThread = ![NSThread isMainThread];
        readiness = provider.availabilityStatus;
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertTrue(calledOffMainThread);
    XCTAssertNotNil(readiness);
    XCTAssertTrue(readiness.brokerAppAvailable);
    XCTAssertEqual(brokerChecks, 1u);
#if MSID_ENABLE_SSO_EXTENSION
    XCTAssertTrue(readiness.ssoExtensionAvailable);
    XCTAssertEqual(ssoChecks, 1u);
#else
    XCTAssertFalse(readiness.ssoExtensionAvailable);
    XCTAssertEqual(ssoChecks, 0u);
#endif
}
#elif TARGET_OS_OSX
- (void)testReadiness_onMac_doesNotProbeBrokerAndKeepsSSOIndependent
{
    __block NSUInteger brokerFactoryCalls = 0;
    __block NSUInteger brokerChecks = 0;
    __block NSUInteger ssoChecks = 0;
    MSIDAuthenticationAvailabilityProvider *provider = [[MSIDAuthenticationAvailabilityProvider alloc]
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
    MSIDAuthenticationAvailabilityStatus *readiness = provider.availabilityStatus;
    XCTAssertNotNil(readiness);
    XCTAssertFalse(readiness.brokerAppAvailable);
#if MSID_ENABLE_SSO_EXTENSION
    XCTAssertTrue(readiness.ssoExtensionAvailable);
    XCTAssertEqual(ssoChecks, 1u);
#else
    XCTAssertFalse(readiness.ssoExtensionAvailable);
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
    MSIDAuthenticationAvailabilityProvider *provider = [[MSIDAuthenticationAvailabilityProvider alloc]
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
    MSIDAuthenticationAvailabilityStatus *readiness = provider.availabilityStatus;
    XCTAssertNotNil(readiness);
    XCTAssertFalse(readiness.brokerAppAvailable);
    XCTAssertFalse(readiness.ssoExtensionAvailable);
    XCTAssertEqual(brokerFactoryCalls, 0u);
    XCTAssertEqual(brokerChecks, 0u);
    XCTAssertEqual(ssoChecks, 0u);
}
#endif

@end
