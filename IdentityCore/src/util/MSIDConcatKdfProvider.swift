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
import CommonCrypto
import CryptoKit

public class MSIDConcatKdfProvider: NSObject {
    
    internal func intToData<T>(value: T) -> Data where T: FixedWidthInteger {
        var int = value
        return Data(bytes: &int, count: MemoryLayout<T>.size)
    }
    
    enum ConcatKDFError: Error {
        case emptyOutputKeyLen
        case emptyInputParameter(parameterName: String)
        case unsupportedKeySize
    }
    
    private func checkParameterIsPresent(param : Data, paramName : String) throws {
        if param.count == 0 {
            throw ConcatKDFError.emptyInputParameter(parameterName: paramName)
        }
    }
    
    /*
     RFC 7518 Section 4.6.2 and NIST.800-56A sections 5.8.1 and 6.2.2.2 are used to configure Concat KDF for Platform SSO. The inputs are defined in the table below. The values are concatenated per NIST.800-56A sections 5.8.1 and then a SHA-256 hash is computed to create the key. The PartyUInfo is returned to the client in the header.
     
     * AlgorithmID - Set to the octets of the ASCII representation of the enc (algorithm) Header Parameter value.
     * PartyUInfo - <prefix bytes length>||<prefix bytes>||<epk bytes length>||<epk bytes>
     * PartyVInfo - This MUST use the jwe_crypto.apv value from the PRT request. <prefix bytes length>||<prefix bytes>||<stk public key
     bytes length>||<stk public key bytes>||<ASCII encoded nonce bytes length>||<ASCII encoded noncebytes>
     * SuppPubInfo - “This is set to the number of bits in the desired output key.”
     * SuppPrivInfo - NULL, not used
     
     NIST spec: https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-56Ar2.pdf
     
     Note that this is not a generic ConcatKDF implementation. This function is specifically optimized for the values used in PRTv4 ECC protocol.
     If there's a need to reuse this for other purposes, this code might need to be changed to address more complex scenarios (e.g. using another  values to calculate concatenatedData or dealing with non-standard key sizes)
     */
    @objc public func concatKDFWithSHA256(
        sharedSecret: Data,
        outputKeyLen: Int,
        algorithmId: Data,
        partyUInfo: Data,
        partyVInfo: Data
    ) throws -> Data {
        
        if outputKeyLen == 0 {
            throw ConcatKDFError.emptyOutputKeyLen
        }
        
        try checkParameterIsPresent(param: sharedSecret, paramName: "sharedSecret")
        try checkParameterIsPresent(param: algorithmId, paramName: "algorithmId")
        try checkParameterIsPresent(param: partyUInfo, paramName: "partyUInfo")
        try checkParameterIsPresent(param: partyVInfo, paramName: "partyVInfo")
        
        let modLen = outputKeyLen % SHA256Digest.byteCount
        
        // Concat KDF does support non-multiple key sizes, but we don't need them for our purposes, so simplifying the code
        if (modLen != 0) {
            throw ConcatKDFError.unsupportedKeySize
        }
        
        let reps = (outputKeyLen / SHA256Digest.byteCount) + (modLen > 0 ? 1 : 0)
        
        let concatedData =  sharedSecret
                            + intToData(value: UInt32(algorithmId.count).bigEndian) + algorithmId
                            + intToData(value: UInt32(partyUInfo.count).bigEndian) + partyUInfo
                            + intToData(value: UInt32(partyVInfo.count).bigEndian) + partyVInfo
                            + intToData(value: UInt32(outputKeyLen * 8).bigEndian) // we multiply outputKeyLen by 8 because it's in bytes, and this should represent key length in bits
        
        var derivedKeyingMaterial = Data()
        for i in 1 ..< reps {
            derivedKeyingMaterial += CryptoKit.SHA256.hash(data: intToData(value: UInt32(i).bigEndian) + concatedData)
        }
        
        derivedKeyingMaterial += CryptoKit.SHA256.hash(data: intToData(value: UInt32(reps).bigEndian) + concatedData)
        return derivedKeyingMaterial
    }
}
