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
#import "MSIDXpcSilentTokenRequestController.h"
#import "MSIDXpcInteractiveTokenRequestController.h"
#import "MSIDXpcProviderCacheMock.h"
#import "MSIDTestSwizzle.h"
#import "MSIDSSOExtensionGetDeviceInfoRequest.h"
#import "MSIDConstants.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDTestContext.h"
#import "MSIDXpcConfiguration.h"
#import "MSIDError.h"
#import "MSIDBrokerNativeAppOperationResponse.h"
#import "MSIDSSOXpcInteractiveTokenRequest.h"
#import "MSIDBrokerOperationInteractiveTokenRequest.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDDefaultTokenResponseValidator.h"

typedef void (^MSIDXpcTestEndpointReplyBlock)(NSXPCListenerEndpoint *endpoint, NSDictionary *parameters, NSError *error);
typedef void (^MSIDXpcTestBrokerReplyBlock)(NSDictionary *response, NSDate *startDate, NSString *processId, NSError *error);

@interface MSIDXpcSingleSignOnProvider (TransportFailureTesting)

- (NSXPCConnection *)dispatcherConnectionWithMachServiceName:(NSString *)machServiceName;
- (NSXPCConnection *)directConnectionWithEndpoint:(NSXPCListenerEndpoint *)endpoint;
- (void)scheduleBlock:(dispatch_block_t)block afterTimeout:(NSTimeInterval)timeout;
- (NSString *)codeSignRequirementForBundleId:(NSString *)bundleId devIdentity:(NSString *)devIdentity;
- (BOOL)isXpcPlatformSupported;

@end

@interface MSIDSSOXpcInteractiveTokenRequest (TransportFailureTesting)

@property (nonatomic) MSIDBrokerOperationInteractiveTokenRequest *operationRequest;
@property (nonatomic) MSIDXpcSingleSignOnProvider *xpcSingleSignOnProvider;

- (void)executeRequestImplWithCompletionBlock:(MSIDInteractiveRequestCompletionBlock)completionBlock;

@end

@interface MSIDXpcTestDispatcherProxy : NSObject

@property (nonatomic, copy) MSIDXpcTestEndpointReplyBlock endpointReplyBlock;

@end

@implementation MSIDXpcTestDispatcherProxy

- (void)getBrokerInstanceEndpointWithReply:(MSIDXpcTestEndpointReplyBlock)reply
{
    self.endpointReplyBlock = reply;
}

- (void)replyWithEndpoint:(NSXPCListenerEndpoint *)endpoint error:(NSError *)error
{
    if (self.endpointReplyBlock)
    {
        self.endpointReplyBlock(endpoint, nil, error);
    }
}

@end

@interface MSIDXpcTestBrokerProxy : NSObject

@property (nonatomic, copy) MSIDXpcTestBrokerReplyBlock brokerReplyBlock;

@end

@implementation MSIDXpcTestBrokerProxy

- (void)handleXpcWithRequestParams:(NSDictionary *)__unused requestParameters
                   parentViewFrame:(NSRect)__unused frame
                   completionBlock:(MSIDXpcTestBrokerReplyBlock)completionBlock
{
    self.brokerReplyBlock = completionBlock;
}

- (void)replyWithResponse:(NSDictionary *)response error:(NSError *)error
{
    if (self.brokerReplyBlock)
    {
        self.brokerReplyBlock(response, [NSDate date], @"test-process", error);
    }
}

@end

@interface MSIDXpcTestConnection : NSObject

@property (nonatomic) NSXPCInterface *remoteObjectInterface;
@property (nonatomic, copy) void (^interruptionHandler)(void);
@property (nonatomic, copy) void (^invalidationHandler)(void);
@property (nonatomic, copy) void (^proxyErrorHandler)(NSError *error);
@property (nonatomic) id remoteProxy;
@property (nonatomic) BOOL invokeInvalidationHandlerOnInvalidate;
@property (nonatomic) BOOL invalidated;
@property (nonatomic) NSUInteger invalidateCount;
@property (nonatomic) NSUInteger suspendAfterInvalidationCount;

@end

@implementation MSIDXpcTestConnection

- (void)setCodeSigningRequirement:(NSString *)__unused requirement
{
}

- (void)resume
{
}

- (void)suspend
{
    if (self.invalidated)
    {
        self.suspendAfterInvalidationCount += 1;
    }
}

- (void)invalidate
{
    self.invalidated = YES;
    self.invalidateCount += 1;
    if (self.invokeInvalidationHandlerOnInvalidate && self.invalidationHandler)
    {
        self.invalidationHandler();
    }
}

- (id)remoteObjectProxyWithErrorHandler:(void (^)(NSError *error))handler
{
    self.proxyErrorHandler = handler;
    return self.remoteProxy;
}

- (void)fireProxyError:(NSError *)error
{
    if (self.proxyErrorHandler)
    {
        self.proxyErrorHandler(error);
    }
}

- (void)fireInterruption
{
    if (self.interruptionHandler)
    {
        self.interruptionHandler();
    }
}

- (void)fireInvalidation
{
    if (self.invalidationHandler)
    {
        self.invalidationHandler();
    }
}

@end

@interface MSIDXpcTestSingleSignOnProvider : MSIDXpcSingleSignOnProvider

@property (nonatomic) MSIDXpcTestConnection *dispatcherConnection;
@property (nonatomic) MSIDXpcTestConnection *directConnection;
@property (nonatomic) NSMutableArray<dispatch_block_t> *scheduledBlocks;
@property (nonatomic) NSMutableArray<NSNumber *> *scheduledTimeouts;
@property (nonatomic) BOOL platformSupported;
@property (nonatomic) NSUInteger directConnectionRequestCount;

@end

@implementation MSIDXpcTestSingleSignOnProvider

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _scheduledBlocks = [NSMutableArray new];
        _scheduledTimeouts = [NSMutableArray new];
        _platformSupported = YES;
    }

    return self;
}

- (NSXPCConnection *)dispatcherConnectionWithMachServiceName:(NSString *)__unused machServiceName
{
    return (NSXPCConnection *)self.dispatcherConnection;
}

- (NSXPCConnection *)directConnectionWithEndpoint:(NSXPCListenerEndpoint *)__unused endpoint
{
    self.directConnectionRequestCount += 1;
    return (NSXPCConnection *)self.directConnection;
}

- (void)scheduleBlock:(dispatch_block_t)block afterTimeout:(NSTimeInterval)timeout
{
    [self.scheduledBlocks addObject:[block copy]];
    [self.scheduledTimeouts addObject:@(timeout)];
}

- (NSString *)codeSignRequirementForBundleId:(NSString *)__unused bundleId
                                  devIdentity:(NSString *)__unused devIdentity
{
    return @"test-code-signing-requirement";
}

- (BOOL)isXpcPlatformSupported
{
    return self.platformSupported;
}

- (BOOL)isXpcInstanceCacheEnabled
{
    return NO;
}

@end

@interface MSIDXpcTestInteractiveOperationRequest : NSObject

@end

@implementation MSIDXpcTestInteractiveOperationRequest

+ (NSString *)operation
{
    return @"login";
}

- (NSDictionary *)jsonDictionary
{
    return @{};
}

@end

@interface MSIDXpcTestSynchronousFailureProvider : MSIDXpcSingleSignOnProvider

@property (nonatomic) NSError *error;

@end

@implementation MSIDXpcTestSynchronousFailureProvider

- (void)handleRequestParam:(NSDictionary *)__unused requestParam
           parentViewFrame:(NSRect)__unused frame
 assertKindOfResponseClass:(Class)__unused aClass
          xpcProviderCache:(id<MSIDXpcProviderCaching>)__unused xpcProviderCache
                   context:(id<MSIDRequestContext>)__unused context
             continueBlock:(MSIDSSOExtensionRequestDelegateCompletionBlock)continueBlock
{
    continueBlock(nil, self.error);
}

@end

@interface MSIDXpcSingleSignOnProviderTest : XCTestCase

@property (nonatomic) MSIDFlightManagerMockProvider *flightProvider;

@end

@implementation MSIDXpcSingleSignOnProviderTest

- (void)setUp
{
    [super setUp];
    self.flightProvider = [MSIDFlightManagerMockProvider new];
    self.flightProvider.boolForKeyContainer = @{};
    [MSIDFlightManager sharedInstance].flightProvider = self.flightProvider;

    // Production code defaults the XPC instance cache to ON in DEBUG builds so local
    // developers don't have to configure the flight. Tests run in DEBUG, so without this
    // swizzle the flight-OFF code paths would never be exercised. Route the decision
    // purely through the flight here so flight-controlled behavior is deterministic.
    [MSIDTestSwizzle instanceMethod:NSSelectorFromString(@"isXpcInstanceCacheEnabled")
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:^BOOL(__unused id selfRef)
    {
        return [[MSIDFlightManager sharedInstance] boolForKey:MSID_FLIGHT_BROKER_XPC_INSTANCE_CACHE_ENABLED];
    }];
}

- (void)tearDown
{
    [MSIDTestSwizzle reset];
    [MSIDFlightManager sharedInstance].flightProvider = nil;
    self.flightProvider = nil;
    [super tearDown];
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

- (MSIDXpcProviderCacheMock *)configuredXpcProviderCache
{
    MSIDXpcProviderCacheMock *cache = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:YES
                                                                                      isXpcValidated:YES];
    cache.cachedXpcProviderType = MSIDMacBrokerSsoProvider;
    cache.xpcConfiguration = [[MSIDXpcConfiguration alloc] initWithXpcProviderType:MSIDMacBrokerSsoProvider];
    return cache;
}

- (NSDictionary *)successfulBrokerResponse
{
    return @{
        @"operation": @"login",
        @"operation_response_type": @"operation_generic_response",
        @"success": @"1"
    };
}

- (void)startRequestWithProvider:(MSIDXpcSingleSignOnProvider *)provider
                           cache:(MSIDXpcProviderCacheMock *)cache
                      completion:(MSIDSSOExtensionRequestDelegateCompletionBlock)completion
{
    [provider handleRequestParam:@{}
       assertKindOfResponseClass:MSIDBrokerNativeAppOperationResponse.class
                xpcProviderCache:cache
                         context:[MSIDTestContext new]
                   continueBlock:completion];
}

// Drives the interactive public entry point (handleRequestParam:parentViewFrame:...), which disables
// the fixed broker-reply watchdog because interactive auth is gated on unbounded user interaction.
- (void)startInteractiveRequestWithProvider:(MSIDXpcSingleSignOnProvider *)provider
                                      cache:(MSIDXpcProviderCacheMock *)cache
                                 completion:(MSIDSSOExtensionRequestDelegateCompletionBlock)completion
{
    [provider handleRequestParam:@{}
                 parentViewFrame:CGRectZero
       assertKindOfResponseClass:MSIDBrokerNativeAppOperationResponse.class
                xpcProviderCache:cache
                         context:[MSIDTestContext new]
                   continueBlock:completion];
}

- (void)testNoXpcComponentInstalledOnDevice_canPerformRequest_returnsFalse
{
    MSIDXpcProviderCacheMock *xpcProviderCacheMock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:NO
                                                                                                      isXpcValidated:NO];
    XCTAssertFalse([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCacheMock]);
}

- (void)testNoXpcComponentInstalledOnDevice_canPerformRequestWithReason_returnsNoProviderInstalled
{
    MSIDXpcProviderCacheMock *xpcProviderCacheMock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:NO
                                                                                                      isXpcValidated:NO];
    MSIDXpcCanPerformFailureReason reason = MSIDXpcCanPerformFailureReasonNone;
    XCTAssertFalse([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCacheMock reason:&reason]);
    XCTAssertEqual(reason, MSIDXpcCanPerformFailureReasonNoProviderInstalled);
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

- (void)testXpcComponentInstalledOnDevice_ssoExtensionDisabled_hasValidXpcConfiguration_canPerformRequestWithReason_returnsNone
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
    MSIDXpcCanPerformFailureReason reason = MSIDXpcCanPerformFailureReasonValidateCacheProviderFailed;
    XCTAssertTrue([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCacheMock reason:&reason]);
    XCTAssertEqual(reason, MSIDXpcCanPerformFailureReasonNone);
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
    SEL selectorForMSIDXpcSingleSignOnProvider = NSSelectorFromString(@"getXpcService:requestCompleted:withContinueBlock:");
    [MSIDTestSwizzle instanceMethod:selectorForMSIDXpcSingleSignOnProvider
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:(id)^(__unused id selfRef,
                                          __unused id<MSIDXpcProviderCaching> cache,
                                          __unused BOOL (^requestCompleted)(void),
                                          __unused void (^continueBlock)(id, NSXPCConnection *, NSError *))
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

- (void)testXpcComponentInstalledOnDevice_ssoExtensionDisabled_hasInvalidXpcValidation_canPerformRequestWithReason_returnsValidateCacheProviderFailed
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

    MSIDXpcCanPerformFailureReason reason = MSIDXpcCanPerformFailureReasonNone;
    XCTAssertFalse([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCachedMock reason:&reason]);
    XCTAssertEqual(reason, MSIDXpcCanPerformFailureReasonValidateCacheProviderFailed);
}

- (void)testSsoExtensionEnabled_deviceInfoRequestCreationFails_canPerformRequestWithReason_returnsDeviceInfoRequestCreationFailed
{
    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(void)
    {
        return YES;
    }];

    SEL selectorForInit = @selector(initWithRequestParameters:error:);
    [MSIDTestSwizzle instanceMethod:selectorForInit
                              class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                              block:(id)^(void)
    {
        // Simulate the SSOExtension request object failing to construct.
        return nil;
    }];

    MSIDXpcProviderCacheMock *xpcProviderCachedMock = [[MSIDXpcProviderCacheMock alloc]
                                                       initWithXpcInstallationStatus:YES
                                                       isXpcValidated:NO];

    MSIDXpcCanPerformFailureReason reason = MSIDXpcCanPerformFailureReasonNone;
    XCTAssertFalse([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCachedMock reason:&reason]);
    XCTAssertEqual(reason, MSIDXpcCanPerformFailureReasonDeviceInfoRequestCreationFailed);
}

- (void)testSsoExtensionEnabled_deviceInfoHandshakeReturnsError_canPerformRequestWithReason_returnsDeviceInfoHandshakeError
{
    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(void)
    {
        return YES;
    }];

    SEL selectorForExecuteRequest = NSSelectorFromString(@"executeRequestWithCompletion:");
    [MSIDTestSwizzle instanceMethod:selectorForExecuteRequest
                              class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                              block:(id)^(id __unused selfRef, MSIDGetDeviceInfoRequestCompletionBlock completionBlock)
     {
        NSError *error = [NSError errorWithDomain:@"MSIDXpcSingleSignOnProviderTestDomain" code:-1 userInfo:nil];
        completionBlock(nil, error);
     }];

    MSIDXpcProviderCacheMock *xpcProviderCachedMock = [[MSIDXpcProviderCacheMock alloc]
                                                       initWithXpcInstallationStatus:YES
                                                       isXpcValidated:NO];

    MSIDXpcCanPerformFailureReason reason = MSIDXpcCanPerformFailureReasonNone;
    XCTAssertFalse([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCachedMock reason:&reason]);
    XCTAssertEqual(reason, MSIDXpcCanPerformFailureReasonDeviceInfoHandshakeError);
}

- (void)testSsoExtensionEnabled_deviceInfoHandshakeTimesOut_canPerformRequestWithReason_returnsDeviceInfoHandshakeTimeout
{
    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(void)
    {
        return YES;
    }];

    SEL selectorForExecuteRequest = NSSelectorFromString(@"executeRequestWithCompletion:");
    [MSIDTestSwizzle instanceMethod:selectorForExecuteRequest
                              class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                              block:(id)^(void)
     {
        // Intentionally never invoke the completion block, forcing the production 1 sec
        // dispatch_group_wait in canPerformRequest: to expire.
     }];

    MSIDXpcProviderCacheMock *xpcProviderCachedMock = [[MSIDXpcProviderCacheMock alloc]
                                                       initWithXpcInstallationStatus:YES
                                                       isXpcValidated:NO];

    MSIDXpcCanPerformFailureReason reason = MSIDXpcCanPerformFailureReasonNone;
    XCTAssertFalse([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCachedMock reason:&reason]);
    XCTAssertEqual(reason, MSIDXpcCanPerformFailureReasonDeviceInfoHandshakeTimeout);
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

    [MSIDTestSwizzle instanceMethod:NSSelectorFromString(@"getXpcService:requestCompleted:withContinueBlock:")
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:^(__unused id selfRef, __unused id<MSIDXpcProviderCaching> cache, __unused BOOL (^requestCompleted)(void), void (^continueBlock)(id, NSXPCConnection *, NSError *))
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

    [MSIDTestSwizzle instanceMethod:NSSelectorFromString(@"getXpcService:requestCompleted:withContinueBlock:")
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:^(__unused id selfRef, __unused id<MSIDXpcProviderCaching> cache, __unused BOOL (^requestCompleted)(void), void (^continueBlock)(id, NSXPCConnection *, NSError *))
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

    [MSIDTestSwizzle instanceMethod:NSSelectorFromString(@"getXpcService:requestCompleted:withContinueBlock:")
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:^(__unused id selfRef, __unused id<MSIDXpcProviderCaching> cache, __unused BOOL (^requestCompleted)(void), void (^continueBlock)(id, NSXPCConnection *, NSError *))
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

#pragma mark - Transport failure completion

- (void)testDispatcherEndpointTimeout_completesOnceWithError_lateEndpointReplyIsIgnored
{
    MSIDXpcTestDispatcherProxy *dispatcherProxy = [MSIDXpcTestDispatcherProxy new];
    MSIDXpcTestConnection *dispatcherConnection = [MSIDXpcTestConnection new];
    dispatcherConnection.remoteProxy = dispatcherProxy;

    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = dispatcherConnection;
    provider.directConnection = [MSIDXpcTestConnection new];

    __block NSUInteger completionCount = 0;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(__unused id response, NSError *error) {
        completionCount += 1;
        capturedError = error;
    }];

    XCTAssertEqual(provider.scheduledBlocks.count, 1u);
    dispatch_block_t endpointTimeoutBlock = provider.scheduledBlocks[0];
    endpointTimeoutBlock();
    [dispatcherProxy replyWithEndpoint:[NSXPCListenerEndpoint new] error:nil];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertEqualObjects(capturedError.domain, MSIDErrorDomain);
    XCTAssertEqual(capturedError.code, MSIDErrorBrokerXpcUnexpectedError);
    XCTAssertEqual(provider.directConnectionRequestCount, 0u);
    XCTAssertEqual(dispatcherConnection.suspendAfterInvalidationCount, 0u);
}

- (void)testBrokerReplyTimeout_completesOnceWithError_lateBrokerReplyIsIgnored
{
    MSIDXpcTestDispatcherProxy *dispatcherProxy = [MSIDXpcTestDispatcherProxy new];
    MSIDXpcTestBrokerProxy *brokerProxy = [MSIDXpcTestBrokerProxy new];
    MSIDXpcTestConnection *dispatcherConnection = [MSIDXpcTestConnection new];
    MSIDXpcTestConnection *directConnection = [MSIDXpcTestConnection new];
    dispatcherConnection.remoteProxy = dispatcherProxy;
    directConnection.remoteProxy = brokerProxy;

    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = dispatcherConnection;
    provider.directConnection = directConnection;

    __block NSUInteger completionCount = 0;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(__unused id response, NSError *error) {
        completionCount += 1;
        capturedError = error;
    }];

    [dispatcherProxy replyWithEndpoint:[NSXPCListenerEndpoint new] error:nil];
    XCTAssertEqual(provider.scheduledBlocks.count, 2u);
    dispatch_block_t brokerTimeoutBlock = provider.scheduledBlocks[1];
    brokerTimeoutBlock();
    [brokerProxy replyWithResponse:[self successfulBrokerResponse] error:nil];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertEqualObjects(capturedError.domain, MSIDErrorDomain);
    XCTAssertEqual(capturedError.code, MSIDErrorBrokerXpcUnexpectedError);
    XCTAssertEqual(directConnection.suspendAfterInvalidationCount, 0u);
}

- (void)testSilentRequest_schedulesBrokerReplyWatchdog
{
    MSIDXpcTestDispatcherProxy *dispatcherProxy = [MSIDXpcTestDispatcherProxy new];
    MSIDXpcTestBrokerProxy *brokerProxy = [MSIDXpcTestBrokerProxy new];
    MSIDXpcTestConnection *dispatcherConnection = [MSIDXpcTestConnection new];
    MSIDXpcTestConnection *directConnection = [MSIDXpcTestConnection new];
    dispatcherConnection.remoteProxy = dispatcherProxy;
    directConnection.remoteProxy = brokerProxy;

    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = dispatcherConnection;
    provider.directConnection = directConnection;

    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(__unused id response, __unused NSError *error) {}];

    [dispatcherProxy replyWithEndpoint:[NSXPCListenerEndpoint new] error:nil];

    // Silent requests schedule both the dispatcher endpoint-lookup watchdog and the 60s broker-reply
    // watchdog, so a hung broker on a non-interactive flow is still reclaimed.
    XCTAssertEqual(provider.scheduledBlocks.count, 2u);
    XCTAssertTrue([provider.scheduledTimeouts containsObject:@(60.0)]);
}

- (void)testInteractiveRequest_doesNotScheduleBrokerReplyWatchdog_delayedReplyStillCompletes
{
    MSIDXpcTestDispatcherProxy *dispatcherProxy = [MSIDXpcTestDispatcherProxy new];
    MSIDXpcTestBrokerProxy *brokerProxy = [MSIDXpcTestBrokerProxy new];
    MSIDXpcTestConnection *dispatcherConnection = [MSIDXpcTestConnection new];
    MSIDXpcTestConnection *directConnection = [MSIDXpcTestConnection new];
    dispatcherConnection.remoteProxy = dispatcherProxy;
    directConnection.remoteProxy = brokerProxy;

    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = dispatcherConnection;
    provider.directConnection = directConnection;

    __block NSUInteger completionCount = 0;
    __block id capturedResponse = nil;
    __block NSError *capturedError = nil;
    [self startInteractiveRequestWithProvider:provider
                                        cache:[self configuredXpcProviderCache]
                                   completion:^(id response, NSError *error) {
        completionCount += 1;
        capturedResponse = response;
        capturedError = error;
    }];

    [dispatcherProxy replyWithEndpoint:[NSXPCListenerEndpoint new] error:nil];

    // Interactive auth is gated on unbounded user interaction (password/MFA/consent), so only the
    // dispatcher endpoint-lookup watchdog is scheduled — the fixed broker-reply watchdog is disabled
    // and cannot abort a legitimate in-progress flow with a spurious timeout error.
    XCTAssertEqual(provider.scheduledBlocks.count, 1u);
    XCTAssertFalse([provider.scheduledTimeouts containsObject:@(60.0)]);

    // A broker reply that arrives after an arbitrary user-driven delay still completes successfully.
    [brokerProxy replyWithResponse:[self successfulBrokerResponse] error:nil];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertNil(capturedError);
    XCTAssertNotNil(capturedResponse);
}

- (void)testNilDispatcherConnection_completesOnceWithError
{
    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];

    __block NSUInteger completionCount = 0;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(__unused id response, NSError *error) {
        completionCount += 1;
        capturedError = error;
    }];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertEqualObjects(capturedError.domain, MSIDErrorDomain);
    XCTAssertEqual(capturedError.code, MSIDErrorBrokerXpcUnexpectedError);
}

- (void)testNilDispatcherProxy_completesOnceWithError
{
    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = [MSIDXpcTestConnection new];

    __block NSUInteger completionCount = 0;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(__unused id response, NSError *error) {
        completionCount += 1;
        capturedError = error;
    }];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertEqualObjects(capturedError.domain, MSIDErrorDomain);
    XCTAssertEqual(capturedError.code, MSIDErrorBrokerXpcUnexpectedError);
}

- (void)testNilEndpointAndNilError_completesOnceWithError
{
    MSIDXpcTestDispatcherProxy *dispatcherProxy = [MSIDXpcTestDispatcherProxy new];
    MSIDXpcTestConnection *dispatcherConnection = [MSIDXpcTestConnection new];
    dispatcherConnection.remoteProxy = dispatcherProxy;

    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = dispatcherConnection;

    __block NSUInteger completionCount = 0;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(__unused id response, NSError *error) {
        completionCount += 1;
        capturedError = error;
    }];
    [dispatcherProxy replyWithEndpoint:nil error:nil];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertEqualObjects(capturedError.domain, MSIDErrorDomain);
    XCTAssertEqual(capturedError.code, MSIDErrorBrokerXpcUnexpectedError);
}

- (void)testNilDirectConnection_completesOnceWithError
{
    MSIDXpcTestDispatcherProxy *dispatcherProxy = [MSIDXpcTestDispatcherProxy new];
    MSIDXpcTestConnection *dispatcherConnection = [MSIDXpcTestConnection new];
    dispatcherConnection.remoteProxy = dispatcherProxy;

    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = dispatcherConnection;

    __block NSUInteger completionCount = 0;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(__unused id response, NSError *error) {
        completionCount += 1;
        capturedError = error;
    }];
    [dispatcherProxy replyWithEndpoint:[NSXPCListenerEndpoint new] error:nil];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertEqualObjects(capturedError.domain, MSIDErrorDomain);
    XCTAssertEqual(capturedError.code, MSIDErrorBrokerXpcUnexpectedError);
}

- (void)testNilDirectProxy_completesOnceWithError
{
    MSIDXpcTestDispatcherProxy *dispatcherProxy = [MSIDXpcTestDispatcherProxy new];
    MSIDXpcTestConnection *dispatcherConnection = [MSIDXpcTestConnection new];
    dispatcherConnection.remoteProxy = dispatcherProxy;

    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = dispatcherConnection;
    provider.directConnection = [MSIDXpcTestConnection new];

    __block NSUInteger completionCount = 0;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(__unused id response, NSError *error) {
        completionCount += 1;
        capturedError = error;
    }];
    [dispatcherProxy replyWithEndpoint:[NSXPCListenerEndpoint new] error:nil];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertEqualObjects(capturedError.domain, MSIDErrorDomain);
    XCTAssertEqual(capturedError.code, MSIDErrorBrokerXpcUnexpectedError);
}

- (void)testDispatcherProxyError_completesWithUnderlyingFrameworkError
{
    MSIDXpcTestDispatcherProxy *dispatcherProxy = [MSIDXpcTestDispatcherProxy new];
    MSIDXpcTestConnection *dispatcherConnection = [MSIDXpcTestConnection new];
    dispatcherConnection.remoteProxy = dispatcherProxy;

    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = dispatcherConnection;

    NSError *frameworkError = [NSError errorWithDomain:NSCocoaErrorDomain code:4097 userInfo:nil];
    __block NSUInteger completionCount = 0;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(__unused id response, NSError *error) {
        completionCount += 1;
        capturedError = error;
    }];
    [dispatcherConnection fireProxyError:frameworkError];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertEqualObjects(capturedError.domain, MSIDErrorDomain);
    XCTAssertEqual(capturedError.code, MSIDErrorBrokerXpcUnexpectedError);
    XCTAssertEqualObjects(capturedError.userInfo[NSUnderlyingErrorKey], frameworkError);
}

- (void)testIntentionalDispatcherInvalidationAfterEndpoint_doesNotSuppressDirectSuccess
{
    MSIDXpcTestDispatcherProxy *dispatcherProxy = [MSIDXpcTestDispatcherProxy new];
    MSIDXpcTestBrokerProxy *brokerProxy = [MSIDXpcTestBrokerProxy new];
    MSIDXpcTestConnection *dispatcherConnection = [MSIDXpcTestConnection new];
    MSIDXpcTestConnection *directConnection = [MSIDXpcTestConnection new];
    dispatcherConnection.remoteProxy = dispatcherProxy;
    dispatcherConnection.invokeInvalidationHandlerOnInvalidate = YES;
    directConnection.remoteProxy = brokerProxy;

    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = dispatcherConnection;
    provider.directConnection = directConnection;

    __block NSUInteger completionCount = 0;
    __block id capturedResponse = nil;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(id response, NSError *error) {
        completionCount += 1;
        capturedResponse = response;
        capturedError = error;
    }];
    [dispatcherProxy replyWithEndpoint:[NSXPCListenerEndpoint new] error:nil];
    [brokerProxy replyWithResponse:[self successfulBrokerResponse] error:nil];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertNotNil(capturedResponse);
    XCTAssertNil(capturedError);
}

- (void)testIntentionalDispatcherInvalidationAfterEndpointError_preservesEndpointError
{
    MSIDXpcTestDispatcherProxy *dispatcherProxy = [MSIDXpcTestDispatcherProxy new];
    MSIDXpcTestConnection *dispatcherConnection = [MSIDXpcTestConnection new];
    dispatcherConnection.remoteProxy = dispatcherProxy;
    dispatcherConnection.invokeInvalidationHandlerOnInvalidate = YES;

    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = dispatcherConnection;

    NSError *endpointError = [NSError errorWithDomain:NSCocoaErrorDomain code:4099 userInfo:nil];
    __block NSUInteger completionCount = 0;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(__unused id response, NSError *error) {
        completionCount += 1;
        capturedError = error;
    }];
    [dispatcherProxy replyWithEndpoint:nil error:endpointError];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertEqualObjects(capturedError.userInfo[NSUnderlyingErrorKey], endpointError);
}

- (void)testDirectInterruptionInvalidationProxyErrorAndReplyRace_completesExactlyOnce
{
    MSIDXpcTestDispatcherProxy *dispatcherProxy = [MSIDXpcTestDispatcherProxy new];
    MSIDXpcTestBrokerProxy *brokerProxy = [MSIDXpcTestBrokerProxy new];
    MSIDXpcTestConnection *dispatcherConnection = [MSIDXpcTestConnection new];
    MSIDXpcTestConnection *directConnection = [MSIDXpcTestConnection new];
    dispatcherConnection.remoteProxy = dispatcherProxy;
    directConnection.remoteProxy = brokerProxy;

    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = dispatcherConnection;
    provider.directConnection = directConnection;

    __block NSUInteger completionCount = 0;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(__unused id response, NSError *error) {
        completionCount += 1;
        capturedError = error;
    }];
    [dispatcherProxy replyWithEndpoint:[NSXPCListenerEndpoint new] error:nil];

    [directConnection fireInterruption];
    [directConnection fireInvalidation];
    [directConnection fireProxyError:[NSError errorWithDomain:NSCocoaErrorDomain code:4097 userInfo:nil]];
    [brokerProxy replyWithResponse:[self successfulBrokerResponse] error:nil];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertNotNil(capturedError);
}

- (void)testDirectReplyBeforeInterruptionAndInvalidation_completesExactlyOnceWithResponse
{
    MSIDXpcTestDispatcherProxy *dispatcherProxy = [MSIDXpcTestDispatcherProxy new];
    MSIDXpcTestBrokerProxy *brokerProxy = [MSIDXpcTestBrokerProxy new];
    MSIDXpcTestConnection *dispatcherConnection = [MSIDXpcTestConnection new];
    MSIDXpcTestConnection *directConnection = [MSIDXpcTestConnection new];
    dispatcherConnection.remoteProxy = dispatcherProxy;
    directConnection.remoteProxy = brokerProxy;

    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = dispatcherConnection;
    provider.directConnection = directConnection;

    __block NSUInteger completionCount = 0;
    __block id capturedResponse = nil;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(id response, NSError *error) {
        completionCount += 1;
        capturedResponse = response;
        capturedError = error;
    }];
    [dispatcherProxy replyWithEndpoint:[NSXPCListenerEndpoint new] error:nil];

    [brokerProxy replyWithResponse:[self successfulBrokerResponse] error:nil];
    [directConnection fireInterruption];
    [directConnection fireInvalidation];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertNotNil(capturedResponse);
    XCTAssertNil(capturedError);
}

- (void)testUnsupportedDispatcherHelperPlatform_completesOnceWithError
{
    MSIDXpcTestSingleSignOnProvider *provider = [MSIDXpcTestSingleSignOnProvider new];
    provider.dispatcherConnection = [MSIDXpcTestConnection new];
    provider.platformSupported = NO;

    __block NSUInteger completionCount = 0;
    __block NSError *capturedError = nil;
    [self startRequestWithProvider:provider
                            cache:[self configuredXpcProviderCache]
                       completion:^(__unused id response, NSError *error) {
        completionCount += 1;
        capturedError = error;
    }];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertEqualObjects(capturedError.domain, MSIDErrorDomain);
    XCTAssertEqual(capturedError.code, MSIDErrorBrokerXpcUnexpectedError);
}

- (void)testInteractiveSynchronousProviderFailure_isDeliveredToCaller
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    MSIDSSOXpcInteractiveTokenRequest *request = [[MSIDSSOXpcInteractiveTokenRequest alloc] initWithRequestParameters:parameters
                                                                                                      oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                            tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]
                                                                                                        tokenCache:(id<MSIDCacheAccessor>)[NSObject new]
                                                                                              accountMetadataCache:nil
                                                                                                extendedTokenCache:nil];
    request.operationRequest = (MSIDBrokerOperationInteractiveTokenRequest *)[MSIDXpcTestInteractiveOperationRequest new];
    MSIDXpcTestSynchronousFailureProvider *provider = [MSIDXpcTestSynchronousFailureProvider new];
    provider.error = [NSError errorWithDomain:NSCocoaErrorDomain code:4097 userInfo:nil];
    request.xpcSingleSignOnProvider = provider;

    XCTestExpectation *expectation = [self expectationWithDescription:@"interactive completion"];
    __block NSUInteger completionCount = 0;
    __block NSError *capturedError = nil;
    [request executeRequestImplWithCompletionBlock:^(__unused MSIDTokenResult *result, NSError *error, __unused MSIDWebviewResponse *webviewResponse) {
        completionCount += 1;
        capturedError = error;
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1.0];

    XCTAssertEqual(completionCount, 1u);
    XCTAssertEqualObjects(capturedError, provider.error);
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

#pragma mark - Controller wrapper / reason-forwarding

// Locks the contract that the no-arg +canPerformRequest wrapper returns exactly what the
// +canPerformRequest:reason: overload returns, and that the overload forwards the provider's
// reason unchanged to the caller's out-param. The provider is swizzled so these controller-level
// tests don't depend on the shared MSIDXpcProviderCache internals.
- (void)testXpcSilentController_canPerformRequestOverload_forwardsProviderFailureReason
{
    if (@available(macOS 13, *))
    {
        [self swizzleProviderCanPerformRequestReturning:NO
                                                 reason:MSIDXpcCanPerformFailureReasonNoProviderInstalled];

        MSIDXpcCanPerformFailureReason reason = MSIDXpcCanPerformFailureReasonNone;
        XCTAssertFalse([MSIDXpcSilentTokenRequestController canPerformRequest:&reason]);
        XCTAssertEqual(reason, MSIDXpcCanPerformFailureReasonNoProviderInstalled);

        // The no-arg wrapper must agree with the overload's result and must not crash on nil out-param.
        XCTAssertFalse([MSIDXpcSilentTokenRequestController canPerformRequest]);
    }
    else
    {
        MSIDXpcCanPerformFailureReason reason = MSIDXpcCanPerformFailureReasonNone;
        XCTAssertFalse([MSIDXpcSilentTokenRequestController canPerformRequest:&reason]);
        XCTAssertEqual(reason, MSIDXpcCanPerformFailureReasonUnsupportedOSVersion);
    }
}

- (void)testXpcInteractiveController_canPerformRequestOverload_forwardsProviderFailureReason
{
    if (@available(macOS 13, *))
    {
        [self swizzleProviderCanPerformRequestReturning:NO
                                                 reason:MSIDXpcCanPerformFailureReasonValidateCacheProviderFailed];

        MSIDXpcCanPerformFailureReason reason = MSIDXpcCanPerformFailureReasonNone;
        XCTAssertFalse([MSIDXpcInteractiveTokenRequestController canPerformRequest:&reason]);
        XCTAssertEqual(reason, MSIDXpcCanPerformFailureReasonValidateCacheProviderFailed);

        XCTAssertFalse([MSIDXpcInteractiveTokenRequestController canPerformRequest]);
    }
    else
    {
        MSIDXpcCanPerformFailureReason reason = MSIDXpcCanPerformFailureReasonNone;
        XCTAssertFalse([MSIDXpcInteractiveTokenRequestController canPerformRequest:&reason]);
        XCTAssertEqual(reason, MSIDXpcCanPerformFailureReasonUnsupportedOSVersion);
    }
}

- (void)testXpcControllers_canPerformRequestOverload_successForwardsNoneReason
{
    if (@available(macOS 13, *))
    {
        [self swizzleProviderCanPerformRequestReturning:YES
                                                 reason:MSIDXpcCanPerformFailureReasonNone];

        // Pre-seed a non-None value to confirm the success path leaves it as None.
        MSIDXpcCanPerformFailureReason silentReason = MSIDXpcCanPerformFailureReasonNoProviderInstalled;
        XCTAssertTrue([MSIDXpcSilentTokenRequestController canPerformRequest:&silentReason]);
        XCTAssertEqual(silentReason, MSIDXpcCanPerformFailureReasonNone);
        XCTAssertTrue([MSIDXpcSilentTokenRequestController canPerformRequest]);

        MSIDXpcCanPerformFailureReason interactiveReason = MSIDXpcCanPerformFailureReasonNoProviderInstalled;
        XCTAssertTrue([MSIDXpcInteractiveTokenRequestController canPerformRequest:&interactiveReason]);
        XCTAssertEqual(interactiveReason, MSIDXpcCanPerformFailureReasonNone);
        XCTAssertTrue([MSIDXpcInteractiveTokenRequestController canPerformRequest]);
    }
}

- (void)swizzleProviderCanPerformRequestReturning:(BOOL)result
                                            reason:(MSIDXpcCanPerformFailureReason)reasonValue
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest:reason:)
                           class:[MSIDXpcSingleSignOnProvider class]
                           block:(id)^(__unused id selfRef,
                                       __unused id cache,
                                       MSIDXpcCanPerformFailureReason *reasonOut)
    {
        if (reasonOut)
        {
            *reasonOut = reasonValue;
        }
        return result;
    }];
}

@end
