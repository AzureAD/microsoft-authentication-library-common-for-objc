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

#import "MSIDAssymetricKeyPair.h"

@implementation MSIDAssymetricKeyPair

- (nullable instancetype)initWithPrivateKey:(SecKeyRef)privateKey
                                  publicKey:(SecKeyRef)publicKey
{
    if (!privateKey || !publicKey)
    {
        return nil;
    }
    
    self = [super init];
    
    if (self)
    {
        _privateKeyRef = privateKey;
        CFRetain(_privateKeyRef);
        
        _publicKeyRef = publicKey;
        CFRetain(_publicKeyRef);
    }
    
    return self;
}

- (NSString *)keyExponent
{
    NSData *publicKeyBits = self.keyData;
    if (!publicKeyBits)
    {
        return nil;
    }
    
    int iterator = 0;
    
    iterator++; // TYPE - bit stream - mod + exp
    [self derEncodingGetSizeFrom:publicKeyBits at:&iterator]; // Total size
    
    iterator++; // TYPE - bit stream mod
    int mod_size = [self derEncodingGetSizeFrom:publicKeyBits at:&iterator];
    iterator += mod_size;
    
    iterator++; // TYPE - bit stream exp
    int exp_size = [self derEncodingGetSizeFrom:publicKeyBits at:&iterator];
    
    return [[publicKeyBits subdataWithRange:NSMakeRange(iterator, exp_size)] base64EncodedStringWithOptions:0];
}

- (NSString *)keyModulus
{
    NSData *publicKeyBits = self.keyData;
    if (!publicKeyBits)
    {
        return nil;
    }
    
    int iterator = 0;
    
    iterator++; // TYPE - bit stream - mod + exp
    [self derEncodingGetSizeFrom:publicKeyBits at:&iterator]; // Total size
    
    iterator++; // TYPE - bit stream mod
    int mod_size = [self derEncodingGetSizeFrom:publicKeyBits at:&iterator];
    NSData *subData=[publicKeyBits subdataWithRange:NSMakeRange(iterator, mod_size)];
    NSString *mod = [[subData subdataWithRange:NSMakeRange(1, subData.length-1)] base64EncodedStringWithOptions:0];
    return mod;
}

- (int)derEncodingGetSizeFrom:(NSData *)buf at:(int *)iterator
{
    const uint8_t *data = [buf bytes];
    int itr = *iterator;
    int num_bytes = 1;
    int ret = 0;
    
    if (data[itr] > 0x80)
    {
        num_bytes = data[itr] - 0x80;
        itr++;
    }
    
    for (int i = 0 ; i < num_bytes; i++)
    {
        ret = (ret * 0x100) + data[itr + i];
    }
    
    *iterator = itr + num_bytes;
    return ret;
}

- (NSData *)keyData
{
    CFErrorRef keyExtractionError = NULL;
    if (@available(iOS 10.0, macOS 10.12, *))
    {
        NSData *keyData = (NSData *)CFBridgingRelease(SecKeyCopyExternalRepresentation(self.publicKeyRef, &keyExtractionError));
        
        if (!keyData)
        {
            NSError *error = CFBridgingRelease(keyExtractionError);
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to read data from key ref %@", error);
            return nil;
        }
        
        return keyData;
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to extract key data from SecKeyRef due to unsupported platform");
        return nil;
    }
}

- (nullable NSString *)encryptForTest:(nonnull NSString *)messageString {
    NSData * message = [[NSData alloc] initWithBase64EncodedString:messageString options:0];
    
    if ([message length] == 0) {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Message to encrypt was empty");
        return nil;
    }

    if (@available(macOS 10.12, *)) {
        SecKeyAlgorithm algorithm = kSecKeyAlgorithmRSAEncryptionOAEPSHA1;
        
        if (!SecKeyIsAlgorithmSupported(_publicKeyRef, kSecKeyOperationTypeEncrypt, algorithm)) {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to use the requested crypto algorithm with the provided key.");
            return nil;
        }

        CFErrorRef error = nil;
        NSData *encryptedBlobBytes = (NSData *)CFBridgingRelease(
            SecKeyCreateEncryptedData(_publicKeyRef, algorithm, (__bridge CFDataRef)message, &error));
        if (error) {
            NSError *err = CFBridgingRelease(error);
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", [@"Unable to encrypt data" stringByAppendingString:[NSString stringWithFormat:@"%ld", err.code]]);
            return nil;
        }
        return [encryptedBlobBytes base64EncodedStringWithOptions:0];
    } else {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to use the requested crypto algorithm with the provided key.");
        return nil;
    }
}

- (nullable NSData *)decrypt:(nonnull NSString *)encryptedMessageString {
    NSData *encryptedMessage = [[NSData alloc] initWithBase64EncodedString:encryptedMessageString options:0];

    if ([encryptedMessage length] == 0) {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Message to encrypt was empty");
        return nil;
    }

    if (@available(macOS 10.12, *)) {
        SecKeyAlgorithm algorithm = kSecKeyAlgorithmRSAEncryptionOAEPSHA1;

        if (!SecKeyIsAlgorithmSupported(_privateKeyRef, kSecKeyOperationTypeDecrypt, algorithm)) {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to use the requested crypto algorithm with the provided key.");
            return nil;
        }

        CFErrorRef error = nil;
        NSData * decryptedMessage = (NSData *)CFBridgingRelease(
            SecKeyCreateDecryptedData(_privateKeyRef, algorithm, (__bridge CFDataRef)encryptedMessage, &error));

        if (error) {
            NSError *err = CFBridgingRelease(error);
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", [@"Unable to decrypt data" stringByAppendingString:[NSString stringWithFormat:@"%ld", err.code]]);
            return nil;
        }
        
        return decryptedMessage;
    } else {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to use the requested crypto algorithm with the provided key.");
        return nil;
    }
}

- (void)dealloc
{
    if (_privateKeyRef)
    {
        CFRelease(_privateKeyRef);
        _privateKeyRef = NULL;
    }
    
    if (_publicKeyRef)
    {
        CFRelease(_publicKeyRef);
        _publicKeyRef = NULL;
    }
}

@end
