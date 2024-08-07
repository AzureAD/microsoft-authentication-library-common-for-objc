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
#import "MSIDExternalSSOContext.h"

@implementation MSIDWorkPlaceJoinUtil

+ (MSIDWPJKeyPairWithCert *)wpjKeyPairWithSSOContext:(MSIDExternalSSOContext *)ssoContext
                                            tenantId:(NSString *)tenantId
                                             context:(id<MSIDRequestContext>)context
{
    return nil;
}

+ (MSIDRegistrationInformation *)getRegistrationInformation:(id<MSIDRequestContext>)context
                                     workplacejoinChallenge:(__unused MSIDWorkplaceJoinChallenge *)workplacejoinChallenge
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
    OSStatus status = noErr;
    NSString *certificateIssuer = nil;
    NSDictionary *keyDict = nil;
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"Attempting to get registration information - %@ shared access Group.", MSID_PII_LOG_MASKABLE(sharedAccessGroup));
    
    identity = [self copyWPJIdentity:context sharedAccessGroup:sharedAccessGroup certificateIssuer:&certificateIssuer privateKeyDict:&keyDict];
    if (!identity || CFGetTypeID(identity) != SecIdentityGetTypeID())
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Failed to retrieve WPJ identity. Identity is nil: %@", @(identity == nil));
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
    
    if (!(certificate && privateKey && certificateIssuer))
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"WPJ identity retrieved from keychain is invalid.");
    }
    else
    {
        info = [[MSIDRegistrationInformation alloc] initWithIdentity:identity
                                                          privateKey:privateKey
                                                         certificate:certificate
                                                   certificateIssuer:certificateIssuer];
        if (!info)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Registration information failed to be created");
        }
    }
    
    CFReleaseNull(identity);
    CFReleaseNull(certificate);
    CFReleaseNull(privateKey);
    
    return info;
}

+ (SecIdentityRef)copyWPJIdentity:(__unused id<MSIDRequestContext>)context
                sharedAccessGroup:(NSString *)accessGroup
                certificateIssuer:(NSString *__autoreleasing*)issuer
                   privateKeyDict:(NSDictionary *__autoreleasing*)keyDict

{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"Attempting to get registration information - %@ shared access Group", accessGroup);
    
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
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"Attempting to get registration information failed - %@ shared access Group - status %d", accessGroup, (int)status);
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
                                               error:(NSError*__nullable __autoreleasing*__nullable)error
{
    return [self getWPJStringDataFromV2ForTenantId:nil identifier:identifier key:nil context:context error:error];
}

+ (nullable NSString *)getWPJStringDataFromV2ForTenantId:(NSString *)tenantId
                                              identifier:(nonnull NSString *)identifier
                                                     key:(nullable NSString *)key
                                                 context:(nullable id<MSIDRequestContext>)context
                                                   error:(NSError*__nullable __autoreleasing*__nullable)error
{
    NSString *teamId = [[MSIDKeychainUtil sharedInstance] teamId];

    if (!teamId)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Encountered an error when reading teamID from keychain.");
        return nil;
    }
    
    if (tenantId)
    {
        NSString *sharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", teamId];
        return [self getWPJStringDataFromV2ForTenantId:tenantId identifier:identifier key:key accessGroup:sharedAccessGroup context:context error:error];
    }
    else
    {
        NSString *sharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin", teamId];
        return [self getWPJStringDataForIdentifier:identifier accessGroup:sharedAccessGroup context:context error:error];
    }

}

@end
