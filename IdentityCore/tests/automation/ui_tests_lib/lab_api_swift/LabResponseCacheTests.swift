// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import XCTest

final class LabResponseCacheTests: XCTestCase {

    func testSetAndGet() async {
        let cache = LabInMemoryResponseCache()
        let accounts = [
            LabTestAccount(
                objectId: "1", userType: "cloud", upn: "user@test.com",
                keyvaultName: "KEY", homeObjectId: "1", targetTenantId: "t1",
                homeTenantId: "t1", tenantName: "test.com", homeTenantName: "test.com",
                domainUsername: "user@test.com", isHomeAccount: true
            )
        ]

        await cache.set(accounts, forKey: "test-key")

        let retrieved: [LabTestAccount]? = await cache.get(forKey: "test-key")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.count, 1)
        XCTAssertEqual(retrieved?.first?.upn, "user@test.com")
    }

    func testGetReturnsNilForMissingKey() async {
        let cache = LabInMemoryResponseCache()
        let result: [LabTestAccount]? = await cache.get(forKey: "nonexistent")
        XCTAssertNil(result)
    }

    func testClear() async {
        let cache = LabInMemoryResponseCache()
        let accounts = [
            LabTestAccount(
                objectId: "1", userType: "cloud", upn: "user@test.com",
                keyvaultName: "KEY", homeObjectId: "1", targetTenantId: "t1",
                homeTenantId: "t1", tenantName: "test.com", homeTenantName: "test.com",
                domainUsername: "user@test.com", isHomeAccount: true
            )
        ]

        await cache.set(accounts, forKey: "test-key")
        await cache.clear()

        let result: [LabTestAccount]? = await cache.get(forKey: "test-key")
        XCTAssertNil(result)
    }
}
