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

// MARK: - String Constants

/// Test account type constants
@objcMembers public class MSIDTestAccountType: NSObject {
    public static let cloud = "cloud"
    public static let federated = "federated"
    public static let onPrem = "onprem"
    public static let guest = "guest"
    public static let msa = "msa"
    public static let b2c = "b2c"
}

/// Test account MFA type constants
@objcMembers public class MSIDTestAccountMFAType: NSObject {
    public static let none = "none"
    public static let manual = "mfaonall"
    public static let auto = "automfaonall"
    public static let onSPO = "mfaonspo"
}

/// Test account protection policy type constants
@objcMembers public class MSIDTestAccountProtectionPolicyType: NSObject {
    public static let none = "none"
    public static let ca = "ca"
    public static let mam = "mam"
    public static let mdm = "mdm"
    public static let mamca = "mamca"
    public static let mamcaspo = "mamspo"
    public static let trueMamca = "truemamca"
    public static let mdmca = "mdmca"
    public static let tb = "tokenbinding"
}

// MARK: - Backward Compatibility Constants for Objective-C

/// Backward-compatible global constants matching the old Objective-C enum naming convention
@objc public let MSIDTestAccountProtectionPolicyTypeNone = MSIDTestAccountProtectionPolicyType.none
@objc public let MSIDTestAccountProtectionPolicyTypeCA = MSIDTestAccountProtectionPolicyType.ca
@objc public let MSIDTestAccountProtectionPolicyTypeMAM = MSIDTestAccountProtectionPolicyType.mam
@objc public let MSIDTestAccountProtectionPolicyTypeMDM = MSIDTestAccountProtectionPolicyType.mdm
@objc public let MSIDTestAccountProtectionPolicyTypeMAMCA = MSIDTestAccountProtectionPolicyType.mamca
@objc public let MSIDTestAccountProtectionPolicyTypeMAMCASPO = MSIDTestAccountProtectionPolicyType.mamcaspo
@objc public let MSIDTestAccountProtectionPolicyTypeTrueMAMCA = MSIDTestAccountProtectionPolicyType.trueMamca
@objc public let MSIDTestAccountProtectionPolicyTypeMDMCA = MSIDTestAccountProtectionPolicyType.mdmca
@objc public let MSIDTestAccountProtectionPolicyTypeTB = MSIDTestAccountProtectionPolicyType.tb

/// Test account B2C provider type constants
@objcMembers public class MSIDTestAccountB2CProviderType: NSObject {
    public static let none = "none"
    public static let amazon = "amazon"
    public static let facebook = "facebook"
    public static let google = "google"
    public static let local = "local"
    public static let msa = "microsoft"
}

/// Test account federation provider type constants
@objcMembers public class MSIDTestAccountFederationProviderType: NSObject {
    public static let none = "none"
    public static let adfsV2 = "adfsv2"
    public static let adfsV3 = "adfsv3"
    public static let adfsV4 = "adfsv4"
    public static let adfs2019 = "adfsv2019"
    public static let ping = "ping"
    public static let shibboleth = "shibboleth"
    public static let ciam = "ciam"
    public static let ciamCUD = "ciamcud"
}

/// Test account environment type constants
@objcMembers public class MSIDTestAccountEnvironmentType: NSObject {
    public static let wwCloud = "azurecloud"
    public static let chinaCloud = "azurechinacloud"
    public static let germanCloud = "azuregermanycloud"
    public static let usGovCloud = "azureusgovernment"
    public static let ppe = "azureppe"
    public static let b2c = "azureb2ccloud"
}

/// Test account user role type constants
@objcMembers public class MSIDTestAccountTypeUserRoleType: NSObject {
    public static let cloudAdministrator = "CloudDeviceAdministrator"
}

// MARK: - Main Class

@objcMembers open class MSIDTestAutomationAccountConfigurationRequest: MSIDAutomationBaseApiRequest {
    
    // MARK: - Properties
    
    public var mfaType: String = MSIDTestAccountMFAType.none
    public var accountType: String = MSIDTestAccountType.cloud
    public var protectionPolicyType: String = MSIDTestAccountProtectionPolicyType.none
    public var b2cProviderType: String?
    public var federationProviderType: String = MSIDTestAccountFederationProviderType.none
    public var environmentType: String = MSIDTestAccountEnvironmentType.wwCloud
    public var additionalQueryParameters: [String: String]?
    public var userRole: String?
    
    // MARK: - Initialization
    
    public required init() {
        super.init()
    }
    
    // MARK: - NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any {
        let request = type(of: self).init()
        request.mfaType = mfaType
        request.accountType = accountType
        request.protectionPolicyType = protectionPolicyType
        request.b2cProviderType = b2cProviderType
        request.federationProviderType = federationProviderType
        request.environmentType = environmentType
        request.additionalQueryParameters = additionalQueryParameters
        request.userRole = userRole
        return request
    }
    
    // MARK: - Base Request Override
    
    open override func requestOperationPath() -> String? {
        return "User"
    }
    
    open override func queryItems() -> [URLQueryItem]? {
        var queryItems = [URLQueryItem]()
        
        // Add MFA type
        queryItems.append(URLQueryItem(name: "mfa", value: mfaType))
        
        // Add account type
        queryItems.append(URLQueryItem(name: "usertype", value: accountType))
        
        // Add protection policy type
        queryItems.append(URLQueryItem(name: "protectionpolicy", value: protectionPolicyType))
        
        // Add B2C provider type if present
        if let b2cProvider = b2cProviderType {
            queryItems.append(URLQueryItem(name: "b2cprovider", value: b2cProvider))
        }
        
        // Add federation provider type if not "none"
        if federationProviderType != MSIDTestAccountFederationProviderType.none {
            queryItems.append(URLQueryItem(name: "federationprovider", value: federationProviderType))
        }
        
        // Add environment type
        queryItems.append(URLQueryItem(name: "azureenvironment", value: environmentType))
        
        // Add user role if present
        if let role = userRole {
            queryItems.append(URLQueryItem(name: "userrole", value: role))
        }
        
        // Add additional query parameters
        if let additionalParams = additionalQueryParameters {
            for (key, value) in additionalParams {
                queryItems.append(URLQueryItem(name: key, value: value))
            }
        }
        
        return queryItems
    }
    
    open override func shouldCacheResponse() -> Bool {
        return true
    }
    
    // MARK: - Factory Method
    
    open override class func request(with dictionary: [String: Any]) -> MSIDAutomationBaseApiRequest? {
        let request = MSIDTestAutomationAccountConfigurationRequest()
        
        if let mfa = dictionary["mfa"] as? String {
            request.mfaType = mfa
        }
        
        if let userType = dictionary["usertype"] as? String {
            request.accountType = userType
        }
        
        if let protectionPolicy = dictionary["protectionpolicy"] as? String {
            request.protectionPolicyType = protectionPolicy
        }
        
        if let b2cProvider = dictionary["b2cprovider"] as? String {
            request.b2cProviderType = b2cProvider
        }
        
        if let federationProvider = dictionary["federationprovider"] as? String {
            request.federationProviderType = federationProvider
        }
        
        if let environment = dictionary["azureenvironment"] as? String {
            request.environmentType = environment
        }
        
        if let role = dictionary["userrole"] as? String {
            request.userRole = role
        }
        
        return request
    }
}
