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

@class MSIDKeyVaultCredentialProvider;
@class MSIDTestAutomationApplication;

NS_ASSUME_NONNULL_BEGIN

/// Provides test app configurations loaded from a JSON stored in Azure Key Vault.
/// Mirrors MSIDKeyVaultAccountProvider but for app configurations instead of accounts.
///
/// Compound keys should match the output of +[MSIDTestAutomationAppConfigurationRequest keyForAppConfigurationRequest:]
/// (e.g., "cloud_azureadmultipleorgs", "cloud_azureadmultipleorgs_app_firstparty_msal", "cloud_azureadmultipleorgs_azurechinacloud").
@interface MSIDKeyVaultAppConfigProvider : NSObject

/// Whether app configurations have been cached
@property (nonatomic, readonly) BOOL hasCachedAppConfigs;

/// Initialize with Key Vault URL and credential provider
/// @param keyVaultURL The full URL to the Key Vault secret containing the app configurations JSON
/// @param credentialProvider The credential provider for authentication
- (instancetype)initWithKeyVaultURL:(NSString *)keyVaultURL
                 credentialProvider:(MSIDKeyVaultCredentialProvider *)credentialProvider;

/// Clear the cached app configurations
- (void)clearCache;

/// Fetch app configurations from Key Vault
/// @param completionHandler Called with error if fetch fails, nil on success
- (void)fetchAppConfigsWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;

/// Get an app configuration for the specified compound key
/// @param appConfigKey The compound key (use +[MSIDTestAutomationAppConfigurationRequest keyForAppConfigurationRequest:])
/// @param error Error pointer for error details
/// @return MSIDTestAutomationApplication or nil if not found
- (MSIDTestAutomationApplication *)appConfigForKey:(NSString *)appConfigKey
                                             error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
