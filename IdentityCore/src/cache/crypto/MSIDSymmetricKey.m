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

#include "MSIDSymmetricKey.h"

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>

@implementation MSIDSymmetricKey

- (nullable instancetype)initWithSymmetericKeyBytes:(NSData *)symmetericKey {
    if (!symmetericKey)
    {
        return nil;
    }
    
    self = [super init];
    
    if (self)
    {
        _symmetericKey = symmetericKey;
    }
    
    return self;
}

- (nullable NSString *)createVerifySignature:(NSData *)context
                                  dataToSign:(NSString *)dataToSign {
    NSData *data = [dataToSign dataUsingEncoding:NSUTF8StringEncoding];
    NSData *derivedKey = [self computeKDFInCounterMode:context];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256,
           derivedKey.bytes,
           derivedKey.length,
           [data bytes],
           [data length],
           cHMAC);
    NSData *signedData = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];

    return [NSString msidBase64UrlEncodedStringFromData:signedData];
}

- (NSData *)computeKDFInCounterMode:(NSData *)ctx
{
    NSData *labelData = [@"AzureAD-SecureConversation" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *mutData = [NSMutableData new];
    [mutData appendBytes:labelData.bytes length:labelData.length];
    Byte bytes[] = {0x00};
    [mutData appendBytes:bytes length:1];
    [mutData appendBytes:ctx.bytes length:ctx.length];
    int32_t size = CFSwapInt32HostToBig(256); //make big-endian
    [mutData appendBytes:&size length:sizeof(size)];
    
    uint8_t *pbDerivedKey = [self KDFCounterMode:(uint8_t*)_symmetericKey.bytes
                          keyDerivationKeyLength:_symmetericKey.length
                                      fixedInput:(uint8_t*)mutData.bytes
                                fixedInputLength:mutData.length];
    mutData = nil;
    NSData *dataToReturn = [NSData dataWithBytes:(const void *)pbDerivedKey length:32];
    free(pbDerivedKey);
    
    return dataToReturn;
}


- (uint8_t*) KDFCounterMode:(uint8_t*) keyDerivationKey
     keyDerivationKeyLength:(size_t) keyDerivationKeyLength
                 fixedInput:(uint8_t*) fixedInput
           fixedInputLength:(size_t) fixedInputLength
{
    uint8_t ctr;
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    uint8_t *keyDerivated;
    uint8_t *dataInput;
    int len;
    int numCurrentElements;
    int numCurrentElements_bytes;
    int outputSizeBit = 256;
    
    numCurrentElements = 0;
    ctr = 1;
    keyDerivated = (uint8_t*)malloc(outputSizeBit/8); //output is 32 bytes
    
    do{
        
        //update data using "ctr"
        dataInput =  [self updateDataInput:ctr
                                fixedInput:fixedInput
                         fixedInput_length:fixedInputLength];
        
        CCHmac(kCCHmacAlgSHA256,
               keyDerivationKey,
               keyDerivationKeyLength,
               dataInput,
               (fixedInputLength+4), //+4 to account for ctr
               cHMAC);
        
        //decide how many bytes (so the "length") copy for currently keyDerivated?
        if (256 >= outputSizeBit) {
            len = outputSizeBit;
        } else {
            len = MIN(256, outputSizeBit - numCurrentElements);
        }
        
        //convert bits in byte
        numCurrentElements_bytes = numCurrentElements/8;
        
        //copy KI in part of keyDerivated
        memcpy((keyDerivated + numCurrentElements_bytes), cHMAC, 32);
        
        //increment ctr and numCurrentElements copied in keyDerivated
        numCurrentElements = numCurrentElements + len;
        ctr++;
        
        //deallock space in memory
        free(dataInput);
        
    } while (numCurrentElements < outputSizeBit);
    
    return keyDerivated;
}


/*
 *Function used to shift data of 1 byte. This byte is the "ctr".
 */
- (uint8_t*)updateDataInput:(uint8_t) ctr
                 fixedInput:(uint8_t*) fixedInput
          fixedInput_length:(size_t) fixedInput_length
{
    uint8_t *tmpFixedInput = (uint8_t *)malloc(fixedInput_length + 4); //+4 is caused from the ct
    
    tmpFixedInput[0] = (ctr >> 24);
    tmpFixedInput[1] = (ctr >> 16);
    tmpFixedInput[2] = (ctr >> 8);
    tmpFixedInput[3] = ctr;
    
    memcpy(tmpFixedInput + 4, fixedInput, fixedInput_length  * sizeof(uint8_t));
    return tmpFixedInput;
}

- (nonnull NSString *)getRaw {
    return [_symmetericKey base64EncodedStringWithOptions:0];
}

@end
