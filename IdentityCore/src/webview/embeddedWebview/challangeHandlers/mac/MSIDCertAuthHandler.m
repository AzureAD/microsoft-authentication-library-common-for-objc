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

#import "MSIDCertAuthHandler.h"
#import "MSIDCertificateChooser.h"

@implementation MSIDCertAuthHandler

+ (void)resetHandler
{
    
}

+ (BOOL)handleChallenge:(NSURLAuthenticationChallenge *)challenge
                webview:(WKWebView *)webview
                context:(id<MSIDRequestContext>)context
      completionHandler:(ChallengeCompletionHandler)completionHandler
{
    NSString *host = challenge.protectionSpace.host;
    NSArray<NSData*> *distinguishedNames = challenge.protectionSpace.distinguishedNames;
    
    // Check if a preferred identity is set for this host
    SecIdentityRef identity = SecIdentityCopyPreferred((CFStringRef)host, NULL, (CFArrayRef)distinguishedNames);
    
    if (!identity)
    {
        // If there was no identity matched for the exact host, try to match by URL
        // URL matching is more flexible, as it's doing a wildcard matching for different subdomains
        // However, we need to do both, because if there's an entry by hostname, matching by URL won't find it
        identity = SecIdentityCopyPreferred((CFStringRef)webview.URL.absoluteString, NULL, (CFArrayRef)distinguishedNames);
    }
    
    if (identity != NULL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Using preferred identity");
        [self respondCertAuthChallengeWithIdentity:identity context:context completionHandler:completionHandler];
    }
    else
    {
        // If not prompt the user to select an identity
        [self promptUserForIdentity:distinguishedNames
                               host:host
                            webview:webview
                      correlationId:context.correlationId
                  completionHandler:^(SecIdentityRef identity)
         {
             if (identity == NULL)
             {
                 MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"No identity returned from cert chooser");
                 
                 // If no identity comes back then we can't handle the request
                 completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
                 return;
             }
             
             // Adding a retain count to match the retain count from SecIdentityCopyPreferred
             CFRetain(identity);
             MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Using user selected certificate");
             [self respondCertAuthChallengeWithIdentity:identity context:context completionHandler:completionHandler];
         }];
    }
    
    return YES;
}

+ (void)respondCertAuthChallengeWithIdentity:(nonnull SecIdentityRef)identity
                                     context:(id<MSIDRequestContext>)context
                           completionHandler:(ChallengeCompletionHandler)completionHandler
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Responding to cert auth challenge with certicate");
    /*
     The `certificates` parameter accepts an array of /intermediate/ certificates leading from the leaf to the root.  It must not include the leaf certificate because the system gets that from the digital identity.  It should not include a root certificate because, when the server does trust evaluation on the leaf, it already has a copy of the relevant root. Therefore, we are sending "nil" to the certificates array.
     */
    NSURLCredential *credential = [[NSURLCredential alloc] initWithIdentity:identity certificates:nil persistence:NSURLCredentialPersistenceNone];
    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    CFRelease(identity);
}


+ (void)promptUserForIdentity:(NSArray *)issuers
                         host:(NSString *)host
                      webview:(WKWebView *)webview
                correlationId:(NSUUID *)correlationId
            completionHandler:(void (^)(SecIdentityRef identity))completionHandler
{
    NSMutableDictionary *query =
    [@{
       (id)kSecClass : (id)kSecClassIdentity,
       (id)kSecMatchLimit : (id)kSecMatchLimitAll,
       } mutableCopy];
    
    if (issuers.count > 0)
    {
        [query setObject:issuers forKey:(id)kSecMatchIssuers];
    }
    
    CFTypeRef result = NULL;
    
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelInfo, correlationId, @"No certificate found matching challenge");
        completionHandler(nil);
        return;
    }
    else if (status != errSecSuccess)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, correlationId, @"Failed to find identity matching issuers with %d error.", status);
        completionHandler(nil);
        return;
    }
    
    [MSIDCertificateChooserHelper showCertSelectionSheet:(__bridge NSArray *)result host:host webview:webview correlationId:correlationId completionHandler:completionHandler];
}


@end
