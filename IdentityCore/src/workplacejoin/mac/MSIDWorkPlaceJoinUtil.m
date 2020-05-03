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

// Convenience macro to release CF objects

@implementation MSIDWorkPlaceJoinUtil

+ (MSIDRegistrationInformation *)getRegistrationInformation:(id<MSIDRequestContext>)context
                                     workplacejoinChallenge:(MSIDWorkplaceJoinChallenge *)workplacejoinChallenge
{
    MSIDRegistrationInformation *info = nil;
        
    if (![workplacejoinChallenge.certAuthorities count])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"No cert authorities provided in the request. Looking up default WPJ certificate");
        info = [self findDefaultWPJRegistrationInfoWithContext:context];
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Looking up workplace join certificate by authorities");
        info = [self findWPJRegistrationInfoWithAuthorities:workplacejoinChallenge.certAuthorities
                                                    context:context];
    }
    
    return info;
}

#pragma mark - Registration info

+ (MSIDRegistrationInformation *)registrationInformationWithIdentity:(SecIdentityRef)identityRef
                                                         certificate:(SecCertificateRef)certRef
                                                          privateKey:(SecKeyRef)privateKeyRef
                                                      requestContext:(id<MSIDRequestContext>)context
{
    if (!certRef || !privateKeyRef)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"WPJ identity retrieved from keychain is invalid. Cert ref = %d, private key ref = %d, identity ref = %d", (int)(certRef != NULL), (int)(privateKeyRef != NULL), (int)(identityRef != NULL));
        CFReleaseNull(identityRef);
        CFReleaseNull(privateKeyRef);
        CFReleaseNull(certRef);
        return nil;
    }
    
    MSIDRegistrationInformation *info = nil;
    
    NSString *certificateSubject = (__bridge_transfer NSString*)(SecCertificateCopySubjectSummary(certRef));
    NSData *certificateData = (__bridge_transfer NSData*)(SecCertificateCopyData(certRef));
    NSData *certificateIssuerData = (__bridge_transfer NSData*)SecCertificateCopyNormalizedIssuerContent(certRef, NULL);
    NSString *certificateIssuerString = nil;
    
    if (certificateIssuerData)
    {
        certificateIssuerString = [[NSString alloc] initWithData:certificateIssuerData encoding:NSASCIIStringEncoding];
    }
    
    if (!certificateData || !certificateSubject)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"WPJ identity retrieved from keychain is invalid. Missing certificate data or subject");
    }
    else
    {
        // We found all the required WPJ information.
        info = [[MSIDRegistrationInformation alloc] initWithSecurityIdentity:identityRef
                                                           certificateIssuer:certificateIssuerString
                                                                 certificate:certRef
                                                          certificateSubject:certificateSubject
                                                             certificateData:certificateData
                                                                  privateKey:privateKeyRef];
    }
    
    CFReleaseNull(identityRef);
    CFReleaseNull(certRef);
    CFReleaseNull(privateKeyRef);
    
    return info;
}

#pragma mark - Lookup by identity

+ (MSIDRegistrationInformation *)findWPJRegistrationInfoWithAuthorities:(NSArray<NSData *> *)certAuthorities
                                                                context:(id<MSIDRequestContext>)context
{
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Attempting to get WPJ registration information.");
    SecIdentityRef identity = [self copyWPJIdentityWithAuthorities:certAuthorities];
    
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
    OSStatus status = SecIdentityCopyCertificate(identity, &certificateRef);
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"WPJ certificate retrieved with result %ld", (long)status);
    
    // Get the private key
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Retrieving WPJ private key reference.");
    SecKeyRef privateKeyRef = NULL;
    status = SecIdentityCopyPrivateKey(identity, &privateKeyRef);
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"WPJ private key reference retrieved with result %ld", (long)status);
    
    return [self registrationInformationWithIdentity:identity
                                         certificate:certificateRef
                                          privateKey:privateKeyRef
                                      requestContext:context];
}

+ (SecIdentityRef)copyWPJIdentityWithAuthorities:(NSArray<NSData *> *)authorities
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
                    break;
                }
            }
        }
    }
    
    CFReleaseNull(identityList);
    return identityRef; //Caller must call CFRelease
}

#pragma mark - Lookup by private key

+ (MSIDRegistrationInformation *)findDefaultWPJRegistrationInfoWithContext:(id<MSIDRequestContext>)context
{
    OSStatus status = noErr;
    CFTypeRef privateKeyCFDict = NULL;
    
    // Set the private key query dictionary.
    NSDictionary *queryCert = @{ (__bridge id)kSecClass : (__bridge id)kSecClassKey,
                                 (__bridge id)kSecAttrApplicationTag: kMSIDPrivateKeyIdentifier,
                                 (__bridge id)kSecReturnAttributes: @YES,
                                 (__bridge id)kSecReturnRef: @YES};
    
    // Get the certificate. If the certificate is not found, this is not considered an error.
    status = SecItemCopyMatching((__bridge CFDictionaryRef)queryCert, (CFTypeRef*)&privateKeyCFDict);
    if (status != errSecSuccess)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to find workplace join private key with status %ld", (long)status);
        return nil;
    }
        
    NSDictionary *privateKeyDict = CFBridgingRelease(privateKeyCFDict);
    
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
    
    SecKeyRef privateKeyRef = (SecKeyRef)CFBridgingRetain(privateKeyDict[(__bridge id)kSecValueRef]);
    
    if (!privateKeyRef)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"No private key ref found. Aborting lookup.");
        return nil;
    }
        
    NSDictionary *certQuery = @{(__bridge id)kSecClass : (__bridge id)kSecClassCertificate,
                                (__bridge id)kSecAttrPublicKeyHash: applicationLabel};
    
    SecCertificateRef certRef;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)certQuery, (CFTypeRef*)&certRef);
    
    if (status != errSecSuccess)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to find certificate for public key hash with status %ld", (long)status);
        return nil;
    }
    
    return [self registrationInformationWithIdentity:nil
                                         certificate:certRef
                                          privateKey:privateKeyRef
                                      requestContext:context];
}

@end
