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

#import "MSIDAuthenticationAvailabilityStatus.h"
#import "MSIDBrokerConstants.h"
#import "MSIDBrokerInvocationOptions.h"
#if MSID_ENABLE_SSO_EXTENSION && !TARGET_OS_VISION
#import "MSIDSSOExtensionInteractiveTokenRequestController.h"
#endif

static NSString * const MSIDBrokerAppAvailableKey = @"brokerAppAvailable";
static NSString * const MSIDSSOExtensionAvailableKey = @"ssoExtensionAvailable";

@interface MSIDAuthenticationAvailabilityStatus ()

@property (nonatomic, readwrite) BOOL brokerAppAvailable;
@property (nonatomic, readwrite) BOOL ssoExtensionAvailable;

- (instancetype)initWithBrokerAppAvailabilityProbe:(BOOL (^)(void))brokerAppAvailabilityProbe
                     ssoExtensionAvailabilityProbe:(BOOL (^)(void))ssoExtensionAvailabilityProbe;

@end

@implementation MSIDAuthenticationAvailabilityStatus

+ (instancetype)currentStatus
{
    return [[self alloc] initWithBrokerAppAvailabilityProbe:^BOOL
    {
#if TARGET_OS_IPHONE
        MSIDBrokerInvocationOptions *options = [[MSIDBrokerInvocationOptions alloc]
            initWithRequiredBrokerType:MSIDRequiredBrokerTypeWithNonceSupport
                          protocolType:MSIDBrokerProtocolTypeCustomScheme
                     aadRequestVersion:MSIDBrokerAADRequestVersionV2];
        return options.isRequiredBrokerPresent;
#else
        return NO;
#endif
    }
                              ssoExtensionAvailabilityProbe:^BOOL
    {
#if MSID_ENABLE_SSO_EXTENSION && !TARGET_OS_VISION
        return [MSIDSSOExtensionInteractiveTokenRequestController canPerformRequest];
#else
        return NO;
#endif
    }];
}

- (instancetype)initWithBrokerAppAvailabilityProbe:(BOOL (^)(void))brokerAppAvailabilityProbe
                     ssoExtensionAvailabilityProbe:(BOOL (^)(void))ssoExtensionAvailabilityProbe
{
    self = [super init];
    if (self)
    {
        if (NSThread.isMainThread)
        {
            _brokerAppAvailable = brokerAppAvailabilityProbe();
        }
        else
        {
            dispatch_sync(dispatch_get_main_queue(), ^
            {
                self.brokerAppAvailable = brokerAppAvailabilityProbe();
            });
        }

        _ssoExtensionAvailable = ssoExtensionAvailabilityProbe();
    }

    return self;
}

- (NSDictionary<NSString *, NSNumber *> *)statusDictionary
{
    return @{
        MSIDBrokerAppAvailableKey : @(self.brokerAppAvailable),
        MSIDSSOExtensionAvailableKey : @(self.ssoExtensionAvailable)
    };
}

@end
