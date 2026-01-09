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

#import "MSIDBrokerCryptoProvider.h"
#import "NSData+MSIDAES.h"
#import "NSData+MSIDExtensions.h"
#import <CommonCrypto/CommonCrypto.h>
#import "NSData+MSIDExtensions.h"
#import "NSMutableDictionary+MSIDExtensions.h"
#import "MSIDLogger+Internal.h"

@interface MSIDBrokerCryptoProvider()

@property (nonatomic) NSData *encryptionKey;

@end

@implementation MSIDBrokerCryptoProvider

+ (NSString *)msidShortFingerprintForData:(NSData *)data
{
    if (!data.length) return @"<empty>";

    // Non-secret, non-reversible: SHA256 and truncate.
    NSString *fingerprint = [[[data msidSHA256] msidHexString] uppercaseString];
    return fingerprint.length > 8 ? [fingerprint substringToIndex:8] : fingerprint;
}

- (instancetype)initWithEncryptionKey:(NSData *)encryptionKey
{
    self = [super init];

    if (self)
    {
        _encryptionKey = encryptionKey;
    }

    return self;
}

- (NSDictionary *)decryptBrokerResponse:(NSDictionary *)response
                          correlationId:(NSUUID *)correlationId
                                  error:(NSError *__autoreleasing*)error
{
    NSString *hash = response[@"hash"];

    if (!hash)
    {
        MSIDFillAndLogError(error, MSIDErrorBrokerResponseHashMissing, @"Key hash is missing from the broker response", correlationId);
        return nil;
    }

    NSString *encryptedBase64Response = response[@"response"];
    NSString *msgVer = response[@"msg_protocol_ver"];

    NSInteger protocolVersion = msgVer ? [msgVer integerValue] : 1;

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Broker response decrypt starting (correlationId=%@, msg_protocol_ver=%@, parsedProtocolVersion=%ld, encryptedBase64Len=%lu, expectedHashLen=%lu).", correlationId.UUIDString, msgVer, (long)protocolVersion, (unsigned long)encryptedBase64Response.length, (unsigned long)hash.length);

    NSData *encryptedResponse = [NSData msidDataFromBase64UrlEncodedString:encryptedBase64Response];

    if (!encryptedResponse)
    {
         MSIDFillAndLogError(error, MSIDErrorBrokerCorruptedResponse, @"Encrypted response missing from broker response", correlationId);
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Broker response decrypt failed: base64url decode returned nil (correlationId=%@, encryptedBase64Len=%lu).", correlationId.UUIDString, (unsigned long)encryptedBase64Response.length);
         return nil;
    }
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Broker response base64url decoded (correlationId=%@, encryptedBytes=%lu, keyLen=%lu, keyFp=%@).", correlationId.UUIDString, (unsigned long)encryptedResponse.length, (unsigned long)self.encryptionKey.length, [MSIDBrokerCryptoProvider msidShortFingerprintForData:self.encryptionKey]);

    NSData *decrypted = [self decryptData:encryptedResponse protocolVersion:protocolVersion];

    if (!decrypted)
    {
         MSIDFillAndLogError(error, MSIDErrorBrokerResponseDecryptionFailed, @"Failed to decrypt broker message", correlationId);
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Broker response decrypt failed: AES decryption returned nil (correlationId=%@, encryptedBytes=%lu, keyLen=%lu, protocolVersion=%ld).", correlationId.UUIDString, (unsigned long)encryptedResponse.length, (unsigned long)self.encryptionKey.length, (long)protocolVersion);
         return nil;
    }
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Broker response decrypted bytes produced (correlationId=%@, decryptedBytes=%lu, decryptedFp=%@).", correlationId.UUIDString, (unsigned long)decrypted.length, [MSIDBrokerCryptoProvider msidShortFingerprintForData:decrypted]);

    NSString *decryptedString = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];

    if (!decryptedString)
    {
         NSString *asciiString = [[NSString alloc] initWithData:decrypted encoding:NSASCIIStringEncoding];
         BOOL asciiAlsoFailed = (asciiString == nil);
         MSIDFillAndLogError(error, MSIDErrorBrokerResponseDecryptionFailed, @"Failed to initialize decrypted string", correlationId);
         MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Broker response decrypt failed: decrypted bytes are not valid UTF-8 (correlationId=%@, decryptedBytes=%lu, asciiDecodeAlsoFailed=%@, protocolVersion=%ld, keyFp=%@, decryptedFp=%@).", correlationId.UUIDString, (unsigned long)decrypted.length, asciiAlsoFailed ? @"YES" : @"NO", (long)protocolVersion, [MSIDBrokerCryptoProvider msidShortFingerprintForData:self.encryptionKey], [MSIDBrokerCryptoProvider msidShortFingerprintForData:decrypted]);
         return nil;
    }

    //now compute the hash on the unencrypted data
    NSString *actualHash = [[[[decrypted msidSHA256] msidHexString] msidTrimmedString] uppercaseString];

    if (![hash isEqualToString:actualHash])
    {
         MSIDFillAndLogError(error, MSIDErrorBrokerResponseHashMismatch, @"Decrypted response does not match the hash", correlationId);
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Broker response decrypt failed: hash mismatch (correlationId=%@, expectedHashPrefix=%@, actualHashPrefix=%@, decryptedBytes=%lu, protocolVersion=%ld, keyFp=%@).", correlationId.UUIDString, hash.length > 8 ? [hash substringToIndex:8] : hash, actualHash.length > 8 ? [actualHash substringToIndex:8] : actualHash, (unsigned long)decrypted.length, (long)protocolVersion, [MSIDBrokerCryptoProvider msidShortFingerprintForData:self.encryptionKey]);
         return nil;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Broker response decrypt succeeded: UTF-8 decode + hash validated (correlationId=%@, decryptedStringLen=%lu).", correlationId.UUIDString, (unsigned long)decryptedString.length);

    // create response from the decrypted payload
    NSDictionary *decryptedResponse = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:decryptedString];
    return [decryptedResponse msidDictionaryWithoutNulls];
}

- (nullable NSData *)decryptData:(NSData *)response
                 protocolVersion:(NSUInteger)version
{
    const void *keyBytes = nil;
    size_t keySize = 0;

    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)

    if (version > 1)
    {
        keyBytes = [self.encryptionKey bytes];
        keySize = [self.encryptionKey length];
    }
    else
    {
        NSString *key = [[NSString alloc] initWithData:self.encryptionKey encoding:NSASCIIStringEncoding];
        bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
        // fetch key data
        [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
        keyBytes = keyPtr;
        keySize = kCCKeySizeAES256;
    }

    return [response msidAES128DecryptedDataWithKey:keyBytes keySize:keySize];
}

@end
