//
//  MSIDKeyOperationUtil.h
//  IdentityCore
//
//  Created by Ameya Patil on 9/24/21.
//  Copyright © 2021 Microsoft. All rights reserved.
//

#import "MSIDJwtAlgorithm.h"

@interface MSIDKeyOperationUtil : NSObject

+ (BOOL)isKeyFromSecureEnclave:(_Nonnull SecKeyRef)key;

+ (BOOL)isOperationSupportedByKey:(SecKeyOperationType)operation
                        algorithm:(_Nonnull SecKeyAlgorithm)algorithm
                              key:(_Nonnull SecKeyRef)key
                          context:(_Nullable id<MSIDRequestContext>)context;

+ (_Nullable MSIDJwtAlgorithm)getJwtAlgorithmForKey:(SecKeyRef _Nonnull )key context:(_Nullable id<MSIDRequestContext>)context;

+ (NSData * _Nullable)getSignedDigestWithKey:(NSData * _Nonnull)rawData
                                  privateKey:(_Nonnull SecKeyRef)privateKey
                                     context:(_Nullable id<MSIDRequestContext>)context
                                       error:(NSError * _Nullable * _Nullable)error;

@end
