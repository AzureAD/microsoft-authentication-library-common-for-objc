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

#import "MSIDChallengeHandler.h"
#import "MSIDClientTLSHandler.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDRegistrationInformation.h"
#import "MSIDWorkPlaceJoinConstants.h"
#if TARGET_OS_OSX
#import "MSIDCertificateChooser.h"
#endif

#if TARGET_OS_IPHONE
#import "MSIDWebviewAuthorization.h"
#import <SafariServices/SafariServices.h>
#import "MSIDWebviewInteracting.h"
#import "UIApplication+MSIDExtensions.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"

static NSArray<UIActivity *> *s_activities = nil;
static NSObject<SFSafariViewControllerDelegate> *s_safariDelegate = nil;
static NSURL *s_endURL = nil;
static SFSafariViewController *s_safariController = nil;
static dispatch_semaphore_t s_sem = nil;
static BOOL s_certAuthInProgress = NO;

@interface MSIDCertAuthDelegate: NSObject<SFSafariViewControllerDelegate>
@end

@implementation MSIDCertAuthDelegate
/*! @abstract Delegate callback called when the user taps the Done button. Upon this call, the view controller is dismissed modally. */
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    [MSIDClientTLSHandler authFailed];
}

/*! @abstract Invoked when the initial URL load is complete.
 @param didLoadSuccessfully YES if loading completed successfully, NO if loading failed.
 @discussion This method is invoked when SFSafariViewController completes the loading of the URL that you pass
 to its initializer. It is not invoked for any subsequent page loads in the same SFSafariViewController instance.
 */
- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully
{
    
}

- (NSArray<UIActivity*>*)safariViewController:(SFSafariViewController *)controller activityItemsForURL:(NSURL *)URL title:(NSString *)title
{
    return s_activities;
}
@end
#endif


@implementation MSIDClientTLSHandler

+ (void)load
{
    [MSIDChallengeHandler registerHandler:self authMethod:NSURLAuthenticationMethodClientCertificate];
#if TARGET_OS_IPHONE
    s_safariDelegate = [MSIDCertAuthDelegate new];
#endif
}

+ (void)resetHandler { }

+ (BOOL)handleChallenge:(NSURLAuthenticationChallenge *)challenge
                webview:(WKWebView *)webview
                context:(id<MSIDRequestContext>)context
      completionHandler:(ChallengeCompletionHandler)completionHandler
{
    NSString *host = challenge.protectionSpace.host;
    
    MSID_LOG_INFO(context, @"Attempting to handle client TLS challenge");
    MSID_LOG_INFO_PII(context, @"Attempting to handle client TLS challenge. host: %@", host);
    
    // See if this is a challenge for the WPJ cert.
    NSArray<NSData*> *distinguishedNames = challenge.protectionSpace.distinguishedNames;
    if ([self isWPJChallenge:distinguishedNames])
    {
        return [self handleWPJChallenge:challenge context:context completionHandler:completionHandler];
    }
    
    return [self handleCertAuthChallenge:challenge webview:webview context:context completionHandler:completionHandler];
}

#pragma mark - WPJ
+ (BOOL)isWPJChallenge:(NSArray *)distinguishedNames
{
    
    for (NSData *distinguishedName in distinguishedNames)
    {
        NSString *distinguishedNameString = [[[NSString alloc] initWithData:distinguishedName encoding:NSISOLatin1StringEncoding] lowercaseString];
        if ([distinguishedNameString containsString:[kMSIDProtectionSpaceDistinguishedName lowercaseString]])
        {
            return YES;
        }
    }
    
    return NO;
}

+ (BOOL)handleWPJChallenge:(NSURLAuthenticationChallenge *)challenge
                   context:(id<MSIDRequestContext>)context
         completionHandler:(ChallengeCompletionHandler)completionHandler
{
    MSIDRegistrationInformation *info = [MSIDWorkPlaceJoinUtil getRegistrationInformation:context error:nil];
    if (!info || ![info isWorkPlaceJoined])
    {
        MSID_LOG_INFO(context, @"Device is not workplace joined");
        MSID_LOG_INFO_PII(context, @"Device is not workplace joined. host: %@", challenge.protectionSpace.host);
        
        // In other cert auth cases we send Cancel to ensure that we continue to get
        // auth challenges, however when we do that with WPJ we don't get the subsequent
        // enroll dialog *after* the failed clientTLS challenge.
        //
        // Using DefaultHandling will result in the OS not handing back client TLS
        // challenges for another ~60 seconds, behavior that looks broken in the
        // user CBA case, but here is masked by the user having to enroll their
        // device.
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return YES;
    }
    
    MSID_LOG_INFO(context, @"Responding to WPJ cert challenge");
    MSID_LOG_INFO_PII(context, @"Responding to WPJ cert challenge. host: %@", challenge.protectionSpace.host);
    
    NSURLCredential *creds = [NSURLCredential credentialWithIdentity:info.securityIdentity
                                                        certificates:@[(__bridge id)info.certificate]
                                                         persistence:NSURLCredentialPersistenceNone];
    
    completionHandler(NSURLSessionAuthChallengeUseCredential, creds);
    
    return YES;
}


#pragma mark - CBA

#if TARGET_OS_IPHONE
+ (void)setCustomActivities:(NSArray<UIActivity *> *)activities
{
    s_activities = activities;
}

+ (void)setEndURL:(NSURL *)url
{
    if (s_safariController)
    {
        s_endURL = url;
        dispatch_async(dispatch_get_main_queue(), ^{
            [s_safariController dismissViewControllerAnimated:YES completion:nil];
        });
        dispatch_semaphore_signal(s_sem);
    }
    return;
}

+ (void)authFailed
{
    if (s_sem)
    {
        dispatch_semaphore_signal(s_sem);
    }
}

+ (BOOL)handleCertAuthChallenge:(NSURLAuthenticationChallenge *)challenge
                        webview:(WKWebView *)webview
                        context:(id<MSIDRequestContext>)context
              completionHandler:(ChallengeCompletionHandler)completionHandler
{
    MSIDWebviewSession *currentSession = [MSIDWebviewAuthorization currentSession];
    NSURL *requestURL = [currentSession.webviewController startURL];
    
    if (!currentSession)
    {
        MSID_LOG_ERROR(context, @"There is no current session open to continue with the cert auth challenge.");
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return NO;
    }
    
    MSID_LOG_INFO(context, @"Received CertAuthChallenge");
    MSID_LOG_INFO_PII(context, @"Received CertAuthChallengehost from : %@", challenge.protectionSpace.host);
    
    s_safariController = nil;
    s_endURL = nil;
    s_sem = dispatch_semaphore_create(0);
    s_certAuthInProgress = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // This will launch a Safari view within the current Application, removing the app flip. Our control of this
        // view is extremely limited. Safari is still running in a separate sandbox almost completely isolated from us.
        s_safariController = [[SFSafariViewController alloc] initWithURL:requestURL];
        s_safariController.delegate = s_safariDelegate;
        
        UIViewController *currentViewController = [UIApplication msidCurrentViewController];
        [currentViewController presentViewController:s_safariController animated:YES completion:nil];
    });
    
    // Now wait around to either get hit from launch services, or for the view to be torn down.
    dispatch_semaphore_wait(s_sem, DISPATCH_TIME_FOREVER);
    s_certAuthInProgress = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [s_safariController dismissViewControllerAnimated:YES completion:nil];
    });
    
    // Cancel the Cert Auth Challenge happened in UIWebview, as we have already handled it in SFSafariViewController
    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, NULL);
    
    MSIDOAuth2EmbeddedWebviewController *embeddedViewController = (MSIDOAuth2EmbeddedWebviewController  *)currentSession.webviewController;
    
    if (s_endURL)
    {
        [embeddedViewController endWebAuthWithURL:s_endURL error:nil];
        s_endURL = nil;
    }
    else
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"no end url is provided to end the cert auth handling", nil, nil, nil, context.correlationId, nil);
        [embeddedViewController endWebAuthWithURL:nil error:error];
    }
    
    return YES;
}
#endif


#if !TARGET_OS_IPHONE

+ (BOOL)handleCertAuthChallenge:(NSURLAuthenticationChallenge *)challenge
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
        MSID_LOG_INFO(context, @"Using preferred identity");
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
                 MSID_LOG_INFO(context, @"No identity returned from cert chooser");
                 
                 // If no identity comes back then we can't handle the request
                 completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
                 return;
             }
             
             // Adding a retain count to match the retain count from SecIdentityCopyPreferred
             CFRetain(identity);
             MSID_LOG_INFO(context, @"Using user selected certificate");
             [self respondCertAuthChallengeWithIdentity:identity context:context completionHandler:completionHandler];
         }];
    }
    
    return YES;
}

+ (void)respondCertAuthChallengeWithIdentity:(nonnull SecIdentityRef)identity
                                     context:(id<MSIDRequestContext>)context
                           completionHandler:(ChallengeCompletionHandler)completionHandler
{
    MSID_LOG_INFO(context, @"Responding to cert auth challenge with certicate");
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
        MSID_LOG_INFO_CORR(correlationId, @"No certificate found matching challenge");
        completionHandler(nil);
        return;
    }
    else if (status != errSecSuccess)
    {
        MSID_LOG_ERROR_CORR(correlationId, @"Failed to find identity matching issuers with %d error.", status);
        completionHandler(nil);
        return;
    }
    
    [MSIDCertificateChooserHelper showCertSelectionSheet:(__bridge NSArray *)result host:host webview:webview correlationId:correlationId completionHandler:completionHandler];
}

#endif

@end
