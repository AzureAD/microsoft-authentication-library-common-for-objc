// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import XCTest

final class LabRequestTests: XCTestCase {

    // MARK: - LabAccountRequest

    func testAccountRequestDefaultParameters() {
        let request = LabAccountRequest()

        XCTAssertEqual(request.path, "User")
        XCTAssertEqual(request.httpMethod, .get)
        XCTAssertTrue(request.shouldCache)
        XCTAssertEqual(request.apiTarget, .labAPI)

        let params = Dictionary(uniqueKeysWithValues: request.queryParameters.map { ($0.name, $0.value) })
        XCTAssertEqual(params["usertype"], "cloud")
        XCTAssertEqual(params["mfa"], "none")
    }

    func testAccountRequestWithFilters() {
        let request = LabAccountRequest(
            accountType: .federated,
            mfaType: .auto,
            protectionPolicy: .ca,
            federationProvider: .adfsV4,
            environment: .ppe
        )

        let params = Dictionary(uniqueKeysWithValues: request.queryParameters.map { ($0.name, $0.value) })
        XCTAssertEqual(params["usertype"], "federated")
        XCTAssertEqual(params["mfa"], "automfaonall")
        XCTAssertEqual(params["protectionpolicy"], "ca")
        XCTAssertEqual(params["federationprovider"], "adfsv4")
        XCTAssertEqual(params["azureenvironment"], "azureppe")
    }

    func testAccountRequestFederationProviderNoneOmitted() {
        let request = LabAccountRequest(federationProvider: FederationProvider.none)
        let paramNames = request.queryParameters.map(\.name)
        XCTAssertFalse(paramNames.contains("federationprovider"))
    }

    // MARK: - LabAppConfigRequest

    func testAppConfigRequestByAppId() {
        let request = LabAppConfigRequest(appId: "my-app-id")
        XCTAssertEqual(request.path, "app/my-app-id")
        XCTAssertTrue(request.shouldCache)
        XCTAssertEqual(request.apiTarget, .labAPI)
    }

    func testAppConfigRequestWithoutAppId() {
        let request = LabAppConfigRequest(appType: .cloud, signInAudience: .multipleOrgs)
        XCTAssertEqual(request.path, "App")

        let params = Dictionary(uniqueKeysWithValues: request.queryParameters.map { ($0.name, $0.value) })
        XCTAssertEqual(params["apptype"], "cloud")
        XCTAssertEqual(params["signinaudience"], "azureadmultipleorgs")
    }

    // MARK: - Operation Requests (Function App targets)

    func testResetRequestRoutesToFunctionApp() {
        let request = LabResetRequest(operation: .password, upn: "user@contoso.com")

        XCTAssertEqual(request.path, "Reset")
        XCTAssertEqual(request.httpMethod, .post)
        XCTAssertEqual(request.apiTarget, .functionApp)
        XCTAssertFalse(request.shouldCache)

        let params = Dictionary(uniqueKeysWithValues: request.queryParameters.map { ($0.name, $0.value) })
        XCTAssertEqual(params["operation"], "Password")
        XCTAssertEqual(params["upn"], "user@contoso.com")
    }

    func testTempAccountRequestRoutesToFunctionApp() {
        let request = LabTempAccountRequest(accountType: .globalMFA)

        XCTAssertEqual(request.path, "CreateTempUser")
        XCTAssertEqual(request.apiTarget, .functionApp)

        let params = Dictionary(uniqueKeysWithValues: request.queryParameters.map { ($0.name, $0.value) })
        XCTAssertEqual(params["usertype"], "GLOBALMFA")
    }

    func testDeleteDeviceRequestRoutesToFunctionApp() {
        let request = LabDeleteDeviceRequest(upn: "user@contoso.com", deviceId: "device-1")
        XCTAssertEqual(request.apiTarget, .functionApp)
        XCTAssertEqual(request.httpMethod, .post)
    }

    func testPolicyToggleRequestRoutesToFunctionApp() {
        let request = LabPolicyToggleRequest(upn: "user@contoso.com", policyType: "ca", enabled: true)
        XCTAssertEqual(request.apiTarget, .functionApp)

        let params = Dictionary(uniqueKeysWithValues: request.queryParameters.map { ($0.name, $0.value) })
        XCTAssertEqual(params["enabled"], "true")
    }

    // MARK: - Cache Key Determinism

    func testCacheKeyIsDeterministic() {
        let request1 = LabAccountRequest(accountType: .cloud, mfaType: MFAType.none, environment: .worldwideCloud)
        let request2 = LabAccountRequest(accountType: .cloud, mfaType: MFAType.none, environment: .worldwideCloud)

        XCTAssertEqual(request1.cacheKey, request2.cacheKey)
    }

    func testCacheKeyDiffersForDifferentRequests() {
        let request1 = LabAccountRequest(accountType: .cloud)
        let request2 = LabAccountRequest(accountType: .federated)

        XCTAssertNotEqual(request1.cacheKey, request2.cacheKey)
    }
}
