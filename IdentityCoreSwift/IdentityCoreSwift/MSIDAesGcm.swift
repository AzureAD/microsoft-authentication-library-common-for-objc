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
import CryptoKit

// todo unsure if needed
import LocalAuthentication
import Security.SecAccessControl
import Security


//protocol MSIDSymmetericKeyProtocol {
//    func getDummyString() -> String;
//}

@objc(MSIDAesGcmInfo)
public class MSIDAesGcmInfo : NSObject {
    @objc
    public var cipherText: NSData
    
    @objc
    public var authTag: NSData
    
    public init(cipherText: NSData, authTag: NSData) {
        self.cipherText = cipherText
        self.authTag = authTag
    }
}

@objc(MSIDAesGcm)
public class MSIDAesGcm : NSObject {//MSIDSymmetericKeyProtocol {
    private var symmetericKeyInBytes: NSData;
    private var symmetericKey: SymmetricKey;
    
    @objc
    public init(symmetericKeyInBytes: NSData) {
        self.symmetericKeyInBytes = symmetericKeyInBytes;
        self.symmetericKey = SymmetricKey(data: Data(referencing: self.symmetericKeyInBytes));
    }
    
    @objc
    public class func create(symmetericKeyInBytes: NSData) -> MSIDAesGcm {
        return MSIDAesGcm(symmetericKeyInBytes: symmetericKeyInBytes);
    }

    @objc
    public func encryptUsingAuthenticatedAesForTest(message: NSData, iv: NSData, authenticationData: NSData) -> MSIDAesGcmInfo
    {
        let nonce :AES.GCM.Nonce = try! AES.GCM.Nonce.init(data: iv);
        let result = try! AES.GCM.seal(message, using: self.symmetericKey, nonce: nonce, authenticating: authenticationData);
        return MSIDAesGcmInfo(cipherText: NSData.init(data: result.ciphertext), authTag: NSData.init(data: result.tag))
    }
    
    @objc
    public func decryptUsingAuthenticatedAes(cipherText: NSData, iv: NSData, authenticationTag: NSData, authenticationData: NSData) -> NSString
    {
        do {
            let nonce :AES.GCM.Nonce = try! AES.GCM.Nonce.init(data: iv); //todo convert iv to nonce
            let sealedBox = try AES.GCM.SealedBox.init(nonce: nonce, ciphertext: Data(referencing: cipherText), tag: Data(referencing: authenticationTag))
            let result = try AES.GCM.open(sealedBox, using: self.symmetericKey, authenticating: authenticationData)
            return NSString.init(data: result, encoding: String.Encoding.utf8.rawValue)!
        }
        catch {
            return NSString.init(string: "Unexpected error: \(error).")
        }
//        let codeBytescount = [UInt8](codeBytes).count
//
//        let iv = Array([UInt8](codeBytes)[0 ..< 32])
//        let cipher = Array([UInt8](codeBytes)[iv.count ..< codeBytescount])
//        do{
//            let gcm = GCM(iv: iv, mode: .combined)
//            let derKey = createKey(password:Data(key.utf8), salt: Data(iv))!
//
//            keyBytes = [UInt8](derKey)
//
//            let aes = try AES(key: keyBytes, blockMode: gcm, padding: .pkcs5)
//
//            print("aes created")
//            let decrypted = try aes.decrypt(cipher)
//            print("decrypted completed")
//            if let decryptedString = String(bytes: decrypted, encoding: .utf8) {
//                code = decryptedString
//            }
//
//            debugPrint(code)
//
//        }catch let error as AES.Error {
//            debugPrint(error.localizedDescription)
//            return code
//        } catch {
//            return code
//        }
//        return code
    }
}
