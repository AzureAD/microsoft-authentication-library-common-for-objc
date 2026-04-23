// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// Request to fetch app configurations from the Lab API.
///
/// Queries the `/App` endpoint (or `/app/{appId}` for a specific app)
/// to retrieve test application configurations.
public struct LabAppConfigRequest: LabAPIRequest {
    public typealias ResponseType = [LabTestApplication]

    public var appType: AppType?
    public var environment: AzureEnvironment?
    public var signInAudience: SignInAudience?
    public var whitelistType: AppWhitelistType?
    public var appId: String?

    public var path: String {
        if let appId = appId, !appId.isEmpty {
            return "app/\(appId)"
        }
        return "App"
    }

    public var shouldCache: Bool { true }
    public var apiTarget: APITarget { .labAPI }

    public var queryParameters: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let type = appType {
            items.append(URLQueryItem(name: "apptype", value: type.rawValue))
        }
        if let env = environment {
            items.append(URLQueryItem(name: "azureenvironment", value: env.rawValue))
        }
        if let audience = signInAudience {
            items.append(URLQueryItem(name: "signinaudience", value: audience.rawValue))
        }
        if let whitelist = whitelistType {
            items.append(URLQueryItem(name: "app_whitelist_type", value: whitelist.rawValue))
        }
        return items
    }

    // MARK: - Init

    public init(
        appType: AppType? = nil,
        environment: AzureEnvironment? = nil,
        signInAudience: SignInAudience? = nil,
        whitelistType: AppWhitelistType? = nil,
        appId: String? = nil
    ) {
        self.appType = appType
        self.environment = environment
        self.signInAudience = signInAudience
        self.whitelistType = whitelistType
        self.appId = appId
    }
}
