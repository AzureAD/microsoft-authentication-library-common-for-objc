//
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

/// Test automation account model for lab API
@objcMembers open class MSIDTestAutomationAccount: NSObject, MSIDJsonSerializable {
    
    // MARK: - Static Properties
    
    /// Temporary tenant mapping dictionary until lab adds this to response
    private static let tenantMappingDictionary: [String: String] = {
        return ["outlook.com": "9188040d-6c67-4c5b-b112-36a304b66dad"]
    }()
    
    // MARK: - Public Properties (Readonly)
    
    public private(set) var objectId: String
    public private(set) var userType: String
    public private(set) var upn: String
    public private(set) var domainUsername: String
    public private(set) var homeObjectId: String
    public private(set) var homeTenantId: String
    public private(set) var tenantName: String
    public private(set) var homeTenantName: String
    public private(set) var homeAccountId: String
    public private(set) var isHomeAccount: Bool
    public private(set) var associatedAppID: String?
    
    // MARK: - Public Properties (Writable)
    
    public var password: String?
    public var overriddenTargetTenantId: String?
    public var overriddenKeyvaultName: String?
    
    // MARK: - Private Backing Storage
    
    private var _targetTenantId: String
    private var _keyvaultName: String
    
    // MARK: - Computed Properties with Overrides
    
    /// Returns overridden target tenant ID if set, otherwise returns the default
    public var targetTenantId: String {
        if let overridden = overriddenTargetTenantId, !overridden.isEmpty {
            return overridden
        }
        return _targetTenantId
    }
    
    /// Returns overridden keyvault name if set, otherwise returns the default
    public var keyvaultName: String {
        if let overridden = overriddenKeyvaultName, !overridden.isEmpty {
            return overridden
        }
        return _keyvaultName
    }
    
    // MARK: - Helper Methods
    
    private static func isStringNilOrBlank(_ string: String?) -> Bool {
        guard let string = string else { return true }
        return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private static func domainSuffix(of email: String?) -> String {
        guard let email = email else { return "" }
        let components = email.components(separatedBy: "@")
        return components.count > 1 ? components[1] : ""
    }
    
    // MARK: - MSIDJsonSerializable
    
    required public init(jsonDictionary json: [AnyHashable: Any]!) throws {
        // Convert AnyHashable keys to String keys
        let stringKeyedJson = json?.reduce(into: [String: Any]()) { result, pair in
            if let key = pair.key as? String {
                result[key] = pair.value
            }
        } ?? [:]
        
        // Extract values from JSON
        guard let objectId = stringKeyedJson["objectId"] as? String,
              let userType = stringKeyedJson["userType"] as? String else {
            throw NSError(domain: MSIDErrorDomain,
                         code: MSIDErrorCode.serverInvalidResponse.rawValue,
                         userInfo: [NSLocalizedDescriptionKey: "Missing required parameters in account response JSON"])
        }
        
        self.objectId = objectId
        self.userType = userType
        self.associatedAppID = stringKeyedJson["appId"] as? String
        
        // Determine UPN
        let homeUPN = stringKeyedJson["homeUPN"] as? String
        let guestUPN = stringKeyedJson["upn"] as? String
        self.upn = (homeUPN != nil && homeUPN != "None") ? homeUPN! : (guestUPN ?? "")
        self.isHomeAccount = !(guestUPN?.contains("#EXT#") ?? false)
        
        // Determine domain username
        let domainUsername = stringKeyedJson["domainAccount"] as? String
        if let domainUsername = domainUsername,
           domainUsername != "None",
           !Self.isStringNilOrBlank(domainUsername) {
            self.domainUsername = domainUsername
        } else {
            self.domainUsername = self.upn
        }
        
        // Keyvault name and password
        guard let keyvaultName = stringKeyedJson["credentialVaultKeyName"] as? String else {
            throw NSError(domain: MSIDErrorDomain,
                         code: MSIDErrorCode.serverInvalidResponse.rawValue,
                         userInfo: [NSLocalizedDescriptionKey: "Missing keyvaultName in account response JSON"])
        }
        
        self._keyvaultName = keyvaultName
        self.password = stringKeyedJson["password"] as? String
        
        // Home object ID
        self.homeObjectId = self.isHomeAccount ? objectId : (stringKeyedJson["homeObjectId"] as? String ?? objectId)
        
        // Target tenant ID
        var targetTenantId = stringKeyedJson["tenantID"] as? String
        if targetTenantId == nil {
            targetTenantId = stringKeyedJson["tenantId"] as? String
        }
        
        // Tenant name
        self.tenantName = Self.domainSuffix(of: guestUPN)
        
        // TODO: remove this hack after MSA migration on lab side is complete!
        if let mappedTenantId = Self.tenantMappingDictionary[self.tenantName.lowercased()] {
            targetTenantId = mappedTenantId
        }
        
        self._targetTenantId = targetTenantId ?? ""
        
        // Home tenant ID
        let homeTenantId = stringKeyedJson["homeTenantID"] as? String
        if let homeTenantId = homeTenantId, !Self.isStringNilOrBlank(homeTenantId) {
            self.homeTenantId = homeTenantId
        } else {
            self.homeTenantId = self._targetTenantId
        }
        
        // Home tenant name
        let homeTenantName = stringKeyedJson["homeDomain"] as? String
        self.homeTenantName = homeTenantName ?? self.tenantName
        
        // Home account ID
        self.homeAccountId = "\(self.homeObjectId).\(self.homeTenantId)"
        
        super.init()
    }
    
    public func jsonDictionary() -> [AnyHashable: Any]! {
        return [:]
    }
}
