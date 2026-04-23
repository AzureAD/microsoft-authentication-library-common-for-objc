// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// Protocol for caching Lab API responses.
public protocol LabResponseCaching: Sendable {
    /// Retrieves a cached response for the given cache key.
    func get<T: Decodable & Sendable>(forKey key: String) async -> T?

    /// Stores a response with the given cache key.
    func set<T: Encodable & Sendable>(_ value: T, forKey key: String) async

    /// Removes all cached responses.
    func clear() async
}

/// An in-memory response cache backed by a Swift actor for thread safety.
public actor LabInMemoryResponseCache: LabResponseCaching {

    private var cache: [String: Data] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {}

    public func get<T: Decodable & Sendable>(forKey key: String) -> T? {
        guard let data = cache[key] else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    public func set<T: Encodable & Sendable>(_ value: T, forKey key: String) {
        cache[key] = try? encoder.encode(value)
    }

    public func clear() {
        cache.removeAll()
    }
}

// MARK: - Cache Key Helpers

extension LabAPIRequest {
    /// Generates a deterministic cache key from the request's path and query parameters.
    public var cacheKey: String {
        var components = [path]
        let sortedParams = queryParameters
            .map { "\($0.name)=\($0.value ?? "")" }
            .sorted()
        components.append(contentsOf: sortedParams)
        return components.joined(separator: "|")
    }
}
