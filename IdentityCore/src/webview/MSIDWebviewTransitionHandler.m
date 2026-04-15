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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#if !MSID_EXCLUDE_WEBKIT

#import "MSIDWebviewTransitionHandler.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDASWebAuthenticationSessionHandler.h"
#import "MSIDMainThreadUtil.h"
#import "MSIDWebviewNavigationAction.h"

@interface MSIDWebviewTransitionHandler ()

/**
 * Reference to the suspended embedded webview kept alive during the transition
 */
@property (nonatomic, nullable) MSIDOAuth2EmbeddedWebviewController *suspendedEmbeddedWebview;

/**
 * Handler for ASWebAuthenticationSession lifecycle.
 * Manages the system webview instance.
 */
@property (nonatomic, nullable) id aSWebAuthenticationSessionHandler;

@end

@implementation MSIDWebviewTransitionHandler

#pragma mark - Launch ASWebAuthenticationSession

- (void)launchASWebAuthenticationSessionWithUrl:(NSURL *)url
                               parentController:(MSIDViewController *)parentController
                              additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                       MSIDSystemWebviewPurpose:(MSIDSystemWebviewPurpose)systemWebViewPurpose
                                        context:(id<MSIDRequestContext>)context
                                     completion:(void (^)(MSIDWebviewNavigationAction *action, NSError *error))completion
{
    if (!url)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[MSIDWebviewTransitionHandler] Cannot launch ASWebAuthentication session with nil URL");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                        @"AsWebAuthentication transition called with no url",
                                        nil, nil, nil, context.correlationId, nil, YES);
        completion([MSIDWebviewNavigationAction failWebAuthWithErrorAction:error], nil);
        return;
    }
    
    if ((systemWebViewPurpose == MSIDSystemWebviewPurposeInstallProfile) && !additionalHeaders)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"AsWebAuthentication transition for mdm profile install called with no additional headers, proceeding without it, users may see additional prompts ");
    }
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionHandler] Launching ASWebAuthentication session with URL: %@", MSID_PII_LOG_MASKABLE(url));
    
    if (additionalHeaders && additionalHeaders.count > 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionHandler] Additional headers provided: %lu", (unsigned long)additionalHeaders.count);
    }
    
    NSString *callbackScheme = nil;
    
    switch(systemWebViewPurpose)
    {
        case MSIDSystemWebviewPurposeInstallProfile:
            callbackScheme = @"msauth";
            break;
        default:
            callbackScheme = @"msauth";
            break;
    }
    
    // Create ASWebAuthenticationSession handler with additional headers support
    if (@available(iOS 18.0, macOS 15.0, *))
    {
        self.aSWebAuthenticationSessionHandler = [[MSIDASWebAuthenticationSessionHandler alloc] initWithParentController:parentController
                                                                                                     startURL:url
                                                                                               callbackScheme:callbackScheme
                                                                                           useEmpheralSession:YES
                                                                                            additionalHeaders:additionalHeaders];
    }
    else
    {
        // Fallback for older OS versions (shouldn't happen since minimum is iOS 18 ?)
        self.aSWebAuthenticationSessionHandler = [[MSIDASWebAuthenticationSessionHandler alloc] initWithParentController:parentController
                                                                                                     startURL:url
                                                                                               callbackScheme:callbackScheme
                                                                                           useEmpheralSession:YES];
        
        if (additionalHeaders && additionalHeaders.count > 0)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[MSIDWebviewTransitionHandler] Additional headers ignored - iOS 18+ required");
        }
    }
    
    if (!self.aSWebAuthenticationSessionHandler)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[MSIDWebviewTransitionHandler] Failed to create ASWebAuthenticationSession handler");
        
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to create ASWebAuthenticationSession handler", nil, nil, nil, nil, nil, YES);
        completion([MSIDWebviewNavigationAction failWebAuthWithErrorAction:error], nil);
        return;
    }
    
    // Start the session
    [self.aSWebAuthenticationSessionHandler startWithCompletionHandler:^(NSURL *callbackURL, NSError *error)
     {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionHandler] External session completed with callback: %@, error: %@",
                             MSID_PII_LOG_MASKABLE(callbackURL), error);
        
        MSIDWebviewNavigationAction *action =  [self handleASWebAuthnSessionCompletion:callbackURL
                                                                                 error:error
                                                              MSIDSystemWebviewPurpose:systemWebViewPurpose
                                                                               context:context];
        completion(action, nil);
        return;
    }];
}

#pragma mark - Suspend/Resume/Dismiss Webview

- (void)suspendEmbeddedWebview:(MSIDOAuth2EmbeddedWebviewController *)embeddedWebview
{
    if (!embeddedWebview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[MSIDWebviewTransitionHandler] Cannot suspend nil webview");
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionHandler] Suspending embedded webview");
    
    // Store reference to keep webview alive
    self.suspendedEmbeddedWebview = embeddedWebview;
    
    // Hide the webview UI without dismissing it
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        MSIDViewController *parentController = embeddedWebview.parentController;
        if (parentController && parentController.view)
        {
            parentController.view.hidden = YES;
            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"[MSIDWebviewTransitionHandler] Webview UI hidden");
        }
    }];
}

- (void)resumeSuspendedEmbeddedWebview
{
    if (!self.suspendedEmbeddedWebview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[MSIDWebviewTransitionHandler] No suspended webview to resume");
                return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionHandler] Resuming suspended embedded webview");
    
    
    // Show the webview UI again
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        MSIDViewController *parentController = self.suspendedEmbeddedWebview.parentController;
        if (parentController && parentController.view)
        {
            parentController.view.hidden = NO;
            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"[MSIDWebviewTransitionHandler] Webview UI shown");
        }
    }];
}

- (void)dismissASWebAuthenticationSession
{
    if (self.aSWebAuthenticationSessionHandler)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionHandler] Dismissing external session");
        
        // Dismiss the ASWebAuthenticationSession
        [self.aSWebAuthenticationSessionHandler dismiss];
        self.aSWebAuthenticationSessionHandler = nil;
    }
}

- (void)dismissSuspendedEmbeddedWebview
{
    if (!self.suspendedEmbeddedWebview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[MSIDWebviewTransitionHandler] No suspended webview to dismiss");
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionHandler] Dismissing suspended embedded webview");
    
    // Cancel the suspended webview to properly clean it up
    [self.suspendedEmbeddedWebview cancelProgrammatically];
    
    // Release the reference
    self.suspendedEmbeddedWebview = nil;
}

#pragma mark - Cleanup

- (void)cleanup
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionHandler] Cleaning up coordinator state");
    
    self.suspendedEmbeddedWebview = nil;
    
    if (self.aSWebAuthenticationSessionHandler)
    {
        [self.aSWebAuthenticationSessionHandler dismiss];
        self.aSWebAuthenticationSessionHandler = nil;
    }
    // Dismiss suspended webview if exists
    if (self.suspendedEmbeddedWebview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"[MSIDWebviewTransitionHandler] Dismissing suspended webview during cleanup");
        [self dismissSuspendedEmbeddedWebview];
    }
}

#pragma mark - Private Helper Methods

- (MSIDWebviewNavigationAction *)handleASWebAuthnSessionCompletion:(NSURL *)callbackURL
                                    error:(NSError *)error
                 MSIDSystemWebviewPurpose:(MSIDSystemWebviewPurpose)systemWebViewPurpose
                                  context:(id<MSIDRequestContext>)context
{
    if (error)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil,
                         @"ASWebAuthenticationSession session failed: %@", error);
        // Clean up
        [self dismissASWebAuthenticationSession];
        return [MSIDWebviewNavigationAction failWebAuthWithErrorAction:error];
    }
    
    // Currently only implemented for MSIDSystemWebviewPurposeInstallProfile purpose, can be extended for future cases
    // Check if callback is msauth://in_app_enrollment_complete
    if (systemWebViewPurpose == MSIDSystemWebviewPurposeInstallProfile)
    {
        if (callbackURL &&
            [callbackURL.scheme caseInsensitiveCompare:@"msauth"] == NSOrderedSame &&
            [callbackURL.host caseInsensitiveCompare:@"in_app_enrollment_complete"] == NSOrderedSame)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil,
                              @"Profile installation complete callback received");
            
            self.aSWebAuthenticationSessionHandler = nil;
            
            // Resume embedded webview UI
            [self resumeSuspendedEmbeddedWebview];
            
            
            // Load callback URL
            return [MSIDWebviewNavigationAction loadRequestAction:[NSURLRequest requestWithURL:callbackURL]];
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                              @"Unexpected callback URL from mdm profile installation: %@", callbackURL);
            
            // Clean up
            [self cleanup];
            
            // Create error for unexpected callback
            NSError *callbackError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                                     @"Unexpected callback from mdm profile installation",
                                                     nil, nil, nil, context.correlationId, nil, YES);
            return [MSIDWebviewNavigationAction failWebAuthWithErrorAction:callbackError];
        }
    }
    else
    {
        // Transition back to embedded webview with the callback URL as the new navigation request
        self.aSWebAuthenticationSessionHandler = nil;
        
        // Resume embedded webview UI
        [self resumeSuspendedEmbeddedWebview];
        
        // Load callback URL
        return [MSIDWebviewNavigationAction loadRequestAction:[NSURLRequest requestWithURL:callbackURL]];
    }
}

@end

#endif
