//
//  MSIDKeyOperationUtil.h
//  IdentityCore
//
//  Created by Ameya Patil on 9/24/21.
//  Copyright © 2021 Microsoft. All rights reserved.
//

#import "MSIDJwtAlgorithm.h"
NS_ASSUME_NONNULL_BEGIN
@interface MSIDKeyOperationUtil : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)sharedInstance;

/// Returns if supplied key is from secure enclave
/// @param key key to check
- (BOOL)isKeyFromSecureEnclave:(_Nonnull SecKeyRef)key;

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
                            error:(NSError * _Nullable * _Nullable)error;

/// Get verifying algorithm to be put as 'alg' claim in JWT. Depending on the key supplied and algorithms supported returns alg.
/// @param key key used for signing JWT
/// @param context request context
/// @param error error determining alg
- (_Nullable MSIDJwtAlgorithm)getJwtAlgorithmForKey:(SecKeyRef _Nonnull )key
                                            context:(_Nullable id<MSIDRequestContext>)context
                                              error:(NSError * _Nullable * _Nullable)error;

/// Returns signature after using supplied key to sign supplied data. Uses SecKeyCreateSignature which signs(SHA256(data))
/// @param rawData Data to be signed. Method will SHA256 this internally
/// @param privateKey Private key to use for signing
/// @param context request context
/// @param error error for failed signing
- (NSData * _Nullable)getSignatureForDataWithKey:(NSData * _Nonnull)rawData
                                      privateKey:(_Nonnull SecKeyRef)privateKey
                                         context:(_Nullable id<MSIDRequestContext>)context
                                           error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
