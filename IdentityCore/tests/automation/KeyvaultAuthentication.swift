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

public class KeyvaultAuthentication : NSObject {

    private var certificateContents : String
    private var certificateData : Data
    private var certificatePassword : String
    private let clientId = "b71232ea-9ba1-4974-b9a6-e4682dd0ab6c"

    @objc public init?(certContents: String, certPassword: String) {

        self.certificateContents = certContents
        self.certificatePassword = certPassword

        guard let certData = Data(base64Encoded: certContents) else {
            print("Couldn't fetch certificate data, make sure certificate path is correct")
            return nil
        }

        self.certificateData = certData

        super.init()
        self.setupKeyvaultCallback()
    }

    private func setupKeyvaultCallback() {

        Authentication.authCallback = { (authority, resource, callback) in

            MSIDClientCredentialHelper.getAccessToken(forAuthority: authority, resource: resource, clientId: self.clientId, certificate: self.certificateData, certificatePassword: self.certificatePassword, completionHandler: { (optionalAccessToken, error) in

                guard let accessToken = optionalAccessToken else {
                    print("Got an error, can't continue \(String(describing: error))")
                    callback(.Failure(error!))
                    return
                }

                print("Successfully received an access token, returning the keyvault callback")

                DispatchQueue.global().async {
                    callback(.Success(accessToken))
                }
            })

        }
    }
    
}
