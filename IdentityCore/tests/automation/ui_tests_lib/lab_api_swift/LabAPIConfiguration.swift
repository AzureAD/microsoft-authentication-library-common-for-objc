// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// Typed configuration for the Lab API client.
///
/// Replaces the untyped `NSDictionary` configuration used in the ObjC implementation.
/// Can be loaded from JSON or constructed programmatically.
public struct LabAPIConfiguration: Codable, Sendable {

    /// The base URL for the Lab API (read/query operations).
    public let labAPIBaseURL: URL

    /// The base URL for the Function App API (write/mutation operations).
    public let functionAppBaseURL: URL?

    /// The OAuth authority URL for acquiring tokens.
    public let authority: String

    /// The resource / scope for the Lab API token.
    public let resource: String

    /// The client ID used for authentication.
    public let clientId: String

    /// Base64-encoded certificate data (pfx/p12) for certificate-based auth.
    public let certificateData: String?

    /// The password for the certificate.
    public let certificatePassword: String?

    /// Client secret for client credentials auth (fallback when no certificate).
    public let clientSecret: String?

    /// Request timeout interval in seconds. Defaults to 60.
    public let timeoutInterval: TimeInterval

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case labAPIBaseURL = "operation_api_path"
        case functionAppBaseURL = "function_app_api_path"
        case authority = "operation_api_authority"
        case resource = "operation_api_resource"
        case clientId = "operation_api_client_id"
        case certificateData = "certificate_data"
        case certificatePassword = "certificate_password"
        case clientSecret = "operation_api_client_secret"
        case timeoutInterval = "timeout_interval"
    }

    // MARK: - Init

    public init(
        labAPIBaseURL: URL,
        functionAppBaseURL: URL? = nil,
        authority: String,
        resource: String,
        clientId: String,
        certificateData: String? = nil,
        certificatePassword: String? = nil,
        clientSecret: String? = nil,
        timeoutInterval: TimeInterval = 60
    ) {
        self.labAPIBaseURL = labAPIBaseURL
        self.functionAppBaseURL = functionAppBaseURL
        self.authority = authority
        self.resource = resource
        self.clientId = clientId
        self.certificateData = certificateData
        self.certificatePassword = certificatePassword
        self.clientSecret = clientSecret
        self.timeoutInterval = timeoutInterval
    }

    // MARK: - Custom Decoding

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let labURLString = try container.decode(String.self, forKey: .labAPIBaseURL)
        guard let labURL = URL(string: labURLString) else {
            throw DecodingError.dataCorruptedError(forKey: .labAPIBaseURL,
                                                    in: container,
                                                    debugDescription: "Invalid Lab API URL: \(labURLString)")
        }
        labAPIBaseURL = labURL

        if let funcURLString = try container.decodeIfPresent(String.self, forKey: .functionAppBaseURL) {
            functionAppBaseURL = URL(string: funcURLString)
        } else {
            functionAppBaseURL = nil
        }

        authority = try container.decode(String.self, forKey: .authority)
        resource = try container.decode(String.self, forKey: .resource)
        clientId = try container.decode(String.self, forKey: .clientId)
        certificateData = try container.decodeIfPresent(String.self, forKey: .certificateData)
        certificatePassword = try container.decodeIfPresent(String.self, forKey: .certificatePassword)
        clientSecret = try container.decodeIfPresent(String.self, forKey: .clientSecret)
        timeoutInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .timeoutInterval) ?? 60
    }

    /// Load configuration from a JSON file.
    public static func load(from fileURL: URL) throws -> LabAPIConfiguration {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(LabAPIConfiguration.self, from: data)
    }
}
