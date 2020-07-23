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


import XCTest
@testable import IdentityCoreSwift

class IdentityCoreSwiftTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let symmetericKeyString = "Zfb98mJBAt/UOpnCI/CYdQ==";
        let symmetericKeyBytes = NSData.init(base64Encoded: symmetericKeyString, options: NSData.Base64DecodingOptions.init(rawValue: 0))!
        let aesGcm = MSIDAesGcm.create(symmetericKeyInBytes: symmetericKeyBytes)
        XCTAssertNotNil(aesGcm);
        
        // let message = "sample message to encrypt";
        let iv = "4JYp0efd0Wxokdl3";
        let authTag = "tPYZ8VzB2CBWYToUZmg5PQ";
        let authData = "eyJhbGciOiJkaXIiLCJlbmMiOiJBMjU2R0NNIiwiY3R4IjoieTAwc0lLUmNGMmJQRkRnYmVPcXVlczBZUG1CK1IwRlAifQ";
        
        let messageData = NSData.init(base64Encoded: iv, options: NSData.Base64DecodingOptions.init(rawValue: 0))!
        let ivData = NSData.init(base64Encoded: iv, options: NSData.Base64DecodingOptions.init(rawValue: 0))!
        let authTagData = NSData.init(base64Encoded: authTag, options: NSData.Base64DecodingOptions.init(rawValue: 0))!
        let authDataData = NSData.init(base64Encoded: authData, options: NSData.Base64DecodingOptions.init(rawValue: 0))!
        
        let cipherText = aesGcm.encryptUsingAuthenticatedAesForTest(message: messageData, iv: ivData, authenticationTag: authTagData, authenticationData: authDataData)
        XCTAssertNotNil(cipherText);
        
        let decryptedMessage = aesGcm.decryptUsingAuthenticatedAes(cipherText: cipherText, iv: ivData, authenticationTag: authTagData, authenticationData: authDataData)
        XCTAssertNotNil(decryptedMessage);
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
