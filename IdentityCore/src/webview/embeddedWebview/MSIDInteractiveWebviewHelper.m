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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDInteractiveWebviewHelper.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDSpecialURLViewActionResolver.h"
#import "MSIDWebviewAction.h"
#import "MSIDWebviewResponse.h"
#import "MSIDRequestContext.h"
#import "MSIDASWebAuthenticationSessionHandler.h"
#import "MSIDError.h"
#import "MSIDLogging.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

@implementation MSIDInteractiveWebviewHelper

#pragma mark - Initialization

- (instancetype)initWithBrokerContext:(BOOL)isRunningInBrokerContext
{
    self = [super init];
    if (self)
    {
        _isRunningInBrokerContext = isRunningInBrokerContext;
        _brtAttemptAttempted = NO;
        _brtAcquired = NO;
        _capturedResponseHeaders = nil;
        _urlResolver = [[MSIDSpecialURLViewActionResolver alloc] init];
    }
    return self;
}

#pragma mark - Special URL Processing

- (void)processSpecialURL:(NSURL *)url
               completion:(void (^)(MSIDWebviewAction * _Nullable, NSError * _Nullable))completion
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context,
                         @"Processing special URL: %@", MSID_PII_LOG_MASKABLE(url));
    
    // Check if BRT acquisition is needed (non-broker only, first msauth/browser redirect)
    if ([self shouldAcquireBRTForSpecialURL:url])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                         @"BRT acquisition needed, starting async operation (single attempt)");
        
        // Mark as attempted (simplified: only one attempt)
        self.brtAttemptAttempted = YES;
        
        // Acquire BRT asynchronously - delegate to parent controller
        [self acquireBRTTokenWithCompletion:^(BOOL success, NSError *error) {
            
            if (success) {
                self.brtAcquired = YES;
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                                 @"BRT acquired successfully");
            } else {
                MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context,
                                 @"BRT acquisition failed: %@", error);
                // Continue even if BRT fails (server will handle auth without BRT)
            }
            
            // After BRT acquisition (success or failure), resolve action
            MSIDWebviewAction *action = [self viewActionForSpecialURL:url];
            
            if (completion) {
                completion(action, nil);
            }
        }];
        
        return; // Async - completion will be called after BRT completes
    }
    
    // No BRT needed, get action immediately (synchronous path)
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                     @"No BRT acquisition needed (already acquired or not applicable), processing synchronously");
    
    MSIDWebviewAction *action = [self viewActionForSpecialURL:url];
    
    // Check for broker retry logic for profileInstalled/profileComplete
    if (action && action.type == MSIDWebviewActionTypeCompleteWithURL)
    {
        NSString *host = [url.host lowercaseString];
        
        if ([host isEqualToString:@"profileinstalled"] || [host isEqualToString:@"profilecomplete"])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                             @"profileInstalled/profileComplete detected, checking if should retry in broker context");
            
            // Check if should retry in broker (non-broker controller on iOS)
            if ([self shouldRetryInBrokerForSpecialURL:url])
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                                 @"Retrying interactive request in broker context");
                
                // Dismiss embedded webview before retrying in broker
                [self dismissEmbeddedWebviewIfPresent];
                
                // Retry in broker context (async) - delegate to parent controller
                [self retryInteractiveRequestInBrokerContextForURL:url completion:^(BOOL success, NSError * _Nullable error) {
                    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                                     @"Broker context retry completed - result: %@, error: %@", success ? @"success" : @"failure", error);
                    // Retry handles completion - no action needed from webview
                }];
                
                // Return nil - retry in broker handles completion, not webview
                if (completion) {
                    completion(nil, nil);
                }
                
                return;
            }
            
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                             @"No broker retry needed - completing auth in current context");
        }
    }
    
    // No retry needed, return action for webview to execute
    if (completion) {
        completion(action, nil);
    }
}

#pragma mark - Policy Checks (Internal)

- (BOOL)shouldAcquireBRTForSpecialURL:(NSURL *)url
{
    // Only acquire BRT if NOT in broker context
    if (self.isRunningInBrokerContext)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Skipping BRT acquisition - already in broker context");
        return NO;
    }
    
    // Check if already acquired successfully
    if (self.brtAcquired)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Skipping BRT acquisition - already acquired");
        return NO;
    }
    
    // Simplified: Check if already attempted (only attempt once)
    if (self.brtAttemptAttempted)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Skipping BRT acquisition - already attempted once");
        return NO;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"BRT acquisition needed for URL: %@", MSID_PII_LOG_MASKABLE(url));
    return YES;
}

- (BOOL)shouldRetryInBrokerForSpecialURL:(NSURL *)url
{
    // Only retry in broker if NOT already in broker context
    if (self.isRunningInBrokerContext)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Already in broker context - no retry needed");
        return NO;
    }
    
#if TARGET_OS_IPHONE
    // On iOS, we can retry in broker via MSIDBrokerInteractiveController
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Will retry in broker context");
    return YES;
#else
    // On macOS, broker retry not currently supported
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Broker retry not supported on macOS");
    return NO;
#endif
}

#pragma mark - Action Implementations (Delegate to Controller)

- (void)acquireBRTTokenWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    if (!self.parentController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"No parent controller - cannot acquire BRT");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                        @"No parent controller configured for BRT acquisition",
                                        nil, nil, nil, self.context.correlationId, nil, NO);
        if (completion) completion(NO, error);
        return;
    }
    
    // Delegate to parent controller for actual BRT acquisition
    [self.parentController acquireBRTTokenWithCompletion:completion];
}

- (void)retryInteractiveRequestInBrokerContextForURL:(NSURL *)url
                                          completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    if (!self.parentController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"No parent controller - cannot retry in broker");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                        @"No parent controller configured for broker retry",
                                        nil, nil, nil, self.context.correlationId, nil, NO);
        if (completion) completion(NO, error);
        return;
    }
    
    // Delegate to parent controller for broker retry
    [self.parentController retryInteractiveRequestInBrokerContextForURL:url completion:completion];
}

- (void)dismissEmbeddedWebviewIfPresent
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Dismissing embedded webview");
    
    if (!self.embeddedWebviewController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, @"No embedded webview controller - nothing to dismiss");
        return;
    }
    
    // Dismiss webview directly (shared implementation)
    if ([self.embeddedWebviewController isKindOfClass:[UIViewController class]])
    {
        UIViewController *viewController = (UIViewController *)self.embeddedWebviewController;
        
        if (viewController.presentingViewController)
        {
            [viewController dismissViewControllerAnimated:YES completion:nil];
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Embedded webview dismissed");
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Embedded webview not currently presented");
        }
    }
}

#pragma mark - View Action Resolution

- (MSIDWebviewAction * _Nullable)viewActionForSpecialURL:(NSURL *)url
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"Resolving view action for special URL: %@", MSID_PII_LOG_MASKABLE(url));
    
    // Use resolver to map URL to action, passing captured response headers
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url
                                                                       responseHeaders:self.capturedResponseHeaders];
    
    if (action)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Resolved action type: %ld", (long)action.type);
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, @"No action resolved for URL");
    }
    
    return action;
}

#pragma mark - Header Capture

- (void)didReceiveHTTPResponseHeaders:(NSDictionary<NSString *, NSString *> *)headers
{
    // Helper captures headers inline
    self.capturedResponseHeaders = headers;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                     @"Captured %lu HTTP response header(s) for special URL processing",
                     (unsigned long)headers.count);
}

#pragma mark - System Webview Management

- (void)openSystemWebviewWithURL:(NSURL *)url
                         headers:(NSDictionary<NSString *, NSString *> *)headers
                         purpose:(MSIDSystemWebviewPurpose)purpose
                      completion:(void (^)(NSURL * _Nullable callbackURL, NSError * _Nullable error))completion
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, 
                         @"Opening system webview for purpose: %d with URL: %@", 
                         (int)purpose, MSID_PII_LOG_MASKABLE(url));
    
    if (!self.parentViewController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"No parent view controller - cannot open system webview");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                        @"No parent view controller configured for system webview",
                                        nil, nil, nil, self.context.correlationId, nil, NO);
        if (completion) completion(nil, error);
        return;
    }
    
    // Create ASWebAuthenticationSession directly in helper (shared implementation)
    MSIDASWebAuthenticationSessionHandler *asWebAuthHandler = 
        [[MSIDASWebAuthenticationSessionHandler alloc] 
            initWithParentController:self.parentViewController
                            startURL:url
                      callbackScheme:@"msauth"
                  useEmpheralSession:YES
                  additionalHeaders:headers];
    
    self.currentSystemWebview = asWebAuthHandler;
    
    // Start ASWebAuth session
    __weak typeof(self) weakSelf = self;
    [asWebAuthHandler startWithCompletionHandler:^(NSURL *callbackURL, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (error) {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, strongSelf.context, 
                             @"System webview failed: %@", error);
        } else if (callbackURL) {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, strongSelf.context, 
                                 @"System webview completed with callback: %@", 
                                 MSID_PII_LOG_MASKABLE(callbackURL));
        }
        
        // Clear reference
        strongSelf.currentSystemWebview = nil;
        
        // Call completion
        if (completion) {
            completion(callbackURL, error);
        }
    }];
}

#pragma mark - Telemetry

- (void)handleWebviewResponseForTelemetry:(MSIDWebviewResponse *)response
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Handling webview response for telemetry");
    
    // TODO: Record telemetry for special URL responses
    // This can track special URL types, timing, success/failure, etc.
}

@end
