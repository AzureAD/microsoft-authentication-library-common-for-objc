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

/// Handler for loading passwords from KeyVault for test accounts
@objcMembers open class MSIDAutomationPasswordRequestHandler: NSObject {
    
    // MARK: - Public Methods
    
    /// Loads the password for a test account from KeyVault
    /// - Parameters:
    ///   - account: The test automation account
    ///   - completionHandler: Called with the password (or cached password) and any error
    public func loadPassword(for account: MSIDTestAutomationAccount, 
                            completionHandler: @escaping (String?, Error?) -> Void) {
        // If password is already cached, return it immediately
        if let password = account.password {
            completionHandler(password, nil)
            return
        }
        
        // Create URL from keyvault name
        guard let url = URL(string: account.keyvaultName) else {
            let error = NSError(domain: "MSIDAutomationPasswordRequestHandler",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid keyvault URL: \(account.keyvaultName)"])
            completionHandler(nil, error)
            return
        }
        
        // Fetch secret from KeyVault
        Secret.get(url: url) { error, secret in
            // Handle error
            if let error = error {
                completionHandler(nil, error)
                return
            }
            
            // Cache the password in the account
            if let secret = secret {
                account.password = secret.value
            }
            
            // Return the password
            completionHandler(secret?.value, nil)
        }
    }
}
