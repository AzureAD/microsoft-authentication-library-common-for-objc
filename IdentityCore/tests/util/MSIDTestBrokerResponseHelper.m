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

#import "MSIDTestBrokerResponseHelper.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import "MSIDConstants.h"

@implementation MSIDTestBrokerResponseHelper

+ (NSURL *)createLegacyBrokerResponse:(NSDictionary *)parameters
                          redirectUri:(NSString *)redirectUri
                        encryptionKey:(NSData *)encryptionKey
{
    NSDictionary *message = [self createLegacyBrokerResponseDictionary:parameters encryptionKey:encryptionKey];
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", redirectUri, [message msidURLEncode]]];
}

+ (NSURL *)createLegacyBrokerErrorResponse:(NSDictionary *)parameters
                               redirectUri:(NSString *)redirectUri
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", redirectUri, [parameters msidURLEncode]]];
}

+ (NSDictionary *)createLegacyBrokerResponseDictionary:(NSDictionary *)parameters
                                         encryptionKey:(NSData *)brokerKey
{
    NSData *payload = [[parameters msidWWWFormURLEncode] dataUsingEncoding:NSUTF8StringEncoding];

    size_t bufferSize = [payload length] + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesEncrypted = 0;

    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          [brokerKey bytes], kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [payload bytes], [payload length], /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesEncrypted);
    if (cryptStatus != kCCSuccess)
    {
        return nil;
    }

    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256([payload bytes], (CC_LONG)[payload length], hash);
    NSMutableString *fingerprint = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 3];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i)
    {
        [fingerprint appendFormat:@"%02x", hash[i]];
    }

    NSDictionary *message =
    @{
      @"msg_protocol_ver" : @"2",
      @"response" :  [NSString msidBase64UrlEncodedStringFromData:[NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted]],
      @"hash" : [fingerprint uppercaseString],
      };

    return message;
}

#pragma mark - Default Broker response

+ (NSURL *)createDefaultBrokerResponse:(NSDictionary *)parameters
                           redirectUri:(NSString *)redirectUri
                         encryptionKey:(NSData *)encryptionKey
{
    NSDictionary *message = [self createDefaultBrokerResponseDictionary:parameters encryptionKey:encryptionKey];
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", redirectUri, [message msidWWWFormURLEncode]]];
}

+ (NSDictionary *)createDefaultBrokerResponseDictionary:(NSDictionary *)parameters
                                          encryptionKey:(NSData *)brokerKey
{
    NSData *payload = [[parameters msidWWWFormURLEncode] dataUsingEncoding:NSUTF8StringEncoding];
    
    size_t bufferSize = [payload length] + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesEncrypted = 0;
    
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          [brokerKey bytes], kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [payload bytes], [payload length], /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesEncrypted);
    if (cryptStatus != kCCSuccess)
    {
        return nil;
    }
    
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256([payload bytes], (CC_LONG)[payload length], hash);
    NSMutableString *fingerprint = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 3];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i)
    {
        [fingerprint appendFormat:@"%02x", hash[i]];
    }
    
    NSDictionary *message =
    @{
      @"msg_protocol_ver" : @"3",
      @"response" :  [NSString msidBase64UrlEncodedStringFromData:[NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted]],
      @"hash" : [fingerprint uppercaseString],
      };
    
    return message;
}

@end
