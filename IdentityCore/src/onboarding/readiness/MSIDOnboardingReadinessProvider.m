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
#if TARGET_OS_IPHONE && !TARGET_OS_VISION
#import "MSIDBrokerInteractiveController.h"
#import "MSIDBrokerInvocationOptions.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#endif
#if MSID_ENABLE_SSO_EXTENSION && !TARGET_OS_VISION
#import "MSIDSSOExtensionInteractiveTokenRequestController.h"
#endif

@interface MSIDOnboardingReadinessProvider ()

@property (nonatomic, copy, nullable) MSIDOnboardingBrokerOptionsFactory brokerOptionsFactory;
@property (nonatomic, copy, nullable) MSIDOnboardingBrokerAvailabilityCheck brokerAvailabilityCheck;
@property (nonatomic, copy, nullable) MSIDOnboardingSSOExtensionAvailabilityCheck ssoExtensionAvailabilityCheck;

@end

@implementation MSIDOnboardingReadinessProvider

- (instancetype)init
{
    return [self initWithBrokerOptionsFactory:nil
                     brokerAvailabilityCheck:nil
              ssoExtensionAvailabilityCheck:nil];
}

- (instancetype)initWithBrokerOptionsFactory:(MSIDOnboardingBrokerOptionsFactory)brokerOptionsFactory
                     brokerAvailabilityCheck:(MSIDOnboardingBrokerAvailabilityCheck)brokerAvailabilityCheck
              ssoExtensionAvailabilityCheck:(MSIDOnboardingSSOExtensionAvailabilityCheck)ssoExtensionAvailabilityCheck
{
    self = [super init];
    if (self)
    {
        _brokerOptionsFactory = [brokerOptionsFactory copy];
        _brokerAvailabilityCheck = [brokerAvailabilityCheck copy];
        _ssoExtensionAvailabilityCheck = [ssoExtensionAvailabilityCheck copy];
    }
    return self;
}

- (nullable MSIDOnboardingReadiness *)readiness
{
    BOOL brokerAvailability = NO;
#if TARGET_OS_IPHONE && !TARGET_OS_VISION
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    parameters.brokerInvocationOptions = self.brokerOptionsFactory
        ? self.brokerOptionsFactory()
        : [[MSIDBrokerInvocationOptions alloc]
           initWithRequiredBrokerType:MSIDRequiredBrokerTypeWithNonceSupport
                         protocolType:MSIDBrokerProtocolTypeCustomScheme
                    aadRequestVersion:MSIDBrokerAADRequestVersionV2];
    if (!parameters.brokerInvocationOptions)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to initialize onboarding Broker request options.");
        return nil;
    }
    brokerAvailability = self.brokerAvailabilityCheck
        ? self.brokerAvailabilityCheck(parameters)
        : [MSIDBrokerInteractiveController canPerformRequest:parameters];
#else
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Onboarding Broker routing is not supported on this platform.");
#endif

    BOOL ssoExtensionAvailability = NO;
#if MSID_ENABLE_SSO_EXTENSION && !TARGET_OS_VISION
    ssoExtensionAvailability = self.ssoExtensionAvailabilityCheck
        ? self.ssoExtensionAvailabilityCheck()
        : [MSIDSSOExtensionInteractiveTokenRequestController canPerformRequest];
#else
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Onboarding SSO extension routing is not supported in this build.");
#endif

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Onboarding readiness: Broker can perform %@; SSO extension can perform %@.",
                      @(brokerAvailability), @(ssoExtensionAvailability));
    return [[MSIDOnboardingReadiness alloc] initWithBrokerAvailability:brokerAvailability
                                             ssoExtensionAvailability:ssoExtensionAvailability];
}

@end
