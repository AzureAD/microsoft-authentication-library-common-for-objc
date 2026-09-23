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
#import "MSIDBrokerKeyProvider.h"
#import <CommonCrypto/CommonCryptor.h>
#import <Security/Security.h>
#import "NSData+MSIDExtensions.h"
#import "MSIDConstants.h"
#import "MSIDKeychainUtil.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>

@interface MSIDBrokerKeyProvider()

@property (nonatomic) NSString *keychainAccessGroup;
@property (nonatomic) NSString *keyIdentifier;

@end

@implementation MSIDBrokerKeyProvider

+ (NSMutableDictionary *)boundSPAQueryForAccount:(NSString *)account error:(NSError * __autoreleasing *)error
{
    NSString *group = [[MSIDKeychainUtil sharedInstance] accessGroup:@"com.microsoft.adalcache"];
    if (!group.length)
    {
        MSIDFillAndLogError(error, MSIDErrorInternal, @"Bound-SPA shared keychain entitlement is unavailable.", nil);
        return nil;
    }
    NSMutableDictionary *query = [@{(id)kSecClass: (id)kSecClassGenericPassword,
                                   (id)kSecAttrService: @"com.microsoft.bound-spa.v1",
                                   (id)kSecAttrAccount: account,
                                   (id)kSecAttrAccessGroup: group} mutableCopy];
#if !TARGET_OS_IPHONE
    query[(id)kSecUseDataProtectionKeychain] = @YES;
#endif
    return query;
}

+ (NSData *)boundSPADataForAccount:(NSString *)account error:(NSError * __autoreleasing *)error
{
    NSMutableDictionary *query = [self boundSPAQueryForAccount:account error:error];
    if (!query)
    {
        return nil;
    }
    query[(id)kSecReturnData] = @YES;
    CFTypeRef data = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &data);
    if (status == errSecSuccess)
    {
        return CFBridgingRelease(data);
    }
    if (status != errSecItemNotFound && error)
    {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
    return nil;
}

+ (BOOL)addBoundSPAData:(NSData *)data account:(NSString *)account error:(NSError * __autoreleasing *)error
{
    NSMutableDictionary *query = [self boundSPAQueryForAccount:account error:error];
    if (!query)
    {
        return NO;
    }
    query[(id)kSecValueData] = data;
    query[(id)kSecAttrAccessible] = (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    if (status == errSecSuccess || status == errSecDuplicateItem)
    {
        return YES;
    }
    if (error)
    {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
    return NO;
}

+ (BOOL)publishBoundSPASupport:(BOOL)enabled error:(NSError * __autoreleasing *)error
{
    // The discovery item is also a secret, distinct from the legacy broker key
    // (which is sent in IPC). It is never included in a request or response.
    if (!enabled)
    {
        NSDictionary *query = [self boundSPAQueryForAccount:@"support" error:error];
        if (!query)
        {
            return NO;
        }
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
        if (status == errSecSuccess || status == errSecItemNotFound)
        {
            return YES;
        }
        if (error)
        {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        return NO;
    }
    uint8_t bytes[32];
    OSStatus status = SecRandomCopyBytes(kSecRandomDefault, sizeof(bytes), bytes);
    if (status != errSecSuccess)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        return NO;
    }
    return [self addBoundSPAData:[NSData dataWithBytes:bytes length:sizeof(bytes)] account:@"support" error:error];
}

+ (BOOL)hasBoundSPASupportWithError:(NSError * __autoreleasing *)error
{
    return [self boundSPADataForAccount:@"support" error:error].length == 32;
}

+ (NSString *)boundSPAProofForParameters:(NSDictionary *)parameters sourceApplication:(NSString *)sourceApplication error:(NSError * __autoreleasing *)error
{
    NSData *secret = [self boundSPADataForAccount:@"support" error:error];
    if (secret.length != 32 || !sourceApplication.length)
    {
        return nil;
    }
    NSMutableDictionary *signedParameters = [parameters mutableCopy];
    [signedParameters removeObjectForKey:@"bound_spa_proof"];
    signedParameters[@"bound_spa_source"] = sourceApplication;
    // Length-prefixed UTF-8 fields avoid delimiter ambiguities and JSON/URL escaping differences.
    NSMutableData *message = [NSMutableData new];
    for (NSString *key in [[signedParameters allKeys] sortedArrayUsingSelector:@selector(compare:)])
    {
        id value = signedParameters[key];
        if ([value isKindOfClass:NSNumber.class])
        {
            value = [value stringValue];
        }
        if (![value isKindOfClass:NSString.class])
        {
            return nil;
        }
        for (NSString *field in @[key, value])
        {
            NSData *bytes = [field dataUsingEncoding:NSUTF8StringEncoding];
            NSData *length = [[NSString stringWithFormat:@"%lu:", (unsigned long)bytes.length] dataUsingEncoding:NSUTF8StringEncoding];
            [message appendData:length];
            [message appendData:bytes];
        }
    }
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, secret.bytes, secret.length, message.bytes, message.length, digest);
    return [[NSData dataWithBytes:digest length:sizeof(digest)] base64EncodedStringWithOptions:0];
}

+ (BOOL)validateBoundSPAProofForParameters:(NSDictionary *)parameters sourceApplication:(NSString *)sourceApplication error:(NSError * __autoreleasing *)error
{
    NSString *expected = [self boundSPAProofForParameters:parameters sourceApplication:sourceApplication error:error];
    NSString *proof = parameters[@"bound_spa_proof"];
    if (![proof isKindOfClass:NSString.class] || !expected || expected.length != proof.length)
    {
        return NO;
    }
    NSData *left = [expected dataUsingEncoding:NSUTF8StringEncoding];
    NSData *right = [proof dataUsingEncoding:NSUTF8StringEncoding];
    const uint8_t *a = left.bytes;
    const uint8_t *b = right.bytes;
    uint8_t difference = 0;
    for (NSUInteger i = 0; i < left.length; i++)
    {
        difference |= a[i] ^ b[i];
    }
    return difference == 0;
}

+ (NSString *)boundSPAExclusionAccount:(NSString *)refreshToken
{
    NSData *bytes = [refreshToken dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
    return [@"excluded:" stringByAppendingString:[[NSData dataWithBytes:digest length:sizeof(digest)] base64EncodedStringWithOptions:0]];
}

+ (BOOL)excludeBoundSPARefreshToken:(NSString *)refreshToken error:(NSError * __autoreleasing *)error
{
    return [self addBoundSPAData:[NSData data] account:[self boundSPAExclusionAccount:refreshToken] error:error];
}

+ (BOOL)isBoundSPARefreshTokenExcluded:(NSString *)refreshToken error:(NSError * __autoreleasing *)error
{
    return [self boundSPADataForAccount:[self boundSPAExclusionAccount:refreshToken] error:error] != nil;
}

- (instancetype)initWithGroup:(NSString *)keychainGroup
{
    return [self initWithGroup:keychainGroup keyIdentifier:MSID_BROKER_SYMMETRIC_KEY_TAG];
}

- (instancetype)initWithGroup:(NSString *)keychainGroup
                keyIdentifier:(NSString *)keyIdentifier
{
    self = [super init];

    if (self)
    {
        if (!keychainGroup)
        {
            keychainGroup = [[NSBundle mainBundle] bundleIdentifier];
        }
        
        MSIDKeychainUtil *keyChainUtil = [MSIDKeychainUtil sharedInstance];
        if (!keyChainUtil.teamId)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to read teamID from keychain");
            return nil;
        }

        // Add team prefix to keychain group if it is missed.
        if (![keychainGroup hasPrefix:keyChainUtil.teamId])
        {
            keychainGroup = [keyChainUtil accessGroup:keychainGroup];
        }

        _keychainAccessGroup = keychainGroup;
        _keyIdentifier = keyIdentifier;
        
        if (!keyIdentifier)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Nil key identifier provided. Cannot generate broker key");
            return nil;
        }
    }

    return self;
}

- (NSData *)brokerKeyWithError:(NSError *__autoreleasing*)error
{
    OSStatus err = noErr;

    NSData *symmetricTag = [self.keyIdentifier dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableDictionary *symmetricKeyQuery =
    [@{
      (id)kSecClass : (id)kSecClassKey,
      (id)kSecAttrApplicationTag : symmetricTag,
      (id)kSecAttrKeyType : @(CSSM_ALGID_AES),
      (id)kSecReturnData : @(YES),
      (id)kSecAttrAccessGroup : self.keychainAccessGroup
      } mutableCopy];
    
#if !TARGET_OS_IPHONE
    symmetricKeyQuery[(id)kSecUseDataProtectionKeychain] = @YES;
#endif

    // Get the key bits.
    CFDataRef symmetricKey = nil;
    err = SecItemCopyMatching((__bridge CFDictionaryRef)symmetricKeyQuery, (CFTypeRef *)&symmetricKey);
    if (err == errSecSuccess)
    {
        NSData *result = (__bridge NSData*)symmetricKey;
        CFRelease(symmetricKey);
        return result;
    }

    // Try to read previous format without keychain access groups
    NSMutableDictionary *query = [symmetricKeyQuery mutableCopy];
    [query removeObjectForKey:(id)kSecAttrAccessGroup];

    /*
     SecItemCopyMatching will look for items in all access groups that app has access to.
     This means there might be multiple items if app declares multiple access groups.
     However, we specifically don't set kSecMatchLimit, so it will take the first match.
     That will mimic previous ADAL behavior.

     From Apple documentation:

     By default, this function returns only the first match found. To obtain
     more than one matching item at a time, specify kSecMatchLimit with a value
     greater than 1. The result will be a CFArrayRef containing up to that
     number of matching items; the items' types are described above.
     */

    err = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&symmetricKey);

    if (err == errSecSuccess)
    {
        NSData *result = (__bridge NSData*)symmetricKey;
        CFRelease(symmetricKey);
        return result;
    }

    return [self createBrokerKeyWithError:error];
}

- (NSString *)base64BrokerKeyWithContext:(id<MSIDRequestContext>)context
                                   error:(NSError *__autoreleasing*)error
{
    NSError *localError;
    NSData *brokerKey = [self brokerKeyWithError:&localError];
    
    if (!brokerKey)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, context, @"Failed to retrieve broker key with error %@", MSID_PII_LOG_MASKABLE(localError));
        
        if (error) *error = localError;
        return nil;
    }
    
    NSString *base64UrlKey = [[NSString msidBase64UrlEncodedStringFromData:brokerKey] msidWWWFormURLEncode];
    
    if (!base64UrlKey)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Unable to base64 encode broker key");

        localError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unable to base64 encode broker key", nil, nil, nil, context.correlationId, nil, YES);
        
        if (error) *error = localError;
        
        return nil;
    }
    
    return base64UrlKey;
}

- (NSData *)createBrokerKeyWithError:(NSError *__autoreleasing*)error
{
    uint8_t *symmetricKey = NULL;
    OSStatus err = errSecSuccess;

    symmetricKey = calloc( 1, kChosenCipherKeySize * sizeof(uint8_t));
    if (!symmetricKey)
    {
        MSIDFillAndLogError(error, MSIDErrorBrokerKeyFailedToCreate, @"Could not create broker key.", nil);
        return nil;
    }

    err = SecRandomCopyBytes(kSecRandomDefault, kChosenCipherKeySize, symmetricKey);
    if (err != errSecSuccess)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to copy random bytes for broker key. Error code: %d", (int)err);
        MSIDFillAndLogError(error, MSIDErrorBrokerKeyFailedToCreate, @"Could not create broker key.", nil);
        free(symmetricKey);
        return nil;
    }

    NSData *keyData = [[NSData alloc] initWithBytes:symmetricKey length:kChosenCipherKeySize * sizeof(uint8_t)];
    free(symmetricKey);

    NSData *symmetricTag = [self.keyIdentifier dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableDictionary *symmetricKeyAttr =
    [@{
      (id)kSecClass : (id)kSecClassKey,
      (id)kSecAttrKeyClass : (id)kSecAttrKeyClassSymmetric,
      (id)kSecAttrApplicationTag : (id)symmetricTag,
      (id)kSecAttrKeyType : @(CSSM_ALGID_AES),
      (id)kSecAttrKeySizeInBits : @(kChosenCipherKeySize << 3),
      (id)kSecAttrEffectiveKeySize : @(kChosenCipherKeySize << 3),
      (id)kSecAttrCanEncrypt : @YES,
      (id)kSecAttrCanDecrypt : @YES,
      (id)kSecValueData : keyData,
      (id)kSecAttrAccessible : (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      (id)kSecAttrAccessGroup : self.keychainAccessGroup
      } mutableCopy];
    
#if !TARGET_OS_IPHONE
    symmetricKeyAttr[(id)kSecUseDataProtectionKeychain] = @YES;
#endif

    // First delete current symmetric key.
    if (![self deleteSymmetricKeyWithError:error])
    {
        return nil;
    }

    err = SecItemAdd((__bridge CFDictionaryRef)symmetricKeyAttr, NULL);

    if (err != errSecSuccess)
    {
        NSString *message = [NSString stringWithFormat:@"Could not write broker key %ld", (long)err];
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", message);
        MSIDFillAndLogError(error, MSIDErrorBrokerKeyFailedToCreate, message, nil);
        return nil;
    }

    return keyData;
}

- (BOOL)deleteSymmetricKeyWithError:(NSError *__autoreleasing*)error
{
    OSStatus err = noErr;

    NSData *symmetricTag = [self.keyIdentifier dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary* symmetricKeyQuery =
    @{
      (id)kSecClass : (id)kSecClassKey,
      (id)kSecAttrApplicationTag : symmetricTag,
      (id)kSecAttrKeyType : @(CSSM_ALGID_AES),
      (id)kSecAttrAccessGroup : self.keychainAccessGroup
      };

    // Delete the symmetric key.
    err = SecItemDelete((__bridge CFDictionaryRef)symmetricKeyQuery);

    // Try to delete something that doesn't exist isn't really an error
    if (err != errSecSuccess && err != errSecItemNotFound)
    {
        NSString *descr = [NSString stringWithFormat:@"Failed to delete broker key with error: %d", (int)err];
        MSIDFillAndLogError(error, MSIDErrorBrokerKeyFailedToCreate, descr, nil);
        return NO;
    }

    return YES;
}

- (BOOL)saveApplicationToken:(NSString *)appToken forClientId:(NSString *)clientId error:(NSError *__autoreleasing*)error
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Saving broker application token for clientId %@.", clientId);
    NSString *tag = [NSString stringWithFormat:@"%@-%@", MSID_BROKER_APPLICATION_TOKEN_TAG, clientId];
    
    NSMutableDictionary *applicationTokenAttributes = [NSMutableDictionary new];
    [applicationTokenAttributes setObject:(id)kSecClassKey forKey:(id)kSecClass];
    [applicationTokenAttributes setObject:[tag dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecAttrApplicationTag];
    [applicationTokenAttributes setObject:self.keychainAccessGroup forKey:(id)kSecAttrAccessGroup];
    
    NSMutableDictionary *update = [NSMutableDictionary dictionary];
    update[(id)kSecValueData] = [appToken dataUsingEncoding:NSUTF8StringEncoding];
    
    OSStatus status = SecItemUpdate((CFDictionaryRef)applicationTokenAttributes, (CFDictionaryRef)update);
    
    if (status == errSecItemNotFound)
    {
        [applicationTokenAttributes setObject:(id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly forKey:(id)kSecAttrAccessible];
        [applicationTokenAttributes addEntriesFromDictionary:update];
        status = SecItemAdd((CFDictionaryRef)applicationTokenAttributes, NULL);
    }
    
    if (status != errSecSuccess)
    {
        NSString *descr = [NSString stringWithFormat:@"Could not write broker application token %ld.", (long)status];
        MSIDFillAndLogError(error, MSIDErrorBrokerApplicationTokenWriteFailed, descr, nil);
        return NO;
    }
    
    return YES;
}

- (NSString *)getApplicationToken:(NSString *)clientId error:(NSError *__autoreleasing*)error
{
    NSString *tag = [NSString stringWithFormat:@"%@-%@", MSID_BROKER_APPLICATION_TOKEN_TAG, clientId];
    
    NSDictionary *applicationTokenQuery =
    @{
      (id)kSecClass : (id)kSecClassKey,
      (id)kSecAttrApplicationTag : [tag dataUsingEncoding:NSUTF8StringEncoding],
      (id)kSecReturnData : @(YES),
      (id)kSecAttrAccessGroup : self.keychainAccessGroup
      };
    
    // Get the key bits.
    CFDataRef applicationToken = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)applicationTokenQuery, (CFTypeRef *)&applicationToken);
    
    if (status == errSecItemNotFound)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"Broker application token not found. (status: %ld).", (long)status);
        return nil;
    }
    
    if (status != errSecSuccess)
    {
        NSString *descr = [NSString stringWithFormat:@"Failed to read broker application token. (status: %ld).", (long)status];
        MSIDFillAndLogError(error, MSIDErrorBrokerApplicationTokenReadFailed, descr, nil);
        return nil;
    }
    
    NSData *result = (__bridge_transfer NSData*)applicationToken;
    return [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
}


@end
