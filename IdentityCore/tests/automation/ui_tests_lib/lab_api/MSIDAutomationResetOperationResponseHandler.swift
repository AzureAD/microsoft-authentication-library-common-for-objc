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

/// Response handler for reset operations that checks for "successful" string in response
@objcMembers open class MSIDAutomationResetOperationResponseHandler: NSObject, MSIDAutomationOperationAPIResponseHandler {
    
    // MARK: - MSIDAutomationOperationAPIResponseHandler
    
    /// Parses the response data and checks if the operation was successful
    /// - Parameters:
    ///   - data: The response data containing operation result
    ///   - error: Error pointer for any parsing errors
    /// - Returns: NSNumber(1) if successful, nil otherwise
    public func response(from data: Data, error: NSErrorPointer) -> Any? {
        // Convert data to string
        guard let responseString = String(data: data, encoding: .utf8) else {
            error?.pointee = NSError(domain: "MSIDAutomation",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Unable to decode response as UTF-8"])
            return nil
        }
        
        // TODO: ask lab to return operation success in a more reasonable way
        let operationSuccessful = responseString.contains("successful")
        
        if !operationSuccessful {
            error?.pointee = NSError(domain: "MSIDAutomation",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Operation was not successful"])
            return nil
        }
        
        return NSNumber(value: 1)
    }
}
