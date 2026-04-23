// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// Errors that can occur when calling the Lab API.
public enum LabAPIError: LocalizedError, Sendable {
    case invalidURL
    case networkError(URLError)
    case httpError(statusCode: Int, body: String?)
    case decodingError(Error)
    case authenticationFailed(Error)
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Failed to construct a valid API URL."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code, let body):
            var msg = "HTTP error \(code)"
            if let body = body { msg += ": \(body)" }
            return msg
        case .decodingError(let error):
            return "Failed to decode API response: \(error.localizedDescription)"
        case .authenticationFailed(let error):
            return "Authentication failed: \(error.localizedDescription)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        }
    }
}

/// The main entry point for interacting with the Lab API.
///
/// Replaces `MSIDAutomationOperationAPIRequestHandler` with a single
/// generic `execute()` method, protocol-based routing, and async/await.
public final class LabAPIClient: Sendable {

    private let configuration: LabAPIConfiguration
    private let authProvider: LabAuthProvider
    private let responseCache: LabResponseCaching?
    private let router: LabAPIRouter
    private let session: URLSession

    /// Creates a new Lab API client.
    public init(
        configuration: LabAPIConfiguration,
        authProvider: LabAuthProvider,
        responseCache: LabResponseCaching? = LabInMemoryResponseCache(),
        session: URLSession? = nil
    ) {
        self.configuration = configuration
        self.authProvider = authProvider
        self.responseCache = responseCache
        self.router = LabAPIRouter(configuration: configuration)

        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = configuration.timeoutInterval
            self.session = URLSession(configuration: config)
        }
    }

    /// Executes a Lab API request and returns the decoded response.
    ///
    /// Flow: cache check → URL build → auth token → HTTP request → decode → cache store
    public func execute<R: LabAPIRequest>(_ request: R) async throws -> R.ResponseType {
        // 1. Check cache
        if request.shouldCache, let cache = responseCache {
            if let cached: R.ResponseType = await cache.get(forKey: request.cacheKey) {
                return cached
            }
        }

        // 2. Build URL
        guard let url = router.buildURL(for: request) else {
            throw LabAPIError.invalidURL
        }

        // 3. Acquire access token
        let accessToken: String
        do {
            accessToken = try await authProvider.getAccessToken()
        } catch {
            throw LabAPIError.authenticationFailed(error)
        }

        // 4. Execute HTTP request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.httpMethod.rawValue
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            throw LabAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LabAPIError.invalidURL
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw LabAPIError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        // 5. Decode response
        let result: R.ResponseType
        do {
            result = try Self.decodeResponse(data: data)
        } catch {
            throw LabAPIError.decodingError(error)
        }

        // 6. Cache result
        if request.shouldCache, let cache = responseCache {
            await cache.set(result, forKey: request.cacheKey)
        }

        return result
    }

    /// Decodes the API response, handling both single-object and array JSON.
    private static func decodeResponse<T: Decodable>(data: Data) throws -> T {
        let decoder = JSONDecoder()

        // Try direct decoding first
        if let result = try? decoder.decode(T.self, from: data) {
            return result
        }

        // If ResponseType is an array, try wrapping a single object
        if T.self is any RangeReplaceableCollection.Type {
            let json = try JSONSerialization.jsonObject(with: data)
            if let dict = json as? [String: Any] {
                let wrappedData = try JSONSerialization.data(withJSONObject: [dict])
                return try decoder.decode(T.self, from: wrappedData)
            }
        }

        return try decoder.decode(T.self, from: data)
    }
}
