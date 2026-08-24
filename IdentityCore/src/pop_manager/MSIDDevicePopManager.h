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

@class MSIDCacheConfig;
@class MSIDBaseToken;
@class MSIDAssymetricKeyLookupAttributes;
@class MSIDAssymetricKeyPair;
@protocol MSIDAssymetricKeyGenerating;
@protocol MSIDRequestContext;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDDevicePopManager : NSObject

@property (nonatomic, readonly) MSIDAssymetricKeyPair *keyPair;

- (instancetype)initWithCacheConfig:(MSIDCacheConfig *)cacheConfig
                  keyPairAttributes:(MSIDAssymetricKeyLookupAttributes *)keyPairAttributes;

/// Initializes a manager with a caller-owned RSA key pair for external AT PoP.
/// External AT PoP is RSA-only (minimum 2048-bit). EC/ES256 keys are not supported on this path
/// (unlike internal Secure Enclave generation). The public key must be exportable and support
/// RS256 Message verification so JWK/kid generation and non-interactive pair matching can succeed;
/// keys that only support private-key signing may fail validation. Validation fails without
/// signing when public-key derivation is unavailable, so initialization never triggers caller-key
/// user-presence UI.
- (nullable instancetype)initWithExternalKeyPair:(nullable MSIDAssymetricKeyPair *)keyPair;

/// Initializes a manager with a validated caller-owned RSA key pair and returns validation errors.
/// Same RSA-only / ≥2048-bit constraints as \c initWithExternalKeyPair:.
- (nullable instancetype)initWithExternalKeyPair:(nullable MSIDAssymetricKeyPair *)keyPair
                                         context:(nullable id<MSIDRequestContext>)context
                                           error:(NSError * _Nullable __autoreleasing * _Nullable)error;

- (nullable NSString *)createSignedAccessToken:(NSString *)accessToken
                                    httpMethod:(NSString *)httpMethod
                                    requestUrl:(NSString *)requestUrl
                                         nonce:(NSString *)nonce
                                         error:(NSError *__autoreleasing * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
