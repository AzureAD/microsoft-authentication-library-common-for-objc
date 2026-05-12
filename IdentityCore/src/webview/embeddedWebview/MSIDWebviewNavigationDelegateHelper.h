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

#import <Foundation/Foundation.h>
#import "MSIDConstants.h"

@protocol MSIDRequestContext;
@class MSIDWebviewNavigationAction;
@class MSIDAADOAuthEmbeddedWebviewController;
@class MSIDOAuth2EmbeddedWebviewController;
@class MSIDWebviewTransitionHandler;

typedef NS_ENUM(NSInteger, MSIDSystemWebviewPurpose);

NS_ASSUME_NONNULL_BEGIN

/**
 * Helper class that encapsulates common webview navigation delegate logic
 * shared between ADBrokerInteractiveControllerWithPRT and MSIDLocalInteractiveController.
 *
 * This helper reduces code duplication by providing reusable implementations for:
 * - Webview configuration
 * - Special URL redirect handling (msauth://, browser://)
 * - ASWebAuthenticationSession transitions
 * - MDM profile installation flows
 * - HTTP response header processing
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
 * @param webviewController The webview controller to configure
 * @param delegate The controller that will handle navigation events (typically self)
 * @param parentController The parent view controller that presents the webview (optional)
 */
- (void)configureWebviewController:(id)webviewController
                          delegate:(id)delegate
                  parentController:(nullable MSIDViewController *)parentController;

#pragma mark - Navigation Delegate Methods

/**
 * Handles special redirect URLs (msauth://, browser://).
 * Routes to appropriate handler based on URL scheme.
 * This is the full method signature used by controllers.
 *
 * @param url The special redirect URL
 * @param brtEvaluator Optional block to determine if BRT acquisition is needed (Local controller only)
 * @param brtHandler Optional block to perform BRT acquisition (Local controller only)
 * @param appName The name of the sdk
 * @param appVersion The version of the sdk
 * @param externalNavigationBlock Optional external navigation handler for browser URLs
 * @param completion Completion block with navigation action or error
 */
- (void)handleSpecialRedirectUrl:(NSURL *)url
                    brtEvaluator:(nullable BOOL(^)(void))brtEvaluator
                      brtHandler:(nullable void(^)(void(^)(BOOL success, NSError * _Nullable error)))brtHandler
                         appName:(NSString *)appName
                      appVersion:(NSString *)appVersion
         externalNavigationBlock:(nullable id)externalNavigationBlock
                      completion:(void (^)(MSIDWebviewNavigationAction * _Nullable action, NSError * _Nullable error))completion;

/**
 * Processes HTTP response headers to extract telemetry information and determine if any special handling is needed (e.g., MDM profile installation).
 *
 * @param headers Response headers to process
 */
- (void)processResponseHeaders:(NSDictionary<NSString *, NSString *> *)headers;

@end

NS_ASSUME_NONNULL_END
