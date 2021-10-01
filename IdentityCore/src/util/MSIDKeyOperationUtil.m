//
//  MSIDKeyOperationUtil.m
//  IdentityCore
//
//  Created by Ameya Patil on 9/24/21.
//  Copyright © 2021 Microsoft. All rights reserved.
//

#import "MSIDKeyOperationUtil.h"
#import "MSIDJwtAlgorithm.h"
#import "NSData+JWT.h"
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
        NSString *attrTokenId = (NSString *)[attributes valueForKey:(NSString *)CFBridgingRelease(kSecAttrTokenID)];
        NSString *secureEnclaveId = (NSString *)(CFBridgingRelease(kSecAttrTokenIDSecureEnclave));  // id = com.apple.settoken for key in secure enclave
        return [secureEnclaveId isEqualToString:attrTokenId];
    }
    return NO;
}

- (BOOL)isOperationSupportedByKey:(SecKeyOperationType)operation algorithm:(SecKeyAlgorithm)algorithm key:(SecKeyRef)key context:(id<MSIDRequestContext> _Nullable)context error:(NSError * _Nullable __autoreleasing *)error
{
    if (key == NULL)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Key passed in to check operation is not defined.", nil, nil, nil, context.correlationId, nil, YES);
            return NO;
        }
    }
    BOOL isSupported = SecKeyIsAlgorithmSupported(key, operation, algorithm);
    if (!isSupported)
    {
        if (error)
        {
            NSString *errorMessage = [NSString stringWithFormat:@"Key does not support %ld with %@", (long)operation, algorithm];
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorMessage, nil, nil, nil, context.correlationId, nil, YES);
        }
    }
    return isSupported;
}

- (MSIDJwtAlgorithm)getJwtAlgorithmForKey:(SecKeyRef)privateKey context:(id<MSIDRequestContext> _Nullable)context error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    if (privateKey == NULL)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"No key to determine signing algorithm", nil, nil, nil, context.correlationId, nil, YES);
        }
        return nil;
    }
    
    if ([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmECDSASignatureDigestX962SHA256 key:privateKey context:context error:error])
    {
        return MSID_JWT_ALG_ES256;
    }
    
    if ([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256 key:privateKey context:context error:error])
    {
        return MSID_JWT_ALG_RS256;
    }
    
    if (error)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Key does not support signing any supported algorithms or key is public key");
    }
    return nil;
}

- (NSData *)getSignatureForDataWithKey:(NSData *)rawData privateKey:(SecKeyRef)privateKey context:(id<MSIDRequestContext>)context error:(NSError * _Nullable __autoreleasing *)error
{
    if (!rawData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"No data to sign", nil, nil, nil, context.correlationId, nil, YES);
            return nil;
        }
    }
    
    if (privateKey == NULL)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"No key defined to sign data with", nil, nil, nil, context.correlationId, nil, YES);
            return nil;
        }
    }
    
    SecKeyAlgorithm algorithm = nil;
    // Since Secure enclave only supports ECC NIST P-256 curve key we can assume key is used for ECDSA
    if ([[MSIDKeyOperationUtil sharedInstance] isKeyFromSecureEnclave:privateKey] && [[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmECDSASignatureMessageX962SHA256 key:privateKey context:context error:error])
    {
        algorithm = kSecKeyAlgorithmECDSASignatureMessageX962SHA256;
    }
    else if ([[MSIDKeyOperationUtil sharedInstance] isOperationSupportedByKey:kSecKeyOperationTypeSign algorithm:kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256 key:privateKey context:context error:error])
    {
        algorithm = kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256;
    }
    
    if (algorithm == NULL)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Signing algorithm could not be determined for supplied key because key is not of supported type or it is a public key.", nil, nil, nil, context.correlationId, nil, YES);
            return nil;
        }
    }
    CFErrorRef *subError = NULL;
    NSData *signature = (NSData *)CFBridgingRelease(SecKeyCreateSignature(privateKey,
                                                                          algorithm,
                                                                          (__bridge CFDataRef)rawData,
                                                                          subError));
    if (!signature)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to sign data with key.", nil, nil, CFBridgingRelease(subError), context.correlationId, nil, YES);
        }
    }
    return signature;
}

@end
