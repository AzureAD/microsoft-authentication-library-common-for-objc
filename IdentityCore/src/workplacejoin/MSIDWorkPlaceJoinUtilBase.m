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

#import "MSIDKeychainUtil.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDWorkPlaceJoinUtilBase.h"
#import "MSIDWorkPlaceJoinUtilBase+Internal.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDKeyOperationUtil.h"

NSString *const MSID_DEVICE_INFORMATION_UPN_ID_KEY        = @"userPrincipalName";
NSString *const MSID_DEVICE_INFORMATION_AAD_DEVICE_ID_KEY = @"aadDeviceIdentifier";
NSString *const MSID_DEVICE_INFORMATION_AAD_TENANT_ID_KEY = @"aadTenantIdentifier";

static NSString *kWPJPrivateKeyIdentifier = @"com.microsoft.workplacejoin.privatekey\0";
static NSString *kECPrivateKeyTagSuffix = @"-EC";

@implementation MSIDWorkPlaceJoinUtilBase

+ (NSString *_Nullable)getWPJStringDataForIdentifier:(nonnull NSString *)identifier
                                         accessGroup:(nullable NSString *)accessGroup
                                             context:(id<MSIDRequestContext>_Nullable)context
                                               error:(NSError*__nullable*__nullable)error
{
    return [self getWPJStringDataFromV2ForTenantId:nil
                                        identifier:identifier
                                               key:nil
                                       accessGroup:accessGroup
                                           context:context
                                             error:error];
}

+ (NSString *_Nullable)getWPJStringDataFromV2ForTenantId:(NSString *)tenantId
                                              identifier:(nonnull NSString *)identifier
                                                     key:(nullable NSString *)key
                                             accessGroup:(nullable NSString *)accessGroup
                                                 context:(id<MSIDRequestContext>_Nullable)context
                                                   error:(NSError*__nullable*__nullable)error
{
    // Building dictionary to retrieve given identifier from the keychain
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
    [query setObject:(__bridge id)(kSecClassGenericPassword) forKey:(__bridge id<NSCopying>)(kSecClass)];
    if (tenantId)
    {
        [query setObject:tenantId forKey:(__bridge id<NSCopying>)(kSecAttrService)];
    }
    else
    {
        [query setObject:identifier forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];
    }
    [query setObject:(id)kCFBooleanTrue forKey:(__bridge id<NSCopying>)(kSecReturnAttributes)];
    if (accessGroup)
    {
        [query setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
    }

    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status != errSecSuccess)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"String Data not found with error code:%d", (int)status);

        return nil;
    }
    NSString *stringData;
    if (tenantId && key)
    {
        stringData = [(__bridge NSDictionary *)result objectForKey:key];
    }
    else
    {
        stringData = [(__bridge NSDictionary *)result objectForKey:(__bridge id)(kSecAttrService)];
    }

    if (result)
    {
        CFRelease(result);
    }

    if (!stringData || stringData.msidTrimmedString.length == 0)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Found empty keychain item.", nil, nil, nil, context.correlationId, nil, NO);
        }
    }

    return stringData;
}

+ (nullable NSDictionary *)getRegisteredDeviceMetadataInformation:(nullable id<MSIDRequestContext>)context
{
    return [self getRegisteredDeviceMetadataInformation:context tenantId:nil];
}

+ (nullable NSDictionary *)getRegisteredDeviceMetadataInformation:(nullable id<MSIDRequestContext>)context tenantId:(nullable NSString *)tenantId
{
    MSIDWPJKeyPairWithCert *wpjCerts = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:tenantId context:context];
    NSString *userPrincipalName;
    NSString *fetchedTenantId;
    if (wpjCerts)
    {
        if (wpjCerts.keyChainVersion != MSIDWPJKeychainAccessGroupV2)
        {
            userPrincipalName = [MSIDWorkPlaceJoinUtil getWPJStringDataForIdentifier:kMSIDUPNKeyIdentifier context:context error:nil];
            fetchedTenantId = [MSIDWorkPlaceJoinUtil getWPJStringDataForIdentifier:kMSIDTenantKeyIdentifier context:context error:nil];
        }
        else
        {
            NSString *formattedKeyForUPN = (__bridge NSString * )kSecAttrLabel;
            NSString *formattedKeyForTenantId = (__bridge NSString *)kSecAttrService;
            userPrincipalName = [MSIDWorkPlaceJoinUtil getWPJStringDataFromV2ForTenantId:tenantId identifier:kMSIDUPNKeyIdentifier key:formattedKeyForUPN context:context error:nil];
            fetchedTenantId = [MSIDWorkPlaceJoinUtil getWPJStringDataFromV2ForTenantId:tenantId identifier:kMSIDTenantKeyIdentifier key:formattedKeyForTenantId context:context error:nil];
        }
        NSMutableDictionary *registrationInfoMetadata = [NSMutableDictionary new];

        // Certificate subject is nothing but the AAD deviceID
        [registrationInfoMetadata setValue:wpjCerts.certificateSubject forKey:MSID_DEVICE_INFORMATION_AAD_DEVICE_ID_KEY];
        [registrationInfoMetadata setValue:userPrincipalName forKey:MSID_DEVICE_INFORMATION_UPN_ID_KEY];
        [registrationInfoMetadata setValue:fetchedTenantId forKey:MSID_DEVICE_INFORMATION_AAD_TENANT_ID_KEY];
        return registrationInfoMetadata;
    }

    return nil;
}
+ (nullable MSIDWPJKeyPairWithCert *)findWPJRegistrationInfoWithAdditionalPrivateKeyAttributes:(nonnull NSDictionary *)queryAttributes
                                                                                certAttributes:(nullable NSDictionary *)certAttributes
                                                                                       context:(nullable id<MSIDRequestContext>)context
{
    OSStatus status = noErr;
    CFTypeRef privateKeyCFDict = NULL;
    
    // Set the private key query dictionary.
    NSMutableDictionary *queryPrivateKey = [NSMutableDictionary new];
    
    if (queryAttributes)
    {
        [queryPrivateKey addEntriesFromDictionary:queryAttributes];
    }
    
    queryPrivateKey[(__bridge id)kSecClass] = (__bridge id)kSecClassKey;
    queryPrivateKey[(__bridge id)kSecReturnAttributes] = @YES;
    queryPrivateKey[(__bridge id)kSecReturnRef] = @YES;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)queryPrivateKey, (CFTypeRef*)&privateKeyCFDict); // +1 privateKeyCFDict
    if (status != errSecSuccess)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to find workplace join private key with status %ld", (long)status);
        return nil;
    }
        
    NSDictionary *privateKeyDict = CFBridgingRelease(privateKeyCFDict); // -1 privateKeyCFDict
    
    /*
     kSecAttrApplicationLabel
     For asymmetric keys this holds the public key hash which allows digital identity formation (to form a digital identity, this value must match the kSecAttrPublicKeyHash ('pkhh') attribute of the certificate)
     */
    NSData *applicationLabel = privateKeyDict[(__bridge id)kSecAttrApplicationLabel];

    if (!applicationLabel)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unexpected key found without application label. Aborting lookup");
        return nil;
    }
    
    SecKeyRef privateKeyRef = (__bridge SecKeyRef)privateKeyDict[(__bridge id)kSecValueRef];
    
    if (!privateKeyRef)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"No private key ref found. Aborting lookup.");
        return nil;
    }
    
    NSMutableDictionary *mutableCertQuery = [NSMutableDictionary new];
    if (certAttributes)
    {
        [mutableCertQuery addEntriesFromDictionary:certAttributes];
#if TARGET_OS_OSX
        if (@available(macOS 10.15, *))
        {
            [mutableCertQuery setObject:@YES forKey:(__bridge id)kSecUseDataProtectionKeychain];
        }
#endif
    }
    
    mutableCertQuery[(__bridge id)kSecClass] = (__bridge id)kSecClassCertificate;
    mutableCertQuery[(__bridge id)kSecAttrPublicKeyHash] = applicationLabel;
    mutableCertQuery[(__bridge id)kSecReturnRef] = @YES;
    
    SecCertificateRef certRef;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)mutableCertQuery, (CFTypeRef*)&certRef); // +1 certRef
    
    if (status != errSecSuccess || !certRef)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to find certificate for public key hash with status %ld", (long)status);
        return nil;
    }
    
    MSIDWPJKeyPairWithCert *keyPair = [[MSIDWPJKeyPairWithCert alloc] initWithPrivateKey:privateKeyRef
                                                                             certificate:certRef
                                                                       certificateIssuer:nil];
    CFReleaseNull(certRef);
    return keyPair;
}

+ (MSIDWPJKeyPairWithCert *)getWPJKeysWithTenantId:(__unused NSString *)tenantId context:(__unused id<MSIDRequestContext>)context
{
    NSString *teamId = [[MSIDKeychainUtil sharedInstance] teamId];
    
    if (!teamId)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Encountered an error when reading teamID from keychain.");
        return nil;
    }
    
    NSData *tagData = [kMSIDPrivateKeyIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    NSString *legacySharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin", teamId];
    NSDictionary *extraCertAttributes =  @{ (__bridge id)kSecAttrAccessGroup :  legacySharedAccessGroup};
    
    // Legacy registrations would have be done using RSA, passing keyType = RSA in query
    NSMutableDictionary *extraPrivateKeyAttributes = [[NSMutableDictionary alloc] initWithDictionary:@{ (__bridge id)kSecAttrApplicationTag: tagData,
                                                                                                        (__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeRSA,
                                                                                                        (__bridge id)kSecAttrAccessGroup : legacySharedAccessGroup}];
    // For macOS, access group should not be included if kSecUseDataProtectionKeychain = NO as some older versions might throw an error. On macOS, access group should only be specified if kSecUseDataProtectionKeychain  = YES
#if TARGET_OS_OSX
    [extraPrivateKeyAttributes removeObjectForKey:(__bridge id)kSecAttrAccessGroup];
    extraCertAttributes = nil;
#endif
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Checking Legacy keychain for registration.");
    MSIDWPJKeyPairWithCert *legacyKeys = [self findWPJRegistrationInfoWithAdditionalPrivateKeyAttributes:extraPrivateKeyAttributes certAttributes:extraCertAttributes context:context];
        
    if (legacyKeys)
    {
        legacyKeys.keyChainVersion = MSIDWPJKeychainAccessGroupV1;
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Returning RSA private device key from legacy registration.");
        if ([NSString msidIsStringNilOrBlank:tenantId])
        {
            // ESTS didn't request a specific tenant, just return default one
            return legacyKeys;
        }
        
        // Read tenantId for legacy identity
        NSError *tenantIdError = nil;
        NSString *registrationTenantId = [MSIDWorkPlaceJoinUtil getWPJStringDataForIdentifier:kMSIDTenantKeyIdentifier context:context error:&tenantIdError];
        
        // There's no tenantId on the registration, or it mismatches what server requested, keep looking for a better match. Otherwise, return the identity already.
        if (!tenantIdError
            && registrationTenantId
            && [registrationTenantId isEqualToString:tenantId])
        {
            return legacyKeys;
        }
    }
    
    // Default registrations can be done using RSA/ECC in iOS and only ECC in macOS.
    NSString *tag = nil;
    __unused MSIDWPJKeyPairWithCert *defaultKeys = nil;
    NSString *defaultSharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", teamId];
    extraCertAttributes = @{ (__bridge id)kSecAttrAccessGroup : defaultSharedAccessGroup };
    
    // In macOS, default registrations can only be ECC. Skip checking default RSA registration for macOS.
#if !TARGET_OS_OSX
    // When checking for RSA default registration, a tenantId is required to be known
    if (tenantId != nil)
    {
        tag = [NSString stringWithFormat:@"%@#%@", kWPJPrivateKeyIdentifier, tenantId];
        tagData = [tag dataUsingEncoding:NSUTF8StringEncoding];
         // 1st Looking for RSA device key in the keychain.
        __unused NSDictionary *extraDefaultPrivateKeyAttributes = @{ (__bridge id)kSecAttrApplicationTag : tagData,
                                                            (__bridge id)kSecAttrAccessGroup : defaultSharedAccessGroup,
                                                            (__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeRSA };
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Checking keychain for default registration done using RSA key.");
        defaultKeys = [self findWPJRegistrationInfoWithAdditionalPrivateKeyAttributes:extraDefaultPrivateKeyAttributes certAttributes:extraCertAttributes context:context];

        // If secondary Identity was found, return it
        if (defaultKeys)
        {
            defaultKeys.keyChainVersion = MSIDWPJKeychainAccessGroupV2;
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Returning RSA private device key from default registration.");
            return defaultKeys;
        }
    }
#endif
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Checking keychain for default registration done using ECC key.");
    // If tenantId is missing, the caller may have requested for ECC primary registration. Query keychain to get the ECC primary registration tenantId
    if (tenantId == nil)
    {
        NSError *error;
        NSString *primaryRegTenantId = [MSIDWorkPlaceJoinUtilBase getPrimaryEccTenantWithSharedAccessGroup:defaultSharedAccessGroup context:context error:&error];
        if (!primaryRegTenantId)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, error.description, error.code);
            // If tenantId for default primary registration is not found, default registration should have a tenantId associated with it, fast returning here.
            return nil;
        }
        tenantId = primaryRegTenantId;
    }
   
    // Since the defualt RSA search returned nil in iOS, the key might be an ECC key. Use the tag specific for EC device key and re-try
    tag = [NSString stringWithFormat:@"%@#%@%@", kWPJPrivateKeyIdentifier, tenantId, kECPrivateKeyTagSuffix];
    tagData = [tag dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *privateKeyAttributes = [[NSMutableDictionary alloc] initWithDictionary:@{ (__bridge id)kSecAttrApplicationTag : tagData,
                                                                                                   (__bridge id)kSecAttrAccessGroup : defaultSharedAccessGroup,
                                                                                                   // Not including kSecAttrTokenIDSecureEnclave in query dict as in the future registrations maybe ECC based even in software keychain
                                                                                                   (__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
                                                                                                   (__bridge id)kSecAttrKeySizeInBits : @256
                                                                                                }];
#if TARGET_OS_OSX
    if (@available(macOS 10.15, *))
    {
        [privateKeyAttributes setObject:@YES forKey:(__bridge id)kSecUseDataProtectionKeychain];
    }
#endif
    defaultKeys = [self findWPJRegistrationInfoWithAdditionalPrivateKeyAttributes:privateKeyAttributes certAttributes:extraCertAttributes context:context];
    if (defaultKeys)
    {
        defaultKeys.keyChainVersion = MSIDWPJKeychainAccessGroupV2;
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Returning EC private device key from default registration.");
        return defaultKeys;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Returning RSA private device key from legacy registration..");
    // Otherwise, return legacy Identity - this can happen if we couldn't match based on the tenantId, but Identity was there. It could be usable. We'll let ESTS to evaluate it and check.
    // This means that for registrations that have no tenantId stored, we'd always do this extra query until registration gets updated to have the tenantId stored on it.
    return legacyKeys;
}

+ (NSString *)getPrimaryEccTenantWithSharedAccessGroup:(NSString *)sharedAccessGroup context:(id<MSIDRequestContext>_Nullable)context error:(NSError **)error
{
    NSString *res = nil;
    NSMutableDictionary *query = [NSMutableDictionary new];
    query[(__bridge id <NSCopying>) (kSecClass)] = (__bridge id) (kSecClassGenericPassword);
    query[(__bridge id <NSCopying>) (kSecReturnAttributes)] = (id) kCFBooleanTrue;
    query[(__bridge id <NSCopying>) (kSecAttrAccount)] = @"ecc_default_tenant";
    query[(__bridge id <NSCopying>) (kSecAttrService)] = @"ecc_default_tenant";
#if TARGET_OS_OSX
    if (@available(macOS 10.15, *)) {
        query[(__bridge id <NSCopying>) (kSecUseDataProtectionKeychain)] = @YES;
    }
#endif
    query[(__bridge id) kSecAttrAccessGroup] = sharedAccessGroup;
    CFDictionaryRef attributeDictCF = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef) query, (CFTypeRef *) &attributeDictCF);
    if (status == errSecSuccess && attributeDictCF)
    {
        NSDictionary *attributeDictionary = CFBridgingRelease(attributeDictCF);
        NSString *primaryECCTenant = attributeDictionary[(__bridge id) kSecAttrDescription];
        if (![NSString msidIsStringNilOrBlank:primaryECCTenant])
        {
            res = primaryECCTenant;
        }
        else
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Corrupted primary ECC tenant value", nil, nil, nil, context.correlationId, nil, NO);
            }
        }
    }
    else
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Could not get default primary registration tenantId.", nil, nil, nil, context.correlationId, nil, NO);
        }
    }
    return res;
}


@end
