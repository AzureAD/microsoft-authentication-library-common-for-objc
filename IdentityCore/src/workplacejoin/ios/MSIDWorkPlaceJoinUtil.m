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

@implementation MSIDWorkPlaceJoinUtil

// Convenience macro to release CF objects

+ (MSIDRegistrationInformation *)getRegistrationInformation:(id<MSIDRequestContext>)context
                                               urlChallenge:(__unused NSURLAuthenticationChallenge *)challenge
{
    NSString *teamId = [[MSIDKeychainUtil sharedInstance] teamId];
    
    if (!teamId)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Encountered an error when reading teamID from keychain.");
        return nil;
    }
    NSString *sharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin", teamId];
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"Attempting to get registration information - %@ shared access Group", MSID_PII_LOG_MASKABLE(sharedAccessGroup));
    MSIDRegistrationInformation *info = nil;
    SecIdentityRef identity = NULL;
    SecCertificateRef certificate = NULL;
    SecKeyRef privateKey = NULL;
    NSString *certificateSubject = nil;
    NSData *certificateData = nil;
    NSString *certificateIssuer = nil;
    OSStatus status = noErr;
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"Attempting to get registration information - %@ shared access Group.", MSID_PII_LOG_MASKABLE(sharedAccessGroup));
    
    identity = [self copyWPJIdentity:context sharedAccessGroup:sharedAccessGroup certificateIssuer:&certificateIssuer];
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
    
    certificateSubject = (NSString *)CFBridgingRelease(SecCertificateCopySubjectSummary(certificate));
    certificateData = (NSData *)CFBridgingRelease(SecCertificateCopyData(certificate));
    
    if (!(certificate && certificateSubject && certificateData && privateKey && certificateIssuer))
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"WPJ identity retrieved from keychain is invalid.");
    }
    else
    {
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
                sharedAccessGroup:(NSString *)accessGroup
                certificateIssuer:(NSString **)issuer

{
    NSMutableDictionary *identityDict = [[NSMutableDictionary alloc] init];
    [identityDict setObject:(__bridge id)kSecClassIdentity forKey:(__bridge id)kSecClass];
    [identityDict setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnRef];
    [identityDict setObject:(__bridge id) kSecAttrKeyClassPrivate forKey:(__bridge id)kSecAttrKeyClass];
    [identityDict setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
    [identityDict setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
    
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
    
    SecIdentityRef identityRef = (__bridge_retained SecIdentityRef)[resultDict objectForKey:(__bridge NSString*)kSecValueRef];
    return identityRef;
}

+ (nullable NSString*) getWPJStringData:(id<MSIDRequestContext>)context
                          identifier:(nonnull NSString*)identifier
                          error:(NSError*__nullable*__nullable)error
{

    NSString *teamId = [[MSIDKeychainUtil sharedInstance] teamId];

    if (!teamId)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Encountered an error when reading teamID from keychain.");
        return nil;
    }
    NSString *sharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin", teamId];

    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Shared access group: %@.", sharedAccessGroup);

    // Building dictionary to retrieve given identifier from the keychain
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
    [query setObject:(__bridge id)(kSecClassGenericPassword) forKey:(__bridge id<NSCopying>)(kSecClass)];
    [query setObject:identifier forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];
    [query setObject:(id)kCFBooleanTrue forKey:(__bridge id<NSCopying>)(kSecReturnAttributes)];

    // We only set the access group in case of non simulator device (simulator does not support keychain access groups)

#if TARGET_OS_IPHONE
    [query setObject:sharedAccessGroup forKey:(__bridge id)kSecAttrAccessGroup];
#endif

    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status != errSecSuccess)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"String Data not found for identifier %@ in shared access group: %@ with error code:%d", identifier, sharedAccessGroup, (int) status);
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to get items from keychain.", nil, nil, nil, context.correlationId, nil, NO);
        }

        if (result)
        {
            CFRelease(result);
        }

        return nil;
    }

    NSString *stringData = [(__bridge NSDictionary *)result objectForKey:(__bridge id)(kSecAttrService)];

    if (result)
    {
        CFRelease(result);
    }

    if (!stringData || [[stringData stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Found empty keychain item.", nil, nil, nil, context.correlationId, nil, NO);
        }
    }

    return stringData;
}

@end
