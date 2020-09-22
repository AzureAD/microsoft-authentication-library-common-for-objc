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

#import "MSIDAssymetricKeyKeychainGenerator.h"
#import "MSIDKeychainUtil.h"
#import "MSIDAssymetricKeyPair.h"
#import "MSIDAssymetricKeyLookupAttributes.h"

@interface MSIDAssymetricKeyKeychainGenerator()

@property (nonatomic) NSString *keychainGroup;
@property (nonatomic) NSDictionary *defaultKeychainQuery;

@end

@implementation MSIDAssymetricKeyKeychainGenerator

#pragma mark - Init

- (nullable instancetype)initWithGroup:(nullable NSString *)keychainGroup error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    if (!keychainGroup)
    {
        keychainGroup = [[NSBundle mainBundle] bundleIdentifier];
    }
    
    MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
    if (!keychainUtil.teamId)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to retrieve teamId from keychain.", nil, nil, nil, nil, nil, YES);
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to retrieve teamId from keychain.");
        return nil;
    }
    
    // Add team prefix to keychain group if it is missed.
    if (![keychainGroup hasPrefix:keychainUtil.teamId])
    {
        keychainGroup = [keychainUtil accessGroup:keychainGroup];
    }
    
    _keychainGroup = keychainGroup;
    
    if (!_keychainGroup)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to set keychain access group.", nil, nil, nil, nil, nil, YES);
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to set keychain access group.");
        return nil;
    }
    
    NSMutableDictionary *defaultKeychainQuery = [@{(id)kSecAttrAccessGroup : self.keychainGroup} mutableCopy];
    [defaultKeychainQuery addEntriesFromDictionary:[self additionalPlatformKeychainAttributes]];
    
    self.defaultKeychainQuery = defaultKeychainQuery;
    return self;
}

#pragma mark - MSIDAssymetricKeyGenerating

- (MSIDAssymetricKeyPair *)generateKeyPairForAttributes:(MSIDAssymetricKeyLookupAttributes *)attributes
                                                  error:(NSError **)error
{
    if ([NSString msidIsStringNilOrBlank:attributes.privateKeyIdentifier]
        || [NSString msidIsStringNilOrBlank:attributes.publicKeyIdentifier])
    {
        [self logAndFillError:@"Invalid key generation attributes provided" status:-1 error:error];
        return nil;
    }
    
    // 0. Cleanup any previous state
    BOOL cleanupResult = [self cleanupKeychainForAttributes:attributes error:error];
    
    if (!cleanupResult)
    {
        [self logAndFillError:@"Failed to cleanup keychain prior to generating new keypair. Proceeding might result in unexpected results. Keychain might need to be manually cleaned to recover." status:-1 error:error];
        return nil;
    }
    
    // 1. Generate keypair
    NSDictionary *keyPairAttr = [self keychainQueryWithAttributes:[attributes assymetricKeyPairAttributes]];
    return [self generateKeyPairForKeyDict:keyPairAttr error:error];
}

- (MSIDAssymetricKeyPair *)readOrGenerateKeyPairForAttributes:(MSIDAssymetricKeyLookupAttributes *)attributes
                                                        error:(NSError **)error
{
    NSError *readError = nil;
    MSIDAssymetricKeyPair *keyPair = [self readKeyPairForAttributes:attributes error:&readError];

    if (keyPair || readError)
    {
        if (error) *error = readError;
        return keyPair;
    }
    
    return [self generateKeyPairForAttributes:attributes error:error];
}

- (MSIDAssymetricKeyPair *)readKeyPairForAttributes:(MSIDAssymetricKeyLookupAttributes *)attributes
                                             error:(NSError **)error
{
    if ([NSString msidIsStringNilOrBlank:attributes.privateKeyIdentifier]
        || [NSString msidIsStringNilOrBlank:attributes.publicKeyIdentifier])
    {
        [self logAndFillError:@"Invalid key lookup attributes provided" status:-1 error:error];
        return nil;
    }
    
    NSDictionary *privateKeyAttributes = [self keyAttributesWithQueryDictionary:[attributes privateKeyAttributes] keyTitle:@"private key" error:error];
    
    if (!privateKeyAttributes)
    {
        return nil;
    }
    
    NSDictionary *publicKeyAttributes = [self keyAttributesWithQueryDictionary:[attributes publicKeyAttributes] keyTitle:@"public key" error:error];
    
    if (!publicKeyAttributes)
    {
        return nil;
    }
    
    SecKeyRef privateKeyRef = (__bridge SecKeyRef)privateKeyAttributes[(__bridge id)kSecValueRef];
    SecKeyRef publicKeyRef = (__bridge SecKeyRef)publicKeyAttributes[(__bridge id)kSecValueRef];
    
    if (!privateKeyRef || !publicKeyRef)
    {
        [self logAndFillError:@"Invalid keychain attributes. No key ref returned" status:-1 error:error];
        return nil;
    }
    
    NSDate *creationDate = [privateKeyAttributes objectForKey:(__bridge NSDate *)kSecAttrCreationDate];
    
    MSIDAssymetricKeyPair *keypair = [[MSIDAssymetricKeyPair alloc] initWithPrivateKey:privateKeyRef
                                                                             publicKey:publicKeyRef
                                                                          creationDate:creationDate];

    return keypair;
}

#pragma mark - Cleanup

- (BOOL)cleanupKeychainForAttributes:(MSIDAssymetricKeyLookupAttributes *)attributes error:(NSError **)error
{
    return [self deleteItemWithAttributes:[attributes privateKeyAttributes] itemTitle:@"private key" error:error]
        && [self deleteItemWithAttributes:[attributes publicKeyAttributes] itemTitle:@"public key" error:error];
}

- (BOOL)deleteItemWithAttributes:(NSDictionary *)attributes itemTitle:(NSString *)itemTitle error:(NSError **)error
{
    NSDictionary *queryAttributes = [self keychainQueryWithAttributes:attributes];
    OSStatus result = SecItemDelete((CFDictionaryRef)queryAttributes);
    
    if (result != errSecSuccess
        && result != errSecItemNotFound)
    {
        [self logAndFillError:[NSString stringWithFormat:@"Failed to remove %@", itemTitle]
                       status:result
                        error:error];
        return NO;
    }
    
    return YES;
}

#pragma mark - Private

- (NSDictionary *)keyAttributesWithQueryDictionary:(NSDictionary *)queryDictionary keyTitle:(NSString *)keyTitle error:(NSError **)error
{
    NSMutableDictionary *keychainQuery = [[self keychainQueryWithAttributes:queryDictionary] mutableCopy];
    keychainQuery[(__bridge id)kSecReturnAttributes] = @YES;
    keychainQuery[(__bridge id)kSecReturnRef] = @YES;
    
    CFTypeRef keyCFDict = NULL;
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery, (CFTypeRef*)&keyCFDict);
    
    if (status != errSecSuccess)
    {
        if (status != errSecItemNotFound)
        {
            [self logAndFillError:[NSString stringWithFormat:@"Failed to find %@", keyTitle]
                           status:status
                            error:error];
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Failed to find key with query %@ with status %ld", keychainQuery, (long)status);
        
        return nil;
    }
    
    NSDictionary *privateKeyDict = CFBridgingRelease(keyCFDict);
    return privateKeyDict;
}

- (NSDictionary *)keychainQueryWithAttributes:(NSDictionary *)attributes
{
    NSMutableDictionary *keyPairAttr = [self.defaultKeychainQuery mutableCopy];
    [keyPairAttr addEntriesFromDictionary:attributes];
    return keyPairAttr;
}

- (MSIDAssymetricKeyPair *)generateEphemeralKeyPair:(NSError **)error
{
    NSDictionary *attributesDict = @{(__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeRSA,
                                     (__bridge id)kSecAttrKeySizeInBits : @2048};
    return [self generateKeyPairForKeyDict:attributesDict error:error];
}

- (MSIDAssymetricKeyPair *)generateKeyPairForKeyDict:(NSDictionary *)attributes
                                               error:(NSError **)error
{
    SecKeyRef publicKeyRef = NULL;
    SecKeyRef privateKeyRef = NULL;
    OSStatus status = SecKeyGeneratePair((__bridge CFDictionaryRef)attributes, &publicKeyRef, &privateKeyRef);
    
    if (status != errSecSuccess)
    {
        [self logAndFillError:@"Failed to generate keypair" status:status error:error];
        return nil;
    }
    
    NSDictionary* publicKeyQuery = @{ (id)kSecValueRef: (__bridge id)publicKeyRef,
     (id)kSecClass: (id)kSecClassKey,
     (id)kSecReturnAttributes:(id)kCFBooleanTrue
    };
    
    /*
     We need this additional query because there is only one API SecKeychainItemCopyAttributesAndData
     to query keychain item attributes which relies on SecKeychainAttributeList param which is only available
     on macOS
     */
    CFDictionaryRef result = nil;
    status = SecItemCopyMatching((CFDictionaryRef)publicKeyQuery, (CFTypeRef *)&result);
    
    if (status != errSecSuccess)
    {
        [self logAndFillError:@"Failed to read key attributes" status:status error:error];
        return nil;
    }
    
    NSDate *creationDate = [publicKeyQuery objectForKey:(__bridge NSDate *)kSecAttrCreationDate];
    MSIDAssymetricKeyPair *keyPair = [[MSIDAssymetricKeyPair alloc] initWithPrivateKey:privateKeyRef publicKey:publicKeyRef creationDate:creationDate];
    
    if (privateKeyRef) CFRelease(privateKeyRef);
    if (publicKeyRef) CFRelease(publicKeyRef);
    
    return keyPair;
}


#pragma mark - Platform

- (NSDictionary *)additionalPlatformKeychainAttributes
{
    #ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    #if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
        if (@available(macOS 10.15, *)) {
            return @{(id)kSecUseDataProtectionKeychain : @YES};
        }
    #endif
    #endif
    
    return nil;
}

#pragma mark - Utils

- (void)logAndFillError:(NSString *)errorTitle status:(OSStatus)status error:(NSError **)error
{
    NSString *description = [NSString stringWithFormat:@"Operation failed with title \"%@\", status %ld", errorTitle, (long)status];
    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", description);
    
    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, description, nil, nil, nil, nil, nil, NO);
    }
}

@end
