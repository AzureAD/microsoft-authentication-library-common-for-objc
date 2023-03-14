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
        
        SecIdentityRef identityRef = [self.loginManager copyIdentityForKeyType:ASAuthorizationProviderExtensionKeyTypeUserDeviceSigning]; // +1
        
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

@end
