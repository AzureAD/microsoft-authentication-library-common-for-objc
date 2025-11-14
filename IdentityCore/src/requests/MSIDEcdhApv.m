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

#import "MSIDEcdhApv.h"
#import "NSData+MSIDExtensions.h"

@implementation MSIDEcdhApv

- (instancetype)initWithKey:(SecKeyRef)publicKey
                  apvPrefix:(NSString *)apvPrefix
          customClientNonce:(NSString * _Nullable)customNonce
                    context:(id<MSIDRequestContext> _Nullable)context
                      error:(NSError * _Nullable __autoreleasing *)error
{
    const NSUInteger kExpectedECP256KeyLength = 65;
    
    if (publicKey == NULL)
    {
        if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Public STK provided is not defined.", nil, nil, nil, context.correlationId, nil, NO);
        return nil;
    }
    
    if ([NSString msidIsStringNilOrBlank:apvPrefix])
    {
        if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"APV prefix is not defined. A prefix must be provided to determine calling application type.", nil, nil, nil, context.correlationId, nil, NO);
        return nil;
    }

    CFErrorRef errorRef = NULL;
    CFDictionaryRef attributes = SecKeyCopyAttributes(publicKey);
    CFStringRef keyType = CFDictionaryGetValue(attributes, kSecAttrKeyType);
    CFStringRef keyClass = CFDictionaryGetValue(attributes, kSecAttrKeyClass);

    BOOL isECPrivateKey = (keyType == kSecAttrKeyTypeECSECPrimeRandom) && (keyClass == kSecAttrKeyClassPrivate);

    if (attributes) CFRelease(attributes);
    NSData *stkData = CFBridgingRelease(SecKeyCopyExternalRepresentation(publicKey, NULL));
    if (isECPrivateKey || !stkData)
    {
        if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Supplied key should be a public EC key. Could not export EC key data.", nil, nil, CFBridgingRelease(errorRef), context.correlationId, nil, NO);
        return nil;
    }
    
    if (stkData.length != kExpectedECP256KeyLength)
    {
        if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Supplied key is not a EC P-256 key.", nil, nil, nil, context.correlationId, nil, NO);
        return nil;
    }
    
    NSMutableData *data = [NSMutableData new];
    
    int prefixLen = NSSwapHostIntToBig((int)apvPrefix.length);
    NSData *prefixLenData = [NSData dataWithBytes:&prefixLen length:sizeof(prefixLen)];
    [data appendData:prefixLenData];
    [data appendData:[apvPrefix dataUsingEncoding:NSUTF8StringEncoding]];
    
    int stkLen = NSSwapHostIntToBig((int)stkData.length);
    NSData *stkLenData = [NSData dataWithBytes:&stkLen length:sizeof(stkLen)];
    [data appendData:stkLenData];
    [data appendData:stkData];
    
    NSString *nonceString = customNonce ? customNonce : [[NSUUID UUID] UUIDString];
    NSData *nonceData = [nonceString dataUsingEncoding:NSASCIIStringEncoding];
    int nonceLen = NSSwapHostIntToBig((int)nonceData.length);
    NSData *nonceLenData = [NSData dataWithBytes:&nonceLen length:sizeof(nonceLen)];
    [data appendData:nonceLenData];
    [data appendData:nonceData];
    
    NSString *apvString = [data msidBase64UrlEncodedString];
    self = [super init];
    if (self)
    {
        _publicKey = publicKey;
        _apvPrefix = apvPrefix;
        _nonce = nonceData;
        _APV = apvString;
    }
    return self;
}
@end
