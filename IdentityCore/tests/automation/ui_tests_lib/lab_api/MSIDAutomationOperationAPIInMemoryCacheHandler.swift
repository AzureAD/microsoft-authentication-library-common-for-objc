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

/// In-memory cache handler for Lab API responses
@objcMembers open class MSIDAutomationOperationAPIInMemoryCacheHandler: NSObject, MSIDAutomationOperationAPICacheHandler {
    
    // MARK: - Properties
    
    private let cache: MSIDCache<NSObject, AnyObject>
    
    // MARK: - Initialization
    
    /// Initialize with a dictionary of cached values
    /// - Parameter cachedDictionary: Dictionary containing pre-cached key-value pairs
    public init(dictionary cachedDictionary: [AnyHashable: Any]) {
        cache = MSIDCache<NSObject, AnyObject>()
        super.init()
        
        // Populate cache with initial values
        for (key, value) in cachedDictionary {
            if let objectKey = key.base as? NSObject,
               let objectValue = value as AnyObject? {
                cache.setObject(objectValue, forKey: objectKey)
            }
        }
    }
    
    // MARK: - MSIDAutomationOperationAPICacheHandler
    
    /// Retrieve a cached response for a given request
    /// - Parameter request: The request to look up in the cache
    /// - Returns: Cached response if found, nil otherwise
    public func cachedResponse(for request: Any) -> Any? {
        guard let objectRequest = request as? NSObject else {
            return nil
        }
        return cache.object(forKey: objectRequest)
    }
    
    /// Cache a response for a given request
    /// - Parameters:
    ///   - response: The response to cache
    ///   - request: The request to use as the cache key
    public func cacheResponse(_ response: Any, for request: Any) {
        guard let objectRequest = request as? NSObject,
              let objectResponse = response as AnyObject? else {
            return
        }
        cache.setObject(objectResponse, forKey: objectRequest)
    }
}
