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

// MARK: - Policy Type Enum

/**
 Automation policy types for testing:
 
 - globalMFA: Global MFA policy
 - mfaOnSPO: MFA on SharePoint Online
 - mfaOnEXO: MFA on Exchange Online
 - mamCA: MAM Conditional Access policy
 - mdmCA: MDM Conditional Access policy
 */
@objc public enum MSIDAutomationPolicyType: Int {
    case globalMFA = 0
    case mfaOnSPO
    case mfaOnEXO
    case mamCA
    case mdmCA
    
    /// Returns the string representation for API requests
    var stringValue: String? {
        switch self {
        case .globalMFA:
            return "GLOBALMFA"
        case .mfaOnSPO:
            return "MFAONSPO"
        case .mfaOnEXO:
            return "MFAONEXO"
        case .mamCA:
            return "MAMCA"
        case .mdmCA:
            return "MDMCA"
        }
    }
}

// MARK: - Main Class

/// Request for enabling or disabling policies in the lab
@objcMembers open class MSIDAutomationPolicyToggleAPIRequest: MSIDAutomationBaseApiRequest {
    
    // MARK: - Properties
    
    /// The automation policy type to toggle
    public var automationPolicy: MSIDAutomationPolicyType = .globalMFA
    
    /// User Principal Name for the account
    public var upn: String?
    
    /// Whether the policy should be enabled (true) or disabled (false)
    public var policyEnabled: Bool = false
    
    // MARK: - Initialization
    
    public required init() {
        super.init()
    }
    
    // MARK: - NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any {
        let request = super.copy(with: zone) as! MSIDAutomationPolicyToggleAPIRequest
        request.automationPolicy = automationPolicy
        request.upn = upn
        request.policyEnabled = policyEnabled
        return request
    }
    
    // MARK: - Base Request Override
    
    open override func functionAppCodeKey() -> String? {
        return policyEnabled ? "enable_policy_api_code" : "disable_policy_api_code"
    }
    
    open override func requestOperationPath() -> String? {
        return policyEnabled ? "EnablePolicy" : "DisablePolicy"
    }
    
    open override func httpMethod() -> String {
        return "POST"
    }
    
    open override func queryItems() -> [URLQueryItem]? {
        guard let policyTypeString = automationPolicy.stringValue else {
            return nil
        }
        
        var queryItems = [
            URLQueryItem(name: "policy", value: policyTypeString)
        ]
        
        if let upn = upn {
            queryItems.append(URLQueryItem(name: "upn", value: upn))
        }
        
        return queryItems
    }
}
