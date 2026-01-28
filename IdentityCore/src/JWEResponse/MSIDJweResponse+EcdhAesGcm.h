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
#import "MSIDRequestContext.h"
#import "MSIDJWECrypto.h"
#import "MSIDJsonSerializable.h"

typedef NSString *const MSIDJWECryptoKeyExchangeAlgorithm NS_TYPED_ENUM;
typedef NSString *const MSIDJWECryptoKeyResponseEncryptionAlgorithm NS_TYPED_ENUM;

extern MSIDJWECryptoKeyExchangeAlgorithm const _Nonnull MSID_KEY_EXCHANGE_ALGORITHM_ECDH_ES;
extern MSIDJWECryptoKeyResponseEncryptionAlgorithm const _Nonnull MSID_RESPONSE_ENCRYPTION_ALGORITHM_A256GCM;

NS_ASSUME_NONNULL_BEGIN
@interface MSIDJweResponse (EcdhAesGcm)
- (BOOL)IsJweResponseAlgorithmSupported:(NSError * _Nullable __autoreleasing * _Nullable)error;
- (nullable NSDictionary *)decryptJweResponseWithPrivateStk:(SecKeyRef)privateStk
                                                  jweCrypto:(MSIDJWECrypto *)jweCrypto
                                                      error:(NSError * _Nullable __autoreleasing * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
