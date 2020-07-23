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
    let symmetericKeyString = "Zfb98mJBAt/UOpnCI/CYdQ=="
    let message = "Sample Message To Encrypt/Decrypt"
    let iv = "4JYp0efd0Wxokdl3";
    let authDataBase64 = "eyJhbGciOiJkaXIiLCJlbmMiOiJBMjU2R0NNIiwiY3R4IjoieTAwc0lLUmNGMmJQRkRnYmVPcXVlczBZUG1CK1IwRlAifQ";
    
    func testEncryptAndDecrypt() throws {
        let symmetericKeyBytes = NSData.init(base64Encoded: symmetericKeyString, options: NSData.Base64DecodingOptions.init(rawValue: 0))!
        let aesGcm = MSIDAesGcm.create(symmetericKeyInBytes: symmetericKeyBytes)
        XCTAssertNotNil(aesGcm);
        
        let messageData = message.data(using: .utf8)! as NSData
        let ivData = try! self.msidDataFromBase64UrlEncodedString(encodedString: iv as NSString)
        let authData = try! self.msidDataFromBase64UrlEncodedString(encodedString: authDataBase64 as NSString)
        let aesGcmInfo = aesGcm.encryptUsingAuthenticatedAesForTest(message: messageData, iv: ivData, authenticationData: authData)
        XCTAssertNotNil(aesGcmInfo)
        
        let decryptedMessage = aesGcm.decryptUsingAuthenticatedAes(cipherText: aesGcmInfo.cipherText, iv: ivData, authenticationTag: aesGcmInfo.authTag, authenticationData: authData)
        XCTAssertEqual(message as NSString, decryptedMessage)
    }
    
    func msidDataFromBase64UrlEncodedString(encodedString: NSString) throws -> NSData
    {
        let base64encoded = encodedString.replacingOccurrences(of: "-", with:"+").replacingOccurrences(of:"_", with:"/")
        
        // The input string lacks the usual '=' padding at the end, so the valid end sequences
        // are:
        //      ........XX           (cbEncodedSize % 4) == 2    (2 chars of virtual padding)
        //      ........XXX          (cbEncodedSize % 4) == 3    (1 char of virtual padding)
        //      ........XXXX         (cbEncodedSize % 4) == 0    (no virtual padding)
        // Invalid sequences are:
        //      ........X            (cbEncodedSize % 4) == 1
        
        // Input string is not sized correctly to be base64 URL encoded.
        
        let stringMod4 = base64encoded.count % 4
        
        if (stringMod4 == 1)
        {
            return NSData.init()
        }
        
        if (stringMod4 == 0)// No Padding necessary
        {
            return NSData.init(base64Encoded: base64encoded, options: NSData.Base64DecodingOptions.init(rawValue: 0))!
        }
        
        // 'virtual padding'
        let padding = 4 - stringMod4
        let paddedLength = base64encoded.count + padding
        let paddedString = base64encoded.padding(toLength: paddedLength, withPad: "=", startingAt: 0)
        
        return NSData.init(base64Encoded: paddedString, options: NSData.Base64DecodingOptions.init(rawValue: 0))!
    }
}
