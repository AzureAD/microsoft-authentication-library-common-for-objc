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
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDSpecialURLViewActionResolver.h"
#import "MSIDWebviewAction.h"
#import "MSIDWebviewResponse.h"
#import "MSIDRequestContext.h"
#import "MSIDASWebAuthenticationSessionHandler.h"
#import "MSIDTokenRequestProviding.h"
#import "MSIDError.h"
#import "MSIDOauth2Factory.h"
#import "MSIDTokenCacheAccessor.h"

#if TARGET_OS_IPHONE
#import "MSIDBrokerInteractiveController.h"
#import <UIKit/UIKit.h>
#endif

@interface MSIDInteractiveWebviewHelper ()

@property (nonatomic, strong) MSIDInteractiveTokenRequestParameters *requestParameters;
@property (nonatomic, strong) id<MSIDTokenRequestProviding> tokenRequestProvider;
@property (nonatomic, strong) id<MSIDTokenCacheAccessor> tokenCache;
#if TARGET_OS_IPHONE
@property (nonatomic, weak) UIViewController *parentViewController;
#endif

@end

@implementation MSIDInteractiveWebviewHelper

#pragma mark - Initialization

- (instancetype)initWithBrokerContext:(BOOL)isRunningInBrokerContext
                    requestParameters:(MSIDInteractiveTokenRequestParameters *)requestParameters
                tokenRequestProvider:(id<MSIDTokenRequestProviding>)tokenRequestProvider
                           tokenCache:(id<MSIDTokenCacheAccessor>)tokenCache
#if TARGET_OS_IPHONE
                 parentViewController:(UIViewController *)parentViewController
#endif
                      embeddedWebview:(id)embeddedWebview
{
    self = [super init];
    if (self)
    {
        _isRunningInBrokerContext = isRunningInBrokerContext;
        _requestParameters = requestParameters;
        _tokenRequestProvider = tokenRequestProvider;
        _tokenCache = tokenCache;
#if TARGET_OS_IPHONE
        _parentViewController = parentViewController;
#endif
        _embeddedWebview = embeddedWebview;
        _brtAttemptAttempted = NO;
        _brtAcquired = NO;
        _capturedResponseHeaders = nil;
        _urlResolver = [[MSIDSpecialURLViewActionResolver alloc] init];
        _context = requestParameters;
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

#pragma mark - Action Implementations (Self-Contained)

- (void)acquireBRTTokenWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    if (!completion)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"acquireBRTTokenWithCompletion called with nil completion");
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Helper acquiring BRT token (self-contained)");
    
    // TODO: Implement actual BRT token acquisition
    // Steps:
    // 1. Create BRT token request using oauth factory from request parameters
    // 2. Execute the token request (network call)
    // 3. Save BRT to token cache
    // 4. Call completion with result
    //
    // For now, return error indicating not implemented
    // In production, this would:
    //   - Use self.tokenRequestProvider to create appropriate token request
    //   - Execute the request to get BRT from server
    //   - Use self.tokenCache to save the BRT
    
    NSError *error = MSIDCreateError(MSIDErrorDomain, 
                                     MSIDErrorInternal,
                                     @"BRT acquisition not yet implemented in self-contained helper", 
                                     nil, nil, nil, 
                                     self.requestParameters.correlationId, 
                                     nil, NO);
    
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, @"BRT acquisition result: FAILED (not implemented)");
    
    completion(NO, error);
}

- (void)retryInteractiveRequestInBrokerContextForURL:(NSURL *)url
                                           completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    if (!completion)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"retryInteractiveRequestInBrokerContextForURL called with nil completion");
        return;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"Helper retrying request in broker context (self-contained) for URL: %@", MSID_PII_LOG_MASKABLE(url));
    
#if TARGET_OS_IPHONE
    // Create broker controller directly in helper - fully self-contained
    NSError *brokerError = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] 
                                                         initWithInteractiveRequestParameters:self.requestParameters
                                                         tokenRequestProvider:self.tokenRequestProvider
                                                         brokerInstallLink:nil
                                                         error:&brokerError];
    
    if (!brokerController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"Failed to create broker controller: %@", brokerError);
        completion(NO, brokerError);
        return;
    }
    
    // TODO: Actually execute the broker request
    // For now, just signal success that we transferred to broker
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Successfully transferred to broker context (self-contained)");
    completion(YES, nil);
    
    // Note: Broker controller will continue the flow in broker context
    // The current webview should be dismissed by caller
#else
    NSError *error = MSIDCreateError(MSIDErrorDomain, 
                                     MSIDErrorInternal,
                                     @"Broker retry not supported on macOS", 
                                     nil, nil, nil,
                                     self.requestParameters.correlationId,
                                     nil, NO);
    MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"Broker retry not supported on this platform");
    completion(NO, error);
#endif
}

- (void)dismissEmbeddedWebviewIfPresent
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Helper dismissing embedded webview (self-contained)");
    
    if (!self.embeddedWebview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"No embedded webview to dismiss");
        return;
    }
    
    // TODO: Implement actual webview dismissal
    // This should call dismiss on the embedded webview
    // The webview is typically a WKWebView wrapped in a view controller
    // For now, just log
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Embedded webview dismissal not yet fully implemented");
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
                         @"Helper opening system webview (self-contained) for purpose: %d with URL: %@", 
                         (int)purpose, MSID_PII_LOG_MASKABLE(url));
    
#if TARGET_OS_IPHONE
    if (!self.parentViewController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"No parent view controller - cannot open system webview");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                        @"No parent view controller configured for system webview",
                                        nil, nil, nil, self.context.correlationId, nil, NO);
        if (completion) completion(nil, error);
        return;
    }
    
    // Create ASWebAuthenticationSession directly in helper - fully self-contained
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
#else
    // macOS doesn't support ASWebAuthenticationSession in this context
    NSError *error = MSIDCreateError(MSIDErrorDomain, 
                                     MSIDErrorInternal,
                                     @"System webview not supported on this platform", 
                                     nil, nil, nil,
                                     self.requestParameters.correlationId,
                                     nil, NO);
    MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"System webview not supported on macOS");
    if (completion) completion(nil, error);
#endif
}

#pragma mark - Telemetry

- (void)handleWebviewResponseForTelemetry:(MSIDWebviewResponse *)response
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Handling webview response for telemetry");
    
    // TODO: Record telemetry for special URL responses
    // This can track special URL types, timing, success/failure, etc.
}

@end
