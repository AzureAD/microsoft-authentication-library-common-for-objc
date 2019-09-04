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

// Convenience macro to release CF objects

@implementation MSIDWorkPlaceJoinUtil

+ (MSIDRegistrationInformation *)getRegistrationInformation:(id<MSIDRequestContext>)context
                                               urlChallenge:(NSURLAuthenticationChallenge *)challenge
{
    MSIDRegistrationInformation *info = nil;
    SecIdentityRef identity = NULL;
    SecCertificateRef certificate = NULL;
    SecKeyRef privateKey = NULL;
    NSString *certificateSubject = nil;
    NSData *certificateData = nil;
    NSString *certificateIssuer  = nil;
    OSStatus status = noErr;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Attempting to get WPJ registration information.");
    identity = [self copyWPJIdentity:context issuer:&certificateIssuer certificateAuthorities:challenge.protectionSpace.distinguishedNames];
    
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
    status = SecIdentityCopyCertificate(identity, &certificate);
    
    // Get the private key
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Retrieving WPJ private key reference.");
    status = SecIdentityCopyPrivateKey(identity, &privateKey);
    
    certificateSubject = (__bridge_transfer NSString*)(SecCertificateCopySubjectSummary(certificate));
    certificateData = (__bridge_transfer NSData*)(SecCertificateCopyData(certificate));
    
    if(!(certificate && certificateSubject && certificateData && privateKey && certificateIssuer))
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"WPJ identity retrieved from keychain is invalid.");
    }
    
    else
    {
        // We found all the required WPJ information.
        info = [[MSIDRegistrationInformation alloc] initWithSecurityIdentity:identity
                                                           certificateIssuer:certificateIssuer
                                                                 certificate:certificate
                                                          certificateSubject:certificateSubject
                                                             certificateData:certificateData
                                                                  privateKey:privateKey];
    }
    
    CFReleaseNull(identity);
    CFReleaseNull(certificate);
    CFReleaseNull(privateKey);
    return info;
}

+ (SecIdentityRef)copyWPJIdentity:(__unused id<MSIDRequestContext>)context
                           issuer:(NSString **)issuer
           certificateAuthorities:(NSArray<NSData *> *)authorities

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
                    
                    break;
                }
            }
        }
    }
    
    CFReleaseNull(identityList);
    return identityRef; //Caller must call CFRelease
}

@end
