// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import XCTest

final class LabTestApplicationDecodingTests: XCTestCase {

    func testDecodeApplication() throws {
        let json = """
        {
            "appId": "app-guid-1",
            "objectId": "obj-guid-1",
            "labName": "TestApp",
            "multiTenantApp": true,
            "redirectUris": ["msauth.com.test://auth", "https://login.microsoftonline.com/common/oauth2/nativeclient"],
            "defaultScopes": ["user.read"],
            "defaultAuthorities": ["https://login.microsoftonline.com/common"],
            "b2cAuthorities": []
        }
        """.data(using: .utf8)!

        let app = try JSONDecoder().decode(LabTestApplication.self, from: json)

        XCTAssertEqual(app.appId, "app-guid-1")
        XCTAssertEqual(app.objectId, "obj-guid-1")
        XCTAssertEqual(app.labName, "TestApp")
        XCTAssertTrue(app.multiTenantApp)
        XCTAssertEqual(app.redirectUris.count, 2)
        XCTAssertEqual(app.defaultScopes, ["user.read"])
        XCTAssertEqual(app.defaultRedirectUri, "msauth.com.test://auth")
    }

    func testDecodeApplicationWithMissingOptionalFields() throws {
        let json = """
        {
            "appId": "app-1"
        }
        """.data(using: .utf8)!

        let app = try JSONDecoder().decode(LabTestApplication.self, from: json)

        XCTAssertEqual(app.appId, "app-1")
        XCTAssertEqual(app.objectId, "")
        XCTAssertFalse(app.multiTenantApp)
        XCTAssertTrue(app.redirectUris.isEmpty)
        XCTAssertNil(app.defaultRedirectUri)
    }

    func testRedirectUriPrefix() {
        var app = LabTestApplication(
            appId: "app-1",
            objectId: "obj-1",
            labName: "Test",
            redirectUris: ["msauth.com.test://auth", "https://login.microsoftonline.com/common/oauth2/nativeclient"]
        )

        XCTAssertEqual(app.defaultRedirectUri, "msauth.com.test://auth")

        app.redirectUriPrefix = "https://"
        XCTAssertEqual(app.defaultRedirectUri, "https://login.microsoftonline.com/common/oauth2/nativeclient")
    }
}
