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
@class MSIDTestAutomationAccount;

NS_ASSUME_NONNULL_BEGIN

/// Provides test accounts loaded from a JSON stored in Azure Key Vault.
/// Supports automatic caching and multiple authentication methods via credential provider.
/// 
/// Account types should match the MSIDTestAccountType values from MSIDTestAutomationAccountConfigurationRequest
/// (e.g., "cloud", "msa", "federated", "guest", "b2c", "onprem").
@interface MSIDKeyVaultAccountProvider : NSObject

/// Whether accounts have been cached
@property (nonatomic, readonly) BOOL hasCachedAccounts;

/// Initialize with Key Vault URL and credential provider
/// @param keyVaultURL The full URL to the Key Vault secret containing the accounts JSON
/// @param credentialProvider The credential provider for authentication
- (instancetype)initWithKeyVaultURL:(NSString *)keyVaultURL
                 credentialProvider:(MSIDKeyVaultCredentialProvider *)credentialProvider;

/// Clear the cached accounts
- (void)clearCache;

/// Fetch accounts from Key Vault
/// @param completionHandler Called with error if fetch fails, nil on success
- (void)fetchAccountsWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;

/// Get an account for the specified type
/// @param accountType The account type (use MSIDTestAccountType values like "cloud", "msa", "federated", etc.)
/// @param error Error pointer for error details
/// @return MSIDTestAutomationAccount or nil if not found
- (MSIDTestAutomationAccount *)accountForType:(NSString *)accountType
                                        error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
