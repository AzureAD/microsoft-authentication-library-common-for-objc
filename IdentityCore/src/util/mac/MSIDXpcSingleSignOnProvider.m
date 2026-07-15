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

#define requireIsAPPLSignedAnchor    "anchor apple generic"

#define requireIsAPPLSignedExternal "certificate 1[field.1.2.840.113635.100.6.2.6] exists"
#define requireIsMSFTSignedExternal "certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = UBF8T346G9"

#define coreRequirementExternal "(" requireIsAPPLSignedExternal    ") and (" requireIsMSFTSignedExternal ")"

// For App Store, Microsoft certificates don't show up in certificate chain.
// Instead, we check for the app to be Microsoft App Group.
#define requireIsAppStoreSigned        "certificate leaf[field.1.2.840.113635.100.6.1.9] exists"
#define requireBelongsToMSFTAppGroup "entitlement[\"com.apple.security.application-groups\"] = \"UBF8T346G9.\"*"

#define coreRequirementAppStore "(" requireIsAppStoreSigned ") and (" requireBelongsToMSFTAppGroup ")"

#define distributionRequirement "(" requireIsAPPLSignedAnchor ") and ((" coreRequirementAppStore ") or (" coreRequirementExternal "))"

// For internal builds only we also recognize dev builds but exclude them from external builds
// for sake of simplicity and performance

#define requireIsAPPLSignedInternal "certificate 1[field.1.2.840.113635.100.6.2.1] exists"
#define requireIsMSFTSignedInternal "certificate leaf[subject.CN] = \"%@\""

// requireIsXctestApp comes from the generated XctestCodeRequirement.h above
#define coreRequirementInternal "((" requireIsAPPLSignedInternal ") and (" requireIsMSFTSignedInternal "))"

#define developmentRequirement "(" requireIsAPPLSignedAnchor ") and ((" coreRequirementAppStore ") or (" coreRequirementExternal ") or (" coreRequirementInternal "))"

#import "MSIDXpcSingleSignOnProvider.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDBrokerCryptoProvider.h"
#import "MSIDBrokerConstants.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDRequestContext.h"
#import "MSIDConstants.h"
#import "MSIDSSOExtensionGetDeviceInfoRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDDeviceInfo.h"
#import "NSDate+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDLogger+Internal.h"
#import "MSIDXpcConfiguration.h"
#import "MSIDXpcProviderCaching.h"
#import "MSIDFlightManager.h"

static const NSTimeInterval MSIDXpcDispatcherEndpointLookupTimeout = 10.0;
static const NSTimeInterval MSIDXpcBrokerReplyTimeout = 60.0;

// Interactive broker requests are gated on real user interaction (password, MFA, consent) and
// therefore have no safe upper bound. Applying the fixed broker-reply watchdog to them could abort
// a legitimate in-progress flow and surface a spurious MSIDErrorBrokerXpcUnexpectedError, so the
// watchdog is disabled for interactive requests. A timeout value <= 0 disables the watchdog;
// connection interruption/invalidation still completes the request via the transport-failure path.
static const NSTimeInterval MSIDXpcBrokerReplyTimeoutDisabled = 0.0;

static NSError *MSIDXpcCreateTransportError(NSString *description, NSError *underlyingError)
{
    return MSIDCreateError(MSIDErrorDomain,
                           MSIDErrorBrokerXpcUnexpectedError,
                           description,
                           nil,
                           nil,
                           underlyingError,
                           nil,
                           nil,
                           YES);
}

@protocol MSIDXpcBrokerInstanceProtocol <NSObject>

- (void)handleXpcWithRequestParams:(NSDictionary *)passedInParams
                   parentViewFrame:(NSRect)frame
                   completionBlock:(void (^)(NSDictionary<NSString *,id> * _Nullable, NSDate * _Nonnull, NSString * _Nonnull, NSError * _Nullable))blockName;

- (void)canPerformWithMetadata:(NSDictionary *)passedInParams
               completionBlock:(void (^)(BOOL))blockName;

@end

@protocol MSIDXpcBrokerDispatcherProtocol <NSObject>

- (void)getBrokerInstanceEndpointWithReply:(void (^)(NSXPCListenerEndpoint  * _Nullable listenerEndpoint, NSDictionary * _Nullable params, NSError * _Nullable error))reply;
@end

typedef void (^NSXPCListenerEndpointCompletionBlock)(id<MSIDXpcBrokerInstanceProtocol> _Nullable xpcService, NSXPCConnection  * _Nullable directConnection, NSError *error);
typedef BOOL (^MSIDXpcRequestCompletedBlock)(void);

@interface MSIDXpcSingleSignOnProvider ()

// Returns whether the cached XPC instance endpoint should be used for this request.
// In DEBUG builds we default to YES so local developers don't need to configure the flight.
// Tests swizzle this to honor the flight regardless of build configuration so that
// flight-controlled behavior can be verified deterministically.
- (BOOL)isXpcInstanceCacheEnabled;
- (BOOL)isXpcPlatformSupported;

- (NSXPCConnection *)dispatcherConnectionWithMachServiceName:(NSString *)machServiceName;
- (NSXPCConnection *)directConnectionWithEndpoint:(NSXPCListenerEndpoint *)endpoint;
- (void)scheduleBlock:(dispatch_block_t)block afterTimeout:(NSTimeInterval)timeout;
- (void)getXpcService:(id<MSIDXpcProviderCaching>)xpcProviderCache
     requestCompleted:(MSIDXpcRequestCompletedBlock)requestCompleted
    withContinueBlock:(NSXPCListenerEndpointCompletionBlock)continueBlock;

// Shared funnel for both the silent and interactive public entry points. brokerReplyTimeout controls
// the broker-reply watchdog for this request (<= 0 disables it; see MSIDXpcBrokerReplyTimeoutDisabled).
- (void)handleRequestParam:(NSDictionary *)requestParam
           parentViewFrame:(NSRect)frame
 assertKindOfResponseClass:(Class)aClass
          xpcProviderCache:(id<MSIDXpcProviderCaching>)xpcProviderCache
                   context:(id<MSIDRequestContext>)context
        brokerReplyTimeout:(NSTimeInterval)brokerReplyTimeout
             continueBlock:(MSIDSSOExtensionRequestDelegateCompletionBlock)continueBlock;

- (void)attemptBrokerRequest:(NSDictionary *)requestParam
             parentViewFrame:(NSRect)frame
   assertKindOfResponseClass:(Class)aClass
            xpcProviderCache:(id<MSIDXpcProviderCaching>)xpcProviderCache
           useCachedEndpoint:(BOOL)useCachedEndpoint
          brokerReplyTimeout:(NSTimeInterval)brokerReplyTimeout
                     context:(id<MSIDRequestContext>)context
               continueBlock:(MSIDSSOExtensionRequestDelegateCompletionBlock)continueBlock;

@end

NSString *MSIDXpcCanPerformFailureReasonToString(MSIDXpcCanPerformFailureReason reason)
{
    switch (reason)
    {
        case MSIDXpcCanPerformFailureReasonNone:
            return @"None";
        case MSIDXpcCanPerformFailureReasonNoProviderInstalled:
            return @"NoProviderInstalled";
        case MSIDXpcCanPerformFailureReasonDeviceInfoRequestCreationFailed:
            return @"DeviceInfoRequestCreationFailed";
        case MSIDXpcCanPerformFailureReasonDeviceInfoHandshakeError:
            return @"DeviceInfoHandshakeError";
        case MSIDXpcCanPerformFailureReasonDeviceInfoHandshakeTimeout:
            return @"DeviceInfoHandshakeTimeout";
        case MSIDXpcCanPerformFailureReasonValidateCacheProviderFailed:
            return @"ValidateCacheProviderFailed";
        case MSIDXpcCanPerformFailureReasonUnsupportedOSVersion:
            return @"UnsupportedOSVersion";
    }

    return @"Unknown";
}

@implementation MSIDXpcSingleSignOnProvider

- (BOOL)isXpcInstanceCacheEnabled
{
#if DEBUG
    return YES;
#else
    return [[MSIDFlightManager sharedInstance] boolForKey:MSID_FLIGHT_BROKER_XPC_INSTANCE_CACHE_ENABLED];
#endif
}

- (BOOL)isXpcPlatformSupported
{
    if (@available(macOS 13.0, *))
    {
        return YES;
    }

    return NO;
}

- (void)handleRequestParam:(NSDictionary *)requestParam
 assertKindOfResponseClass:(Class)aClass
          xpcProviderCache:(id<MSIDXpcProviderCaching>)xpcProviderCache
                   context:(id<MSIDRequestContext>)context
             continueBlock:(MSIDSSOExtensionRequestDelegateCompletionBlock)continueBlock
{
    // Silent requests are not gated on user interaction, so the standard broker-reply watchdog applies.
    [self handleRequestParam:requestParam
             parentViewFrame:CGRectZero
   assertKindOfResponseClass:(Class)aClass
            xpcProviderCache:xpcProviderCache
                     context:(id<MSIDRequestContext>)context
          brokerReplyTimeout:MSIDXpcBrokerReplyTimeout
               continueBlock:continueBlock];
}

- (void)handleRequestParam:(NSDictionary *)requestParam
           parentViewFrame:(NSRect)frame
 assertKindOfResponseClass:(Class)aClass
          xpcProviderCache:(id<MSIDXpcProviderCaching>)xpcProviderCache
                   context:(id<MSIDRequestContext>)context
             continueBlock:(MSIDSSOExtensionRequestDelegateCompletionBlock)continueBlock
{
    // Interactive requests are gated on real user interaction (password, MFA, consent), which has no
    // safe upper bound, so the broker-reply watchdog is disabled to avoid aborting a legitimate flow.
    [self handleRequestParam:requestParam
             parentViewFrame:frame
   assertKindOfResponseClass:aClass
            xpcProviderCache:xpcProviderCache
                     context:context
          brokerReplyTimeout:MSIDXpcBrokerReplyTimeoutDisabled
               continueBlock:continueBlock];
}

- (void)handleRequestParam:(NSDictionary *)requestParam
           parentViewFrame:(NSRect)frame
 assertKindOfResponseClass:(Class)aClass
          xpcProviderCache:(id<MSIDXpcProviderCaching>)xpcProviderCache
                   context:(id<MSIDRequestContext>)context
        brokerReplyTimeout:(NSTimeInterval)brokerReplyTimeout
             continueBlock:(MSIDSSOExtensionRequestDelegateCompletionBlock)continueBlock
{
    [self attemptBrokerRequest:requestParam
               parentViewFrame:frame
     assertKindOfResponseClass:aClass
              xpcProviderCache:xpcProviderCache
             useCachedEndpoint:[self isXpcInstanceCacheEnabled]
            brokerReplyTimeout:brokerReplyTimeout
                       context:context
                 continueBlock:continueBlock];
}

// Single attempt at a broker request. When useCachedEndpoint=YES and a cached endpoint is
// available, builds the instance NSXPCConnection directly from the cached endpoint and skips
// the dispatcher round-trip; on any transport-level failure of that cached attempt (proxy
// error, connection interruption/invalidation BEFORE the request reply), the cache is cleared
// and we recurse exactly once with useCachedEndpoint=NO so the retry goes through the
// dispatcher.
//
// useCachedEndpoint MUST be NO on the recursive (dispatcher-fallback) attempt — otherwise an
// infinite loop is possible if the dispatcher path itself transports through a stale endpoint.
//
// A two-flag completion gate is used:
//   - requestReplyReceived: set synchronously inside handleXpcWithRequestParams: callback so the
//     subsequent (self-issued) [directConnection invalidate] does not get treated as a transport
//     failure by the connection's invalidation handler.
//   - outerCompleted: dedups delivery to `continueBlock` (covers connection-handler vs request-reply
//     races, double-fire of invalidation+interruption, etc.).
- (void)attemptBrokerRequest:(NSDictionary *)requestParam
             parentViewFrame:(NSRect)frame
   assertKindOfResponseClass:(Class)aClass
            xpcProviderCache:(id<MSIDXpcProviderCaching>)xpcProviderCache
           useCachedEndpoint:(BOOL)useCachedEndpoint
          brokerReplyTimeout:(NSTimeInterval)brokerReplyTimeout
                     context:(id<MSIDRequestContext>)context
               continueBlock:(MSIDSSOExtensionRequestDelegateCompletionBlock)continueBlock
{
    __block BOOL requestReplyReceived = NO;
    __block BOOL outerCompleted = NO;
    __block BOOL fromCache = NO;
    NSObject *stateLock = [NSObject new];
    __weak typeof(self) weakSelf = self;

    // Atomically claims the "completion" slot. Returns YES on the first call, NO thereafter.
    // All read-and-set on `outerCompleted` MUST go through this gate to prevent racing
    // callbacks (interruption/invalidation handler vs. reply block vs. retry path) from
    // delivering `continueBlock` more than once.
    BOOL (^claimCompletion)(void) = ^BOOL {
        @synchronized (stateLock)
        {
            if (outerCompleted) return NO;
            outerCompleted = YES;
            return YES;
        }
    };

    BOOL (^isCompleted)(void) = ^BOOL {
        @synchronized (stateLock)
        {
            return outerCompleted;
        }
    };

    // Marks the request reply as received. Returns the previous value so callers can
    // distinguish "this is the reply" from "the reply already arrived".
    BOOL (^markReplyReceived)(void) = ^BOOL {
        @synchronized (stateLock)
        {
            BOOL prev = requestReplyReceived;
            requestReplyReceived = YES;
            return prev;
        }
    };

    BOOL (^isReplyReceived)(void) = ^BOOL {
        @synchronized (stateLock)
        {
            return requestReplyReceived;
        }
    };

    NSXPCListenerEndpointCompletionBlock continueBlockInternal = ^(id<MSIDXpcBrokerInstanceProtocol> xpcService, NSXPCConnection *directConnection, NSError *error)
    {
        if (isCompleted())
        {
            [directConnection invalidate];
            return;
        }

        NSError *transportError = error;
        if (!transportError && !xpcService)
        {
            transportError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- XPC service proxy is unavailable", nil);
        }
        else if (!transportError && !directConnection)
        {
            transportError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- XPC direct connection is unavailable", nil);
        }

        if (!xpcService || !directConnection || transportError)
        {
            // Connection-establishment / connection-handler failure path.
            // If the request reply already came in, this is just our own [directConnection invalidate]
            // firing — ignore.
            if (isReplyReceived()) return;
            if (!claimCompletion()) return;

            if (fromCache && useCachedEndpoint)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[Entra broker] CLIENT - cached XPC endpoint failed (%@), clearing cache and retrying via dispatcher", transportError);
                [xpcProviderCache clearCachedBrokerInstanceEndpoint];
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf)
                {
                    // Provider deallocated mid-flight — we still owe the caller a callback.
                    if (continueBlock) continueBlock(nil, transportError);
                    return;
                }
                // Note: the recursive call has its own __block completion state, so the outer
                // frame's outerCompleted=YES claim correctly stays latched — any late-firing
                // outer-frame callback (e.g. invalidation handler from the cache-hit connection)
                // will be ignored.
                [strongSelf attemptBrokerRequest:requestParam
                                 parentViewFrame:frame
                       assertKindOfResponseClass:aClass
                                xpcProviderCache:xpcProviderCache
                               useCachedEndpoint:NO
                              brokerReplyTimeout:brokerReplyTimeout
                                         context:context
                                   continueBlock:continueBlock];
                return;
            }

            if (continueBlock) continueBlock(nil, transportError);
            return;
        }

        // Broker-reply watchdog. Disabled (brokerReplyTimeout <= 0) for interactive requests, whose
        // reply is gated on unbounded user interaction; a connection interruption/invalidation still
        // completes the request via the transport-failure path above.
        if (brokerReplyTimeout > 0)
        {
            NSError *brokerReplyTimeoutError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- broker reply timed out", nil);
            [self scheduleBlock:^{
                if (isReplyReceived()) return;
                if (!claimCompletion()) return;

                [directConnection suspend];
                [directConnection invalidate];
                if (continueBlock) continueBlock(nil, brokerReplyTimeoutError);
            } afterTimeout:brokerReplyTimeout];
        }

        [xpcService handleXpcWithRequestParams:requestParam parentViewFrame:frame completionBlock:^(NSDictionary<NSString *,id> * _Nullable replyParam, NSDate * _Nonnull __unused xpcStartDate, NSString * _Nonnull __unused processId, NSError * _Nullable callbackError) {
            // Mark synchronously so the connection's invalidation handler (which fires as a side
            // effect of our own invalidate below) does not treat this as a transport failure.
            (void)markReplyReceived();
            if (isCompleted()) return;

            [directConnection suspend];
            [directConnection invalidate];

            BOOL forceRunOnBackgroundQueue = [[replyParam objectForKey:MSID_BROKER_OPERATION_KEY] isEqualToString:@"refresh"];
            [self forceRunOnBackgroundQueue:forceRunOnBackgroundQueue dispatchBlock:^{
                if (!claimCompletion()) return;

                if (callbackError)
                {
                    MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"[Entra broker] CLIENT received operationResponse with error: %@", callbackError);
                    if (continueBlock) continueBlock(nil, callbackError);
                    return;
                }

                NSError *innerError = nil;
                __auto_type operationResponse = (MSIDBrokerOperationTokenResponse *)[MSIDJsonSerializableFactory createFromJSONDictionary:replyParam classTypeJSONKey:MSID_BROKER_OPERATION_RESPONSE_TYPE_JSON_KEY assertKindOfClass:aClass error:&innerError];

                if (!operationResponse)
                {
                    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Entra broker] CLIENT cannot create operationResponse");
                    if (continueBlock) continueBlock(nil, innerError);
                }
                else
                {
                    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Entra broker] CLIENT received operationResponse, error: %@", callbackError);
                    if (continueBlock) continueBlock(operationResponse, callbackError);
                }
            }];
        }];
    };

    NSXPCListenerEndpoint *cachedEndpoint = useCachedEndpoint ? xpcProviderCache.cachedBrokerInstanceEndpoint : nil;
    if (cachedEndpoint)
    {
        fromCache = YES;
        [self getXpcServiceFromCachedEndpoint:cachedEndpoint
                             xpcProviderCache:xpcProviderCache
                                      context:context
                            withContinueBlock:continueBlockInternal];
    }
    else
    {
        fromCache = NO;
        [self getXpcService:xpcProviderCache
           requestCompleted:isCompleted
          withContinueBlock:continueBlockInternal];
    }
}

+ (BOOL)canPerformRequest:(id<MSIDXpcProviderCaching>)xpcProviderCache
{
    return [self canPerformRequest:xpcProviderCache reason:nil];
}

+ (BOOL)canPerformRequest:(id<MSIDXpcProviderCaching>)xpcProviderCache
                    reason:(MSIDXpcCanPerformFailureReason *)reason
{
    // Step 0: If none of the XPC components (CP or MacBrokerApp) exist on the device, return false.
    // Step 1: Read from the userDefaults cache to find the correct XPC configuration based on the active SsoExtension.
        // Step 1.1: If the XPC configuration is found, validate the existence of the corresponding XPC component based on the configuration.
            // Step 1.1.1: If the XPC component no longer exists on the device, return false (this is unlikely to happen in a short time period).
            // Step 1.1.2: If the XPC component exists on the device, return true.
        // Step 1.2: If the cache is not found, perform a handshake with the SsoExtension (canPerformRequest -> getDeviceInfo).
            // Step 1.2.1: If the handshake succeeds, update the XPC provider cache and configuration, then go to Step 1.1.
            // Step 1.2.2: If the handshake fails because canPerformRequest returns NO, use predefined logic to decide the XPC provider/configuration (use the XPC component from the MacBrokerApp first, then from the CompanyPortal App).
                // Step 1.2.2.1: If using the XPC provider from the MacBroker App, return true.
                // Step 1.2.2.2: If using the XPC provider from the CompanyPortal App, return true.

    if (reason)
    {
        *reason = MSIDXpcCanPerformFailureReasonNone;
    }

    /* Step 0 Start*/
    if (!xpcProviderCache.isXpcProviderInstalledOnDevice)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Entra broker] CLIENT Xpc component is not available on device", nil, nil);
        if (reason)
        {
            *reason = MSIDXpcCanPerformFailureReasonNoProviderInstalled;
        }
        return NO;
    }
    /* Step 0 End*/
    
    // Tracks whether the getDeviceInfo handshake below hit a hard error or timed out, so that if the
    // subsequent validateCacheXpcProvider check ultimately fails, we can report the more specific root cause.
    __block BOOL handshakeHadError = NO;
    BOOL handshakeTimedOut = NO;

    /* Step 1 Start: decide Xpc configuration */
    if (!xpcProviderCache.xpcConfiguration && [MSIDSSOExtensionGetDeviceInfoRequest canPerformRequest])
    {
        MSIDRequestParameters *requestParams = [[MSIDRequestParameters alloc] initWithAuthority:nil
                                                                                     authScheme:nil
                                                                                    redirectUri:nil
                                                                                       clientId:nil
                                                                                         scopes:nil
                                                                                     oidcScopes:nil
                                                                                  correlationId:[NSUUID UUID]
                                                                                 telemetryApiId:nil
                                                                            intuneAppIdentifier:nil
                                                                                    requestType:MSIDRequestBrokeredType
                                                                                          error:nil];
        NSError *ssoExtensionRequestError = nil;
        MSIDSSOExtensionGetDeviceInfoRequest *ssoExtensionRequest = [[MSIDSSOExtensionGetDeviceInfoRequest alloc] initWithRequestParameters:requestParams error:&ssoExtensionRequestError];
        if (!ssoExtensionRequest || ssoExtensionRequestError)
        {
            // This is unlikely to happen, but if it does, return NO
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"[Entra broker] CLIENT get error when creating getDeviceInfoRequest with error: %@", ssoExtensionRequestError);
            if (reason)
            {
                *reason = MSIDXpcCanPerformFailureReasonDeviceInfoRequestCreationFailed;
            }
            return NO;
        }
    
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);
        // deviceInfo is assigned to the Xpc configuration during json dictionary to model mapping in MSIDDeviceInfo.m
        [ssoExtensionRequest executeRequestWithCompletion:^(MSIDDeviceInfo * __unused _Nullable deviceInfo, NSError * _Nullable error)
         {
            if (error)
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"[Entra broker] CLIENT did not receive deviceInfo with error: %@", error);
                handshakeHadError = YES;
                dispatch_group_leave(group);
                return;
            }
            
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"[Entra broker] CLIENT received deviceInfo successfully", nil);
            dispatch_group_leave(group);
        }];
        
        // waiting expired in 1 sec
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC);
        long waitResult = dispatch_group_wait(group, timeout);
        handshakeTimedOut = (waitResult != 0);
        if (handshakeTimedOut)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[Entra broker] CLIENT getDeviceInfo handshake timed out after 1 sec", nil, nil);
        }
    }
    
    if (!xpcProviderCache.xpcConfiguration)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Entra broker] CLIENT no Xpc configuration available. start manual selection.", nil, nil);
    }
    
    if (![xpcProviderCache validateCacheXpcProvider])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Entra broker] CLIENT no %@ Xpc component found on device. Failed to validate cached Xpc and skip Xpc flow", xpcProviderCache.xpcConfiguration.xpcHostAppName, nil);
        // Reset the cached Xpc provider/configuration.
        xpcProviderCache.cachedXpcProviderType = MSIDUnknownSsoProvider;
        if (reason)
        {
            // If the getDeviceInfo handshake above timed out or errored, surface that as the root cause
            // instead of the more generic validation failure it ultimately fell through to.
            if (handshakeTimedOut)
            {
                *reason = MSIDXpcCanPerformFailureReasonDeviceInfoHandshakeTimeout;
            }
            else if (handshakeHadError)
            {
                *reason = MSIDXpcCanPerformFailureReasonDeviceInfoHandshakeError;
            }
            else
            {
                *reason = MSIDXpcCanPerformFailureReasonValidateCacheProviderFailed;
            }
        }
        return NO;
    }
    
    /* Step 1 Finish */
    
    return YES;
}

#pragma mark - Helpers

- (NSString *)codeSignRequirementForBundleId:(NSString *)bundleId devIdentity:(NSString *)devIdentity
{
#if DEBUG
    if ([NSString msidIsStringNilOrBlank:devIdentity])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"devIdentity is not provided, fail to set code sign requirement for Xpc service. End early", nil, nil);
        return nil;
    }
    
    NSString *codeSignFormat = [NSString stringWithCString:developmentRequirement encoding:NSUTF8StringEncoding];
    NSString *baseRequirementWithDevIdentity = [NSString stringWithFormat:codeSignFormat, devIdentity];
    NSString *stringWithAdditionalRequirements = [NSString stringWithFormat:@"(identifier \"%@\") and %@"
                                                  " and !(entitlement[\"com.apple.security.cs.allow-dyld-environment-variables\"] /* exists */)"
                                                  " and !(entitlement[\"com.apple.security.cs.disable-library-validation\"] /* exists */)"
                                                  " and !(entitlement[\"com.apple.security.cs.allow-unsigned-executable-memory\"] /* exists */)"
                                                  " and !(entitlement[\"com.apple.security.cs.allow-jit\"] /* exists */)", bundleId, baseRequirementWithDevIdentity];
#else
    NSString *baseRequirementWithDevIdentity = [NSString stringWithCString:distributionRequirement encoding:NSUTF8StringEncoding];
    NSString *stringWithAdditionalRequirements = [NSString stringWithFormat:@"(identifier \"%@\") and %@"
                                                  " and !(entitlement[\"com.apple.security.cs.allow-dyld-environment-variables\"] /* exists */)"
                                                  " and !(entitlement[\"com.apple.security.cs.disable-library-validation\"] /* exists */)"
                                                  " and !(entitlement[\"com.apple.security.cs.allow-unsigned-executable-memory\"] /* exists */)"
                                                  " and !(entitlement[\"com.apple.security.cs.allow-jit\"] /* exists */)"
                                                  " and !(entitlement[\"com.apple.security.get-task-allow\"] /* exists */)" , bundleId, baseRequirementWithDevIdentity];
#endif
    
    return stringWithAdditionalRequirements;
}

- (NSString *)signingIdentity
{
    SecCodeRef selfCode = NULL;
    OSStatus status = SecCodeCopySelf(kSecCSDefaultFlags, &selfCode);
    
    if (!selfCode)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, [NSString stringWithFormat:@"Failed to copy signing information, status; %ld", (long)status], nil, nil);
        return nil;
    }
    
    CFDictionaryRef cfDic = NULL;
    status = SecCodeCopySigningInformation(selfCode, kSecCSSigningInformation, &cfDic);
    
    if (!cfDic)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, [NSString stringWithFormat:@"Failed to copy signing dictionary, status: %ld", (long)status], nil, nil);
        CFRelease(selfCode);
        return nil;
    }
    
    NSDictionary *signingDic = CFBridgingRelease(cfDic);
    CFRelease(selfCode);
    
    return [self devSigningIdentityFromSigningDictionary:signingDic];
}

- (NSString *)devSigningIdentityFromSigningDictionary:(NSDictionary *)signingDic
{
    NSArray *signingCertificates = signingDic[@"certificates"];
    
    if (!signingCertificates
        || ![signingCertificates isKindOfClass:[NSArray class]]
        || ![signingCertificates count])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"No certificates present in the signing dictionary", nil, nil);
        return nil;
    }
    
    SecCertificateRef leafCert = (__bridge SecCertificateRef)(signingCertificates[0]);
    CFStringRef certCommonName = NULL;
    OSStatus status = SecCertificateCopyCommonName(leafCert, &certCommonName);
    
    if (!certCommonName)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, [NSString stringWithFormat:@"Error with code %ld, description %@", (long)status, @"Failed to copy certificate common name"], nil, nil);
        return nil;
    }
    
    return CFBridgingRelease(certCommonName);
}

- (void)forceRunOnBackgroundQueue:(BOOL)forceOnBackgroundQueue dispatchBlock:(void (^)(void))dispatchBlock
{
    if (forceOnBackgroundQueue && [NSThread isMainThread])
    {
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            dispatchBlock();
        });
    }
    else
    {
        dispatchBlock();
    }
}

- (NSXPCConnection *)dispatcherConnectionWithMachServiceName:(NSString *)machServiceName
{
    return [[NSXPCConnection alloc] initWithMachServiceName:machServiceName options:0];
}

- (NSXPCConnection *)directConnectionWithEndpoint:(NSXPCListenerEndpoint *)endpoint
{
    return [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
}

- (void)scheduleBlock:(dispatch_block_t)block afterTimeout:(NSTimeInterval)timeout
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0),
                   block);
}

- (void)getXpcService:(id<MSIDXpcProviderCaching>)xpcProviderCache
     requestCompleted:(MSIDXpcRequestCompletedBlock)requestCompleted
    withContinueBlock:(NSXPCListenerEndpointCompletionBlock)continueBlock
{
    if (!xpcProviderCache.xpcConfiguration)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[Entra broker] CLIENT - Code should not be triggerred at here", nil, nil);
        continueBlock(nil, nil, MSIDXpcCreateTransportError(@"[Entra broker] CLIENT - Xpc configuration is not available", nil));
        return;
    }

    // Capture the cached provider type *before* the dispatcher round-trip. The endpoint we are
    // about to fetch is bound to this provider; if cachedXpcProviderType changes mid-flight
    // (provider switch), the CAS in setCachedBrokerInstanceEndpoint:forProviderType: will reject
    // the write and we will not pollute the cache.
    MSIDSsoProviderType capturedProviderType = xpcProviderCache.cachedXpcProviderType;
    BOOL cacheEnabled = [self isXpcInstanceCacheEnabled];

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Entra broker] CLIENT - started establishing connection to %@", xpcProviderCache.xpcConfiguration.xpcMachServiceName);
    NSXPCConnection *connection = [self dispatcherConnectionWithMachServiceName:xpcProviderCache.xpcConfiguration.xpcMachServiceName];
    if (!connection)
    {
        continueBlock(nil, nil, MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- dispatcher connection is unavailable", nil));
        return;
    }
    
    NSString *codeSigningRequirement = [self codeSignRequirementForBundleId:xpcProviderCache.xpcConfiguration.xpcBrokerDispatchServiceBundleId devIdentity:[self signingIdentity]];
    if ([NSString msidIsStringNilOrBlank:codeSigningRequirement])
    {
        // This can only happen under debug build under development environment
        continueBlock(nil, nil, MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"[Entra broker] CLIENT -- developer error, codeSigningRequirement is not provided", nil, nil, nil, nil, nil, YES));
        return;
    }
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(MSIDXpcBrokerDispatcherProtocol)];
    if ([self isXpcPlatformSupported])
    {
        if (@available(macOS 13.0, *))
        {
            [connection setCodeSigningRequirement:codeSigningRequirement];
        }
    }
    else
    {
        continueBlock(nil, nil, MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- unsupported platform for dispatcher connection", nil));
        return;
    }

    NSObject *dispatcherStateLock = [NSObject new];
    __block BOOL dispatcherReplyReceived = NO;
    void (^markDispatcherReplyReceived)(void) = ^{
        @synchronized (dispatcherStateLock)
        {
            dispatcherReplyReceived = YES;
        }
    };
    BOOL (^isDispatcherReplyReceived)(void) = ^BOOL {
        @synchronized (dispatcherStateLock)
        {
            return dispatcherReplyReceived;
        }
    };

    // Install handlers BEFORE resume so a synchronous failure cannot fire in the gap between
    // resume and handler installation.
    [connection setInterruptionHandler:^{
        if (isDispatcherReplyReceived() || requestCompleted()) return;

        NSError *xpcError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- dispatcher connection is interrupted", nil);
        if (continueBlock) continueBlock(nil, nil, xpcError);
    }];

    [connection setInvalidationHandler:^{
        if (isDispatcherReplyReceived() || requestCompleted()) return;

        NSError *xpcError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- dispatcher connection is invalidated", nil);
        if (continueBlock) continueBlock(nil, nil, xpcError);
    }];

    [connection resume];

    id<MSIDXpcBrokerDispatcherProtocol> parentXpcService = [connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        if (isDispatcherReplyReceived() || requestCompleted()) return;

        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Entra broker] CLIENT -- failed to connect to dispatcher, error: %@", error);
        NSError *xpcError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- failed to connect to dispatcher", error);
        if (continueBlock) continueBlock(nil, nil, xpcError);
        [connection invalidate];
    }];
    if (!parentXpcService)
    {
        NSError *xpcError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- dispatcher proxy is unavailable", nil);
        if (continueBlock) continueBlock(nil, nil, xpcError);
        [connection invalidate];
        return;
    }

    NSError *dispatcherTimeoutError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- dispatcher endpoint lookup timed out", nil);
    [self scheduleBlock:^{
        if (isDispatcherReplyReceived() || requestCompleted()) return;

        if (continueBlock) continueBlock(nil, nil, dispatcherTimeoutError);
        [connection invalidate];
    } afterTimeout:MSIDXpcDispatcherEndpointLookupTimeout];
    
    [parentXpcService getBrokerInstanceEndpointWithReply:^(NSXPCListenerEndpoint * _Nullable listenerEndpoint, NSDictionary<NSString *, id> * _Nullable __unused params, NSError * _Nullable error) {
        markDispatcherReplyReceived();
        if (requestCompleted())
        {
            return;
        }

        [connection suspend];

        if (error)
        {
            NSError *xpcUnexpectedError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT - get broker instance endpoint failed", error);
            if (continueBlock) continueBlock(nil, nil, xpcUnexpectedError);
            [connection invalidate];
            return;
        }

        if (!listenerEndpoint)
        {
            NSError *xpcUnexpectedError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT - broker instance endpoint is unavailable", nil);
            if (continueBlock) continueBlock(nil, nil, xpcUnexpectedError);
            [connection invalidate];
            return;
        }

        [connection invalidate];
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Entra broker] CLIENT - connected to new service endpoint %@", listenerEndpoint);

        // Populate cache with the freshly-issued endpoint. CAS against the providerType captured
        // before this round-trip began. If the provider type has switched in the meantime, the
        // setter rejects the write and we leave the cache as-is.
        if (cacheEnabled && listenerEndpoint)
        {
            BOOL stored = [xpcProviderCache setCachedBrokerInstanceEndpoint:listenerEndpoint forProviderType:capturedProviderType];
            if (!stored)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Entra broker] CLIENT - provider type changed during dispatcher round-trip; not caching endpoint");
            }
        }

        NSXPCConnection *directConnection = [self directConnectionWithEndpoint:listenerEndpoint];
        if (!directConnection)
        {
            NSError *xpcUnexpectedError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- direct connection is unavailable", nil);
            if (continueBlock) continueBlock(nil, nil, xpcUnexpectedError);
            return;
        }

        directConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(MSIDXpcBrokerInstanceProtocol)];
        NSString *clientCodeSigningRequirement = [self codeSignRequirementForBundleId:xpcProviderCache.xpcConfiguration.xpcBrokerInstanceServiceBundleId devIdentity:[self signingIdentity]];
        if ([NSString msidIsStringNilOrBlank:clientCodeSigningRequirement])
        {
            // This can only happen under debug build under development environment
            continueBlock(nil, nil, MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"[Entra broker] CLIENT -- developer error, codeSigningRequirement is not provided", nil, nil, nil, nil, nil, YES));
            return;
        }
        
        if ([self isXpcPlatformSupported])
        {
            if (@available(macOS 13.0, *))
            {
                [directConnection setCodeSigningRequirement:clientCodeSigningRequirement];
            }
        }
        else
        {
            NSError *xpcUnexpectedError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- unsupported platform for direct connection", nil);
            if (continueBlock) continueBlock(nil, nil, xpcUnexpectedError);
            return;
        }

        // Install handlers BEFORE resume.
        [directConnection setInterruptionHandler:^{
            NSError *xpcError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- instance connection is interrupted", nil);
            if (continueBlock) continueBlock(nil, nil, xpcError);
        }];

        [directConnection setInvalidationHandler:^{
            NSError *xpcError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- instance connection is invalidated", nil);
            if (continueBlock) continueBlock(nil, nil, xpcError);
        }];

        id<MSIDXpcBrokerInstanceProtocol> directService = [directConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull callbackError) {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Entra broker] CLIENT -- failed to connect to instance, error: %@", callbackError);
            if (continueBlock) continueBlock(nil, nil, callbackError);
            [directConnection invalidate];
        }];
        if (!directService)
        {
            NSError *xpcUnexpectedError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- direct proxy is unavailable", nil);
            if (continueBlock) continueBlock(nil, directConnection, xpcUnexpectedError);
            [directConnection invalidate];
            return;
        }

        [directConnection resume];

        if (continueBlock) continueBlock(directService, directConnection, nil);
    }];
}

// Cache-hit fast path: build the instance NSXPCConnection directly from a previously-cached
// NSXPCListenerEndpoint, bypassing the dispatcher. Failures (proxy error, interruption, or
// invalidation BEFORE the request reply) are reported through `continueBlock`; the caller is
// expected to treat them as transport failures and retry through the dispatcher.
- (void)getXpcServiceFromCachedEndpoint:(NSXPCListenerEndpoint *)endpoint
                       xpcProviderCache:(id<MSIDXpcProviderCaching>)xpcProviderCache
                                context:(id<MSIDRequestContext>)context
                      withContinueBlock:(NSXPCListenerEndpointCompletionBlock)continueBlock
{
    if (!xpcProviderCache.xpcConfiguration)
    {
        if (continueBlock) continueBlock(nil, nil, MSIDCreateError(MSIDErrorDomain, MSIDErrorBrokerXpcUnexpectedError, @"[Entra broker] CLIENT - Xpc configuration is not available", nil, nil, nil, nil, nil, YES));
        return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"[Entra broker] CLIENT - using cached XPC instance endpoint, skipping dispatcher round-trip");

    if (!endpoint)
    {
        if (continueBlock) continueBlock(nil, nil, MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- cached instance endpoint is unavailable", nil));
        return;
    }

    NSXPCConnection *directConnection = [self directConnectionWithEndpoint:endpoint];
    if (!directConnection)
    {
        if (continueBlock) continueBlock(nil, nil, MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- cached direct connection is unavailable", nil));
        return;
    }

    directConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(MSIDXpcBrokerInstanceProtocol)];

    NSString *clientCodeSigningRequirement = [self codeSignRequirementForBundleId:xpcProviderCache.xpcConfiguration.xpcBrokerInstanceServiceBundleId devIdentity:[self signingIdentity]];
    if ([NSString msidIsStringNilOrBlank:clientCodeSigningRequirement])
    {
        if (continueBlock) continueBlock(nil, nil, MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"[Entra broker] CLIENT -- developer error, codeSigningRequirement is not provided", nil, nil, nil, nil, nil, YES));
        return;
    }

    if ([self isXpcPlatformSupported])
    {
        if (@available(macOS 13.0, *))
        {
            [directConnection setCodeSigningRequirement:clientCodeSigningRequirement];
        }
    }
    else
    {
        // Should not happen — XPC flow is gated to macOS 13+ via canPerformRequest:.
        if (continueBlock) continueBlock(nil, nil, MSIDCreateError(MSIDErrorDomain, MSIDErrorBrokerXpcUnexpectedError, @"[Entra broker] CLIENT -- unsupported platform for cached endpoint connection", nil, nil, nil, nil, nil, YES));
        return;
    }

    // Install handlers BEFORE resume so a synchronous failure on a stale endpoint does not slip
    // through the gap.
    [directConnection setInterruptionHandler:^{
        NSError *xpcError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- cached instance connection is interrupted", nil);
        if (continueBlock) continueBlock(nil, nil, xpcError);
    }];

    [directConnection setInvalidationHandler:^{
        NSError *xpcError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- cached instance connection is invalidated", nil);
        if (continueBlock) continueBlock(nil, nil, xpcError);
    }];

    id<MSIDXpcBrokerInstanceProtocol> directService = [directConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull callbackError) {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Entra broker] CLIENT -- failed to connect to cached instance endpoint, error: %@", callbackError);
        if (continueBlock) continueBlock(nil, nil, callbackError);
        [directConnection invalidate];
    }];
    if (!directService)
    {
        NSError *xpcUnexpectedError = MSIDXpcCreateTransportError(@"[Entra broker] CLIENT -- cached direct proxy is unavailable", nil);
        if (continueBlock) continueBlock(nil, directConnection, xpcUnexpectedError);
        [directConnection invalidate];
        return;
    }

    [directConnection resume];

    if (continueBlock) continueBlock(directService, directConnection, nil);
}

@end
