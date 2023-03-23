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
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDRegistrationInformation.h"
#import "MSIDWorkplaceJoinChallenge.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDWorkPlaceJoinUtilBase+Internal.h"
#import "MSIDExternalSSOContext.h"
#import "MSIDAADAuthority.h"

// Convenience macro to release CF objects

@implementation MSIDWorkPlaceJoinUtil

+ (MSIDWPJKeyPairWithCert *)wpjKeyPairWithSSOContext:(MSIDExternalSSOContext *)ssoContext
                                            tenantId:(NSString *)tenantId
                                             context:(id<MSIDRequestContext>)context
{
    if (![NSString msidIsStringNilOrBlank:tenantId])
    {
        NSURL *tokenEndpointURL = ssoContext.tokenEndpointURL;
        
        if (tokenEndpointURL)
        {
            NSError *authorityURLError = nil;
            MSIDAADAuthority *authorityURL = [[MSIDAADAuthority alloc] initWithURL:tokenEndpointURL
                                                                         rawTenant:nil
                                                                           context:context
                                                                             error:&authorityURLError];
            
            if (!authorityURL)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to create authority URL with error %@", authorityURLError);
                return nil;
            }
            else if (![authorityURL.tenant.rawTenant.lowercaseString isEqualToString:tenantId.lowercaseString])
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"Tenant was specified for matching and it mismatches registration tenant, returning early. Specified tenant %@, registration tenant %@", tenantId, authorityURL.tenant.rawTenant);
                return nil;
            }
        }
    }
    
    return [ssoContext wpjKeyPairWithCertWithContext:context];
}

+ (MSIDRegistrationInformation *)getRegistrationInformation:(id<MSIDRequestContext>)context
                                     workplacejoinChallenge:(MSIDWorkplaceJoinChallenge *)workplacejoinChallenge
{
    if (![workplacejoinChallenge.certAuthorities count])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"No cert authorities provided in the request. Aborting the request.");
        return nil;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Looking up workplace join certificate by authorities");
    return [self findWPJRegistrationInfoWithAuthorities:workplacejoinChallenge.certAuthorities
                                                context:context];
}

#pragma mark - Lookup by identity

+ (MSIDRegistrationInformation *)findWPJRegistrationInfoWithAuthorities:(NSArray<NSData *> *)certAuthorities
                                                                context:(id<MSIDRequestContext>)context
{
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Attempting to get WPJ registration information.");
    NSString *certIssuer = nil;
    NSDictionary *keyDict = nil;
    SecIdentityRef identity = [self copyWPJIdentityWithAuthorities:certAuthorities issuer:&certIssuer privateKeyDict:&keyDict]; // +1 identity
    
    // If there's no identity in the keychain, return nil. adError won't be set if the
    // identity can't be found since this isn't considered an error condition.
    if (!identity || CFGetTypeID(identity) != SecIdentityGetTypeID())
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Failed to retrieve WPJ identity.");
        CFReleaseNull(identity);
        return nil;
    }
    
    // Get the wpj certificate
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Retrieving WPJ certificate reference.");
    SecCertificateRef certificateRef = NULL;
    OSStatus status = SecIdentityCopyCertificate(identity, &certificateRef); // +1 certificateRef
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"WPJ certificate retrieved with result %ld", (long)status);
    
    // Get the private key
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Retrieving WPJ private key reference.");
    SecKeyRef privateKeyRef = NULL;
    status = SecIdentityCopyPrivateKey(identity, &privateKeyRef); // +1 privateKeyRef
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"WPJ private key reference retrieved with result %ld", (long)status);
    
    MSIDRegistrationInformation *info = nil;
    
    if (!certificateRef || !privateKeyRef)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"WPJ identity retrieved from keychain is invalid. Cert ref = %d, private key ref = %d", (int)(certificateRef != NULL), (int)(privateKeyRef != NULL));
    }
    else
    {
        // We found all the required WPJ information.
        info = [[MSIDRegistrationInformation alloc] initWithIdentity:identity
                                                          privateKey:privateKeyRef
                                                         certificate:certificateRef
                                                   certificateIssuer:certIssuer];
    }
    
    CFReleaseNull(identity);
    CFReleaseNull(privateKeyRef);
    CFReleaseNull(certificateRef);
    return info;
}

+ (SecIdentityRef)copyWPJIdentityWithAuthorities:(NSArray<NSData *> *)authorities issuer:(NSString **)issuer privateKeyDict:(NSDictionary **)keyDict
{
    if (![authorities count])
    {
        return NULL;
    }
    
    NSDictionary *query = @{ (__bridge id)kSecClass : (__bridge id)kSecClassIdentity,
                             (__bridge id)kSecReturnAttributes:(__bridge id)kCFBooleanTrue,
                             (__bridge id)kSecReturnRef :  (__bridge id)kCFBooleanTrue,
                             (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitAll,
                             (__bridge id)kSecMatchIssuers : authorities
                             };
    
    CFArrayRef identityList = NULL;
    SecIdentityRef identityRef = NULL;
    NSDictionary *identityDict = nil;
    NSData *currentIssuer = nil;
    NSString *currentIssuerName = nil;
    
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&identityList);
    
    if (status != errSecSuccess)
    {
        return NULL;
    }
    
    CFIndex identityCount = CFArrayGetCount(identityList);
    NSString *challengeIssuerName = [[NSString alloc] initWithData:authorities[0] encoding:NSASCIIStringEncoding];
    
    for (int resultIndex = 0; resultIndex < identityCount; resultIndex++)
    {
        identityDict = (NSDictionary *)CFArrayGetValueAtIndex(identityList, resultIndex);
        
        if ([identityDict isKindOfClass:[NSDictionary class]])
        {
            currentIssuer = [identityDict objectForKey:(__bridge NSString*)kSecAttrIssuer];
            
            if (currentIssuer)
            {
                currentIssuerName = [[NSString alloc] initWithData:currentIssuer encoding:NSASCIIStringEncoding];
                
                /* The issuer name returned from the certificate in keychain is capitalized but the issuer name returned from the TLS challenge is not.
                 Hence we need to do a caseInsenstitive compare to match the issuer.
                 */
                
                if ([challengeIssuerName caseInsensitiveCompare:currentIssuerName] == NSOrderedSame)
                {
                    identityRef = (__bridge_retained SecIdentityRef)[identityDict objectForKey:(__bridge NSString*)kSecValueRef];
                    if (issuer)
                    {
                        *issuer = currentIssuerName;
                    }
                    
                    if (keyDict)
                    {
                        *keyDict = identityDict;
                    }
                    
                    break;
                }
            }
        }
    }
    
    CFReleaseNull(identityList);
    return identityRef; //Caller must call CFRelease
}

#pragma mark - Lookup by private key

+ (nullable NSString *)getWPJStringDataForIdentifier:(nonnull NSString *)identifier
                                             context:(id<MSIDRequestContext>_Nullable)context
                                               error:(NSError*__nullable*__nullable)error
{
    return [self getWPJStringDataForIdentifier:identifier accessGroup:nil context:context error:error];
}

+ (nullable NSString *)getWPJStringDataFromV2ForTenantId:(NSString *_Nullable)tenantId
                                              identifier:(nonnull NSString *)identifier
                                                     key:(nullable NSString *)key
                                                 context:(nullable id<MSIDRequestContext>)context
                                                   error:(NSError*__nullable*__nullable)error
{
    return [self getWPJStringDataFromV2ForTenantId:tenantId identifier:identifier key:key accessGroup:nil context:context error:error];
}

@end
