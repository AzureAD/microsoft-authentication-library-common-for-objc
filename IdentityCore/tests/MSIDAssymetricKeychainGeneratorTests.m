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

#import <XCTest/XCTest.h>
#import "MSIDAssymetricKeyKeychainGenerator.h"
#import "MSIDAssymetricKeyLookupAttributes.h"
#import "MSIDAssymetricKeyPair.h"
#if !TARGET_OS_IPHONE
#import "MSIDAssymetricKeyLoginKeychainGenerator.h"
#endif

@interface MSIDAssymetricKeychainGeneratorTests : XCTestCase

@end
NSString *privateKeyIdentifier = @"com.msal.unittest.privateKey";
NSString *publicKeyIdentifier = @"com.msal.unittest.publicKey";

@implementation MSIDAssymetricKeychainGeneratorTests

- (void)testGenerateKeyPair_whenNilAttributesProvided_shouldReturnNilAndFillError
{
    MSIDAssymetricKeyLookupAttributes *attr = nil;
    
    MSIDAssymetricKeyKeychainGenerator *generator = [self keyGenerator];
    
    NSError *error = nil;
    MSIDAssymetricKeyPair *result = [generator generateKeyPairForAttributes:attr error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Operation failed with title \"Invalid key generation attributes provided\", status -1");
}

- (void)testGenerateKeyPair_whenInvalidAttributesProvided_shouldReturnNilAndFillError
{
    MSIDAssymetricKeyLookupAttributes *attr = [MSIDAssymetricKeyLookupAttributes new];
    
    MSIDAssymetricKeyKeychainGenerator *generator = [self keyGenerator];
    
    NSError *error = nil;
    MSIDAssymetricKeyPair *result = [generator generateKeyPairForAttributes:attr error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Operation failed with title \"Invalid key generation attributes provided\", status -1");
}

- (void)testGenerateKeyPair_whenValidAttributesProvided_andKeyDoesNotExist_shouldGenerateKeyAndReturnIt
{
    [self deleteKeyWithTag:privateKeyIdentifier];
    [self deleteKeyWithTag:publicKeyIdentifier];
    
    MSIDAssymetricKeyLookupAttributes *attr = [MSIDAssymetricKeyLookupAttributes new];
    attr.privateKeyIdentifier = privateKeyIdentifier;
    attr.publicKeyIdentifier = publicKeyIdentifier;
    
    MSIDAssymetricKeyKeychainGenerator *generator = [self keyGenerator];
    
    NSError *error = nil;
    MSIDAssymetricKeyPair *result = [generator generateKeyPairForAttributes:attr error:&error];
    
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    XCTAssertNotNil((id)result.privateKeyRef);
    XCTAssertNotNil((id)result.publicKeyRef);
    
    BOOL privateKeyExists = [self keyExists:privateKeyIdentifier];
    XCTAssertTrue(privateKeyExists);
    
    BOOL publicKeyExists = [self keyExists:publicKeyIdentifier];
    XCTAssertTrue(publicKeyExists);
    
    XCTAssertNotNil([result getKeyModulus:result.publicKeyRef]);
    XCTAssertNotNil([result getKeyExponent:result.publicKeyRef]);

}

- (void)testGenerateKeyPair_whenKeyExists_shouldGenerateNewKeyAndReturnIt
{
    MSIDAssymetricKeyLookupAttributes *attr = [MSIDAssymetricKeyLookupAttributes new];
    attr.privateKeyIdentifier = privateKeyIdentifier;
    attr.publicKeyIdentifier = publicKeyIdentifier;
    
    // Generate first time
    MSIDAssymetricKeyKeychainGenerator *generator = [self keyGenerator];
    
    NSError *error = nil;
    MSIDAssymetricKeyPair *result = [generator generateKeyPairForAttributes:attr error:&error];
    
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    
    // Now generate again
    MSIDAssymetricKeyPair *secondResult = [generator generateKeyPairForAttributes:attr error:&error];
    XCTAssertNotNil(secondResult);
    XCTAssertNil(error);
    
    NSDictionary *firstPrivateAttr = CFBridgingRelease(SecKeyCopyAttributes(result.privateKeyRef));
    NSDictionary *secondPrivateAttr = CFBridgingRelease(SecKeyCopyAttributes(secondResult.privateKeyRef));
    
    NSDictionary *firstPublicKeyAttr = CFBridgingRelease(SecKeyCopyAttributes(result.publicKeyRef));
    NSDictionary *secondPublicKeyAttr = CFBridgingRelease(SecKeyCopyAttributes(secondResult.publicKeyRef));
    
    XCTAssertNotEqualObjects(firstPrivateAttr[@"klbl"], secondPrivateAttr[@"klbl"]);
    XCTAssertNotEqualObjects(firstPublicKeyAttr[@"klbl"], secondPublicKeyAttr[@"klbl"]);
    
    BOOL privateKeyExists = [self keyExists:privateKeyIdentifier];
    XCTAssertTrue(privateKeyExists);
    
    BOOL publicKeyExists = [self keyExists:publicKeyIdentifier];
    XCTAssertTrue(publicKeyExists);
}

- (void)testReadKeyForAttributes_whenNilAttributes_shouldReturnNilAndFillError
{
    MSIDAssymetricKeyLookupAttributes *attr = nil;
    
    MSIDAssymetricKeyKeychainGenerator *generator = [self keyGenerator];
    
    NSError *error = nil;
    MSIDAssymetricKeyPair *result = [generator readKeyPairForAttributes:attr error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Operation failed with title \"Invalid key lookup attributes provided\", status -1");
}

- (void)testReadKeyForAttributes_whenInvalidAttributes_shouldReturnNilAndFillError
{
    MSIDAssymetricKeyLookupAttributes *attr = [MSIDAssymetricKeyLookupAttributes new];
    
    MSIDAssymetricKeyKeychainGenerator *generator = [self keyGenerator];
    
    NSError *error = nil;
    MSIDAssymetricKeyPair *result = [generator readKeyPairForAttributes:attr error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Operation failed with title \"Invalid key lookup attributes provided\", status -1");
}

- (void)testReadKeyForAttributes_whenKeyExists_shouldReturnKeyPairAndNilError
{
    MSIDAssymetricKeyLookupAttributes *attr = [MSIDAssymetricKeyLookupAttributes new];
    attr.privateKeyIdentifier = privateKeyIdentifier;
    attr.publicKeyIdentifier = publicKeyIdentifier;
    attr.keyDisplayableLabel = @"My key";
    
    // First generate key
    MSIDAssymetricKeyKeychainGenerator *generator = [self keyGenerator];
    
    NSError *error = nil;
    MSIDAssymetricKeyPair *result = [generator generateKeyPairForAttributes:attr error:&error];
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    
    // Now read it back
    MSIDAssymetricKeyPair *readResult = [generator readKeyPairForAttributes:attr error:&error];
    XCTAssertNotNil(readResult);
    XCTAssertNil(error);
    
    NSDictionary *firstPrivateAttr = CFBridgingRelease(SecKeyCopyAttributes(result.privateKeyRef));
    NSDictionary *secondPrivateAttr = CFBridgingRelease(SecKeyCopyAttributes(readResult.privateKeyRef));
    
    NSDictionary *firstPublicKeyAttr = CFBridgingRelease(SecKeyCopyAttributes(result.publicKeyRef));
    NSDictionary *secondPublicKeyAttr = CFBridgingRelease(SecKeyCopyAttributes(readResult.publicKeyRef));
    
    XCTAssertEqualObjects(firstPrivateAttr[@"klbl"], secondPrivateAttr[@"klbl"]);
    XCTAssertEqualObjects(firstPublicKeyAttr[@"klbl"], secondPublicKeyAttr[@"klbl"]);
}

- (void)testReadKeyForAttributes_whenKeyDoesntExist_shouldReturnNilAndNilError
{
    MSIDAssymetricKeyKeychainGenerator *generator = [self keyGenerator];
        
    MSIDAssymetricKeyLookupAttributes *attr = [MSIDAssymetricKeyLookupAttributes new];
    attr.privateKeyIdentifier = privateKeyIdentifier;
    attr.publicKeyIdentifier = publicKeyIdentifier;
    attr.keyDisplayableLabel = @"My key";
    
    [self deleteKeyWithTag:privateKeyIdentifier];
    [self deleteKeyWithTag:publicKeyIdentifier];
    
    NSError *error = nil;
    MSIDAssymetricKeyPair *readResult = [generator readKeyPairForAttributes:attr error:&error];
    XCTAssertNil(readResult);
    XCTAssertNil(error);
}

- (void)testReadKeyForAttributes_whenOnlyPrivateKeyExists_shouldReturnNilAndFillError
{
    MSIDAssymetricKeyKeychainGenerator *generator = [self keyGenerator];
    
    MSIDAssymetricKeyLookupAttributes *attr = [MSIDAssymetricKeyLookupAttributes new];
    attr.privateKeyIdentifier = privateKeyIdentifier;
    attr.publicKeyIdentifier = publicKeyIdentifier;
    attr.keyDisplayableLabel = @"My key";
    
    NSError *error = nil;
    MSIDAssymetricKeyPair *result = [generator generateKeyPairForAttributes:attr error:&error];
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    
    // Delete public key part
    [self deleteKeyWithTag:publicKeyIdentifier];
    
    // Try to read the key
    MSIDAssymetricKeyPair *readResult = [generator readKeyPairForAttributes:attr error:&error];
    XCTAssertNil(readResult);
    XCTAssertNil(error);
}

- (void)testReadOrGenerateKey_whenNilAttr_shouldReturnNilAndFillError
{
    MSIDAssymetricKeyLookupAttributes *attr = nil;
    
    MSIDAssymetricKeyKeychainGenerator *generator = [self keyGenerator];
    
    NSError *error = nil;
    MSIDAssymetricKeyPair *result = [generator readOrGenerateKeyPairForAttributes:attr error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Operation failed with title \"Invalid key lookup attributes provided\", status -1");
}

- (void)testReadOrGenerateKey_whenKeyExists_shouldReturnKey
{
    MSIDAssymetricKeyLookupAttributes *attr = [MSIDAssymetricKeyLookupAttributes new];
    attr.privateKeyIdentifier = privateKeyIdentifier;
    attr.publicKeyIdentifier = publicKeyIdentifier;
    attr.keyDisplayableLabel = @"My key";
    
    // First generate key
    MSIDAssymetricKeyKeychainGenerator *generator = [self keyGenerator];
    
    NSError *error = nil;
    MSIDAssymetricKeyPair *result = [generator generateKeyPairForAttributes:attr error:&error];
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    
    // Now read it back
    MSIDAssymetricKeyPair *readResult = [generator readOrGenerateKeyPairForAttributes:attr error:&error];
    XCTAssertNotNil(readResult);
    XCTAssertNil(error);
    
    NSDictionary *firstPrivateAttr = CFBridgingRelease(SecKeyCopyAttributes(result.privateKeyRef));
    NSDictionary *secondPrivateAttr = CFBridgingRelease(SecKeyCopyAttributes(readResult.privateKeyRef));
    
    NSDictionary *firstPublicKeyAttr = CFBridgingRelease(SecKeyCopyAttributes(result.publicKeyRef));
    NSDictionary *secondPublicKeyAttr = CFBridgingRelease(SecKeyCopyAttributes(readResult.publicKeyRef));
    
    XCTAssertEqualObjects(firstPrivateAttr[@"klbl"], secondPrivateAttr[@"klbl"]);
    XCTAssertEqualObjects(firstPublicKeyAttr[@"klbl"], secondPublicKeyAttr[@"klbl"]);
}

- (void)testReadOrGenerateKey_whenOnlyPartialKeyExists_shouldReturnNewKey
{
    MSIDAssymetricKeyLookupAttributes *attr = [MSIDAssymetricKeyLookupAttributes new];
    attr.privateKeyIdentifier = privateKeyIdentifier;
    attr.publicKeyIdentifier = publicKeyIdentifier;
    attr.keyDisplayableLabel = @"My key";
    
    // First generate key
    MSIDAssymetricKeyKeychainGenerator *generator = [self keyGenerator];
    
    NSError *error = nil;
    MSIDAssymetricKeyPair *result = [generator generateKeyPairForAttributes:attr error:&error];
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    
    // Delete public key part
    [self deleteKeyWithTag:privateKeyIdentifier];
    
    // Now read it back
    MSIDAssymetricKeyPair *readResult = [generator readOrGenerateKeyPairForAttributes:attr error:&error];
    XCTAssertNotNil(readResult);
    XCTAssertNil(error);
    
    NSDictionary *firstPrivateAttr = CFBridgingRelease(SecKeyCopyAttributes(result.privateKeyRef));
    NSDictionary *secondPrivateAttr = CFBridgingRelease(SecKeyCopyAttributes(readResult.privateKeyRef));
    
    NSDictionary *firstPublicKeyAttr = CFBridgingRelease(SecKeyCopyAttributes(result.publicKeyRef));
    NSDictionary *secondPublicKeyAttr = CFBridgingRelease(SecKeyCopyAttributes(readResult.publicKeyRef));
    
    XCTAssertNotEqualObjects(firstPrivateAttr[@"klbl"], secondPrivateAttr[@"klbl"]);
    XCTAssertNotEqualObjects(firstPublicKeyAttr[@"klbl"], secondPublicKeyAttr[@"klbl"]);
}

#pragma mark - Helpers

- (void)deleteKeyWithTag:(NSString *)tag
{
    NSDictionary *deleteKeyAttr = @{(id)kSecClass : (id)kSecClassKey,
                                    (id)kSecAttrApplicationTag : (id)[tag dataUsingEncoding:NSUTF8StringEncoding]};
    
    OSStatus status = SecItemDelete((CFDictionaryRef)deleteKeyAttr);
    BOOL deletionSucceeded = status == errSecSuccess || status == errSecItemNotFound;
    XCTAssertTrue(deletionSucceeded);
}

- (BOOL)keyExists:(NSString *)tag
{
    NSDictionary *lookupAttr = @{(id)kSecClass : (id)kSecClassKey,
                                 (id)kSecAttrApplicationTag : (id)[tag dataUsingEncoding:NSUTF8StringEncoding],
                                 (id)kSecReturnRef : @YES};
    
    CFTypeRef result = NULL;
    SecItemCopyMatching((CFDictionaryRef)lookupAttr, &result);
    BOOL keyExists = result != nil;
    if (keyExists) CFRelease(result);
    
    return keyExists;
}

- (MSIDAssymetricKeyKeychainGenerator *)keyGenerator
{
#if TARGET_OS_IPHONE
    return [[MSIDAssymetricKeyKeychainGenerator alloc] initWithGroup:nil error:nil];
#else
    return [[MSIDAssymetricKeyLoginKeychainGenerator alloc] initWithGroup:nil error:nil];
#endif
}

@end
