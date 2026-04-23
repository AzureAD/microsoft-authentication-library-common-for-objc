// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// Constructs URLs for Lab API requests, routing to the appropriate
/// backend (Lab API vs Function App) based on the request's `apiTarget`.
public struct LabAPIRouter: Sendable {

    private let labAPIBaseURL: URL
    private let functionAppBaseURL: URL?

    public init(labAPIBaseURL: URL, functionAppBaseURL: URL?) {
        self.labAPIBaseURL = labAPIBaseURL
        self.functionAppBaseURL = functionAppBaseURL
    }

    public init(configuration: LabAPIConfiguration) {
        self.labAPIBaseURL = configuration.labAPIBaseURL
        self.functionAppBaseURL = configuration.functionAppBaseURL
    }

    /// Builds the full URL for a Lab API request.
    public func buildURL<R: LabAPIRequest>(for request: R) -> URL? {
        let baseURL: URL
        switch request.apiTarget {
        case .labAPI:
            baseURL = labAPIBaseURL
        case .functionApp:
            baseURL = functionAppBaseURL ?? labAPIBaseURL
        }

        let fullPath = baseURL.appendingPathComponent(request.path)
        var components = URLComponents(url: fullPath, resolvingAgainstBaseURL: false)

        let queryItems = request.queryParameters
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        return components?.url
    }
}
