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

@interface NSString (MSIDExtensions)

/*! Encodes string to the Base64 encoding. */
- (NSString *)msidBase64UrlEncode;
/*! Decodes string from the Base64 encoding. */
- (NSString *)msidBase64UrlDecode;

/*! Returns YES if the string is nil, or contains only white space */
+ (BOOL)msidIsStringNilOrBlank:(NSString *)string;

/*! Returns the same string, but without the leading and trailing whitespace */
- (NSString *)msidTrimmedString;

/*! Decodes a previously URL encoded string. */
- (NSString *)msidUrlFormDecode;

/*! Encodes the string to pass it as a URL agrument. */
- (NSString *)msidUrlFormEncode;

/*! Converts base64 String to NSData */
+ (NSData *)msidBase64UrlDecodeData:(NSString *)encodedString;

/*! Converts NSData to base64 String */
+ (NSString *)msidBase64UrlEncodeData:(NSData *)data;

- (NSString*)msidComputeSHA256;

/*! Converts string to url */
- (NSURL *)msidUrl;

/*! Calculates a hash of the passed string. Useful for logging tokens, where we do not log
 the actual contents, but still want to log something that can be correlated. */
- (NSString *)msidTokenHash;

- (NSOrderedSet<NSString *> *)scopeSet;

- (BOOL)msidIsEquivalentWithAnyAlias:(NSArray<NSString *> *)aliases;

/*! Removes padding for Base64 encoded string */
- (NSString *)msidStringByRemovingPadding;

@end
