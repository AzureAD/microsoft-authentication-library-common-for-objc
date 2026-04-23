// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import XCTest

final class LabPasswordManagerTests: XCTestCase {

    func testPasswordAlreadyOnAccountIsCached() async throws {
        let kvClient = LabKeyVaultClient(authCallback: { _, _ in "mock" })
        let manager = LabPasswordManager(
            keyVaultClient: kvClient,
            baseKeyVaultURL: "https://msidlabs.vault.azure.net/secrets/"
        )

        var account = LabTestAccount(
            objectId: "1", userType: "cloud", upn: "user@contoso.com",
            keyvaultName: "CONTOSO_USER", homeObjectId: "1", targetTenantId: "t1",
            homeTenantId: "t1", tenantName: "contoso.com", homeTenantName: "contoso.com",
            domainUsername: "user@contoso.com", isHomeAccount: true,
            password: "already-known"
        )

        let password = try await manager.loadPassword(for: &account)
        XCTAssertEqual(password, "already-known")

        let cacheCount = await manager.cacheCount
        XCTAssertEqual(cacheCount, 1)
    }

    func testSecondAccountWithSameKeyvaultNameUsesCache() async throws {
        let kvClient = LabKeyVaultClient(authCallback: { _, _ in "mock" })
        let manager = LabPasswordManager(
            keyVaultClient: kvClient,
            baseKeyVaultURL: "https://msidlabs.vault.azure.net/secrets/"
        )

        // First account has password already
        var account1 = LabTestAccount(
            objectId: "1", userType: "cloud", upn: "user1@contoso.com",
            keyvaultName: "SHARED_SECRET", homeObjectId: "1", targetTenantId: "t1",
            homeTenantId: "t1", tenantName: "contoso.com", homeTenantName: "contoso.com",
            domainUsername: "user1@contoso.com", isHomeAccount: true,
            password: "the-password"
        )
        _ = try await manager.loadPassword(for: &account1)

        // Second account references same keyvault name but has no password
        var account2 = LabTestAccount(
            objectId: "2", userType: "cloud", upn: "user2@contoso.com",
            keyvaultName: "SHARED_SECRET", homeObjectId: "2", targetTenantId: "t1",
            homeTenantId: "t1", tenantName: "contoso.com", homeTenantName: "contoso.com",
            domainUsername: "user2@contoso.com", isHomeAccount: true
        )
        let password = try await manager.loadPassword(for: &account2)

        // Should get cached password without network call
        XCTAssertEqual(password, "the-password")
        XCTAssertEqual(account2.password, "the-password")
    }

    func testInvalidateForcesRefetch() async throws {
        let kvClient = LabKeyVaultClient(authCallback: { _, _ in "mock" })
        let manager = LabPasswordManager(
            keyVaultClient: kvClient,
            baseKeyVaultURL: "https://msidlabs.vault.azure.net/secrets/"
        )

        var account = LabTestAccount(
            objectId: "1", userType: "cloud", upn: "user@contoso.com",
            keyvaultName: "MY_SECRET", homeObjectId: "1", targetTenantId: "t1",
            homeTenantId: "t1", tenantName: "contoso.com", homeTenantName: "contoso.com",
            domainUsername: "user@contoso.com", isHomeAccount: true,
            password: "old-password"
        )
        _ = try await manager.loadPassword(for: &account)

        let countBefore = await manager.cacheCount
        XCTAssertEqual(countBefore, 1)

        await manager.invalidate(keyvaultName: "MY_SECRET")

        let countAfter = await manager.cacheCount
        XCTAssertEqual(countAfter, 0)
    }

    func testClearCache() async throws {
        let kvClient = LabKeyVaultClient(authCallback: { _, _ in "mock" })
        let manager = LabPasswordManager(
            keyVaultClient: kvClient,
            baseKeyVaultURL: "https://msidlabs.vault.azure.net/secrets/"
        )

        var account = LabTestAccount(
            objectId: "1", userType: "cloud", upn: "user@contoso.com",
            keyvaultName: "SECRET_1", homeObjectId: "1", targetTenantId: "t1",
            homeTenantId: "t1", tenantName: "contoso.com", homeTenantName: "contoso.com",
            domainUsername: "user@contoso.com", isHomeAccount: true,
            password: "pw1"
        )
        _ = try await manager.loadPassword(for: &account)

        await manager.clearCache()

        let count = await manager.cacheCount
        XCTAssertEqual(count, 0)
    }
}
