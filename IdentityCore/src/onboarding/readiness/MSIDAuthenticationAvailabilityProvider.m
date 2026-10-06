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

#import "MSIDAuthenticationAvailabilityProvider.h"
#if TARGET_OS_IPHONE && !TARGET_OS_VISION
#import "MSIDBrokerInteractiveController.h"
#import "MSIDBrokerInvocationOptions.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#endif
#if MSID_ENABLE_SSO_EXTENSION && !TARGET_OS_VISION
#import "MSIDSSOExtensionInteractiveTokenRequestController.h"
#endif

@class MSIDBrokerInvocationOptions;
@class MSIDInteractiveTokenRequestParameters;

typedef MSIDBrokerInvocationOptions * _Nullable (^MSIDAuthenticationBrokerOptionsFactory)(void);
typedef BOOL (^MSIDAuthenticationBrokerAvailabilityCheck)(MSIDInteractiveTokenRequestParameters *parameters);
typedef BOOL (^MSIDAuthenticationSSOExtensionAvailabilityCheck)(void);

@interface MSIDAuthenticationAvailabilityProvider ()

@property (nonatomic, copy, nullable) MSIDAuthenticationBrokerOptionsFactory brokerOptionsFactory;
@property (nonatomic, copy, nullable) MSIDAuthenticationBrokerAvailabilityCheck brokerAvailabilityCheck;
@property (nonatomic, copy, nullable) MSIDAuthenticationSSOExtensionAvailabilityCheck ssoExtensionAvailabilityCheck;

- (instancetype)initWithBrokerOptionsFactory:(nullable MSIDAuthenticationBrokerOptionsFactory)brokerOptionsFactory
                     brokerAvailabilityCheck:(nullable MSIDAuthenticationBrokerAvailabilityCheck)brokerAvailabilityCheck
              ssoExtensionAvailabilityCheck:(nullable MSIDAuthenticationSSOExtensionAvailabilityCheck)ssoExtensionAvailabilityCheck;

@end

@implementation MSIDAuthenticationAvailabilityProvider

- (instancetype)init
{
    return [self initWithBrokerOptionsFactory:nil
                     brokerAvailabilityCheck:nil
              ssoExtensionAvailabilityCheck:nil];
}

- (instancetype)initWithBrokerOptionsFactory:(MSIDAuthenticationBrokerOptionsFactory)brokerOptionsFactory
                     brokerAvailabilityCheck:(MSIDAuthenticationBrokerAvailabilityCheck)brokerAvailabilityCheck
              ssoExtensionAvailabilityCheck:(MSIDAuthenticationSSOExtensionAvailabilityCheck)ssoExtensionAvailabilityCheck
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

- (nullable MSIDAuthenticationAvailabilityStatus *)availabilityStatus
{
    BOOL brokerAppAvailable = NO;
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
    brokerAppAvailable = self.brokerAvailabilityCheck
        ? self.brokerAvailabilityCheck(parameters)
        : [MSIDBrokerInteractiveController canPerformRequest:parameters];
#else
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Onboarding Broker routing is not supported on this platform.");
#endif

    BOOL ssoExtensionAvailable = NO;
#if MSID_ENABLE_SSO_EXTENSION && !TARGET_OS_VISION
    ssoExtensionAvailable = self.ssoExtensionAvailabilityCheck
        ? self.ssoExtensionAvailabilityCheck()
        : [MSIDSSOExtensionInteractiveTokenRequestController canPerformRequest];
#else
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Onboarding SSO extension routing is not supported in this build.");
#endif

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Onboarding readiness: Broker can perform %@; SSO extension can perform %@.",
                      @(brokerAppAvailable), @(ssoExtensionAvailable));
    return [[MSIDAuthenticationAvailabilityStatus alloc] initWithBrokerAppAvailable:brokerAppAvailable
                                                           ssoExtensionAvailable:ssoExtensionAvailable];
}

@end
