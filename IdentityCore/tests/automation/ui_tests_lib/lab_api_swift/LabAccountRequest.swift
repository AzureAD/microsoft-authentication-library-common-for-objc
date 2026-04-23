// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// Request to fetch test accounts from the Lab API.
///
/// Queries the `/User` endpoint with filters for account type,
/// MFA configuration, protection policies, etc.
public struct LabAccountRequest: LabAPIRequest {
    public typealias ResponseType = [LabTestAccount]

    public var accountType: AccountType
    public var mfaType: MFAType?
    public var protectionPolicy: ProtectionPolicy?
    public var b2cProvider: B2CProvider?
    public var federationProvider: FederationProvider?
    public var environment: AzureEnvironment?
    public var userRole: UserRole?
    public var additionalParameters: [String: String]?

    public var path: String { "User" }
    public var shouldCache: Bool { true }
    public var apiTarget: APITarget { .labAPI }

    public var queryParameters: [URLQueryItem] {
        var items: [URLQueryItem] = []
        items.append(URLQueryItem(name: "usertype", value: accountType.rawValue))

        if let mfa = mfaType {
            items.append(URLQueryItem(name: "mfa", value: mfa.rawValue))
        }
        if let policy = protectionPolicy {
            items.append(URLQueryItem(name: "protectionpolicy", value: policy.rawValue))
        }
        if let b2c = b2cProvider {
            items.append(URLQueryItem(name: "b2cprovider", value: b2c.rawValue))
        }
        if let federation = federationProvider, federation != .none {
            items.append(URLQueryItem(name: "federationprovider", value: federation.rawValue))
        }
        if let env = environment {
            items.append(URLQueryItem(name: "azureenvironment", value: env.rawValue))
        }
        if let role = userRole {
            items.append(URLQueryItem(name: "userrole", value: role.rawValue))
        }
        if let additional = additionalParameters {
            for (key, value) in additional.sorted(by: { $0.key < $1.key }) {
                items.append(URLQueryItem(name: key, value: value))
            }
        }
        return items
    }

    // MARK: - Init

    public init(
        accountType: AccountType = .cloud,
        mfaType: MFAType? = MFAType.none,
        protectionPolicy: ProtectionPolicy? = ProtectionPolicy.none,
        b2cProvider: B2CProvider? = nil,
        federationProvider: FederationProvider? = FederationProvider.none,
        environment: AzureEnvironment? = .worldwideCloud,
        userRole: UserRole? = nil,
        additionalParameters: [String: String]? = nil
    ) {
        self.accountType = accountType
        self.mfaType = mfaType
        self.protectionPolicy = protectionPolicy
        self.b2cProvider = b2cProvider
        self.federationProvider = federationProvider
        self.environment = environment
        self.userRole = userRole
        self.additionalParameters = additionalParameters
    }
}
