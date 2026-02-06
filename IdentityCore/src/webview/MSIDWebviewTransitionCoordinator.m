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
#import "MSIDWebviewNavigationAction.h"


@implementation MSIDWebviewTransitionCoordinator

- (BOOL)isTransitioning
{
    return self.suspendedEmbeddedWebview != nil || self.aSWebAuthenticationSessionHandler != nil;
}


#pragma mark - ASWebAuth Session transition - Option 1 - handle transition in controller via webview response

- (void)launchASWebAuthenticationSession:(NSURL *)url
                        parentController:(MSIDViewController *)parentController
                       additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                MSIDSystemWebviewPurpose:(MSIDSystemWebviewPurpose)systemWebViewPurpose
                                 context:(id<MSIDRequestContext>)context
                              completion:(MSIDRequestCompletionBlock)completionBlock
{
    if (!url)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[MSIDWebviewTransitionCoordinator] Cannot launch external session with nil URL");
        if (completionBlock)
        {
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"External session URL is nil", nil, nil, nil, nil, nil, YES);
            completionBlock(nil, error);
        }
        return;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Launching ASWebAuthentication session with URL: %@", MSID_PII_LOG_MASKABLE(url));
    
    if (additionalHeaders && additionalHeaders.count > 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Additional headers provided: %lu", (unsigned long)additionalHeaders.count);
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
                                                                                           useEmpheralSession:NO
                                                                                            additionalHeaders:additionalHeaders];
    }
    else
    {
        // Fallback for older OS versions (shouldn't happen since minimum is iOS 18 ?)
        self.aSWebAuthenticationSessionHandler = [[MSIDASWebAuthenticationSessionHandler alloc] initWithParentController:parentController
                                                                                                     startURL:url
                                                                                               callbackScheme:callbackScheme
                                                                                           useEmpheralSession:NO];
        
        if (additionalHeaders && additionalHeaders.count > 0)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[MSIDWebviewTransitionCoordinator] Additional headers ignored - iOS 18+ required");
        }
    }
    
    if (!self.aSWebAuthenticationSessionHandler)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[MSIDWebviewTransitionCoordinator] Failed to create ASWebAuthenticationSession handler");
        if (completionBlock)
        {
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to create external session", nil, nil, nil, nil, nil, YES);
            completionBlock(nil, error);
        }
        return;
    }
    
    // Start the session
    [self.aSWebAuthenticationSessionHandler startWithCompletionHandler:^(NSURL *callbackURL, NSError *error)
     {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] External session completed with callback: %@, error: %@",
                             MSID_PII_LOG_MASKABLE(callbackURL), error);
        
        [self handleASWebAuthnSessionCompletion:callbackURL error:error MSIDSystemWebviewPurpose:systemWebViewPurpose context:context completion:completionBlock];
    }];
}


- (void)handleASWebAuthnSessionCompletion:(NSURL *)callbackURL
                                    error:(NSError *)error
                 MSIDSystemWebviewPurpose:(MSIDSystemWebviewPurpose)systemWebViewPurpose
                                  context:(id<MSIDRequestContext>)context
                               completion:(MSIDRequestCompletionBlock)completionBlock
{
    if (error)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil,
                         @"ASWebAuthenticationSession session failed: %@", error);
        
        // Clean up
        [self cleanup];
        completionBlock(nil, error);
        return;
    }
    // Currently only implemented for MSIDSystemWebviewPurposeInstallProfile purpose, can be extended for future cases
    // Check if callback is msauth://in-app-enrollment
    if (systemWebViewPurpose == MSIDSystemWebviewPurposeInstallProfile)
    {
        if (callbackURL &&
            [callbackURL.scheme caseInsensitiveCompare:@"msauth"] == NSOrderedSame &&
            [callbackURL.host caseInsensitiveCompare:@"in_app_enrollment_complete"] == NSOrderedSame)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil,
                              @"Profile installation complete callback received");
            
            self.aSWebAuthenticationSessionHandler = nil;
            
            // Option 1: cancel ASWebAuthN , load callback URL in WKWebview and let WKWebView handle the response
            // 2. Resume embedded webview UI
            [self resumeSuspendedEmbeddedWebview];
            
            // 3. Get webview reference
            MSIDOAuth2EmbeddedWebviewController *webview =
            (MSIDOAuth2EmbeddedWebviewController *)self.suspendedEmbeddedWebview;
            
            // 4. Load callback URL
            [webview loadRequest:[NSURLRequest requestWithURL:callbackURL]];
            
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
            completionBlock(nil, callbackError);
        }
    }
    else
    {
        // for now in other cases we will transition the control back to Embedded webview
        self.aSWebAuthenticationSessionHandler = nil;
        
        // Option 1: cancel ASWebAuthN , load callback URL in WKWebview and let WKWebView handle the response
        // 2. Resume embedded webview UI
        [self resumeSuspendedEmbeddedWebview];
        
        // 3. Get webview reference
        MSIDOAuth2EmbeddedWebviewController *webview =
        (MSIDOAuth2EmbeddedWebviewController *)self.suspendedEmbeddedWebview;
        
        // 4. Load callback URL
        [webview loadRequest:[NSURLRequest requestWithURL:callbackURL]];
    }
}

#pragma mark - ASWebAuth Session transition - Option 1 - handle transition via delegate in embedded webview

- (void)launchASWebAuthenticationSessionWithUrl:(NSURL *)url
                               parentController:(MSIDViewController *)parentController
                              additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                       MSIDSystemWebviewPurpose:(MSIDSystemWebviewPurpose)systemWebViewPurpose
                                        context:(id<MSIDRequestContext>)context
                                     completion:(void (^)(MSIDWebviewNavigationAction *action, NSError *error))completion
{
    if (!url)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[MSIDWebviewTransitionCoordinator] Cannot launch ASWebAuthentication session with nil URL");
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
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Launching ASWebAuthentication session with URL: %@", MSID_PII_LOG_MASKABLE(url));
    
    if (additionalHeaders && additionalHeaders.count > 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Additional headers provided: %lu", (unsigned long)additionalHeaders.count);
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
                                                                                           useEmpheralSession:NO
                                                                                            additionalHeaders:additionalHeaders];
    }
    else
    {
        // Fallback for older OS versions (shouldn't happen since minimum is iOS 18 ?)
        self.aSWebAuthenticationSessionHandler = [[MSIDASWebAuthenticationSessionHandler alloc] initWithParentController:parentController
                                                                                                     startURL:url
                                                                                               callbackScheme:callbackScheme
                                                                                           useEmpheralSession:NO];
        
        if (additionalHeaders && additionalHeaders.count > 0)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[MSIDWebviewTransitionCoordinator] Additional headers ignored - iOS 18+ required");
        }
    }
    
    if (!self.aSWebAuthenticationSessionHandler)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[MSIDWebviewTransitionCoordinator] Failed to create ASWebAuthenticationSession handler");
        
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to create ASWebAuthenticationSession handler", nil, nil, nil, nil, nil, YES);
        completion([MSIDWebviewNavigationAction failWebAuthWithErrorAction:error], nil);
        return;
    }
    
    // Start the session
    [self.aSWebAuthenticationSessionHandler startWithCompletionHandler:^(NSURL *callbackURL, NSError *error)
     {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] External session completed with callback: %@, error: %@",
                             MSID_PII_LOG_MASKABLE(callbackURL), error);
        
        MSIDWebviewNavigationAction *action =  [self handleASWebAuthnSessionCompletion:callbackURL error:error MSIDSystemWebviewPurpose:systemWebViewPurpose context:context];
        completion(action, nil);
        return;
    }];
}

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
        [self dismissASWebAuthenticationSession]; // TODO: check if this will cancel the token request and return cancel error to calling app
        return [MSIDWebviewNavigationAction failWebAuthWithErrorAction:error];
    }
    // Currently only implemented for MSIDSystemWebviewPurposeInstallProfile purpose, can be extended for future cases
    // Check if callback is msauth://in-app-enrollment
    if (systemWebViewPurpose == MSIDSystemWebviewPurposeInstallProfile)
    {
        if (callbackURL &&
            [callbackURL.scheme caseInsensitiveCompare:@"msauth"] == NSOrderedSame &&
            [callbackURL.host caseInsensitiveCompare:@"in_app_enrollment_complete"] == NSOrderedSame)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil,
                              @"Profile installation complete callback received");
            
            self.aSWebAuthenticationSessionHandler = nil;
            
            // Option 1: cancel ASWebAuthN , load callback URL in WKWebview and let WKWebView handle the response
            // 2. Resume embedded webview UI
            [self resumeSuspendedEmbeddedWebview];
            
            
            // 4. Load callback URL
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
        // for now in other cases we will transition the control back to Embedded webview
        self.aSWebAuthenticationSessionHandler = nil;
        
        // Option 1: cancel ASWebAuthN , load callback URL in WKWebview and let WKWebView handle the response
        // 2. Resume embedded webview UI
        [self resumeSuspendedEmbeddedWebview];
        
        // 4. Load callback URL
        return [MSIDWebviewNavigationAction loadRequestAction:[NSURLRequest requestWithURL:callbackURL]];
    }
}

#pragma mark - webview pause, resume and dismiss

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
        MSIDViewController *parentController = webview.parentController;
        if (parentController && parentController.view)
        {
            parentController.view.hidden = YES;
            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"[MSIDWebviewTransitionCoordinator] Webview UI hidden");
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
        MSIDViewController *parentController = self.suspendedEmbeddedWebview.parentController;
        if (parentController && parentController.view)
        {
            parentController.view.hidden = NO;
            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"[MSIDWebviewTransitionCoordinator] Webview UI shown");
        }
    }];
    
    // Note: The webview should continue its navigation naturally
    // We don't need to manually trigger anything as it's been kept alive
}

- (void)dismissASWebAuthenticationSession
{
    if (self.aSWebAuthenticationSessionHandler)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Dismissing external session");
        
        // Dismiss the ASWebAuthenticationSession
        [self.aSWebAuthenticationSessionHandler dismiss];
        self.aSWebAuthenticationSessionHandler = nil;
    }
}

- (void)dismissSuspendedEmbeddedWebview
{
    if (!self.suspendedEmbeddedWebview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[MSIDWebviewTransitionCoordinator] No suspended webview to dismiss");
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Dismissing suspended embedded webview");
    
    // Cancel the suspended webview to properly clean it up
    [self.suspendedEmbeddedWebview cancelProgrammatically];
    
    // Release the reference
    self.suspendedEmbeddedWebview = nil;
}


- (void)cleanup
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionCoordinator] Cleaning up coordinator state");
    
    self.suspendedEmbeddedWebview = nil;
    
    if (self.aSWebAuthenticationSessionHandler)
    {
        [self.aSWebAuthenticationSessionHandler dismiss];
        self.aSWebAuthenticationSessionHandler = nil;
    }
    // Dismiss suspended webview if exists
    if (self.suspendedEmbeddedWebview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"[MSIDWebviewTransitionCoordinator] Dismissing suspended webview during cleanup");
        [self dismissSuspendedEmbeddedWebview];
    }
}

@end

#endif
