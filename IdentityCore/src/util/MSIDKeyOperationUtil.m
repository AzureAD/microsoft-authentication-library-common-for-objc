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

#import "MSIDKeyOperationUtil.h"
#import "MSIDJwtAlgorithm.h"
#import "NSData+MSIDExtensions.h"

@implementation MSIDKeyOperationUtil

+ (MSIDKeyOperationUtil *)sharedInstance
{
    static dispatch_once_t once;
    static MSIDKeyOperationUtil *s_keyOperationUtil = nil;
    dispatch_once(&once, ^{
        s_keyOperationUtil = [[MSIDKeyOperationUtil alloc] init];
    });
    return s_keyOperationUtil;
}

- (BOOL)isKeyFromSecureEnclave:(SecKeyRef)key
{
    if (key)
    {
        NSDictionary *attributes = (NSDictionary *)CFBridgingRelease(SecKeyCopyAttributes(key));
        NSString *attrTokenId = [attributes valueForKey:(__bridge NSString*)kSecAttrTokenID];
        NSString *secureEnclaveId = (__bridge NSString*)kSecAttrTokenIDSecureEnclave;  // id = com.apple.settoken for key in secure enclave
        return [secureEnclaveId isEqualToString:attrTokenId];
    }
    return NO;
}

- (BOOL)isOperationSupportedByKey:(SecKeyOperationType)operation algorithm:(SecKeyAlgorithm)algorithm key:(SecKeyRef)key context:(id<MSIDRequestContext> _Nullable)context error:(NSError * _Nullable __autoreleasing *)error
{
    if (key == NULL)
    {
        [self generateErrorWithMessage:@"Key passed in to check operation is not defined." underlyingError:nil context:context error:error];
        return NO;
    }
    BOOL isSupported = SecKeyIsAlgorithmSupported(key, operation, algorithm);
    if (!isSupported)
    {
        NSString *errorMessage = [NSString stringWithFormat:@"Key does not support %ld with %@", (long)operation, algorithm];
        [self generateErrorWithMessage:errorMessage underlyingError:nil context:context error:error];
    }
    return isSupported;
}

- (MSIDJwtAlgorithm)getJwtAlgorithmForKey:(SecKeyRef)privateKey context:(id<MSIDRequestContext> _Nullable)context error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    if (privateKey == NULL)
    {
        [self generateErrorWithMessage:@"No key to determine signing algorithm" underlyingError:nil context:context error:error];
        return nil;
    }
    
    NSError *ecdsaAlgError;
    if ([self isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmECDSASignatureDigestX962SHA256 key:privateKey context:context error:&ecdsaAlgError])
    {
        return MSID_JWT_ALG_ES256;
    }

    if ([self isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256 key:privateKey context:context error:error])
    {
        return MSID_JWT_ALG_RS256;
    }
    
    if (error && ecdsaAlgError)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Key does not support signing any supported algorithms or key is public key");
    }
    return nil;
}

- (NSData *)getSignatureForDataWithKey:(NSData *)rawData privateKey:(SecKeyRef)privateKey signingAlgorithm:(SecKeyAlgorithm)algorithm context:(id<MSIDRequestContext>)context error:(NSError * _Nullable __autoreleasing *)error
{
    if (!rawData)
    {
        [self generateErrorWithMessage: @"No data to sign" underlyingError:nil context:context error:error];
        return nil;
    }
    
    if (privateKey == NULL)
    {
        [self generateErrorWithMessage:@"No key defined to sign data with" underlyingError:nil context:context error:error];
        return nil;
    }
    
    if (algorithm == NULL)
    {
        [self generateErrorWithMessage:@"Signing algorithm not defined." underlyingError:nil context:context error:error];
        return nil;
    }
    
    // Check if provided key supports signing for provided algorithm
    if (![self isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:algorithm key:privateKey context:context error:error])
    {
        [self generateErrorWithMessage:@"Signing algorithm could not be determined for supplied key because key is not of supported type or it is a public key." underlyingError:nil context:context error:error];
        return nil;
    }
    
    CFErrorRef subError = NULL;
    NSData *signature = (NSData *)CFBridgingRelease(SecKeyCreateSignature(privateKey,
                                                                          algorithm,
                                                                          (__bridge CFDataRef)rawData,
                                                                          &subError));
    if (!signature)
    {
        NSError *signingError;
        if (subError)
        {
            signingError = CFBridgingRelease(subError);
        }
        [self generateErrorWithMessage:@"Failed to sign data with key." underlyingError:signingError context:context error:error];
    }
    return signature;
}

- (BOOL)validateExternalRSAKeyPair:(SecKeyRef)privateKey
                        publicKey:(SecKeyRef)publicKey
                    failureReason:(MSIDExternalKeyPairValidationFailureReason *)failureReason
                            error:(NSError *__autoreleasing *)error
{
    if (failureReason) *failureReason = MSIDExternalKeyPairValidationFailureReasonNone;

    if (privateKey == NULL || publicKey == NULL)
    {
        return [self failExternalKeyPairValidation:MSIDExternalKeyPairValidationFailureReasonInvalidKeyHandle
                                          message:@"Both private and public key handles are required."
                                    failureReason:failureReason
                                            error:error];
    }

    NSDictionary *privateAttributes = (NSDictionary *)CFBridgingRelease(SecKeyCopyAttributes(privateKey));
    NSDictionary *publicAttributes = (NSDictionary *)CFBridgingRelease(SecKeyCopyAttributes(publicKey));
    if (!privateAttributes || !publicAttributes)
    {
        return [self failExternalKeyPairValidation:MSIDExternalKeyPairValidationFailureReasonInvalidKeyHandle
                                          message:@"Unable to read key attributes."
                                    failureReason:failureReason
                                            error:error];
    }

    id privateKeyType = privateAttributes[(id)kSecAttrKeyType];
    id publicKeyType = publicAttributes[(id)kSecAttrKeyType];
    if (![privateKeyType isEqual:(id)kSecAttrKeyTypeRSA] || ![publicKeyType isEqual:(id)kSecAttrKeyTypeRSA])
    {
        return [self failExternalKeyPairValidation:MSIDExternalKeyPairValidationFailureReasonUnsupportedKeyType
                                          message:@"External AT PoP keys must be RSA keys."
                                    failureReason:failureReason
                                            error:error];
    }

    id privateKeyClass = privateAttributes[(id)kSecAttrKeyClass];
    id publicKeyClass = publicAttributes[(id)kSecAttrKeyClass];
    if (![privateKeyClass isEqual:(id)kSecAttrKeyClassPrivate] || ![publicKeyClass isEqual:(id)kSecAttrKeyClassPublic])
    {
        return [self failExternalKeyPairValidation:MSIDExternalKeyPairValidationFailureReasonInvalidKeyClass
                                          message:@"External AT PoP keys must contain one private key and one public key."
                                    failureReason:failureReason
                                            error:error];
    }

    NSNumber *privateKeySize = privateAttributes[(id)kSecAttrKeySizeInBits];
    NSNumber *publicKeySize = publicAttributes[(id)kSecAttrKeySizeInBits];
    if (privateKeySize.integerValue < 2048 || publicKeySize.integerValue < 2048 || ![privateKeySize isEqualToNumber:publicKeySize])
    {
        return [self failExternalKeyPairValidation:MSIDExternalKeyPairValidationFailureReasonKeySizeTooSmall
                                          message:@"External AT PoP RSA keys must have a matching size of at least 2048 bits."
                                    failureReason:failureReason
                                            error:error];
    }

    SecKeyAlgorithm algorithm = kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256;
    if (!SecKeyIsAlgorithmSupported(privateKey, kSecKeyOperationTypeSign, algorithm)
        || !SecKeyIsAlgorithmSupported(publicKey, kSecKeyOperationTypeVerify, algorithm))
    {
        return [self failExternalKeyPairValidation:MSIDExternalKeyPairValidationFailureReasonNotSigningCapable
                                          message:@"External AT PoP key pair does not support RS256 signing and verification."
                                    failureReason:failureReason
                                            error:error];
    }

    CFErrorRef publicKeyError = NULL;
    NSData *publicKeyData = (NSData *)CFBridgingRelease(SecKeyCopyExternalRepresentation(publicKey, &publicKeyError));
    if (!publicKeyData)
    {
        NSError *underlyingError = CFBridgingRelease(publicKeyError);
        return [self failExternalKeyPairValidation:MSIDExternalKeyPairValidationFailureReasonPublicKeySerializationFailed
                                          message:@"External AT PoP public key cannot be serialized."
                                 underlyingError:underlyingError
                                    failureReason:failureReason
                                            error:error];
    }

    SecKeyRef derivedPublicKey = SecKeyCopyPublicKey(privateKey);
    if (derivedPublicKey)
    {
        CFErrorRef derivedKeyError = NULL;
        NSData *derivedPublicKeyData = (NSData *)CFBridgingRelease(SecKeyCopyExternalRepresentation(derivedPublicKey, &derivedKeyError));
        CFRelease(derivedPublicKey);

        if (derivedPublicKeyData)
        {
            if (![derivedPublicKeyData isEqualToData:publicKeyData])
            {
                return [self failExternalKeyPairValidation:MSIDExternalKeyPairValidationFailureReasonKeyPairMismatch
                                                  message:@"External AT PoP public and private keys do not match."
                                            failureReason:failureReason
                                                    error:error];
            }

            return YES;
        }

        if (derivedKeyError) CFRelease(derivedKeyError);
    }

    NSData *challenge = [@"MSAL external AT PoP key pair validation" dataUsingEncoding:NSUTF8StringEncoding];
    CFErrorRef signingError = NULL;
    NSData *signature = (NSData *)CFBridgingRelease(SecKeyCreateSignature(privateKey,
                                                                          algorithm,
                                                                          (__bridge CFDataRef)challenge,
                                                                          &signingError));
    if (!signature)
    {
        NSError *underlyingError = CFBridgingRelease(signingError);
        return [self failExternalKeyPairValidation:MSIDExternalKeyPairValidationFailureReasonNotSigningCapable
                                          message:@"External AT PoP private key failed validation signing."
                                 underlyingError:underlyingError
                                    failureReason:failureReason
                                            error:error];
    }

    CFErrorRef verificationError = NULL;
    BOOL verified = SecKeyVerifySignature(publicKey,
                                          algorithm,
                                          (__bridge CFDataRef)challenge,
                                          (__bridge CFDataRef)signature,
                                          &verificationError);
    if (!verified)
    {
        NSError *underlyingError = CFBridgingRelease(verificationError);
        return [self failExternalKeyPairValidation:MSIDExternalKeyPairValidationFailureReasonKeyPairMismatch
                                          message:@"External AT PoP public and private keys do not match."
                                 underlyingError:underlyingError
                                    failureReason:failureReason
                                            error:error];
    }

    return YES;
}

- (BOOL)failExternalKeyPairValidation:(MSIDExternalKeyPairValidationFailureReason)reason
                              message:(NSString *)message
                        failureReason:(MSIDExternalKeyPairValidationFailureReason *)failureReason
                                error:(NSError *__autoreleasing *)error
{
    return [self failExternalKeyPairValidation:reason
                                       message:message
                              underlyingError:nil
                                 failureReason:failureReason
                                         error:error];
}

- (BOOL)failExternalKeyPairValidation:(MSIDExternalKeyPairValidationFailureReason)reason
                              message:(NSString *)message
                     underlyingError:(NSError *)underlyingError
                        failureReason:(MSIDExternalKeyPairValidationFailureReason *)failureReason
                                error:(NSError *__autoreleasing *)error
{
    if (failureReason) *failureReason = reason;
    [self generateErrorWithMessage:message underlyingError:underlyingError context:nil error:error];
    return NO;
}

- (void)generateErrorWithMessage:(NSString *)errorMessage underlyingError:(NSError *)underlyingError context:(id<MSIDRequestContext> _Nullable)context error:(NSError *__autoreleasing*)error
{
    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorMessage, nil, nil, underlyingError, context.correlationId, nil, NO);
    }
}

@end
