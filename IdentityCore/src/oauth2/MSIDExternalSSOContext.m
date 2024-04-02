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


#import "MSIDExternalSSOContext.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDKeychainUtil.h"

@implementation MSIDExternalSSOContext

#if TARGET_OS_IPHONE && !TARGET_OS_MACCATALYST
static NSString *const MSID_BROKER_SHARED_APP_GROUP = @"group.com.microsoft.azureauthenticator.sso";
#elif TARGET_OS_OSX
static NSString *const MSID_BROKER_SHARED_APP_GROUP = @"com.microsoft.identity.ssoextensiongroup";
#endif

static NSString *const MSID_PLATFORM_SSO_DEVICE_REGISTRATION_COMPLETED_KEY = @"psso_device_registration_completed";

- (MSIDWPJKeyPairWithCert *)wpjKeyPairWithCertWithContext:(id<MSIDRequestContext>)context
{
#if TARGET_OS_OSX
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 130000
    if (@available(macOS 13.0, *))
    {
        if (!self.loginManager)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Loginmanager not present, returning early");
            return nil;
        }
        
        if (!self.loginManager.isDeviceRegistered || (self.loginManager.isDeviceRegistered && ![MSIDExternalSSOContext isPlatformSSORegisteredFlagSetInUserDefaults]))
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"No valid PSSO registration found on device, returning early");
            return nil;
        }
        
        SecIdentityRef identityRef = nil;
        [self getPlatformSSOIdentity:&identityRef]; // +1
        
        if (!identityRef)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to copy identity for the ASAuthorizationProviderExtensionKeyTypeUserDeviceSigning keytype");
            return nil;
        }
        
        SecCertificateRef certificateRef = NULL;
        OSStatus certCopyStatus = SecIdentityCopyCertificate(identityRef, &certificateRef); // +1
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Certificate copy status from identity %d", (int)certCopyStatus);
        
        if (!certificateRef)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to copy certificate from identityref with status %d", (int)certCopyStatus);
            CFReleaseNull(identityRef);
            return nil;
        }
        
        SecKeyRef privateKeyRef = NULL;
        OSStatus keyCopyStatus = SecIdentityCopyPrivateKey(identityRef, &privateKeyRef); // +1
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Key copy status from identity %d", (int)keyCopyStatus);
        
        if (!privateKeyRef)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to copy private key from identityref with status %d", (int)keyCopyStatus);
            CFReleaseNull(identityRef);
            CFReleaseNull(certificateRef);
            return nil;
        }
        
        MSIDWPJKeyPairWithCert *keypair = [[MSIDWPJKeyPairWithCert alloc] initWithPrivateKey:privateKeyRef
                                                                                 certificate:certificateRef
                                                                           certificateIssuer:nil];
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Successfully created MSIDWPJKeyPairWithCert from external SSO context for identity %@", identityRef ? @"not-null" : @"null");
        
        CFReleaseNull(identityRef);
        CFReleaseNull(certificateRef);
        CFReleaseNull(privateKeyRef);
        return keypair;
    }
#endif
#endif

    return nil;
}

- (nullable NSURL *)tokenEndpointURL
{
#if TARGET_OS_OSX
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 130000
    if (@available(macOS 13.0, *))
    {
        if (!self.loginManager)
        {
            return nil;
        }
        
        return self.loginManager.loginConfiguration.tokenEndpointURL;
    }
#endif
#endif
    
    return nil;
}

- (void)getPlatformSSOIdentity:(SecIdentityRef _Nullable *_Nullable)identityRef API_AVAILABLE(macos(13.0))
{
    
#if TARGET_OS_OSX && __MAC_OS_X_VERSION_MAX_ALLOWED >= 130000
    if (!identityRef)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"identityRef passed is nil, cannot set identity from LoginManager");
        return;
    }
#if TARGET_OS_OSX && __MAC_OS_X_VERSION_MAX_ALLOWED >= 140000
    if (@available(macOS 14.0, *))
    {
        *identityRef =  [self.loginManager copyIdentityForKeyType:ASAuthorizationProviderExtensionKeyTypeCurrentDeviceSigning];
        return;
    }
#endif
    *identityRef =  [self.loginManager copyIdentityForKeyType:ASAuthorizationProviderExtensionKeyTypeUserDeviceSigning];
#endif

}

+ (NSUserDefaults *)getSSOUserDefaults
{
    static NSUserDefaults *ssoUserDefault = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        /**
         NSUserDefaults on MacOS need to add TeamID explicitly in the app shared group string.
         This link for extension/main app sharing:
         https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html#//apple_ref/doc/uid/TP40014214-CH21-SW1
         This link for app to app sharing:
         https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html#//apple_ref/doc/uid/TP40011195-CH4-SW19
         */
        
        NSString *sharedAppGroup;
        
        #if TARGET_OS_IPHONE
            sharedAppGroup = MSID_BROKER_SHARED_APP_GROUP;
        #elif TARGET_OS_OSX
            sharedAppGroup = [NSString stringWithFormat:@"%@.%@",[[MSIDKeychainUtil sharedInstance] teamId], MSID_BROKER_SHARED_APP_GROUP];
        #endif
        
        ssoUserDefault = [[NSUserDefaults alloc] initWithSuiteName:sharedAppGroup];
    });
    
    return ssoUserDefault;
}

+ (BOOL)isPlatformSSORegisteredFlagSetInUserDefaults
{
    return [[MSIDExternalSSOContext getSSOUserDefaults] boolForKey:MSID_PLATFORM_SSO_DEVICE_REGISTRATION_COMPLETED_KEY];
}

@end
