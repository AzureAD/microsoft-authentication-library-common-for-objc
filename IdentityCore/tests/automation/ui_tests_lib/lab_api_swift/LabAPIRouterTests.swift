// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import XCTest

final class LabAPIRouterTests: XCTestCase {

    private let labURL = URL(string: "https://msidlab.com/api")!
    private let functionAppURL = URL(string: "https://msidlabfunc.azurewebsites.net/api")!

    func testRoutesLabAPIRequests() {
        let router = LabAPIRouter(labAPIBaseURL: labURL, functionAppBaseURL: functionAppURL)
        let request = LabAccountRequest(accountType: .cloud)

        let url = router.buildURL(for: request)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.hasPrefix("https://msidlab.com/api/User"))
        XCTAssertTrue(url!.absoluteString.contains("usertype=cloud"))
    }

    func testRoutesFunctionAppRequests() {
        let router = LabAPIRouter(labAPIBaseURL: labURL, functionAppBaseURL: functionAppURL)
        let request = LabResetRequest(operation: .password, upn: "user@test.com")

        let url = router.buildURL(for: request)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.hasPrefix("https://msidlabfunc.azurewebsites.net/api/Reset"))
    }

    func testFallsBackToLabURLWhenNoFunctionApp() {
        let router = LabAPIRouter(labAPIBaseURL: labURL, functionAppBaseURL: nil)
        let request = LabResetRequest(operation: .password, upn: "user@test.com")

        let url = router.buildURL(for: request)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.hasPrefix("https://msidlab.com/api/Reset"))
    }

    func testURLContainsQueryParameters() {
        let router = LabAPIRouter(labAPIBaseURL: labURL, functionAppBaseURL: nil)
        let request = LabAccountRequest(
            accountType: .federated,
            mfaType: .auto,
            environment: .ppe
        )

        let url = router.buildURL(for: request)
        XCTAssertNotNil(url)
        let query = url!.query ?? ""
        XCTAssertTrue(query.contains("usertype=federated"))
        XCTAssertTrue(query.contains("mfa=automfaonall"))
        XCTAssertTrue(query.contains("azureenvironment=azureppe"))
    }
}
