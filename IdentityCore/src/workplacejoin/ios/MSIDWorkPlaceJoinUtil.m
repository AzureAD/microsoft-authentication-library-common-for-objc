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

#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDKeychainUtil.h"
#import "MSIDRegistrationInformation.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDError.h"
#import "MSIDWorkplaceJoinChallenge.h"
#import "MSIDWorkPlaceJoinUtilBase+Internal.h"

static NSString *kWPJPrivateKeyIdentifier = @"com.microsoft.workplacejoin.privatekey\0";

@implementation MSIDWorkPlaceJoinUtil

+ (nullable MSIDAssymetricKeyPairWithCert *)getWPJKeysWithContext:(nullable id<MSIDRequestContext>)context
{
    return [self getWPJKeysWithTenantId:nil context:context];
}

+ (MSIDAssymetricKeyPairWithCert *)getWPJKeysWithTenantId:(NSString *)tenantId context:(id<MSIDRequestContext>)context
{
    return [self getRegistrationInformation:context tenantId:tenantId workplacejoinChallenge:nil];
}

+ (MSIDRegistrationInformation *)getRegistrationInformation:(id<MSIDRequestContext>)context
                                     workplacejoinChallenge:(__unused MSIDWorkplaceJoinChallenge *)workplacejoinChallenge
{
    return [self getRegistrationInformation:context tenantId:nil workplacejoinChallenge:workplacejoinChallenge];
}

+ (MSIDRegistrationInformation *)getRegistrationInformation:(id<MSIDRequestContext>)context
                                                   tenantId:(NSString *)tenantId
                                     workplacejoinChallenge:(__unused MSIDWorkplaceJoinChallenge *)workplacejoinChallenge
{
    MSIDRegistrationInformation *info = nil;
    SecIdentityRef identity = NULL;
    SecCertificateRef certificate = NULL;
    SecKeyRef privateKey = NULL;
    OSStatus status = noErr;
    NSString *certificateIssuer = nil;
    NSDictionary *keyDict = nil;
    
    identity = [self copyWPJIdentityWithTenantId:tenantId context:context certificateIssuer:&certificateIssuer privateKeyDict:&keyDict];
    
    if (!identity || CFGetTypeID(identity) != SecIdentityGetTypeID())
    {
        
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Failed to retrieve WPJ identity.");
        CFReleaseNull(identity);
        return nil;
    }
    
    // Get the wpj certificate
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Retrieving WPJ certificate reference.");
    status = SecIdentityCopyCertificate(identity, &certificate);
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"WPJ certificate retrieved with result %ld", (long)status);
    
    // Get the private key
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Retrieving WPJ private key reference.");
    status = SecIdentityCopyPrivateKey(identity, &privateKey);
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"WPJ private key reference retrieved with result %ld", (long)status);
    
    // Get the public key
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Retrieving WPJ public key reference.");
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    
    if (!(certificate && publicKey && privateKey && certificateIssuer))
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"WPJ identity retrieved from keychain is invalid.");
    }
    else
    {
        info = [[MSIDRegistrationInformation alloc] initWithIdentity:identity
                                                          privateKey:privateKey
                                                           publicKey:publicKey
                                                         certificate:certificate
                                                   certificateIssuer:certificateIssuer
                                                      privateKeyDict:keyDict];
    }
    
    CFReleaseNull(identity);
    CFReleaseNull(certificate);
    CFReleaseNull(privateKey);
    CFReleaseNull(publicKey);
    
    return info;
}

+ (SecIdentityRef)copyWPJIdentityWithTenantId:(NSString *)tenantId
                                      context:(id<MSIDRequestContext>)context
                            certificateIssuer:(NSString **)issuer
                               privateKeyDict:(NSDictionary **)keyDict
{
    NSString *teamId = [[MSIDKeychainUtil sharedInstance] teamId];
    
    if (!teamId)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Encountered an error when reading teamID from keychain.");
        return nil;
    }
    
    NSString *legacySharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin", teamId];
    
    SecIdentityRef legacyIdentity = [self copyWPJIdentity:context tag:nil sharedAccessGroup:legacySharedAccessGroup certificateIssuer:issuer privateKeyDict:keyDict];
    
    if (legacyIdentity)
    {
        if ([NSString msidIsStringNilOrBlank:tenantId])
        {
            // ESTS didn't request a specific tenant, just return default one
            return legacyIdentity;
        }
        
        // Read tenantId for legacy identity
        NSString *registrationTenantId = [MSIDWorkPlaceJoinUtil getWPJStringDataForIdentifier:kMSIDTenantKeyIdentifier context:context error:nil];
        
        // There's no tenantId on the registration, or it mismatches what server requested, keep looking for a better match. Otherwise, return the identity already.
        if (![NSString msidIsStringNilOrBlank:registrationTenantId]
            && [registrationTenantId isEqualToString:tenantId])
        {
            return legacyIdentity;
        }
    }
    
    NSString *defaultSharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", teamId];
    NSString *tag = [NSString stringWithFormat:@"%@#%@", kWPJPrivateKeyIdentifier, tenantId];
    
    SecIdentityRef secondaryIdentity = [self copyWPJIdentity:context
                                                         tag:tag
                                           sharedAccessGroup:defaultSharedAccessGroup
                                           certificateIssuer:issuer
                                              privateKeyDict:keyDict];
    
    // If secondary Identity was found, return it
    if (secondaryIdentity)
    {
        return secondaryIdentity;
    }
    
    // Otherwise, return legacy Identity - this can happen if we couldn't match based on the tenantId, but Identity was there. It could be usable. We'll let ESTS to evaluate it and check.
    // This means that for registrations that have no tenantId stored, we'd always do this extra query until registration gets updated to have the tenantId stored on it.
    return legacyIdentity;
}

+ (SecIdentityRef)copyWPJIdentity:(id<MSIDRequestContext>)context
                              tag:(NSString *)tag
                sharedAccessGroup:(NSString *)accessGroup
                certificateIssuer:(NSString **)issuer
                   privateKeyDict:(NSDictionary **)keyDict

{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"Attempting to get registration information - %@ shared access Group, tag %@", MSID_PII_LOG_MASKABLE(accessGroup), tag);
    
    NSMutableDictionary *identityDict = [[NSMutableDictionary alloc] init];
    [identityDict setObject:(__bridge id)kSecClassIdentity forKey:(__bridge id)kSecClass];
    [identityDict setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnRef];
    [identityDict setObject:(__bridge id) kSecAttrKeyClassPrivate forKey:(__bridge id)kSecAttrKeyClass];
    [identityDict setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
    [identityDict setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
    
    if (![NSString msidIsStringNilOrBlank:tag])
    {
        NSData *tagData = [tag dataUsingEncoding:NSUTF8StringEncoding];
        [identityDict setObject:tagData forKey:(__bridge  id)kSecAttrApplicationTag];
    }
    
    CFDictionaryRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)identityDict, (CFTypeRef *)&result);
    
    if (status != errSecSuccess)
    {
        return NULL;
    }
    
    NSDictionary *resultDict = (__bridge_transfer NSDictionary *)result;
    NSData *certIssuer = [resultDict objectForKey:(__bridge NSString*)kSecAttrIssuer];
    
    if (issuer && certIssuer)
    {
        *issuer = [[NSString alloc] initWithData:certIssuer encoding:NSASCIIStringEncoding];
    }
    
    if (keyDict)
    {
        *keyDict = resultDict;
    }
    
    SecIdentityRef identityRef = (__bridge_retained SecIdentityRef)[resultDict objectForKey:(__bridge NSString*)kSecValueRef];
    return identityRef;
}

+ (nullable NSString *)getWPJStringDataForIdentifier:(nonnull NSString *)identifier
                                             context:(nullable id<MSIDRequestContext>)context
                                               error:(NSError*__nullable*__nullable)error
{
    NSString *teamId = [[MSIDKeychainUtil sharedInstance] teamId];

    if (!teamId)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Encountered an error when reading teamID from keychain.");
        return nil;
    }
    NSString *sharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin", teamId];

    return [self getWPJStringDataForIdentifier:identifier accessGroup:sharedAccessGroup context:context error:error];
}

@end
