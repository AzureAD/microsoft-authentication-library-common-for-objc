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
#import "MSIDKeyOperationUtil.h"
#import "MSIDJwtAlgorithm.h"
#import "NSData+MSIDTestUtil.h"
#import "NSData+JWT.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDTestSecureEnclaveKeyPairGenerator.h"

@interface MSIDKeyOperationUtilTest : XCTestCase
    @property (nonatomic) SecKeyRef eccPrivateKey;
    @property (nonatomic) SecKeyRef eccPublicKey;
    @property (nonatomic) SecKeyRef rsaPrivateKey;
    @property (nonatomic) SecKeyRef rsaPublicKey;
    @property (nonatomic) NSString *testApplicationTag;
    @property (nonatomic) NSString *sharedAccessGroup;
    @property (nonatomic) MSIDTestSecureEnclaveKeyPairGenerator *generator;
@end

@implementation MSIDKeyOperationUtilTest

- (void)setUp
{
    _testApplicationTag = @"Microsoft ECC Test App";
    NSString *prefix = @"SGGM6D27TK";
#if TARGET_OS_IPHONE
    prefix = @"UBF8T346G9";
#endif
    _sharedAccessGroup = [NSString stringWithFormat:@"%@.%@", prefix, @"com.microsoft.MSIDTestsHostApp"]; // Using SGGM6D27TK as prefix for complete shared group
    if (!self.generator)
    {
        self.generator = [[MSIDTestSecureEnclaveKeyPairGenerator alloc] initWithSharedAccessGroup:_sharedAccessGroup useSecureEnclave:YES applicationTag:_testApplicationTag];
    }
    self.eccPrivateKey = [self.generator eccPrivateKey];
    self.eccPublicKey = [self.generator eccPublicKey];
    if (!self.rsaPrivateKey)
    {
        [self populateRsaKeys];
    }
}

- (void)tearDown
{
    self.generator = nil;
    if (self.rsaPublicKey)
    {
        CFRelease(self.rsaPublicKey);
        self.rsaPublicKey = NULL;
    }
    if (self.rsaPrivateKey)
    {
        CFRelease(self.rsaPrivateKey);
        self.rsaPrivateKey = NULL;
    }
}

- (void)testIfKeyIsFromSecureEnclave_shouldReturnTrueForSECKeys
{
    XCTAssertTrue(self.eccPrivateKey != NULL);
    XCTAssertTrue([[MSIDKeyOperationUtil sharedInstance] isKeyFromSecureEnclave:self.eccPrivateKey]);
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isKeyFromSecureEnclave:self.eccPublicKey]);
    // RSA keys can't be in secure enclave
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isKeyFromSecureEnclave:self.rsaPrivateKey]);
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isKeyFromSecureEnclave:self.rsaPublicKey]);
}

- (void)testIfOperationIsSupportedByKey
{
    NSError *error;
    /**
                Private key operations : Ideally, private keys are used to decrypt and sign.
                Public Key operations : Ideally, public keys are used to encrypt and verify signatures.
     */
    
    // Private key tests
    
    // ECC private key should be able to sign artifacts with ECDSA
    XCTAssertTrue([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmECDSASignatureDigestX962SHA256 key:self.eccPrivateKey context:nil error:&error]);
    XCTAssertTrue([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmECDSASignatureMessageX962SHA256 key:self.eccPrivateKey context:nil error:&error]);
    // ECC private key should not be able to sign artifacts with RSA key algorithms
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256 key:self.eccPrivateKey context:nil error:&error]);
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmRSASignatureRaw key:self.eccPrivateKey context:nil error:&error]);
    // RSA private key should be able to sign artifacts with RSA key algorithms
    XCTAssertTrue([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256 key:self.rsaPrivateKey context:nil error:&error]);
    XCTAssertTrue([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmRSASignatureRaw key:self.rsaPrivateKey context:nil error:&error]);
    // RSA private key should be able to sign artifacts with ECDSA
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmECDSASignatureDigestX962SHA256 key:self.rsaPrivateKey context:nil error:&error]);
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmECDSASignatureMessageX962SHA256 key:self.rsaPrivateKey context:nil error:&error]);
#if TARGET_OS_IPHONE  // Fails on macOS but passes on iOS. Opened FB https://feedbackassistant.apple.com/feedback/9665871
    // Private key should not be used to verify
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeVerify algorithm:kSecKeyAlgorithmECDSASignatureDigestX962SHA256 key:self.eccPrivateKey context:nil error:&error]);
#endif
    XCTAssertTrue([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeVerify algorithm:kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256 key:self.rsaPrivateKey context:nil error:&error]);
    // Testing private key cannot be used to encrypt (kSecAttrCanEncrypt of private key is set to NO)
#if TARGET_OS_IPHONE  // Fails on macOS but passes on iOS. Opened FB : https://feedbackassistant.apple.com/feedback/9665871
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeEncrypt algorithm:kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM key:self.eccPrivateKey context:nil error:&error]);
#endif
    // Testing private key can be used to decrypt (kSecAttrCanDecrypt of private key is set to YES)
    XCTAssertTrue([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeDecrypt algorithm:kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM key:self.eccPrivateKey context:nil error:&error]);
    
    // Public key tests
    
    // Testing public key can be used to encrypt (kSecAttrCanEncrypt of public key set to YES)
    XCTAssertTrue([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeEncrypt algorithm:kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM key:self.eccPublicKey context:nil error:&error]);
    // Testing public key cannot be used to decrypt (kSecAttrCanDecrypt of public key set to NO)
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeDecrypt algorithm:kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM key:self.eccPublicKey context:nil error:&error]);
    // Any public key should not be able to sign an artifact
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmECDSASignatureDigestX962SHA256 key:self.eccPublicKey context:nil error:&error]);
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmECDSASignatureDigestX962SHA256 key:self.rsaPublicKey context:nil error:&error]);
    
    // Operation not supported for NULL key
    SecKeyRef nullKey = NULL;
    XCTAssertFalse([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmRSASignatureRaw key:nullKey context:nil error:&error]);
}

- (void)testCorrectJwtalgorithmIsReturnedForAKey
{
    XCTAssertNotEqual(self.eccPrivateKey, NULL);
    // Return ES256 for ECC private key
    XCTAssertEqual([[MSIDKeyOperationUtil sharedInstance] getJwtAlgorithmForKey:self.eccPrivateKey context:nil error:nil], MSID_JWT_ALG_ES256);
    NSError *error;
    // Passing public key should not return a Jwt alg
    XCTAssertNil([[MSIDKeyOperationUtil sharedInstance] getJwtAlgorithmForKey:self.eccPublicKey context:nil error:&error]);
    XCTAssertNotNil(error);
}

- (void)testSigningRawDataWithKey
{
    NSData *dataToBeSigned = [@"TEST" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *dataDigest = [dataToBeSigned msidSHA256];
    NSError *error;
    NSData *signature = nil;
    
    // Valid signature with ECC private key via secure enclave
    signature = [[MSIDKeyOperationUtil sharedInstance] getSignatureForDataWithKey:dataToBeSigned privateKey:self.eccPrivateKey signingAlgorithm:kSecKeyAlgorithmECDSASignatureMessageX962SHA256 context:nil error:&error];
    XCTAssertNotNil(signature);
    XCTAssertNil(error);

    CFErrorRef verifyingError = NULL;
    BOOL isVerified = SecKeyVerifySignature(self.eccPublicKey,
                                            kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                            (__bridge CFDataRef) dataToBeSigned,
                                            (__bridge CFDataRef) signature,
                                            &verifyingError);
    XCTAssertTrue(isVerified);
    XCTAssertTrue(verifyingError == NULL);
    
    // Valid signature with RSA private key
    signature = [[MSIDKeyOperationUtil sharedInstance] getSignatureForDataWithKey:dataToBeSigned privateKey:self.rsaPrivateKey signingAlgorithm:kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256 context:nil error:&error];
    XCTAssertNotNil(signature);
    XCTAssertNil(error);

    verifyingError = NULL;
    isVerified = SecKeyVerifySignature(self.rsaPublicKey,
                                       kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256,
                                       (__bridge CFDataRef) dataToBeSigned,
                                       (__bridge CFDataRef) signature,
                                       &verifyingError);
    XCTAssertTrue(isVerified);
    XCTAssertTrue(verifyingError == NULL);
    // Checking RSA signature generated by MSIDKeyOperationUtil matches signature generated with NSData+JWT
    NSData *rsaDataSignature = [dataDigest msidSignHashWithPrivateKey:self.rsaPrivateKey];
    XCTAssertEqualObjects([rsaDataSignature msidBase64UrlEncodedString], [signature msidBase64UrlEncodedString]);

}

- (void)testSigningRawDataWithKey_NegativeTests
{
    NSData *dataToBeSigned = nil;
    NSError *error;
    NSData *signature = nil;
    SecKeyAlgorithm alg = NULL;
    
    // nil data
    signature = [[MSIDKeyOperationUtil sharedInstance] getSignatureForDataWithKey:dataToBeSigned privateKey:self.eccPrivateKey signingAlgorithm:kSecKeyAlgorithmECDSASignatureMessageX962SHA256 context:nil error:&error];
    XCTAssertNil(signature);
    XCTAssertNotNil(error);
    error = nil;
    // NULL alg
    signature = [[MSIDKeyOperationUtil sharedInstance] getSignatureForDataWithKey:[@"TEST" dataUsingEncoding:NSUTF8StringEncoding] privateKey:self.eccPrivateKey signingAlgorithm:alg context:nil error:&error];
    XCTAssertNil(signature);
    XCTAssertNotNil(error);
    error = nil;
    // nil private key
    SecKeyRef nilPrivateKey = NULL;
    signature = [[MSIDKeyOperationUtil sharedInstance] getSignatureForDataWithKey:[@"TEST" dataUsingEncoding:NSUTF8StringEncoding] privateKey:nilPrivateKey signingAlgorithm:alg context:nil error:&error];
    XCTAssertNil(signature);
    XCTAssertNotNil(error);
    error = nil;
    // Trying to sign using a public key
    signature = [[MSIDKeyOperationUtil sharedInstance] getSignatureForDataWithKey:[@"TEST" dataUsingEncoding:NSUTF8StringEncoding] privateKey:self.eccPublicKey signingAlgorithm:kSecKeyAlgorithmECDSASignatureMessageX962SHA256 context:nil error:&error];
    XCTAssertNil(signature);
    XCTAssertNotNil(error);
    error = nil;
}

#pragma mark -- Test Utility

-(void) populateRsaKeys
{
    __auto_type hexString = @"308204a3 02010002 82010100 b1dc0c48 cc3192e3 790f615c 7c50dac6 b25e30ff 26eddf8e 6db8eb67 44b0b35e ee71e8c8 14a4200f 0e9dee71 117bce26 31f6f5db 8b5f8ab0 a197cc8b 20661c87 e231f618 189f5e5e 26d6b90d 83c025fc 931b164c fd6ee3f8 91d0fb8a 795cccaa 6f24fccc 1052fc75 ae6a2558 4d7b93ab 63cdc3fa 357fa238 8e34684b 5146233e e50eba7b 89b61bc7 82bcaca0 b216568b d58ea7fb 1bc09bf7 c6cb31ed 72f51c1c aa69674c d307843e 31a41531 0ab1a091 927a0f7f 1022ef46 bf72143b 26f08a57 cc2afdb5 ac0bc7d0 753812f0 bd82a633 dc44e8a6 a80d55c1 56304748 89fce0db 2174ce94 a2f93607 b48fb6c7 3281f0d7 d85dbc8f 70dc8257 7d4eb7a8 e877bf33 02030100 01028201 000de5d4 ebe750c4 5a93fe18 ac82664b 0215b3f8 7e278b94 d96b4774 d587ef8a c4933b41 6648fe9e 26af0cb6 320d9caf fa1a1363 18b9a648 8f0ec16e d13c41de 5edbd4ed 96ea6da1 9117d5d5 75f1e294 d54ca564 33b5e5f1 585e0487 73459273 c7a991a9 5344bf47 4ce6c912 8bf8d9fc 2afb4c7b d0d45759 d4b37ff2 da57ca74 3c774541 2d9d5bdc 8eac55d3 5b80f31a d0d75df4 c1a80248 495b72fd 30705ab8 20e9fbcb e5bf06e0 10a68aab d986b76f d34c711a d07a45be 53d668ca 7851c135 f041ca8d 013b6e99 bf6681db 7cb8a7db 1581470e e0d74e90 9adb773b 604b38a7 45743b09 7c4ec4b2 73828383 d2f361d4 0ee5a002 827f3812 39a37f29 5f9afb72 79028181 00f34013 54f20db9 ea06e732 66d6da62 3997ddbc b861e3ca 36ff994f 8ee851bd aa90fe36 b212f0da d3f745b2 7621544b df498b1b 8c991fc6 90b133dc db148798 b6dc83d9 1d341115 4fd2397e 40b6e6e4 5def4585 3f4721de eabefcd1 6cd8b1d5 6ab8e0b0 054eee00 2a3d7046 9c30e544 ebb2095c 41b96997 f33a47ee d8cd882f e7028181 00bb2e8f cfd51f36 98cd7169 9012fe2d 9cde0518 abd13609 829a7c7c de23b34a aafb89fd 632a3c99 8ab0fabc 4d812fd0 091ac5b2 bb12455d b8c4ad0c fa616b02 4084bbbf c6b013a2 27d75f0f ef419e38 3e96561d 1295fd37 146001e0 c2d14a1e c7aa9755 3b61ca76 4acbb47d fdf46cf5 78c9c099 2ac9778a dff39a1c b54aec7c d5028181 00d0e070 b93cb0f4 b834fd4a 966c6052 804a1c29 f5da7914 276e0c63 f8bf1d91 d4697521 da7fd13a d7513a14 28c42df2 88e64a01 7a15f2e7 3b502ecc b383497c a5696dfe 7dc93bf2 24fccc49 d1a03d5c 541d2681 68f8d7e8 e782e0ed a49ddef6 f811913f 150fd5e7 665e238f 3e87ee17 e49c98d5 13caf715 77d2cffa 1549486c 79028180 377babc1 2d291d63 d9b1be5a a866935a a62cd88d 456c4111 677d72fd dd932d94 d50ea7ff 16ebf38f 3aba77ca 797a94ad be33cfb0 c7cfabe2 32da20b8 aedbab45 3892f65b 8ca1a535 2e0fcd87 5be9ec3e 110de17c 3add5dd0 3a4d1434 6b190f5a 9be453ad 506554ff 02b6b389 ed43c6d7 50e63800 88cb586c dda656d0 1e2f4f29 0281806e 1d67170c 6fbf6cd7 7a69a2e7 f3aa8ae0 10d353cd 1153dfc9 f689a6a3 20438a14 841615e3 aa5d5b00 b7bb61ea 8ec8ea02 1b2bf85c 03761e5c a5dc6d4f 97179b2a 386aaa02 b6c3ec3f 37d29d46 e8ba5082 008d7e92 b00eed5d 943552ef e5dde749 b1c0a549 149a8b09 170a128a fe503554 17214ae7 ac699b5f 21c06faa 6d22ce";
    
    __auto_type data = [NSData hexStringToData:hexString];
    
    NSDictionary *attributes = @{ (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA, (id)kSecAttrKeySizeInBits: @2048, (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPrivate };
    
    SecKeyRef signingKey = NULL;
    if (@available(iOS 10.0, *))
    {
        signingKey = SecKeyCreateWithData((__bridge CFDataRef)data, (__bridge CFDictionaryRef)attributes, NULL);
    }
    
    self.rsaPrivateKey = signingKey;
    if (self.rsaPrivateKey)
    {
        self.rsaPublicKey = SecKeyCopyPublicKey(self.rsaPrivateKey);
    }
}
@end
