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

import Foundation

/// Bridges the new Swift Lab API types into the existing ObjC test infra.
///
/// Provides:
/// - Cross-account password caching via LabPasswordManager
/// - Lab API operations (create temp user, reset password, etc.)
///
/// Account/app fetching is handled by KeyVault JSON (MSIDKeyVaultAccountProvider).
/// This adapter handles passwords and mutation operations only.
@objc public class LabAPIAdapter: NSObject {

    private let client: LabAPIClient?
    private let passwordManager: LabPasswordManager

    /// Initialize with password manager only (KeyVault-only mode, no Lab API operations).
    @objc public init(passwordManager: LabPasswordManager) {
        self.client = nil
        self.passwordManager = passwordManager
        super.init()
    }

    /// Initialize with both password manager and Lab API client (for operations like temp user creation).
    public init(configuration: LabAPIConfiguration,
                authProvider: LabAuthProvider,
                passwordManager: LabPasswordManager) {
        self.client = LabAPIClient(
            configuration: configuration,
            authProvider: authProvider
        )
        self.passwordManager = passwordManager
        super.init()
    }

    // MARK: - Password Loading

    /// Loads password for an account using the cross-account cache.
    /// Same keyvault secret URL is only fetched once, regardless of how many accounts share it.
    @objc public func loadPassword(
        keyvaultName: String,
        existingPassword: String?,
        completion: @escaping (String?, NSError?) -> Void
    ) {
        Task {
            do {
                var account = LabTestAccount(
                    objectId: "", userType: "", upn: "",
                    keyvaultName: keyvaultName, homeObjectId: "",
                    targetTenantId: "", homeTenantId: "",
                    tenantName: "", homeTenantName: "",
                    domainUsername: "", isHomeAccount: true,
                    password: existingPassword
                )
                let password = try await passwordManager.loadPassword(for: &account)
                DispatchQueue.main.async {
                    completion(password, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error as NSError)
                }
            }
        }
    }

    // MARK: - Lab API Operations

    /// Resets a test account password.
    @objc public func resetPassword(
        upn: String,
        completion: @escaping (Bool, NSError?) -> Void
    ) {
        guard let client = client else {
            completion(false, NSError(domain: "LabAPIAdapter", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "No Lab API client configured for operations"]))
            return
        }
        let request = LabResetRequest(operation: .password, upn: upn)
        Task {
            do {
                let result = try await client.execute(request)
                DispatchQueue.main.async {
                    completion(result.isSuccess, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error as NSError)
                }
            }
        }
    }

    /// Creates a temporary test account.
    @objc public func createTempAccount(
        accountType: String,
        completion: @escaping ([[String: Any]]?, NSError?) -> Void
    ) {
        guard let client = client else {
            completion(nil, NSError(domain: "LabAPIAdapter", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "No Lab API client configured for operations"]))
            return
        }
        let type = TemporaryAccountType(rawValue: accountType) ?? .basic
        let request = LabTempAccountRequest(accountType: type)
        Task {
            do {
                let accounts = try await client.execute(request)
                let dicts = accounts.map { account -> [String: Any] in
                    var dict: [String: Any] = [
                        "objectId": account.objectId,
                        "userType": account.userType,
                        "upn": account.upn,
                        "credentialVaultKeyName": account.keyvaultName,
                        "tenantID": account.targetTenantId,
                    ]
                    if let password = account.password {
                        dict["password"] = password
                    }
                    return dict
                }
                DispatchQueue.main.async {
                    completion(dicts, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error as NSError)
                }
            }
        }
    }

    /// Invalidates a cached password (use after password reset).
    @objc public func invalidatePassword(keyvaultName: String) {
        Task {
            await passwordManager.invalidate(keyvaultName: keyvaultName)
        }
    }
}
