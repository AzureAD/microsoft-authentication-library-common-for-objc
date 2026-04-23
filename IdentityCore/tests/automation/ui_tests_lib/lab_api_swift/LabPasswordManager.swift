// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// Manages password retrieval with caching, so the same KeyVault secret
/// is never fetched more than once per session.
///
/// Improvement over ObjC `MSIDAutomationPasswordRequestHandler` which only
/// cached on individual account objects. This caches by keyvault name,
/// so accounts sharing a secret (e.g., same tenant) only hit KeyVault once.
public actor LabPasswordManager {

    private let keyVaultClient: LabKeyVaultClient
    private let baseKeyVaultURL: String
    private var cache: [String: String] = [:]

    /// Creates a password manager.
    ///
    /// - Parameters:
    ///   - keyVaultClient: The KeyVault client to use for fetching secrets.
    ///   - baseKeyVaultURL: The base URL for keyvault secrets.
    ///     Example: `"https://msidlabs.vault.azure.net/secrets/"`
    public init(keyVaultClient: LabKeyVaultClient, baseKeyVaultURL: String) {
        self.keyVaultClient = keyVaultClient
        self.baseKeyVaultURL = baseKeyVaultURL.hasSuffix("/") ? baseKeyVaultURL : baseKeyVaultURL + "/"
    }

    /// Loads the password for a test account, using cache when available.
    ///
    /// Cache key is the effective keyvault name, so:
    /// - Two accounts with the same keyvault name → one fetch
    /// - After a password reset, call `invalidate(keyvaultName:)` to re-fetch
    public func loadPassword(for account: inout LabTestAccount) async throws -> String {
        let keyvaultName = account.effectiveKeyvaultName

        // Already on the account object
        if let existing = account.password, !existing.isEmpty {
            cache[keyvaultName] = existing
            return existing
        }

        // Check cross-account cache
        if let cached = cache[keyvaultName] {
            account.password = cached
            return cached
        }

        // Fetch from KeyVault
        let secretURL: URL
        if keyvaultName.hasPrefix("https://") {
            guard let url = URL(string: keyvaultName) else {
                throw LabPasswordError.invalidKeyvaultName(keyvaultName)
            }
            secretURL = url
        } else {
            guard let url = URL(string: "\(baseKeyVaultURL)\(keyvaultName)") else {
                throw LabPasswordError.invalidKeyvaultName(keyvaultName)
            }
            secretURL = url
        }

        let secret = try await keyVaultClient.getSecret(url: secretURL)

        cache[keyvaultName] = secret.value
        account.password = secret.value

        return secret.value
    }

    /// Loads passwords for multiple accounts, deduplicating KeyVault calls.
    public func loadPasswords(for accounts: inout [LabTestAccount]) async throws {
        for i in accounts.indices {
            _ = try await loadPassword(for: &accounts[i])
        }
    }

    /// Invalidates a cached password (use after password reset).
    public func invalidate(keyvaultName: String) {
        cache.removeValue(forKey: keyvaultName)
    }

    /// Clears the entire password cache.
    public func clearCache() {
        cache.removeAll()
    }

    /// Number of cached passwords (for debugging/testing).
    public var cacheCount: Int {
        cache.count
    }
}

/// Errors from password operations.
public enum LabPasswordError: LocalizedError, Sendable {
    case invalidKeyvaultName(String)

    public var errorDescription: String? {
        switch self {
        case .invalidKeyvaultName(let name):
            return "Invalid keyvault name or URL: \(name)"
        }
    }
}
