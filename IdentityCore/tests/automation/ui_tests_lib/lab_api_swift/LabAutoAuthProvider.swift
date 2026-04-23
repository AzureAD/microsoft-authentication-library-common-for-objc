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

/// Auth provider that selects the best method based on environment:
///
/// 1. **Pipeline certificate** — `KEYVAULT_CERTIFICATE_DATA` env var (CI)
/// 2. **Azure CLI** — `az account get-access-token` (local dev)
///
/// Locally, just run `az login` once every ~90 days. No conf.json cert needed.
public final class LabAutoAuthProvider: LabAuthProvider {

    private let resource: String
    private let tokenCache: LabTokenCache

    /// Which auth method was last used successfully.
    public private(set) var lastUsedMethod: AuthMethod = .unknown

    public enum AuthMethod: String, Sendable {
        case pipelineCertificate = "Pipeline Certificate"
        case azureCLI = "Azure CLI"
        case unknown = "Unknown"
    }

    public init(resource: String, tokenCache: LabTokenCache = LabTokenCache()) {
        self.resource = resource
        self.tokenCache = tokenCache
    }

    public func getAccessToken() async throws -> String {
        let cacheKey = "auto|\(resource)"
        if let cached = await tokenCache.getToken(forKey: cacheKey) {
            return cached
        }

        // 1. Try pipeline certificate from env var (CI)
        if let pipelineCert = ProcessInfo.processInfo.environment["KEYVAULT_CERTIFICATE_DATA"],
           !pipelineCert.isEmpty {
            NSLog("[LabAutoAuthProvider] Pipeline certificate detected, using cert auth")
            // Certificate auth will be handled by the existing MSIDClientCredentialHelper
            // or a future LabCertificateAuthProvider. For now, fall through to Azure CLI.
        }

        // 2. Azure CLI (local dev)
        do {
            let token = try await getTokenViaAzureCLI()
            await tokenCache.setToken(token, forKey: cacheKey, expiresIn: 3600)
            lastUsedMethod = .azureCLI
            NSLog("[LabAutoAuthProvider] Authenticated via Azure CLI")
            return token
        } catch {
            throw LabAuthError.tokenAcquisitionFailed(
                "All auth methods failed. Last error: \(error.localizedDescription). "
                + "Run 'az login' to authenticate locally, or set KEYVAULT_CERTIFICATE_DATA for CI."
            )
        }
    }

    // MARK: - Azure CLI

    private func getTokenViaAzureCLI() async throws -> String {
        let azPaths = [
            "/usr/local/bin/az",
            "/opt/homebrew/bin/az",
            "/usr/bin/az",
        ]

        guard let azPath = azPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw LabAuthError.tokenAcquisitionFailed(
                "Azure CLI not found. Install: 'brew install azure-cli', then run 'az login'."
            )
        }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: azPath)
        process.arguments = [
            "account", "get-access-token",
            "--resource", resource,
            "--query", "accessToken",
            "--output", "tsv",
        ]
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw LabAuthError.tokenAcquisitionFailed(
                "Azure CLI exited with code \(process.terminationStatus). Run 'az login' to refresh."
            )
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            throw LabAuthError.tokenAcquisitionFailed("Azure CLI returned empty token.")
        }

        return token
    }
}
