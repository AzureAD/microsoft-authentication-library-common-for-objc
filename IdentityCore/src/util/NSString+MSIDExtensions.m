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

#import <CommonCrypto/CommonDigest.h>
#import "NSString+MSIDExtensions.h"
#import "MSIDConstants.h"

typedef unsigned char byte;

static char base64UrlEncodeTable[64] =
{
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-', '_'
};

#define NA (255)

static byte rgbDecodeTable[128] = {                         // character code
    NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,  // 0-15
    NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,  // 16-31
    NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, 62, NA, NA,  // 32-47
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, NA, NA, NA,  0, NA, NA,  // 48-63
    NA,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,  // 64-79
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, NA, NA, NA, NA, 63,  // 80-95
    NA, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,  // 96-111
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, NA, NA, NA, NA, NA,  // 112-127
};

#define RANDOM_STRING_MAX_SIZE 1024

//Checks that all bytes inside the format are valid base64 characters:
static BOOL validBase64Characters(const byte* data, const int size)
{
    for (int i = 0; i < size; ++i)
    {
        if (data[i] >= sizeof(rgbDecodeTable) || rgbDecodeTable[data[i]] == NA)
        {
            return false;
        }
    }
    return true;
}

@implementation NSString (MSIDExtensions)

/// <summary>
/// Base64 URL decode a set of bytes.
/// </summary>
/// <remarks>
/// See RFC 4648, Section 5 plus switch characters 62 and 63 and no padding.
/// For a good overview of Base64 encoding, see http://en.wikipedia.org/wiki/Base64
/// </remarks>
+ (NSData *)msidBase64UrlDecodeData:(NSString *)encodedString
{
    if ( nil == encodedString )
    {
        return nil;
    }
    
    NSData      *encodedBytes = [encodedString dataUsingEncoding:NSUTF8StringEncoding];
    const byte  *pbEncoded    = [encodedBytes bytes];
    const int    cbEncoded    = (int)[encodedBytes length];
    if (!validBase64Characters(pbEncoded, cbEncoded))
    {
        return nil;
    }
    
    int   cbDecodedSize;
    int   ich;
    int   ib;
    byte  b0, b1, b2, b3;
    
    // The input string lacks the usual '=' padding at the end, so the valid end sequences
    // are:
    //      ........XX           (cbEncodedSize % 4) == 2    (2 chars of virtual padding)
    //      ........XXX          (cbEncodedSize % 4) == 3    (1 char of virtual padding)
    //      ........XXXX         (cbEncodedSize % 4) == 0    (no virtual padding)
    // Invalid sequences are:
    //      ........X            (cbEncodedSize % 4) == 1
    
    // Input string is not sized correctly to be base64 URL encoded.
    if ( ( 0 == cbEncoded ) || ( 1 == ( cbEncoded % 4 ) ) )
    {
        return nil;
    }
    
    // 'virtual padding' is how many trailing '=' characters we would have
    // had under 'normal' base-64 encoding
    int virtualPadding = ( ( cbEncoded % 4 ) == 2 ) ? 2 : ( ( cbEncoded % 4 ) == 3 ) ? 1 : 0;
    
    // Calculate decoded buffer size.
    cbDecodedSize = (cbEncoded + virtualPadding + 3) / 4 * 3;
    cbDecodedSize -= virtualPadding;
    
    byte *pbDecoded = (byte *)calloc( cbDecodedSize, sizeof(byte) );
    
    if(!pbDecoded) {
        return nil;
    }
    
    // Decode each four-byte cluster into the corresponding three data bytes,
    // allowing for the fact that the last cluster may be less than four bytes
    // (virtual padding).
    ich = ib = 0;
    
    int end4 = (cbEncoded/4)*4;
    //Quick loop, no boundary checks:
    for(; ich < end4; )
    {
        b0 = rgbDecodeTable[pbEncoded[ich++]];
        b1 = rgbDecodeTable[pbEncoded[ich++]];
        b2 = rgbDecodeTable[pbEncoded[ich++]];
        b3 = rgbDecodeTable[pbEncoded[ich++]];
        
        pbDecoded[ib++] = (b0 << 2) | (b1 >> 4);
        pbDecoded[ib++] = (b1 << 4) | (b2 >> 2);
        pbDecoded[ib++] = (b2 << 6) | b3;
    }
    
    //Beyond the padding to 4. Requires boundary checks,
    //but the inner side shouldn't be executed more than 3 times:
    while ( ich < cbEncoded )
    {
        b0 = rgbDecodeTable[pbEncoded[ich++]];
        b1 = (ich < cbEncoded) ? rgbDecodeTable[pbEncoded[ich++]] : 0;
        b2 = (ich < cbEncoded) ? rgbDecodeTable[pbEncoded[ich++]] : 0;
        b3 = (ich < cbEncoded) ? rgbDecodeTable[pbEncoded[ich++]] : 0;
        
        pbDecoded[ib++] = (b0 << 2) | (b1 >> 4);
        
        if (ib < cbDecodedSize) {
            pbDecoded[ib++] = (b1 << 4) | (b2 >> 2);
            
            if (ib < cbDecodedSize) {
                pbDecoded[ib++] = (b2 << 6) | b3;
            }
        }
    }
    
    // Place the result in a NSData object and then free it.
    NSData *result = [NSData dataWithBytes:pbDecoded length:cbDecodedSize];
    
    free( pbDecoded );
    
    return result;
}

- (NSString *)msidBase64UrlDecode
{
    NSData *decodedData = [self.class msidBase64UrlDecodeData:self];
    
    return [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
}

//Helper method to encode 3 bytes into a sequence of 4 bytes:
//"static inline" is the way declare inline methods in LLVM
static inline void Encode3bytesTo4bytes(char* output, int b0, int b1, int b2)
{
    output[0] = base64UrlEncodeTable[b0 >> 2];                                  // 6 MSB from byte 0
    output[1] = base64UrlEncodeTable[((b0 << 4) & 0x30) | ((b1 >> 4) & 0x0f)];  // 2 LSB from byte 0 and 4 MSB from byte 1
    output[2] = base64UrlEncodeTable[((b1 << 2) & 0x3c) | ((b2 >> 6) & 0x03)];  // 4 LSB from byte 1 and 2 MSB from byte 2
    output[3] = base64UrlEncodeTable[b2 & 0x3f];
}

/// <summary>
/// Base64 URL encode a set of bytes.
/// </summary>
/// <remarks>
/// See RFC 4648, Section 5 plus switch characters 62 and 63 and no padding.
/// For a good overview of Base64 encoding, see http://en.wikipedia.org/wiki/Base64
/// </remarks>
+ (NSString *)msidBase64UrlEncodeData:(NSData *)data
{
    if ( nil == data )
        return nil;
    
    const byte *pbBytes = [data bytes];
    int         cbBytes = (int)[data length];
    
    // Calculate encoded string size including padding. This may be more than is actually
    // required since we will not pad and instead will terminate with null. The computation
    // is the number of byte triples times 4 radix64 characters plus 1 for null termination.
    int   encodedSize = 1 + ( cbBytes + 2 ) / 3 * 4;
    char *pbEncoded = (char *)calloc( encodedSize, sizeof(char) );
    
    if(!pbEncoded){
        return nil;
    }
    
    // Encode data byte triplets into four-byte clusters.
    int   iBytes;      // raw byte index
    int   iEncoded;    // encoded byte index
    byte  b0, b1, b2;  // individual bytes for triplet
    
    iBytes = iEncoded = 0;
    
    int end3 = (cbBytes/3)*3;
    //Fast loop, no bounderies check:
    for ( ; iBytes < end3; )
    {
        b0 = pbBytes[iBytes++];
        b1 = pbBytes[iBytes++];
        b2 = pbBytes[iBytes++];
        
        Encode3bytesTo4bytes(pbEncoded + iEncoded, b0, b1, b2);
        iEncoded += 4;
    }
    
    //Slower loop should execute no more than 3 times:
    while ( iBytes < cbBytes )
    {
        b0 = pbBytes[iBytes++];
        b1 = (iBytes < cbBytes) ? pbBytes[iBytes++] : 0;                                        // Add extra zero byte if needed
        b2 = (iBytes < cbBytes) ? pbBytes[iBytes++] : 0;                                        // Add extra zero byte if needed
        
        Encode3bytesTo4bytes(pbEncoded + iEncoded, b0, b1, b2);
        iEncoded += 4;
    }
    
    // Where we would have padded it, we instead truncate the string
    switch ( cbBytes % 3 )
    {
        case 0:
            // No left overs, nothing to pad
            break;
            
        case 1:
            // One left over, normally pad 2
            pbEncoded[iEncoded - 2] = '\0';
            // fall through
            
        case 2:
            pbEncoded[iEncoded - 1] = '\0';
            break;
    }
    
    // Null terminate, convert to NSString and free the buffer
    pbEncoded[iEncoded++] = '\0';
    
    NSString *result = [NSString stringWithCString:pbEncoded encoding:NSUTF8StringEncoding];
    
    free(pbEncoded);
    
    return result;
}

// Base64 URL encodes a string
- (NSString *)msidBase64UrlEncode
{
    NSData *decodedData = [self dataUsingEncoding:NSUTF8StringEncoding];
    
    return [self.class msidBase64UrlEncodeData:decodedData];
}

+ (BOOL)msidIsStringNilOrBlank:(NSString *)string
{
    if (!string || [string isKindOfClass:[NSNull class]] || !string.length)
    {
        return YES;
    }
    
    static NSCharacterSet* nonWhiteCharSet;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        nonWhiteCharSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
    });
    
    return [string rangeOfCharacterFromSet:nonWhiteCharSet].location == NSNotFound;
}

- (NSString *)msidTrimmedString
{
    //The white characters set is cached by the system:
    NSCharacterSet* set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [self stringByTrimmingCharactersInSet:set];
}

- (NSString *)msidUrlFormDecode
{
    // Two step decode: first replace + with a space, then percent unescape
    CFMutableStringRef decodedString = CFStringCreateMutableCopy( NULL, 0, (__bridge CFStringRef)self );
    CFStringFindAndReplace( decodedString, CFSTR("+"), CFSTR(" "), CFRangeMake( 0, CFStringGetLength( decodedString ) ), kCFCompareCaseInsensitive );
    
    CFStringRef unescapedString = CFURLCreateStringByReplacingPercentEscapes( NULL,                    // Allocator
                                                                                          decodedString,           // Original string
                                                                                          CFSTR("")); // Encoding
    CFRelease( decodedString );
    
    return CFBridgingRelease(unescapedString);
}

- (NSString *)msidUrlFormEncode
{
    static NSCharacterSet* set = nil;
 
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSMutableCharacterSet *allowedSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [allowedSet addCharactersInString:@" "];
        [allowedSet removeCharactersInString:@"!$&'()*+,/:;=?@"];
        
        set = allowedSet;
    });
    
    NSString* encodedString = [self stringByAddingPercentEncodingWithAllowedCharacters:set];
    return [encodedString stringByReplacingOccurrencesOfString:@" " withString:@"+"];
}

- (NSData *)msalSHA256Data
{
    NSData *inputData = [self dataUsingEncoding:NSASCIIStringEncoding];
    NSMutableData *outData = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    
    // input length shouldn't be this big
    if (inputData.length > UINT32_MAX)
    {
        MSID_LOG_WARN(nil, @"Input length is too big to convert SHA256 data");
        return nil;
    }
    CC_SHA256(inputData.bytes, (uint32_t)inputData.length, outData.mutableBytes);
    
    return outData;
}

- (NSString*)msidComputeSHA256
{
        // TODO: Check if this is in fact right implementation
//    const char* inputStr = [self UTF8String];
//    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
//    CC_SHA256(inputStr, (int)strlen(inputStr), hash);
//    NSMutableString* toReturn = [[NSMutableString alloc] initWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
//    for (int i = 0; i < sizeof(hash)/sizeof(hash[0]); ++i)
//    {
//        [toReturn appendFormat:@"%02x", hash[i]];
//    }
//    return toReturn;
    return [NSString msidBase64UrlEncodeData:[self msalSHA256Data]];
}

- (NSURL *)msidUrl
{
    return [[NSURL alloc] initWithString:self];
}

- (NSString *)msidTokenHash
{
    NSMutableString *returnStr = [[self msidComputeSHA256] mutableCopy];
    
    // 7 characters is sufficient to differentiate tokens in the log, otherwise the hashes start making log lines hard to read
    return [returnStr substringToIndex:7];
}

- (NSOrderedSet<NSString *> *)scopeSet
{
    NSMutableOrderedSet<NSString *> *scope = [NSMutableOrderedSet<NSString *> new];
    NSArray* parts = [self componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
    for (NSString *part in parts)
    {
        if (![NSString msidIsStringNilOrBlank:part])
        {
            [scope addObject:part.msidTrimmedString.lowercaseString];
        }
    }
    return scope;
}


+ (NSString *)randomUrlSafeStringOfSize:(NSUInteger)size
{
    if (size > RANDOM_STRING_MAX_SIZE)
    {
        return nil;
    }
    
    NSMutableData *data = [NSMutableData dataWithLength:size];
    int result = SecRandomCopyBytes(kSecRandomDefault, data.length, data.mutableBytes);
    
    if (result != 0)
    {
        return nil;
    }
    
    return [NSString msidBase64UrlEncodeData:data];
}


- (BOOL)msidIsEquivalentWithAnyAlias:(NSArray<NSString *> *)aliases
{
    if (!aliases)
    {
        return NO;
    }

    for (NSString *alias in aliases)
    {
        if ([self caseInsensitiveCompare:alias] == NSOrderedSame)
        {
            return YES;
        }
    }
    return NO;
}

@end
