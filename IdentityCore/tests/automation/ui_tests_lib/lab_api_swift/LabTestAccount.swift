// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// A test account fetched from the Lab API, representing an Entra ID user
/// configured for automation testing.
public struct LabTestAccount: Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    public let objectId: String
    public let userType: String
    public let upn: String
    public let keyvaultName: String
    public let homeObjectId: String
    public let targetTenantId: String
    public let homeTenantId: String
    public let associatedAppID: String?

    /// The user's password. Typically fetched separately from KeyVault.
    public var password: String?

    /// Override for the target tenant ID (e.g., for cross-tenant tests).
    public var overriddenTargetTenantId: String?

    /// Override for the keyvault secret name.
    public var overriddenKeyvaultName: String?

    // MARK: - Internal stored properties (derived during decoding)

    /// The domain username (falls back to UPN if not present).
    public let domainUsername: String

    /// The display name of the tenant domain (extracted from the guest UPN).
    public let tenantName: String

    /// The display name of the home tenant domain.
    public let homeTenantName: String

    /// Whether this account is a home (non-guest) account.
    public let isHomeAccount: Bool

    // MARK: - Computed Properties

    /// The effective target tenant ID (respects override).
    public var effectiveTargetTenantId: String {
        if let override = overriddenTargetTenantId, !override.isEmpty {
            return override
        }
        return targetTenantId
    }

    /// The effective keyvault secret name (respects override).
    public var effectiveKeyvaultName: String {
        if let override = overriddenKeyvaultName, !override.isEmpty {
            return override
        }
        return keyvaultName
    }

    /// The home account identifier in the format `{homeObjectId}.{homeTenantId}`.
    public var homeAccountId: String {
        "\(homeObjectId).\(homeTenantId)"
    }

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case objectId
        case userType
        case upn
        case homeUPN
        case domainAccount
        case credentialVaultKeyName
        case homeObjectId
        case tenantID
        case tenantId
        case homeTenantID
        case homeDomain
        case appId
        case password
    }

    // MARK: - Custom Decoding

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        objectId = try container.decodeIfPresent(String.self, forKey: .objectId) ?? ""
        userType = try container.decodeIfPresent(String.self, forKey: .userType) ?? ""
        associatedAppID = try container.decodeIfPresent(String.self, forKey: .appId)
        password = try container.decodeIfPresent(String.self, forKey: .password)

        // UPN resolution: prefer homeUPN, fall back to guest upn
        let homeUPN = try container.decodeIfPresent(String.self, forKey: .homeUPN)
        let guestUPN = try container.decodeIfPresent(String.self, forKey: .upn) ?? ""

        if let home = homeUPN, home != "None", !home.isEmpty {
            upn = home
        } else {
            upn = guestUPN
        }

        // Determine if home account
        isHomeAccount = !guestUPN.contains("#EXT#") && userType != "Guest"

        // Domain username
        let rawDomainAccount = try container.decodeIfPresent(String.self, forKey: .domainAccount)
        if let domain = rawDomainAccount, domain != "None", !domain.trimmingCharacters(in: .whitespaces).isEmpty {
            domainUsername = domain
        } else {
            domainUsername = upn
        }

        // KeyVault name
        keyvaultName = try container.decodeIfPresent(String.self, forKey: .credentialVaultKeyName) ?? ""

        // Home object ID
        if isHomeAccount {
            homeObjectId = objectId
        } else {
            homeObjectId = try container.decodeIfPresent(String.self, forKey: .homeObjectId) ?? objectId
        }

        // Target tenant ID (API returns either "tenantID" or "tenantId")
        let tid = try container.decodeIfPresent(String.self, forKey: .tenantID)
            ?? container.decodeIfPresent(String.self, forKey: .tenantId)
            ?? ""
        targetTenantId = tid

        // Tenant name derived from UPN domain
        tenantName = Self.domainSuffix(from: guestUPN) ?? ""

        // Home tenant ID
        let rawHomeTenantId = try container.decodeIfPresent(String.self, forKey: .homeTenantID)
        if let htid = rawHomeTenantId, !htid.trimmingCharacters(in: .whitespaces).isEmpty {
            homeTenantId = htid
        } else {
            homeTenantId = targetTenantId
        }

        // Home tenant name
        let rawHomeDomain = try container.decodeIfPresent(String.self, forKey: .homeDomain)
        homeTenantName = rawHomeDomain ?? tenantName
    }

    // MARK: - Custom Encoding

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(objectId, forKey: .objectId)
        try container.encode(userType, forKey: .userType)
        try container.encode(upn, forKey: .upn)
        try container.encode(keyvaultName, forKey: .credentialVaultKeyName)
        try container.encode(homeObjectId, forKey: .homeObjectId)
        try container.encode(targetTenantId, forKey: .tenantID)
        try container.encode(homeTenantId, forKey: .homeTenantID)
        try container.encodeIfPresent(associatedAppID, forKey: .appId)
        try container.encodeIfPresent(password, forKey: .password)
        try container.encode(domainUsername, forKey: .domainAccount)
        try container.encode(homeTenantName, forKey: .homeDomain)
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectId)
        hasher.combine(upn)
        hasher.combine(targetTenantId)
    }

    public static func == (lhs: LabTestAccount, rhs: LabTestAccount) -> Bool {
        lhs.objectId == rhs.objectId
            && lhs.upn == rhs.upn
            && lhs.targetTenantId == rhs.targetTenantId
    }

    // MARK: - Manual Init (for testing / programmatic use)

    public init(
        objectId: String,
        userType: String,
        upn: String,
        keyvaultName: String,
        homeObjectId: String,
        targetTenantId: String,
        homeTenantId: String,
        tenantName: String,
        homeTenantName: String,
        domainUsername: String,
        isHomeAccount: Bool,
        associatedAppID: String? = nil,
        password: String? = nil
    ) {
        self.objectId = objectId
        self.userType = userType
        self.upn = upn
        self.keyvaultName = keyvaultName
        self.homeObjectId = homeObjectId
        self.targetTenantId = targetTenantId
        self.homeTenantId = homeTenantId
        self.tenantName = tenantName
        self.homeTenantName = homeTenantName
        self.domainUsername = domainUsername
        self.isHomeAccount = isHomeAccount
        self.associatedAppID = associatedAppID
        self.password = password
    }

    // MARK: - Helpers

    private static func domainSuffix(from upn: String) -> String? {
        guard let atIndex = upn.lastIndex(of: "@") else { return nil }
        let domain = String(upn[upn.index(after: atIndex)...])
        return domain.isEmpty ? nil : domain
    }
}
