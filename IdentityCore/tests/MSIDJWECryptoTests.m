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
#import <XCTest/XCTest.h>
#import "MSIDTestSecureEnclaveKeyPairGenerator.h"
#import "MSIDEcdhApv.h"
#import "MSIDJWECrypto.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDJwtAlgorithm.h"

@interface MSIDJWECryptoTests : XCTestCase
@property (nonatomic) SecKeyRef eccPrivateKey;
@property (nonatomic) SecKeyRef eccPublicKey;
@property (nonatomic) NSString *testApplicationTag;
@property (nonatomic) NSString *sharedAccessGroup;
@property (nonatomic) MSIDTestSecureEnclaveKeyPairGenerator *generator;
@end

@implementation MSIDJWECryptoTests

- (void)setUp
{
    _testApplicationTag = @"Microsoft ECC Test App";
    NSString *prefix = @"SGGM6D27TK";
    BOOL useSecureEnclave = NO;
#if TARGET_OS_IPHONE
    prefix = @"UBF8T346G9";
    useSecureEnclave = YES;
#endif
    _sharedAccessGroup = [NSString stringWithFormat:@"%@.%@", prefix, @"com.microsoft.MSIDTestsHostApp"]; // Using SGGM6D27TK as prefix for complete shared group
    if (!self.generator)
    {
        self.generator = [[MSIDTestSecureEnclaveKeyPairGenerator alloc] initWithSharedAccessGroup:_sharedAccessGroup useSecureEnclave:useSecureEnclave applicationTag:_testApplicationTag];
    }
    self.eccPrivateKey = [self.generator eccPrivateKey];
    self.eccPublicKey = [self.generator eccPublicKey];
}

- (void)tearDown
{
    self.generator = nil;
}

- (void)testGenerateJweCryptoWithTransportKey_validInputs_shouldReturnJweCrypto
{
    NSError *error = nil;
    NSString *apvPrefix = @"MsalClient";
    MSIDEcdhApv *ecdhPartyVInfoData = [[MSIDEcdhApv alloc] initWithKey:self.eccPublicKey apvPrefix:apvPrefix context:nil error:&error];
    XCTAssertNotNil(ecdhPartyVInfoData);
    XCTAssertNil(error);
    
    MSIDJWECrypto *jweCrypto = [[MSIDJWECrypto alloc] initWithKeyExchangeAlg:MSID_JWT_ALG_ECDH
                                                         encryptionAlgorithm:MSID_JWT_ALG_A256GCM
                                                                         apv:ecdhPartyVInfoData
                                                                     context:nil
                                                                       error:&error];
    XCTAssertNotNil(jweCrypto);
    XCTAssertNil(error);
    XCTAssertEqualObjects(jweCrypto.keyExchangeAlgorithm, MSID_JWT_ALG_ECDH);
    XCTAssertEqualObjects(jweCrypto.encryptionAlgorithm, MSID_JWT_ALG_A256GCM);
    XCTAssertNotNil(jweCrypto.jweCryptoDictionary);
    XCTAssertEqual(jweCrypto.jweCryptoDictionary[@"alg"], MSID_JWT_ALG_ECDH);
    XCTAssertEqual(jweCrypto.jweCryptoDictionary[@"enc"], MSID_JWT_ALG_A256GCM);
    XCTAssertNotNil(jweCrypto.jweCryptoDictionary[@"apv"]);
    XCTAssertEqual(jweCrypto.jweCryptoDictionary[@"apv"], ecdhPartyVInfoData.APV);
    XCTAssertNotNil(jweCrypto.urlEncodedJweCrypto);
    XCTAssertTrue([jweCrypto.urlEncodedJweCrypto containsString:ecdhPartyVInfoData.APV]);
    
    NSString *apv = ecdhPartyVInfoData.APV;
    NSData *apvData = [NSData msidDataFromBase64UrlEncodedString:apv];
    XCTAssertNotNil(apvData);
    XCTAssertTrue([apvData length] > 0);
    
    // APV: <Prefix Length> | <Prefix> | <Public Key Length> | <Public Key> | <Nonce Length> | <Nonce>
    NSData *prefixLenData = [apvData subdataWithRange:NSMakeRange(0, sizeof(int))];
    
    // Extract prefix length from apv data
    prefixLenData = [self convertToLittleEndian:prefixLenData];
    NSUInteger prefixLen = [self convertHexBytesToInt:prefixLenData];
    XCTAssertEqual(prefixLen, [apvPrefix length]);
    
    // Extract prefix from apv data
    NSData *prefixFromApv = [apvData subdataWithRange:NSMakeRange(sizeof(int), prefixLen)];
    XCTAssertEqualObjects([apvPrefix dataUsingEncoding:NSUTF8StringEncoding], prefixFromApv);
    
    // Check if apv data contains the public key
    NSData *publicKeyData = CFBridgingRelease(SecKeyCopyExternalRepresentation(self.eccPublicKey, NULL));
    
    // Extract STK public key from APV
    NSData *eccKeyLengthInApv = [apvData subdataWithRange:NSMakeRange(sizeof(int) + prefixLen , sizeof(int))];
    eccKeyLengthInApv = [self convertToLittleEndian:eccKeyLengthInApv];
    NSUInteger eccKeyLengthInApvInt = [self convertHexBytesToInt:eccKeyLengthInApv];
    XCTAssertEqual(eccKeyLengthInApvInt, publicKeyData.length);
    
    NSData *stkPublicKeyFromApv = [apvData subdataWithRange:NSMakeRange(sizeof(int) + prefixLen + sizeof(int), eccKeyLengthInApvInt)];
    XCTAssertEqualObjects(stkPublicKeyFromApv, publicKeyData);
    
    // Extract nonce length from apv data
    NSData *nonceLengthInApv = [apvData subdataWithRange:NSMakeRange(sizeof(int) + prefixLen + sizeof(int) + eccKeyLengthInApvInt, sizeof(int))];
    nonceLengthInApv = [self convertToLittleEndian:nonceLengthInApv];
    NSUInteger nonceLengthInApvInt = [self convertHexBytesToInt:nonceLengthInApv];
    XCTAssertEqual(nonceLengthInApvInt, [NSUUID UUID].UUIDString.length);
    
    // Extract nonce from apv data
    NSData *nonceFromApv = [apvData subdataWithRange:NSMakeRange(sizeof(int) + prefixLen + sizeof(int) + eccKeyLengthInApvInt + sizeof(int), nonceLengthInApvInt)];
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDBytes:nonceFromApv.bytes];
    XCTAssertNotNil(uuid);
}

- (void)testGenerateJweCryptoWithTransportKey_PrivateKey_shouldReturnError
{
    NSError *error = nil;
    NSString *apvPrefix = @"MsalClient";
    MSIDEcdhApv *ecdhPartyVInfoData = [[MSIDEcdhApv alloc] initWithKey:self.eccPrivateKey apvPrefix:apvPrefix context:nil error:&error];
    XCTAssertNil(ecdhPartyVInfoData);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"Supplied key should be a public EC key. Could not export EC key data.");
}

- (void)testGenerateJweCryptoWithTransportKey_invalidPublicKey_shouldReturnError
{
    // Generate RSA public key pair using SecKeyGeeneratePair
    NSDictionary *parameters = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
        (id)kSecAttrKeySizeInBits: @(2048),
        (id)kSecPrivateKeyAttrs: @{(id)kSecAttrIsPermanent: @NO}
    };

    SecKeyRef privateKey = NULL;

    CFErrorRef error = NULL;
    // Generate the key pair
    privateKey = (__bridge SecKeyRef)CFBridgingRelease(SecKeyCreateRandomKey((__bridge CFDictionaryRef)parameters, &error));
    XCTAssertTrue(privateKey != NULL);
    
    SecKeyRef invalidKey = SecKeyCopyPublicKey(privateKey);
    NSString *apvPrefix = @"MsalClient";
    NSError *cryptoerror = nil;
    MSIDEcdhApv *ecdhPartyVInfoData = [[MSIDEcdhApv alloc] initWithKey:invalidKey apvPrefix:apvPrefix context:nil error:&cryptoerror];
    XCTAssertNil(ecdhPartyVInfoData);
    XCTAssertNotNil(cryptoerror);
    XCTAssertEqualObjects(cryptoerror.userInfo[@"MSIDErrorDescriptionKey"], @"Supplied key is not a EC P-256 key.");
}

- (void)testGenerateJweCryptoWithTransportKey_invalidApvPrefix_shouldReturnError
{
    NSError *error = nil;
    MSIDEcdhApv *ecdhPartyVInfoData = [[MSIDEcdhApv alloc] initWithKey:self.eccPublicKey apvPrefix:@"" context:nil error:&error];
    XCTAssertNil(ecdhPartyVInfoData);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"APV prefix is not defined. A prefix must be provided to determine calling application type.");
}

- (void)testGenerateEcdhApv_withNilArguments_shouldError
{
    NSError *error = nil;
    self.eccPublicKey = nil;
    MSIDEcdhApv *ecdhPartyVInfoData = [[MSIDEcdhApv alloc] initWithKey:self.eccPublicKey apvPrefix:@"" context:nil error:&error];
    XCTAssertNil(ecdhPartyVInfoData);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"Public STK provided is not defined.");
    
    self.eccPublicKey = [self.generator eccPublicKey];
    ecdhPartyVInfoData = [[MSIDEcdhApv alloc] initWithKey:self.eccPublicKey apvPrefix:@"" context:nil error:&error];
    XCTAssertNil(ecdhPartyVInfoData);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"APV prefix is not defined. A prefix must be provided to determine calling application type.");
}

- (void)testGenerateJweCrypto_withNilArguments_shouldError
{
    NSError *error = nil;
    MSIDEcdhApv *ecdhPartyVInfoData = [[MSIDEcdhApv alloc] initWithKey:self.eccPublicKey apvPrefix:@"MsalClient" context:nil error:&error];
    XCTAssertNotNil(ecdhPartyVInfoData);
    XCTAssertNil(error);
    NSString *nilArgument = nil;
    MSIDJWECrypto *jweCrypto = [[MSIDJWECrypto alloc] initWithKeyExchangeAlg:nilArgument
                                                         encryptionAlgorithm:MSID_JWT_ALG_A256GCM
                                                                         apv:ecdhPartyVInfoData
                                                                     context:nil
                                                                       error:&error];
    XCTAssertNil(jweCrypto);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"JWE crypto generation failed: Key exchange algorithm is nil or blank");
    
    jweCrypto = [[MSIDJWECrypto alloc] initWithKeyExchangeAlg:MSID_JWT_ALG_ECDH
                                          encryptionAlgorithm:nilArgument
                                                          apv:ecdhPartyVInfoData
                                                      context:nil
                                                        error:&error];
    XCTAssertNil(jweCrypto);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"JWE crypto generation failed: Encryption algorithm is nil or blank");
    MSIDEcdhApv *apv = nil;
    jweCrypto = [[MSIDJWECrypto alloc] initWithKeyExchangeAlg:MSID_JWT_ALG_ECDH
                                          encryptionAlgorithm:MSID_JWT_ALG_A256GCM
                                                          apv:apv
                                                      context:nil
                                                        error:&error];
    XCTAssertNil(jweCrypto);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"JWE crypto generation failed: APV is nil");
    
    jweCrypto = [[MSIDJWECrypto alloc] initWithKeyExchangeAlg:@"ABCD"
                                          encryptionAlgorithm:MSID_JWT_ALG_A256GCM
                                                          apv:ecdhPartyVInfoData
                                                      context:nil
                                                        error:&error];
    XCTAssertNil(jweCrypto);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"JWE crypto generation failed: Unsupported key exchange algorithm ABCD");
    
    jweCrypto = [[MSIDJWECrypto alloc] initWithKeyExchangeAlg:MSID_JWT_ALG_ECDH
                                          encryptionAlgorithm:@"ABCD"
                                                          apv:ecdhPartyVInfoData
                                                      context:nil
                                                        error:&error];
    XCTAssertNil(jweCrypto);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"JWE crypto generation failed: Unsupported encryption algorithm ABCD");
    
}

#pragma mark - Helper methods
- (NSData *)convertToLittleEndian:(NSData *)data
{
    NSUInteger length = [data length];
    NSMutableData *littleEndianData = [NSMutableData dataWithLength:length];
    const uint8_t *bytes = [data bytes];
    uint8_t *reversedBytes = [littleEndianData mutableBytes];
    
    for (NSUInteger i = 0; i < length; i++) {
        reversedBytes[i] = bytes[length - i - 1];
    }
    
    return [littleEndianData copy];
}

- (NSInteger)convertHexBytesToInt:(NSData *)data
{
    const uint8_t *bytes = [data bytes];
    NSUInteger length = [data length];
    NSInteger result = 0;

    for (NSUInteger i = 0; i < length; i++) {
        result = (result << 8) | bytes[i];
    }

    return result;
}

@end
