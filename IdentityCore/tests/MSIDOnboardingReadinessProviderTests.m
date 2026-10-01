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
#if TARGET_OS_IPHONE
#import "MSIDApplicationTestUtil.h"
#import "MSIDTestBundle.h"
#endif

@interface MSIDOnboardingReadinessProviderTests : XCTestCase
@end

@implementation MSIDOnboardingReadinessProviderTests

#if TARGET_OS_IPHONE
- (void)tearDown
{
    MSIDApplicationTestUtil.canOpenURLSchemes = nil;
    [MSIDApplicationTestUtil reset];
    [MSIDTestBundle reset];
    [super tearDown];
}

- (void)testReadiness_whenApplicationHasBrokerAndSSO_shouldReturnAvailableForBoth
{
    MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
        initWithAppExtensionProbe:^{ return NO; }
                  querySchemesProbe:^{ return YES; }
                        brokerProbe:^{ return @YES; }
                  ssoExtensionProbe:^{ return @YES; }];
    MSIDOnboardingReadiness *readiness = provider.readiness;
    XCTAssertEqual(readiness.brokerAvailability, MSIDOnboardingReadinessStateAvailable);
    XCTAssertEqual(readiness.ssoExtensionAvailability, MSIDOnboardingReadinessStateAvailable);
    XCTAssertNil(readiness.jsonDictionary[@"unknownReasons"]);
}

- (void)testReadiness_whenProbesReturnNo_shouldReturnUnavailableForBoth
{
    MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
        initWithAppExtensionProbe:^{ return NO; }
                  querySchemesProbe:^{ return YES; }
                        brokerProbe:^{ return @NO; }
                  ssoExtensionProbe:^{ return @NO; }];
    MSIDOnboardingReadiness *readiness = provider.readiness;
    XCTAssertEqual(readiness.brokerAvailability, MSIDOnboardingReadinessStateUnavailable);
    XCTAssertEqual(readiness.ssoExtensionAvailability, MSIDOnboardingReadinessStateUnavailable);
}

- (void)testReadiness_whenInAppExtension_shouldNotProbeBrokerButStillProbeSSO
{
    MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
        initWithAppExtensionProbe:^{ return YES; }
                  querySchemesProbe:^{ XCTFail(@"Query schemes must not be checked in an extension"); return NO; }
                        brokerProbe:^{ XCTFail(@"Broker must not be probed in an extension"); return @NO; }
                  ssoExtensionProbe:^{ return @YES; }];
    MSIDOnboardingReadiness *readiness = provider.readiness;
    XCTAssertEqual(readiness.brokerAvailability, MSIDOnboardingReadinessStateUnknown);
    XCTAssertEqual(readiness.brokerUnknownReason, MSIDOnboardingReadinessUnknownReasonNotProbeableInCurrentHost);
    XCTAssertEqual(readiness.ssoExtensionAvailability, MSIDOnboardingReadinessStateAvailable);
}

- (void)testReadiness_whenMissingQuerySchemes_shouldNotInterpretBrokerAsAbsent
{
    MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
        initWithAppExtensionProbe:^{ return NO; }
                  querySchemesProbe:^{ return NO; }
                        brokerProbe:^{ XCTFail(@"Cannot trust broker probe without query schemes"); return @NO; }
                  ssoExtensionProbe:^{ return @NO; }];
    MSIDOnboardingReadiness *readiness = provider.readiness;
    XCTAssertEqual(readiness.brokerAvailability, MSIDOnboardingReadinessStateUnknown);
    XCTAssertEqual(readiness.brokerUnknownReason, MSIDOnboardingReadinessUnknownReasonMissingQuerySchemeConfiguration);
    XCTAssertEqual(readiness.ssoExtensionAvailability, MSIDOnboardingReadinessStateUnavailable);
}

- (void)testReadiness_whenBrokerProbeFails_shouldReportUnknownIndependently
{
    MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
        initWithAppExtensionProbe:^{ return NO; }
                  querySchemesProbe:^{ return YES; }
                        brokerProbe:^{ return (NSNumber *)nil; }
                  ssoExtensionProbe:^{ return @YES; }];
    MSIDOnboardingReadiness *readiness = provider.readiness;
    XCTAssertEqual(readiness.brokerAvailability, MSIDOnboardingReadinessStateUnknown);
    XCTAssertEqual(readiness.brokerUnknownReason, MSIDOnboardingReadinessUnknownReasonProbeFailed);
    XCTAssertEqual(readiness.ssoExtensionAvailability, MSIDOnboardingReadinessStateAvailable);
}

- (void)testReadiness_whenCalledOffMainThread_shouldProbeBrokerOnMainThread
{
    __block BOOL brokerProbedOnMainThread = NO;
    __block MSIDOnboardingReadiness *readiness = nil;
    MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
        initWithAppExtensionProbe:^{ return NO; }
                  querySchemesProbe:^{ return YES; }
                        brokerProbe:^{
                            brokerProbedOnMainThread = [NSThread isMainThread];
                            return @YES;
                        }
                  ssoExtensionProbe:^{ return @NO; }];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Background readiness completes"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        readiness = provider.readiness;
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertTrue(brokerProbedOnMainThread);
    XCTAssertEqual(readiness.brokerAvailability, MSIDOnboardingReadinessStateAvailable);
}

- (void)testReadiness_whenRequiredBrokerSchemesPresent_shouldUseNonceCapableBrokerProbe
{
    [MSIDTestBundle overrideObject:@[@"msauthv2", @"msauthv3"] forKey:@"LSApplicationQueriesSchemes"];
    MSIDApplicationTestUtil.canOpenURLSchemes = @[@"msauthv2", @"msauthv3"];
    MSIDOnboardingReadinessProvider *provider = [MSIDOnboardingReadinessProvider new];
    XCTAssertEqual(provider.readiness.brokerAvailability, MSIDOnboardingReadinessStateAvailable);

    MSIDApplicationTestUtil.canOpenURLSchemes = @[@"msauthv2"];
    XCTAssertEqual(provider.readiness.brokerAvailability, MSIDOnboardingReadinessStateUnavailable);
}

- (void)testReadiness_whenHostDoesNotDeclareQuerySchemes_shouldReturnUnknown
{
    [MSIDTestBundle overrideObject:@[@"msauthv2"] forKey:@"LSApplicationQueriesSchemes"];
    MSIDApplicationTestUtil.canOpenURLSchemes = @[@"msauthv2", @"msauthv3"];
    MSIDOnboardingReadinessProvider *provider = [MSIDOnboardingReadinessProvider new];
    MSIDOnboardingReadiness *readiness = provider.readiness;
    XCTAssertEqual(readiness.brokerAvailability, MSIDOnboardingReadinessStateUnknown);
    XCTAssertEqual(readiness.brokerUnknownReason, MSIDOnboardingReadinessUnknownReasonMissingQuerySchemeConfiguration);
}
#endif

- (void)testReadiness_whenSSOPlatformProbeUnavailable_shouldReportUnknown
{
    MSIDOnboardingReadinessProvider *provider = [[MSIDOnboardingReadinessProvider alloc]
        initWithAppExtensionProbe:^{ return NO; }
                  querySchemesProbe:^{ return YES; }
                        brokerProbe:^{ return @YES; }
                  ssoExtensionProbe:^{ return (NSNumber *)nil; }];
    MSIDOnboardingReadiness *readiness = provider.readiness;
    XCTAssertEqual(readiness.ssoExtensionAvailability, MSIDOnboardingReadinessStateUnknown);
    XCTAssertEqual(readiness.ssoExtensionUnknownReason, MSIDOnboardingReadinessUnknownReasonPlatformCapabilityUnavailable);
}

@end
