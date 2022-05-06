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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "MSIDTestSecureEnclaveKeyPairGenerator.h"

@interface MSIDTestSecureEnclaveKeyPairGenerator()
    @property (readwrite, assign, nonatomic) SecKeyRef eccPrivateKey;
    @property (readwrite, assign, nonatomic) SecKeyRef eccPublicKey;
@end

@implementation MSIDTestSecureEnclaveKeyPairGenerator : NSObject

const static NSString *kTestApplicationTag = @"Microsoft ECC Test App";

- (void)generateKeyPair
{
    NSString *prefix = @"";
#if TARGET_OS_IPHONE
    prefix = @"UBF8T346G9";
#else
    prefix = @"SGGM6D27TK";
#endif
    NSString *sharedAccessGroup = [NSString stringWithFormat:@"%@.%@", prefix, @"com.microsoft.MSIDTestsHostApp"]; // Using SGGM6D27TK as prefix for complete shared group
    if (!_eccPublicKey)
    {
        SecAccessControlRef access = NULL;
        if (@available(macOS 10.12.1, iOS 9.0, *))
        {
            access = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                     kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                     kSecAccessControlPrivateKeyUsage,
                                                     NULL);
        }
        
        NSData *tag = [kTestApplicationTag dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary* attributes =
          @{ (id)kSecAttrKeyType:(id)kSecAttrKeyTypeECSECPrimeRandom,
             (id)kSecAttrKeySizeInBits:@256,
             (id)kSecAttrTokenID:(id)kSecAttrTokenIDSecureEnclave,
             (id)kSecPrivateKeyAttrs:
                 @{
                     (id)kSecAttrIsPermanent:@YES,
                     (id)kSecAttrApplicationTag:tag,
                     (id)kSecAttrAccessGroup:sharedAccessGroup,
                     (id)kSecAttrAccessControl:(__bridge id)access,
                     (id)kSecAttrCanEncrypt:@NO
                 }
           };
        CFRelease(access);
        CFErrorRef error = NULL;
        SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes,
                                                     &error);
        if (!privateKey) {
            NSError *err = CFBridgingRelease(error);
            XCTAssertNotNil(err);
            err = nil;
            return;
        }
        XCTAssertTrue(error == NULL);
        self.eccPrivateKey = privateKey;
        self.eccPublicKey =  SecKeyCopyPublicKey(privateKey);
    }
}

- (SecKeyRef)eccPublicKey
{
    if (!_eccPublicKey)
    {
        [self generateKeyPair];
    }
    return _eccPublicKey;
}

- (SecKeyRef)eccPrivateKey
{
    if (!_eccPrivateKey)
    {
        [self generateKeyPair];
    }
    return _eccPrivateKey;
}

- (void)dealloc
{
    if (_eccPublicKey)
    {
        CFRelease(_eccPublicKey);
        _eccPublicKey = NULL;
    }
    if (_eccPrivateKey)
    {
        CFRelease(_eccPrivateKey);
        _eccPrivateKey = NULL;
    }
}
@end

