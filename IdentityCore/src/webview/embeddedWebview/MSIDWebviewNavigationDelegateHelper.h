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

@protocol MSIDRequestContext;
@protocol MSIDWebviewInteracting;
@protocol MSIDWebviewNavigationDelegate;
@class MSIDWebviewNavigationDecision;
@class MSIDOAuth2EmbeddedWebviewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * Helper class that encapsulates common webview navigation delegate logic
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
 * Wires @c delegate as the navigation delegate of @c webviewController when the latter
 * is an @c MSIDOAuth2EmbeddedWebviewController (or subclass). For any other concrete
 * @c MSIDWebviewInteracting type (Safari, ASWebAuth, etc.) the call is a no-op.
 *
 * @param webviewController The webview produced by the configuration block.
 * @param delegate          The controller that will receive navigation events.
 */
- (void)configureWebviewController:(nullable id<MSIDWebviewInteracting>)webviewController
                          delegate:(id<MSIDWebviewNavigationDelegate>)delegate;

#pragma mark - Navigation Delegate Methods

/**
 * Handles special redirect URLs (msauth://, browser://).
 * Routes to appropriate handler based on URL scheme.
 * This is the full method signature used by controllers.
 *
 * @param URL The special redirect URL
 * @param embeddedWebviewController The embedded webview controller instance
 * @param appName The name of the sdk
 * @param appVersion The version of the sdk
 * @param completion Completion block with the navigation decision or error
 */
- (void)handleSpecialRedirectURL:(NSURL *)URL
       embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController * _Nullable)embeddedWebviewController
                         appName:(NSString *)appName
                      appVersion:(NSString *)appVersion
                      completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable navigationDecision, NSError * _Nullable error))completion;

/**
 * Caches response headers and detects an ASWebAuthenticationSession hand-off signal.
 * On YES, caller should cancel the WKWebView navigation and invoke the hand-off method below.
 *
 * @param headers HTTP response headers (raw `allHeaderFields`)
 * @return YES if @c headers signal a hand-off; NO otherwise
 */
- (BOOL)processResponseHeaders:(NSDictionary *)headers;

#if !MSID_EXCLUDE_SYSTEMWV
/**
 * Performs the hand-off using the headers cached by the last @c processResponseHeaders: call.
 *
 * @param parentController The view controller that presents the webview
 * @param completion Completion block - MUST be called exactly once; failures surface as a @c failWithError decision
 */
- (void)performASWebAuthenticationHandoffWithParentController:(MSIDViewController *)parentController
                                                   completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                        NSError * _Nullable error))completion;
#endif // !MSID_EXCLUDE_SYSTEMWV

@end

NS_ASSUME_NONNULL_END

#endif
