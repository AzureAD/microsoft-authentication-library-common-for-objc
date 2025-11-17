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

// MARK: - Account Type Enum

/**
 Temporary account types for testing:
 
 - basic: Account can be used for all manual testing including password resets, etc
 - globalMFA: User with Global MFA
 - mfaOnSPO: User requires MFA on a specific resource and the resource is SharePoint
 - mfaOnEXO: User requires MFA on a specific resource and the resource is Exchange Online
 - mamCA: User requires MAM on SharePoint
 - mdmCA: User requires MDM on SharePoint
 */
@objc public enum MSIDAutomationTemporaryAccountType: Int {
    case basic = 0
    case globalMFA
    case mfaOnSPO
    case mfaOnEXO
    case mamCA
    case mdmCA
    
    /// Returns the string representation for API requests
    var stringValue: String? {
        switch self {
        case .basic:
            return "Basic"
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

@objcMembers open class MSIDAutomationTemporaryAccountRequest: MSIDAutomationBaseApiRequest {
    
    // MARK: - Properties
    
    public var accountType: MSIDAutomationTemporaryAccountType = .basic
    
    // MARK: - Initialization
    
    public required init() {
        super.init()
    }
    
    // MARK: - NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any {
        let request = super.copy(with: zone) as! MSIDAutomationTemporaryAccountRequest
        request.accountType = accountType
        return request
    }
    
    // MARK: - Base Request Override
    
    open override func functionAppCodeKey() -> String? {
        return "create_user_api_code"
    }
    
    open override func requestOperationPath() -> String? {
        return "CreateTempUser"
    }
    
    open override func queryItems() -> [URLQueryItem]? {
        guard let accountTypeString = accountType.stringValue else {
            return nil
        }
        
        return [URLQueryItem(name: "usertype", value: accountTypeString)]
    }
    
    open override func httpMethod() -> String {
        return "POST"
    }
}
