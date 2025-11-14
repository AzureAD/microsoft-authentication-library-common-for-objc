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


#import "NSData+MSIDEccSecKeyRef.h"
#import "NSData+MSIDExtensions.h"

@implementation NSData (MSIDEccSecKeyRef)

+ (nullable SecKeyRef)createECCKeyFromEccJsonWebKey:(nonnull NSDictionary *)jsonWebKey
                                              error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    if (!jsonWebKey[@"x"] || !jsonWebKey[@"y"])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected key dictionary, missing x or y", nil, nil, nil, nil, nil, NO);
        }
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unexpected key dictionary, missing x (%d) or y (%d)", (int)(jsonWebKey[@"x"] != nil), (int)(jsonWebKey[@"y"] != nil));
        
        return nil;
    }
    
    const unsigned char bytes[] = {0x04};
    NSMutableData *keyData = [[NSMutableData alloc] initWithBytes:bytes length:sizeof(bytes)];
    [keyData appendData:[NSData msidDataFromBase64UrlEncodedString:jsonWebKey[@"x"]]];
    [keyData appendData:[NSData msidDataFromBase64UrlEncodedString:jsonWebKey[@"y"]]];
    return [keyData createECCKeyFromEccJsonWebKey:error];
}

- (nullable SecKeyRef)createECCKeyFromEccJsonWebKey:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    NSDictionary *options = @{(id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
                              (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic,
                              (id)kSecAttrKeySizeInBits: @256,
    };
    
    CFErrorRef cfError = NULL;
    SecKeyRef key = SecKeyCreateWithData((__bridge CFDataRef)self,
                                         (__bridge CFDictionaryRef)options,
                                         &cfError);
    if (!key)
    {
        NSError *nsError = CFBridgingRelease(cfError);
        
        if (error)
        {
            *error = nsError;
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create public key with error %@", nsError);
    }
    
    return key;
}

@end
