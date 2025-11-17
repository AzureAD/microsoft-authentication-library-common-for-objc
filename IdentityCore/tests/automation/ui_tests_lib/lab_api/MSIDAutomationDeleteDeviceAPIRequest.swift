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

/// Request for deleting a device from the lab
@objcMembers open class MSIDAutomationDeleteDeviceAPIRequest: MSIDAutomationBaseApiRequest {
    
    // MARK: - Properties
    
    /// User Principal Name for the device owner
    public var userUPN: String?
    
    /// Device GUID to delete
    public var deviceGUID: String?
    
    // MARK: - Initialization
    
    public required init() {
        super.init()
    }
    
    // MARK: - NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any {
        let request = super.copy(with: zone) as! MSIDAutomationDeleteDeviceAPIRequest
        request.userUPN = userUPN
        request.deviceGUID = deviceGUID
        return request
    }
    
    // MARK: - Base Request Override
    
    open override func functionAppCodeKey() -> String? {
        return "delete_device_api_code"
    }
    
    open override func requestOperationPath() -> String? {
        return "DeleteDevice"
    }
    
    open override func httpMethod() -> String {
        return "POST"
    }
    
    open override func queryItems() -> [URLQueryItem]? {
        var queryItems = [URLQueryItem]()
        
        if let upn = userUPN {
            queryItems.append(URLQueryItem(name: "upn", value: upn))
        }
        
        if let guid = deviceGUID {
            queryItems.append(URLQueryItem(name: "deviceid", value: guid))
        }
        
        return queryItems
    }
    
    // MARK: - Hashable
    
    open override var hash: Int {
        var hasher = Hasher()
        hasher.combine(userUPN)
        hasher.combine(deviceGUID)
        return hasher.finalize()
    }
}
