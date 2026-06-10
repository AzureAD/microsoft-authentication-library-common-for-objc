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

@class MSIDEcdhApv;
NS_ASSUME_NONNULL_BEGIN
@interface MSIDJWECrypto : NSObject

/// JWE response encryption algorithm
@property (nonatomic, readonly) NSString *encryptionAlgorithm;
/// Key exchange algorithm
@property (nonatomic, readonly) NSString *keyExchangeAlgorithm;
/// APV . Contains this party's public key for key exchange.
@property (nonatomic, readonly) MSIDEcdhApv *apv;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (nullable instancetype)initWithKeyExchangeAlg:(NSString *)keyExchangeAlgorithm
                            encryptionAlgorithm:(NSString *)encryptionAlgorithm
                                            apv:(MSIDEcdhApv *)apv
                                        context:(_Nullable id<MSIDRequestContext>)context
                                          error:(NSError * _Nullable __autoreleasing *)error;

- (NSString *)urlEncodedJweCrypto;
- (NSDictionary *)jweCryptoDictionary;
@end
NS_ASSUME_NONNULL_END
