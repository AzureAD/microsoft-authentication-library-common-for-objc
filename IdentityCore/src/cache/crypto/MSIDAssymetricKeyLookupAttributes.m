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

- (NSDictionary *)assymetricKeyPairAttributes
{
    NSMutableDictionary *keyPairAttr = [NSMutableDictionary new];
    keyPairAttr[(__bridge id)kSecAttrIsPermanent] = @YES;
    keyPairAttr[(__bridge id)kSecAttrKeyType] = (__bridge id)kSecAttrKeyTypeRSA;
    keyPairAttr[(__bridge id)kSecAttrKeySizeInBits] = @2048;
    keyPairAttr[(__bridge id)kSecAttrLabel] = self.keyDisplayableLabel;
    keyPairAttr[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    
    NSMutableDictionary *privateKeyAttr = [NSMutableDictionary new];
    privateKeyAttr[(__bridge id)kSecAttrApplicationTag] = [self.privateKeyIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    privateKeyAttr[(__bridge id)kSecAttrIsSensitive] = @YES;
    privateKeyAttr[(__bridge id)kSecAttrIsExtractable] = @NO;

    NSMutableDictionary *publicKeyAttr = [NSMutableDictionary new];
    publicKeyAttr[(__bridge id)kSecAttrApplicationTag] = [self.publicKeyIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    publicKeyAttr[(__bridge id)kSecAttrIsExtractable] = @YES;
    
    keyPairAttr[(__bridge id)kSecPrivateKeyAttrs] = privateKeyAttr;
    keyPairAttr[(__bridge id)kSecPublicKeyAttrs] = publicKeyAttr;
    
    return keyPairAttr;
}

- (NSDictionary *)privateKeyAttributes
{
    NSMutableDictionary *keyAttr = [NSMutableDictionary new];
    keyAttr[(__bridge id)kSecAttrApplicationTag] = [self.privateKeyIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    keyAttr[(__bridge id)kSecClass] = (__bridge id)kSecClassKey;
    keyAttr[(__bridge id)kSecAttrKeyType] = (__bridge id)kSecAttrKeyTypeRSA;
    return keyAttr;
}

- (NSDictionary *)publicKeyAttributes
{
    NSMutableDictionary *keyAttr = [NSMutableDictionary new];
    keyAttr[(__bridge id)kSecAttrApplicationTag] = [self.publicKeyIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    keyAttr[(__bridge id)kSecClass] = (__bridge id)kSecClassKey;
    keyAttr[(__bridge id)kSecAttrKeyType] = (__bridge id)kSecAttrKeyTypeRSA;
    return keyAttr;
}

@end
