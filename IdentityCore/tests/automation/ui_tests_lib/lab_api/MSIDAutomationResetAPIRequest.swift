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

/// Request for resetting user account state in the lab
@objcMembers open class MSIDAutomationResetAPIRequest: MSIDAutomationBaseApiRequest {
    
    // MARK: - Properties
    
    /// The API operation to perform (e.g., "password", "mfa")
    public var apiOperation: String?
    
    /// User Principal Name for the account to reset
    public var userUPN: String?
    
    // MARK: - Initialization
    
    public required init() {
        super.init()
    }
    
    // MARK: - NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any {
        let request = super.copy(with: zone) as! MSIDAutomationResetAPIRequest
        request.apiOperation = apiOperation
        request.userUPN = userUPN
        return request
    }
    
    // MARK: - Base Request Override
    
    open override func functionAppCodeKey() -> String? {
        return "reset_api_code"
    }
    
    open override func requestOperationPath() -> String? {
        return "Reset"
    }
    
    open override func httpMethod() -> String {
        return "POST"
    }
    
    open override func queryItems() -> [URLQueryItem]? {
        var queryItems = [URLQueryItem]()
        
        if let operation = apiOperation {
            queryItems.append(URLQueryItem(name: "operation", value: operation))
        }
        
        if let upn = userUPN {
            queryItems.append(URLQueryItem(name: "upn", value: upn))
        }
        
        return queryItems
    }
}
