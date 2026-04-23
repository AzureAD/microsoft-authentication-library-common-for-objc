// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// An `LabAuthProvider` that acquires tokens using a client secret.
///
/// Fallback authentication method when certificate is not available.
public final class LabClientSecretAuthProvider: LabAuthProvider {

    private let authority: String
    private let resource: String
    private let clientId: String
    private let clientSecret: String
    private let tokenCache: LabTokenCache
    private let session: URLSession

    private var cacheKey: String {
        "\(authority)|\(clientId)|\(resource)|secret"
    }

    public init(
        authority: String,
        resource: String,
        clientId: String,
        clientSecret: String,
        tokenCache: LabTokenCache = LabTokenCache(),
        session: URLSession = .shared
    ) {
        self.authority = authority
        self.resource = resource
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.tokenCache = tokenCache
        self.session = session
    }

    /// Convenience initializer from configuration.
    public convenience init(
        configuration: LabAPIConfiguration,
        tokenCache: LabTokenCache = LabTokenCache(),
        session: URLSession = .shared
    ) throws {
        guard let secret = configuration.clientSecret, !secret.isEmpty else {
            throw LabAuthError.noClientSecret
        }

        self.init(
            authority: configuration.authority,
            resource: configuration.resource,
            clientId: configuration.clientId,
            clientSecret: secret,
            tokenCache: tokenCache,
            session: session
        )
    }

    public func getAccessToken() async throws -> String {
        if let cached = await tokenCache.getToken(forKey: cacheKey) {
            return cached
        }

        let tokenEndpoint = "\(authority)/oauth2/token"
        guard let url = URL(string: tokenEndpoint) else {
            throw LabAuthError.tokenAcquisitionFailed("Invalid authority URL: \(tokenEndpoint)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=client_credentials",
            "client_id=\(clientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientId)",
            "resource=\(resource.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? resource)",
            "client_secret=\(clientSecret.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientSecret)",
        ].joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw LabAuthError.tokenAcquisitionFailed("Token endpoint returned error: \(responseBody)")
        }

        let tokenResponse = try JSONDecoder().decode(LabTokenResponse.self, from: data)

        await tokenCache.setToken(
            tokenResponse.accessToken,
            forKey: cacheKey,
            expiresIn: TimeInterval(tokenResponse.expiresIn)
        )

        return tokenResponse.accessToken
    }
}
