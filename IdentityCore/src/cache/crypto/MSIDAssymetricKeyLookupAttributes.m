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

#import "MSIDAssymetricKeyLookupAttributes.h"

@implementation MSIDAssymetricKeyLookupAttributes

/*
 This particular query generates the asymmetric key pair but only saves the private key in the keychain.
 Please refer to https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/generating_new_cryptographic_keys?language=objc
 */
- (NSDictionary *)assymetricKeyPairAttributes
{
    NSData *tag = [self.privateKeyIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* attributes =
        @{ (id)kSecAttrKeyType:               (id)kSecAttrKeyTypeRSA,
           (id)kSecAttrKeySizeInBits:         @2048,
           (id)kSecAttrLabel:self.keyDisplayableLabel,
           (id)kSecPrivateKeyAttrs:
               @{ (id)kSecAttrIsPermanent:    @YES,
                  (id)kSecAttrApplicationTag: tag,
                  (id)kSecAttrAccessible:(id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                  (id)kSecAttrIsExtractable:@NO,
                  (id)kSecAttrIsSensitive:@YES
                  },
         };
    
    return attributes;
}

/*
This particular query only queries the private key from the keychain and uses
SecKeyCopyPublicKey(privateKey) to query the corresponding the public key.
*/
- (NSDictionary *)privateKeyAttributes
{
    NSDictionary *getQuery = @{ (id)kSecClass: (id)kSecClassKey,
                                (id)kSecAttrApplicationTag: [self.privateKeyIdentifier dataUsingEncoding:NSUTF8StringEncoding],
                                (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
                                (id)kSecReturnRef: @YES,
                                (id)kSecReturnAttributes: @YES,
    };
    
    return getQuery;
}

@end
