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
#import "MSIDXpcSingleSignOnProvider.h"
#import "MSIDXpcProviderCacheMock.h"
#import "MSIDTestSwizzle.h"
#import "MSIDSSOExtensionGetDeviceInfoRequest.h"
#import "MSIDConstants.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDTestContext.h"

@interface MSIDXpcSingleSignOnProviderTest : XCTestCase

@property (nonatomic) MSIDFlightManagerMockProvider *flightProvider;

@end

@implementation MSIDXpcSingleSignOnProviderTest

- (void)setUp
{
    self.flightProvider = [MSIDFlightManagerMockProvider new];
    self.flightProvider.boolForKeyContainer = @{};
    [MSIDFlightManager sharedInstance].flightProvider = self.flightProvider;
}

- (void)tearDown
{
    [MSIDTestSwizzle reset];
    [MSIDFlightManager sharedInstance].flightProvider = nil;
    self.flightProvider = nil;
}

#pragma mark - Helpers (XPC instance cache wave 3)

- (void)setInstanceCacheFlightEnabled:(BOOL)enabled
{
    self.flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_BROKER_XPC_INSTANCE_CACHE_ENABLED: @(enabled) };
}

// Pre-populate the mock cache with a non-nil endpoint bound to the given provider type.
// We use [NSXPCListenerEndpoint new] as a placeholder — production code paths that touch
// the endpoint are swizzled in the cache-hit tests.
- (NSXPCListenerEndpoint *)prewarmMockCache:(MSIDXpcProviderCacheMock *)mock
                            forProviderType:(MSIDSsoProviderType)providerType
{
    mock.cachedXpcProviderType = providerType;
    NSXPCListenerEndpoint *endpoint = [NSXPCListenerEndpoint new];
    BOOL stored = [mock setCachedBrokerInstanceEndpoint:endpoint forProviderType:providerType];
    XCTAssertTrue(stored, @"prewarm should succeed when providerType matches");
    return endpoint;
}

- (void)testNoXpcComponentInstalledOnDevice_canPerformRequest_returnsFalse
{
    MSIDXpcProviderCacheMock *xpcProviderCacheMock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:NO
                                                                                                      isXpcValidated:NO];
    XCTAssertFalse([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCacheMock]);
}

- (void)testXpcComponentInstalledOnDevice_ssoExtensionDisabled_hasValidXpcConfiguration_canPerformRequest_returnsTrue
{
    
    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    MSIDXpcProviderCacheMock *xpcProviderCacheMock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:YES
                                                                                                      isXpcValidated:YES];
    XCTAssertTrue([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCacheMock]);
}

- (void)testXpcComponentInstalledOnDevice_ssoExtensionDisabled_hasValidXpcConfiguration_canPerformRequest_doesNotCallRemoteXpcService
{
    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    __block BOOL xpcServiceCalled = NO;
    SEL selectorForMSIDXpcSingleSignOnProvider = NSSelectorFromString(@"getXpcService:withContinueBlock:");
    [MSIDTestSwizzle instanceMethod:selectorForMSIDXpcSingleSignOnProvider
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:(id)^(void)
     {
        xpcServiceCalled = YES;
     }];
    
    MSIDXpcProviderCacheMock *xpcProviderCacheMock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:YES
                                                                                                      isXpcValidated:YES];
    [MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCacheMock];
    XCTAssertFalse(xpcServiceCalled, @"getXpcService should not be called from canPerformRequest");
}

- (void)testXpcComponentInstalledOnDevice_ssoExtensionDisabled_hasInvalidXpcValidation_canPerformRequest_returnsFalse
{
    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    MSIDXpcProviderCacheMock *xpcProviderCachedMock = [[MSIDXpcProviderCacheMock alloc]
                                                       initWithXpcInstallationStatus:YES
                                                       isXpcValidated:NO];
    
    XCTAssertFalse([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCachedMock]);
}

- (void)testNoXpcComponentInstalledOnDevice_ssoExtensionEnabled_hasInvalidXpcValidation_canPerformRequest_ssoExtensionShouldTrigger
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"SsoExtension will be triggered for to get device info"];

    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(void)
    {
        return YES;
    }];
    
    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest_request = NSSelectorFromString(@"executeRequestWithCompletion:");
    [MSIDTestSwizzle instanceMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest_request
                              class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                              block:(id)^(void)
     {
        [expectation fulfill];
     }];
    
    MSIDXpcProviderCacheMock *xpcProviderCachedMock = [[MSIDXpcProviderCacheMock alloc]
                                                       initWithXpcInstallationStatus:YES
                                                       isXpcValidated:NO];
    [MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCachedMock];
    [self waitForExpectations:@[expectation] timeout:2.0];
}

#pragma mark - XPC instance cache (wave 3)

// Flight OFF: cache must not be consulted; dispatcher path runs unconditionally.
- (void)testHandleRequest_flightOff_doesNotConsultCache_takesDispatcherPath
{
    [self setInstanceCacheFlightEnabled:NO];

    MSIDXpcProviderCacheMock *cacheMock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:YES isXpcValidated:YES];
    // Even with a "cached" endpoint, flight OFF must skip cache reads entirely.
    [self prewarmMockCache:cacheMock forProviderType:MSIDMacBrokerSsoProvider];
    NSUInteger getCountBefore = cacheMock.cachedBrokerInstanceEndpointGetCount;

    __block NSUInteger dispatcherCallCount = 0;
    __block NSUInteger cacheHitCallCount = 0;

    [MSIDTestSwizzle instanceMethod:NSSelectorFromString(@"getXpcService:withContinueBlock:")
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:^(__unused id selfRef, __unused id<MSIDXpcProviderCaching> cache, void (^continueBlock)(id, NSXPCConnection *, NSError *))
    {
        dispatcherCallCount += 1;
        NSError *err = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
        continueBlock(nil, nil, err);
    }];

    [MSIDTestSwizzle instanceMethod:NSSelectorFromString(@"getXpcServiceFromCachedEndpoint:xpcProviderCache:context:withContinueBlock:")
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:^(__unused id selfRef, __unused NSXPCListenerEndpoint *ep, __unused id<MSIDXpcProviderCaching> cache, __unused id<MSIDRequestContext> ctx, void (^continueBlock)(id, NSXPCConnection *, NSError *))
    {
        cacheHitCallCount += 1;
        continueBlock(nil, nil, [NSError errorWithDomain:@"test" code:99 userInfo:nil]);
    }];

    XCTestExpectation *outerExpectation = [self expectationWithDescription:@"outer continueBlock fires once"];
    __block NSUInteger outerCallCount = 0;
    MSIDXpcSingleSignOnProvider *provider = [MSIDXpcSingleSignOnProvider new];
    [provider handleRequestParam:@{}
       assertKindOfResponseClass:[NSObject class]
                xpcProviderCache:cacheMock
                         context:[MSIDTestContext new]
                   continueBlock:^(__unused id response, __unused NSError *error)
    {
        outerCallCount += 1;
        [outerExpectation fulfill];
    }];

    [self waitForExpectations:@[outerExpectation] timeout:2.0];

    XCTAssertEqual(dispatcherCallCount, 1u, @"dispatcher path must run exactly once");
    XCTAssertEqual(cacheHitCallCount, 0u, @"cache-hit path must not run when flight is OFF");
    XCTAssertEqual(cacheMock.cachedBrokerInstanceEndpointGetCount, getCountBefore, @"cache getter must not be consulted when flight is OFF");
    XCTAssertEqual(outerCallCount, 1u);
}

// Flight ON, cold cache: cache getter consulted; dispatcher path runs; cache-hit helper not called.
- (void)testHandleRequest_flightOn_coldCache_takesDispatcherPath
{
    [self setInstanceCacheFlightEnabled:YES];

    MSIDXpcProviderCacheMock *cacheMock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:YES isXpcValidated:YES];
    cacheMock.cachedXpcProviderType = MSIDMacBrokerSsoProvider;

    __block NSUInteger dispatcherCallCount = 0;
    __block NSUInteger cacheHitCallCount = 0;

    [MSIDTestSwizzle instanceMethod:NSSelectorFromString(@"getXpcService:withContinueBlock:")
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:^(__unused id selfRef, __unused id<MSIDXpcProviderCaching> cache, void (^continueBlock)(id, NSXPCConnection *, NSError *))
    {
        dispatcherCallCount += 1;
        continueBlock(nil, nil, [NSError errorWithDomain:@"test" code:1 userInfo:nil]);
    }];

    [MSIDTestSwizzle instanceMethod:NSSelectorFromString(@"getXpcServiceFromCachedEndpoint:xpcProviderCache:context:withContinueBlock:")
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:^(__unused id selfRef, __unused NSXPCListenerEndpoint *ep, __unused id<MSIDXpcProviderCaching> cache, __unused id<MSIDRequestContext> ctx, void (^continueBlock)(id, NSXPCConnection *, NSError *))
    {
        cacheHitCallCount += 1;
        continueBlock(nil, nil, nil);
    }];

    XCTestExpectation *outerExpectation = [self expectationWithDescription:@"outer continueBlock fires once"];
    MSIDXpcSingleSignOnProvider *provider = [MSIDXpcSingleSignOnProvider new];
    [provider handleRequestParam:@{}
       assertKindOfResponseClass:[NSObject class]
                xpcProviderCache:cacheMock
                         context:[MSIDTestContext new]
                   continueBlock:^(__unused id response, __unused NSError *error)
    {
        [outerExpectation fulfill];
    }];

    [self waitForExpectations:@[outerExpectation] timeout:2.0];

    XCTAssertEqual(dispatcherCallCount, 1u, @"dispatcher path must run exactly once on cold cache");
    XCTAssertEqual(cacheHitCallCount, 0u, @"cache-hit helper must not run on cold cache");
    XCTAssertGreaterThanOrEqual(cacheMock.cachedBrokerInstanceEndpointGetCount, 1u, @"cache getter must be consulted when flight is ON");
}

// Flight ON, warm cache, stale endpoint: cache-hit runs first, fails, then exactly one dispatcher
// retry. Cache cleared exactly once. Outer block fires exactly once even when both paths fail.
- (void)testHandleRequest_flightOn_warmCache_staleEndpoint_retriesViaDispatcherOnce
{
    [self setInstanceCacheFlightEnabled:YES];

    MSIDXpcProviderCacheMock *cacheMock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:YES isXpcValidated:YES];
    [self prewarmMockCache:cacheMock forProviderType:MSIDMacBrokerSsoProvider];

    __block NSUInteger dispatcherCallCount = 0;
    __block NSUInteger cacheHitCallCount = 0;

    [MSIDTestSwizzle instanceMethod:NSSelectorFromString(@"getXpcServiceFromCachedEndpoint:xpcProviderCache:context:withContinueBlock:")
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:^(__unused id selfRef, __unused NSXPCListenerEndpoint *ep, __unused id<MSIDXpcProviderCaching> cache, __unused id<MSIDRequestContext> ctx, void (^continueBlock)(id, NSXPCConnection *, NSError *))
    {
        cacheHitCallCount += 1;
        // Simulate stale endpoint: connection establishes-but-fails.
        continueBlock(nil, nil, [NSError errorWithDomain:@"stale" code:42 userInfo:nil]);
    }];

    [MSIDTestSwizzle instanceMethod:NSSelectorFromString(@"getXpcService:withContinueBlock:")
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:^(__unused id selfRef, __unused id<MSIDXpcProviderCaching> cache, void (^continueBlock)(id, NSXPCConnection *, NSError *))
    {
        dispatcherCallCount += 1;
        // Retry also fails; outer block must surface the error exactly once.
        continueBlock(nil, nil, [NSError errorWithDomain:@"dispatcherFail" code:99 userInfo:nil]);
    }];

    XCTestExpectation *outerExpectation = [self expectationWithDescription:@"outer continueBlock fires once"];
    __block NSUInteger outerCallCount = 0;
    __block NSError *capturedError = nil;
    MSIDXpcSingleSignOnProvider *provider = [MSIDXpcSingleSignOnProvider new];
    [provider handleRequestParam:@{}
       assertKindOfResponseClass:[NSObject class]
                xpcProviderCache:cacheMock
                         context:[MSIDTestContext new]
                   continueBlock:^(__unused id response, NSError *error)
    {
        outerCallCount += 1;
        capturedError = error;
        [outerExpectation fulfill];
    }];

    [self waitForExpectations:@[outerExpectation] timeout:2.0];

    XCTAssertEqual(cacheHitCallCount, 1u, @"cache-hit path must run exactly once");
    XCTAssertEqual(dispatcherCallCount, 1u, @"dispatcher retry must run exactly once (no infinite loop)");
    XCTAssertEqual(cacheMock.clearCachedBrokerInstanceEndpointCallCount, 1u, @"cache must be cleared exactly once before retry");
    XCTAssertEqual(outerCallCount, 1u, @"outer block must fire exactly once even on double failure");
    XCTAssertNotNil(capturedError, @"final error must be surfaced");
}

#pragma mark - Mock-level CAS semantics (wave 2/3 invariants)

// Mock mirrors production: provider-type switch invalidates any cached endpoint.
- (void)testMock_setCachedXpcProviderType_clearsCachedEndpoint
{
    MSIDXpcProviderCacheMock *mock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:YES isXpcValidated:YES];
    [self prewarmMockCache:mock forProviderType:MSIDMacBrokerSsoProvider];

    XCTAssertNotNil(mock.cachedBrokerInstanceEndpoint, @"endpoint should be set after prewarm");

    mock.cachedXpcProviderType = MSIDCompanyPortalSsoProvider;

    XCTAssertNil(mock.cachedBrokerInstanceEndpoint, @"endpoint must be cleared on provider-type switch");
}

// Mock CAS: setter rejects writes when cachedXpcProviderType has changed since the dispatcher
// round-trip began. This mirrors production behavior in MSIDXpcProviderCache.
- (void)testMock_setCachedBrokerInstanceEndpoint_providerSwitchedDuringRoundTrip_isRejectedByCAS
{
    MSIDXpcProviderCacheMock *mock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:YES isXpcValidated:YES];
    mock.cachedXpcProviderType = MSIDMacBrokerSsoProvider;

    // Simulate: dispatcher round-trip started under MacBroker, but provider switched mid-flight.
    mock.cachedXpcProviderType = MSIDCompanyPortalSsoProvider;

    NSXPCListenerEndpoint *staleEndpoint = [NSXPCListenerEndpoint new];
    BOOL stored = [mock setCachedBrokerInstanceEndpoint:staleEndpoint forProviderType:MSIDMacBrokerSsoProvider];

    XCTAssertFalse(stored, @"CAS must reject store when providerType has changed");
    XCTAssertEqual(mock.setCachedBrokerInstanceEndpointRejectedCount, 1u);
    XCTAssertEqual(mock.cachedBrokerInstanceEndpointSetCount, 0u);
    XCTAssertNil(mock.cachedBrokerInstanceEndpoint);
}

@end
