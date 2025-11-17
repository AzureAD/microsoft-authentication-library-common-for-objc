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

/// Modern Swift implementation with Objective-C compatibility
/// Uses @objcMembers to automatically expose all members to Objective-C
@objcMembers open class MSIDAutomationBaseApiRequest: NSObject {
    
    // MARK: - Initialization
    
    public required override init() {
        super.init()
    }
    
    // MARK: - NSCopying
    
    /// Creates a copy of this request
    /// Override this in subclasses to copy specific properties
    /// Note: Returns 'Any' for Objective-C compatibility, but creates correct type
    open func copy(with zone: NSZone? = nil) -> Any {
        let request = type(of: self).init()
        return request
    }
    
    // MARK: - MSIDTestAutomationRequest
    
    open func requestURL(withAPIPath apiPath: String) -> URL? {
        guard let requestOperationPath = requestOperationPath() else {
            return nil
        }
        
        let fullAPIPath = (apiPath as NSString).appendingPathComponent(requestOperationPath)
        guard var components = URLComponents(string: fullAPIPath) else {
            return nil
        }
        
        guard let extraQueryItems = queryItems() else {
            return nil
        }
        
        components.queryItems = extraQueryItems
        return components.url
    }
    
    open func requestURL(withAPIPath apiPath: String, functionCode: String?) -> URL? {
        guard let requestOperationPath = requestOperationPath() else {
            return nil
        }
        
        let fullAPIPath = (apiPath as NSString).appendingPathComponent(requestOperationPath)
        guard var components = URLComponents(string: fullAPIPath) else {
            return nil
        }
        
        var queryItems = [URLQueryItem]()
        
        // Add the function code as a query parameter
        if let functionCode = functionCode {
            queryItems.append(URLQueryItem(name: "code", value: functionCode))
        }
        
        // Add the request-specific query items
        guard let extraQueryItems = self.queryItems() else {
            return nil
        }
        
        queryItems.append(contentsOf: extraQueryItems)
        components.queryItems = queryItems
        return components.url
    }
    
    open func functionAppCodeKey() -> String? {
        // Default implementation returns nil - override in subclasses that use function apps
        return nil
    }
    
    // MARK: - Abstract Methods
    
    open func requestOperationPath() -> String? {
        assertionFailure("Abstract method, implement in subclasses")
        return nil
    }
    
    open func queryItems() -> [URLQueryItem]? {
        assertionFailure("Abstract method, implement in subclasses")
        return nil
    }
    
    open func httpMethod() -> String {
        return "GET"
    }
    
    open class func request(with dictionary: [String: Any]) -> MSIDAutomationBaseApiRequest? {
        assertionFailure("Abstract method, implement in subclasses")
        return nil
    }
    
    open func shouldCacheResponse() -> Bool {
        return false
    }
    
    // MARK: - Equality (Swift)
    
    public static func == (lhs: MSIDAutomationBaseApiRequest, rhs: MSIDAutomationBaseApiRequest) -> Bool {
        return lhs.requestOperationPath() == rhs.requestOperationPath() &&
               lhs.queryItems() == rhs.queryItems()
    }
    
    // MARK: - Equality (Objective-C)
    
    open func isEqual(to request: MSIDAutomationBaseApiRequest) -> Bool {
        return self == request
    }
    
    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? MSIDAutomationBaseApiRequest else {
            return false
        }
        return self == other
    }
    
    // MARK: - Hashing
    
    open override var hash: Int {
        var hasher = Hasher()
        hasher.combine(requestOperationPath())
        hasher.combine(queryItems())
        return hasher.finalize()
    }
}

