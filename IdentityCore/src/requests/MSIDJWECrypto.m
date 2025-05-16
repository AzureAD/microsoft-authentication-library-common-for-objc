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
#import "MSIDJWECrypto.h"
#import "MSIDEcdhApv.h"
#import "MSIDJwtAlgorithm.h"

@implementation MSIDJWECrypto

- (instancetype)initWithKeyExchangeAlg:(NSString *)keyExchangeAlgorithm
                   encryptionAlgorithm:(NSString *)encryptionAlgorithm
                                   apv:(MSIDEcdhApv *)apv
                               context:(_Nullable id<MSIDRequestContext>)context
                                 error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    self = [super init];
    if (self)
    {
        if ([NSString msidIsStringNilOrBlank:keyExchangeAlgorithm])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"JWE crypto generation failed: Key exchange algorithm is nil or blank");
            MSIDFillAndLogError(error, MSIDErrorInternal, @"JWE crypto generation failed: Key exchange algorithm is nil or blank", context.correlationId);
            return nil;
        }
        
        if ([NSString msidIsStringNilOrBlank:encryptionAlgorithm])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"JWE crypto generation failed: Encryption algorithm is nil or blank");
            MSIDFillAndLogError(error, MSIDErrorInternal, @"JWE crypto generation failed: Encryption algorithm is nil or blank", context.correlationId);
            return nil;
        }
        
        if (!apv)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"JWE crypto generation failed: APV is nil");
            MSIDFillAndLogError(error, MSIDErrorInternal, @"JWE crypto generation failed: APV is nil", context.correlationId);
            return nil;
        }
        
        if (![MSID_JWT_ALG_ECDH isEqual:keyExchangeAlgorithm])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"JWE crypto generation failed: Unsupported key exchange algorithm %@", keyExchangeAlgorithm);
            MSIDFillAndLogError(error, MSIDErrorInternal, [NSString stringWithFormat:@"JWE crypto generation failed: Unsupported key exchange algorithm %@", keyExchangeAlgorithm], context.correlationId);
            return nil;
        }
        
        if (![MSID_JWT_ALG_A256GCM isEqual:encryptionAlgorithm])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"JWE crypto generation failed: Unsupported encryption algorithm %@", encryptionAlgorithm);
            MSIDFillAndLogError(error, MSIDErrorInternal, [NSString stringWithFormat:@"JWE crypto generation failed: Unsupported encryption algorithm %@", encryptionAlgorithm], context.correlationId);
            return nil;
        }
        
        _keyExchangeAlgorithm = keyExchangeAlgorithm;
        _encryptionAlgorithm = encryptionAlgorithm;
        _apv = apv;
        _jweCryptoDictionary = @{
                                @"alg": keyExchangeAlgorithm,
                                @"enc": encryptionAlgorithm,
                                @"apv": apv.APV
                                };
    }
    return self;
}

- (NSString *)urlEncodedJweCrypto
{
    if (_urlEncodedCachedJweCrypto) return _urlEncodedCachedJweCrypto;
    _urlEncodedCachedJweCrypto = [_jweCryptoDictionary msidJSONSerializeWithContext:nil];
    return _urlEncodedCachedJweCrypto;
}

@end
