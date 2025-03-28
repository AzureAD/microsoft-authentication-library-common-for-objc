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

#import "MSIDJsonSerializable.h"

typedef NS_ENUM(NSInteger, MSIDDeviceMode)
{
    MSIDDeviceModePersonal = 0,
    MSIDDeviceModeShared
};

typedef NS_ENUM(NSInteger, MSIDSSOExtensionMode)
{
    MSIDSSOExtensionModeFull = 0,
    MSIDSSOExtensionModeSilentOnly
};

typedef NS_ENUM(NSInteger, MSIDWorkPlaceJoinStatus)
{
    MSIDWorkPlaceJoinStatusNotJoined = 0,
    MSIDWorkPlaceJoinStatusJoined
};

typedef NS_ENUM(NSInteger, MSIDPlatformSSOStatus)
{
    MSIDPlatformSSONotEnabled = 0, //Platform SSO Not enabled in SSO Config
    MSIDPlatformSSOEnabledNotRegistered = 1, //Platform SSO Enabled in sso config , but not Registered
    MSIDPlatformSSOEnabledAndRegistered = 2, //Platform SSO Enabled in sso config and registered
    MSIDPlatformSSORegistrationNeedsRepair = 3, //Platform registration needs to be repaired
};

typedef NS_ENUM(NSInteger, MSIDPreferredAuthMethod)
{
    MSIDPreferredAuthMethodNotConfigured = 0,
    MSIDPreferredAuthMethodQRPIN
};

typedef NS_ENUM(NSInteger, MSIDSsoProviderType)
{
    MSIDUnknownSsoProvider = 0,
    MSIDMacBrokerSsoProvider,
    MSIDCompanyPortalSsoProvider
};

NS_ASSUME_NONNULL_BEGIN

@interface MSIDDeviceInfo : NSObject <MSIDJsonSerializable>

@property (nonatomic) MSIDDeviceMode deviceMode;
@property (nonatomic) MSIDSSOExtensionMode ssoExtensionMode;
@property (nonatomic) MSIDWorkPlaceJoinStatus wpjStatus;
@property (nonatomic, nullable) NSString *brokerVersion;
@property (nonatomic) MSIDSsoProviderType ssoProviderType;
@property (nonatomic) NSDictionary *additionalExtensionData;
@property (nonatomic) MSIDPreferredAuthMethod preferredAuthConfig;
@property (nonatomic) NSString *clientFlights;

#if TARGET_OS_OSX
@property (nonatomic) MSIDPlatformSSOStatus platformSSOStatus;
#endif

// New property to return additional device Info
@property (nonatomic) NSDictionary *extraDeviceInfo;

- (instancetype)initWithDeviceMode:(MSIDDeviceMode)deviceMode
                  ssoExtensionMode:(MSIDSSOExtensionMode)ssoExtensionMode
                 isWorkPlaceJoined:(BOOL)isWorkPlaceJoined
                     brokerVersion:(NSString *)brokerVersion
                   ssoProviderType:(MSIDSsoProviderType)ssoProviderType;

@end

NS_ASSUME_NONNULL_END
