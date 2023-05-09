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

#import "MSIDJwtAlgorithm.h"
#import "MSIDRequestContext.h"

NS_ASSUME_NONNULL_BEGIN
@interface MSIDKeyOperationUtil : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)sharedInstance;

/// Returns if supplied key is from secure enclave
/// @param key key to check
- (BOOL)isKeyFromSecureEnclave:(_Nonnull SecKeyRef)key API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0));

/// Returns boolean indicating if a key operation can be done using the key with supplied algorithm
/// @param operation operation type like encryption, decryption, signing, verifying. Refer SecKeyOperationType for available operations
/// @param algorithm algorithm used for key operation. Refer SecKeyAlgorithm for types.
/// @param key key to perform operation with.
/// @param context request context
/// @param error error if unsuccessful
- (BOOL)isOperationSupportedByKey:(SecKeyOperationType)operation
                        algorithm:(_Nonnull SecKeyAlgorithm)algorithm
                              key:(_Nonnull SecKeyRef)key
                          context:(_Nullable id<MSIDRequestContext>)context
                            error:(NSError * _Nullable * _Nullable)error API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0));

/// Get asymmetric verifying algorithm to be put as 'alg' claim in JWT. Depending on the key supplied and algorithms supported returns alg.
/// @param key key used for signing JWT
/// @param context request context
/// @param error error determining alg
- (_Nullable MSIDJwtAlgorithm)getJwtAlgorithmForKey:(SecKeyRef _Nonnull )key
                                            context:(_Nullable id<MSIDRequestContext>)context
                                              error:(NSError * _Nullable * _Nullable)error API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0));

/// Returns signature after using supplied key to sign supplied data. Uses SecKeyCreateSignature which signs(SHA256(data))
/// @param rawData Data to be signed. Method will SHA256 this internally
/// @param privateKey Private key to use for signing
/// @param algorithm to use for signing
/// @param context request context
/// @param error error for failed signing
- (NSData * _Nullable)getSignatureForDataWithKey:(NSData * _Nonnull)rawData
                                      privateKey:(_Nonnull SecKeyRef)privateKey
                                signingAlgorithm:(SecKeyAlgorithm)algorithm
                                         context:(_Nullable id<MSIDRequestContext>)context
                                           error:(NSError * _Nullable * _Nullable)error API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0));
@end
NS_ASSUME_NONNULL_END
