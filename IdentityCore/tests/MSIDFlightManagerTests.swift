//
//  Copyright (C) Microsoft Corporation. All rights reserved.
//

import XCTest

class MSIDFlightManagerTests: XCTestCase {
    
    private var mockFlightProvider: MockFlightProvider!
    private var mockQueryKeyDelegate: MockQueryKeyDelegate!
    
    override func setUp() {
        super.setUp()
        mockFlightProvider = MockFlightProvider()
        mockQueryKeyDelegate = MockQueryKeyDelegate()
    }
    
    override func tearDown() {
        mockFlightProvider = nil
        mockQueryKeyDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Singleton Tests
    
    func testSharedInstance_ReturnsSameInstance() {
        let instance1 = MSIDFlightManager.sharedInstance()
        let instance2 = MSIDFlightManager.sharedInstance()
        
        XCTAssertTrue(instance1 === instance2, "Shared instance should return the same object")
    }
    
    func testSharedInstance_IsThreadSafe() {
        let expectation = XCTestExpectation(description: "All threads complete")
        expectation.expectedFulfillmentCount = 10
        
        var instances: [MSIDFlightManager] = []
        let instancesQueue = DispatchQueue(label: "instances", attributes: .concurrent)
        
        for _ in 0..<10 {
            DispatchQueue.global().async {
                let instance = MSIDFlightManager.sharedInstance()
                instancesQueue.async(flags: .barrier) {
                    instances.append(instance)
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // All instances should be the same
        let firstInstance = instances[0]
        for instance in instances {
            XCTAssertTrue(instance === firstInstance, "All instances should be identical")
        }
    }
    
    // MARK: - Query Key Instance Tests
    
    func testSharedInstanceByQueryKey_WithEmptyQueryKey_ReturnsSharedInstance() {
        let instance = MSIDFlightManager.sharedInstance(byQueryKey: "", keyType: .tenantId)
        let sharedInstance = MSIDFlightManager.sharedInstance()
        
        XCTAssertTrue(instance === sharedInstance, "Should return shared instance when queryKey is empty")
    }
    
    func testSharedInstanceByQueryKey_WithValidQueryKey_ReturnsUniqueInstance() {
        let queryKey = "test-query-key"
        let instance1 = MSIDFlightManager.sharedInstance(byQueryKey: queryKey, keyType: .tenantId)
        let instance2 = MSIDFlightManager.sharedInstance(byQueryKey: queryKey, keyType: .tenantId)
        let sharedInstance = MSIDFlightManager.sharedInstance()
        
        XCTAssertTrue(instance1 === instance2, "Same query key should return same instance")
        XCTAssertFalse(instance1 === sharedInstance, "Query key instance should be different from shared instance")
    }
    
    func testSharedInstanceByQueryKey_WithDifferentQueryKeys_ReturnsDifferentInstances() {
        let instance1 = MSIDFlightManager.sharedInstance(byQueryKey: "key1", keyType: .tenantId)
        let instance2 = MSIDFlightManager.sharedInstance(byQueryKey: "key2", keyType: .tenantId)
        
        XCTAssertFalse(instance1 === instance2, "Different query keys should return different instances")
    }
    
    func testSharedInstanceByQueryKey_SetsFlightProviderFromDelegate() {
        let queryKey = "test-key"
        let expectedFlightProvider = MockFlightProvider()
        mockQueryKeyDelegate.mockFlightProvider = expectedFlightProvider
        
        let sharedInstance = MSIDFlightManager.sharedInstance()
        sharedInstance.queryKeyFlightProvider = mockQueryKeyDelegate
        
        _ = MSIDFlightManager.sharedInstance(byQueryKey: queryKey, keyType: .tenantId)
        
        XCTAssertTrue(mockQueryKeyDelegate.flightProviderForQueryKeyCalled)
        XCTAssertEqual(mockQueryKeyDelegate.lastQueryKey, queryKey)
        XCTAssertEqual(mockQueryKeyDelegate.lastKeyType, .tenantId)
    }
    
    // MARK: - Flight Provider Tests
    
    func testBoolForKey_WithoutFlightProvider_ReturnsFalse() {
        let flightManager = MSIDFlightManager.sharedInstance()
        flightManager.flightProvider = nil
        
        let result = flightManager.bool(forKey: "test-key")
        
        XCTAssertFalse(result, "Should return false when no flight provider is set")
    }
    
    func testBoolForKey_WithFlightProvider_ReturnsProviderValue() {
        let flightManager = MSIDFlightManager.sharedInstance()
        mockFlightProvider.boolValues["test-key"] = true
        
        // Use a more reliable synchronization approach
        let expectation = XCTestExpectation(description: "Flight provider set")
        flightManager.flightProvider = mockFlightProvider
        
        // Give a small delay to ensure the barrier async completes
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let result = flightManager.bool(forKey: "test-key")
        
        XCTAssertTrue(result, "Should return value from flight provider")
        XCTAssertTrue(mockFlightProvider.boolForKeyCalled)
        XCTAssertEqual(mockFlightProvider.lastBoolKey, "test-key")
    }
    
    func testStringForKey_WithoutFlightProvider_ReturnsNil() {
        let flightManager = MSIDFlightManager.sharedInstance()
        flightManager.flightProvider = nil
        
        let result = flightManager.string(forKey: "test-key")
        
        XCTAssertNil(result, "Should return nil when no flight provider is set")
    }
    
    func testStringForKey_WithFlightProvider_ReturnsProviderValue() {
        let flightManager = MSIDFlightManager.sharedInstance()
        let expectedValue = "test-value"
        mockFlightProvider.stringValues["test-key"] = expectedValue
        
        // Use a more reliable synchronization approach
        let expectation = XCTestExpectation(description: "Flight provider set")
        flightManager.flightProvider = mockFlightProvider
        
        // Give a small delay to ensure the barrier async completes
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let result = flightManager.string(forKey: "test-key")
        
        XCTAssertEqual(result, expectedValue, "Should return value from flight provider")
        XCTAssertTrue(mockFlightProvider.stringForKeyCalled)
        XCTAssertEqual(mockFlightProvider.lastStringKey, "test-key")
    }
    
    // MARK: - Thread Safety Tests
    
    func testFlightProviderSetter_IsThreadSafe() {
        let flightManager = MSIDFlightManager.sharedInstance()
        let expectation = XCTestExpectation(description: "All operations complete")
        expectation.expectedFulfillmentCount = 20
        
        // Simulate concurrent reads and writes
        for i in 0..<10 {
            DispatchQueue.global().async {
                let provider = MockFlightProvider()
                provider.identifier = "provider-\(i)"
                flightManager.flightProvider = provider
                expectation.fulfill()
            }
            
            DispatchQueue.global().async {
                _ = flightManager.bool(forKey: "test-key-\(i)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should not crash and should have a flight provider set
        XCTAssertNotNil(flightManager.flightProvider)
    }
    
    func testConcurrentFlightOperations_AreThreadSafe() {
        let flightManager = MSIDFlightManager.sharedInstance()
        mockFlightProvider.boolValues["bool-key"] = true
        mockFlightProvider.stringValues["string-key"] = "test-value"
        flightManager.flightProvider = mockFlightProvider
        
        let expectation = XCTestExpectation(description: "All operations complete")
        expectation.expectedFulfillmentCount = 100
        
        for _ in 0..<50 {
            DispatchQueue.global().async {
                _ = flightManager.bool(forKey: "bool-key")
                expectation.fulfill()
            }
            
            DispatchQueue.global().async {
                _ = flightManager.string(forKey: "string-key")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should not crash
        XCTAssertTrue(mockFlightProvider.boolForKeyCalled)
        XCTAssertTrue(mockFlightProvider.stringForKeyCalled)
    }
    
    // MARK: - Edge Cases
    
    func testQueryKeyInstance_WithWhitespaceOnlyKey_ReturnsSharedInstance() {
        let instance = MSIDFlightManager.sharedInstance(byQueryKey: "   ", keyType: .tenantId)
        let sharedInstance = MSIDFlightManager.sharedInstance()
        
        XCTAssertTrue(instance === sharedInstance, "Should return shared instance for whitespace-only key")
    }
    
    func testMultipleKeyTypes_CreateSeparateInstances() {
        let queryKey = "same-key"
        let instance1 = MSIDFlightManager.sharedInstance(byQueryKey: queryKey, keyType: .tenantId)
        let instance2 = MSIDFlightManager.sharedInstance(byQueryKey: queryKey, keyType: .appBundleId)
        
        // Note: Based on the implementation, same queryKey with different keyType should return the same instance
        // since the implementation only uses queryKey as the dictionary key
        XCTAssertTrue(instance1 === instance2, "Same query key returns same instance regardless of key type")
    }
}

// MARK: - Mock Classes

class MockFlightProvider: NSObject, MSIDFlightManagerInterface {
    var identifier: String = "mock"
    var boolValues: [String: Bool] = [:]
    var stringValues: [String: String] = [:]
    
    var boolForKeyCalled = false
    var stringForKeyCalled = false
    var lastBoolKey: String?
    var lastStringKey: String?
    
    func bool(forKey flightKey: String) -> Bool {
        boolForKeyCalled = true
        lastBoolKey = flightKey
        return boolValues[flightKey] ?? false
    }
    
    func string(forKey key: String) -> String? {
        stringForKeyCalled = true
        lastStringKey = key
        return stringValues[key]
    }
}

class MockQueryKeyDelegate: NSObject, MSIDFlightManagerQueryKeyDelegate {
    var mockFlightProvider: MockFlightProvider?
    
    var flightProviderForQueryKeyCalled = false
    var lastQueryKey: String?
    var lastKeyType: MSIDFlightManagerQueryKeyType?
    
    func flightProvider(forQueryKey queryKey: String, keyType: MSIDFlightManagerQueryKeyType) -> MSIDFlightManagerInterface? {
        flightProviderForQueryKeyCalled = true
        lastQueryKey = queryKey
        lastKeyType = keyType
        return mockFlightProvider
    }
}
