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

/// Response handler for temporary account creation that extracts the account from the "success" array
@objcMembers open class MSIDAutomationTemporaryAccountResponseHandler: NSObject, MSIDAutomationOperationAPIResponseHandler {
    
    // MARK: - MSIDAutomationOperationAPIResponseHandler
    
    /// Parses temporary account response and returns the created account
    /// - Parameters:
    ///   - data: The JSON response data containing the account in a "success" array
    ///   - error: Error pointer for any parsing errors
    /// - Returns: MSIDTestAutomationAccount if successful, nil otherwise
    public func response(from data: Data, error: NSErrorPointer) -> Any? {
        // Parse JSON data
        let jsonDictionary: [String: Any]
        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                error?.pointee = NSError(domain: "MSIDAutomation",
                                        code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Response is not a valid JSON dictionary"])
                return nil
            }
            jsonDictionary = json
        } catch let jsonError as NSError {
            error?.pointee = jsonError
            return nil
        }
        
        // Extract accounts array from "success" key
        guard let accountsArray = jsonDictionary["success"] as? [[AnyHashable: Any]],
              !accountsArray.isEmpty else {
            error?.pointee = NSError(domain: "MSIDAutomation",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "No accounts found in 'success' array"])
            return nil
        }
        
        // Create test account from first item in array
        do {
            let testAccount = try MSIDTestAutomationAccount(jsonDictionary: accountsArray[0])
            // Clear password as it's not provided in temporary account response
            testAccount.password = nil
            return testAccount
        } catch let accountError as NSError {
            error?.pointee = accountError
            return nil
        }
    }
}
