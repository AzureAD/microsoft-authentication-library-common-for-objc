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

#import "MSIDOnboardingReadinessProvider.h"
#import "MSIDBrokerConstants.h"
#import "MSIDBrokerInvocationOptions.h"
#if TARGET_OS_IPHONE
#import "MSIDAppExtensionUtil.h"
#endif
#if MSID_ENABLE_SSO_EXTENSION && !TARGET_OS_VISION
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#endif

@interface MSIDOnboardingReadinessProvider ()

@property (nonatomic, copy) BOOL (^appExtensionProbe)(void);
@property (nonatomic, copy) BOOL (^querySchemesProbe)(void);
@property (nonatomic, copy) NSNumber * _Nullable (^brokerProbe)(void);
@property (nonatomic, copy) NSNumber * _Nullable (^ssoExtensionProbe)(void);

@end

@implementation MSIDOnboardingReadinessProvider

- (instancetype)init
{
#if TARGET_OS_IPHONE
    BOOL (^appExtensionProbe)(void) = ^BOOL
    {
        NSString *bundlePath = [NSBundle mainBundle].bundlePath;
        // The compliant-extension override permits some APIs, but cannot make broker presence observable.
        return [MSIDAppExtensionUtil isExecutingInAppExtension]
            || !bundlePath.length
            || [bundlePath hasSuffix:@".appex"];
    };
    BOOL (^querySchemesProbe)(void) = ^BOOL
    {
        // The redirect verifier skips this check in Broker builds, but readiness needs an observable result.
        NSArray *querySchemes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"LSApplicationQueriesSchemes"];
        return [querySchemes isKindOfClass:[NSArray class]]
            && [querySchemes containsObject:MSID_BROKER_MSAL_SCHEME]
            && [querySchemes containsObject:MSID_BROKER_NONCE_SCHEME];
    };
    // A nil probe result is unobservable; @NO is a trustworthy negative.
    NSNumber * _Nullable (^brokerProbe)(void) = ^NSNumber *
    {
        MSIDBrokerInvocationOptions *options = [[MSIDBrokerInvocationOptions alloc]
            initWithRequiredBrokerType:MSIDRequiredBrokerTypeWithNonceSupport
                          protocolType:MSIDBrokerProtocolTypeCustomScheme
                     aadRequestVersion:MSIDBrokerAADRequestVersionV2];
        return options ? @(options.isRequiredBrokerPresent) : nil;
    };
#else
    BOOL (^appExtensionProbe)(void) = ^BOOL
    {
        return NO;
    };
    BOOL (^querySchemesProbe)(void) = ^BOOL
    {
        return NO;
    };
    NSNumber * _Nullable (^brokerProbe)(void) = ^NSNumber *
    {
        return nil;
    };
#endif

    NSNumber * _Nullable (^ssoExtensionProbe)(void) = ^NSNumber *
    {
#if MSID_ENABLE_SSO_EXTENSION && !TARGET_OS_VISION
        if (@available(iOS 13.0, macOS 10.15, *))
        {
            ASAuthorizationSingleSignOnProvider *provider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
            if (!provider)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"SSO extension provider unavailable for onboarding readiness.");
                return nil;
            }
            return @(provider.canPerformAuthorization);
        }
#endif
        return nil;
    };

    return [self initWithAppExtensionProbe:appExtensionProbe
                        querySchemesProbe:querySchemesProbe
                              brokerProbe:brokerProbe
                        ssoExtensionProbe:ssoExtensionProbe];
}

- (instancetype)initWithAppExtensionProbe:(BOOL (^)(void))appExtensionProbe
                        querySchemesProbe:(BOOL (^)(void))querySchemesProbe
                              brokerProbe:(NSNumber * _Nullable (^)(void))brokerProbe
                        ssoExtensionProbe:(NSNumber * _Nullable (^)(void))ssoExtensionProbe
{
    self = [super init];
    if (self)
    {
        _appExtensionProbe = [appExtensionProbe copy];
        _querySchemesProbe = [querySchemesProbe copy];
        _brokerProbe = [brokerProbe copy];
        _ssoExtensionProbe = [ssoExtensionProbe copy];
    }
    return self;
}

- (MSIDOnboardingReadiness *)readiness
{
    MSIDOnboardingReadinessState brokerState = MSIDOnboardingReadinessStateUnknown;
    MSIDOnboardingReadinessUnknownReason brokerReason = MSIDOnboardingReadinessUnknownReasonNone;
#if TARGET_OS_IPHONE
    if (self.appExtensionProbe())
    {
        brokerReason = MSIDOnboardingReadinessUnknownReasonNotProbeableInCurrentHost;
    }
    else if (!self.querySchemesProbe())
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Cannot probe compatible broker without required query schemes.");
        brokerReason = MSIDOnboardingReadinessUnknownReasonMissingQuerySchemeConfiguration;
    }
    else
    {
        __block NSNumber *present = nil;
        if ([NSThread isMainThread])
        {
            present = self.brokerProbe();
        }
        else
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                present = self.brokerProbe();
            });
        }
        if (present)
        {
            brokerState = present.boolValue ? MSIDOnboardingReadinessStateAvailable : MSIDOnboardingReadinessStateUnavailable;
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to probe onboarding broker availability.");
            brokerReason = MSIDOnboardingReadinessUnknownReasonProbeFailed;
        }
    }
#else
    brokerReason = MSIDOnboardingReadinessUnknownReasonPlatformCapabilityUnavailable;
#endif

    NSNumber *canAuthorize = self.ssoExtensionProbe();
    MSIDOnboardingReadinessState ssoState = MSIDOnboardingReadinessStateUnknown;
    MSIDOnboardingReadinessUnknownReason ssoReason = MSIDOnboardingReadinessUnknownReasonNone;
    if (canAuthorize)
    {
        ssoState = canAuthorize.boolValue ? MSIDOnboardingReadinessStateAvailable : MSIDOnboardingReadinessStateUnavailable;
    }
    else
    {
        ssoReason = MSIDOnboardingReadinessUnknownReasonPlatformCapabilityUnavailable;
    }
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil,
                      @"Onboarding readiness: broker state %ld, reason %ld; SSO extension state %ld, reason %ld.",
                      (long)brokerState, (long)brokerReason, (long)ssoState, (long)ssoReason);
    return [[MSIDOnboardingReadiness alloc] initWithBrokerAvailability:brokerState
                                                   brokerUnknownReason:brokerReason
                                              ssoExtensionAvailability:ssoState
                                             ssoExtensionUnknownReason:ssoReason];
}

@end
