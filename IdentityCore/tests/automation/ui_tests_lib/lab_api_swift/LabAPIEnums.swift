// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

// MARK: - Account Type

/// The type of test account in the Lab.
public enum AccountType: String, Codable, Sendable {
    case cloud = "cloud"
    case federated = "federated"
    case onPrem = "onprem"
    case guest = "guest"
    case msa = "msa"
    case b2c = "b2c"
}

// MARK: - MFA Type

/// The MFA configuration of a test account.
public enum MFAType: String, Codable, Sendable {
    case none = "none"
    case manual = "mfaonall"
    case auto = "automfaonall"
    case onSPO = "mfaonspo"
}

// MARK: - Protection Policy

/// The protection policy applied to a test account.
public enum ProtectionPolicy: String, Codable, Sendable {
    case none = "none"
    case ca = "ca"
    case mam = "mam"
    case mdm = "mdm"
    case mamCA = "mamca"
    case mamCASPO = "mamspo"
    case trueMAMCA = "truemamca"
    case mdmCA = "mdmca"
    case tokenBinding = "tokenbinding"
}

// MARK: - B2C Provider

/// The B2C identity provider type.
public enum B2CProvider: String, Codable, Sendable {
    case none = "none"
    case amazon = "amazon"
    case facebook = "facebook"
    case google = "google"
    case local = "local"
    case microsoft = "microsoft"
}

// MARK: - Federation Provider

/// The federation identity provider type.
public enum FederationProvider: String, Codable, Sendable {
    case none = "none"
    case adfsV2 = "adfsv2"
    case adfsV3 = "adfsv3"
    case adfsV4 = "adfsv4"
    case adfs2019 = "adfsv2019"
    case ping = "ping"
    case shibboleth = "shibboleth"
    case ciam = "ciam"
    case ciamCUD = "ciamcud"
}

// MARK: - Azure Environment

/// The Azure cloud environment for a test account.
public enum AzureEnvironment: String, Codable, Sendable {
    case worldwideCloud = "azurecloud"
    case chinaCloud = "azurechinacloud"
    case germanCloud = "azuregermanycloud"
    case usGovCloud = "azureusgovernment"
    case ppe = "azureppe"
    case b2cCloud = "azureb2ccloud"
}

// MARK: - User Role

/// The user role in the tenant.
public enum UserRole: String, Codable, Sendable {
    case cloudDeviceAdministrator = "CloudDeviceAdministrator"
}

// MARK: - App Type

/// The type of test application.
public enum AppType: String, Codable, Sendable {
    case cloud = "cloud"
    case onPrem = "onprem"
}

// MARK: - Sign-In Audience

/// The sign-in audience for a test application.
public enum SignInAudience: String, Codable, Sendable {
    case myOrg = "azureadmyorg"
    case multipleOrgs = "azureadmultipleorgs"
    case personalAndOrg = "azureadandpersonalmicrosoftaccount"
}

// MARK: - App Whitelist Type

/// Whitelist type for app configuration queries.
public enum AppWhitelistType: String, Codable, Sendable {
    case mamCA = "app_whitelist_mamca"
    case foci = "app_whitelist_foci"
}

// MARK: - Temporary Account Type

/// The type of temporary test account to create.
public enum TemporaryAccountType: String, Codable, Sendable {
    case basic = "Basic"
    case globalMFA = "GLOBALMFA"
    case mfaOnSPO = "MFAONSPO"
    case mfaOnEXO = "MFAONEXO"
    case mamCA = "MAMCA"
    case mdmCA = "MDMCA"
}

// MARK: - HTTP Method

/// HTTP methods used by Lab API requests.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

// MARK: - API Target

/// Determines which backend endpoint a request should be routed to.
public enum APITarget: Sendable {
    /// Standard Lab API endpoint (read/query operations).
    case labAPI
    /// Function App endpoint (write/mutation operations).
    case functionApp
}

// MARK: - Reset Operation

/// The type of reset operation to perform.
public enum ResetOperation: String, Codable, Sendable {
    case password = "Password"
    case mfa = "MFA"
}
