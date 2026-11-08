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
        case redirectUris = "redirectUri"
        case defaultScopes
        case defaultAuthorities = "authority"
        case b2cAuthorities
    }

    // MARK: - Custom Decoding

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        appId = try container.decodeIfPresent(String.self, forKey: .appId) ?? ""
        objectId = try container.decodeIfPresent(String.self, forKey: .objectId) ?? ""
        labName = try container.decodeIfPresent(String.self, forKey: .labName) ?? ""

        // The Lab API returns "Yes"/"No" strings for this field, not a native Bool.
        let multiTenantStr = try container.decodeIfPresent(String.self, forKey: .multiTenantApp)
        multiTenantApp = multiTenantStr?.caseInsensitiveCompare("yes") == .orderedSame

        // Handle both string and array formats for redirect URIs
        if let uris = try? container.decode([String].self, forKey: .redirectUris) {
            redirectUris = uris
        } else if let uri = try? container.decode(String.self, forKey: .redirectUris) {
            redirectUris = uri.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            redirectUris = []
        }

        // The Lab API returns comma-separated strings for scopes and authorities.
        let scopesStr = try container.decodeIfPresent(String.self, forKey: .defaultScopes) ?? ""
        defaultScopes = scopesStr.isEmpty ? [] : scopesStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        let authoritiesStr = try container.decodeIfPresent(String.self, forKey: .defaultAuthorities) ?? ""
        defaultAuthorities = authoritiesStr.isEmpty ? [] : authoritiesStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

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
