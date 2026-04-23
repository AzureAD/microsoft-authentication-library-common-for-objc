// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

// MARK: - LabAPIRequest Protocol

/// A protocol defining a request to the Lab API.
///
/// Each request type declares:
/// - The response type it expects (must be `Codable`)
/// - The HTTP path, method, and query parameters
/// - Whether the response should be cached
/// - Which API endpoint to target (Lab API vs Function App)
///
/// Conforming types are `Hashable` so they can serve as cache keys.
public protocol LabAPIRequest: Hashable, Sendable {
    /// The type of the decoded response.
    associatedtype ResponseType: Decodable & Encodable & Sendable

    /// The path appended to the base URL (e.g., `"User"`, `"App"`, `"Reset"`).
    var path: String { get }

    /// The HTTP method for this request.
    var httpMethod: HTTPMethod { get }

    /// URL query parameters for this request.
    var queryParameters: [URLQueryItem] { get }

    /// Whether the response for this request should be cached.
    var shouldCache: Bool { get }

    /// Which backend endpoint this request targets.
    var apiTarget: APITarget { get }
}

// MARK: - Default Implementations

public extension LabAPIRequest {
    var httpMethod: HTTPMethod { .get }
    var shouldCache: Bool { false }
    var apiTarget: APITarget { .labAPI }
}
