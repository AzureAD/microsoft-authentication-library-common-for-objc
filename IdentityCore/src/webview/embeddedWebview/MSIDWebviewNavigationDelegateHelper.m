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

#import "MSIDWebviewNavigationDelegateHelper.h"
#import "MSIDWebviewNavigationAction.h"
#import "MSIDWebviewNavigationActionUtil.h"
#import "MSIDAADOAuthEmbeddedWebviewController.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDWebviewTransitionHandler.h"
#import "MSIDRequestContext.h"

@interface MSIDWebviewNavigationDelegateHelper()

@property (nonatomic) id<MSIDRequestContext> context;

@end

@implementation MSIDWebviewNavigationDelegateHelper

#pragma mark - Init

- (instancetype)initWithContext:(id<MSIDRequestContext>)context
{
    self = [super init];
    if (self)
    {
        _context = context;
    }
    return self;
}

#pragma mark - Webview Configuration

- (void)configureWebviewController:(id)webviewController
                          delegate:(id)delegate
{
    // Create strong reference to avoid multiple weak property accesses
    id<MSIDRequestContext> context = self.context;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                     @"Configuring webview controller with navigation delegate helper");
    
    // Set navigation delegate if webview supports it
    if ([webviewController isKindOfClass:MSIDOAuth2EmbeddedWebviewController.class])
    {
        MSIDAADOAuthEmbeddedWebviewController *aadWebviewController =
            (MSIDAADOAuthEmbeddedWebviewController *)webviewController;
        
        aadWebviewController.navigationDelegate = delegate;
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                         @"Set up navigationResponseBlock to capture HTTP headers.");
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context,
                         @"Webview controller is not EmbeddedWebviewController, skipping navigation delegate setup.");
    }
}

#pragma mark - Navigation Delegate Methods

- (void)handleSpecialRedirectUrl:(NSURL *)url
               webviewController:(id)webviewController
                      completion:(void (^)(MSIDWebviewNavigationAction * _Nullable action, NSError * _Nullable error))completion
                    brtEvaluator:(nullable BOOL(^)(void))brtEvaluator
                      brtHandler:(nullable void(^)(void(^)(BOOL success, NSError * _Nullable error)))brtHandler
                 isBrokerContext:(BOOL)isBrokerContext
            externalNavigationBlock:(nullable id)externalNavigationBlock
{
    // Create strong reference to avoid multiple weak property accesses
    id<MSIDRequestContext> context = self.context;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                     @"Helper handling special redirect: %@", _PII_NULLIFY(url));
    
    NSString *scheme = url.scheme.lowercaseString;
    
    // Handle msauth:// scheme
    if ([scheme isEqualToString:@"msauth"])
    {
        // Check if BRT is needed (Local controller only)
        if (brtEvaluator && brtEvaluator())
        {
            // BRT needed - acquire it first
            if (brtHandler)
            {
                brtHandler(^(__unused BOOL success, __unused NSError *error) {
                    // After BRT acquisition, resolve action
                    MSIDWebviewNavigationActionUtil *util = [MSIDWebviewNavigationActionUtil sharedInstance];
                    MSIDWebviewNavigationAction *action = [util resolveActionForMSAuthURL:url
                                                                           webviewController:webviewController
                                                                            responseHeaders:self.lastResponseHeaders
                                                                            isBrokerContext:isBrokerContext
                                                                       externalNavigationBlock:externalNavigationBlock];
                    completion(action, nil);
                });
                return;
            }
        }
        
        // No BRT needed or broker context - resolve action directly
        MSIDWebviewNavigationActionUtil *util = [MSIDWebviewNavigationActionUtil sharedInstance];
        MSIDWebviewNavigationAction *action = [util resolveActionForMSAuthURL:url
                                                               webviewController:webviewController
                                                                responseHeaders:self.lastResponseHeaders
                                                                isBrokerContext:isBrokerContext
                                                           externalNavigationBlock:externalNavigationBlock];
        completion(action, nil);
        return;
    }
    
    // Handle browser:// scheme
    if ([scheme isEqualToString:@"browser"])
    {
        // Check if BRT is needed (Local controller only)
        if (brtEvaluator && brtEvaluator())
        {
            // BRT needed - acquire it first
            if (brtHandler)
            {
                brtHandler(^(__unused BOOL success, __unused NSError *error) {
                    // After BRT acquisition, use default action
                    MSIDWebviewNavigationAction *action = [MSIDWebviewNavigationAction continueDefaultAction];
                    completion(action, nil);
                });
                return;
            }
        }
        
        // No BRT needed - use default action
        MSIDWebviewNavigationAction *action = [MSIDWebviewNavigationAction continueDefaultAction];
        completion(action, nil);
        return;
    }
    
    // Unknown scheme - use default behavior
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                     @"Unknown special redirect scheme: %@. Using default behavior.", scheme);
    completion([MSIDWebviewNavigationAction continueDefaultAction], nil);
}

- (void)processResponseHeaders:(NSDictionary<NSString *, NSString *> *)headers
{
    self.lastResponseHeaders = headers;
    // TODO: Add telemetry handling for response headers
}

- (void)handleASWebAuthenticationTransition:(NSURL *)url
                           embeddedWebview:(MSIDAADOAuthEmbeddedWebviewController *)embeddedWebview
                         additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                                   purpose:(MSIDSystemWebviewPurpose)purpose
                         transitionHandler:(MSIDWebviewTransitionHandler *)transitionHandler
                          parentController:(MSIDViewController *)parentController
                                completion:(void (^)(MSIDWebviewNavigationAction * _Nullable, NSError * _Nullable))completion
{
    // Create strong reference to avoid multiple weak property accesses
    id<MSIDRequestContext> context = self.context;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Handling ASWebAuthentication transition");
    
    if (!url)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                         @"ASWebAuthentication transition called with no url, proceeding the flow in embedded webview");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                        @"ASWebAuthentication transition called with no url",
                                        nil, nil, nil, context.correlationId, nil, YES);
        completion([MSIDWebviewNavigationAction failWebAuthWithErrorAction:error], nil);
        return;
    }
    
    if (!embeddedWebview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                         @"Cannot suspend webview - no current webview found");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                        @"No current webview found for suspension",
                                        nil, nil, nil, context.correlationId, nil, YES);
        completion([MSIDWebviewNavigationAction failWebAuthWithErrorAction:error], nil);
        return;
    }
    
    // Suspend the embedded webview (hide but keep alive)
    [transitionHandler suspendEmbeddedWebview:embeddedWebview];
    
    [transitionHandler launchASWebAuthenticationSessionWithUrl:url
                                              parentController:parentController
                                             additionalHeaders:additionalHeaders
                                      MSIDSystemWebviewPurpose:purpose
                                                       context:context
                                                    completion:^(MSIDWebviewNavigationAction * _Nonnull action, NSError * _Nonnull error) {
        completion(action, error);
    }];
}

@end
