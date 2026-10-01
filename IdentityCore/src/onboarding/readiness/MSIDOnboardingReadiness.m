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

#import "MSIDOnboardingReadiness.h"
#import "MSIDWebCPOnboardingReadinessContract.h"

@interface MSIDOnboardingReadiness ()

@property (nonatomic, readwrite) MSIDOnboardingReadinessState brokerAvailability;
@property (nonatomic, readwrite) MSIDOnboardingReadinessState ssoExtensionAvailability;
@property (nonatomic, readwrite) MSIDOnboardingReadinessUnknownReason brokerUnknownReason;
@property (nonatomic, readwrite) MSIDOnboardingReadinessUnknownReason ssoExtensionUnknownReason;

@end

@implementation MSIDOnboardingReadiness

- (instancetype)initWithBrokerAvailability:(MSIDOnboardingReadinessState)brokerAvailability
                       brokerUnknownReason:(MSIDOnboardingReadinessUnknownReason)brokerUnknownReason
                  ssoExtensionAvailability:(MSIDOnboardingReadinessState)ssoExtensionAvailability
                 ssoExtensionUnknownReason:(MSIDOnboardingReadinessUnknownReason)ssoExtensionUnknownReason
{
    self = [super init];
    if (self)
    {
        _brokerAvailability = brokerAvailability;
        _brokerUnknownReason = brokerUnknownReason;
        _ssoExtensionAvailability = ssoExtensionAvailability;
        _ssoExtensionUnknownReason = ssoExtensionUnknownReason;
    }
    return self;
}

- (nullable NSDictionary<NSString *, id> *)jsonDictionary
{
    NSString *brokerState = [self stringForState:self.brokerAvailability];
    NSString *ssoState = [self stringForState:self.ssoExtensionAvailability];
    if (!brokerState || !ssoState)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to serialize onboarding readiness state.");
        return nil;
    }
    NSMutableDictionary<NSString *, id> *result = [@{
        @"contractVersion": @(MSIDWebCPOnboardingReadinessContractVersion),
        @"capabilities": @[@"brokerAvailability", @"ssoExtensionAvailability"],
        @"brokerAvailability": brokerState,
        @"ssoExtensionAvailability": ssoState
    } mutableCopy];
    NSMutableDictionary<NSString *, NSString *> *reasons = [NSMutableDictionary new];

    if (self.brokerAvailability == MSIDOnboardingReadinessStateUnknown)
    {
        NSString *reason = [self stringForReason:self.brokerUnknownReason];
        if (reason)
        {
            reasons[@"brokerAvailability"] = reason;
        }
    }
    if (self.ssoExtensionAvailability == MSIDOnboardingReadinessStateUnknown)
    {
        NSString *reason = [self stringForReason:self.ssoExtensionUnknownReason];
        if (reason)
        {
            reasons[@"ssoExtensionAvailability"] = reason;
        }
    }
    if ((self.brokerAvailability == MSIDOnboardingReadinessStateUnknown
         && !reasons[@"brokerAvailability"])
        || (self.ssoExtensionAvailability == MSIDOnboardingReadinessStateUnknown
            && !reasons[@"ssoExtensionAvailability"]))
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to serialize onboarding readiness unknown reason.");
        return nil;
    }
    if (reasons.count)
    {
        result[@"unknownReasons"] = [reasons copy];
    }
    return [result copy];
}

- (nullable NSString *)stringForState:(MSIDOnboardingReadinessState)state
{
    switch (state)
    {
        case MSIDOnboardingReadinessStateAvailable: return @"available";
        case MSIDOnboardingReadinessStateUnavailable: return @"unavailable";
        case MSIDOnboardingReadinessStateUnknown: return @"unknown";
    }
    return nil;
}

- (nullable NSString *)stringForReason:(MSIDOnboardingReadinessUnknownReason)reason
{
    switch (reason)
    {
        case MSIDOnboardingReadinessUnknownReasonNone: return nil;
        case MSIDOnboardingReadinessUnknownReasonNotProbeableInCurrentHost: return @"notProbeableInCurrentHost";
        case MSIDOnboardingReadinessUnknownReasonMissingQuerySchemeConfiguration: return @"missingQuerySchemeConfiguration";
        case MSIDOnboardingReadinessUnknownReasonPlatformCapabilityUnavailable: return @"platformCapabilityUnavailable";
        case MSIDOnboardingReadinessUnknownReasonProbeFailed: return @"probeFailed";
    }
    return nil;
}

@end
