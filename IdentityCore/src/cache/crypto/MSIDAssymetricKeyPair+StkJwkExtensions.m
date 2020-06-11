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

#import "MSIDAssymetricKeyPair+StkJwkExtensions.h"

#import "MSIDJsonObject.h"
#import "NSData+MSIDAssymetricKeyPairExtensions.h"

@implementation MSIDAssymetricKeyPair (StkJwkExtensions)

- (nullable NSString *)generateStkJwk {
    NSString * modulus;
    NSString * exponent;
    if (![self extractRawKeys:&modulus exponent:&exponent])
    {
        return nil;
    }
    
    return [self formatAsJsonWebKey:@"RSA" modulus:modulus exponent:exponent];
}

// MacOS supports exporting public keys as a DER ASN.1 sequence.
// A stkjwk can be created by exporting the modulus and exponent based on DER ASN.1 standards.
// Documentation on the byte structure of DER ASN.1 encoding for the purpose of modulus and exponent parsing for an RSA
// key is as follows:
//   [1 byte sequence tag] [3 byte longform sequenceLength]
//     [1 byte integer indicator] [3 byte longform modulusLength] [modulusLength sized modulusValue]
//     [1 byte integer indicator] [1 byte shortform exponentLength] [exponentLength sized exponentValue]
// Notes on expecations of this data format:
//   sequence tag and length: these are used for internal memory management of a DER ASN.1 data structure
//                 modulus: For a 2048 bit RSA key, if the modulus is encoded as a positive number, a 256 byte public key will be
//                          prefixed with an one empty byte. This empty byte prefix is for internal memory management, and can be simply
//                          stripped off for the purposes of exporting the modulus.
//                exponent: this is always expected to be "AQAB" for RSA public keys
//   shortform vs longform: two different types of lengths (1 or two bytes) that describe a values are supported in DER ASN.1 encoding:
//                          - lengths shorter then 127 are simply encoded as a 1 byte int
//                          - lengths larger then 126 are 3 bytes long broken into two parts: [1 prefix byte set to 127][a 2 byte int]
// More details on the DER ASN.1 encoding can be found at:
// https://docs.microsoft.com/en-us/windows/win32/seccertenroll/about-sequence
- (bool)extractRawKeys:(NSString **)modulus
              exponent:(NSString **)exponent {
    // TODO: Code Reviewers: Is there a recommended code pattern for @available for macOS and iOS?
    if (@available(macOS 10.12, *)) {
        CFErrorRef error = nil;
        NSData *publicKey = (NSData *)CFBridgingRelease(SecKeyCopyExternalRepresentation(_publicKeyRef, &error));
        if (error) {
            // TODO: Code Reviewers: What is the best way to propogate error information up the stack to get captured in telemetry? Is it MSID_LOG_WITH_CTX?
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to copy external representation for a public key.");
            return false;
        }
        
        int sizeOfShortFormInt = 1;
        int sizeOfLongFormInt = 2; /* note that long form ints are prefixed with a 1 byte indicator */
        int modulusLengthStartsAt = 1 /* sequence tag */ + 1 /* long form size prefix */ + sizeOfLongFormInt /* sequence size */
                                  + 1 /* integer indicator */ + 1 /* byte that indicates long form */;
        
        int modulusLength = [publicKey convertByteRangeToInt:modulusLengthStartsAt numberOfBytesToRead:sizeOfLongFormInt];
    
        int modulusValueStartsAt = modulusLengthStartsAt + sizeOfLongFormInt;
        if (modulusLength == 257) {
            // validate there is an empty one byte prefix inside of a 257 byte modulus
            if (![@"AA==" isEqualToString:[publicKey convertByteRangeToBase64String:modulusValueStartsAt numberOfBytesToRead:1]]) {
                MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Expected an empty byte to prefix a 257 byte modulus.");
                return false;
            }

            modulusValueStartsAt++; /* skip empty one byte prefix */
            modulusLength--;        /* extract 1 fewer bytes, from 257 down to 256 */
        }
        
        if (modulusLength != 256) {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unexpected modulus size: %d", modulusLength);
            return false;
        }

        *modulus = [publicKey convertByteRangeToBase64String:modulusValueStartsAt numberOfBytesToRead:modulusLength];
        
        int exponentLengthStartsAt = modulusValueStartsAt + modulusLength
                                   + 1 /* integer indicator */ /* note that there is no 1 byte for short form */;
        
        int exponentLength = [publicKey convertByteRangeToInt:exponentLengthStartsAt numberOfBytesToRead:sizeOfShortFormInt];
        if (exponentLength != 3) {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unexpected exponent size: %d", exponentLength);
            return false;
        }

        int exponentValueStartsAt = exponentLengthStartsAt + sizeOfShortFormInt;
        *exponent = [publicKey convertByteRangeToBase64String:exponentValueStartsAt numberOfBytesToRead:exponentLength];
        if (![*exponent isEqualToString:@"AQAB"]) {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unexpected public key exponent %@", *exponent);
            return false;
        }

        if ((int)[publicKey length] != exponentValueStartsAt + exponentLength) {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to export modulus and exponent from MacOS public key.");
            return false;
        }
        
        return *modulus != nil && *exponent != nil;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to create an RSA public key due to missing platform api support.");
    return false;
}

- (nullable NSString *)formatAsJsonWebKey:(NSString *)keyType
                                  modulus:(NSString *)modulus
                                 exponent:(NSString *)exponent {
    NSMutableDictionary *stkJwk = [NSMutableDictionary new];
    stkJwk[@"kty"] = keyType;
    stkJwk[@"n"] = modulus;
    stkJwk[@"e"] = exponent;

    NSError *nsError;
    MSIDJsonObject *json = [[MSIDJsonObject alloc] initWithJSONDictionary:stkJwk error:&nsError];

    if (nsError) {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to create the stk jwk json: %ld.", nsError.code);
        return nil;
    }

    NSData *serialize = [json serialize:&nsError];
    if (nsError) {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to serialize the stk jwk: %ld.", nsError.code);
        return nil;
    }

    return [[NSString alloc] initWithData:serialize encoding:NSASCIIStringEncoding];
}

@end
