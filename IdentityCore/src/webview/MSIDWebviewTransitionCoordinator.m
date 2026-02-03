//------------------------------------------------------------------------------
//
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#if !MSID_EXCLUDE_WEBKIT

#import "MSIDWebviewTransitionCoordinator.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDASWebAuthenticationSessionHandler.h"
#import "MSIDMainThreadUtil.h"

@implementation MSIDWebviewTransitionCoordinator

- (BOOL)isTransitioning
{
    return self.suspendedEmbeddedWebview != nil || self.profileSessionHandler != nil;
}

- (void)suspendEmbeddedWebview:(MSIDOAuth2EmbeddedWebviewController *)webview
{
    if (!webview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[MSIDWebviewTransitionCoordinator] Cannot suspend nil webview");
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Suspending embedded webview");
    
    // Store reference to keep webview alive
    self.suspendedEmbeddedWebview = webview;
    
    // Hide the webview UI without dismissing it
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        if (webview.parentController && webview.parentController.view)
        {
            webview.parentController.view.hidden = YES;
            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"[MSIDWebviewTransitionCoordinator] Webview UI hidden");
        }
    }];
}

- (void)launchProfileInstallationSession:(NSURL *)profileURL
                        parentController:(MSIDViewController *)parentController
                          callbackScheme:(NSString *)callbackScheme
                       completionHandler:(void (^)(NSURL * _Nullable, NSError * _Nullable))completionHandler
{
    if (!profileURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[MSIDWebviewTransitionCoordinator] Cannot launch session with nil URL");
        if (completionHandler)
        {
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Profile installation URL is nil", nil, nil, nil, nil, nil, YES);
            completionHandler(nil, error);
        }
        return;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Launching profile installation session with URL: %@", MSID_PII_LOG_MASKABLE(profileURL));
    
    // Create ASWebAuthenticationSession handler
    self.profileSessionHandler = [[MSIDASWebAuthenticationSessionHandler alloc] initWithParentController:parentController
                                                                                                 startURL:profileURL
                                                                                           callbackScheme:callbackScheme
                                                                                       useEmpheralSession:NO];
    
    if (!self.profileSessionHandler)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[MSIDWebviewTransitionCoordinator] Failed to create ASWebAuthenticationSession handler");
        if (completionHandler)
        {
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to create profile installation session", nil, nil, nil, nil, nil, YES);
            completionHandler(nil, error);
        }
        return;
    }
    
    // Start the session
    [self.profileSessionHandler startWithCompletionHandler:^(NSURL *callbackURL, NSError *error) {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Profile installation session completed with callback: %@, error: %@", 
                             MSID_PII_LOG_MASKABLE(callbackURL), error);
        
        if (completionHandler)
        {
            completionHandler(callbackURL, error);
        }
    }];
}

- (void)resumeSuspendedEmbeddedWebview
{
    if (!self.suspendedEmbeddedWebview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[MSIDWebviewTransitionCoordinator] No suspended webview to resume");
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Resuming suspended embedded webview");
    
    // Show the webview UI again
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        if (self.suspendedEmbeddedWebview.parentController && self.suspendedEmbeddedWebview.parentController.view)
        {
            self.suspendedEmbeddedWebview.parentController.view.hidden = NO;
            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"[MSIDWebviewTransitionCoordinator] Webview UI shown");
        }
    }];
    
    // Note: The webview should continue its navigation naturally
    // We don't need to manually trigger anything as it's been kept alive
}

- (void)dismissProfileInstallationSession
{
    if (self.profileSessionHandler)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Dismissing profile installation session");
        
        // Dismiss the ASWebAuthenticationSession
        [self.profileSessionHandler dismiss];
        self.profileSessionHandler = nil;
    }
}

- (void)cleanup
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Cleaning up coordinator state");
    
    self.suspendedEmbeddedWebview = nil;
    
    if (self.profileSessionHandler)
    {
        [self.profileSessionHandler dismiss];
        self.profileSessionHandler = nil;
    }
}

@end

#endif
