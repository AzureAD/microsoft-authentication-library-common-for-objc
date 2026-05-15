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

#import <Foundation/Foundation.h>
#import "MSIDConstants.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"

@protocol MSIDRequestContext;
@protocol MSIDWebviewNavigationDelegate;
@class MSIDWebviewNavigationDecision;

NS_ASSUME_NONNULL_BEGIN

/**
 * Helper class that encapsulates common webview navigation delegate logic shared between
 * MSIDLocalInteractiveController and MSIDBrokerInteractiveController.
 *
 * This helper reduces code duplication by providing reusable implementations for:
 * - Webview configuration (setting the navigation delegate)
 * - Special URL redirect handling (routing via MSIDWebviewNavigationDecisionResolver)
 * - ASWebAuthenticationSession transitions (handoff from the embedded webview)
 * - HTTP response header processing for ASWebAuth handoff signals
 *
 * Controllers can customize behavior by passing callbacks for controller-specific logic
 * (e.g., BRT acquisition in local controller).
 */
@interface MSIDWebviewNavigationDelegateHelper : NSObject

/**
 * Initialize helper with request context.
 *
 * @param context Request context for logging and correlation ID
 * @return Initialized helper instance
 */
- (instancetype)initWithContext:(id<MSIDRequestContext>)context NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

#pragma mark - Webview Configuration

/**
 * Configures webview controller by setting the calling controller as the special navigation delegate.
 * This is typically called from the webview configuration block.
 *
 * @param embeddedWebviewController The webview controller to configure
 * @param delegate The controller that will handle navigation events (typically self)
 */
- (void)configureWebviewController:(MSIDOAuth2EmbeddedWebviewController *)embeddedWebviewController
                          delegate:(id<MSIDWebviewNavigationDelegate>)delegate;

#pragma mark - Navigation Delegate Methods

/**
 * Handles special redirect URLs (msauth://, browser://).
 * Routes to appropriate handler based on URL scheme.
 * This is the full method signature used by controllers.
 *
 * @param url The special redirect URL
 * @param embeddedWebviewController The embedded webview controller instance
 * @param brtEvaluator Optional block to determine if BRT acquisition is needed (Local controller only)
 * @param brtHandler Optional block to perform BRT acquisition (Local controller only)
 * @param appName The name of the sdk
 * @param appVersion The version of the sdk
 * @param externalNavigationBlock Optional external navigation handler for browser URLs
 * @param completion Completion block with the navigation decision or error
 */
- (void)handleSpecialRedirectUrl:(NSURL *)url
       embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController *)embeddedWebviewController
                    brtEvaluator:(nullable BOOL(^)(void))brtEvaluator
                      brtHandler:(nullable void(^)(void(^)(BOOL success, NSError * _Nullable error)))brtHandler
                         appName:(NSString *)appName
                      appVersion:(NSString *)appVersion
         externalNavigationBlock:(nullable MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
                      completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable navigationDecision, NSError * _Nullable error))completion;

/**
 * Processes HTTP response headers to determine whether an ASWebAuthenticationSession
 * handoff should be initiated. When the handoff header is present and the target URL
 * passes validation, the embedded webview is suspended and an ASWebAuthenticationSession
 * is launched in its place.
 *
 * @param headers Response headers to process
 * @param embeddedWebviewController The embedded webview controller instance
 * @param parentController The parent view controller that presents the webview
 */
- (void)processResponseHeaders:(NSDictionary *)headers
     embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController *)embeddedWebviewController
              parentController:(nonnull MSIDViewController *)parentController;

@end

NS_ASSUME_NONNULL_END

#endif
