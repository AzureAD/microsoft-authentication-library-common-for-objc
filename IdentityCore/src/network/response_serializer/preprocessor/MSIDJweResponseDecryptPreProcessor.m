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

#import "MSIDJweResponseDecryptPreProcessor.h"
#import "MSIDJweResponse.h"
#import "MSIDJweResponse+EcdhAesGcm.h"
#import "MSIDJsonResponsePreprocessor.h"

@implementation MSIDJweResponseDecryptPreProcessor

- (instancetype)initWithDecryptionKey:(SecKeyRef)decryptionKey
                            jweCrypto:(MSIDJWECrypto *)jweCrypto
             additionalResponseClaims:(NSDictionary *)additionalResponseClaims
{
    self = [super init];
    if (self)
    {
        if (!decryptionKey || !jweCrypto)
        {
            return nil;
        }
        _decryptionKey = decryptionKey;
        CFRetain(_decryptionKey);
        _jweCrypto = jweCrypto;
        _additionalResponseClaims = additionalResponseClaims;
    }
    return self;
}

- (nullable NSDictionary *)decryptJweResponseData:(NSData *)data
                                        jweCrypto:(MSIDJWECrypto *)jweCrypto
                                          context:(id <MSIDRequestContext>)context
                                            error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    // Parse JWE string.
    NSString *rawResponse;
    if (data) rawResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    if (!rawResponse)
    {
        __auto_type localError = MSIDCreateError(MSIDOAuthErrorDomain,
                                                 MSIDErrorServerInvalidResponse,
                                                 @"No raw response received from server.",
                                                 nil, nil, nil, context.correlationId, nil, YES);
        if (error) *error = localError;

        return nil;
    }

    MSIDJweResponse *jweResponse = [[MSIDJweResponse alloc] initWithRawJWE:rawResponse];
    NSDictionary *decryptedResponse = [jweResponse decryptJweResponseWithPrivateStk:self.decryptionKey jweCrypto:jweCrypto error:error];

    if (self.additionalResponseClaims && decryptedResponse)
    {
        NSMutableDictionary *mutableDecryptedResponse = [decryptedResponse mutableCopy];
        [mutableDecryptedResponse addEntriesFromDictionary:self.additionalResponseClaims];
        decryptedResponse = [mutableDecryptedResponse copy];
    }
    return decryptedResponse;
}
- (nullable id)responseObjectForResponse:(nullable NSHTTPURLResponse *)httpResponse
                                    data:(nullable NSData *)data
                                 context:(nullable id<MSIDRequestContext>)context
                                   error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    // Use the existing decryption method to process the response data.
    return nil;
}

- (void)dealloc
{
    if (_decryptionKey)
    {
        CFRelease(_decryptionKey);
        _decryptionKey = NULL;
    }
}

@end
