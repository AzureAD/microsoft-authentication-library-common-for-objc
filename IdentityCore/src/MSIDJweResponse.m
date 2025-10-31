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
#import "MSIDJweResponse.h"
#import "NSString+MSIDExtensions.h"
#import "NSData+MSIDExtensions.h"
#import "IdentityCore-Swift.h"

#define JWE_MIN_COMPONENT_COUNT 5

@implementation MSIDJweResponse

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithRawJWE:(NSString *)rawJWE
{
    self = [super init];
    if (self)
    {
        NSArray<NSString *> *jwePieces = [rawJWE componentsSeparatedByString: @"."];
        if ([jwePieces count] < JWE_MIN_COMPONENT_COUNT)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Tried to decode JWE, but received less then %d components. Number of components %d", JWE_MIN_COMPONENT_COUNT, (int)[jwePieces count]);
            return nil;
        }
        
        NSString *header = [jwePieces[0] msidBase64UrlDecode];
        
        if (!header)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Tried to decode the JWE header, but failed to perform base64 decoding");
            return nil;
        }
        
        NSError *jsonError  = nil;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:[header dataUsingEncoding:NSUTF8StringEncoding]
                                                        options:0
                                                          error:&jsonError];
        
        if (nil != jsonObject && [jsonObject isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *dict = (NSDictionary *)jsonObject;
            _headerAlgorithm = [dict objectForKey:@"alg"];
            if([dict objectForKey:@"ctx"])
            {
                _headerContext = [[NSData alloc] initWithBase64EncodedString:[dict objectForKey:@"ctx"] options:0];
            }
            _jweHeader = dict;
        }
        else
        {
            return nil;
        }
        
        _encryptedKey = [NSData msidDataFromBase64UrlEncodedString:[jwePieces objectAtIndex:1]];
        _iv = [NSData msidDataFromBase64UrlEncodedString:[jwePieces objectAtIndex:2]];
        _payload = [NSData msidDataFromBase64UrlEncodedString:[jwePieces objectAtIndex:3]];
        _tag = [NSData msidDataFromBase64UrlEncodedString:[jwePieces objectAtIndex:4]];
        
        // Per RFC https://tools.ietf.org/html/rfc7516#appendix-A.1.5, Authenticated data will be ASCII(BASE64URL(UTF8(JWE Protected Header))).
        _aad = [[jwePieces objectAtIndex:0] dataUsingEncoding:NSASCIIStringEncoding] ;
    }
    return self;
}
@end
