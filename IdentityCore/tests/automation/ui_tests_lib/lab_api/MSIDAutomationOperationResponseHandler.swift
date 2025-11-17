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

/// Response handler that deserializes JSON data into objects conforming to MSIDJsonSerializable
@objcMembers open class MSIDAutomationOperationResponseHandler: NSObject, MSIDAutomationOperationAPIResponseHandler {
    
    // MARK: - Properties
    
    /// The class type that will be used to deserialize the response
    private let className: MSIDJsonSerializable.Type
    
    // MARK: - Initialization
    
    /// Initialize with a class that conforms to MSIDJsonSerializable protocol
    /// - Parameter className: The class type to use for deserialization
    /// - Returns: Initialized instance or nil if the class doesn't conform to MSIDJsonSerializable
    public init?(className: MSIDJsonSerializable.Type) {
        self.className = className
        super.init()
    }
    
    // MARK: - MSIDAutomationOperationAPIResponseHandler
    
    /// Deserializes JSON data into an array of objects
    /// - Parameters:
    ///   - response: The JSON data to deserialize
    ///   - error: Error pointer for any deserialization errors
    /// - Returns: Array of deserialized objects, or nil if deserialization fails
    public func response(from data: Data, error: NSErrorPointer) -> Any? {
        // Parse JSON data
        let jsonResponse: Any
        do {
            jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
        } catch let jsonError as NSError {
            error?.pointee = jsonError
            return nil
        }
        
        var resultArray = [Any]()
        
        // Handle single dictionary response
        if let responseDict = jsonResponse as? [String: Any] {
            do {
                let result = try className.init(jsonDictionary: responseDict)
                resultArray.append(result)
            } catch let deserializationError as NSError {
                error?.pointee = deserializationError
            }
        }
        
        // Handle array of dictionaries response
        if let responseArray = jsonResponse as? [[String: Any]] {
            for responseDict in responseArray {
                // Assert if there are errors in the response
                if let resultValue = responseDict["result"] as? String,
                   resultValue == "Errors" {
                    if let message = responseDict["message"] as? String {
                        assertionFailure(message)
                    } else {
                        assertionFailure("Error result received from API")
                    }
                }
                
                do {
                    let result = try className.init(jsonDictionary: responseDict)
                    resultArray.append(result)
                } catch let deserializationError as NSError {
                    error?.pointee = deserializationError
                }
            }
        }
        
        return resultArray
    }
}
