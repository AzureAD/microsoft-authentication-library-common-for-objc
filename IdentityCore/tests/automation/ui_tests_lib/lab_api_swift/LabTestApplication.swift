// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// A test application registered in the Lab, used for automation testing.
public struct LabTestApplication: Codable, Hashable, Sendable {

    // MARK: - Properties

    public let appId: String
    public let objectId: String
    public let labName: String
    public let multiTenantApp: Bool
    public let redirectUris: [String]
    public let defaultScopes: [String]
    public let defaultAuthorities: [String]
    public let b2cAuthorities: [String]

    /// An optional prefix override for redirect URIs.
    public var redirectUriPrefix: String?

    // MARK: - Computed Properties

    /// The first redirect URI, or nil if none configured.
    public var defaultRedirectUri: String? {
        if let prefix = redirectUriPrefix {
            return redirectUris.first(where: { $0.hasPrefix(prefix) })
        }
        return redirectUris.first
    }

    /// The first default authority.
    public var defaultAuthority: String? {
        defaultAuthorities.first
    }

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case appId
        case objectId
        case labName
        case multiTenantApp
        case redirectUris
        case defaultScopes
        case defaultAuthorities
        case b2cAuthorities
    }

    // MARK: - Custom Decoding

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        appId = try container.decodeIfPresent(String.self, forKey: .appId) ?? ""
        objectId = try container.decodeIfPresent(String.self, forKey: .objectId) ?? ""
        labName = try container.decodeIfPresent(String.self, forKey: .labName) ?? ""
        multiTenantApp = try container.decodeIfPresent(Bool.self, forKey: .multiTenantApp) ?? false

        // Handle both string and array formats for redirect URIs
        if let uris = try? container.decode([String].self, forKey: .redirectUris) {
            redirectUris = uris
        } else if let uri = try? container.decode(String.self, forKey: .redirectUris) {
            redirectUris = uri.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            redirectUris = []
        }

        defaultScopes = try container.decodeIfPresent([String].self, forKey: .defaultScopes) ?? []
        defaultAuthorities = try container.decodeIfPresent([String].self, forKey: .defaultAuthorities) ?? []
        b2cAuthorities = try container.decodeIfPresent([String].self, forKey: .b2cAuthorities) ?? []
    }

    // MARK: - Manual Init

    public init(
        appId: String,
        objectId: String,
        labName: String,
        multiTenantApp: Bool = false,
        redirectUris: [String] = [],
        defaultScopes: [String] = [],
        defaultAuthorities: [String] = [],
        b2cAuthorities: [String] = []
    ) {
        self.appId = appId
        self.objectId = objectId
        self.labName = labName
        self.multiTenantApp = multiTenantApp
        self.redirectUris = redirectUris
        self.defaultScopes = defaultScopes
        self.defaultAuthorities = defaultAuthorities
        self.b2cAuthorities = b2cAuthorities
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(appId)
        hasher.combine(objectId)
    }

    public static func == (lhs: LabTestApplication, rhs: LabTestApplication) -> Bool {
        lhs.appId == rhs.appId && lhs.objectId == rhs.objectId
    }
}
