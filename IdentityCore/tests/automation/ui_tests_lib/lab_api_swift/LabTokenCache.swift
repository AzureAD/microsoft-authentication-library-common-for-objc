// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// An actor that caches access tokens with expiration awareness.
///
/// Thread-safe by design (Swift actor isolation). Replaces the
/// static `NSMutableDictionary` used in the ObjC `MSIDClientCredentialHelper`.
public actor LabTokenCache {

    // MARK: - Types

    private struct CachedToken {
        let accessToken: String
        let expiresAt: Date
    }

    // MARK: - State

    private var cache: [String: CachedToken] = [:]

    /// Buffer in seconds before actual expiry to consider a token expired.
    private let expirationBuffer: TimeInterval

    // MARK: - Init

    public init(expirationBuffer: TimeInterval = 300) {
        self.expirationBuffer = expirationBuffer
    }

    // MARK: - Public API

    /// Retrieves a cached token if it exists and hasn't expired.
    public func getToken(forKey key: String) -> String? {
        guard let cached = cache[key] else { return nil }
        if Date() >= cached.expiresAt.addingTimeInterval(-expirationBuffer) {
            cache.removeValue(forKey: key)
            return nil
        }
        return cached.accessToken
    }

    /// Stores a token with its expiration.
    public func setToken(_ accessToken: String, forKey key: String, expiresIn: TimeInterval) {
        let expiresAt = Date().addingTimeInterval(expiresIn)
        cache[key] = CachedToken(accessToken: accessToken, expiresAt: expiresAt)
    }

    /// Removes all cached tokens.
    public func clear() {
        cache.removeAll()
    }
}
