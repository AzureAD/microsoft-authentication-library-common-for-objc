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

#import "MSIDDeviceInfo.h"
#import "MSIDConstants.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "NSJSONSerialization+MSIDExtensions.h"
#import "MSIDJsonSerializer.h"
#if TARGET_OS_OSX
#import "MSIDXpcProviderCache.h"
#endif
#if !AD_BROKER
#import "MSIDBrokerFlightProvider.h"
#endif
static NSArray *deviceModeEnumString;

@implementation MSIDDeviceInfo

- (instancetype)initWithDeviceMode:(MSIDDeviceMode)deviceMode
                  ssoExtensionMode:(MSIDSSOExtensionMode)ssoExtensionMode
                 isWorkPlaceJoined:(BOOL)isWorkPlaceJoined
                     brokerVersion:(NSString *)brokerVersion
                   ssoProviderType:(MSIDSsoProviderType)ssoProviderType
{
    self = [super init];
    
    if (self)
    {
        _deviceMode = deviceMode;
        _ssoExtensionMode = ssoExtensionMode;
        _wpjStatus = isWorkPlaceJoined ? MSIDWorkPlaceJoinStatusJoined : MSIDWorkPlaceJoinStatusNotJoined;
        _brokerVersion = brokerVersion;
        _ssoProviderType = ssoProviderType;
    }
    
    return self;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(__unused NSError *__autoreleasing*)error
{
    self = [super init];
    
    if (self)
    {
        _deviceMode = [self deviceModeEnumFromString:[json msidStringObjectForKey:MSID_BROKER_DEVICE_MODE_KEY]];
        _ssoExtensionMode = [self ssoExtensionModeEnumFromString:[json msidStringObjectForKey:MSID_BROKER_SSO_EXTENSION_MODE_KEY]];
        _wpjStatus = [self wpjStatusEnumFromString:[json msidStringObjectForKey:MSID_BROKER_WPJ_STATUS_KEY]];
        _brokerVersion = [json msidStringObjectForKey:MSID_BROKER_BROKER_VERSION_KEY];
        _preferredAuthConfig = [self preferredAuthConfigurationEnumFromString:[json msidStringObjectForKey:MSID_BROKER_PREFERRED_AUTH_CONFIGURATION_KEY]];
        _clientFlights = [json msidStringObjectForKey:MSID_BROKER_CLIENT_FLIGHTS_KEY];
        
#if TARGET_OS_OSX
        _platformSSOStatus = [self platformSSOStatusEnumFromString:[json msidStringObjectForKey:MSID_PLATFORM_SSO_STATUS_KEY]];
        _ssoProviderType = [self ssoProviderTypeEnumFromString:[json msidStringObjectForKey:MSID_SSO_PROVIDER_TYPE_KEY]];
        [self updateSsoProviderType];
#endif
        
        NSString *jsonDataString = [json msidStringObjectForKey:MSID_ADDITIONAL_EXTENSION_DATA_KEY];
        if (jsonDataString)
        {
            _additionalExtensionData = [NSJSONSerialization msidNormalizedDictionaryFromJsonData:[jsonDataString dataUsingEncoding:NSUTF8StringEncoding]
                                                                                           error:nil];
        }
        
        NSString *extraDeviceInfoStr = [json msidStringObjectForKey:MSID_EXTRA_DEVICE_INFO_KEY];
        if (extraDeviceInfoStr)
        {
            _extraDeviceInfo = [extraDeviceInfoStr msidJson];
        }
        
#if !AD_BROKER
        // Save client flights if available
        if (![NSString msidIsStringNilOrBlank:_clientFlights])
        {
            MSIDBrokerFlightProvider *flightProvider = [[MSIDBrokerFlightProvider alloc] initWithBase64EncodedFlightsPayload:_clientFlights];
            
            [MSIDFlightManager sharedInstance].flightProvider = flightProvider;
        }
#endif
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    
    json[MSID_BROKER_DEVICE_MODE_KEY] = [self deviceModeStringFromEnum:self.deviceMode];
    json[MSID_BROKER_SSO_EXTENSION_MODE_KEY] = [self ssoExtensionModeStringFromEnum:self.ssoExtensionMode];
    json[MSID_BROKER_WPJ_STATUS_KEY] = [self wpjStatusStringFromEnum:self.wpjStatus];
    json[MSID_BROKER_BROKER_VERSION_KEY] = self.brokerVersion;
    json[MSID_BROKER_PREFERRED_AUTH_CONFIGURATION_KEY] = [self preferredAuthConfigurationStringFromEnum:self.preferredAuthConfig];
    json[MSID_BROKER_CLIENT_FLIGHTS_KEY] = self.clientFlights;
#if TARGET_OS_OSX
    json[MSID_PLATFORM_SSO_STATUS_KEY] = [self platformSSOStatusStringFromEnum:self.platformSSOStatus];
    json[MSID_SSO_PROVIDER_TYPE_KEY] = [self ssoProviderTypeStringFromEnum:self.ssoProviderType];
#endif
    json[MSID_ADDITIONAL_EXTENSION_DATA_KEY] = [self.additionalExtensionData msidJSONSerializeWithContext:nil];
    if (self.extraDeviceInfo)
    {
        json[MSID_EXTRA_DEVICE_INFO_KEY] = [self.extraDeviceInfo msidJSONSerializeWithContext:nil];
    }
    
    return json;
}

- (NSString *)deviceModeStringFromEnum:(MSIDDeviceMode)deviceMode
{
    switch (deviceMode) {
        case MSIDDeviceModePersonal:
            return @"personal";
        case MSIDDeviceModeShared:
            return @"shared";
        default:
            return nil;
    }
}

- (MSIDDeviceMode)deviceModeEnumFromString:(NSString *)deviceModeString
{
    if ([deviceModeString isEqualToString:@"personal"])    return MSIDDeviceModePersonal;
    if ([deviceModeString isEqualToString:@"shared"])  return MSIDDeviceModeShared;

    return MSIDDeviceModePersonal;
}

- (NSString *)ssoExtensionModeStringFromEnum:(MSIDSSOExtensionMode)ssoExtensionMode
{
    switch (ssoExtensionMode) {
        case MSIDSSOExtensionModeFull:
            return @"full";
        case MSIDSSOExtensionModeSilentOnly:
            return @"silent_only";
        default:
            return nil;
    }
}

- (MSIDSSOExtensionMode)ssoExtensionModeEnumFromString:(NSString *)ssoExtensionModeString
{
    if ([ssoExtensionModeString isEqualToString:@"full"])    return MSIDSSOExtensionModeFull;
    if ([ssoExtensionModeString isEqualToString:@"silent_only"])  return MSIDSSOExtensionModeSilentOnly;

    return MSIDSSOExtensionModeFull;
}

- (NSString *)wpjStatusStringFromEnum:(MSIDWorkPlaceJoinStatus)wpjStatus
{
    switch (wpjStatus) {
        case MSIDWorkPlaceJoinStatusNotJoined:
            return @"notJoined";
        case MSIDWorkPlaceJoinStatusJoined:
            return @"joined";
        default:
            return nil;
    }
}

- (MSIDWorkPlaceJoinStatus)wpjStatusEnumFromString:(NSString *)wpjStatusString
{
    if ([wpjStatusString isEqualToString:@"notJoined"]) return MSIDWorkPlaceJoinStatusNotJoined;
    if ([wpjStatusString isEqualToString:@"joined"])    return MSIDWorkPlaceJoinStatusJoined;

    return MSIDWorkPlaceJoinStatusNotJoined;
}

- (NSString *)platformSSOStatusStringFromEnum:(MSIDPlatformSSOStatus)platformSSOStatus
{
    switch (platformSSOStatus) {
        case MSIDPlatformSSONotEnabled:
            return @"platformSSONotEnabled";
        case MSIDPlatformSSOEnabledNotRegistered:
            return @"platformSSOEnabledNotRegistered";
        case MSIDPlatformSSOEnabledAndRegistered:
            return @"platformSSOEnabledAndRegistered";
        case MSIDPlatformSSORegistrationNeedsRepair:
            return @"platformSSORegistrationNeedsRepair";
        
        default:
            return nil;
    }
}

- (MSIDPlatformSSOStatus)platformSSOStatusEnumFromString:(NSString *)platformSSOStatusString
{
    if ([platformSSOStatusString isEqualToString:@"platformSSONotEnabled"])    return MSIDPlatformSSONotEnabled;
    if ([platformSSOStatusString isEqualToString:@"platformSSOEnabledNotRegistered"])  return MSIDPlatformSSOEnabledNotRegistered;
    if ([platformSSOStatusString isEqualToString:@"platformSSOEnabledAndRegistered"])  return MSIDPlatformSSOEnabledAndRegistered;
    if ([platformSSOStatusString isEqualToString:@"platformSSORegistrationNeedsRepair"])  return MSIDPlatformSSORegistrationNeedsRepair;
    
    return MSIDPlatformSSONotEnabled;
}

- (NSString *)preferredAuthConfigurationStringFromEnum:(MSIDPreferredAuthMethod)preferredAuthConfiguration
{
    switch (preferredAuthConfiguration) {
        case MSIDPreferredAuthMethodNotConfigured:
            return @"preferredAuthNotConfigured";
        case MSIDPreferredAuthMethodQRPIN:
            return @"preferredAuthQRPIN";
        
        default:
            return nil;
    }
}

- (MSIDPreferredAuthMethod)preferredAuthConfigurationEnumFromString:(NSString *)preferredAuthConfigurationString
{
    if ([preferredAuthConfigurationString isEqualToString:@"preferredAuthNotConfigured"])    return MSIDPreferredAuthMethodNotConfigured;
    if ([preferredAuthConfigurationString isEqualToString:@"preferredAuthQRPIN"])            return MSIDPreferredAuthMethodQRPIN;
    
    return MSIDPreferredAuthMethodNotConfigured;
}

#if TARGET_OS_OSX

- (void)updateSsoProviderType
{
    // Update the provider type from SsoExtension only if it is recognized.
    //
    // 1. An "unknown" type might occur when:
    //    - The Broker version lacks an updated return value for `ssoProviderType`.
    //      In such cases, since the broker likely doesn't have the XPC service,
    //      `MSIDXpcProviderCache` will determine which XPC service to use.
    //
    // 2. An "unknown" type might also occur from:
    //    - The XPC service response itself.
    //      Here, we already know which XPC service is appropriate before this call,
    //      so there's no need to update the provider type.
    
    if (self.ssoProviderType != MSIDUnknownSsoProvider)
    {
        [MSIDXpcProviderCache sharedInstance].cachedXpcProviderType = self.ssoProviderType;
    }
}

#endif

- (NSString *)ssoProviderTypeStringFromEnum:(MSIDSsoProviderType)deviceMode
{
    switch (deviceMode)
    {
        case MSIDCompanyPortalSsoProvider:
            return @"companyPortal";
        case MSIDMacBrokerSsoProvider:
            return @"macBroker";
        default:
            return @"unknown";
    }
}

- (MSIDSsoProviderType)ssoProviderTypeEnumFromString:(NSString *)deviceModeString
{
    if ([deviceModeString isEqualToString:@"companyPortal"])
    {
        return MSIDCompanyPortalSsoProvider;
    }
    
    if ([deviceModeString isEqualToString:@"macBroker"])
    {
        return MSIDMacBrokerSsoProvider;
    }

    return MSIDUnknownSsoProvider;
}

@end
