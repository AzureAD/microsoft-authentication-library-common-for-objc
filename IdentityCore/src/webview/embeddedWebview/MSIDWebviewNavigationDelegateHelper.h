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
@class MSIDWebMDMEnrollmentCompletionResponse;
@class MSIDInteractiveTokenRequest;
@class MSIDWebviewTransitionHandler;
@class MSIDInteractiveTokenRequestParameters;
@class MSIDTokenResult;

typedef void (^MSIDRequestCompletionBlock)(MSIDTokenResult * _Nullable result, NSError * _Nullable error);
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
 * Request context for logging and correlation ID.
 * Kept as weak reference to avoid retain cycles.
 */
@property (nonatomic, weak, readonly) id<MSIDRequestContext> context;

/**
 * Last received HTTP response headers.
 * Used for telemetry extraction and URL action resolution.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *lastResponseHeaders;

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
 */
- (void)configureWebviewController:(id)webviewController
                          delegate:(id)delegate;

#pragma mark - Navigation Delegate Methods

/**
 * Handles special redirect URLs (msauth://, browser://).
 * Routes to appropriate handler based on URL scheme.
 * This is the full method signature used by controllers.
 *
 * @param url The special redirect URL
 * @param webviewController The current webview controller
 * @param completion Completion block with navigation action or error
 * @param brtEvaluator Optional block to determine if BRT acquisition is needed (Local controller only)
 * @param brtHandler Optional block to perform BRT acquisition (Local controller only)
 * @param isBrokerContext YES for broker controller, NO for local controller
 * @param externalNavigationBlock Optional external navigation handler for browser URLs
 */
- (void)handleSpecialRedirectUrl:(NSURL *)url
               webviewController:(id)webviewController
                      completion:(void (^)(MSIDWebviewNavigationAction * _Nullable action, NSError * _Nullable error))completion
                    brtEvaluator:(nullable BOOL(^)(void))brtEvaluator
                      brtHandler:(nullable void(^)(void(^)(BOOL success, NSError * _Nullable error)))brtHandler
                 isBrokerContext:(BOOL)isBrokerContext
            externalNavigationBlock:(nullable id)externalNavigationBlock;

/**
 * Processes HTTP response headers for telemetry extraction.
 *
 * @param headers Response headers to process
 */
- (void)processResponseHeaders:(NSDictionary<NSString *, NSString *> *)headers
             transitionHandler:(MSIDWebviewTransitionHandler *)transitionHandler
              parentController:(MSIDViewController *)parentController
                    completion:(void (^_Nonnull)(MSIDWebviewNavigationAction * _Nullable action, NSError * _Nullable error))completion;

/**
 * Handles transition from embedded webview to ASWebAuthenticationSession.
 * Suspends the embedded webview and launches system webview.
 *
 * @param url URL to open in ASWebAuthenticationSession
 * @param embeddedWebview The embedded webview to suspend
 * @param additionalHeaders Optional headers to pass to system webview
 * @param purpose Purpose of the system webview (e.g., profile installation)
 * @param handler Coordinator managing the transition
 * @param parentController Parent view controller for presenting system webview
 * @param completion Completion block with navigation action or error
 */
- (void)handleASWebAuthenticationTransition:(nullable NSURL *)url
                           embeddedWebview:(nullable MSIDAADOAuthEmbeddedWebviewController *)embeddedWebview
                         additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                                   purpose:(MSIDSystemWebviewPurpose)purpose
                         transitionHandler:(MSIDWebviewTransitionHandler *)handler
                          parentController:(MSIDViewController *)parentController
                                completion:(nullable void (^)(MSIDWebviewNavigationAction * _Nullable action, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
