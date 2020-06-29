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

#import "MSIDTestBrokerKeyProviderHelper.h"
#import "MSIDKeychainUtil.h"
#import "MSIDBrokerKeyProvider.h"
#import <CommonCrypto/CommonCryptor.h>
#import <Security/Security.h>

@implementation MSIDTestBrokerKeyProviderHelper

+ (void)addKey:(NSData *)keyData
   accessGroup:(NSString *)accessGroup
applicationTag:(NSString *)applicationTag
{
    NSData *symmetricTag = [applicationTag dataUsingEncoding:NSUTF8StringEncoding];
    [self addKey:keyData accessGroup:accessGroup applicationTagData:symmetricTag];
}

+ (void)addKey:(NSData *)keyData
   accessGroup:(NSString *)accessGroup
applicationTagData:(NSData *)applicationTagData
{
    NSString *keychainGroup = [[MSIDKeychainUtil sharedInstance] accessGroup:accessGroup];
    
    NSDictionary *symmetricKeyAttr =
    @{
      (id)kSecClass : (id)kSecClassKey,
      (id)kSecAttrKeyClass : (id)kSecAttrKeyClassSymmetric,
      (id)kSecAttrApplicationTag : (id)applicationTagData,
      (id)kSecAttrKeyType : @(CSSM_ALGID_AES),
      (id)kSecAttrKeySizeInBits : @(kChosenCipherKeySize << 3),
      (id)kSecAttrEffectiveKeySize : @(kChosenCipherKeySize << 3),
      (id)kSecAttrCanEncrypt : @YES,
      (id)kSecAttrCanDecrypt : @YES,
      (id)kSecValueData : keyData,
      (id)kSecAttrAccessible : (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      (id)kSecAttrAccessGroup : keychainGroup
      };
    
    SecItemAdd((__bridge CFDictionaryRef)symmetricKeyAttr, NULL);
}

@end
