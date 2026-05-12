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

@implementation MSIDWebviewTransitionHandler

#pragma mark - Launch ASWebAuthenticationSession

- (void)launchASWebAuthenticationSessionWithUrl:(NSURL *)url
                               parentController:(MSIDViewController *)parentController
                              additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                             useEphemeralSession:(BOOL)useEphemeralSession
                       MSIDSystemWebviewPurpose:(MSIDSystemWebviewPurpose)systemWebviewPurpose
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
    
    if ((systemWebviewPurpose == MSIDSystemWebviewPurposeInstallProfile) && !additionalHeaders)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"AsWebAuthentication transition for mdm profile install called with no additional headers, proceeding without it, users may see additional prompts ");
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionHandler] Launching ASWebAuthentication session with URL: %@, ephemeral: %@",
                          MSID_PII_LOG_MASKABLE(url), useEphemeralSession ? @"YES" : @"NO");
    
    if (additionalHeaders && additionalHeaders.count > 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDWebviewTransitionHandler] Additional headers provided: %lu", (unsigned long)additionalHeaders.count);
    }
    
    NSString *callbackScheme = nil;
    
    switch(systemWebviewPurpose)
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
                                                                                           useEmpheralSession:useEphemeralSession
                                                                                            additionalHeaders:additionalHeaders];
    }
    else
    {
        // Fallback for older OS versions
        self.aSWebAuthenticationSessionHandler = [[MSIDASWebAuthenticationSessionHandler alloc] initWithParentController:parentController
                                                                                                     startURL:url
                                                                                               callbackScheme:callbackScheme
                                                                                           useEmpheralSession:useEphemeralSession];
        
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
                                                              MSIDSystemWebviewPurpose:systemWebviewPurpose
                                                                               context:context];
        completion(action, nil);
        return;
    }];
}

#pragma mark - Suspend/Resume/Dismiss Webview

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

#pragma mark - Private Helper Methods

- (MSIDWebviewNavigationAction *)handleASWebAuthnSessionCompletion:(NSURL *)callbackURL
                                    error:(NSError *)error
                 MSIDSystemWebviewPurpose:(MSIDSystemWebviewPurpose)systemWebviewPurpose
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
    // Check if callback is msauth://in_app_enrollment_complete
    if (systemWebviewPurpose == MSIDSystemWebviewPurposeInstallProfile)
    {
        if (callbackURL &&
            [callbackURL.scheme caseInsensitiveCompare:@"msauth"] == NSOrderedSame &&
            [callbackURL.host caseInsensitiveCompare:@"in_app_enrollment_complete"] == NSOrderedSame)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil,
                              @"Profile installation complete callback received");
            
            self.aSWebAuthenticationSessionHandler = nil;
            
            // 4. Load callback URL
            return [MSIDWebviewNavigationAction completeWebAuthWithURLAction:callbackURL];
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                              @"Unexpected callback URL from mdm profile installation: %@", callbackURL);
            
            // Clean up
            [self dismissASWebAuthenticationSession];
            
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
        
        // 4. Load callback URL
        return [MSIDWebviewNavigationAction loadRequestAction:[NSURLRequest requestWithURL:callbackURL]];
    }
}

@end

#endif
