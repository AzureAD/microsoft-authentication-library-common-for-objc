//
//  MSIDDevicePopManager.m
//  IdentityCore
//
//  Created by Rohit Narula on 4/28/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSIDDevicePopManager.h"
#import "MSIDConstants.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDJWTHelper.h"

static NSString *jwkTemplate = @"{\"e\":\"%@\",\"kty\":\"RSA\",\"n\":\"%@\"}";
static NSString *kidTemplate = @"{\"kid\":\"%@\"}";
#define CFReleaseNull(CF) { CFTypeRef _cf = (CF); if (_cf) CFRelease(_cf); CF = NULL; }

@implementation MSIDDevicePopManager

+ (instancetype)sharedManager
{
    static dispatch_once_t onceToken;
    static MSIDDevicePopManager *popManager;
    dispatch_once(&onceToken, ^{
        popManager = [[MSIDDevicePopManager alloc] init];
    });
    
    return popManager;
}

-(instancetype)init
{
     if (self = [super init])
     {
         [self generateAsymmmetricKeyPair];
     }
    
    return self;
}

- (void)generateAsymmmetricKeyPair
{
    OSStatus status = noErr;
    int keySize = 2048;
    [self deleteAsymmetricKeys];
    SecKeyRef publicKeyRef = NULL;
    SecKeyRef privateKeyRef = NULL;

    // Container dictionaries.
    NSMutableDictionary * privateKeyAttr = [[NSMutableDictionary alloc] init];
    NSMutableDictionary * publicKeyAttr = [[NSMutableDictionary alloc] init];
    NSMutableDictionary * keyPairAttr = [[NSMutableDictionary alloc] init];

    // Set top level dictionary for the keypair.
    [keyPairAttr setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
    [keyPairAttr setObject:[NSNumber numberWithUnsignedInteger:keySize] forKey:(id)kSecAttrKeySizeInBits];

    // Set the private key dictionary.
    [privateKeyAttr setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecAttrIsPermanent];
    [privateKeyAttr setObject:[MSID_BROKER_SDK_POP_TOKEN_PRIVATE_KEY dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecAttrApplicationTag];
    // See SecKey.h to set other flag values.

    // Set the public key dictionary.
    [publicKeyAttr setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecAttrIsPermanent];
    [publicKeyAttr setObject:[MSID_BROKER_SDK_POP_TOKEN_PUBLIC_KEY dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecAttrApplicationTag];
    // See SecKey.h to set other flag values.

    // Set attributes to top level dictionary.
    [keyPairAttr setObject:privateKeyAttr forKey:(id)kSecPrivateKeyAttrs];
    [keyPairAttr setObject:publicKeyAttr forKey:(id)kSecPublicKeyAttrs];

    // SecKeyGeneratePair returns the SecKeyRefs just for educational purposes.
    status = SecKeyGeneratePair((CFDictionaryRef)keyPairAttr, &publicKeyRef, &privateKeyRef);
    if (status != noErr || publicKeyRef == NULL || privateKeyRef || NULL){
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Error generating asymmetric key pair, OSStatus == %d.", status);
    }
    
    if (publicKeyRef) CFRelease(publicKeyRef);
    if (privateKeyRef) CFRelease(privateKeyRef);
}

- (void)deleteAsymmetricKeys
{
    OSStatus status = noErr;
    NSMutableDictionary * queryPublicKey = [[NSMutableDictionary alloc] init];
    NSMutableDictionary * queryPrivateKey = [[NSMutableDictionary alloc] init];
    
    // Set the public key query dictionary.
    [queryPublicKey setObject:(id)kSecClassKey forKey:(id)kSecClass];
    [queryPublicKey setObject:[MSID_BROKER_SDK_POP_TOKEN_PUBLIC_KEY dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecAttrApplicationTag];
    [queryPublicKey setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
    
    // Set the private key query dictionary.
    [queryPrivateKey setObject:(id)kSecClassKey forKey:(id)kSecClass];
    [queryPrivateKey setObject:[MSID_BROKER_SDK_POP_TOKEN_PRIVATE_KEY dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecAttrApplicationTag];
    [queryPrivateKey setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
    
    // Delete the private key.
    status = SecItemDelete((CFDictionaryRef)queryPrivateKey);
    if (status != errSecSuccess)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Error removing private key, OSStatus == %d.", status);
    }
    
    // Delete the public key.
    status = SecItemDelete((CFDictionaryRef)queryPublicKey);
    if (status != errSecSuccess)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Error removing private key, OSStatus == %d.", status);
    }
}

- (NSData *)getPublicKeyBits:(NSError **)error
{
    OSStatus status = noErr;
    NSData *publicKeyBits = nil;
    
    NSMutableDictionary * queryPublicKey = [[NSMutableDictionary alloc] init];
        
    // Set the public key query dictionary.
    [queryPublicKey setObject:(id)kSecClassKey forKey:(id)kSecClass];
    [queryPublicKey setObject:[MSID_BROKER_SDK_POP_TOKEN_PUBLIC_KEY dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecAttrApplicationTag];
    [queryPublicKey setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
    [queryPublicKey setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnData];
        
    // Get the key bits.
    CFTypeRef keyBits = nil;
    status = SecItemCopyMatching((CFDictionaryRef)queryPublicKey, (CFTypeRef *)&keyBits);
        
    if (status != errSecSuccess)
    {
        if (error)
        {
            NSString *errorDescription = [NSString stringWithFormat:@"Error retrieving public key bits, OSStatus = %d.", status];
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, nil, nil, nil, NO);
        }
        
        return nil;
    }
    
    
    publicKeyBits = CFBridgingRelease(keyBits);
    return publicKeyBits;
}

- (SecKeyRef)copyPrivateKeyRef:(NSError **)error
{
    OSStatus status = noErr;
    SecKeyRef privateKeyReference = NULL;
    NSMutableDictionary * queryPrivateKey = [[NSMutableDictionary alloc] init];
        
        // Set the private key query dictionary.
    [queryPrivateKey setObject:(id)kSecClassKey forKey:(id)kSecClass];
    [queryPrivateKey setObject:[MSID_BROKER_SDK_POP_TOKEN_PRIVATE_KEY dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecAttrApplicationTag];
    [queryPrivateKey setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
    [queryPrivateKey setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnRef];
        
        // Get the key.
    status = SecItemCopyMatching((CFDictionaryRef)queryPrivateKey, (CFTypeRef *)&privateKeyReference);
        
    if (status != errSecSuccess)
    {
        if (error)
        {
            NSString *errorDescription = [NSString stringWithFormat:@"Error retrieving private key ref, OSStatus = %d.", status];
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, nil, nil, nil, NO);
        }
        
        return nil;
    }
    
    return privateKeyReference;
}

- (NSString *)getPublicKeyExp:(NSData *)publicKeyBits
{
    NSData* pk = [publicKeyBits copy];
    if (pk == NULL) return NULL;
    
    int iterator = 0;
    
    iterator++; // TYPE - bit stream - mod + exp
    [self derEncodingGetSizeFrom:pk at:&iterator]; // Total size
    
    iterator++; // TYPE - bit stream mod
    int mod_size = [self derEncodingGetSizeFrom:pk at:&iterator];
    iterator += mod_size;
    
    iterator++; // TYPE - bit stream exp
    int exp_size = [self derEncodingGetSizeFrom:pk at:&iterator];
    
    return [[pk subdataWithRange:NSMakeRange(iterator, exp_size)] base64EncodedStringWithOptions:0];
}

- (NSString *)getPublicKeyMod:(NSData *)publicKeyBits
{
    NSData* pk = [publicKeyBits copy];
    if (pk == NULL) return NULL;
    
    int iterator = 0;
    
    iterator++; // TYPE - bit stream - mod + exp
    [self derEncodingGetSizeFrom:pk at:&iterator]; // Total size
    
    iterator++; // TYPE - bit stream mod
    int mod_size = [self derEncodingGetSizeFrom:pk at:&iterator];
    NSData* subData=[pk subdataWithRange:NSMakeRange(iterator, mod_size)];
    NSString *mod = [[subData subdataWithRange:NSMakeRange(1, subData.length-1)] base64EncodedStringWithOptions:0];
    return mod;
}

- (int)derEncodingGetSizeFrom:(NSData *)buf at:(int *)iterator
{
    const uint8_t* data = [buf bytes];
    int itr = *iterator;
    int num_bytes = 1;
    int ret = 0;
    
    if (data[itr] > 0x80) {
        num_bytes = data[itr] - 0x80;
        itr++;
    }
    
    for (int i = 0 ; i < num_bytes; i++)
        ret = (ret * 0x100) + data[itr + i];
    
    *iterator = itr + num_bytes;
    return ret;
}

- (NSString *)createPublicKeyJWK:(NSData *)publicKeyBits
{
    NSString* jwk = [NSString stringWithFormat:jwkTemplate,
                     [self getPublicKeyExp:publicKeyBits],
                     [self getPublicKeyMod:publicKeyBits]];
    
    NSData *jwkData = [jwk dataUsingEncoding:NSUTF8StringEncoding];
    NSData *hashedData = [jwkData msidSHA256];
    NSString *base64EncodedJWK = [hashedData msidBase64UrlEncodedString];
    return base64EncodedJWK;
}

- (NSString *)getRequestConfirmation:(NSError **)error
{
    NSError *localError = nil;
    NSData *publicKeyBits = [self getPublicKeyBits:&localError];
    
    if (!publicKeyBits)
    {
       if (error)
        {
           NSString *errorDescription = [NSString stringWithFormat:@"Error retrieving public key bits."];
           *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, nil, nil, nil, NO);
        }
        
        return nil;
    }
    
    NSString *kid = [NSString stringWithFormat:kidTemplate, [self createPublicKeyJWK:publicKeyBits]];
    NSData *kidData = [kid dataUsingEncoding:NSUTF8StringEncoding];
    return [kidData msidBase64UrlEncodedString];
}

- (NSString *)createSignedAccessToken:(NSString *)accessToken
                           httpMethod:(NSString *)httpMethod
                           requestUrl:(NSString *)requestUrl
                                nonce:(NSString *)nonce
                                error:(NSError **)error
{
    NSError *localError = nil;
    NSData *publicKeyBits = [self getPublicKeyBits:&localError];
    
    if (!publicKeyBits)
    {
        if (error)
        {
            *error = localError;
            return nil;
        }
    }
    
    NSString *kid = [self createPublicKeyJWK:publicKeyBits];
    
    if (!kid)
    {
        if (error)
        {
           NSString *errorDescription = [NSString stringWithFormat:@"Error generating kid from public key bits."];
           *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, nil, nil, nil, NO);
        }
        
        return nil;
    }
    
    NSURL *url = [NSURL URLWithString:requestUrl];
    if (!url)
    {
        if (error)
        {
          NSString *errorDescription = [NSString stringWithFormat:@"Invalid request url %@", requestUrl];
          *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, nil, nil, nil, NO);
            
        }
               
        return nil;
    }
    
    NSString *host = url.host;
    NSString *path = url.path;
    
    NSDictionary *header = @{
                             @"alg" : @"RS256",
                             @"typ" : @"JWT",
                             @"kid" : kid
                             };
    
    NSDictionary *payload = @{
                              @"at" : accessToken,
                              @"cnf": @{
                                      @"jwk":@{
                                          @"kty" : @"RSA",
                                          @"n" : [self getPublicKeyMod:publicKeyBits],
                                          @"e" : [self getPublicKeyExp:publicKeyBits]
                                      }
                              },
                              @"ts" : [NSString stringWithFormat:@"%lu", (long)[[NSDate date] timeIntervalSince1970]],
                              @"m" : httpMethod,
                              @"u" : host,
                              @"p" : path,
                              @"nonce" : nonce,
                              };
    
    SecKeyRef privateKeyRef = [self copyPrivateKeyRef:&localError];
    if (!privateKeyRef)
    {
        if (error)
        {
            *error = localError;
        }
        
        return nil;
    }
    
    NSString *signedJwtHeader = [MSIDJWTHelper createSignedJWTforHeader:header payload:payload signingKey:privateKeyRef];
    CFReleaseNull(privateKeyRef);
    return signedJwtHeader;
}

+ (NSString*)decryptJWT:(NSData *)jwtData
          decrpytionKey:(SecKeyRef)decrpytionKey
{
#if TARGET_OS_IPHONE
    size_t cipherBufferSize = SecKeyGetBlockSize(decrpytionKey);
#endif // TARGET_OS_IPHONE
    size_t keyBufferSize = [jwtData length];
    
    NSMutableData *bits = [NSMutableData dataWithLength:keyBufferSize];
    OSStatus status = errSecAuthFailed;
#if TARGET_OS_IPHONE
    status = SecKeyDecrypt(decrpytionKey,
                           kSecPaddingPKCS1,
                           (const uint8_t *) [jwtData bytes],
                           cipherBufferSize,
                           [bits mutableBytes],
                           &keyBufferSize);
#else // !TARGET_OS_IPHONE
    (void)decrpytionKey;
    // TODO: SecKeyDecrypt is not available on OS X
#endif // TARGET_OS_IPHONE
    if(status != errSecSuccess)
    {
        return nil;
    }
    
    [bits setLength:keyBufferSize];
    return [[NSString alloc] initWithData:bits encoding:NSUTF8StringEncoding];
}

@end
