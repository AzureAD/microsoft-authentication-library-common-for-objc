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

#if !MSID_EXCLUDE_SYSTEMWV

static BOOL s_disableCertBasedAuth = NO; 

#endif

@implementation MSIDCertAuthHandler

#if TARGET_OS_IPHONE && !MSID_EXCLUDE_SYSTEMWV

+ (void)disableCertBasedAuth
{
    // This is a private API only to ensure nobody with access to internal headers takes dependency on it
    // This should be executed in automation tests only
    s_disableCertBasedAuth = YES;
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
    
    if (s_disableCertBasedAuth)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Cert based auth is explicitly disabled. Ignoring challenge.");
        return NO;
    }
    
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
