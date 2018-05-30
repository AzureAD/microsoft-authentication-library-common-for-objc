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

typedef unsigned char byte;


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
    NSUInteger paddedLength = encodedString.length + (4 - (encodedString.length % 4));
    NSString *paddedString = [encodedString stringByPaddingToLength:paddedLength withString:@"=" startingAtIndex:0];
    
    NSData *data = [[NSData alloc]
                    initWithBase64EncodedString:paddedString
                    options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    return data;
}


/// <summary>
/// Base64 URL decode a set of bytes.
/// </summary>
/// <remarks>
/// See RFC 4648, Section 5 plus switch characters 62 and 63 and no padding.
/// For a good overview of Base64 encoding, see http://en.wikipedia.org/wiki/Base64
/// </remarks>
- (NSString *)msidBase64UrlDecode
{
    NSUInteger paddedLength = self.length + (4 - (self.length % 4));
    NSString *paddedString = [self stringByPaddingToLength:paddedLength withString:@"=" startingAtIndex:0];
    
    NSData *data = [[NSData alloc]
                    initWithBase64EncodedString:paddedString
                    options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    if (!data) return nil;
    
    char lastByte;
    [data getBytes:&lastByte range:NSMakeRange([data length]-1, 1)];
    
    if (lastByte == 0x0) {
        //string is null-terminated
        return [NSString stringWithUTF8String:[data bytes]];
    } else {
        //string is not null-terminated
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
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
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [[string dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed].stringByRemovingPadding;
}


// Base64 URL encodes a string
- (NSString *)msidBase64UrlEncode
{
    return [[self dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed].stringByRemovingPadding;
}


+ (BOOL)msidIsStringNilOrBlank:(NSString *)string
{
    if (!string || [string isKindOfClass:[NSNull class]] || !string.length)
    {
        return YES;
    }
    
    static NSCharacterSet *nonWhiteCharSet;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        nonWhiteCharSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
    });
    
    return [string rangeOfCharacterFromSet:nonWhiteCharSet].location == NSNotFound;
}

- (NSString *)msidTrimmedString
{
    //The white characters set is cached by the system:
    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
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
    static NSCharacterSet *set = nil;
    
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


- (NSString*)msidComputeSHA256
{
    const char *inputStr = [self UTF8String];
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(inputStr, (int)strlen(inputStr), hash);
    NSMutableString *toReturn = [[NSMutableString alloc] initWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
    for (int i = 0; i < sizeof(hash)/sizeof(hash[0]); ++i)
    {
        [toReturn appendFormat:@"%02x", hash[i]];
    }
    return toReturn;
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
    NSArray *parts = [self componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
    for (NSString *part in parts)
    {
        if (![NSString msidIsStringNilOrBlank:part])
        {
            [scope addObject:part.msidTrimmedString.lowercaseString];
        }
    }
    return scope;
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

- (NSString *)stringByRemovingPadding
{
    return [self stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

@end

