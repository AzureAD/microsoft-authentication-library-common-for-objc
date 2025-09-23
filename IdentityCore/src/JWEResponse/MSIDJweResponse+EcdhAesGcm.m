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


#import <Foundation/Foundation.h>
#import "MSIDJweResponse+EcdhAesGcm.h"
#import "MSIDJWECrypto.h"
#import "MSIDJweResponse.h"
#import "NSData+MSIDExtensions.h"
#import "NSData+MSIDEccSecKeyRef.h"
#import "MSIDEcdhApv.h"
#import "MSIDJsonSerializer.h"
#import "IdentityCore-Swift.h"

MSIDJWECryptoKeyExchangeAlgorithm const MSID_KEY_EXCHANGE_ALGORITHM_ECDH_ES = @"ECDH-ES";
MSIDJWECryptoKeyResponseEncryptionAlgorithm const MSID_RESPONSE_ENCRYPTION_ALGORITHM_A256GCM = @"A256GCM";

@implementation MSIDJweResponse (EcdhAesGcm)

- (nullable NSDictionary *)decryptJweResponseWithPrivateStk:(nonnull SecKeyRef)privateStkRef
                                                  jweCrypto:(nonnull MSIDJWECrypto *)jweCrypto
                                                      error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    // 1. Check for necessary request parameters
    NSData *apv = [NSData msidDataFromBase64UrlEncodedString:jweCrypto.apv.APV];
    
    if (!apv.length)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected input parameters, no apv present in request JWE Crypto", nil, nil, nil, nil, nil, NO);
        }
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unexpected input parameters, no apv present in request JWE Crypto");
        return nil;
    }
    
    // 2. Check for necessary response parameters, epk, enc, apu
    NSDictionary *epk = self.jweHeader[@"epk"];
    
    if (![epk count]
        || ![epk isKindOfClass:[NSDictionary class]])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected server response, no epk present in JWE header", nil, nil, nil, nil, nil, NO);
        }
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unexpected server response, no epk present in JWE header, epk %@", epk);
        return nil;
    }
    
    NSString *encHeader = self.jweHeader[@"enc"];
    NSString *apuHeader = self.jweHeader[@"apu"];
    
    if ([NSString msidIsStringNilOrBlank:encHeader]
        || [NSString msidIsStringNilOrBlank:apuHeader])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected server response, no enc or apu present JWE header", nil, nil, nil, nil, nil, NO);
        }
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unexpected server response, no enc or apu present JWE header, enc %@, apu %@", encHeader, apuHeader);
        return nil;
    }
    
    if (![self IsJweResponseAlgorithmSupported:error])
    {
        return nil;
    }
    
    // 3. Create key from server response
    SecKeyRef serverKeyRef = [NSData createECCKeyFromEccJsonWebKey:epk error:error];
    
    if (!serverKeyRef)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Could not get EC public key from server JWE response payload.");
        return nil;
    }
    
    // 4. Calculate shared key through a key exchange
    // It performs a Diffie-Hellman key exchange (kSecKeyAlgorithmECDHKeyExchangeStandard) using the Device Encryption public key and the Ephemeral private key.
    NSData *sharedSecret = [self calculateSharedSecretUsingEcdhWithOtherPartyPublicEcKey:serverKeyRef
                                                                              privateStk:privateStkRef
                                                                                   error:error];
    
    if (!sharedSecret)
    {
        CFRelease(serverKeyRef);
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to calculate shared secret using ECDH");
        return nil;
    }
    
    // 5. Calculate derived key using ConcatKDF
    // ConcatKDF is performed using the key exchange result, algorithm, PartyUInfo, and PartyVInfo.
    NSData *algorithmId = [encHeader dataUsingEncoding:NSASCIIStringEncoding];
    NSData *apu = [NSData msidDataFromBase64UrlEncodedString:apuHeader];
    
    NSData *derivedKey = [self calculateDerivedKeyWithSharedKey:sharedSecret
                                                    algorithmId:algorithmId
                                                            apu:apu
                                                            apv:apv
                                                          error:error];
    
    if (!derivedKey)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to calculate derived key from shared secret using ConcatKDF");
        return nil;
    }
    
    // 6. Decrypt JWE using derived key as the AES GCM decryption key
    // The key from ConcatKDF is used along with the Initialization Vector, and the Additional Authentication Data (AAD) to encrypt the plain text using AESGCM.
    return [self decryptJweResponseUsingSymmetricKey:derivedKey error:error];
}

- (NSData *)calculateSharedSecretUsingEcdhWithOtherPartyPublicEcKey:(SecKeyRef)serverKeyRef
                                                         privateStk:(SecKeyRef)privateStkRef
                                                              error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    SecKeyAlgorithm algorithm = kSecKeyAlgorithmECDHKeyExchangeStandard;
    NSDictionary *attributes = @{(id)kSecKeyKeyExchangeParameterRequestedSize:@32};
    
    CFErrorRef cfError = NULL;
    NSData *sharedKey = (NSData *)CFBridgingRelease(SecKeyCopyKeyExchangeResult(privateStkRef, algorithm, serverKeyRef, (__bridge CFDictionaryRef)attributes, &cfError));
    
    if (!sharedKey)
    {
        NSError *nsError = CFBridgingRelease(cfError);
        
        if (error)
        {
            *error = nsError;
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to do key exchange with error %@", nsError);
        return nil;
    }
    
    return sharedKey;
}

- (NSData *)calculateDerivedKeyWithSharedKey:(NSData *)sharedSecret
                                 algorithmId:(NSData *)algorithmId
                                         apu:(NSData *)apu
                                         apv:(NSData *)apv
                                       error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    NSError *concatKDFError = nil;
    MSIDConcatKdfProvider *concatKDFProvider = [MSIDConcatKdfProvider new];
    NSData *derivedKey = [concatKDFProvider concatKDFWithSHA256WithSharedSecret:sharedSecret
                                                           outputKeyLen:32
                                                            algorithmId:algorithmId
                                                             partyUInfo:apu
                                                             partyVInfo:apv
                                                                  error:&concatKDFError];

    if (!derivedKey)
    {
        if (error)
        {
            *error = concatKDFError;
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to calculate ConcatKDF with error %@", concatKDFError);
        return nil;
    }
    
    return derivedKey;
}

- (NSDictionary *)decryptJweResponseUsingSymmetricKey:(NSData *)symmetricKey
                                                error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    if (!symmetricKey)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Symmetric key is nil", nil, nil, nil, nil, nil, NO);
        }
        return nil;
    }
    
    if (![self IsJweResponseAlgorithmSupported:error])
    {
        return nil;
    }
    
    // Since only A256GCM is supported, we can decrypt jwe message using AES256GCM.
    MSIDAesGcmDecryptor *decryptor = [MSIDAesGcmDecryptor new];
    NSData *decryptedData = [decryptor decryptWithAES256GCMHandlerWithMessage:self.payload iv:self.iv key:symmetricKey tag:self.tag aad:self.aad error:error];
    
    if (!decryptedData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected server response, failed to decrypt JWE", nil, nil, nil, nil, nil, NO);
        }
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unexpected server response, failed to decrypt JWE");
        return nil;
    }
    
    MSIDJsonSerializer *serializer = [MSIDJsonSerializer new];
    
    NSDictionary *jsonResult = [serializer deserializeJSON:decryptedData error:error];
    return jsonResult;
}

- (BOOL)IsJweResponseAlgorithmSupported:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    if (self.headerAlgorithm && ![self.headerAlgorithm isEqualToString:MSID_KEY_EXCHANGE_ALGORITHM_ECDH_ES])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, [NSString stringWithFormat:@"Unsupported JWE algorithm : %@", self.headerAlgorithm], nil, nil, nil, nil, nil, NO);
        }
        return NO;
    }
    
    if (![self.jweHeader[@"enc"] isEqualToString:MSID_RESPONSE_ENCRYPTION_ALGORITHM_A256GCM])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, [NSString stringWithFormat:@"Unsupported JWE encryption algorithm : %@", self.jweHeader[@"enc"]], nil, nil, nil, nil, nil, NO);
        }
        return NO;
    }
    
    return YES;
}
@end
