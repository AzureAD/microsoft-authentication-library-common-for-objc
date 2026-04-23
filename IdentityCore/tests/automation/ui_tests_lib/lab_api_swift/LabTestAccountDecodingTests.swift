// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import XCTest

final class LabTestAccountDecodingTests: XCTestCase {

    // MARK: - Basic Cloud Account

    func testDecodeCloudAccount() throws {
        let json = """
        {
            "objectId": "abc-123",
            "userType": "cloud",
            "upn": "user@contoso.com",
            "credentialVaultKeyName": "CONTOSO_USER",
            "homeObjectId": "abc-123",
            "tenantID": "tenant-guid-1",
            "homeTenantID": "tenant-guid-1",
            "homeDomain": "contoso.com"
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder().decode(LabTestAccount.self, from: json)

        XCTAssertEqual(account.objectId, "abc-123")
        XCTAssertEqual(account.userType, "cloud")
        XCTAssertEqual(account.upn, "user@contoso.com")
        XCTAssertEqual(account.keyvaultName, "CONTOSO_USER")
        XCTAssertEqual(account.targetTenantId, "tenant-guid-1")
        XCTAssertEqual(account.homeTenantId, "tenant-guid-1")
        XCTAssertEqual(account.homeTenantName, "contoso.com")
        XCTAssertEqual(account.tenantName, "contoso.com")
        XCTAssertTrue(account.isHomeAccount)
        XCTAssertEqual(account.homeAccountId, "abc-123.tenant-guid-1")
        XCTAssertEqual(account.domainUsername, "user@contoso.com")
    }

    // MARK: - Guest Account (with #EXT#)

    func testDecodeGuestAccount() throws {
        let json = """
        {
            "objectId": "guest-obj-1",
            "userType": "Guest",
            "homeUPN": "user@home.com",
            "upn": "user_home.com#EXT#@target.com",
            "credentialVaultKeyName": "GUEST_KEY",
            "homeObjectId": "home-obj-1",
            "tenantID": "target-tenant",
            "homeTenantID": "home-tenant",
            "homeDomain": "home.com"
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder().decode(LabTestAccount.self, from: json)

        XCTAssertEqual(account.upn, "user@home.com")
        XCTAssertFalse(account.isHomeAccount)
        XCTAssertEqual(account.homeObjectId, "home-obj-1")
        XCTAssertEqual(account.targetTenantId, "target-tenant")
        XCTAssertEqual(account.homeTenantId, "home-tenant")
        XCTAssertEqual(account.tenantName, "target.com")
        XCTAssertEqual(account.homeTenantName, "home.com")
    }

    // MARK: - HomeUPN = "None" Fallback

    func testDecodeAccountWithHomeUPNNone() throws {
        let json = """
        {
            "objectId": "obj-1",
            "userType": "cloud",
            "homeUPN": "None",
            "upn": "fallback@domain.com",
            "credentialVaultKeyName": "KEY",
            "tenantID": "t1"
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder().decode(LabTestAccount.self, from: json)
        XCTAssertEqual(account.upn, "fallback@domain.com")
    }

    // MARK: - Domain Username Fallback

    func testDomainUsernameFallsBackToUPN() throws {
        let json = """
        {
            "objectId": "obj-1",
            "userType": "cloud",
            "upn": "user@contoso.com",
            "domainAccount": "None",
            "credentialVaultKeyName": "KEY",
            "tenantID": "t1"
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder().decode(LabTestAccount.self, from: json)
        XCTAssertEqual(account.domainUsername, "user@contoso.com")
    }

    // MARK: - Override Properties

    func testOverrideTargetTenantId() throws {
        let json = """
        {
            "objectId": "obj-1",
            "userType": "cloud",
            "upn": "user@contoso.com",
            "credentialVaultKeyName": "KEY",
            "tenantID": "original-tenant"
        }
        """.data(using: .utf8)!

        var account = try JSONDecoder().decode(LabTestAccount.self, from: json)
        XCTAssertEqual(account.effectiveTargetTenantId, "original-tenant")

        account.overriddenTargetTenantId = "overridden-tenant"
        XCTAssertEqual(account.effectiveTargetTenantId, "overridden-tenant")
    }

    // MARK: - TenantId Key Variant

    func testDecodeWithLowercaseTenantIdKey() throws {
        let json = """
        {
            "objectId": "obj-1",
            "userType": "cloud",
            "upn": "user@contoso.com",
            "credentialVaultKeyName": "KEY",
            "tenantId": "lowercase-tenant"
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder().decode(LabTestAccount.self, from: json)
        XCTAssertEqual(account.targetTenantId, "lowercase-tenant")
    }

    // MARK: - Hashable / Equality

    func testEqualityAndHashing() throws {
        let account1 = LabTestAccount(
            objectId: "obj-1", userType: "cloud", upn: "user@contoso.com",
            keyvaultName: "KEY", homeObjectId: "obj-1", targetTenantId: "t1",
            homeTenantId: "t1", tenantName: "contoso.com", homeTenantName: "contoso.com",
            domainUsername: "user@contoso.com", isHomeAccount: true
        )
        let account2 = LabTestAccount(
            objectId: "obj-1", userType: "cloud", upn: "user@contoso.com",
            keyvaultName: "DIFFERENT_KEY", homeObjectId: "obj-1", targetTenantId: "t1",
            homeTenantId: "t1", tenantName: "contoso.com", homeTenantName: "contoso.com",
            domainUsername: "user@contoso.com", isHomeAccount: true
        )

        XCTAssertEqual(account1, account2)
        XCTAssertEqual(account1.hashValue, account2.hashValue)
    }
}
