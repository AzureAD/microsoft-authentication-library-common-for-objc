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

#import "MSIDKeyVaultCredentialProvider.h"

// KeyvaultAuthentication is a Swift class - import via the auto-generated Swift header
#if __has_include("MSIDAutomation-Swift.h")
#import "MSIDAutomation-Swift.h"
#elif __has_include("IdentityCore-Swift.h")
#import "IdentityCore-Swift.h"
#else
// Forward declare for compilation - actual import handled by build system
@class KeyvaultAuthentication;
#endif

NSString * const MSIDKeyVaultEnvVarsCertificateData = @"KEYVAULT_CERTIFICATE_DATA";
NSString * const MSIDKeyVaultEnvVarsCertificatePassword = @"KEYVAULT_CERTIFICATE_PASSWORD";

NSString *MSIDKeyVaultAuthMethodName(MSIDKeyVaultAuthMethod method) {
    switch (method) {
        case MSIDKeyVaultAuthMethodPipelineCertificate:
            return @"Pipeline Certificate";
        case MSIDKeyVaultAuthMethodConfigCertificate:
            return @"Config Certificate";
        case MSIDKeyVaultAuthMethodUnknown:
        default:
            return @"Unknown";
    }
}

@interface MSIDKeyVaultCredentialProvider ()

@property (nonatomic, strong) KeyvaultAuthentication *pipelineCertAuth;
@property (nonatomic, strong) KeyvaultAuthentication *configCertAuth;
@property (nonatomic, readwrite) MSIDKeyVaultAuthMethod lastSuccessfulMethod;

@end

@implementation MSIDKeyVaultCredentialProvider

- (instancetype)initWithCertificateContents:(NSString *)certContents
                        certificatePassword:(NSString *)certPassword
{
    self = [super init];
    if (self) {
        _lastSuccessfulMethod = MSIDKeyVaultAuthMethodUnknown;
        
        // Initialize config certificate auth if provided
        if (certContents.length > 0 && certPassword.length > 0) {
            _configCertAuth = [[KeyvaultAuthentication alloc] initWithCertContents:certContents
                                                                      certPassword:certPassword];
            NSLog(@"[MSIDKeyVaultCredentialProvider] Config certificate auth initialized");
        }
        
        // Check for pipeline certificate from environment variables
        NSDictionary *env = [[NSProcessInfo processInfo] environment];
        NSString *pipelineCertData = env[MSIDKeyVaultEnvVarsCertificateData];
        NSString *pipelineCertPassword = env[MSIDKeyVaultEnvVarsCertificatePassword];
        
        if (pipelineCertData.length > 0 && pipelineCertPassword.length > 0) {
            _pipelineCertAuth = [[KeyvaultAuthentication alloc] initWithCertContents:pipelineCertData
                                                                        certPassword:pipelineCertPassword];
            NSLog(@"[MSIDKeyVaultCredentialProvider] Pipeline certificate auth initialized from environment variables");
        }
    }
    return self;
}

- (BOOL)isPipelineCertificateAvailable
{
    return self.pipelineCertAuth != nil;
}

- (BOOL)hasAnyCertificate
{
    return self.pipelineCertAuth != nil || self.configCertAuth != nil;
}

- (KeyvaultAuthentication *)getKeyvaultAuthentication
{
    if (self.pipelineCertAuth) {
        self.lastSuccessfulMethod = MSIDKeyVaultAuthMethodPipelineCertificate;
        NSLog(@"[MSIDKeyVaultCredentialProvider] Using Pipeline Certificate authentication");
        return self.pipelineCertAuth;
    }
    
    if (self.configCertAuth) {
        self.lastSuccessfulMethod = MSIDKeyVaultAuthMethodConfigCertificate;
        NSLog(@"[MSIDKeyVaultCredentialProvider] Using Config Certificate authentication");
        return self.configCertAuth;
    }
    
    self.lastSuccessfulMethod = MSIDKeyVaultAuthMethodUnknown;
    NSLog(@"[MSIDKeyVaultCredentialProvider] No certificate authentication available");
    return nil;
}

@end
