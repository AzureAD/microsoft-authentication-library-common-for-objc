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
    // Building dictionary to retrieve given identifier from the keychain
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
    [query setObject:(__bridge id)(kSecClassGenericPassword) forKey:(__bridge id<NSCopying>)(kSecClass)];
    [query setObject:identifier forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];
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

    NSString *stringData = [(__bridge NSDictionary *)result objectForKey:(__bridge id)(kSecAttrService)];

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
    MSIDWPJKeyPairWithCert *wpjCerts = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:nil context:context];

    if (wpjCerts)
    {
        NSString *userPrincipalName = [MSIDWorkPlaceJoinUtil getWPJStringDataForIdentifier:kMSIDUPNKeyIdentifier context:context error:nil];
        NSString *tenantId = [MSIDWorkPlaceJoinUtil getWPJStringDataForIdentifier:kMSIDTenantKeyIdentifier context:context error:nil];
        NSMutableDictionary *registrationInfoMetadata = [NSMutableDictionary new];

        // Certificate subject is nothing but the AAD deviceID
        [registrationInfoMetadata setValue:wpjCerts.certificateSubject forKey:MSID_DEVICE_INFORMATION_AAD_DEVICE_ID_KEY];
        [registrationInfoMetadata setValue:userPrincipalName forKey:MSID_DEVICE_INFORMATION_UPN_ID_KEY];
        [registrationInfoMetadata setValue:tenantId forKey:MSID_DEVICE_INFORMATION_AAD_TENANT_ID_KEY];
        return registrationInfoMetadata;
    }

    return nil;
}

+ (nullable MSIDWPJKeyPairWithCert *)findWPJRegistrationInfoWithAdditionalPrivateKeyAttributes:(nonnull NSDictionary *)queryAttributes
                                                                                certAttributes:(nullable NSDictionary *)certAttributes
                                                                                       context:(nullable id<MSIDRequestContext>)context
                                                                            shouldCheckEnclave:(BOOL)shouldCheckEnclave
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
        if (shouldCheckEnclave && privateKeyCFDict == NULL)
        {
            // Checking if key exists in Secure Enclave
            NSData *tagData = queryPrivateKey[(__bridge id)kSecAttrApplicationTag];
            NSString *tag = [[NSString alloc] initWithData:tagData encoding:NSUTF8StringEncoding];
            if (![tag hasSuffix:kECPrivateKeyTagSuffix])
            {
                tag = [NSString stringWithFormat:@"%@%@", tag, kECPrivateKeyTagSuffix];
                queryPrivateKey[(__bridge id)kSecAttrApplicationTag] = [tag dataUsingEncoding:NSUTF8StringEncoding];
            }
            status = SecItemCopyMatching((__bridge CFDictionaryRef)queryPrivateKey, (CFTypeRef*)&privateKeyCFDict); // +1 privateKeyCFDict
        }
        
        if (status != errSecSuccess)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to find workplace join private key with status %ld", (long)status);
            return nil;
        }
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
    }
    
#if TARGET_OS_OSX
    // For macOS, if the key is ECC key, use shared access group to query certificate. If it is RSA, remove shared access group from query for certificate as it is not login keychain.
        NSString *sharedAccessGroup = [certAttributes valueForKey:(__bridge id)kSecAttrAccessGroup];
        if (sharedAccessGroup && ![[MSIDKeyOperationUtil sharedInstance] isKeyFromSecureEnclave:privateKeyRef])
        {
            [mutableCertQuery removeObjectForKey:(__bridge id)kSecAttrAccessGroup];
        }
#endif
    
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
    
    NSString *legacySharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin", teamId];
    NSData *tagData = [kMSIDPrivateKeyIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *extraPrivateKeyAttributes = @{ (__bridge id)kSecAttrApplicationTag: tagData,
                                                 (__bridge id)kSecAttrAccessGroup : legacySharedAccessGroup };
    NSDictionary *extraCertAttributes = @{ (__bridge id)kSecAttrAccessGroup : legacySharedAccessGroup };
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Checking Legacy keychain for registration.");
    MSIDWPJKeyPairWithCert *legacyKeys = [self findWPJRegistrationInfoWithAdditionalPrivateKeyAttributes:extraPrivateKeyAttributes certAttributes:extraCertAttributes context:context shouldCheckEnclave:NO];
        
    if (legacyKeys)
    {
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
    
    if (!tenantId)
    {
        // default registration should have a tenantId associated.
        return legacyKeys;
    }
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Checking Default keychain for registration.");
    NSString *defaultSharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", teamId];
    NSString *tag = [NSString stringWithFormat:@"%@#%@", kWPJPrivateKeyIdentifier, tenantId];
    tagData = [tag dataUsingEncoding:NSUTF8StringEncoding];
    
    extraPrivateKeyAttributes = @{ (__bridge id)kSecAttrApplicationTag : tagData,
                                   (__bridge id)kSecAttrAccessGroup : defaultSharedAccessGroup };
    
    extraCertAttributes = @{ (__bridge id)kSecAttrAccessGroup : defaultSharedAccessGroup };
    
    MSIDWPJKeyPairWithCert *defaultKeys = [self findWPJRegistrationInfoWithAdditionalPrivateKeyAttributes:extraPrivateKeyAttributes certAttributes:extraCertAttributes context:context shouldCheckEnclave:YES];
     
    // If secondary Identity was found, return it
    if (defaultKeys)
    {
        return defaultKeys;
    }
        
    // Otherwise, return legacy Identity - this can happen if we couldn't match based on the tenantId, but Identity was there. It could be usable. We'll let ESTS to evaluate it and check.
    // This means that for registrations that have no tenantId stored, we'd always do this extra query until registration gets updated to have the tenantId stored on it.
    return legacyKeys;
}

@end
