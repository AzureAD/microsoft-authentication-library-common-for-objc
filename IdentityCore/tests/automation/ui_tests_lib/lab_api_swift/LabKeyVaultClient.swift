// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// Errors that can occur when interacting with Azure Key Vault.
public enum LabKeyVaultError: LocalizedError, Sendable {
    case invalidURL(String)
    case noAuthCallback
    case noAuthHeader
    case noBearerChallenge
    case missingAuthParameter(String)
    case networkError(Error)
    case httpError(statusCode: Int, body: String?)
    case decodingError(Error)
    case noSecretValue

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid Key Vault URL: \(url)"
        case .noAuthCallback:
            return "No authentication callback configured for Key Vault."
        case .noAuthHeader:
            return "Key Vault did not return a WWW-Authenticate header."
        case .noBearerChallenge:
            return "No Bearer challenge found in WWW-Authenticate header."
        case .missingAuthParameter(let param):
            return "Missing authentication parameter: \(param)"
        case .networkError(let error):
            return "Key Vault network error: \(error.localizedDescription)"
        case .httpError(let code, let body):
            var msg = "Key Vault HTTP error \(code)"
            if let body = body { msg += ": \(body)" }
            return msg
        case .decodingError(let error):
            return "Failed to decode Key Vault response: \(error.localizedDescription)"
        case .noSecretValue:
            return "Key Vault returned an empty secret value."
        }
    }
}

/// Represents a secret retrieved from Azure Key Vault.
public struct LabKeyVaultSecret: Sendable {
    public let name: String
    public let value: String
    public let url: URL
    public let created: Date?
    public let updated: Date?
}

/// A client for fetching secrets from Azure Key Vault.
///
/// Modernized from the ObjC `Secret` + `Network` + `Authentication` classes.
/// Uses `async/await` and structured concurrency.
public final class LabKeyVaultClient: Sendable {

    public typealias AuthCallback = @Sendable (_ authority: String, _ resource: String) async throws -> String

    private let authCallback: AuthCallback
    private let session: URLSession
    private let apiVersion: String

    public init(
        authCallback: @escaping AuthCallback,
        session: URLSession = .shared,
        apiVersion: String = "2016-10-01"
    ) {
        self.authCallback = authCallback
        self.session = session
        self.apiVersion = apiVersion
    }

    /// Fetches a secret from Key Vault.
    public func getSecret(url: URL) async throws -> LabKeyVaultSecret {
        let (authority, resource) = try await discoverAuthParameters(for: url)
        let accessToken = try await authCallback(authority, resource)

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "api-version", value: apiVersion))
        components?.queryItems = queryItems

        guard let secretURL = components?.url else {
            throw LabKeyVaultError.invalidURL(url.absoluteString)
        }

        var request = URLRequest(url: secretURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LabKeyVaultError.networkError(URLError(.badServerResponse))
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw LabKeyVaultError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        let secretResponse = try JSONDecoder().decode(LabSecretValueResponse.self, from: data)

        guard let value = secretResponse.value, !value.isEmpty else {
            throw LabKeyVaultError.noSecretValue
        }

        let name = url.lastPathComponent
        var created: Date?
        var updated: Date?
        if let attrs = secretResponse.attributes {
            if let c = attrs.created { created = Date(timeIntervalSince1970: TimeInterval(c)) }
            if let u = attrs.updated { updated = Date(timeIntervalSince1970: TimeInterval(u)) }
        }

        return LabKeyVaultSecret(name: name, value: value, url: url, created: created, updated: updated)
    }

    private func discoverAuthParameters(for url: URL) async throws -> (authority: String, resource: String) {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "api-version", value: apiVersion))
        components?.queryItems = queryItems

        guard let discoveryURL = components?.url else {
            throw LabKeyVaultError.invalidURL(url.absoluteString)
        }

        let request = URLRequest(url: discoveryURL)
        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LabKeyVaultError.networkError(URLError(.badServerResponse))
        }

        guard let authHeader = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate") else {
            throw LabKeyVaultError.noAuthHeader
        }

        return try parseBearerChallenge(authHeader)
    }

    private func parseBearerChallenge(_ header: String) throws -> (authority: String, resource: String) {
        guard header.lowercased().hasPrefix("bearer ") else {
            throw LabKeyVaultError.noBearerChallenge
        }

        let params = header.dropFirst("Bearer ".count)
        var dict: [String: String] = [:]
        let scanner = Scanner(string: String(params))
        scanner.charactersToBeSkipped = CharacterSet.whitespaces.union(.init(charactersIn: ","))

        while !scanner.isAtEnd {
            guard let key = scanner.scanUpToString("=") else { break }
            _ = scanner.scanString("=")
            _ = scanner.scanString("\"")
            guard let value = scanner.scanUpToString("\"") else { break }
            _ = scanner.scanString("\"")
            dict[key.lowercased()] = value
        }

        let authority = dict["authorization_uri"] ?? dict["authorization"] ?? dict["authority"]
        guard let auth = authority, !auth.isEmpty else {
            throw LabKeyVaultError.missingAuthParameter("authorization_uri")
        }

        let resource = dict["resource"] ?? dict["scope"]
        guard let res = resource, !res.isEmpty else {
            throw LabKeyVaultError.missingAuthParameter("resource")
        }

        return (auth, res)
    }
}

// MARK: - Response Models

private struct LabSecretValueResponse: Decodable {
    let value: String?
    let attributes: LabSecretAttributes?
}

private struct LabSecretAttributes: Decodable {
    let created: Int?
    let updated: Int?
}
