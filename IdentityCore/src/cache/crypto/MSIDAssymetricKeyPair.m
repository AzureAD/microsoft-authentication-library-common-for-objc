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
#import "NSData+MSIDExtensions.h"

static NSString *s_jwkTemplate = @"{\"e\":\"%@\",\"kty\":\"RSA\",\"n\":\"%@\"}";
static NSString *s_kidTemplate = @"{\"kid\":\"%@\"}";

@interface MSIDAssymetricKeyPair()

@property (nonatomic) NSString *keyExponent;
@property (nonatomic) NSString *keyModulus;
@property (nonatomic) NSData *keyData;
@property (nonatomic) NSString *jsonWebKey;
@property (nonatomic) NSString *kid;
@property (nonatomic) NSString *stkJwk;
@property (nonatomic) NSDate *creationDate;

@end

@implementation MSIDAssymetricKeyPair

- (nullable instancetype)initWithPrivateKey:(SecKeyRef)privateKey
                                  publicKey:(SecKeyRef)publicKey
                               creationDate:(NSDate *)creationDate
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
        _creationDate = creationDate;
    }
    
    return self;
}

- (NSString *)keyExponent
{
    if (!_keyExponent)
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
        
        _keyExponent = [[publicKeyBits subdataWithRange:NSMakeRange(iterator, exp_size)] base64EncodedStringWithOptions:0];
    }
    
    return _keyExponent;
}

- (NSString *)keyModulus
{
    if (!_keyModulus)
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
        _keyModulus = [[subData subdataWithRange:NSMakeRange(1, subData.length-1)] base64EncodedStringWithOptions:0];
    }
    
    return _keyModulus;
}

/// <summary>
/// Example JWK Thumbprint Computation
/// </summary>
/// <remarks>
/// This SDK will use RFC7638
/// See https://tools.ietf.org/html/rfc7638 Section3.1
/// </remarks>
- (NSString *)jsonWebKey
{
    if (!_jsonWebKey)
    {
        NSString *kid = [NSString stringWithFormat:s_kidTemplate, self.kid];
        if (!kid)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError,nil, @"Failed to create req_cnf from kid");
            return nil;
        }
        
        NSData *kidData = [kid dataUsingEncoding:NSUTF8StringEncoding];
        _jsonWebKey = [kidData msidBase64UrlEncodedString];
    }
    
    return _jsonWebKey;
}

- (NSString *)kid
{
    if (!_kid)
    {
        NSData *jwkData = [self.stkJwk dataUsingEncoding:NSUTF8StringEncoding];
        NSData *hashedData = [jwkData msidSHA256];
        _kid = [hashedData msidBase64UrlEncodedString];
    }
    
    return _kid;
}

- (NSString *)stkJwk
{
    if (!_stkJwk)
    {
        _stkJwk = [NSString stringWithFormat:s_jwkTemplate, self.keyExponent, self.keyModulus];
    }
    
    return _stkJwk;
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
    if (!_keyData)
    {
        CFErrorRef keyExtractionError = NULL;
        if (@available(iOS 10.0, macOS 10.12, *))
        {
            _keyData = (NSData *)CFBridgingRelease(SecKeyCopyExternalRepresentation(self.publicKeyRef, &keyExtractionError));
            
            if (!_keyData)
            {
                NSError *error = CFBridgingRelease(keyExtractionError);
                MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to read data from key ref %@", error);
                return nil;
            }
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to extract key data from SecKeyRef due to unsupported platform");
        }
    }
    
    return _keyData;
}

- (nullable NSData *)decrypt:(nonnull NSString *)encryptedMessageString
{
    NSData *encryptedMessage = [[NSData alloc] initWithBase64EncodedString:encryptedMessageString options:0];

    if ([encryptedMessage length] == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Message to encrypt was empty");
        return nil;
    }
    
    if (@available(iOS 10.0, macOS 10.12, *))
    {
        return [encryptedMessage msidDecryptedDataWithAlgorithm:kSecKeyAlgorithmRSAEncryptionOAEPSHA1 privateKey:self.privateKeyRef];
    }
    else
    {
        return nil;
    }
}

- (NSString *)signData:(NSString *)message
{
    NSData *signedData = [[message dataUsingEncoding:NSUTF8StringEncoding] msidSignHashWithPrivateKey:self.privateKeyRef];
    return [[NSString alloc] initWithData:signedData encoding:NSUTF8StringEncoding];
}

- (NSDate *)creationDate
{
    if (!_creationDate)
    {
        NSDictionary* publicKeyQuery = @{ (id)kSecValueRef: (__bridge id)self.publicKeyRef,
         (id)kSecClass: (id)kSecClassKey,
         (id)kSecReturnAttributes:(id)kCFBooleanTrue
        };
        
        CFDictionaryRef result = nil;
        OSStatus status = SecItemCopyMatching((CFDictionaryRef)publicKeyQuery, (CFTypeRef *)&result);
        
        if (status != errSecSuccess)
        {
            return nil;
        }
        
        NSDictionary *attributeDict = CFBridgingRelease(result);
        _creationDate = [attributeDict objectForKey:(__bridge NSDate *)kSecAttrCreationDate];
    }
    
    return _creationDate;
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
