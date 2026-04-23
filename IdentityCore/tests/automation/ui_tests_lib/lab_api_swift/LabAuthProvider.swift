// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// Protocol for providing OAuth access tokens.
public protocol LabAuthProvider: Sendable {
    /// Acquires an access token for the Lab API.
    func getAccessToken() async throws -> String
}

// MARK: - Errors

/// Errors that can occur during authentication.
public enum LabAuthError: LocalizedError, Sendable {
    case noCertificateData
    case invalidCertificate(String)
    case noClientSecret
    case tokenAcquisitionFailed(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .noCertificateData:
            return "No certificate data provided for certificate-based authentication."
        case .invalidCertificate(let detail):
            return "Invalid certificate: \(detail)"
        case .noClientSecret:
            return "No client secret provided for client credential authentication."
        case .tokenAcquisitionFailed(let detail):
            return "Token acquisition failed: \(detail)"
        case .invalidResponse:
            return "Invalid token response from the authority."
        }
    }
}

// MARK: - Token Response

/// The response from an OAuth token endpoint.
struct LabTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}
