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

-(nullable instancetype)initWithSharedAccessGroup:(NSString *)sharedAccessGroup
                                 useSecureEnclave:(BOOL)useSecureEnclave
                                   applicationTag:(NSString *)applicationTag;
@end

@implementation MSIDTestSecureEnclaveKeyPairGenerator : NSObject

const static NSString *kTestApplicationTag = @"Microsoft ECC Test App";

-(instancetype)initWithSharedAccessGroup:(NSString *)sharedAccessGroup
                        useSecureEnclave:(BOOL)useSecureEnclave
                          applicationTag:(NSString *)applicationTag
{
    self = [super init];
    if (self)
    {
        if (sharedAccessGroup)
        {
            _sharedAccessGroup = sharedAccessGroup;
        }
        else
        {
            _sharedAccessGroup = [self getSharedAccessGroup];
        }
        _useSecureEnclave = useSecureEnclave;
        _applicationTag = applicationTag ? applicationTag : kTestApplicationTag;
    }
    return self;
}

- (void)generateKeyPair
{
    NSString *sharedAccessGroup = [self getSharedAccessGroup];
    [self queryKeysForAccessGroup:sharedAccessGroup];
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
        
        NSData *tag = [self.applicationTag dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableDictionary *privateKeyAttrs = [[NSMutableDictionary alloc] initWithDictionary:@{
            (id)kSecAttrAccessGroup:sharedAccessGroup,
            (id)kSecAttrAccessControl:(__bridge id)access,
        }];
        if (sharedAccessGroup)
        {
            [privateKeyAttrs removeObjectForKey:(__bridge id)kSecAttrAccessControl];
        }
        NSMutableDictionary* attributes = [[NSMutableDictionary alloc] initWithDictionary:
          @{ (id)kSecAttrKeyType:(id)kSecAttrKeyTypeECSECPrimeRandom,
             (id)kSecAttrKeySizeInBits:@256,
             (id)kSecAttrTokenID:(id)kSecAttrTokenIDSecureEnclave,
             (id)kSecAttrApplicationTag:tag,
             (id)kSecPrivateKeyAttrs:privateKeyAttrs
           }];
        if (@available(macOS 10.15, *))
        {
            [attributes setObject:@YES forKey:(__bridge id)kSecUseDataProtectionKeychain];
        }
        CFRelease(access);
        if (!self.useSecureEnclave)
        {
            [attributes removeObjectForKey:(id)kSecAttrTokenID];
        }
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
        [self queryKeysForAccessGroup:sharedAccessGroup];
        
        
        self.eccPrivateKey = privateKey;
        self.eccPublicKey =  SecKeyCopyPublicKey(privateKey);
    }
}

- (void)queryKeysForAccessGroup:(NSString *)accessGroup
{
    OSStatus status = errSecItemNotFound;
    CFTypeRef privateKeyCFDict = NULL;
    NSDictionary *queryDict = [self keyDictionary];
    status = SecItemCopyMatching((__bridge CFDictionaryRef)queryDict, (CFTypeRef*)&privateKeyCFDict); // +1 privateKeyCFDict
    if (status != errSecSuccess)
    {
        return;
    }
    
    NSDictionary *privateKeyDict = CFBridgingRelease(privateKeyCFDict); // -1 privateKeyCFDict
    self.eccPrivateKey =  (__bridge SecKeyRef)(privateKeyDict[(__bridge id)kSecValueRef]);
    CFRetain(_eccPrivateKey);
    self.eccPublicKey  =  SecKeyCopyPublicKey(_eccPrivateKey);
}

- (void)deleteKeysForAccessGroup:(NSString *)accessGroup
{
    OSStatus status = errSecItemNotFound;
    status = SecItemDelete((__bridge CFDictionaryRef) [self keyDictionary]);
    if (status != errSecSuccess)
    {
        return;
    }
}

- (NSString *)getSharedAccessGroup
{
    if (_sharedAccessGroup)
    {
        return _sharedAccessGroup;
    }
    NSString *prefix = @"";
#if TARGET_OS_IPHONE
    prefix = @"UBF8T346G9";
#else
    prefix = @"SGGM6D27TK";
#endif
    return [NSString stringWithFormat:@"%@.%@", prefix, @"com.microsoft.MSIDTestsHostApp"]; // Using SGGM6D27TK as prefix for complete shared group
}

- (NSDictionary *)keyDictionary
{
    NSMutableDictionary *queryPrivateKey = [NSMutableDictionary new];
    queryPrivateKey[(__bridge id)kSecAttrApplicationTag] = [self.applicationTag dataUsingEncoding:NSUTF8StringEncoding];
    queryPrivateKey[(__bridge id)kSecClass] = (__bridge id)kSecClassKey;
    queryPrivateKey[(__bridge id)kSecReturnAttributes] = @YES;
    queryPrivateKey[(__bridge id)kSecReturnRef] = @YES;
    if (self.useSecureEnclave)
    {
        queryPrivateKey[(__bridge id)kSecAttrTokenID] = (__bridge id)kSecAttrTokenIDSecureEnclave;
    }
#if TARGET_OS_OSX
        if (@available(macOS 10.15, *))
        [queryPrivateKey setObject:@YES forKey:(__bridge id)kSecUseDataProtectionKeychain];
#endif
    queryPrivateKey[(__bridge id)kSecAttrKeyType] = (__bridge id)kSecAttrKeyTypeECSECPrimeRandom;
    queryPrivateKey[(__bridge id)kSecAttrKeySizeInBits] = @256;
    queryPrivateKey[(__bridge id)kSecAttrAccessGroup] = [self getSharedAccessGroup];
    
    return queryPrivateKey;
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

