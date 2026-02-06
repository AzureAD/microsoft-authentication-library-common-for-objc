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

#import <Foundation/Foundation.h>

@class KeyvaultAuthentication;

/// Authentication methods supported by the credential provider
typedef NS_ENUM(NSInteger, MSIDKeyVaultAuthMethod) {
    MSIDKeyVaultAuthMethodPipelineCertificate = 0,  // Certificate from pipeline (via environment variable)
    MSIDKeyVaultAuthMethodConfigCertificate,        // Certificate from conf.json (fallback)
    MSIDKeyVaultAuthMethodUnknown
};

/// Environment variable names for pipeline certificate
extern NSString * const MSIDKeyVaultEnvVarsCertificateData;
extern NSString * const MSIDKeyVaultEnvVarsCertificatePassword;

/// Returns the display name for the auth method
NSString *MSIDKeyVaultAuthMethodName(MSIDKeyVaultAuthMethod method);

/// Credential provider that supports multiple authentication methods for Azure Key Vault.
/// Uses a credential chain approach: tries Pipeline Cert → Config Cert
@interface MSIDKeyVaultCredentialProvider : NSObject

/// The last successful authentication method used
@property (nonatomic, readonly) MSIDKeyVaultAuthMethod lastSuccessfulMethod;

/// Check if pipeline certificate is available (from environment variable)
@property (nonatomic, readonly) BOOL isPipelineCertificateAvailable;

/// Check if any certificate is available
@property (nonatomic, readonly) BOOL hasAnyCertificate;

/// Initialize with certificate credentials from conf.json as fallback.
/// The provider will first check for pipeline certificate in environment variables,
/// then fall back to the provided certificate.
/// - Parameters:
///   - certContents: Base64-encoded PKCS12 certificate from conf.json (optional)
///   - certPassword: Certificate password from conf.json (optional)
- (instancetype)initWithCertificateContents:(NSString *)certContents
                        certificatePassword:(NSString *)certPassword;

/// Get the KeyvaultAuthentication instance for fetching secrets.
/// Returns the pipeline cert auth if available, otherwise the config cert auth.
/// The caller can then use Secret.get(url) to fetch secrets.
- (KeyvaultAuthentication *)getKeyvaultAuthentication;

@end
