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
#import "MSIDWebviewAuthorization.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "UIApplication+MSIDExtensions.h"
#import "MSIDMainThreadUtil.h"
#import "NSDictionary+MSIDQueryItems.h"
#import "MSIDCertAuthManager.h"

#if MSID_ENABLE_TEST_HOOKS
#import <Security/Security.h>
#endif

#if TARGET_OS_IPHONE && !MSID_EXCLUDE_SYSTEMWV && MSID_ENABLE_TEST_HOOKS

// Test-only API surface. Declared in a file-private class extension so the
// formal property contract lives only inside this .m and never reaches any
// header consumer. The implementations are additionally compiled out of any
// build where MSID_ENABLE_TEST_HOOKS is not defined, so no shipping binary
// contains the test hooks even via Objective-C runtime reflection.
// Consumers opt in by defining MSID_ENABLE_TEST_HOOKS=1 only for
// test-bearing CMake/Xcode configurations.
@interface MSIDCertAuthHandler ()

// When YES, +handleChallenge: refuses the CBA challenge.
@property (class, nonatomic) BOOL disableCertBasedAuth;

// When non-NULL, the iOS challenge handler answers every subsequent
// WKWebView client-cert challenge in-process with this identity (until
// the slot is cleared) instead of routing to SFSafariViewController.
// The host test installs the identity via SecPKCS12Import and assigns
// it here; tear-down assigns NULL to clear it. This is the mechanism
// that lets MSAL ObjC consumers run end-to-end CBA tests on hosted CI
// without a UI agent (matching what other platforms already do via
// silent client-cert credential responses).
@property (class, nonatomic) SecIdentityRef testIdentityForCertBasedAuth;

@end

static BOOL s_disableCertBasedAuth = NO;
static SecIdentityRef s_testIdentityForCertBasedAuth = NULL;

#endif

@implementation MSIDCertAuthHandler

#if TARGET_OS_IPHONE && !MSID_EXCLUDE_SYSTEMWV && MSID_ENABLE_TEST_HOOKS

+ (BOOL)disableCertBasedAuth
{
    return s_disableCertBasedAuth;
}

+ (void)setDisableCertBasedAuth:(BOOL)disableCertBasedAuth
{
    s_disableCertBasedAuth = disableCertBasedAuth;
}

+ (SecIdentityRef)testIdentityForCertBasedAuth
{
    return s_testIdentityForCertBasedAuth;
}

+ (void)setTestIdentityForCertBasedAuth:(SecIdentityRef)testIdentityForCertBasedAuth
{
    // Retain the new identity BEFORE releasing the old one. If a caller passes
    // the same SecIdentityRef that's already installed, releasing first could
    // drop the last reference and leave us retaining a dangling pointer.
    SecIdentityRef previous = s_testIdentityForCertBasedAuth;
    if (testIdentityForCertBasedAuth)
    {
        CFRetain(testIdentityForCertBasedAuth);
    }
    s_testIdentityForCertBasedAuth = testIdentityForCertBasedAuth;
    if (previous)
    {
        CFRelease(previous);
    }
}

#endif

+ (void)resetHandler
{
#if TARGET_OS_IPHONE && !MSID_EXCLUDE_SYSTEMWV
    [MSIDCertAuthManager.sharedInstance resetState];
#endif
}

+ (BOOL)handleChallenge:(NSURLAuthenticationChallenge *)challenge
                webview:(WKWebView *)webview
#if TARGET_OS_IPHONE
       parentController:(UIViewController *)parentViewController
#endif
                context:(id<MSIDRequestContext>)context
      completionHandler:(ChallengeCompletionHandler)completionHandler
{
#if !MSID_EXCLUDE_SYSTEMWV
    
#if MSID_ENABLE_TEST_HOOKS
    if (s_disableCertBasedAuth)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Cert based auth is explicitly disabled. Ignoring challenge.");
        return NO;
    }

    // Test-only short-circuit: if a test has injected an identity via
    // +setTestIdentityForCertBasedAuth:, answer the challenge in-process
    // and skip the SFSafariViewController hand-off entirely. This is what
    // lets end-to-end CBA tests run on hosted CI with no UI agent.
    if (s_testIdentityForCertBasedAuth)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Answering CBA challenge with injected test identity.");
        NSURLCredential *credential = [NSURLCredential credentialWithIdentity:s_testIdentityForCertBasedAuth
                                                                 certificates:nil
                                                                  persistence:NSURLCredentialPersistenceNone];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
        return YES;
    }
#endif
    
    MSIDWebviewSession *currentSession = [MSIDWebviewAuthorization currentSession];
    
    if (!currentSession)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"There is no current session open to continue with the cert auth challenge.");
        return NO;
    }
    
    if (MSIDCertAuthManager.sharedInstance.isCertAuthInProgress)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Certificate authentication challenge already in progress, ignoring duplicate cert auth challenge.");
        
        // Cancel the Cert Auth Challenge happened in the webview, as we have already handled it in SFSafariViewController
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, NULL);
        return YES;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"Received CertAuthChallengehost from : %@", MSID_PII_LOG_TRACKABLE(challenge.protectionSpace.host));
    
    NSURL *requestURL = [currentSession.webviewController startURL];
    
    [MSIDCertAuthManager.sharedInstance startWithURL:requestURL
                                    parentController:parentViewController
                                             context:context
                          ephemeralWebBrowserSession:YES
                                     completionBlock:^(NSURL *callbackURL, NSError *error)
     {
        MSIDWebviewSession *session = [MSIDWebviewAuthorization currentSession];
        MSIDOAuth2EmbeddedWebviewController *embeddedViewController = (MSIDOAuth2EmbeddedWebviewController  *)session.webviewController;
        
        [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
            
            if (callbackURL || error)
            {
                [embeddedViewController endWebAuthWithURL:callbackURL error:error];
            }
            else
            {
                NSError* unexpectedError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected Cert Auth response received.", nil, nil, nil, nil, nil, YES);
                [embeddedViewController endWebAuthWithURL:nil error:unexpectedError];
            }
        }];
    }];
    
    // Cancel the Cert Auth Challenge happened in the webview, as we have already handled it in SFSafariViewController
    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, NULL);
    
    return YES;
#else
    return NO;
#endif
}

@end
